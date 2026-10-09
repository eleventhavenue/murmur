import AppKit
import SwiftUI

final class OnboardingWindow: NSWindow {
    init(settings: Settings, session: ReaderSession, onTest: @escaping (String) -> Void, onFinish: @escaping () -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
                   styleMask: [.titled, .closable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        title = "Welcome to Murmur"
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: OnboardingView(settings: settings, session: session, onTest: onTest, onFinish: onFinish))
        center()
    }
}
