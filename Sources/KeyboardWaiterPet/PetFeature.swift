import AppKit
#if SWIFT_PACKAGE
import KeyboardWaiterCore
#endif

/// 宠物模块的门面，也是它和宿主之间**唯一**的接触面。
///
/// 装配（在 App 层）：
/// ```swift
/// let pet = PetFeature(statsStore: controller.statsStore)
/// controller.register(feature: pet)
/// ```
/// 拆掉宠物：删掉这个目录、Package.swift 里的 target、以及 main.swift 那几行。Core 一行不改。
public final class PetFeature: NSObject, AppFeature {
    private let source: PetObservationSource
    private let ecology: PetEcology
    private let spriteProvider: PetSpriteProvider

    private var windowController: PetHabitatWindowController?
    private var bestiaryController: PetBestiaryWindowController?
    private var snapshot: PetHabitatSnapshot?

    public init(
        source: PetObservationSource,
        ecology: PetEcology = PetEcology(),
        spriteProvider: PetSpriteProvider? = nil
    ) {
        self.source = source
        self.ecology = ecology
        self.spriteProvider = spriteProvider ?? Self.defaultSpriteProvider()
        super.init()
    }

    public convenience init(statsStore: StatsStore) {
        self.init(source: StatsStoreObservationSource(statsStore: statsStore))
    }

    // MARK: 开关

    private static let enabledKey = "keyboard_waiter.pet.enabled"

    public var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if !newValue { teardownWindow() }
        }
    }

    // MARK: AppFeature

    public func featureMenuItems() -> [NSMenuItem] {
        guard isEnabled else {
            return [menuItem(title: PetStrings.enableAction, action: #selector(toggleEnabled))]
        }

        let snapshot = refreshSnapshot()

        let status = NSMenuItem(title: PetStrings.habitatSummary(snapshot), action: nil, keyEquivalent: "")
        status.isEnabled = false

        var items: [NSMenuItem] = [status]

        // 今天有新发现就顶到菜单里，这是最值得看一眼的东西
        for speciesID in snapshot.newlyDiscovered {
            let item = NSMenuItem(title: PetStrings.newDiscovery(speciesID), action: nil, keyEquivalent: "")
            item.isEnabled = false
            items.append(item)
        }

        items.append(menuItem(title: PetStrings.openBestiaryAction, action: #selector(openBestiary)))
        items.append(menuItem(
            title: PetStore.isWindowVisible ? PetStrings.hidePetAction : PetStrings.showPetAction,
            action: #selector(toggleWindow)
        ))
        items.append(menuItem(title: PetStrings.disableAction, action: #selector(toggleEnabled)))

        return items
    }

    public func featureDidRefresh() {
        guard isEnabled else { return }
        let snapshot = refreshSnapshot()
        windowController?.update(snapshot: snapshot, spriteProvider: spriteProvider)
        bestiaryController?.update(snapshot: snapshot, spriteProvider: spriteProvider)
    }

    public func featureApplyLanguage(_ language: AppFeatureLanguage) {
        switch language {
        case .english: PetStrings.language = .english
        case .simplifiedChinese: PetStrings.language = .simplifiedChinese
        }
        featureDidRefresh()
    }

    public func featureWillTerminate() {
        teardownWindow()
    }

    public func restoreWindowIfNeeded() {
        guard isEnabled, PetStore.isWindowVisible else { return }
        showWindow()
    }

    // MARK: 图鉴推进

    @discardableResult
    public func refreshSnapshot() -> PetHabitatSnapshot {
        let today = StatsStoreObservationSource.startOfDay(Date(), calendar: .current)
        let adoptionDay = StatsStoreObservationSource.startOfDay(PetStore.birthDate, calendar: .current)

        // 只评估「领养之后」且「还没评估过」的日子。
        // 老用户装上不会一次性解锁一整本图鉴——那样第一天就通关了。
        let from = max(adoptionDay, (PetDiscoveryStore.lastEvaluatedDay ?? adoptionDay) - 86_400)
        let pending = source.petObservations(from: from, to: today)

        let discovered = Set(PetDiscoveryStore.discoveries.keys)
        let found = ecology.newDiscoveries(in: pending, alreadyDiscovered: discovered)

        for item in found {
            PetDiscoveryStore.record(speciesID: item.speciesID, on: item.dayStart)
        }
        PetDiscoveryStore.lastEvaluatedDay = today

        let recent = source.petObservations(
            from: today - Int64(ecology.vitalityWindowDays - 1) * 86_400,
            to: today
        )

        let snapshot = ecology.snapshot(
            discoveries: PetDiscoveryStore.discoveries,
            recentObservations: recent,
            newlyDiscovered: found.filter { $0.dayStart == today }.map(\.speciesID)
        )

        self.snapshot = snapshot
        return snapshot
    }

    // MARK: 窗口

    private func showWindow() {
        if windowController == nil {
            let controller = PetHabitatWindowController()
            controller.onOpenBestiary = { [weak self] in self?.openBestiary() }
            windowController = controller
        }

        windowController?.update(
            snapshot: snapshot ?? refreshSnapshot(),
            spriteProvider: spriteProvider
        )
        windowController?.show()
        PetStore.isWindowVisible = true
    }

    private func teardownWindow() {
        windowController?.hide()
        windowController = nil
    }

    @objc private func openBestiary() {
        if bestiaryController == nil {
            bestiaryController = PetBestiaryWindowController()
        }

        bestiaryController?.showAndActivate(
            snapshot: snapshot ?? refreshSnapshot(),
            spriteProvider: spriteProvider
        )
    }

    @objc private func toggleWindow() {
        if PetStore.isWindowVisible {
            teardownWindow()
            PetStore.isWindowVisible = false
        } else {
            showWindow()
        }
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        if isEnabled { restoreWindowIfNeeded() }
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    /// 有美术资源就用，没有就用代码画的占位形象。
    private static func defaultSpriteProvider() -> PetSpriteProvider {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("KeyboardWaiter/Pets")

        guard let directory, FileManager.default.fileExists(atPath: directory.path) else {
            return PetPlaceholderSpriteProvider()
        }

        return PetImageSetSpriteProvider(directory: directory)
    }
}
