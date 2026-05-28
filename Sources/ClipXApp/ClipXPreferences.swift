import AppKit
import SwiftUI

extension Notification.Name {
    static let clipXAppearanceChanged = Notification.Name("ClipXAppearanceChanged")
    static let clipXLanguageChanged = Notification.Name("ClipXLanguageChanged")
    static let clipXShortcutChanged = Notification.Name("ClipXShortcutChanged")
    static let clipXShortcutRecordingChanged = Notification.Name("ClipXShortcutRecordingChanged")
}

enum ClipXTheme: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.t("System")
        case .dark: L10n.t("Dark")
        case .light: L10n.t("Light")
        }
    }
}

struct ClipXLanguageOption: Identifiable, Equatable {
    let code: String
    let title: String

    var id: String { code }

    static let options: [ClipXLanguageOption] = [
        .init(code: "system", title: "System"),
        .init(code: "en", title: "English"),
        .init(code: "zh-Hans", title: "简体中文"),
        .init(code: "zh-Hant", title: "繁體中文"),
        .init(code: "ja", title: "日本語"),
        .init(code: "ko", title: "한국어"),
        .init(code: "fr", title: "Français"),
        .init(code: "de", title: "Deutsch"),
        .init(code: "es", title: "Español"),
        .init(code: "pt-BR", title: "Português"),
        .init(code: "ru", title: "Русский")
    ]
}

enum ClipXAppearance {
    static var theme: ClipXTheme {
        get { ClipXTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "dark") ?? .dark }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "appTheme") }
    }

    static var pureBlackGlass: Bool {
        get {
            if UserDefaults.standard.object(forKey: "pureBlackGlass") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "pureBlackGlass")
        }
        set { UserDefaults.standard.set(newValue, forKey: "pureBlackGlass") }
    }

    static var reduceTransparency: Bool {
        get { UserDefaults.standard.bool(forKey: "reduceTransparency") }
        set { UserDefaults.standard.set(newValue, forKey: "reduceTransparency") }
    }

    static var selectedLanguageCode: String {
        get { UserDefaults.standard.string(forKey: "languageCode") ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: "languageCode") }
    }

    static var preferredColorScheme: ColorScheme? {
        switch theme {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    static var isDarkMode: Bool {
        switch theme {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua
        }
    }

    static var glassOverlayAlpha: CGFloat {
        if reduceTransparency {
            return isDarkMode ? 0.94 : 0.82
        }
        if pureBlackGlass {
            return isDarkMode ? 0.78 : 0.50
        }
        return isDarkMode ? 0.58 : 0.34
    }

    static var titlebarAlpha: CGFloat {
        if reduceTransparency {
            return isDarkMode ? 0.13 : 0.78
        }
        return isDarkMode ? 0.055 : 0.58
    }

    static var visualEffectMaterial: NSVisualEffectView.Material {
        if reduceTransparency {
            return isDarkMode ? .underWindowBackground : .contentBackground
        }
        return isDarkMode ? .hudWindow : .sidebar
    }

    static func notifyAppearanceChanged() {
        NotificationCenter.default.post(name: .clipXAppearanceChanged, object: nil)
    }

    static func notifyLanguageChanged() {
        NotificationCenter.default.post(name: .clipXLanguageChanged, object: nil)
    }
}
