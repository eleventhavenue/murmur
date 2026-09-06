import AVFoundation

/// Apple's on-device voices, rendered to PCM so they flow through the same audio pipeline (speed, waveform).
struct SystemVoiceProvider: SpeechProvider {
    let voiceIdentifier: String

    func synthesize(_ text: String, onBuffer: @escaping (AVAudioPCMBuffer) async -> Void) async throws {
        let utterance = AVSpeechUtterance(string: text)
        if !voiceIdentifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = Self.bestDefaultVoice()
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        let synthesizer = AVSpeechSynthesizer()
        let stream = AsyncStream<AVAudioPCMBuffer> { continuation in
            synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { continuation.finish(); return }
                if pcm.frameLength == 0 { continuation.finish() } else { continuation.yield(pcm) }
            }
        }
        for await buffer in stream {
            await onBuffer(buffer)
        }
        withExtendedLifetime(synthesizer) {}
    }

    static func bestDefaultVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let ranked = voices.sorted { a, b in a.quality.rawValue > b.quality.rawValue }
        return ranked.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}
