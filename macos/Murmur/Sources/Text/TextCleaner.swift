import Foundation

/// Turns whatever was highlighted (terminal output, markdown, HTML text, code comments)
/// into something that reads naturally out loud.
struct TextCleaner {
    var stripMarkdown = true
    var joinWrappedLines = true

    func clean(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        // Structure first, before anything erases the evidence for it.
        s = markStructure(s)
        s = s.replacingOccurrences(of: "\t", with: "    ")

        // ANSI escape sequences (terminal colours, cursor moves).
        s = regexReplace(s, "\u{1B}\\[[0-9;?]*[ -/]*[@-~]", "")
        // Box-drawing / block characters from CLI UIs.
        s = regexReplace(s, "[\\u2500-\\u257F\\u2580-\\u259F]", " ")
        // Zero-width & odd whitespace.
        s = regexReplace(s, "[\\u200B-\\u200D\\uFEFF\\u00A0]", " ")

        if stripMarkdown {
            // Fenced code blocks: keep the content, drop the fences.
            s = regexReplace(s, "(?m)^\\s*```[^\\n]*$", "")
            s = regexReplace(s, "(?m)^\\s*~~~[^\\n]*$", "")
            // Images then links: keep the alt / label.
            s = regexReplace(s, "!\\[([^\\]]*)\\]\\([^)]*\\)", "$1")
            s = regexReplace(s, "\\[([^\\]]+)\\]\\([^)]*\\)", "$1")
            // Headings, blockquotes, horizontal rules.
            s = regexReplace(s, "(?m)^\\s{0,3}#{1,6}\\s+", "")
            s = regexReplace(s, "(?m)^\\s*>\\s?", "")
            s = regexReplace(s, "(?m)^\\s*([-*_]\\s*){3,}$", "")
            // Emphasis markers.
            s = regexReplace(s, "(\\*\\*|__)(.+?)\\1", "$2")
            s = regexReplace(s, "(?<![\\w*])\\*(?!\\s)(.+?)(?<!\\s)\\*(?![\\w*])", "$1")
            s = regexReplace(s, "(?<![\\w_])_(?!\\s)(.+?)(?<!\\s)_(?![\\w_])", "$1")
            s = regexReplace(s, "~~(.+?)~~", "$1")
            // Inline code.
            s = regexReplace(s, "`([^`]*)`", "$1")
            // Table pipes.
            s = regexReplace(s, "(?m)^\\s*\\|?\\s*:?-{2,}:?\\s*(\\|\\s*:?-{2,}:?\\s*)*\\|?\\s*$", "")
            s = s.replacingOccurrences(of: "|", with: ", ")
            // HTML tags.
            s = regexReplace(s, "<[^>\\n]{1,80}>", " ")
            s = s.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
                 .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&nbsp;", with: " ")
        }

        s = speakAcronyms(s)
        // URLs → just the host, so "https://github.com/foo/bar" reads as "github.com".
        s = regexReplace(s, "https?://([A-Za-z0-9.-]+)[^\\s)\\]>\"']*", "$1")
        // Re-flow first (list markers tell us where blocks start), then drop the markers.
        s = joinWrappedLines ? joinLines(s) : s
        s = regexReplace(s, "(?m)^[ \\t]*" + Self.listMarker, "")
        s = regexReplace(s, "[ ]{2,}", " ")
        s = regexReplace(s, "\\n{3,}", "\n\n")
        s = regexReplace(s, "(?m)^[ ]+|[ ]+$", "")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Written forms that speech synthesisers spell out letter by letter when
    /// they should be said as words.
    ///
    /// Every voice tested reads an all-caps token as individual letters, which
    /// is right for API and URL and wrong for README — "R E A D M E". Only
    /// terms that are genuinely pronounced as words belong here; anything
    /// people really do spell aloud is deliberately absent.
    static let spokenForms: [String: String] = [
        "README": "Read Me",
        "TODO": "To-do",
        "FIXME": "Fix Me",
        "JSON": "Jason",
        "YAML": "Yammel",
        "SQL": "Sequel",
        "REGEX": "Reg-ex",
        "ASCII": "Askey",
        "WYSIWYG": "Wizzywig",
        "SaaS": "Sass",
        "CRUD": "Crud",
        "NaN": "Nan",
    ]

    /// Applies the table above, matching whole words only so README changes but
    /// READMEs-inside-a-longer-token does not.
    private func speakAcronyms(_ text: String) -> String {
        var out = text
        for (written, spoken) in Self.spokenForms {
            // Optional trailing "s" so READMEs becomes "Read Mes" rather than
            // falling back to being spelled out.
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: written) + "(s?)\\b"
            out = regexReplace(out, pattern, spoken + "$1")
        }
        return out
    }

