import AVFoundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject private var license = License.shared
    @State private var trusted = AX.isTrusted
    @State private var probing = false
    @State private var probeResult: String?
    @State private var copiedHook = false
    let onTest: (String) -> Void
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                section("Permission") { permission }
                section("Voice") { voice }
                section("Shortcut") { shortcut }
                section("Reading") { reading }
                section("Claude Code") { claudeCode }
                tryIt
            }
            .padding(.horizontal, 44)
            .padding(.bottom, 40)
        }
        .background(Theme.surfaceSolid)
        .onReceive(timer) { _ in trusted = AX.isTrusted }
    }

    // MARK: Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Wordmark(size: 40)
            Text("Select anything.\nPress \(settings.hotKey.display). Listen.")
                .font(Theme.display(28))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3)
        }
        .padding(.top, 56)
        .padding(.bottom, 36)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            Text(title.uppercased())
                .font(Theme.ui(10, .medium))
                .tracking(1.6)
                .foregroundStyle(Theme.inkFaint)
                .padding(.top, 16)
            content()
        }
        .padding(.bottom, 28)
    }

    private var permission: some View {
        HStack(alignment: .center, spacing: 14) {
            Circle().fill(trusted ? Color.green : Theme.accent).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(trusted ? "Accessibility is on" : "Accessibility is off")
                    .font(Theme.ui(15))
                    .foregroundStyle(Theme.ink)
                Text("Murmur needs it to see what you've highlighted.")
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            if !trusted {
                pill("Grant access") { AX.requestTrust(); AX.openPrivacyPane() }
            }
        }
    }

    private var voice: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 4) {
                ForEach(Provider.allCases) { p in
                    let selected = settings.provider == p
                    Button { settings.provider = p } label: {
                        Text(p.label)
                            .font(Theme.ui(13, selected ? .medium : .regular))
                            .foregroundStyle(selected ? Theme.surfaceSolid : Theme.inkSoft)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(selected ? Theme.ink : .clear))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(Theme.well))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: settings.provider)

            switch settings.provider {
            case .system:
                labelled("Voice") {
                    Picker("", selection: $settings.systemVoice) {
                        Text("Best available").tag("")
                        ForEach(systemVoices, id: \.identifier) { v in
                            Text("\(v.name) · \(v.language)").tag(v.identifier)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)
                }
                hint("Works offline, no key needed. Higher-quality voices can be downloaded in System Settings → Accessibility → Spoken Content.")
            case .localServer:
                labelled("Server") { field(TextField("http://localhost:8880/v1", text: $settings.localServerURL)) }
                labelled("Model") { field(TextField("kokoro", text: $settings.localServerModel)) }
                labelled("Voice") { field(TextField("af_heart", text: $settings.localServerVoice)) }
                HStack(spacing: 10) {
                    pill(probing ? "Checking…" : "Test connection") { Task { await probeServer() } }
                    if let result = probeResult {
                        Text(result)
                            .font(Theme.ui(12))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                hint("Any server that speaks OpenAI's /v1/audio/speech works: Kokoro-FastAPI, LM Studio, LocalAI, Speaches. Your text never leaves your machine. Leave the key blank unless your server asks for one.")
                labelled("Key") { field(SecureField("optional", text: $settings.localServerKey)) }
            case .cloud:
                licenceRow
                hint("Premium voices with no API key of your own. Requires a Murmur Pro subscription — your key is on murmurrrr.com/account.")
            case .cartesia:
                labelled("API key") { field(SecureField("", text: $settings.cartesiaKey)) }
                labelled("Voice ID") { field(TextField("", text: $settings.cartesiaVoice)) }
                hint("Sonic-3, streamed. Keys at play.cartesia.ai. Voice IDs are on each voice in their library.")
            case .fish:
                labelled("API key") { field(SecureField("", text: $settings.fishKey)) }
                labelled("Voice ID") { field(TextField("", text: $settings.fishVoice)) }
                hint("Fish S1. Keys at fish.audio. Leave the voice blank for the default.")
            }

            pill("Test voice") {
                onTest("This is Murmur. Highlight anything on your screen, press the shortcut, and I'll read it to you. Try the speed chips while I talk.")
            }
        }
    }

    /// Asks the server for a word of audio and reports what came back. Far more
    /// useful than a bare reachability check: it catches a wrong model name or
    /// an unknown voice, which is what actually goes wrong.
    private func probeServer() async {
        probing = true
        probeResult = nil
        defer { probing = false }

        let provider = LocalServerProvider(baseURL: settings.localServerURL,
                                           model: settings.localServerModel,
                                           voice: settings.localServerVoice,
                                           apiKey: settings.localServerKey)
        var frames = 0
        do {
            try await provider.synthesize("Hello.") { buffer in
                frames += Int(buffer.frameLength)
            }
            probeResult = frames > 0
                ? "Connected — received \(String(format: "%.1f", Double(frames) / 24_000))s of audio."
                : "Connected, but the server sent no audio. Check the voice name."
        } catch {
            probeResult = (error as? SpeechError)?.message ?? error.localizedDescription
        }
    }

    @ViewBuilder private var licenceRow: some View {
        labelled("Licence") {
            HStack(spacing: 10) {
                field(SecureField("MURMUR-XXXX-XXXX-XXXX-XXXX", text: $settings.licenseKey))
                Button("Check") {
                    Task { await license.validate(settings.licenseKey) }
                }
                .buttonStyle(.plain)
                .font(Theme.ui(12, .medium))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Theme.well))
            }
        }

        switch license.state {
        case .checking:
            hint("Checking…")
        case .valid(let plan):
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text(plan == "pro_plus" ? "Murmur Pro+ active" : "Murmur Pro active")
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.inkSoft)
            }
        case .invalid(let message):
            hint(message)
        case .none:
            EmptyView()
        }
    }

    private var systemVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { ($0.quality.rawValue, $0.name) > ($1.quality.rawValue, $1.name) }
    }

    private var shortcut: some View {
        VStack(alignment: .leading, spacing: 12) {
            HotKeyRecorder(hotKey: $settings.hotKey)
            hint("⌘⇧M is also “Recent mentions” in Slack. Global shortcuts win, so pick something else if you use that.")
        }
    }

    private var reading: some View {
        VStack(alignment: .leading, spacing: 14) {
            labelled("Speed") {
                HStack(spacing: 2) {
                    ForEach([0.8, 1.0, 1.25, 1.5, 2.0], id: \.self) { s in
                        let selected = abs(settings.speed - s) < 0.01
                        Button { settings.speed = s } label: {
                            Text(s == floor(s) ? "\(Int(s))×" : "\(s)×")
                                .font(Theme.ui(11, selected ? .medium : .regular))
                                .foregroundStyle(selected ? Theme.surfaceSolid : Theme.inkSoft)
                                .padding(.horizontal, 9).padding(.vertical, 6)
                                .background(Capsule().fill(selected ? Theme.ink : .clear))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Capsule().fill(Theme.well))
            }
            toggle("Clean up markdown, code fences and HTML", $settings.cleanMarkdown)
            toggle("Re-flow hard-wrapped lines (terminals, PDFs)", $settings.joinWrappedLines)
            toggle("Nothing selected → point & click to read", $settings.lensFallback)
            toggle("Launch at login", Binding(get: { settings.launchAtLogin }, set: { settings.launchAtLogin = $0 }))
        }
    }

    private var claudeCode: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hear every reply as it lands. Add this Stop hook to ~/.claude/settings.json.")
                .font(Theme.ui(13))
                .foregroundStyle(Theme.inkSoft)
            Text(Self.hookSnippet)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.well))
            pill(copiedHook ? "Copied" : "Copy snippet") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(Self.hookSnippet, forType: .string)
                copiedHook = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedHook = false }
            }
        }
    }

    static var hookSnippet: String {
        let bin = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/Murmur").path
        return """
        "hooks": {
          "Stop": [{ "hooks": [{ "type": "command", "command": "\"\(bin)\" --hook" }] }]
        }
        """
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try it now")
                .font(Theme.ui(10, .medium)).tracking(1.6).foregroundStyle(Theme.inkFaint)
            Text("Highlight this sentence with your mouse, then press \(settings.hotKey.display). A small player will appear at the top of your screen and start reading. Press the shortcut again with nothing selected to point at any text on screen instead.")
                .font(Theme.ui(16, .light))
                .foregroundStyle(Theme.ink)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.well))
    }

    // MARK: Bits

    private func labelled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label).font(Theme.ui(13)).foregroundStyle(Theme.inkSoft).frame(width: 64, alignment: .leading)
            content()
        }
    }

    private func field<F: View>(_ f: F) -> some View {
        f.textFieldStyle(.plain)
            .font(Theme.ui(13))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.well))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.hairline, lineWidth: 1))
            .frame(maxWidth: 360)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(Theme.ui(12)).foregroundStyle(Theme.inkFaint).fixedSize(horizontal: false, vertical: true)
    }

    private func toggle(_ label: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) { Text(label).font(Theme.ui(13)).foregroundStyle(Theme.ink) }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Theme.ink)
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(13, .medium))
                .foregroundStyle(Theme.surfaceSolid)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Capsule().fill(Theme.ink))
        }
        .buttonStyle(.plain)
    }
}
