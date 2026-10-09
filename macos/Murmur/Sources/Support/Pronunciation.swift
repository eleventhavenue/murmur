import Foundation

/// The user's own pronunciation dictionary, layered over TextCleaner's built-in
/// table. "Clerk" → "Clark", a product name the voice mangles, a colleague's
/// name. Matched as whole words, case-sensitively, so an entry for "AI" does
/// not touch "said".
@MainActor
final class Pronunciation: ObservableObject {
    static let shared = Pronunciation()
    private let d = UserDefaults.standard
    private let key = "pronunciation.entries"

    struct Entry: Identifiable, Codable, Equatable {
        var id = UUID()
        var written: String
        var spoken: String
    }

    @Published private(set) var entries: [Entry] {
        didSet { save() }
    }

    private init() {
        if let data = d.data(forKey: key), let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
    }

    var asMap: [String: String] {
        Dictionary(entries.filter { !$0.written.isEmpty && !$0.spoken.isEmpty }
                         .map { ($0.written, $0.spoken) }, uniquingKeysWith: { _, last in last })
    }

    func add(written: String, spoken: String) {
        let w = written.trimmingCharacters(in: .whitespaces), s = spoken.trimmingCharacters(in: .whitespaces)
        guard !w.isEmpty, !s.isEmpty else { return }
        if let i = entries.firstIndex(where: { $0.written == w }) { entries[i].spoken = s }
        else { entries.append(Entry(written: w, spoken: s)) }
    }

    func update(_ entry: Entry) {
        if let i = entries.firstIndex(where: { $0.id == entry.id }) { entries[i] = entry }
    }

    func remove(_ entry: Entry) { entries.removeAll { $0.id == entry.id } }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) { d.set(data, forKey: key) }
    }
}
