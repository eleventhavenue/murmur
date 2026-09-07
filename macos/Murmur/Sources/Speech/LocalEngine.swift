import Foundation

/// Sets up and runs a local voice engine on the user's behalf.
///
/// "Local voices" should mean pressing a button, not reading a README. This
/// drives Docker to run Kokoro-FastAPI, which exposes the same
/// `/v1/audio/speech` API the Local Server provider already speaks, so once it
/// is up nothing else in Murmur needs to change.
///
/// Deliberately orchestrates rather than bundles. The image is pulled from
/// upstream by the user's own Docker, so Murmur redistributes no model weights
/// and inherits none of their licences — notably espeak-ng and phonemizer,
/// which Kokoro depends on for grapheme-to-phoneme and which are GPL-3.0.
@MainActor
final class LocalEngine: ObservableObject {
    static let shared = LocalEngine()

    enum State: Equatable {
        case checking
        case noDocker
        case notInstalled
        case pulling(String)
        case starting
        case running
        case stopped
        case failed(String)
    }

    @Published private(set) var state: State = .checking

    static let image = "ghcr.io/remsky/kokoro-fastapi-cpu:latest"
    static let container = "murmur-kokoro"
    static let port = 8880
    static let baseURL = "http://localhost:8880/v1"

    /// A GUI app launched from Finder gets a minimal PATH, so `docker` must be
    /// found by looking where the installers actually put it.
    private static let dockerPaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
    ]

    private var dockerPath: String? {
        Self.dockerPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    var isDockerAvailable: Bool { dockerPath != nil }

    // MARK: - Lifecycle

    func refresh() async {
        guard let docker = dockerPath else { state = .noDocker; return }
        state = .checking

        // Is the daemon even up? `docker info` fails fast when it is not.
        guard case .success = await run(docker, ["info", "--format", "{{.ServerVersion}}"]) else {
            state = .noDocker
            return
        }

        let running = await run(docker, ["ps", "--filter", "name=\(Self.container)",
                                        "--filter", "status=running", "--format", "{{.Names}}"])
        if case .success(let out) = running, out.contains(Self.container) {
            state = .running
            return
        }

        let exists = await run(docker, ["ps", "-a", "--filter", "name=\(Self.container)",
                                        "--format", "{{.Names}}"])
        if case .success(let out) = exists, out.contains(Self.container) {
            state = .stopped
            return
        }

        let images = await run(docker, ["images", "-q", Self.image])
        if case .success(let out) = images, !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state = .stopped
        } else {
            state = .notInstalled
        }
    }

    /// Pulls the image if needed, then starts the container.
    func install() async {
        guard let docker = dockerPath else { state = .noDocker; return }

        state = .pulling("Starting download…")
        let pulled = await runStreaming(docker, ["pull", Self.image]) { [weak self] line in
            // Docker's plain progress lines are noisy; surface the useful part.
            if line.contains("Pulling") || line.contains("Download") || line.contains("Extract") {
                Task { @MainActor in self?.state = .pulling(String(line.prefix(80))) }
            }
        }

        guard pulled else {
            state = .failed("Could not download the voice engine. Check Docker and your connection.")
            return
        }
        await start()
    }

    func start() async {
        guard let docker = dockerPath else { state = .noDocker; return }
        state = .starting

        // Reuse an existing container so restarts keep the same model cache.
        let existing = await run(docker, ["ps", "-a", "--filter", "name=\(Self.container)",
                                          "--format", "{{.Names}}"])
        if case .success(let out) = existing, out.contains(Self.container) {
            _ = await run(docker, ["start", Self.container])
        } else {
            let created = await run(docker, [
                "run", "-d", "--name", Self.container,
                "-p", "\(Self.port):8880",
                "--restart", "unless-stopped",
                Self.image,
            ])
            if case .failure(let message) = created {
                state = .failed(Self.explain(message))
                return
            }
        }

        // The server needs a moment to load the model before it answers.
        for _ in 0..<45 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if await LocalServerDiscovery.probe(Self.baseURL, timeout: 2) != nil {
                state = .running
                return
            }
        }
        state = .failed("The engine started but never became ready. Check `docker logs \(Self.container)`.")
    }

    /// Starts the engine if it is installed but not running, so selecting local
    /// voices and pressing the hotkey just works after a reboot.
    ///
    /// Never installs and never prompts: if Docker is missing or the image was
    /// never pulled, this does nothing and the provider surfaces its own error.
    /// Silently downloading gigabytes because someone pressed a hotkey would be
    /// the wrong trade.
    func ensureRunning() async {
        if case .running = state { return }
        await refresh()
        guard case .stopped = state else { return }
        await start()
    }

    func stop() async {
        guard let docker = dockerPath else { return }
        _ = await run(docker, ["stop", Self.container])
        state = .stopped
    }

    // MARK: - Process plumbing

    private enum Result {
        case success(String)
        case failure(String)
    }

    private func run(_ tool: String, _ arguments: [String]) async -> Result {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: tool)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let text = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: process.terminationStatus == 0
                        ? .success(text) : .failure(text))
                } catch {
                    continuation.resume(returning: .failure(error.localizedDescription))
                }
            }
        }
    }

    /// Same, but reports output line by line so a long pull shows progress.
    private func runStreaming(_ tool: String, _ arguments: [String],
                              onLine: @escaping (String) -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: tool)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    var buffer = Data()
                    while true {
                        let chunk = pipe.fileHandleForReading.availableData
                        if chunk.isEmpty { break }
                        buffer.append(chunk)
                        while let newline = buffer.firstIndex(of: 0x0A) {
                            let line = String(data: buffer[..<newline], encoding: .utf8) ?? ""
                            buffer.removeSubrange(...newline)
                            if !line.isEmpty { onLine(line) }
                        }
                    }
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private static func explain(_ message: String) -> String {
        if message.contains("port is already allocated") {
            return "Port \(port) is already in use. Stop whatever is using it, or point Murmur at it directly."
        }
        if message.contains("Cannot connect to the Docker daemon") {
            return "Docker isn't running. Start Docker Desktop and try again."
        }
        return String(message.prefix(160))
    }
}
