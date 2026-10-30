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
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.brand(14))
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .foregroundStyle(prominent ? Color(nsColor: .textBackgroundColor) : Color.primary)
            .background(prominent ? Color.primary.opacity(0.88) : Color.primary.opacity(0.03), in: Capsule())
            .overlay { if !prominent { Capsule().strokeBorder(Color.primary.opacity(0.12)) } }
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
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
