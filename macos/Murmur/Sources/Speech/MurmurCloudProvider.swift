import AVFoundation
import Foundation

/// Murmur Cloud: premium voices for Pro subscribers, authenticated with a
/// license key instead of a personal API key.
///
/// The upstream provider key lives on the server, so nothing sensitive ships in
/// the app. Anyone who prefers to bring their own Cartesia or Fish key can still
/// do that for free; this exists so paying users don't have to.
struct MurmurCloudProvider: SpeechProvider {
    let licenseKey: String
    let voiceID: String
    static let sampleRate: Double = 24_000

    func synthesize(_ text: String, onBuffer: @escaping (AVAudioPCMBuffer) async -> Void) async throws {
        guard !licenseKey.isEmpty else {
            throw SpeechError(message: "Add your Murmur licence key in Settings, or pick a different voice.")
        }

        var request = URLRequest(url: License.endpoint(path: "/api/tts"))
        request.httpMethod = "POST"
        request.setValue(licenseKey, forHTTPHeaderField: "X-Murmur-License")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "voice": voiceID,
        ])

        var pending = Data()
        let http = StreamingHTTP()
        for try await chunk in http.stream(request) {
            pending.append(chunk)
            let sliceBytes = Int(Self.sampleRate / 10) * 4
            while pending.count >= sliceBytes {
                let slice = pending.prefix(sliceBytes)
                pending.removeFirst(sliceBytes)
                if let buffer = PCM.bufferFromFloat32(Data(slice), sampleRate: Self.sampleRate) {
                    await onBuffer(buffer)
                }
            }
        }
        let aligned = pending.count - pending.count % 4
        if aligned > 0, let buffer = PCM.bufferFromFloat32(pending.prefix(aligned), sampleRate: Self.sampleRate) {
            await onBuffer(buffer)
        }
    }
}
