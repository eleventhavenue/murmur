import Foundation
import NaturalLanguage

struct TextChunk: Identifiable, Equatable {
    let id: Int
    let text: String
    let paragraph: Int
}

/// Splits cleaned text into sentence-sized chunks. Small chunks = fast first audio + precise highlighting.
enum Chunker {
    static let target = 240
    static let hardMax = 420

    static func chunks(for text: String) -> [TextChunk] {
        var result: [TextChunk] = []
        let paragraphs = text.components(separatedBy: "\n\n").map { $0.replacingOccurrences(of: "\n", with: " ") }
        for (p, para) in paragraphs.enumerated() {
            let trimmed = para.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            var buffer = ""
            for sentence in sentences(in: trimmed) {
                for piece in splitLong(sentence) {
                    if buffer.isEmpty { buffer = piece }
                    else if (buffer.count + piece.count + 1) <= target && buffer.count < 90 { buffer += " " + piece }
                    else { result.append(TextChunk(id: result.count, text: buffer, paragraph: p)); buffer = piece }
                }
            }
            if !buffer.isEmpty { result.append(TextChunk(id: result.count, text: buffer, paragraph: p)) }
        }
        return result
    }

    static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var out: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { out.append(s) }
            return true
        }
        return out.isEmpty ? [text] : out
    }

    private static func splitLong(_ sentence: String) -> [String] {
        guard sentence.count > hardMax else { return [sentence] }
        var pieces: [String] = []
        var current = ""
        for clause in sentence.components(separatedBy: ", ") {
            if current.isEmpty { current = clause }
            else if current.count + clause.count < hardMax { current += ", " + clause }
            else { pieces.append(current + ","); current = clause }
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }
}
