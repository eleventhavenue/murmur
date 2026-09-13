import AVFoundation

struct SpeechError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

import Foundation

/// Where one word starts, in characters into the chunk and in frames into its
/// audio. Frames rather than seconds, because the playback rate changes and the
/// player reports its position in the same source timeline.
struct SpeechMark {
    let range: NSRange
    let frame: AVAudioFramePosition
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
