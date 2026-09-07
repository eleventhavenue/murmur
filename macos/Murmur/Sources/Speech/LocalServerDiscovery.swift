import Foundation

/// Finds an OpenAI-compatible TTS server already running on this machine.
///
/// Typing a URL is the kind of setup step that loses people, and most users who
/// have a local server running have it on a well-known port. Probing those
/// directly turns configuration into a button press.
enum LocalServerDiscovery {

    struct Server: Identifiable, Equatable {
        var id: String { baseURL }
        let baseURL: String
        let label: String
        let models: [String]
        let voices: [String]
    }

    /// Ports worth trying, with the tool that usually owns each one.
    private static let candidates: [(port: Int, label: String)] = [
        (8880, "Kokoro-FastAPI"),
        (1234, "LM Studio"),
        (8000, "Local server"),
        (8080, "Local server"),
        (5002, "Local server"),
        (11434, "Ollama"),
    ]

    /// Probes every candidate at once and returns whatever answers.
    static func scan(timeout: TimeInterval = 2.0) async -> [Server] {
        await withTaskGroup(of: Server?.self) { group in
            for candidate in candidates {
                group.addTask {
                    await probe("http://localhost:\(candidate.port)/v1",
                                label: candidate.label, timeout: timeout)
                }
            }
            var found: [Server] = []
            for await server in group {
                if let server { found.append(server) }
            }
            return found.sorted { $0.baseURL < $1.baseURL }
        }
    }

    /// Confirms a base URL speaks the API, and collects what it can offer.
    static func probe(_ baseURL: String, label: String = "Local server",
                      timeout: TimeInterval = 4.0) async -> Server? {
        guard let root = normalized(baseURL) else { return nil }

        // /v1/models is the one endpoint every OpenAI-compatible server implements.
        guard let models = await fetchList(root.appendingPathComponent("models"),
                                           keys: ["id"], timeout: timeout) else { return nil }

        // Voices are not part of the OpenAI spec. Kokoro-FastAPI and several
        // others expose them anyway, which lets us offer a picker instead of a
        // text field. Absence is not a failure.
        let voices = await fetchList(root.appendingPathComponent("audio/voices"),
                                     keys: ["id", "name"], timeout: timeout) ?? []

        return Server(baseURL: root.absoluteString, label: label,
                      models: models, voices: voices)
    }

    /// Normalises anything the user might paste into a `/v1` root.
    static func normalized(_ base: String) -> URL? {
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") { trimmed = "http://" + trimmed }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if trimmed.hasSuffix("/audio/speech") { trimmed.removeLast("/audio/speech".count) }
        if !trimmed.hasSuffix("/v1") { trimmed += "/v1" }
        return URL(string: trimmed)
    }

    /// Reads a JSON list of names, tolerating the several shapes servers use:
    /// `{"data":[{"id":…}]}`, `{"voices":[…]}`, or a bare array of strings.
    private static func fetchList(_ url: URL, keys: [String], timeout: TimeInterval) async -> [String]? {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        func names(from any: Any) -> [String] {
            if let strings = any as? [String] { return strings }
            if let objects = any as? [[String: Any]] {
                return objects.compactMap { object in
                    keys.compactMap { object[$0] as? String }.first
                }
            }
            return []
        }

        if let root = try? JSONSerialization.jsonObject(with: data) {
            if let array = root as? [Any] { return names(from: array) }
            if let dict = root as? [String: Any] {
                for key in ["data", "voices", "models"] {
                    if let inner = dict[key] {
                        let found = names(from: inner)
                        if !found.isEmpty { return found }
                    }
                }
                return []
            }
        }
        return nil
    }
}
