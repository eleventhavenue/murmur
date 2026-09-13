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
    private let collector = MarkCollector()

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
                let collector = await MainActor.run { self?.collector }
                try await provider.synthesize(text) { buffer in
                    await MainActor.run { self?.append(buffer) }
                } onMark: { mark in
                    collector?.add(mark)   // synchronous, thread-safe
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
        // Drain marks collected synchronously during synthesis. Only estimate
        // when the provider genuinely reported none.
        marks = collector.drain()
        if error == nil, marks.isEmpty { marks = Self.estimateMarks(for: text, duration: duration) }
        if error == nil {
            let ns = text as NSString
            Log.info(String(format: "MARKS n=%d dur=%.3f", marks.count, duration))
            for m in marks where NSMaxRange(m.range) <= ns.length {
                Log.info(String(format: "   mark %.3f %@", m.time, ns.substring(with: m.range)))
            }
        }
        continuations.forEach { error == nil ? $0.finish() : $0.finish(throwing: error) }
        continuations = []
    }

    /// Spreads words across the chunk's duration when the provider reports no
    /// boundaries of its own.
    ///
    /// Weighted by characters rather than word count, so "a" does not get the
    /// same airtime as "extraordinarily", and with extra weight after clause
    /// and sentence punctuation, because every voice pauses there and a flat
    /// spread runs ahead through the second half of any sentence with a comma
    /// in it. Chunks are single sentences, so the error cannot compound beyond
    /// one of them.
    private static func estimateMarks(for text: String, duration: TimeInterval) -> [SpeechMark] {
        guard duration > 0, !text.isEmpty else { return [] }
        let ns = text as NSString

        var words: [NSRange] = []
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length),
                               options: [.byWords, .substringNotRequired]) { _, range, _, _ in
            words.append(range)
        }
        guard !words.isEmpty else { return [] }

        // Weight for each word: its length, plus a pause allowance if the text
        // right after it is clause or sentence punctuation.
        func weight(_ index: Int) -> Double {
            let range = words[index]
            var w = Double(range.length)
            let after = NSMaxRange(range)
            if after < ns.length {
                let next = ns.substring(with: NSRange(location: after, length: 1))
                if ".!?".contains(next) { w += 6 }
                else if ",;:".contains(next) { w += 3 }
            }
            return w
        }
        let weights = words.indices.map(weight)
        let total = weights.reduce(0, +)
        guard total > 0 else { return [] }

        var consumed = 0.0
        return words.enumerated().map { i, range in
            let time = duration * consumed / total
            consumed += weights[i]
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

/// Gathers speech marks as they arrive, from whatever thread the provider uses.
///
/// The marks used to be appended through `Task { @MainActor }`, which is
/// asynchronous: synthesis finished and the loader fell back to estimated marks
/// before a single real one had landed, so accurate timings were silently
/// discarded on every chunk. Collecting under a lock keeps them synchronous and
/// order-preserving.
final class MarkCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var marks: [SpeechMark] = []

    func add(_ mark: SpeechMark) {
        lock.lock(); marks.append(mark); lock.unlock()
    }

    func drain() -> [SpeechMark] {
        lock.lock(); defer { lock.unlock() }
        return marks
    }
}
