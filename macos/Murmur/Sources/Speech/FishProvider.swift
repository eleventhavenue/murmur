import AVFoundation
import Foundation

/// Fish Audio S1, raw int16 PCM.
struct FishProvider: SpeechProvider {
    let apiKey: String
    let referenceID: String
    static let sampleRate: Double = 24_000

    func synthesize(_ text: String, onBuffer: @escaping (AVAudioPCMBuffer) async -> Void) async throws {
        guard !apiKey.isEmpty else { throw SpeechError(message: "Add your Fish Audio API key in Settings.") }
        var request = URLRequest(url: URL(string: "https://api.fish.audio/v1/tts")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("s1", forHTTPHeaderField: "model")
        var body: [String: Any] = [
            "text": text,
            "format": "pcm",
            "sample_rate": Int(Self.sampleRate),
            "latency": "balanced",
        ]
        if !referenceID.isEmpty { body["reference_id"] = referenceID }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var pending = Data()
        let http = StreamingHTTP()
        for try await chunk in http.stream(request) {
            pending.append(chunk)
            let sliceBytes = Int(Self.sampleRate / 10) * 2
            while pending.count >= sliceBytes {
                let slice = pending.prefix(sliceBytes)
                pending.removeFirst(sliceBytes)
                if let buffer = PCM.bufferFromInt16(Data(slice), sampleRate: Self.sampleRate) { await onBuffer(buffer) }
            }
        }
        let aligned = pending.count - pending.count % 2
        if aligned > 0, let buffer = PCM.bufferFromInt16(pending.prefix(aligned), sampleRate: Self.sampleRate) {
            await onBuffer(buffer)
        }
    }
}
