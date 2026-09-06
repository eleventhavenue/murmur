import AppKit

/// Grabs the highlighted text in whatever app is frontmost.
/// 1. Accessibility (instant, no clipboard involvement)  2. ⌘C with clipboard restore (Chrome, Electron, VS Code…)
enum SelectionCapture {
    struct Result {
        let text: String
        let appName: String
    }

    static func capture() async -> Result? {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        if let text = viaAccessibility(), !text.isEmpty { return Result(text: text, appName: appName) }
        if let text = await viaClipboard(), !text.isEmpty { return Result(text: text, appName: appName) }
        return nil
    }

    static func viaAccessibility() -> String? {
        guard AX.isTrusted else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        guard let focused: AXUIElement = AX.attribute(systemWide, kAXFocusedUIElementAttribute) else { return nil }
        if let s = AX.string(focused, kAXSelectedTextAttribute) { return s }
        // Some apps only expose selection on the window's focused element.
        if let app = NSWorkspace.shared.frontmostApplication {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            if let el: AXUIElement = AX.attribute(appElement, kAXFocusedUIElementAttribute),
               let s = AX.string(el, kAXSelectedTextAttribute) { return s }
        }
        return nil
    }

    static func viaClipboard() async -> String? {
        guard AX.isTrusted else { return nil }
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot(pasteboard)
        let before = pasteboard.changeCount

        try? await Task.sleep(nanoseconds: 40_000_000)
        postCommandC()

        var changed = false
        for _ in 0..<15 {
            try? await Task.sleep(nanoseconds: 25_000_000)
            if pasteboard.changeCount != before { changed = true; break }
        }
        let text = changed ? pasteboard.string(forType: .string) : nil
        if changed {
            try? await Task.sleep(nanoseconds: 60_000_000)
            snapshot.restore(to: pasteboard)
        }
        return text
    }

    private static func postCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    static func clipboardText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}

/// Copies the clipboard's items so we can put them back after borrowing ⌘C.
private struct ClipboardSnapshot {
    private var items: [[NSPasteboard.PasteboardType: Data]] = []

    init(_ pasteboard: NSPasteboard) {
        for item in pasteboard.pasteboardItems ?? [] {
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { dict[type] = data } }
            if !dict.isEmpty { items.append(dict) }
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restored: [NSPasteboardItem] = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}
