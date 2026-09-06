import AppKit

// CLI mode: `Murmur read "text"`, `echo text | Murmur read -`, `Murmur --hook` (Claude Code Stop hook).
if CommandLine.arguments.count > 1, CLI.run(arguments: Array(CommandLine.arguments.dropFirst())) {
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
