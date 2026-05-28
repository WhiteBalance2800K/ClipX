import AppKit
import SwiftUI

enum ClipXColor {
    private static var dark: Bool { ClipXAppearance.isDarkMode }
    private static var solid: Bool { ClipXAppearance.reduceTransparency }
    private static var pure: Bool { ClipXAppearance.pureBlackGlass }

    static var canvas: Color {
        dark ? .black : Color(hex: 0xF4F5F7)
    }

    static var canvas2: Color {
        dark ? Color(hex: 0x050505) : Color(hex: 0xECEFF3)
    }

    static var appContent: Color {
        dark ? Color.black.opacity(solid ? 0.54 : 0.18) : Color.white.opacity(solid ? 0.84 : 0.50)
    }

    static var sidebar: Color {
        if dark {
            return Color.white.opacity(solid ? 0.078 : (pure ? 0.052 : 0.070))
        }
        return Color(hex: 0xEEF2F7).opacity(solid ? 0.96 : 0.86)
    }

    static var panel: Color {
        if dark {
            return Color.white.opacity(solid ? 0.052 : (pure ? 0.028 : 0.045))
        }
        return Color(hex: 0xF7F9FC).opacity(solid ? 0.98 : 0.88)
    }

    static var surface: Color {
        dark ? Color.white.opacity(solid ? 0.095 : 0.052) : Color(hex: 0xFFFFFF).opacity(solid ? 1.0 : 0.92)
    }

    static var surfaceStrong: Color {
        dark ? Color.white.opacity(solid ? 0.13 : 0.078) : Color(hex: 0xF1F2F5).opacity(solid ? 1.0 : 0.96)
    }

    static var raised: Color {
        dark ? Color.white.opacity(solid ? 0.11 : 0.066) : Color(hex: 0xFFFFFF).opacity(solid ? 1.0 : 0.90)
    }

    static var raisedStrong: Color {
        dark ? Color.white.opacity(solid ? 0.18 : 0.11) : Color(hex: 0xE8EAEE)
    }

    static var text: Color {
        dark ? Color(hex: 0xF6F7F9) : Color(hex: 0x16191F)
    }

    static var textSoft: Color {
        dark ? Color(hex: 0xC7CBD3) : Color(hex: 0x333843)
    }

    static var muted: Color {
        dark ? Color(hex: 0x858B96) : Color(hex: 0x697180)
    }

    static var border: Color {
        dark ? Color.white.opacity(solid ? 0.09 : 0.070) : Color.black.opacity(0.075)
    }

    static var borderStrong: Color {
        dark ? Color.white.opacity(solid ? 0.18 : 0.145) : Color.black.opacity(0.13)
    }

    static var separator: Color {
        dark ? Color.white.opacity(solid ? 0.065 : 0.045) : Color.black.opacity(0.060)
    }

    static var accent: Color {
        dark ? Color(hex: 0xF6F7F9) : Color(hex: 0x155EEF)
    }

    static var accent2: Color {
        dark ? Color(hex: 0xA8AFBC) : Color(hex: 0x2563EB)
    }

    static var accentSoft: Color {
        dark ? Color.white.opacity(solid ? 0.16 : 0.12) : Color(hex: 0xDBEAFE)
    }

    static var selection: Color {
        dark ? Color.white.opacity(solid ? 0.18 : 0.12) : Color(hex: 0xE8EAEE)
    }

    static var selectionBorder: Color {
        dark ? Color.white.opacity(0.24) : Color(hex: 0xC4CAD3).opacity(0.95)
    }

    static var mint: Color { Color(hex: 0x42D6A4) }
    static var mintSoft: Color { Color(hex: 0x42D6A4).opacity(dark ? 0.14 : 0.18) }
    static var amber: Color { Color(hex: 0xF0BE4E) }
    static var amberSoft: Color { Color(hex: 0xF0BE4E).opacity(dark ? 0.16 : 0.22) }
    static var danger: Color { Color(hex: 0xEF6A68) }
    static var dangerSoft: Color { Color(hex: 0xEF6A68).opacity(dark ? 0.14 : 0.18) }

    static var codeBackground: Color {
        dark ? Color.black.opacity(solid ? 0.58 : 0.36) : Color(hex: 0xFFFFFF).opacity(solid ? 1.0 : 0.92)
    }

    static var glassOverlay: Color {
        dark ? Color.black.opacity(ClipXAppearance.glassOverlayAlpha) : Color.white.opacity(ClipXAppearance.glassOverlayAlpha)
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = ClipXAppearance.visualEffectMaterial
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = ClipXAppearance.visualEffectMaterial
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct Keycap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(ClipXColor.textSoft)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(ClipXColor.raised)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(ClipXColor.border)
            )
    }
}

struct ClipTag: View {
    enum Tone {
        case neutral
        case accent
        case mint
        case amber
        case danger

        var foreground: Color {
            switch self {
            case .neutral: ClipXColor.muted
            case .accent: ClipXColor.accent
            case .mint: ClipXColor.mint
            case .amber: ClipXColor.amber
            case .danger: ClipXColor.danger
            }
        }

        var background: Color {
            switch self {
            case .neutral: ClipXColor.raised
            case .accent: ClipXColor.accentSoft
            case .mint: ClipXColor.mintSoft
            case .amber: ClipXColor.amberSoft
            case .danger: ClipXColor.dangerSoft
            }
        }
    }

    let text: String
    var tone: Tone = .neutral

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(tone.background)
            .clipShape(Capsule())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isDanger = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isDanger ? ClipXColor.danger : Color.black)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ClipXColor.border)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    private var background: some ShapeStyle {
        if isDanger {
            return AnyShapeStyle(ClipXColor.dangerSoft)
        }
        return AnyShapeStyle(LinearGradient(colors: [ClipXColor.accent, ClipXColor.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ClipXColor.textSoft)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(configuration.isPressed ? ClipXColor.raisedStrong : ClipXColor.surfaceStrong)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
