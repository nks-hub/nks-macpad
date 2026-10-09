import AppKit

func L(_ cs: String, _ en: String) -> String {
    Preferences.interfaceLanguage == "cs" ? cs : en
}

enum Preferences {
    static var interfaceLanguage: String {
        let language = UserDefaults.standard.string(forKey: "language") ?? Locale.preferredLanguages.first ?? "en"
        return language.hasPrefix("cs") ? "cs" : "en"
    }
    static var interfaceLocale: Locale { Locale(identifier: interfaceLanguage) }
    static var restore: Bool {
        get { UserDefaults.standard.object(forKey: "restore") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "restore") }
    }
    static var wrap: Bool {
        get { UserDefaults.standard.object(forKey: "wrap") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "wrap") }
    }
    static var fontSize: CGFloat {
        get { let size = UserDefaults.standard.double(forKey: "fontSize"); return size == 0 ? 14 : size }
        set { UserDefaults.standard.set(min(48, max(8, newValue)), forKey: "fontSize") }
    }
    static var font: NSFont {
        let name = UserDefaults.standard.string(forKey: "fontName") ?? ""
        return NSFont(name: name, size: fontSize) ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
    static func applyAppearance() {
        switch UserDefaults.standard.string(forKey: "appearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}
