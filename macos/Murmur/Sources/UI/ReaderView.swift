import SwiftUI

struct ReaderView: View {
    @ObservedObject var session: ReaderSession
    let onClose: () -> Void
    @State private var expanded = false
    @State private var hoverExpand = false

    static let width: CGFloat = 620
    private let speeds: [Double] = [0.8, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 0) {
            header
            teleprompter
                .padding(.horizontal, 30)
                .padding(.top, 6)
                .padding(.bottom, 18)
            if expanded { script }
            controls
            progressLine
        }
        .frame(width: Self.width)
        .background(
            ZStack {
                Frost()
                Theme.surface
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: expanded)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: session.phase)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Wordmark()
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .opacity(session.phase == .preparing ? 0.4 : 1)
                .animation(session.phase == .preparing ? .easeInOut(duration: 0.7).repeatForever() : .default, value: session.phase)
            if !session.sourceApp.isEmpty {
                Text(session.sourceApp.uppercased())
                    .font(Theme.ui(10, .medium))
                    .tracking(1.4)
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            Text(counter)
                .font(Theme.ui(11))
                .foregroundStyle(Theme.inkFaint)
                .monospacedDigit()
            IconButton(symbol: "xmark", size: 26, weight: .medium, action: onClose)
        }
        .padding(.leading, 26)
        .padding(.trailing, 16)
        .padding(.top, 16)
    }

    private var statusColor: Color {
        switch session.phase {
        case .playing, .preparing: return Theme.accent
        case .failed: return .red
        default: return Theme.inkFaint
        }
    }

    private var counter: String {
        guard !session.chunks.isEmpty else { return "" }
        let position = "\(min(session.currentIndex + 1, session.chunks.count)) / \(session.chunks.count)"
        guard let remaining = remainingTime else { return position }
        return "\(position) · \(remaining)"
    }

    /// Roughly how much is left to hear.
    ///
    /// Pressing a hotkey could previously commit you to seven minutes of audio
    /// with nothing on screen suggesting the length. Speech runs at about 150
    /// words a minute, and a word averages around 5.5 characters, both scaled
    /// by the playback rate.
    private var remainingTime: String? {
        let chunks = session.chunks
        guard session.currentIndex < chunks.count else { return nil }
        let charsLeft = chunks[session.currentIndex...].reduce(0) { $0 + $1.text.count }
        let words = Double(charsLeft) / 5.5
        let seconds = words / 150.0 * 60.0 / max(session.speed, 0.1)
        guard seconds >= 1 else { return nil }
        if seconds < 60 { return "\(Int(seconds.rounded()))s" }
        let minutes = Int((seconds / 60).rounded())
        return minutes < 60 ? "\(minutes) min" : String(format: "%.1f hr", seconds / 3600)
    }

    // MARK: Teleprompter

    private var teleprompter: some View {
        VStack(alignment: .leading, spacing: 10) {
            if case .failed(let message) = session.phase {
                Text(message)
                    .font(Theme.display(22))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Open Settings from the menu bar icon.")
                    .font(Theme.ui(13))
                    .foregroundStyle(Theme.inkFaint)
            } else {
                if session.currentIndex > 0 {
                    Text(session.chunks[session.currentIndex - 1].text)
                        .font(Theme.ui(14, .light))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                        .transition(.opacity)
                }
                Text(session.currentText)
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(session.phase == .preparing ? 0.45 : 1)
                    .id(session.currentIndex)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity))
                if session.currentIndex + 1 < session.chunks.count {
                    Text(session.chunks[session.currentIndex + 1].text)
                        .font(Theme.ui(14, .light))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .clipped()
    }

    // MARK: Full script

    private var script: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(session.chunks) { chunk in
                        let isCurrent = chunk.id == session.currentIndex
                        let isPast = chunk.id < session.currentIndex
                        Button { session.seek(to: chunk.id) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(isCurrent ? Theme.accent : Color.clear)
                                    .frame(width: 2)
                                Text(chunk.text)
                                    .font(Theme.ui(14, isCurrent ? .regular : .light))
                                    .foregroundStyle(isCurrent ? Theme.ink : (isPast ? Theme.inkFaint : Theme.inkSoft))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(isCurrent ? Theme.well : .clear))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(chunk.id)
                        .padding(.top, chunk.id > 0 && session.chunks[chunk.id - 1].paragraph != chunk.paragraph ? 10 : 0)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }
            .frame(height: 260)
            .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
            .onChange(of: session.currentIndex) { _, idx in
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(idx, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(session.currentIndex, anchor: .center) }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 14) {
            Waveform(levels: session.levels, active: session.phase == .playing)
                .frame(width: 96, height: 26)
            Spacer(minLength: 8)
            IconButton(symbol: "backward.fill", size: 30) { session.skip(-1) }
            IconButton(symbol: playSymbol, size: 44, weight: .semibold, prominent: true) { session.togglePlayPause() }
            IconButton(symbol: "forward.fill", size: 30) { session.skip(1) }
            Spacer(minLength: 8)
            speedControl
            IconButton(symbol: expanded ? "chevron.up" : "text.alignleft", size: 28, weight: .medium) {
                expanded.toggle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var playSymbol: String {
        switch session.phase {
        case .playing: return "pause.fill"
        case .finished: return "arrow.counterclockwise"
        default: return "play.fill"
        }
    }

    private var speedControl: some View {
        HStack(spacing: 2) {
            ForEach(speeds, id: \.self) { s in
                let selected = abs(session.speed - s) < 0.01
                Button { session.speed = s } label: {
                    Text(label(for: s))
                        .font(Theme.ui(11, selected ? .medium : .regular))
                        .foregroundStyle(selected ? Theme.surfaceSolid : Theme.inkSoft)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(selected ? Theme.ink : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.well))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: session.speed)
    }

    private func label(for speed: Double) -> String {
        speed == floor(speed) ? "\(Int(speed))×" : "\(speed)×".replacingOccurrences(of: ".0×", with: "×")
    }

    private var progressLine: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.hairline)
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: geo.size.width * session.progress)
                    .animation(.linear(duration: 0.05), value: session.progress)
            }
        }
        .frame(height: 2)
    }
}
