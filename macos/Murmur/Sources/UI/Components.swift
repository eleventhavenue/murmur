import SwiftUI

/// Small shared pieces so the onboarding, main window and settings read as
/// one surface. Everything here uses Theme tokens and nothing else.

struct Pill: View {
    let title: String
    var prominent = true
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(13, .medium))
                .foregroundStyle(prominent ? Theme.surfaceSolid : Theme.ink)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Capsule().fill(prominent ? Theme.ink : Theme.well))
                .overlay(Capsule().strokeBorder(prominent ? Color.clear : Theme.hairline, lineWidth: 1))
                .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 20
    var selected = false
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.well))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? Theme.ink : Theme.hairline, lineWidth: selected ? 1.5 : 1))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(Theme.label()).tracking(1.6).foregroundStyle(Theme.inkFaint)
    }
}

struct Hint: View {
    let text: String
    var body: some View {
        Text(text).font(Theme.ui(12)).foregroundStyle(Theme.inkFaint).fixedSize(horizontal: false, vertical: true)
    }
}

struct StatusDot: View {
    let on: Bool
    var body: some View { Circle().fill(on ? Color.green : Theme.accent).frame(width: 8, height: 8) }
}

/// Text field with the house styling.
struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(Theme.ui(13))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.well))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.hairline, lineWidth: 1))
    }
}
extension View { func fieldStyle() -> some View { modifier(FieldStyle()) } }

/// The hotkey rendered like a keycap, the way the site shows its shortcut.
struct KeycapBadge: View {
    let text: String
    var size: CGFloat = 22
    var body: some View {
        Text(text)
            .font(Theme.ui(size, .semibold))
            .foregroundStyle(Theme.green.asColor)
            .padding(.horizontal, 10).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.accent))
    }
}

extension NSColor { var asColor: Color { Color(nsColor: self) } }
