import AVFoundation

/// player → time-pitch (speed without chipmunk) → mixer, with a level tap for the waveform.
final class AudioPipeline {
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000, channels: 1, interleaved: false)!
    var onLevels: (([Float]) -> Void)?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private var converters: [String: AVAudioConverter] = [:]
    private var smoothed = [Float](repeating: 0, count: 24)

    init() {
        engine.attach(player)
        engine.attach(pitch)
        engine.connect(player, to: pitch, format: format)
        engine.connect(pitch, to: engine.mainMixerNode, format: format)
        pitch.overlap = 12
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.measure(buffer)
        }
    }

    var rate: Float {
        get { pitch.rate }
        set { pitch.rate = max(0.5, min(3.0, newValue)) }
    }

    func start() throws {
        if !engine.isRunning { try engine.start() }
    }

    func play() { player.play() }
    func pause() { player.pause() }
    var isPlaying: Bool { player.isPlaying }

    /// Drops everything scheduled. Subsequent schedule() calls start fresh.
    func reset() { player.stop() }

    func stop() {
        player.stop()
        engine.stop()
        smoothed = [Float](repeating: 0, count: smoothed.count)
        onLevels?(smoothed)
    }

    /// Frames of audio the player has consumed since the last play() after a reset.
    var sampleTime: AVAudioFramePosition {
        guard let nodeTime = player.lastRenderTime, let t = player.playerTime(forNodeTime: nodeTime) else { return 0 }
        return t.sampleTime
    }

    func schedule(_ buffer: AVAudioPCMBuffer, completion: (() -> Void)? = nil) {
        guard let converted = convert(buffer) else { return }
        if let completion {
            player.scheduleBuffer(converted, completionCallbackType: .dataPlayedBack) { _ in completion() }
        } else {
            player.scheduleBuffer(converted)
        }
    }

    func silence(seconds: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frames, 1))!
        buffer.frameLength = max(frames, 1)
        return buffer
    }

    // MARK: - Conversion

    private func convert(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let inFormat = input.format
        if inFormat.sampleRate == format.sampleRate, inFormat.commonFormat == .pcmFormatFloat32,
           inFormat.channelCount == 1, !inFormat.isInterleaved {
            return input
        }
        let key = "\(inFormat.sampleRate)-\(inFormat.commonFormat.rawValue)-\(inFormat.channelCount)-\(inFormat.isInterleaved)"
        let converter: AVAudioConverter
        if let cached = converters[key] { converter = cached }
        else {
            guard let c = AVAudioConverter(from: inFormat, to: format) else { return nil }
            converters[key] = c
            converter = c
        }
        let ratio = format.sampleRate / inFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return input
        }
        return error == nil ? output : nil
    }

    // MARK: - Levels

    private func measure(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        let bands = smoothed.count
        guard n >= bands else { return }
        let per = n / bands
        var next = [Float](repeating: 0, count: bands)
        for b in 0..<bands {
            var sum: Float = 0
            for i in (b * per)..<((b + 1) * per) { sum += data[i] * data[i] }
            let rms = (sum / Float(per)).squareRoot()
            next[b] = min(1, rms * 5.5)
        }
        for i in 0..<bands {
            let target = next[i]
            smoothed[i] = target > smoothed[i] ? target : smoothed[i] * 0.72 + target * 0.28
        }
        let snapshot = smoothed
        DispatchQueue.main.async { [weak self] in self?.onLevels?(snapshot) }
    }
}
