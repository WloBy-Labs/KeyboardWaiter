import AppKit

/// 栖息地窗口：一小片地，住着已经发现的物种。
///
/// 关键点：必须是 `.nonactivatingPanel`。菜单栏应用一旦弹出普通窗口就会成为前台应用，
/// 那一刻的按键会被归到宿主头上，污染「输入发生在哪个应用」的统计。
final class PetHabitatWindowController: NSWindowController {
    private let habitatView = PetHabitatView()

    /// 点一下这片地就打开图鉴——桌面上这个东西必须有个「看懂它」的入口
    var onOpenBestiary: (() -> Void)? {
        get { habitatView.onClick }
        set { habitatView.onClick = newValue }
    }

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: PetHabitatView.defaultWidth, height: PetHabitatView.defaultHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = habitatView

        super.init(window: panel)
        restorePosition()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        restorePosition()
        window?.orderFrontRegardless()
    }

    func hide() {
        if let origin = window?.frame.origin { PetStore.windowOrigin = origin }
        window?.orderOut(nil)
    }

    func update(snapshot: PetHabitatSnapshot, spriteProvider: PetSpriteProvider) {
        habitatView.update(snapshot: snapshot, spriteProvider: spriteProvider)
    }

    private func restorePosition() {
        guard let window else { return }

        if let origin = PetStore.windowOrigin, isOnScreen(origin) {
            window.setFrameOrigin(origin)
            return
        }

        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        window.setFrameOrigin(
            CGPoint(x: frame.maxX - PetHabitatView.defaultWidth - 24, y: frame.minY + 24)
        )
    }

    /// 换过显示器之后上次记的位置可能已经在屏幕外
    private func isOnScreen(_ origin: CGPoint) -> Bool {
        let probe = CGRect(origin: origin,
                           size: CGSize(width: PetHabitatView.defaultWidth, height: PetHabitatView.defaultHeight))
        return NSScreen.screens.contains { $0.frame.intersects(probe) }
    }
}

private final class PetHabitatView: NSView {
    static let defaultWidth: CGFloat = 260
    static let defaultHeight: CGFloat = 132
    private static let maxVisible = 5

    var onClick: (() -> Void)?
    private var snapshot: PetHabitatSnapshot?
    private var spriteProvider: PetSpriteProvider?
    private var phase: CGFloat = 0
    private var timer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
            self?.phase += 0.1
            self?.needsDisplay = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { timer?.invalidate() }

    func update(snapshot: PetHabitatSnapshot, spriteProvider: PetSpriteProvider) {
        self.snapshot = snapshot
        self.spriteProvider = spriteProvider
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let snapshot, let spriteProvider else { return }

        drawGround()

        let visible = Array(snapshot.inhabitants.prefix(Self.maxVisible))
        guard !visible.isEmpty else {
            drawEmptyHint(count: snapshot.totalSpecies)
            return
        }

        // 活跃的画大、靠前；冬眠的小一圈、半透明
        let slotWidth = bounds.width / CGFloat(visible.count)
        for (index, inhabitant) in visible.enumerated() {
            let baseSize: CGFloat = inhabitant.isDormant ? 34 : 40 + CGFloat(inhabitant.vitality) * 10
            let x = slotWidth * (CGFloat(index) + 0.5) - baseSize / 2
            // 每只错开相位，看起来不是整齐划一地跳
            let bob = inhabitant.isDormant
                ? 0
                : sin((phase + CGFloat(index) * 0.7) * 1.6) * (1.5 + CGFloat(inhabitant.vitality) * 2)

            let image = spriteProvider.image(
                speciesID: inhabitant.speciesID,
                dormant: inhabitant.isDormant,
                size: baseSize
            )
            image.draw(in: CGRect(x: x, y: 34 + bob, width: baseSize, height: baseSize))

            // 名字必须写出来，否则没人知道这是什么
            let name = PetStrings.speciesName(inhabitant.speciesID) as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: NSColor(calibratedRed: 0.30, green: 0.27, blue: 0.20,
                                          alpha: inhabitant.isDormant ? 0.5 : 1.0)
            ]
            let textWidth = name.size(withAttributes: attributes).width
            name.draw(at: CGPoint(x: slotWidth * (CGFloat(index) + 0.5) - textWidth / 2, y: 20),
                      withAttributes: attributes)
        }

        drawCaption(snapshot: snapshot)
    }

    override func mouseUp(with event: NSEvent) {
        // 拖动不算点击
        if event.clickCount == 1 { onClick?() }
        super.mouseUp(with: event)
    }

    private func drawGround() {
        let ground = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: bounds.width, height: 34),
                                  xRadius: 14, yRadius: 14)
        NSColor(calibratedRed: 0.90, green: 0.86, blue: 0.76, alpha: 0.9).setFill()
        ground.fill()
    }

    private func drawCaption(snapshot: PetHabitatSnapshot) {
        let text = PetStrings.habitatCaption(snapshot) as NSString
        text.draw(
            at: CGPoint(x: 10, y: 9),
            withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor(calibratedRed: 0.34, green: 0.31, blue: 0.24, alpha: 1.0)
            ]
        )
    }

    private func drawEmptyHint(count: Int) {
        let text = PetStrings.emptyHabitatHint as NSString
        text.draw(
            in: CGRect(x: 12, y: 44, width: bounds.width - 24, height: 40),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor(calibratedRed: 0.38, green: 0.35, blue: 0.28, alpha: 1.0)
            ]
        )
    }
}
