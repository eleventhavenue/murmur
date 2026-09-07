import AVFoundation

/// Ranks the system voices so Murmur picks a good one and never a joke one.
///
/// macOS ships three lineages under one API, and `AVSpeechSynthesisVoice.quality`
/// cannot tell them apart:
///
///   com.apple.voice.{premium,enhanced,compact}  the modern Siri-lineage voices
///   com.apple.eloquence.*                       DECtalk-era, robotic
///   com.apple.speech.synthesis.voice.*          legacy, and where the novelty
///                                               voices live (Zarvox, Bubbles,
///                                               Boing, Bells, Cellos…)
///
/// Every one of those reports quality `.default`, so sorting on quality alone
/// leaves 41 voices tied on a stock Mac and the winner is whatever order the
/// system happened to return. That is how "best available voice" could pick
/// Bubbles. Ranking on the identifier prefix instead makes the choice both
/// deterministic and sane.
enum VoiceCatalog {

    enum Tier: Int, Comparable {
        case novelty = 0      // legacy + novelty, never chosen automatically
        case eloquence = 1    // robotic but intelligible
        case superCompact = 2
        case compact = 3
        case enhanced = 4
        case premium = 5

        static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }

        var label: String {
            switch self {
            case .premium: return "Premium"
            case .enhanced: return "Enhanced"
            case .compact: return "Compact"
            case .superCompact: return "Compact"
            case .eloquence: return "Eloquence"
            case .novelty: return "Novelty"
            }
        }
    }

    static func tier(of voice: AVSpeechSynthesisVoice) -> Tier {
        let id = voice.identifier
        if id.contains("com.apple.voice.premium") { return .premium }
        if id.contains("com.apple.voice.enhanced") { return .enhanced }
        if id.contains("com.apple.voice.super-compact") { return .superCompact }
        if id.contains("com.apple.voice.compact") { return .compact }
        if id.hasPrefix("com.apple.eloquence") { return .eloquence }
        if id.hasPrefix("com.apple.speech.synthesis.voice") { return .novelty }
        // Unknown lineage: trust the system's own quality rating.
        switch voice.quality {
        case .premium: return .premium
        case .enhanced: return .enhanced
        default: return .compact
        }
    }

    /// English voices worth offering, best first. Novelty voices are excluded.
    static func selectable() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && tier(of: $0) > .novelty }
            .sorted { a, b in
                let (ta, tb) = (tier(of: a), tier(of: b))
                if ta != tb { return ta > tb }
                // Stable tie-break so the list, and the default, never shuffle.
                if a.language != b.language { return a.language < b.language }
                return a.name < b.name
            }
    }

    /// The voice used when the user has not chosen one. Deterministic.
    static func best() -> AVSpeechSynthesisVoice? {
        selectable().first
            ?? AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("en") }
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// True when nothing better than a compact voice is installed, which is the
    /// stock state of every Mac and the reason Murmur sounds robotic by default.
    static var lacksHighQualityVoice: Bool {
        !selectable().contains { tier(of: $0) >= .enhanced }
    }

    static func display(_ voice: AVSpeechSynthesisVoice) -> String {
        // Apple already suffixes premium and enhanced names, so avoid "Zoe
        // (Premium) · Premium".
        let t = tier(of: voice)
        let name = voice.name
        let suffix = name.contains("(") ? "" : " · \(t.label)"
        return "\(name)\(suffix) · \(voice.language)"
    }

    /// Opens System Settings where the better voices are downloaded.
    static func openVoiceDownloads() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?SpokenContent")
        if let url { NSWorkspace.shared.open(url) }
    }
}

import AppKit
