import SwiftUI

/// Murmur's visual language, shared with murmurrrr.com.
///
/// The site defines the brand in `site/src/app/globals.css`: a bone background,
/// deep green ink, a single yellow accent, and Instrument Serif for display
/// type. Those tokens are mirrored here so the desktop app and the website read
/// as one product.
///
/// Light mode maps one-to-one onto the site. Dark mode inverts the relationship
/// rather than the literal colours: the deep green becomes the surface and the
/// bone becomes the ink, so the palette stays the same three colours.
enum Theme {

    // MARK: - Palette

    /// Bone. `--color-bg` on the site.
    static let bone = NSColor(srgbRed: 0.953, green: 0.949, blue: 0.925, alpha: 1)   // #F3F2EC
    /// Deep green. `--color-ink` and `--color-surface` on the site.
    static let green = NSColor(srgbRed: 0.122, green: 0.227, blue: 0.200, alpha: 1)  // #1F3A33
    /// The one accent. `--color-accent`.
    static let yellow = Color(red: 0.863, green: 0.831, blue: 0.267)                 // #DCD444
    /// Muted secondary text on the site. `--color-ink2`.
    private static let taupe = NSColor(srgbRed: 0.671, green: 0.651, blue: 0.592, alpha: 1) // #ABA697
    /// A darker green for dark-mode chrome, so panels sit above the background.
    private static let greenDeep = NSColor(srgbRed: 0.086, green: 0.161, blue: 0.141, alpha: 1)

    static let accent = yellow

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.isDark ? dark : light })
    }

    /// Primary text.
    static let ink = dynamic(light: green, dark: bone)
    /// Secondary text: labels, captions, the source-app chip.
    static let inkSoft = dynamic(light: taupe, dark: bone.withAlphaComponent(0.62))
    /// Tertiary text: counters, hints.
    static let inkFaint = dynamic(light: taupe.withAlphaComponent(0.75),
                                  dark: bone.withAlphaComponent(0.34))
    /// Hairline rules. `--color-ink3`.
    static let hairline = dynamic(light: green.withAlphaComponent(0.10),
                                  dark: bone.withAlphaComponent(0.12))
    /// Translucent panel fill, laid over the frosted backing.
    static let surface = dynamic(light: bone.withAlphaComponent(0.90),
                                 dark: greenDeep.withAlphaComponent(0.92))
    /// Opaque panel fill, and the colour text sits on when reversed out.
    static let surfaceSolid = dynamic(light: bone, dark: greenDeep)
    /// Inset wells: chips, fields, the script sheet.
    static let well = dynamic(light: green.withAlphaComponent(0.05),
                              dark: bone.withAlphaComponent(0.07))

    // MARK: - Type

    /// Instrument Serif, bundled in Resources/Fonts. Used for the wordmark and
    /// the teleprompter, exactly as the site uses it for headings.
    static func display(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular", size: size)
    }

    /// UI text. The site pairs its serif with Inter; on macOS the system face is
    /// the better-tuned equivalent and costs nothing to ship.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Small uppercase labels with the site's wide tracking.
    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .semibold)
    }
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

/// Frosted glass backing for floating panels.
struct Frost: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { nsView.material = material }
}

/// "murmur." — the site's wordmark, trailing period and all.
struct Wordmark: View {
    var size: CGFloat = 15
    var body: some View {
        Text("murmur.")
            .font(Theme.display(size))
            .foregroundStyle(Theme.ink)
    }
}

/// Tiny circular icon button with a hover ring.
struct IconButton: View {
    let symbol: String
    var size: CGFloat = 30
    var weight: Font.Weight = .regular
    var prominent = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(prominent ? Theme.ink : (hover ? Theme.well : Color.clear))
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: weight))
                    .foregroundStyle(prominent ? Theme.surfaceSolid : Theme.ink)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
    }
}
