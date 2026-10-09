import SwiftUI

/// The application window: a sidebar of a few pages, each doing one job.
///
/// Murmur is still a menu-bar app first. This window is where the stats,
/// the pronunciation dictionary and the integrations live, and it only
/// appears in the Dock while it is open.
struct MainView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var session: ReaderSession
    @Binding var page: MainPage
    let onRead: (String, String) -> Void

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Section {
                    ForEach(MainPage.allCases) { p in
                        Label(p.title, systemImage: p.symbol).tag(p)
                            .font(Theme.ui(13, page == p ? .medium : .regular))
                    }
                } header: {
                    Wordmark(size: 22).padding(.vertical, 10)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            Group {
                switch page {
                case .home: HomeView(settings: settings, session: session, onRead: onRead, go: { page = $0 })
                case .read: ReadView(onRead: onRead)
                case .pronunciation: PronunciationView()
                case .integrations: IntegrationsView(settings: settings)
                case .settings: SettingsView(settings: settings) { sample in onRead(sample, "Murmur") }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.surfaceSolid)
        }
        .navigationTitle("")
    }
}

enum MainPage: String, CaseIterable, Identifiable {
    case home, read, pronunciation, integrations, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return "Home"
        case .read: return "Read"
        case .pronunciation: return "Pronunciation"
        case .integrations: return "Integrations"
        case .settings: return "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .home: return "house"
        case .read: return "text.alignleft"
        case .pronunciation: return "character.book.closed"
        case .integrations: return "point.3.connected.trianglepath.dotted"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var session: ReaderSession
    @ObservedObject private var insights = Insights.shared
    @ObservedObject private var engine = LocalEngine.shared
    let onRead: (String, String) -> Void
    let go: (MainPage) -> Void
    @State private var trusted = AX.isTrusted
    private let poll = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Hey \(NSFullUserName().split(separator: " ").first.map(String.init) ?? "there"), highlight anything and press")
                        .font(Theme.display(32)).foregroundStyle(Theme.ink)
                    KeycapBadge(text: settings.hotKey.display, size: 24)
                }
                .padding(.top, 36)

                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) {
                        if !trusted { permissionCard }
                        statusCard
                        tryCard
                    }
                    insightsCard.frame(width: 260)
                }
            }
            .padding(.horizontal, 40).padding(.bottom, 40)
        }
        .onReceive(poll) { _ in trusted = AX.isTrusted }
        .task { await engine.refresh() }
    }

    private var permissionCard: some View {
        Card {
            HStack(spacing: 14) {
                StatusDot(on: false)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Accessibility is off").font(Theme.ui(15, .medium)).foregroundStyle(Theme.ink)
                    Text("Murmur can't see what you've highlighted until this is on.").font(Theme.ui(12)).foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                Pill(title: "Grant access") { AX.requestTrust(); AX.openPrivacyPane() }
            }
        }
    }

    private var statusCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Voice")
                HStack(spacing: 10) {
                    StatusDot(on: voiceReady)
                    Text(voiceSummary).font(Theme.ui(14, .medium)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button("Change") { go(.settings) }.buttonStyle(.plain).font(Theme.ui(12)).foregroundStyle(Theme.inkFaint)
                }
                if settings.provider == .localServer, !voiceReady {
                    Hint(text: engineHint)
                }
            }
        }
    }

    private var voiceReady: Bool {
        switch settings.provider {
        case .system: return true
        case .localServer: return engine.state == .running
        case .cloud: return !settings.licenseKey.isEmpty
        default: return !settings.activeKeyMissing
        }
    }

    private var voiceSummary: String {
        switch settings.provider {
        case .system: return "Apple · \(VoiceCatalog.best()?.name ?? "system voice")"
        case .localServer: return "Local engine · \(settings.localServerVoice.isEmpty ? "Kokoro" : settings.localServerVoice)"
        case .cloud: return "Murmur Cloud"
        case .cartesia: return "Cartesia"
        case .fish: return "Fish Audio"
        }
    }

    private var engineHint: String {
        switch engine.state {
        case .noDocker: return "Docker isn't running. Murmur is using Apple's voices until it is."
        case .pulling: return "Engine is still downloading. Apple's voices are standing in."
        case .starting, .checking: return "Engine is starting. Apple's voices are standing in."
        case .stopped: return "Engine is installed but stopped. It'll start on your next reading."
        default: return "Apple's voices are standing in until the engine is reachable."
        }
    }

    private var tryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Try it now")
                Text("Highlight this sentence with your mouse, then press \(settings.hotKey.display). A small player will appear at the top of your screen and start reading.")
                    .font(Theme.display(20)).foregroundStyle(Theme.ink).lineSpacing(3)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var insightsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                stat(value: insights.totalWords.formatted(), label: "words heard")
                stat(value: "\(insights.minutesListened)", label: "minutes listened")
                stat(value: "\(insights.streakDays)", label: insights.streakDays == 1 ? "day streak" : "day streak")
                Divider()
                Hint(text: "Counts only. Murmur never keeps what you read.")
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(value).font(Theme.display(34)).foregroundStyle(Theme.ink)
            Text(label).font(Theme.ui(13)).foregroundStyle(Theme.inkSoft)
        }
    }
}

// MARK: - Read (scratchpad)

