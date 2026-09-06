import AppKit
import SwiftUI

/// "Point & read": a full-screen overlay that outlines whatever text block is under the cursor. Click to read it.
@MainActor
final class LensController {
    var onPick: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private var window: LensWindow?
    private var timer: Timer?
    private let model = LensModel()
    private var lastElement: AXUIElement?

    var isActive: Bool { window != nil }

    func begin() {
        guard !isActive else { return }
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main!
        let w = LensWindow(screen: screen, model: model)
        w.onClick = { [weak self] in self?.pick() }
        w.onEscape = { [weak self] in self?.cancel() }
        w.makeKeyAndOrderFront(nil)
        window = w
        model.reset()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.track() }
        }
        track()
    }

    func cancel() {
        end()
        onCancel?()
    }

    private func end() {
        timer?.invalidate(); timer = nil
        window?.orderOut(nil); window = nil
        lastElement = nil
    }

    private func track() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        model.cursor = CGPoint(x: mouse.x - window.frame.minX, y: mouse.y - window.frame.minY)
        // Temporarily let the hit-test pass through us.
        window.ignoresMouseEvents = true
        defer { window.ignoresMouseEvents = false }
        guard let element = AX.element(at: mouse) else { model.highlight = nil; model.preview = ""; return }
        if let last = lastElement, CFEqual(last, element) { return }
        lastElement = element
        let target = readableTarget(element)
        if let frame = AX.frame(target) {
            model.highlight = CGRect(x: frame.minX - window.frame.minX, y: frame.minY - window.frame.minY,
                                     width: frame.width, height: frame.height)
        } else {
            model.highlight = nil
        }
        let text = AX.readableText(target) ?? ""
        model.preview = String(text.replacingOccurrences(of: "\n", with: " ").prefix(90))
    }

    /// Walk up from tiny leaf nodes to a paragraph-sized parent so a click reads the whole block.
    private func readableTarget(_ element: AXUIElement) -> AXUIElement {
        var current = element
        for _ in 0..<4 {
            let text = AX.readableText(current) ?? ""
            if text.count >= 40 { return current }
            guard let parent = AX.parent(current) else { return current }
            let role = AX.role(parent)
            if ["AXWindow", "AXApplication", "AXScrollArea", "AXWebArea", "AXSheet"].contains(role) { return current }
            let parentText = AX.readableText(parent) ?? ""
            if parentText.count > 2500 { return current }
            current = parent
        }
        return current
    }

    private func pick() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        window.ignoresMouseEvents = true
        let element = AX.element(at: mouse)
        window.ignoresMouseEvents = false
        let text = element.flatMap { AX.readableText(readableTarget($0)) } ?? ""
        end()
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onCancel?() } else { onPick?(text) }
    }
}

@MainActor
final class LensModel: ObservableObject {
    @Published var highlight: CGRect?
    @Published var cursor: CGPoint = .zero
    @Published var preview = ""
    func reset() { highlight = nil; preview = "" }
}

final class LensWindow: NSPanel {
    var onClick: (() -> Void)?
    var onEscape: (() -> Void)?

    init(screen: NSScreen, model: LensModel) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        acceptsMouseMovedEvents = true
        contentView = NSHostingView(rootView: LensView(model: model))
    }

    override var canBecomeKey: Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
    override func resetCursorRects() {
        contentView?.addCursorRect(contentView!.bounds, cursor: .crosshair)
    }
}

struct LensView: View {
    @ObservedObject var model: LensModel

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.04)
                if let r = model.highlight {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.accent.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2))
                        .frame(width: r.width + 8, height: r.height + 8)
                        .position(x: r.midX, y: geo.size.height - r.midY)
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: r)
                }
                label
                    .position(labelPosition(in: geo.size))
                    .animation(.easeOut(duration: 0.08), value: model.cursor)
            }
        }
        .ignoresSafeArea()
    }

    private var label: some View {
        HStack(spacing: 10) {
            Image(systemName: "cursorarrow.click.2").font(.system(size: 12, weight: .medium))
            Text(model.preview.isEmpty ? "Point at any text · click to read · esc to cancel" : model.preview)
                .lineLimit(1)
                .font(Theme.ui(12))
        }
        .foregroundStyle(Theme.surfaceSolid)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Theme.ink))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .frame(maxWidth: 420)
        .fixedSize()
    }

    private func labelPosition(in size: CGSize) -> CGPoint {
        let x = min(max(model.cursor.x + 150, 180), size.width - 180)
        let y = size.height - model.cursor.y + 34
        return CGPoint(x: x, y: min(y, size.height - 30))
    }
}
