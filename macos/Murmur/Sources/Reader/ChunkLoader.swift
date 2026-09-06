import AVFoundation

/// Fetches one chunk's audio and lets any number of consumers replay it (cached for instant back-skips).
@MainActor
final class ChunkLoader {
    private(set) var buffers: [AVAudioPCMBuffer] = []
    private(set) var isComplete = false
    private(set) var error: Error?
    private var continuations: [AsyncThrowingStream<AVAudioPCMBuffer, Error>.Continuation] = []
    private var task: Task<Void, Never>?

    var totalFrames: AVAudioFramePosition { buffers.reduce(0) { $0 + AVAudioFramePosition($1.frameLength) } }

    func begin(provider: SpeechProvider, text: String) {
        guard task == nil else { return }
        task = Task { [weak self] in
            do {
                try await provider.synthesize(text) { buffer in
                    await MainActor.run { self?.append(buffer) }
                }
                await MainActor.run { self?.finish(error: nil) }
            } catch {
                await MainActor.run { self?.finish(error: error) }
            }
        }
    }

    func cancel() { task?.cancel() }

    private func append(_ buffer: AVAudioPCMBuffer) {
        buffers.append(buffer)
        continuations.forEach { $0.yield(buffer) }
    }

    private func finish(error: Error?) {
        self.error = error
        isComplete = true
        continuations.forEach { error == nil ? $0.finish() : $0.finish(throwing: error) }
        continuations = []
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
