import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var menuTitle: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "中文"
        }
    }

    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en_US")
        case .simplifiedChinese:
            return Locale(identifier: "zh_Hans_CN")
        }
    }
}

enum AppLanguageStore {
    private static let defaultsKey = "keyboard_waiter.language"

    static var current: AppLanguage {
        guard
            let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
            let language = AppLanguage(rawValue: rawValue)
        else {
            return .english
        }

        return language
    }

    static func set(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: defaultsKey)
    }
}
