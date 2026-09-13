import AVFoundation
import Foundation

/// Any server that speaks OpenAI's `/v1/audio/speech` API.
///
/// One implementation reaches the whole local TTS ecosystem — Kokoro-FastAPI,
/// LM Studio, LocalAI, Speaches — so people can run whichever model they like
/// on their own machine and Murmur just plays it. Nothing is bundled, nothing
/// is licensed, and the text never leaves their network.
///
/// `pcm` is requested because it needs no decoding and starts playing on the
/// first bytes. Servers that ignore the request and send a WAV are handled too,
/// since that is a common deviation.
struct LocalServerProvider: SpeechProvider {
    let baseURL: String
    let model: String
    let voice: String
    let apiKey: String

    /// OpenAI's documented rate for `pcm`, and what every compatible server emits.
    static let defaultSampleRate: Double = 24_000

    func synthesize(_ text: String,
                    onBuffer: @escaping (AVAudioPCMBuffer) async -> Void,
                    onMark: @escaping (SpeechMark) -> Void) async throws {
        guard let url = Self.speechURL(from: baseURL) else {
            throw SpeechError(message: "That server address doesn't look like a URL.")
        }

        // Kokoro-FastAPI can report where every word starts. Prefer that when
        // the server has it, so the highlight is exact rather than estimated.
        if await CaptionedSpeech.isSupported(baseURL: baseURL) {
            do {
                try await synthesizeCaptioned(text, onBuffer: onBuffer, onMark: onMark)
                return
            } catch {
                // Fall through to the plain endpoint; estimated marks are
                // better than no audio.
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model.isEmpty ? "tts-1" : model,
            "input": text,
            "voice": voice,
            "response_format": "pcm",
            // Playback rate is handled by our own time-pitch unit, so that
            // changing speed mid-sentence doesn't require re-synthesis.
            "speed": 1.0,
        ])

        var decoder = PCMStreamDecoder(fallbackSampleRate: Self.defaultSampleRate)
        let http = StreamingHTTP()

        for try await chunk in http.stream(request) {
            for buffer in decoder.consume(chunk) { await onBuffer(buffer) }
        }
        if let tail = decoder.flush() { await onBuffer(tail) }
    }

    /// Accepts `http://localhost:8880`, `.../v1` or a full `.../v1/audio/speech`.
    static func speechURL(from base: String) -> URL? {
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if trimmed.hasSuffix("/audio/speech") { return URL(string: trimmed) }
        if trimmed.hasSuffix("/v1") { return URL(string: trimmed + "/audio/speech") }
        return URL(string: trimmed + "/v1/audio/speech")
    }
}

/// Turns a byte stream into PCM buffers, sniffing a WAV header if one arrives.
///
/// Servers are inconsistent: most honour `response_format: "pcm"` and send raw
/// little-endian int16, but several send a RIFF/WAVE file regardless. Reading
/// the header when present means both work, and means the sample rate comes
/// from the server rather than being assumed.
struct PCMStreamDecoder {
    private let fallbackSampleRate: Double
    private var sampleRate: Double
    private var pending = Data()
    private var inspectedHeader = false

    /// Emit roughly 100 ms at a time so playback starts quickly.
    private var sliceBytes: Int { max(2, Int(sampleRate / 10) * 2) }

    init(fallbackSampleRate: Double) {
        self.fallbackSampleRate = fallbackSampleRate
        self.sampleRate = fallbackSampleRate
    }

    mutating func consume(_ chunk: Data) -> [AVAudioPCMBuffer] {
        pending.append(chunk)

        if !inspectedHeader {
            // A RIFF header is 44 bytes for canonical WAV, more when the file
            // carries extra chunks. Wait for enough bytes to decide.
            guard pending.count >= 44 else { return [] }
            inspectedHeader = true
            if let header = WAVHeader(pending) {
                sampleRate = header.sampleRate
                pending.removeFirst(header.dataOffset)
            }
        }

        var buffers: [AVAudioPCMBuffer] = []
        while pending.count >= sliceBytes {
            let slice = Data(pending.prefix(sliceBytes))
            pending.removeFirst(sliceBytes)
            if let buffer = PCM.bufferFromInt16(slice, sampleRate: sampleRate) {
                buffers.append(buffer)
            }
        }
        return buffers
    }

    mutating func flush() -> AVAudioPCMBuffer? {
        // Header never materialised (very short reply): treat what we have as raw.
        if !inspectedHeader {
            inspectedHeader = true
            if let header = WAVHeader(pending) {
                sampleRate = header.sampleRate
                pending.removeFirst(header.dataOffset)
            }
        }
        let aligned = pending.count - pending.count % 2
        guard aligned > 0 else { return nil }
        let slice = Data(pending.prefix(aligned))
        pending.removeAll()
        return PCM.bufferFromInt16(slice, sampleRate: sampleRate)
    }
}

/// Minimal RIFF/WAVE reader: just the sample rate and where the samples start.
struct WAVHeader {
    let sampleRate: Double
    let dataOffset: Int

