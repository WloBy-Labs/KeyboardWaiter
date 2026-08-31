import AppKit

/// 宿主向外提供的语言，避免功能模块去读 Core 的内部本地化状态。
public enum AppFeatureLanguage {
    case english
    case simplifiedChinese
}

/// 可插拔功能模块的扩展点。
///
/// Core **不认识任何具体模块**——它只知道有这么一个协议，谁来实现由 App 层在启动时决定。
/// 模块要做的是：贡献几个菜单项、在刷新时更新自己、跟随语言切换、退出时收尾。
public protocol AppFeature: AnyObject {
    /// 插进状态栏菜单的条目，会被放在独立的分隔区里。
    func featureMenuItems() -> [NSMenuItem]
    /// 宿主的周期刷新（默认 15 秒）以及统计发生变化时调用。
    func featureDidRefresh()
    func featureApplyLanguage(_ language: AppFeatureLanguage)
    func featureWillTerminate()
}

public extension AppFeature {
    func featureMenuItems() -> [NSMenuItem] { [] }
    func featureDidRefresh() {}
    func featureApplyLanguage(_ language: AppFeatureLanguage) {}
    func featureWillTerminate() {}
}
