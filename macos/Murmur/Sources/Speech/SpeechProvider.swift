import AVFoundation

struct SpeechError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

import Foundation

/// Where one word starts: characters into the chunk, and seconds into its audio.
///
/// Seconds rather than frames, because providers do not agree on a sample rate.
/// Apple's voices render at 22.05 kHz while the pipeline runs at 24 kHz and
/// resamples, so a frame count from one clock means something different in the
/// other. Timing in seconds is the only value both ends agree on.
struct SpeechMark {
    let range: NSRange
    let time: TimeInterval
}

protocol SpeechProvider {
    /// Synthesises one chunk, delivering PCM buffers as soon as they arrive.
    ///
    /// `onMark` reports word boundaries where the provider knows them. Most do
    /// not, so callers must cope with receiving none; ChunkLoader estimates in
    /// that case.
    func synthesize(_ text: String,
                    onBuffer: @escaping (AVAudioPCMBuffer) async -> Void,
                    onMark: @escaping (SpeechMark) -> Void) async throws
}

extension SpeechProvider {
    /// For callers that only want audio.
    func synthesize(_ text: String, onBuffer: @escaping (AVAudioPCMBuffer) async -> Void) async throws {
        try await synthesize(text, onBuffer: onBuffer, onMark: { _ in })
    }
}

enum PCM {
    /// Wraps raw little-endian float32 mono samples into a buffer.
    static func bufferFromFloat32(_ data: Data, sampleRate: Double) -> AVAudioPCMBuffer? {
        let frames = data.count / 4
        guard frames > 0,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(frames)
        data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Float.self)
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: frames)
        }
        return buffer
    }

    /// Wraps raw little-endian int16 mono samples into a float buffer.
    static func bufferFromInt16(_ data: Data, sampleRate: Double) -> AVAudioPCMBuffer? {
        let frames = data.count / 2
        guard frames > 0,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(frames)
        data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Int16.self)
            let dst = buffer.floatChannelData![0]
            for i in 0..<frames { dst[i] = Float(Int16(littleEndian: src[i])) / 32768.0 }
        }
        return buffer
    }
}
