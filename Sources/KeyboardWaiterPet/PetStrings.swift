import Foundation

/// 模块自带文案，不依赖宿主的本地化系统——宿主只需要告诉它当前语言。
public enum PetStrings {
    public static var language: PetLanguage = .english

    public static var defaultName: String {
        switch language {
        case .english: return "Waiter"
        case .simplifiedChinese: return "小待"
        }
    }

    private static let speciesNamesZH: [String: String] = [
        "nightowl": "夜行种", "earlybird": "晨光种", "sprinter": "疾行种",
        "shortcut": "捷径种", "wanderer": "远行种", "nomad": "游牧种",
        "burrower": "深耕种", "reviser": "反复种", "ambidexter": "双持种",
        "marathoner": "长驻种"
    ]

    private static let speciesNamesEN: [String: String] = [
        "nightowl": "Night Owl", "earlybird": "Early Bird", "sprinter": "Sprinter",
        "shortcut": "Shortcutter", "wanderer": "Wanderer", "nomad": "Nomad",
        "burrower": "Burrower", "reviser": "Reviser", "ambidexter": "Ambidexter",
        "marathoner": "Marathoner"
    ]

    private static let speciesHintsZH: [String: String] = [
        "nightowl": "连续三天在凌晨还在敲",
        "earlybird": "连续三天清晨就开工",
        "sprinter": "一天敲够两万次",
        "shortcut": "修饰键占比超过 15%",
        "wanderer": "一天指针走过 100 米",
        "nomad": "一天里在八个应用间穿梭",
        "burrower": "一天七成输入集中在一个应用",
        "reviser": "删除键占比超过 12%",
        "ambidexter": "键盘和指针各占一半",
        "marathoner": "一天里有十二个小时在动"
    ]

    private static let speciesHintsEN: [String: String] = [
        "nightowl": "Active after midnight three days running",
        "earlybird": "Up and typing early three days running",
        "sprinter": "20,000 keys in a single day",
        "shortcut": "Modifier keys above 15% of all presses",
        "wanderer": "100 metres of pointer travel in a day",
        "nomad": "Input across eight apps in one day",
        "burrower": "70% of a day inside a single app",
        "reviser": "Delete key above 12% of all presses",
        "ambidexter": "Keyboard and pointer split evenly",
        "marathoner": "Twelve active hours in one day"
    ]

    public static func speciesName(_ id: String) -> String {
        switch language {
        case .english: return speciesNamesEN[id] ?? id
        case .simplifiedChinese: return speciesNamesZH[id] ?? id
        }
    }

    public static func speciesHint(_ id: String) -> String {
        switch language {
        case .english: return speciesHintsEN[id] ?? ""
        case .simplifiedChinese: return speciesHintsZH[id] ?? ""
        }
    }

    public static func habitatSummary(_ snapshot: PetHabitatSnapshot) -> String {
        switch language {
        case .english:
            return "Habitat · \(snapshot.discoveredCount)/\(snapshot.totalSpecies) species"
        case .simplifiedChinese:
            return "栖息地 · 已发现 \(snapshot.discoveredCount)/\(snapshot.totalSpecies) 种"
        }
    }

    public static func newDiscovery(_ speciesID: String) -> String {
        switch language {
        case .english: return "  New today: \(speciesName(speciesID))"
        case .simplifiedChinese: return "  今天新发现：\(speciesName(speciesID))"
        }
    }

    public static var bestiaryWindowTitle: String {
        switch language {
        case .english: return "Habitat Field Guide"
        case .simplifiedChinese: return "栖息地图鉴"
        }
    }

    public static func bestiaryHeadline(_ snapshot: PetHabitatSnapshot) -> String {
        switch language {
        case .english: return "\(snapshot.discoveredCount) of \(snapshot.totalSpecies) species found"
        case .simplifiedChinese: return "已发现 \(snapshot.discoveredCount) / \(snapshot.totalSpecies) 种"
        }
    }

    public static var bestiaryExplanation: String {
        switch language {
        case .english:
            return "Species appear on their own, from how you actually use this Mac. "
                + "What summons each one stays unknown until it shows up."
        case .simplifiedChinese:
            return "物种是从你实际怎么用这台电脑里自己冒出来的。"
                + "把它们引来的条件，要等它出现那天才会揭晓。"
        }
    }

    public static var undiscoveredName: String {
        switch language {
        case .english: return "? ? ?"
        case .simplifiedChinese: return "？ ？ ？"
        }
    }

