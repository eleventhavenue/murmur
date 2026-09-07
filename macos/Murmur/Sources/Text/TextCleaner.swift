import Foundation

/// Turns whatever was highlighted (terminal output, markdown, HTML text, code comments)
/// into something that reads naturally out loud.
struct TextCleaner {
    var stripMarkdown = true
    var joinWrappedLines = true

    func clean(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
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

    /// Bullets, numbered items, checkboxes and CLI prompt glyphs.
    static let listMarker = "(?:(?:[-*+•●○◦▪▸▹►‣⁃]|\\d+[.)])\\s+(?:\\[[ xX]\\]\\s*)?|[⏺⎿❯➜→]\\s*)"
    private static let listMarkerRegex = try! NSRegularExpression(pattern: "^\\s*" + listMarker)

    /// Re-flows hard-wrapped text (terminals, emails, PDFs) into paragraphs.
    private func joinLines(_ s: String) -> String {
        let lines = s.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var out = ""
        var paragraph = ""
        func flush() {
            if !paragraph.isEmpty { out += (out.isEmpty ? "" : "\n\n") + paragraph }
            paragraph = ""
        }
        for line in lines {
            if line.isEmpty { flush(); continue }
            let isListItem = Self.listMarkerRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
            if isListItem { flush(); paragraph = line; continue }
            if paragraph.isEmpty { paragraph = line; continue }
            let prevEndsSentence = paragraph.last.map { ".!?:;".contains($0) } ?? false
            let startsUpper = line.first.map { $0.isUppercase } ?? false
            // Short previous line that ended a sentence, next starts with a capital → probably a new block.
            if prevEndsSentence && startsUpper && paragraph.count < 60 {
                flush(); paragraph = line
            } else {
                paragraph += (paragraph.hasSuffix("-") ? "" : " ") + line
            }
        }
        flush()
        return out
    }

    private func regexReplace(_ s: String, _ pattern: String, _ template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return s }
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
}
