import AVFoundation
import SwiftUI

/// First-run flow. Six short steps, each one screen, each doing one thing.
///
/// The third step is the one that matters: it asks how much the person wants
/// to set up, in plain words, and routes them to the matching voice path.
/// Someone who answers "just make it work" never sees the word Docker.
struct OnboardingView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var session: ReaderSession
    @ObservedObject private var engine = LocalEngine.shared
    @ObservedObject private var license = License.shared
    let onTest: (String) -> Void
    let onFinish: () -> Void

    enum Step: Int, CaseIterable { case welcome, access, path, voice, shortcut, tryIt, done }
    @State private var step: Step = .welcome
    @State private var trusted = AX.isTrusted
    @State private var heardIt = false
    @State private var serverVoices: [String] = []
    @State private var scanNote: String?
    private let poll = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            progress.padding(.top, 28).padding(.horizontal, 48)
            Group {
                switch step {
                case .welcome:  welcome
                case .access:   access
                case .path:     path
                case .voice:    voice
                case .shortcut: shortcut
                case .tryIt:    tryIt
                case .done:     done
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 48).padding(.top, 36)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(step)
            footer.padding(.horizontal, 48).padding(.bottom, 32)
        }
        .frame(width: 760, height: 600)
        .background(Theme.surfaceSolid)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: step)
        .onReceive(poll) { _ in
            trusted = AX.isTrusted
            if step == .tryIt, session.phase == .playing, session.sourceApp == "Murmur" || session.sourceApp == "Onboarding" || !session.sourceApp.isEmpty { heardIt = true }
        }
        .task { await engine.refresh() }
    }

    // MARK: Chrome

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule().fill(s.rawValue <= step.rawValue ? Theme.ink : Theme.hairline).frame(height: 3)
            }
        }
    }

    private var footer: some View {
        HStack {
            if step != .welcome && step != .done {
                Button("Back") { go(-1) }.buttonStyle(.plain).font(Theme.ui(13)).foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            if step == .access && !trusted {
                Button("Skip for now") { go(1) }.buttonStyle(.plain).font(Theme.ui(13)).foregroundStyle(Theme.inkFaint)
                    .padding(.trailing, 14)
            }
            if step == .done {
                Pill(title: "Open Murmur") { onFinish() }
            } else if step == .path {
                EmptyView() // the cards advance
            } else {
                Pill(title: step == .tryIt ? (heardIt ? "Continue" : "Continue anyway") : "Continue",
                     disabled: step == .access && !trusted) { go(1) }
            }
        }
    }

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        step = next
        if step == .voice { Task { await refreshServerVoices() } }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            Wordmark(size: 56)
            Text("Your text, read beautifully.")
                .font(Theme.display(34)).foregroundStyle(Theme.ink)
            Text("Highlight anything on your Mac, press a shortcut, and Murmur reads it to you in a small player at the top of your screen. Everything you read stays on this machine.")
                .font(Theme.ui(15)).foregroundStyle(Theme.inkSoft).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Hint(text: "About two minutes to set up.")
        }
    }

    private var access: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Step 1")
            Text("Let Murmur see what you highlight.")
                .font(Theme.display(30)).foregroundStyle(Theme.ink)
            Text("macOS calls this Accessibility access. It's how Murmur reads the text you've selected in any app. Murmur never stores that text and never sends it anywhere unless you choose a cloud voice.")
                .font(Theme.ui(14)).foregroundStyle(Theme.inkSoft).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Card {
                HStack(spacing: 14) {
                    StatusDot(on: trusted)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trusted ? "Accessibility is on" : "Accessibility is off")
                            .font(Theme.ui(15, .medium)).foregroundStyle(Theme.ink)
                        Text(trusted ? "You're set. Murmur can read your selections."
                                     : "Click Grant access, then turn on Murmur in the list that opens.")
                            .font(Theme.ui(12)).foregroundStyle(Theme.inkFaint)
                    }
                    Spacer()
                    if !trusted { Pill(title: "Grant access") { AX.requestTrust(); AX.openPrivacyPane() } }
                }
            }
            if trusted {
                Text("This page will move on automatically.").font(Theme.ui(12)).foregroundStyle(Theme.inkFaint)
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { if step == .access { go(1) } } }
            }
        }
    }

    /// The fork. Three honest cards: time, quality, where it runs, cost.
    private var path: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Step 2")
            Text("How much do you want to set up?")
                .font(Theme.display(30)).foregroundStyle(Theme.ink)
            Text("All three work. You can change your mind any time in Voices.")
                .font(Theme.ui(14)).foregroundStyle(Theme.inkSoft)

            HStack(alignment: .top, spacing: 14) {
                pathCard(
                    title: "Just make it work",
                    time: "30 seconds", quality: "Good", runs: "On this Mac", cost: "Free",
                    body: "Apple's built-in voices. Nothing to install, nothing to sign up for. You can download better Apple voices in one click.",
                    provider: .system)
                pathCard(
                    title: "Best voices, no setup",
                    time: "1 minute", quality: "Best", runs: "In the cloud", cost: "Murmur Pro",
                    body: "Natural neural voices without running anything yourself. Text is sent to Murmur's servers to be spoken, and nowhere else.",
                    provider: .cloud)
                pathCard(
                    title: "I'll run it myself",
                    time: engine.isDockerAvailable ? "5–10 minutes" : "Needs Docker",
                    quality: "Better", runs: "On this Mac", cost: "Free",
                    body: "Murmur downloads and runs the Kokoro engine for you, 27 natural voices, fully offline. Or point it at a server you already run.",
                    provider: .localServer)
            }
        }
    }

    private func pathCard(title: String, time: String, quality: String, runs: String, cost: String,
                          body: String, provider: Provider) -> some View {
        Button {
            settings.provider = provider
            go(1)
        } label: {
            Card(padding: 18, selected: settings.provider == provider) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title).font(Theme.display(22)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(body).font(Theme.ui(12)).foregroundStyle(Theme.inkSoft).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    VStack(alignment: .leading, spacing: 5) {
                        fact("Setup", time); fact("Quality", quality); fact("Runs", runs); fact("Cost", cost)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }

    private func fact(_ k: String, _ v: String) -> some View {
        HStack(spacing: 8) {
            Text(k).font(Theme.ui(11)).foregroundStyle(Theme.inkFaint).frame(width: 48, alignment: .leading)
            Text(v).font(Theme.ui(11, .medium)).foregroundStyle(Theme.ink)
        }
    }

    /// Depends on the card chosen. Each path gets exactly the controls it needs.
    @ViewBuilder private var voice: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Step 3")
            switch settings.provider {
            case .system: systemVoiceStep
            case .cloud: cloudStep
            case .localServer: localStep
            default: systemVoiceStep
            }
        }
    }

    private var systemVoiceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick a voice.").font(Theme.display(30)).foregroundStyle(Theme.ink)
            Text("Changing the selection plays a sample.").font(Theme.ui(14)).foregroundStyle(Theme.inkSoft)
            Picker("", selection: $settings.systemVoice) {
                Text("Best available (\(VoiceCatalog.best()?.name ?? "system"))").tag("")
                ForEach(VoiceCatalog.selectable(), id: \.identifier) { v in Text(VoiceCatalog.display(v)).tag(v.identifier) }
            }
            .labelsHidden().frame(maxWidth: 360)
            .onChange(of: settings.systemVoice) { _, _ in onTest(Self.sample) }
            if VoiceCatalog.lacksHighQualityVoice {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Mac only has basic voices installed.").font(Theme.ui(14, .medium)).foregroundStyle(Theme.ink)
                        Text("Apple's Premium voices are free and sound dramatically better. Download one, come back, and it'll be picked automatically.")
                            .font(Theme.ui(12)).foregroundStyle(Theme.inkFaint).fixedSize(horizontal: false, vertical: true)
                        Pill(title: "Open voice downloads") { VoiceCatalog.openVoiceDownloads() }
                    }
                }
            } else {
                Pill(title: "Play a sample", prominent: false) { onTest(Self.sample) }
            }
        }
    }

    private var cloudStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect Murmur Pro.").font(Theme.display(30)).foregroundStyle(Theme.ink)
            Text("Paste the licence key from your account page. Don't have one yet? You can finish setup with Apple's voices and upgrade later.")
                .font(Theme.ui(14)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                SecureField("MURMUR-XXXX-XXXX-XXXX-XXXX", text: $settings.licenseKey).fieldStyle().frame(maxWidth: 340)
                Pill(title: "Check", prominent: false) { Task { await license.validate(settings.licenseKey) } }
            }
            switch license.state {
            case .checking: Hint(text: "Checking…")
            case .valid(let plan): HStack(spacing: 8) { StatusDot(on: true); Text(plan == "pro_plus" ? "Murmur Pro+ active" : "Murmur Pro active").font(Theme.ui(13)).foregroundStyle(Theme.inkSoft) }
            case .invalid(let m): Hint(text: m)
            case .none: EmptyView()
            }
            HStack(spacing: 14) {
                Link("Get Murmur Pro", destination: URL(string: "https://murmurrrr.com/pricing")!).font(Theme.ui(13)).foregroundStyle(Theme.ink)
                Button("Use Apple voices for now") { settings.provider = .system }.buttonStyle(.plain).font(Theme.ui(13)).foregroundStyle(Theme.inkFaint)
            }
        }
    }

    private var localStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set up local voices.").font(Theme.display(30)).foregroundStyle(Theme.ink)
            switch engine.state {
            case .checking:
                Hint(text: "Checking for Docker…")
            case .noDocker:
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Murmur runs the engine in Docker, which isn't installed.").font(Theme.ui(14, .medium)).foregroundStyle(Theme.ink)
                        Text("Install Docker Desktop, then come back here. Until then Murmur will use Apple's voices, so nothing is blocked.")
                            .font(Theme.ui(12)).foregroundStyle(Theme.inkFaint).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 12) {
                            Link("Get Docker Desktop", destination: URL(string: "https://www.docker.com/products/docker-desktop/")!).font(Theme.ui(13)).foregroundStyle(Theme.ink)
                            Button("Use Apple voices instead") { settings.provider = .system }.buttonStyle(.plain).font(Theme.ui(13)).foregroundStyle(Theme.inkFaint)
                        }
                    }
                }
            case .notInstalled:
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Download and start the Kokoro engine").font(Theme.ui(14, .medium)).foregroundStyle(Theme.ink)
                        Text("About 4.5 GB, once. 27 natural voices, entirely on this Mac. You can keep going while it downloads: Murmur uses Apple's voices until it's ready.")
                            .font(Theme.ui(12)).foregroundStyle(Theme.inkFaint).fixedSize(horizontal: false, vertical: true)
                        Pill(title: "Download and start") { Task { await engine.install(); await refreshServerVoices() } }
                    }
                }
            case .pulling(let detail):
                Card { VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Downloading the engine…").font(Theme.ui(14, .medium)).foregroundStyle(Theme.ink) }
                    Text(detail).font(Theme.ui(11)).foregroundStyle(Theme.inkFaint).lineLimit(1)
                    Hint(text: "You can continue. It keeps going in the background.")
                } }
            case .starting:
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Starting…").font(Theme.ui(13)).foregroundStyle(Theme.inkSoft) }
            case .running:
                HStack(spacing: 8) { StatusDot(on: true); Text("Local engine running").font(Theme.ui(13)).foregroundStyle(Theme.inkSoft) }
                if !serverVoices.isEmpty {
                    Picker("", selection: $settings.localServerVoice) { ForEach(serverVoices, id: \.self) { Text($0).tag($0) } }
                        .labelsHidden().frame(maxWidth: 300)
                        .onChange(of: settings.localServerVoice) { _, _ in onTest(Self.sample) }
                    Hint(text: "Changing the voice plays a sample. \(serverVoices.count) available.")
                }
            case .stopped:
                Pill(title: "Start local engine") { Task { await engine.start(); await refreshServerVoices() } }
            case .failed(let m):
                Hint(text: m)
            }
            Divider().padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("Already running Kokoro, LM Studio or another server?").font(Theme.ui(13, .medium)).foregroundStyle(Theme.ink)
                HStack(spacing: 10) {
                    TextField("http://localhost:8880/v1", text: $settings.localServerURL).fieldStyle().frame(maxWidth: 300)
                    Pill(title: "Scan", prominent: false) { Task { await scan() } }
                }
                if let scanNote { Hint(text: scanNote) }
            }
        }
    }

    private var shortcut: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Step 4")
            Text("Choose your shortcut.").font(Theme.display(30)).foregroundStyle(Theme.ink)
            Text("Press it with text highlighted to hear it read. Press it again to pause.")
                .font(Theme.ui(14)).foregroundStyle(Theme.inkSoft)
            HotKeyRecorder(hotKey: $settings.hotKey)
            Hint(text: "⌘⇧M is also “Recent mentions” in Slack. Murmur's global shortcut wins, so pick another if you use that.")
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Step 5")
            Text(heardIt ? "You heard it." : "Try it.").font(Theme.display(30)).foregroundStyle(Theme.ink)
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text("Highlight the sentence below with your mouse, then press").font(Theme.ui(13)).foregroundStyle(Theme.inkSoft)
                        KeycapBadge(text: settings.hotKey.display, size: 13)
                    }
                    Text("A small player will appear at the top of your screen and start reading. Press the shortcut again to pause, and again to resume.")
                        .font(Theme.display(22)).foregroundStyle(Theme.ink).lineSpacing(3)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if heardIt {
                HStack(spacing: 8) { StatusDot(on: true); Text("That's it. That's the whole product.").font(Theme.ui(13)).foregroundStyle(Theme.inkSoft) }
            } else {
                Hint(text: "Nothing happened? Make sure the text is highlighted, and that Accessibility is on.")
            }
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 18) {
            Wordmark(size: 44)
            Text("Murmur lives in your menu bar.").font(Theme.display(30)).foregroundStyle(Theme.ink)
            Text("Look for the waveform icon at the top right. Highlight text anywhere and press \(settings.hotKey.display). The main window has your stats, a pronunciation dictionary, and everything else.")
                .font(Theme.ui(14)).foregroundStyle(Theme.inkSoft).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: Binding(get: { settings.launchAtLogin }, set: { settings.launchAtLogin = $0 })) {
                Text("Launch Murmur when I log in").font(Theme.ui(13)).foregroundStyle(Theme.ink)
            }
            .toggleStyle(.switch).controlSize(.small).tint(Theme.ink)
            if settings.provider == .localServer {
                Toggle(isOn: $settings.autoStartEngine) {
                    Text("Start the local engine when Murmur launches").font(Theme.ui(13)).foregroundStyle(Theme.ink)
                }
                .toggleStyle(.switch).controlSize(.small).tint(Theme.ink)
                Hint(text: "Until it's ready after a reboot, Murmur uses Apple's voices so nothing waits on it.")
            }
        }
    }

    // MARK: Helpers

    static let sample = "Hello. This is how I'll sound when I read to you."

    private func refreshServerVoices() async {
        guard settings.provider == .localServer else { return }
        if let s = await LocalServerDiscovery.probe(settings.localServerURL) {
            serverVoices = s.voices
            if settings.localServerVoice.isEmpty, let v = s.voices.first { settings.localServerVoice = v }
        }
    }

    private func scan() async {
        scanNote = nil
        let found = await LocalServerDiscovery.scan()
        if let only = found.first {
            settings.localServerURL = only.baseURL
            if let m = only.models.first { settings.localServerModel = m }
            serverVoices = only.voices
            if let v = only.voices.first { settings.localServerVoice = v }
            scanNote = "Found \(only.label) with \(only.voices.count) voices."
        } else {
            scanNote = "No server found on the usual ports."
        }
    }
}
