import AppKit
import SwiftUI

final class MainWindow: NSWindow {
    private let model: PageModel

    final class PageModel: ObservableObject { @Published var page: MainPage = .home }

    init(settings: Settings, session: ReaderSession, onRead: @escaping (String, String) -> Void) {
        model = PageModel()
        super.init(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        title = "Murmur"
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isReleasedWhenClosed = false
        minSize = NSSize(width: 820, height: 560)
        contentView = NSHostingView(rootView: Host(model: model, settings: settings, session: session, onRead: onRead))
        center()
        setFrameAutosaveName("MurmurMain")
    }

    func show(_ page: MainPage) { model.page = page }

    private struct Host: View {
        @ObservedObject var model: PageModel
        let settings: Settings
        let session: ReaderSession
        let onRead: (String, String) -> Void
        var body: some View { MainView(settings: settings, session: session, page: $model.page, onRead: onRead) }
    }
}
