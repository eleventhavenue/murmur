import AppKit
import AVFoundation
import Combine

/// Orchestrates one reading: clean → chunk → prefetch audio → stream into the pipeline → track position.
@MainActor
final class ReaderSession: ObservableObject {
    enum Phase: Equatable {
        case idle, preparing, playing, paused, finished
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle { didSet { if phase != oldValue { Log.info("phase \(phase)") } } }
    @Published private(set) var chunks: [TextChunk] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var progress: Double = 0
    @Published private(set) var levels = [Float](repeating: 0, count: 24)
    @Published private(set) var sourceApp: String = ""
    @Published var speed: Double {
        didSet { audio.rate = Float(speed); Settings.shared.speed = speed }
    }

    var currentText: String { chunks.indices.contains(currentIndex) ? chunks[currentIndex].text : "" }
    var isActive: Bool { phase == .playing || phase == .paused || phase == .preparing }
    private(set) var originalText = ""

    private let audio = AudioPipeline()
    private var loaders: [Int: ChunkLoader] = [:]
    private var generation = 0
    private var pumpTask: Task<Void, Never>?
    private var chunkStartSample: AVAudioFramePosition = 0
    private var ticker: Timer?
    private let prefetchDepth = 3

    init() {
        speed = Settings.shared.speed
        audio.rate = Float(speed)
        audio.onLevels = { [weak self] l in self?.levels = l }
    }

    // MARK: - Control

    func start(text: String, sourceApp: String = "") {
        teardown()
        let settings = Settings.shared
        let cleaner = TextCleaner(stripMarkdown: settings.cleanMarkdown, joinWrappedLines: settings.joinWrappedLines)
        originalText = text
        self.sourceApp = sourceApp
        chunks = Chunker.chunks(for: cleaner.clean(text))
        currentIndex = 0
        progress = 0
        guard !chunks.isEmpty else { phase = .failed("Nothing readable in that selection."); return }
        phase = .preparing
        do { try audio.start() } catch { phase = .failed("Audio engine failed: \(error.localizedDescription)"); return }
        generation += 1
        let gen = generation
        pumpTask = Task { await pump(from: 0, gen: gen) }
        startTicker()
    }

    func togglePlayPause() {
        switch phase {
        case .playing: audio.pause(); phase = .paused
        case .paused: audio.play(); phase = .playing
        case .finished: seek(to: 0)
        default: break
        }
    }

    func seek(to index: Int) {
        guard chunks.indices.contains(index) else { return }
        generation += 1
        let gen = generation
        pumpTask?.cancel()
        audio.reset()
        currentIndex = index
        chunkStartSample = 0
        phase = .preparing
        do { try audio.start() } catch { phase = .failed(error.localizedDescription); return }
        pumpTask = Task { await pump(from: index, gen: gen) }
        startTicker()
    }

    func skip(_ delta: Int) { seek(to: max(0, min(chunks.count - 1, currentIndex + delta))) }

    func stop() {
        teardown()
        phase = .idle
    }

    private func teardown() {
        generation += 1
        pumpTask?.cancel()
        pumpTask = nil
        loaders.values.forEach { $0.cancel() }
        loaders = [:]
        ticker?.invalidate()
        ticker = nil
        audio.stop()
    }

    // MARK: - Pipeline

    private func provider() -> SpeechProvider {
        let s = Settings.shared
        switch s.provider {
        case .system: return SystemVoiceProvider(voiceIdentifier: s.systemVoice)
        case .cloud: return MurmurCloudProvider(licenseKey: s.licenseKey, voiceID: s.cartesiaVoice)
        case .localServer:
            return LocalServerProvider(baseURL: s.localServerURL, model: s.localServerModel,
                                       voice: s.localServerVoice, apiKey: s.localServerKey)
        case .cartesia: return CartesiaProvider(apiKey: s.cartesiaKey, voiceID: s.cartesiaVoice)
        case .fish: return FishProvider(apiKey: s.fishKey, referenceID: s.fishVoice)
        }
    }

    private func loader(for index: Int) -> ChunkLoader {
        if let l = loaders[index] { return l }
        let l = ChunkLoader()
        l.begin(provider: provider(), text: chunks[index].text)
        loaders[index] = l
        return l
    }

    private func pump(from start: Int, gen: Int) async {
        // Wake a local engine that is installed but stopped, before the first
        // request fails. Costs nothing for every other provider.
        if Settings.shared.provider == .localServer {
            await LocalEngine.shared.ensureRunning()
            guard gen == generation else { return }
        }

        var started = false
        for i in start..<chunks.count {
            guard gen == generation else { return }
            for j in i..<min(i + prefetchDepth, chunks.count) { _ = loader(for: j) }
            let chunkLoader = loader(for: i)
            do {
                for try await buffer in chunkLoader.stream() {
                    guard gen == generation else { return }
                    audio.schedule(buffer)
                    if !started {
                        started = true
                        audio.play()
                        phase = .playing
                    }
                }
            } catch {
                guard gen == generation else { return }
                phase = .failed((error as? SpeechError)?.message ?? error.localizedDescription)
                return
            }
            guard gen == generation else { return }
            // Breath between sentences doubles as the "chunk finished" marker.
            let isLast = i == chunks.count - 1
            audio.schedule(audio.silence(seconds: isLast ? 0.05 : 0.18)) { [weak self] in
                Task { @MainActor in self?.chunkDidFinish(i, gen: gen) }
            }
        }
    }

    private func chunkDidFinish(_ index: Int, gen: Int) {
        guard gen == generation else { return }
        if index >= chunks.count - 1 {
            phase = .finished
            progress = 1
            ticker?.invalidate()
        } else {
            currentIndex = index + 1
            chunkStartSample = audio.sampleTime
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard phase == .playing || phase == .paused, !chunks.isEmpty else { return }
        let totalChars = Double(chunks.reduce(0) { $0 + $1.text.count })
        let before = Double(chunks[..<currentIndex].reduce(0) { $0 + $1.text.count })
        var fraction = 0.0
        if let l = loaders[currentIndex], l.isComplete, l.totalFrames > 0 {
            fraction = min(1, Double(audio.sampleTime - chunkStartSample) / Double(l.totalFrames))
        }
        progress = min(1, (before + fraction * Double(chunks[currentIndex].text.count)) / max(totalChars, 1))
    }
}
