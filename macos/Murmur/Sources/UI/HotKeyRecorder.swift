import AppKit
import SwiftUI

struct HotKeyRecorder: View {
    @Binding var hotKey: HotKey
    @State private var recording = false

    var body: some View {
        Button { recording.toggle() } label: {
            HStack(spacing: 10) {
                Text(recording ? "Press keys…" : hotKey.display)
                    .font(Theme.ui(14, .medium))
                    .foregroundStyle(recording ? Theme.accent : Theme.ink)
                    .frame(minWidth: 72)
                if !recording {
                    Text("change")
                        .font(Theme.ui(11))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(recording ? Theme.accent : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .background(KeyCatcher(active: recording) { event in
            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if event.keyCode == 53 { recording = false; return } // esc cancels
            guard !flags.isEmpty else { return }
            hotKey = HotKey(keyCode: UInt32(event.keyCode),
                            modifiers: HotKeyManager.carbonModifiers(from: flags),
                            display: HotKeyManager.display(keyCode: event.keyCode, flags: flags,
                                                           characters: event.charactersIgnoringModifiers))
            recording = false
        })
    }
}

private struct KeyCatcher: NSViewRepresentable {
    let active: Bool
    let onKey: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKey = onKey
        context.coordinator.set(active: active)
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var onKey: ((NSEvent) -> Void)?
        private var monitor: Any?
        func set(active: Bool) {
            if active, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
                    self?.onKey?(e); return nil
                }
            } else if !active, let m = monitor {
                NSEvent.removeMonitor(m); monitor = nil
            }
        }
    }
}
