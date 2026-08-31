import AppKit

/// 形象来源。现在是代码画的占位图，美术交付后换成 `PetImageSetSpriteProvider`，
/// 上层只认这个协议，不关心图从哪来。
public protocol PetSpriteProvider: AnyObject {
    /// - Parameters:
    ///   - dormant: 冬眠态（最近没在做这件事了），通常画成闭眼/褪色
    func image(speciesID: String, dormant: Bool, size: CGFloat) -> NSImage
}

/// 按约定文件名从目录加载：`<物种id>.png` 和 `<物种id>_dormant.png`。
/// 缺图时回退到占位图，所以美术可以一批一批交，不用一次交齐。
public final class PetImageSetSpriteProvider: PetSpriteProvider {
    private let directory: URL
    private let fallback: PetSpriteProvider
    private var cache: [String: NSImage] = [:]

    public init(directory: URL, fallback: PetSpriteProvider = PetPlaceholderSpriteProvider()) {
        self.directory = directory
        self.fallback = fallback
    }

    public func image(speciesID: String, dormant: Bool, size: CGFloat) -> NSImage {
        let key = dormant ? "\(speciesID)_dormant" : speciesID
        if let cached = cache[key] { return cached }

        // 没有单独的冬眠图就退回常态图，再没有才用占位
        let candidates = dormant ? [key, speciesID] : [key]
        for candidate in candidates {
            if let image = NSImage(contentsOf: directory.appendingPathComponent("\(candidate).png")) {
                cache[key] = image
                return image
            }
        }

        return fallback.image(speciesID: speciesID, dormant: dormant, size: size)
    }
}
