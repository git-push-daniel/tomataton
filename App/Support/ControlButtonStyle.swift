import SwiftUI

/// Icon with a caption underneath. Used for the main timer controls so their
/// meaning is visible without tooltips, which macOS doesn't show in menu bar popovers.
struct ControlButtonStyle: ButtonStyle {
    var tint: Color
    var prominent = false
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        ControlButton(configuration: configuration, tint: tint, prominent: prominent, large: large)
    }

    private struct ControlButton: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color
        let prominent: Bool
        let large: Bool

        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .labelStyle(StackedLabelStyle(large: large))
                .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .frame(minWidth: large ? 68 : 56)
                .padding(.vertical, large ? 10 : 6)
                .padding(.horizontal, 6)
                .background(background, in: .rect(cornerRadius: 8))
                .contentShape(.rect(cornerRadius: 8))
                .opacity(isEnabled ? 1 : 0.4)
                .onHover { isHovered = $0 }
        }

        private var background: AnyShapeStyle {
            if prominent {
                return AnyShapeStyle(tint.opacity(configuration.isPressed ? 0.75 : isHovered ? 0.9 : 1))
            }
            let opacity = configuration.isPressed ? 0.28 : isHovered ? 0.2 : 0.12
            return AnyShapeStyle(Color.secondary.opacity(opacity))
        }
    }
}

private struct StackedLabelStyle: LabelStyle {
    var large: Bool

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 3) {
            configuration.icon
                .font(large ? .title2 : .title3)
                .frame(height: large ? 26 : 22)
            configuration.title
                .font(large ? .caption : .caption2)
        }
    }
}
