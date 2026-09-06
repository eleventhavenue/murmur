import AppKit
import Foundation

/// Small command-line surface so scripts (and Claude Code hooks) can hand text to the running app.
enum CLI {
    static func run(arguments: [String]) -> Bool {
        guard let command = arguments.first else { return false }
        switch command {
        case "read":
            let rest = arguments.dropFirst()
            let text: String
            if rest.isEmpty || rest.first == "-" {
                text = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
            } else {
                text = rest.joined(separator: " ")
            }
            send(text)
            return true
        case "--hook", "hook":
            // Claude Code "Stop" hook: JSON on stdin with transcript_path. Reads the last assistant reply aloud.
            let data = FileHandle.standardInput.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let path = json["transcript_path"] as? String,
                  let text = lastAssistantText(transcriptPath: path) else { return true }
            send(text)
            return true
        case "-h", "--help", "help":
            print("""
            murmur read "text"        read text aloud
            echo text | murmur read - read stdin aloud
            murmur --hook             Claude Code Stop hook (reads last reply)
            """)
            return true
        default:
            return false
        }
    }

    static func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("murmur-\(UUID().uuidString).txt")
        try? trimmed.write(to: file, atomically: true, encoding: .utf8)
        var comps = URLComponents()
        comps.scheme = "murmur"
        comps.host = "read"
        comps.queryItems = [URLQueryItem(name: "file", value: file.path)]
        if let url = comps.url {
            NSWorkspace.shared.open(url)
            // Give Launch Services a moment to deliver before this process exits.
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
    }

    static func lastAssistantText(transcriptPath: String) -> String? {
        guard let content = try? String(contentsOfFile: transcriptPath, encoding: .utf8) else { return nil }
        // Only keep the trailing run of assistant text blocks (after the last user message).
        var trailing: [String] = []
        for line in content.split(separator: "\n").reversed() {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let type = obj["type"] as? String
            if type == "user" {
                let msg = obj["message"] as? [String: Any]
                let c = msg?["content"]
                // Tool results also arrive as "user" lines; skip those, stop at real user text.
                if let arr = c as? [[String: Any]], arr.allSatisfy({ $0["type"] as? String == "tool_result" }) { continue }
                break
            }
            if type == "assistant", let message = obj["message"] as? [String: Any],
               let blocks = message["content"] as? [[String: Any]] {
                let block = blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined(separator: "\n")
                if !block.isEmpty { trailing.insert(block, at: 0) }
            }
        }
        let result = trailing.joined(separator: "\n\n")
        return result.isEmpty ? nil : result
    }
}
