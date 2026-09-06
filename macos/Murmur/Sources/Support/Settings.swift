import AppKit
import Combine
import ServiceManagement

enum Provider: String, CaseIterable, Identifiable {
    case system, cloud, cartesia, fish
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .cloud: return "Murmur Cloud"
        case .cartesia: return "Cartesia"
        case .fish: return "Fish Audio"
        }
    }
    /// Needs credentials of some kind: an API key, or a licence for the cloud.
    var needsKey: Bool { self != .system }
}

struct HotKey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon modifier mask
    var display: String

    static let `default` = HotKey(keyCode: 46, modifiers: 256 | 512, display: "⌘⇧M")
}

@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var provider: Provider { didSet { d.set(provider.rawValue, forKey: "provider") } }
    @Published var cartesiaVoice: String { didSet { d.set(cartesiaVoice, forKey: "cartesiaVoice") } }
    @Published var fishVoice: String { didSet { d.set(fishVoice, forKey: "fishVoice") } }
    @Published var systemVoice: String { didSet { d.set(systemVoice, forKey: "systemVoice") } }
    @Published var speed: Double { didSet { d.set(speed, forKey: "speed") } }
    @Published var cleanMarkdown: Bool { didSet { d.set(cleanMarkdown, forKey: "cleanMarkdown") } }
    @Published var joinWrappedLines: Bool { didSet { d.set(joinWrappedLines, forKey: "joinWrappedLines") } }
    @Published var lensFallback: Bool { didSet { d.set(lensFallback, forKey: "lensFallback") } }
    @Published var hotKey: HotKey { didSet { if let data = try? JSONEncoder().encode(hotKey) { d.set(data, forKey: "hotKey") } } }
    @Published var hasOnboarded: Bool { didSet { d.set(hasOnboarded, forKey: "hasOnboarded") } }

    @Published var cartesiaKey: String { didSet { Keychain.set(cartesiaKey, for: "cartesia") } }
    @Published var fishKey: String { didSet { Keychain.set(fishKey, for: "fish") } }

    /// Murmur Pro licence. The key itself lives in the Keychain; the
    /// entitlements it last resolved to are cached so the app knows what it can
    /// offer while offline.
    @Published var licenseKey: String { didSet { Keychain.set(licenseKey, for: "license") } }
    @Published var licensePlan: String { didSet { d.set(licensePlan, forKey: "licensePlan") } }
    @Published var licenseCloudVoices: Bool { didSet { d.set(licenseCloudVoices, forKey: "licenseCloudVoices") } }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch { NSLog("Launch at login: \(error)") }
        }
    }

    private init() {
        provider = Provider(rawValue: d.string(forKey: "provider") ?? "") ?? .system
        cartesiaVoice = d.string(forKey: "cartesiaVoice") ?? "694f9389-aac1-45b6-b726-9d9369183238"
        fishVoice = d.string(forKey: "fishVoice") ?? ""
        systemVoice = d.string(forKey: "systemVoice") ?? ""
        speed = d.object(forKey: "speed") as? Double ?? 1.0
        cleanMarkdown = d.object(forKey: "cleanMarkdown") as? Bool ?? true
        joinWrappedLines = d.object(forKey: "joinWrappedLines") as? Bool ?? true
        lensFallback = d.object(forKey: "lensFallback") as? Bool ?? true
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        if let data = d.data(forKey: "hotKey"), let hk = try? JSONDecoder().decode(HotKey.self, from: data) {
            hotKey = hk
        } else {
            hotKey = .default
        }
        cartesiaKey = Keychain.get("cartesia") ?? ""
        fishKey = Keychain.get("fish") ?? ""
        licenseKey = Keychain.get("license") ?? ""
        licensePlan = d.string(forKey: "licensePlan") ?? "free"
        licenseCloudVoices = d.bool(forKey: "licenseCloudVoices")
    }

    var activeKeyMissing: Bool {
        switch provider {
        case .system: return false
        case .cloud: return licenseKey.isEmpty
        case .cartesia: return cartesiaKey.isEmpty
        case .fish: return fishKey.isEmpty
        }
    }
}
