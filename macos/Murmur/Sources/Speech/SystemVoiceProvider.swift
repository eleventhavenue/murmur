import AVFoundation

/// Apple's on-device voices, rendered to PCM so they flow through the same
/// audio pipeline (speed, waveform) as everything else.
///
/// These are the only voices that hand back real word boundaries. The
/// synthesiser reports each word as it renders it, and pairing that with the
/// frame count produced so far gives an exact map from characters to audio
/// position, which is what drives the highlight in the player.
struct SystemVoiceProvider: SpeechProvider {
    let voiceIdentifier: String

    func synthesize(_ text: String,
                    onBuffer: @escaping (AVAudioPCMBuffer) async -> Void,
                    onMark: @escaping (SpeechMark) -> Void) async throws {
        let utterance = AVSpeechUtterance(string: text)
        if !voiceIdentifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = Self.bestDefaultVoice()
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        let synthesizer = AVSpeechSynthesizer()
        let recorder = MarkRecorder(onMark: onMark)
        synthesizer.delegate = recorder

        let stream = AsyncStream<AVAudioPCMBuffer> { continuation in
            synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { continuation.finish(); return }
                if pcm.frameLength == 0 {
                    continuation.finish()
                } else {
                    // Counted before yielding, so a mark arriving during this
                    // callback lands at the right offset.
                    recorder.advance(by: AVAudioFramePosition(pcm.frameLength))
                    continuation.yield(pcm)
                }
            }
        }
        for await buffer in stream {
            await onBuffer(buffer)
        }
        withExtendedLifetime((synthesizer, recorder)) {}
    }

    /// Delegates to VoiceCatalog, which ranks by voice lineage rather than the
    /// system quality flag. Sorting on quality alone leaves every voice tied on
    /// a stock Mac, which made this pick arbitrary and occasionally a novelty
    /// voice.
    static func bestDefaultVoice() -> AVSpeechSynthesisVoice? {
        VoiceCatalog.best()
    }
}

/// Bridges `willSpeakRange` into frame-stamped marks.
///
/// The delegate fires on the main queue while rendering runs elsewhere, so the
/// frame counter is guarded. `speechSynthesizer(_:willSpeakRangeOfSpeechString:)`
/// does fire during `write(_:toBufferCallback:)`, not only during live speech,
/// which is what makes this possible at all.
private final class MarkRecorder: NSObject, AVSpeechSynthesizerDelegate {
    private let onMark: (SpeechMark) -> Void
    private let lock = NSLock()
    private var frames: AVAudioFramePosition = 0

    init(onMark: @escaping (SpeechMark) -> Void) {
        self.onMark = onMark
    }

    func advance(by count: AVAudioFramePosition) {
        lock.lock(); frames += count; lock.unlock()
    }

    private var currentFrame: AVAudioFramePosition {
        lock.lock(); defer { lock.unlock() }
        return frames
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        onMark(SpeechMark(range: characterRange, frame: currentFrame))
    }
}
