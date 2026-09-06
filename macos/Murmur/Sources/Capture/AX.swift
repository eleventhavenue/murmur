import AppKit
import ApplicationServices

/// Thin helpers over the Accessibility API.
enum AX {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func requestTrust() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openPrivacyPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    static func string(_ element: AXUIElement, _ name: String) -> String? {
        let s: String? = attribute(element, name)
        guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }

    static func role(_ element: AXUIElement) -> String { string(element, kAXRoleAttribute) ?? "" }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        let c: [AXUIElement]? = attribute(element, kAXChildrenAttribute)
        return c ?? []
    }

    static func parent(_ element: AXUIElement) -> AXUIElement? {
        attribute(element, kAXParentAttribute)
    }

    /// Frame in Cocoa (bottom-left origin) screen coordinates.
    static func frame(_ element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success else { return nil }
        var pos = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: pos.x, y: primaryHeight - pos.y - size.height, width: size.width, height: size.height)
    }

    static func element(at cocoaPoint: CGPoint) -> AXUIElement? {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var element: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(),
                                                      Float(cocoaPoint.x), Float(primaryHeight - cocoaPoint.y), &element)
        return status == .success ? element : nil
    }

    /// Readable text for an element: its own value/title, else its descendants' static text.
    static func readableText(_ element: AXUIElement, limit: Int = 8000) -> String? {
        let role = role(element)
        let textRoles: Set<String> = ["AXStaticText", "AXTextArea", "AXTextField", "AXHeading", "AXLink", "AXButton", "AXCell", "AXMenuItem"]
        if textRoles.contains(role) || role.isEmpty {
            if let v = string(element, kAXValueAttribute) { return trim(v, limit: limit) }
            if let v = string(element, kAXTitleAttribute) { return trim(v, limit: limit) }
            if let v = string(element, kAXDescriptionAttribute) { return trim(v, limit: limit) }
        }
        var parts: [String] = []
        var budget = 400
        collect(element, into: &parts, budget: &budget, depth: 0)
        let joined = parts.joined(separator: "\n")
        return joined.isEmpty ? nil : trim(joined, limit: limit)
    }

    private static func collect(_ element: AXUIElement, into parts: inout [String], budget: inout Int, depth: Int) {
        guard budget > 0, depth < 12 else { return }
        budget -= 1
        let r = role(element)
        if r == "AXStaticText" || r == "AXHeading" || r == "AXTextArea" || r == "AXTextField" {
            if let v = string(element, kAXValueAttribute) { parts.append(v); return }
        }
        if r == "AXLink" || r == "AXButton", let t = string(element, kAXTitleAttribute) { parts.append(t); return }
        for child in children(element) { collect(child, into: &parts, budget: &budget, depth: depth + 1) }
    }

    private static func trim(_ s: String, limit: Int) -> String {
        guard s.count > limit else { return s }
        // Terminals expose the entire scrollback; the newest text is at the end.
        return String(s.suffix(limit))
    }
}
