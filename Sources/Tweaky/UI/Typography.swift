import CoreText
import SwiftUI

extension Font {
    /// Google Sans (OFL, bundled in Resources/Fonts); falls back to the system font if it is not registered.
    static func brand(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Google Sans", size: size).weight(weight)
    }
}

enum BrandFont {
    /// Registers the bundled font for this process only; nothing is installed system-wide.
    static func register() {
        guard let url = Bundle.main.url(forResource: "GoogleSans", withExtension: "ttf", subdirectory: "Fonts") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

/// Text-only pill buttons: near-black filled for the main action, hairline outline otherwise.
struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        PillButton(configuration: configuration, prominent: prominent)
    }
}

/// Separate view so the pill can track hover, like the landing page buttons.
private struct PillButton: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(.brand(14, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(fill, in: Capsule())
            .overlay { if !prominent { Capsule().strokeBorder(Color.primary.opacity(isActive ? 0.22 : 0.12)) } }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.14), value: isActive)
    }

    private var isActive: Bool { isEnabled && (isHovered || configuration.isPressed) }

    private var fill: Color {
        if prominent {
            // #2B2B2B at rest, #1F1F1F on hover; stays dark in Dark Mode so the label stays white.
            return isActive ? Color(white: 0.12) : Color(white: 0.17)
        }
        return Color.primary.opacity(isActive ? 0.07 : 0.03)
    }
}

/// Light translucency: behind-window blur under a mostly opaque surface, so the UI stays calm and readable.
struct BrandSurface: View {
    var body: some View {
        ZStack {
            BehindWindowBlur()
            Color(nsColor: .textBackgroundColor).opacity(0.78)
        }
    }
}

private struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
