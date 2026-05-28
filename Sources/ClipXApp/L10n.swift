import Foundation

enum L10n {
    static func t(_ key: String) -> String {
        let activeBundle = languageBundle(for: ClipXAppearance.selectedLanguageCode)
        let translated = activeBundle.localizedString(forKey: key, value: nil, table: nil)
        if translated != key {
            return translated
        }
        return englishFallbackBundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static let resourceBundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("ClipX_ClipXApp.bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        if let bundle = Bundle(url: Bundle.main.bundleURL.appendingPathComponent("ClipX_ClipXApp.bundle")) {
            return bundle
        }
        return .module
    }()

    private static let englishFallbackBundle: Bundle = {
        languageBundle(for: "en")
    }()

    private static func languageBundle(for storedCode: String) -> Bundle {
        let code: String
        if storedCode == "system" {
            code = Locale.current.language.languageCode?.identifier == "zh" ? "zh-Hans" : "en"
        } else {
            code = storedCode
        }

        let candidates = [code, code.replacingOccurrences(of: "-", with: "_"), String(code.prefix(2))]
        for candidate in candidates {
            if let path = resourceBundle.path(forResource: candidate.lowercased(), ofType: "lproj") ??
                resourceBundle.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return resourceBundle
    }
}