    init?(_ data: Data) {
        guard data.count >= 44 else { return nil }
        let bytes = [UInt8](data.prefix(min(data.count, 4096)))
        guard bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46,   // "RIFF"
              bytes[8] == 0x57, bytes[9] == 0x41, bytes[10] == 0x56, bytes[11] == 0x45  // "WAVE"
        else { return nil }

        func u32(_ i: Int) -> UInt32 {
            UInt32(bytes[i]) | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2]) << 16 | UInt32(bytes[i + 3]) << 24
        }

        // Walk the chunk list: "fmt " carries the rate, "data" starts the samples.
        var rate: Double?
        var offset = 12
        while offset + 8 <= bytes.count {
            let id = (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
            let size = Int(u32(offset + 4))
            let body = offset + 8

            if id == (0x66, 0x6D, 0x74, 0x20), body + 8 <= bytes.count {        // "fmt "
                rate = Double(u32(body + 4))
            }
            if id == (0x64, 0x61, 0x74, 0x61) {                                  // "data"
                self.sampleRate = rate ?? 24_000
                self.dataOffset = body
                return
            }
            // Chunks are word-aligned.
            offset = body + size + (size % 2)
        }
        return nil
    }
}


// MARK: - Kokoro-FastAPI captioned speech

extension LocalServerProvider {
    /// `POST /dev/captioned_speech` returns the whole sentence as one JSON
    /// payload: base64 audio plus a `start_time` for every word. It does not
    /// stream even when asked to, so the first sentence of a reading waits for
    /// synthesis to finish before any sound. Later sentences are prefetched, so
    /// only the first pays that, and exact highlighting is worth it.
    func synthesizeCaptioned(_ text: String,
                             onBuffer: @escaping (AVAudioPCMBuffer) async -> Void,
                             onMark: @escaping (SpeechMark) -> Void) async throws {
        guard let url = CaptionedSpeech.url(baseURL: baseURL) else {
            throw SpeechError(message: "Bad server address.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model.isEmpty ? "kokoro" : model,
            "input": text,
            "voice": voice,
            "response_format": "pcm",
            "stream": false,
            "return_timestamps": true,
            "speed": 1.0,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SpeechError(message: "Captioned speech failed (\((response as? HTTPURLResponse)?.statusCode ?? 0)).")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let b64 = json["audio"] as? String,
              let audio = Data(base64Encoded: b64) else {
            throw SpeechError(message: "Captioned speech returned an unexpected shape.")
        }

        // Marks first, so the highlight is ready when the first buffer lands.
        let stamps = (json["timestamps"] as? [[String: Any]]) ?? []
        for mark in CaptionedSpeech.marks(from: stamps, in: text) { onMark(mark) }

        // Same decoder as the streaming path: it copes with raw pcm and with a
        // WAV header should the server change its mind.
        var decoder = PCMStreamDecoder(fallbackSampleRate: Self.defaultSampleRate)
        for buffer in decoder.consume(audio) { await onBuffer(buffer) }
        if let tail = decoder.flush() { await onBuffer(tail) }
    }
}

/// Discovery and translation for the captioned endpoint.
enum CaptionedSpeech {
    /// Remembered per server so the probe happens once, not once per sentence.
    private static let lock = NSLock()
    private static var supported: [String: Bool] = [:]

    static func url(baseURL: String) -> URL? {
        guard let root = LocalServerDiscovery.normalized(baseURL),
              var comps = URLComponents(url: root, resolvingAgainstBaseURL: false) else { return nil }
        comps.path = "/dev/captioned_speech"
        comps.query = nil
        return comps.url
    }

    // Synchronous accessors keep the lock out of async contexts, which Swift 6
    // forbids and Swift 5 warns about.
    private static func cached(_ baseURL: String) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        return supported[baseURL]
    }
    private static func remember(_ value: Bool, for baseURL: String) {
        lock.lock(); supported[baseURL] = value; lock.unlock()
    }

    static func isSupported(baseURL: String) async -> Bool {
        if let cached = cached(baseURL) { return cached }

        // The OpenAPI document is the honest capability check; a bare 404 on
        // the endpoint would also work but is slower to distinguish from a
        // server that is simply down.
        var result = false
        if let root = LocalServerDiscovery.normalized(baseURL),
           var comps = URLComponents(url: root, resolvingAgainstBaseURL: false) {
            comps.path = "/openapi.json"; comps.query = nil
            if let u = comps.url {
                var req = URLRequest(url: u); req.timeoutInterval = 3
                if let (data, resp) = try? await URLSession.shared.data(for: req),
                   (resp as? HTTPURLResponse)?.statusCode == 200,
                   let spec = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let paths = spec["paths"] as? [String: Any] {
                    result = paths.keys.contains("/dev/captioned_speech")
                }
            }
        }
        remember(result, for: baseURL)
        return result
    }

    /// The server returns words, not character positions. Walk the text
    /// forward matching each word so every stamp becomes a range, and skip
    /// tokens that are only punctuation (Kokoro reports the final "." as its
    /// own word). Forward-only matching survives cleaning differences, because
    /// a miss costs one word rather than desyncing everything after it.
    static func marks(from stamps: [[String: Any]], in text: String) -> [SpeechMark] {
        let ns = text as NSString
        var cursor = 0
        var out: [SpeechMark] = []
        for stamp in stamps {
            guard let word = stamp["word"] as? String,
                  let start = stamp["start_time"] as? Double else { continue }
            let core = word.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            if core.isEmpty { continue }
            let search = NSRange(location: cursor, length: ns.length - cursor)
            let found = ns.range(of: core, options: [.caseInsensitive], range: search)
            guard found.location != NSNotFound else { continue }
            out.append(SpeechMark(range: found, time: start))
            cursor = NSMaxRange(found)
        }
        return out
    }
}
