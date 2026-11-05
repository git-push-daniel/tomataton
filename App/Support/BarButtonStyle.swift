import SwiftUI

/// Small button for the bar under a list, like the +/− under macOS lists.
/// Icon-only labels become a square; text labels get horizontal padding.
/// The whole shape is clickable (borderless buttons only react on the glyph
/// or text itself) and it highlights on hover so the target is visible.
struct BarButtonStyle: ButtonStyle {
    var size: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        BarButton(configuration: configuration, size: size)
    }

    private struct BarButton: View {
        let configuration: ButtonStyleConfiguration
        let size: CGFloat

        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .padding(.horizontal, 4)
                .frame(minWidth: size, minHeight: size)
                .background(Color.secondary.opacity(highlight), in: .rect(cornerRadius: 5))
                .contentShape(.rect(cornerRadius: 5))
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .onHover { isHovered = $0 }
        }

        private var highlight: Double {
            guard isEnabled else { return 0 }
            return configuration.isPressed ? 0.28 : isHovered ? 0.14 : 0
        }
    }
}