struct ReadView: View {
    let onRead: (String, String) -> Void
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Read anything.").font(Theme.display(32)).foregroundStyle(Theme.ink).padding(.top, 36)
            Text("Paste or type, then press Read. Markdown, tables and code are cleaned up the same way as highlighted text.")
                .font(Theme.ui(14)).foregroundStyle(Theme.inkSoft)
            TextEditor(text: $text)
                .font(Theme.ui(14))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.well))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                .frame(minHeight: 260)
            HStack {
                Pill(title: "Read", disabled: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { onRead(text, "Scratchpad") }
                Pill(title: "Clear", prominent: false) { text = "" }
                Spacer()
                Text("\(text.split(separator: " ").count) words").font(Theme.ui(12)).foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 40).padding(.bottom, 40)
    }
}

// MARK: - Pronunciation

struct PronunciationView: View {
    @ObservedObject private var dict = Pronunciation.shared
    @State private var written = ""
    @State private var spoken = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pronunciation.").font(Theme.display(32)).foregroundStyle(Theme.ink).padding(.top, 36)
                Text("Teach Murmur how to say names and jargon. Matched as whole words, exactly as written. Murmur already says README as \"Read Me\" and JSON as \"Jason\"; this is for your own.")
                    .font(Theme.ui(14)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    TextField("Written, e.g. Clerk", text: $written).fieldStyle().frame(width: 220)
                    Image(systemName: "arrow.right").foregroundStyle(Theme.inkFaint)
                    TextField("Spoken, e.g. Clark", text: $spoken).fieldStyle().frame(width: 220)
                    Pill(title: "Add", disabled: written.isEmpty || spoken.isEmpty) {
                        dict.add(written: written, spoken: spoken); written = ""; spoken = ""
                    }
                }

                if dict.entries.isEmpty {
                    Hint(text: "No entries yet.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(dict.entries) { e in
                            HStack(spacing: 12) {
                                Text(e.written).font(Theme.ui(13, .medium)).foregroundStyle(Theme.ink).frame(width: 200, alignment: .leading)
                                Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(Theme.inkFaint)
                                Text(e.spoken).font(Theme.ui(13)).foregroundStyle(Theme.inkSoft)
                                Spacer()
                                Button { dict.remove(e) } label: { Image(systemName: "xmark").font(.system(size: 11)) }
                                    .buttonStyle(.plain).foregroundStyle(Theme.inkFaint)
                            }
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
                }

                Eyebrow(text: "Built in").padding(.top, 10)
                Text(TextCleaner.spokenForms.sorted { $0.key < $1.key }.map { "\($0.key) → \($0.value)" }.joined(separator: "   ·   "))
                    .font(Theme.ui(12)).foregroundStyle(Theme.inkFaint).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40).padding(.bottom, 40)
        }
    }
}

// MARK: - Integrations

struct IntegrationsView: View {
    @ObservedObject var settings: Settings
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Everything Murmur connects to.").font(Theme.display(32)).foregroundStyle(Theme.ink).padding(.top, 36)
                Text("Murmur is a reader with many inputs and many voices. Any of these can hand it text; any voice below can speak it.")
                    .font(Theme.ui(14)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)

                Eyebrow(text: "Ways in")
                integration("Highlight + \(settings.hotKey.display)", "Any app. Selection via Accessibility, with a clipboard copy as fallback for Electron apps.", ready: true)
                integration("Point & Read", "Press the shortcut with nothing selected, then click any block of text on screen.", ready: true)
                integration("Claude Code", "Hear every reply as it lands. A Stop hook pipes the last message to Murmur.", ready: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(SettingsView.hookSnippet).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.ink)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surfaceSolid))
                        Pill(title: copied ? "Copied" : "Copy snippet", prominent: false) {
                            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(SettingsView.hookSnippet, forType: .string)
                            copied = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        }
                        Hint(text: "Add it to ~/.claude/settings.json.")
                    }
                }
                integration("Command line", "murmur read \"text\"  ·  echo text | murmur read -", ready: true)
                integration("URL scheme", "open \"murmur://read?text=Hello\" from Shortcuts, Raycast, Alfred or any script.", ready: true)
                integration("Safari extension", "Read the page or selection from a toolbar button.", ready: false)
                integration("iPhone", "Share Sheet, Action Button, Siri. Same account, same voices.", ready: false)

                Eyebrow(text: "Voices").padding(.top, 10)
                integration("Apple voices", "Built in, offline, free. Download Premium ones for a big step up.", ready: true)
                integration("Local engine", "Kokoro via Docker, 27 voices, fully offline. Murmur sets it up for you.", ready: true)
                integration("Your own server", "Anything speaking OpenAI's /v1/audio/speech: LM Studio, LocalAI, Speaches.", ready: true)
                integration("Murmur Cloud", "Premium voices with a licence key, nothing to run.", ready: true)
                integration("Cartesia · Fish Audio", "Bring your own API key. Never touches Murmur's servers.", ready: true)
            }
            .padding(.horizontal, 40).padding(.bottom, 40)
        }
    }

    private func integration<Extra: View>(_ title: String, _ body: String, ready: Bool, @ViewBuilder extra: @escaping () -> Extra) -> some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(title).font(Theme.ui(14, .medium)).foregroundStyle(Theme.ink)
                    if !ready { Text("PLANNED").font(Theme.label(9)).tracking(1.2).foregroundStyle(Theme.inkFaint) }
                    Spacer()
                }
                Text(body).font(Theme.ui(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                extra()
            }
        }
        .opacity(ready ? 1 : 0.7)
    }
    private func integration(_ title: String, _ body: String, ready: Bool) -> some View {
        integration(title, body, ready: ready) { EmptyView() }
    }
}