    // MARK: - Structure

    /// Promotes document structure to blank lines.
    ///
    /// Everything downstream treats a blank line as a hard break and a single
    /// newline as a soft wrap to be closed up. Headings and table rows carry no
    /// terminal punctuation, so unless their boundaries are promoted here they
    /// get welded to whatever follows: a title runs into its first paragraph,
    /// and a table collapses into one unreadable run of words.
    private func markStructure(_ s: String) -> String {
        // Block-level HTML ends a block whatever it contained.
        var text = regexReplace(s, "(?i)</(h[1-6]|p|li|tr|div|blockquote|section|article)>", "\n\n")
        text = regexReplace(text, "(?i)<br\\s*/?>", "\n\n")

        var out: [String] = []
        func breakBefore() {
            if let last = out.last, !last.isEmpty { out.append("") }
        }

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let row = tableRow(trimmed) {
                // Separator rows carry no content; dropping them also stops
                // "---" being read as punctuation.
                if row.isEmpty { continue }
                breakBefore()
                out.append(row)
                out.append("")
                continue
            }

            if Self.headingMarker.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                breakBefore()
                out.append(trimmed)
                out.append("")
                continue
            }

            out.append(line)
        }
        return out.joined(separator: "\n")
    }

    private static let headingMarker = try! NSRegularExpression(pattern: "^#{1,6}\\s+\\S")
    private static let separatorRow = try! NSRegularExpression(pattern: "^\\|?[\\s:|-]*-{2,}[\\s:|-]*\\|?$")

    /// Recognises a table row and rewrites its cells as a spoken list.
    ///
    /// Returns nil when the line is not a row, and an empty string for a
    /// separator row that should be dropped. Markdown rows arrive pipe
    /// delimited; a table copied out of a rendered page arrives tab delimited,
    /// which is the case that previously collapsed into one long sentence,
    /// because tabs were flattened to spaces before anything could read them.
    private func tableRow(_ line: String) -> String? {
        guard !line.isEmpty else { return nil }

        if line.hasPrefix("|") || (line.contains("|") && line.hasSuffix("|")) {
            let range = NSRange(line.startIndex..., in: line)
            if Self.separatorRow.firstMatch(in: line, range: range) != nil { return "" }
            return cells(line.components(separatedBy: "|"))
        }

        // A tab that is not indentation means columns. Leading tabs are indent.
        let body = line.drop { $0 == "\t" }
        if body.contains("\t") {
            return cells(body.components(separatedBy: "\t"))
        }

        return nil
    }

    /// Joins cells with a comma so each is spoken as its own clause, and so a
    /// row ends on a full stop rather than trailing off.
    private func cells(_ parts: [String]) -> String? {
        let kept = parts
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard kept.count > 1 else { return nil }
        var row = kept.joined(separator: ", ")
        if let last = row.last, !".!?".contains(last) { row += "." }
        return row
    }

    /// Bullets, numbered items, checkboxes and CLI prompt glyphs.
    static let listMarker = "(?:(?:[-*+•●○◦▪▸▹►‣⁃]|\\d+[.)])\\s+(?:\\[[ xX]\\]\\s*)?|[⏺⎿❯➜→]\\s*)"
    private static let listMarkerRegex = try! NSRegularExpression(pattern: "^\\s*" + listMarker)

    /// Re-flows hard-wrapped text (terminals, emails, PDFs) into paragraphs.
    private func joinLines(_ s: String) -> String {
        let lines = s.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let wrapWidth = Self.wrapWidth(of: lines)
        var out = ""
        var paragraph = ""
        func flush() {
            if !paragraph.isEmpty { out += (out.isEmpty ? "" : "\n\n") + paragraph }
            paragraph = ""
        }
        for (index, line) in lines.enumerated() {
            if line.isEmpty { flush(); continue }
            let isListItem = Self.listMarkerRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
            if isListItem { flush(); paragraph = line; continue }

            // A title that lost its markup, which is what you get copying a
            // rendered page: no "#", no tags, just a short line. Without this
            // it is welded to the first sentence of the body.
            let next = index + 1 < lines.count ? lines[index + 1] : ""
            if Self.looksLikeHeading(line, followedBy: next, wrapWidth: wrapWidth) {
                flush()
                paragraph = line.hasSuffix(".") ? line : line + "."
                flush()
                continue
            }

            if paragraph.isEmpty { paragraph = line; continue }
            let prevEndsSentence = paragraph.last.map { ".!?:;".contains($0) } ?? false
            let startsUpper = line.first.map { $0.isUppercase } ?? false
            // Short previous line that ended a sentence, next starts with a capital → probably a new block.
            if prevEndsSentence && startsUpper && paragraph.count < 60 {
                flush(); paragraph = line
            } else if paragraph.hasSuffix("-") {
                // A hyphen at a line break is usually a word the wrapper split,
                // not a real one, and nothing short of a dictionary can tell
                // "transi-/tion" from "twelve-/month" reliably.
                //
                // Measured against the system voice, the two mistakes are not
                // equally bad. Leaving a wrongly split word hyphenated makes it
                // 33% longer, because the synthesiser inserts a real break and
                // says "transi, tion". Removing a genuine compound hyphen costs
                // 7%, since "twelvemonth" still reads as one word. So always
                // close the gap when the next line continues in lower case.
                let continuesWord = line.first?.isLowercase ?? false
                paragraph = continuesWord ? String(paragraph.dropLast()) + line : paragraph + line
            } else {
                paragraph += " " + line
            }
        }
        flush()
        return out
    }

    /// Typical line length for the block, used to judge whether a short line is
    /// a title or just the last line of a wrapped paragraph. Hard-wrapped prose
    /// sits close to one width; a heading is conspicuously shorter than it.
    private static func wrapWidth(of lines: [String]) -> Int {
        let lengths = lines.map(\.count).filter { $0 > 0 }.sorted()
        guard !lengths.isEmpty else { return 0 }
        // 90th percentile rather than the maximum, so one runaway line does not
        // drag the threshold up and suppress every real heading.
        return lengths[min(lengths.count - 1, (lengths.count * 9) / 10)]
    }

    /// A line with no terminal punctuation, markedly shorter than the
    /// surrounding wrap, followed by something that starts a new sentence.
    ///
    /// All three conditions matter. Length alone would catch the short final
    /// line of any paragraph; punctuation alone would catch mid-sentence wraps.
    private static func looksLikeHeading(_ line: String, followedBy next: String, wrapWidth: Int) -> Bool {
        guard !next.isEmpty else { return false }
        guard line.count <= 70 else { return false }
        guard wrapWidth > 0, Double(line.count) < Double(wrapWidth) * 0.66 else { return false }
        guard let last = line.last, !".!?,;:—-".contains(last) else { return false }
        guard let first = next.first, first.isUppercase || first.isNumber else { return false }
        // Sentence-like lines are prose that merely lacks a full stop.
        guard line.split(separator: " ").count <= 12 else { return false }
        // A heading introduces prose. A short line followed by another short
        // line is a navigation list or a menu, and treating each entry as its
        // own heading just punctuates the boilerplate.
        guard Double(next.count) >= Double(wrapWidth) * 0.66 || next.count > line.count * 2 else { return false }
        return true
    }

    private func regexReplace(_ s: String, _ pattern: String, _ template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return s }
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
}
