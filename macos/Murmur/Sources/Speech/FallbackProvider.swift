import AVFoundation
import Foundation

/// Tries the voice the user chose, and if it cannot be reached, speaks with the
/// built-in system voice instead of failing.
///
/// This is what makes Murmur usable the moment it launches. The local engine
/// lives in a Docker container that is not running after a reboot, and a cloud
/// voice needs a network. Neither should turn a hotkey press into an error
/// when a perfectly good voice is sitting on the machine. The reading goes
/// ahead; the player says which voice it used and why.
struct FallbackProvider: SpeechProvider {
    let primary: SpeechProvider
    let primaryName: String
    let fallback: SpeechProvider
    /// Called once, on the main actor, the first time a reading falls back.
    let onFallback: @MainActor (String) -> Void

    func synthesize(_ text: String,
                    onBuffer: @escaping (AVAudioPCMBuffer) async -> Void,
                    onMark: @escaping (SpeechMark) -> Void) async throws {
        var delivered = false
        do {
            try await primary.synthesize(text, onBuffer: { buffer in
                delivered = true
                await onBuffer(buffer)
            }, onMark: onMark)
        } catch where !delivered && Self.isReachabilityFailure(error) {
            // Only fall back when nothing was heard yet. Switching voices
            // mid-sentence would be worse than the error.
            let reason = Self.describe(error)
            await onFallback("\(primaryName) isn't reachable (\(reason)). Using the system voice.")
            try await fallback.synthesize(text, onBuffer: onBuffer, onMark: onMark)
        }
    }

    /// Connection-shaped failures only. A rejected API key or a server-side
    /// error is something the user needs to see, not paper over.
    private static func isReachabilityFailure(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return [NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost,
                    NSURLErrorNotConnectedToInternet, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed]
                .contains(ns.code)
        }
        if let speech = error as? SpeechError {
            let m = speech.message.lowercased()
            return m.contains("connect") || m.contains("timed out") || m.contains("unreachable")
        }
        return false
    }

    private static func describe(_ error: Error) -> String {
        let ns = error as NSError
        switch ns.code {
        case NSURLErrorTimedOut: return "timed out"
        case NSURLErrorNotConnectedToInternet: return "offline"
        default: return "not running"
        }
    }
}
