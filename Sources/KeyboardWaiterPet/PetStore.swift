import Foundation

/// 宠物需要持久化的只有身份和窗口位置。
/// 成长值、阶段、心情全部实时从数据源算出来——不落盘就不会和真实数据对不上，
/// 应用没开的那几天也能补算回来。
public enum PetStore {
    private static let nameKey = "keyboard_waiter.pet.name"
    private static let birthKey = "keyboard_waiter.pet.birth"
    private static let visibleKey = "keyboard_waiter.pet.window_visible"
    private static let originXKey = "keyboard_waiter.pet.window_x"
    private static let originYKey = "keyboard_waiter.pet.window_y"

    public static var name: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? PetStrings.defaultName }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    public static var birthDate: Date {
        if let stored = UserDefaults.standard.object(forKey: birthKey) as? Date { return stored }
        let now = Date()
        UserDefaults.standard.set(now, forKey: birthKey)
        return now
    }

    public static var isWindowVisible: Bool {
        get { UserDefaults.standard.object(forKey: visibleKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: visibleKey) }
    }

    public static var windowOrigin: CGPoint? {
        get {
            guard
                let x = UserDefaults.standard.object(forKey: originXKey) as? Double,
                let y = UserDefaults.standard.object(forKey: originYKey) as? Double
            else { return nil }
            return CGPoint(x: x, y: y)
        }
        set {
            guard let newValue else { return }
            UserDefaults.standard.set(Double(newValue.x), forKey: originXKey)
            UserDefaults.standard.set(Double(newValue.y), forKey: originYKey)
        }
    }

    public static func reset() {
        for key in [nameKey, birthKey, visibleKey, originXKey, originYKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
