import AVFoundation
import Foundation

/// Fetches one chunk's audio and lets any number of consumers replay it (cached for instant back-skips).
@MainActor
final class ChunkLoader {
    private(set) var buffers: [AVAudioPCMBuffer] = []
    /// Word boundaries, in ascending frame order. Real where the provider
    /// supplied them, estimated otherwise.
    private(set) var marks: [SpeechMark] = []
    private var text = ""
    private(set) var isComplete = false
    private(set) var error: Error?
    private var continuations: [AsyncThrowingStream<AVAudioPCMBuffer, Error>.Continuation] = []
    private var task: Task<Void, Never>?

    var totalFrames: AVAudioFramePosition { buffers.reduce(0) { $0 + AVAudioFramePosition($1.frameLength) } }

    /// Length of this chunk's audio in seconds.
    ///
    /// Derived from each buffer's own format rather than a frame count, because
    /// providers render at different rates and the pipeline resamples. A frame
    /// total is only meaningful next to the clock that produced it.
    var duration: TimeInterval {
        buffers.reduce(0) { total, buffer in
            let rate = buffer.format.sampleRate
            return rate > 0 ? total + Double(buffer.frameLength) / rate : total
        }
    }

    func begin(provider: SpeechProvider, text: String) {
        guard task == nil else { return }
        self.text = text
        task = Task { [weak self] in
            do {
                try await provider.synthesize(text) { buffer in
                    await MainActor.run { self?.append(buffer) }
                } onMark: { mark in
                    Task { @MainActor in self?.marks.append(mark) }
                }
                await MainActor.run { self?.finish(error: nil) }
            } catch {
                await MainActor.run { self?.finish(error: error) }
            }
        }
    }

    /// Character range being spoken at a given point in this chunk.
    func range(at time: TimeInterval) -> NSRange? {
        guard !marks.isEmpty else { return nil }
        // Marks are ascending, so the last one at or before the playhead wins.
        var found: SpeechMark?
        for mark in marks {
            if mark.time > time { break }
            found = mark
        }
        return found?.range
    }

    func cancel() { task?.cancel() }

    private func append(_ buffer: AVAudioPCMBuffer) {
        buffers.append(buffer)
        continuations.forEach { $0.yield(buffer) }
    }

    private func finish(error: Error?) {
        self.error = error
        isComplete = true
        if error == nil, marks.isEmpty { marks = Self.estimateMarks(for: text, duration: duration) }
        continuations.forEach { error == nil ? $0.finish() : $0.finish(throwing: error) }
        continuations = []
    }

    /// Spreads words across the chunk's duration in proportion to their length.
    ///
    /// Only Apple's voices report real boundaries. For everything else this is
    /// close enough to look right, because chunks are single sentences, so the
    /// error cannot accumulate beyond one of them. Leading silence is not
    /// modelled, which is the main source of drift.
    private static func estimateMarks(for text: String, duration: TimeInterval) -> [SpeechMark] {
        guard duration > 0, !text.isEmpty else { return [] }
        let ns = text as NSString

        var words: [NSRange] = []
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length),
                               options: [.byWords, .substringNotRequired]) { _, range, _, _ in
            words.append(range)
        }
        guard !words.isEmpty else { return [] }

        // Weight by characters spanned rather than word count, so "a" does not
        // get the same airtime as "extraordinarily".
        let total = words.reduce(0) { $0 + $1.length }
        guard total > 0 else { return [] }

        var consumed = 0
        return words.map { range in
            let time = duration * Double(consumed) / Double(total)
            consumed += range.length
            return SpeechMark(range: range, time: time)
        }
    }

    func stream() -> AsyncThrowingStream<AVAudioPCMBuffer, Error> {
        AsyncThrowingStream { continuation in
            for b in buffers { continuation.yield(b) }
            if let error { continuation.finish(throwing: error) }
            else if isComplete { continuation.finish() }
            else { continuations.append(continuation) }
        }
    }
}
