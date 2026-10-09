import Foundation

/// Reading statistics for the Home screen: words heard, time listened, streak.
///
/// Counts only. Nothing about *what* was read is kept, which is the line that
/// keeps Murmur's "your text never leaves your machine" promise honest even
/// against the machine's own disk.
@MainActor
final class Insights: ObservableObject {
    static let shared = Insights()
    private let d = UserDefaults.standard

    @Published private(set) var totalWords: Int
    @Published private(set) var totalSeconds: Double
    @Published private(set) var readings: Int
    @Published private(set) var streakDays: Int
    @Published private(set) var lastReadDay: String?

    private init() {
        totalWords = d.integer(forKey: "insights.words")
        totalSeconds = d.double(forKey: "insights.seconds")
        readings = d.integer(forKey: "insights.readings")
        streakDays = d.integer(forKey: "insights.streak")
        lastReadDay = d.string(forKey: "insights.lastDay")
    }

    /// Called when a reading finishes or is stopped partway.
    func record(words: Int, seconds: Double) {
        guard words > 0 else { return }
        totalWords += words
        totalSeconds += max(0, seconds)
        readings += 1

        let today = Self.dayKey(Date())
        if lastReadDay != today {
            let yesterday = Self.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
            streakDays = (lastReadDay == yesterday) ? streakDays + 1 : 1
            lastReadDay = today
        }

        d.set(totalWords, forKey: "insights.words")
        d.set(totalSeconds, forKey: "insights.seconds")
        d.set(readings, forKey: "insights.readings")
        d.set(streakDays, forKey: "insights.streak")
        d.set(lastReadDay, forKey: "insights.lastDay")
    }

    /// Minutes saved against reading silently at a typical 230 words a minute,
    /// versus listening at ~170. Shown as a gentle motivator, not a claim.
    var minutesListened: Int { Int((totalSeconds / 60).rounded()) }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
}
