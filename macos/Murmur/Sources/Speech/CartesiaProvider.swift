import AVFoundation
import Foundation

/// Cartesia Sonic-3 over the streaming bytes endpoint, raw float32 PCM at 24 kHz.
struct CartesiaProvider: SpeechProvider {
    let apiKey: String
    let voiceID: String
    static let sampleRate: Double = 24_000

    func synthesize(_ text: String, onBuffer: @escaping (AVAudioPCMBuffer) async -> Void) async throws {
        guard !apiKey.isEmpty else { throw SpeechError(message: "Add your Cartesia API key in Settings.") }
        var request = URLRequest(url: URL(string: "https://api.cartesia.ai/tts/bytes")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("2025-04-16", forHTTPHeaderField: "Cartesia-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model_id": "sonic-3",
            "transcript": text,
            "voice": ["mode": "id", "id": voiceID],
            "output_format": ["container": "raw", "encoding": "pcm_f32le", "sample_rate": Int(Self.sampleRate)],
            "language": "en",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var pending = Data()
        let http = StreamingHTTP()
        for try await chunk in http.stream(request) {
            pending.append(chunk)
            // Emit in ~100 ms slices, aligned to 4-byte samples.
            let sliceBytes = Int(Self.sampleRate / 10) * 4
            while pending.count >= sliceBytes {
                let slice = pending.prefix(sliceBytes)
                pending.removeFirst(sliceBytes)
                if let buffer = PCM.bufferFromFloat32(Data(slice), sampleRate: Self.sampleRate) { await onBuffer(buffer) }
            }
        }
        let aligned = pending.count - pending.count % 4
        if aligned > 0, let buffer = PCM.bufferFromFloat32(pending.prefix(aligned), sampleRate: Self.sampleRate) {
            await onBuffer(buffer)
        }
    }
}
