import Foundation

/// Talks to murmurrrr.com to turn a license key into entitlements.
///
/// Validation is a convenience, not a gate: Murmur's local voices work forever
/// with no key, no account and no network. This only decides whether the cloud
/// voices are available.
@MainActor
final class License: ObservableObject {
    static let shared = License()

    enum State: Equatable {
        case none
        case checking
        case valid(plan: String)
        case invalid(String)
    }

    @Published private(set) var state: State = .none

    /// Override for local development: `defaults write ai.murmur.app apiBase http://localhost:3000`
    nonisolated static func endpoint(path: String) -> URL {
        let base = UserDefaults.standard.string(forKey: "apiBase") ?? "https://murmurrrr.com"
        return URL(string: base + path) ?? URL(string: "https://murmurrrr.com" + path)!
    }

    private init() {
        if !Settings.shared.licenseKey.isEmpty { state = .valid(plan: Settings.shared.licensePlan) }
    }

    var hasCloudAccess: Bool {
        if case .valid = state { return Settings.shared.licenseCloudVoices }
        return false
    }

    struct Response: Decodable {
        let valid: Bool
        let plan: String
        let cloudVoices: Bool
        let reason: String?
    }

    func validate(_ rawKey: String) async {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !key.isEmpty else {
            state = .none
            store(plan: "free", cloudVoices: false)
            return
        }

        state = .checking

        var request = URLRequest(url: Self.endpoint(path: "/api/license/validate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["key": key])
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(Response.self, from: data)

            if response.valid {
                state = .valid(plan: response.plan)
                store(plan: response.plan, cloudVoices: response.cloudVoices)
            } else {
                state = .invalid(Self.explain(response.reason))
                store(plan: "free", cloudVoices: false)
            }
        } catch {
            // Offline is not a licence failure. Keep whatever we last confirmed.
            state = Settings.shared.licenseCloudVoices
                ? .valid(plan: Settings.shared.licensePlan)
                : .invalid("Couldn't reach murmurrrr.com. Local voices still work.")
        }
    }

    private func store(plan: String, cloudVoices: Bool) {
        Settings.shared.licensePlan = plan
        Settings.shared.licenseCloudVoices = cloudVoices
    }

    private static func explain(_ reason: String?) -> String {
        switch reason {
        case "malformed_key": return "That doesn't look like a Murmur key."
        case "unknown_key": return "We don't recognise that key."
        case "inactive_key": return "That key has been deactivated."
        case "licensing_not_configured": return "Licensing isn't switched on yet."
        default: return "That key isn't active. Check your subscription."
        }
    }
}