    /// 未发现物种的条件藏起来——解锁那一刻才揭晓，才有「原来是因为这个」的回报。
    public static var undiscoveredCondition: String {
        switch language {
        case .english: return "Condition unknown"
        case .simplifiedChinese: return "条件未知"
        }
    }

    public static func discoveredStatus(on dayStart: Int64, vitality: Double, dormant: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = language == .english ? "MMM d" : "M 月 d 日"
        let date = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(dayStart)))

        switch language {
        case .english:
            return dormant
                ? "Found \(date) · dormant, you haven't done this lately"
                : String(format: "Found %@ · active %.0f%%", date, vitality * 100)
        case .simplifiedChinese:
            return dormant
                ? "\(date) 发现 · 冬眠中，最近没这么用了"
                : String(format: "%@ 发现 · 活跃度 %.0f%%", date, vitality * 100)
        }
    }

    public static func domainHint(_ domain: PetSpeciesDomain) -> String {
        switch (language, domain) {
        case (.english, .rhythm): return "something about when you work"
        case (.english, .keyboard): return "something about how you type"
        case (.english, .pointer): return "something about the pointer"
        case (.english, .apps): return "something about the apps you use"
        case (.simplifiedChinese, .rhythm): return "和你什么时候工作有关"
        case (.simplifiedChinese, .keyboard): return "和你怎么敲键盘有关"
        case (.simplifiedChinese, .pointer): return "和指针有关"
        case (.simplifiedChinese, .apps): return "和你用哪些应用有关"
        }
    }

    /// 未发现物种的条件行：默认藏着，接近了才透露方向。
    public static func pendingCondition(speciesID: String, revealsDomain: Bool) -> String {
        guard revealsDomain, let species = PetBestiary.species(id: speciesID) else {
            return undiscoveredCondition
        }
        return species.domainHint
    }

    public static func pendingStatus(progress: Double, awaitingStreak: Bool) -> String {
        switch language {
        case .english:
            if awaitingStreak { return "Touched it once — it did not hold" }
            if progress >= 0.85 { return String(format: "Very close: %.0f%%", progress * 100) }
            return progress < 0.05
                ? "No sign of it lately"
                : String(format: "Closest this week: %.0f%%", progress * 100)
        case .simplifiedChinese:
            if awaitingStreak { return "触碰过一次 · 但没能延续" }
            if progress >= 0.85 { return String(format: "很接近了：%.0f%%", progress * 100) }
            return progress < 0.05
                ? "最近没有它的踪迹"
                : String(format: "最近一周最接近：%.0f%%", progress * 100)
        }
    }

    public static func habitatCaption(_ snapshot: PetHabitatSnapshot) -> String {
        switch language {
        case .english: return "\(snapshot.discoveredCount)/\(snapshot.totalSpecies) · click for guide"
        case .simplifiedChinese: return "\(snapshot.discoveredCount)/\(snapshot.totalSpecies) 种 · 点击查看图鉴"
        }
    }

    public static var openBestiaryAction: String {
        switch language {
        case .english: return "Open Field Guide..."
        case .simplifiedChinese: return "打开图鉴…"
        }
    }

    public static var emptyHabitatHint: String {
        switch language {
        case .english: return "Nothing has moved in yet.\nKeep working — species appear on their own."
        case .simplifiedChinese: return "还没有东西住进来。\n照常用电脑，物种会自己出现。"
        }
    }

    public static var showPetAction: String {
        switch language {
        case .english: return "Show Desktop Pet"
        case .simplifiedChinese: return "显示桌宠"
        }
    }

    public static var hidePetAction: String {
        switch language {
        case .english: return "Hide Desktop Pet"
        case .simplifiedChinese: return "隐藏桌宠"
        }
    }

    public static var renameAction: String {
        switch language {
        case .english: return "Rename Pet..."
        case .simplifiedChinese: return "给宠物改名…"
        }
    }

    public static var renamePrompt: String {
        switch language {
        case .english: return "What should your pet be called?"
        case .simplifiedChinese: return "给宠物起个名字"
        }
    }

    public static var enableAction: String {
        switch language {
        case .english: return "Enable Pet"
        case .simplifiedChinese: return "启用宠物"
        }
    }

    public static var disableAction: String {
        switch language {
        case .english: return "Turn Off Pet"
        case .simplifiedChinese: return "关闭宠物"
        }
    }

    public static var confirmAction: String {
        switch language {
        case .english: return "OK"
        case .simplifiedChinese: return "确定"
        }
    }

    public static var cancelAction: String {
        switch language {
        case .english: return "Cancel"
        case .simplifiedChinese: return "取消"
        }
    }
}
