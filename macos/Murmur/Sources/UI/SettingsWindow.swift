import AppKit
import SwiftUI

final class SettingsWindow: NSWindow {
    init(settings: Settings, onTest: @escaping (String) -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 560, height: 760),
                   styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        title = "Murmur"
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: SettingsView(settings: settings, onTest: onTest))
        center()
    }
}
