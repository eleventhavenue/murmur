import AppKit
import SwiftUI

/// Floating, non-activating panel: shows up over whatever you're doing without stealing focus.
final class ReaderPanel: NSPanel {
    private let session: ReaderSession
    private var keyMonitor: Any?
    private var dismissWork: DispatchWorkItem?
    private var pinnedTop: CGFloat?
    private var host: NSHostingView<ReaderView>!

    init(session: ReaderSession) {
        self.session = session
        super.init(contentRect: NSRect(x: 0, y: 0, width: ReaderView.width, height: 200),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .none
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        host = NSHostingView(rootView: ReaderView(session: session, onClose: { [weak self] in self?.dismiss() }))
        host.sizingOptions = [.intrinsicContentSize]
        contentView = host

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isKeyWindow else { return event }
            return self.handle(event) ? nil : event
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func orderOut(_ sender: Any?) {
        fitTimer?.invalidate()
        fitTimer = nil
        super.orderOut(sender)
    }

    private var fitTimer: Timer?

    /// The SwiftUI ideal size, which is right even before the panel is on screen.
    private var contentSize: CGSize {
        let s = host.intrinsicContentSize
        return (s.width > 10 && s.height > 10) ? s : CGSize(width: ReaderView.width, height: 210)
    }

    /// Content grows and shrinks (expand, long sentences); keep the top edge pinned.
    private func fit() {
        let size = contentSize
        guard isVisible, let top = pinnedTop, abs(frame.height - size.height) > 0.5 else { return }
        let target = NSRect(x: frame.minX, y: top - size.height, width: size.width, height: size.height)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(target, display: true)
        }
    }

    func present() {
        dismissWork?.cancel()
        let size = contentSize
        fitTimer?.invalidate()
        fitTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in self?.fit() }
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let top = visible.maxY - 22
        let origin = NSPoint(x: visible.midX - size.width / 2, y: top - size.height)
        if !isVisible {
            pinnedTop = nil
            setFrame(NSRect(origin: NSPoint(x: origin.x, y: origin.y + 14), size: size), display: false)
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().alphaValue = 1
                animator().setFrame(NSRect(origin: origin, size: size), display: true)
            }, completionHandler: { [weak self] in
                guard let self else { return }
                self.pinnedTop = top
                self.fit()
            })
        } else {
            pinnedTop = frame.maxY
            orderFrontRegardless()
        }
    }

    func dismiss() {
        dismissWork?.cancel()
        fitTimer?.invalidate()
        fitTimer = nil
        session.stop()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }

    /// Auto-hide a beat after the last sentence, unless the pointer is resting on the panel.
    func scheduleAutoDismiss() {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.session.phase == .finished else { return }
            if self.frame.contains(NSEvent.mouseLocation) { self.scheduleAutoDismiss(); return }
            self.dismiss()
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }

    private func handle(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: dismiss(); return true                       // esc
        case 49: session.togglePlayPause(); return true       // space
        case 123: session.skip(-1); return true               // ←
        case 124: session.skip(1); return true                // →
        case 126: session.speed = min(3, (session.speed + 0.25)); return true
        case 125: session.speed = max(0.5, (session.speed - 0.25)); return true
        default: return false
        }
    }
}
