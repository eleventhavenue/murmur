import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private let session = ReaderSession()
    private lazy var panel = ReaderPanel(session: session)
    private lazy var lens = LensController()
    private var settingsWindow: SettingsWindow?
    private var statusItem: NSStatusItem!

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:_:)),
                                                     forEventClass: AEEventClass(kInternetEventClass),
                                                     andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()
        HotKeyManager.shared.onPress = { [weak self] in self?.hotKeyPressed() }
        HotKeyManager.shared.register(settings.hotKey)
        settings.$hotKey.dropFirst().sink { HotKeyManager.shared.register($0) }.store(in: &bag)
        session.$phase.sink { [weak self] phase in
            if phase == .finished { self?.panel.scheduleAutoDismiss() }
        }.store(in: &bag)
        lens.onPick = { [weak self] text in self?.read(text, from: "Lens") }
        lens.onCancel = { }

        if !settings.hasOnboarded || !AX.isTrusted {
            settings.hasOnboarded = true
            showSettings()
            if !AX.isTrusted { AX.requestTrust() }
        }
    }
    private var bag = Set<AnyCancellable>()

    // MARK: Actions

    private func hotKeyPressed() {
        if lens.isActive { lens.cancel(); return }

        // Without Accessibility there is no way to see a selection. Murmur used
        // to quietly read the clipboard instead, which meant pressing the
        // hotkey on highlighted text played something copied hours earlier and
        // gave no clue why. Say what is wrong instead.
        guard AX.isTrusted else {
            session.present(error: "Murmur needs Accessibility access to see what you've highlighted.")
            panel.present()
            AX.requestTrust()
            return
        }

        Task { @MainActor in
            let selection = await SelectionCapture.capture()
            if let selection {
                if session.isActive, selection.text == session.originalText {
                    session.togglePlayPause()
                } else {
                    read(selection.text, from: selection.appName)
                }
            } else if session.isActive {
                session.togglePlayPause()
            } else if settings.lensFallback {
                panel.orderOut(nil)
                lens.begin()
            } else {
                // Deliberately does not fall back to the clipboard. The hotkey
                // means "read what I selected"; reading something else is worse
                // than doing nothing. "Read Clipboard" in the menu is explicit.
                session.present(error: "Nothing selected.")
                panel.present()
            }
        }
    }

    private func read(_ text: String, from app: String) {
        Log.info("read \(text.count) chars from \(app)")
        session.start(text: text, sourceApp: app)
        panel.present()
    }

    @objc private func readSelection() { hotKeyPressed() }
    @objc private func readClipboard() {
        if let clip = SelectionCapture.clipboardText(), !clip.isEmpty { read(clip, from: "Clipboard") }
    }
    @objc private func startLens() {
        guard AX.isTrusted else { showSettings(); return }
        panel.orderOut(nil)
        lens.begin()
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(settings: settings) { [weak self] sample in self?.read(sample, from: "Murmur") }
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: URL scheme  murmur://read?text=…  |  murmur://read?file=/path

    @objc private func handleURL(_ event: NSAppleEventDescriptor, _ reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              url.host == "read" else { return }
        let items = comps.queryItems ?? []
        if let path = items.first(where: { $0.name == "file" })?.value,
           let text = try? String(contentsOfFile: path, encoding: .utf8) {
            try? FileManager.default.removeItem(atPath: path)
            read(text, from: "Claude Code")
        } else if let text = items.first(where: { $0.name == "text" })?.value {
            read(text, from: "Link")
        }
    }

    // MARK: Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Murmur")
            image?.isTemplate = true
            button.image = image
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Read Selection", action: #selector(readSelection), keyEquivalent: "")
        menu.addItem(withTitle: "Read Clipboard", action: #selector(readClipboard), keyEquivalent: "")
        menu.addItem(withTitle: "Point & Read…", action: #selector(startLens), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Murmur", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }
}
