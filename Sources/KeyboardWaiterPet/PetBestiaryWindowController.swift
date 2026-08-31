import AppKit

/// 图鉴窗口：把桌面上那片地翻译成人话。
///
/// 桌面栖息地是环境装饰，只负责「余光里有个东西在动」；
/// 「这是什么、为什么在这儿、还差哪些」全部在这里回答。
final class PetBestiaryWindowController: NSWindowController {
    private let scrollView = NSScrollView()
    private let contentView = PetBestiaryContentView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.89, alpha: 1.0)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = contentView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        window.contentView?.addSubview(scrollView)
        if let host = window.contentView {
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: host.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: host.bottomAnchor),
                contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            ])
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndActivate(snapshot: PetHabitatSnapshot, spriteProvider: PetSpriteProvider) {
        window?.title = PetStrings.bestiaryWindowTitle
        contentView.update(snapshot: snapshot, spriteProvider: spriteProvider)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func update(snapshot: PetHabitatSnapshot, spriteProvider: PetSpriteProvider) {
        guard window?.isVisible == true else { return }
        contentView.update(snapshot: snapshot, spriteProvider: spriteProvider)
    }
}

private final class PetBestiaryContentView: NSView {
    private static let rowHeight: CGFloat = 76
    private static let headerHeight: CGFloat = 92

    private var snapshot: PetHabitatSnapshot?
    private var spriteProvider: PetSpriteProvider?

    override var isFlipped: Bool { true }

    func update(snapshot: PetHabitatSnapshot, spriteProvider: PetSpriteProvider) {
        self.snapshot = snapshot
        self.spriteProvider = spriteProvider
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        let rows = snapshot?.totalSpecies ?? PetBestiary.all.count
        return NSSize(width: NSView.noIntrinsicMetric,
                      height: Self.headerHeight + CGFloat(rows) * Self.rowHeight + 24)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let snapshot, let spriteProvider else { return }

        drawHeader(snapshot: snapshot)

        var y = Self.headerHeight

        // 已发现的排在前面，最近活跃的更靠上
        for inhabitant in snapshot.inhabitants {
            drawRow(
                speciesID: inhabitant.speciesID,
                discovered: true,
                discoveredOn: inhabitant.discoveredOn,
                vitality: inhabitant.vitality,
                dormant: inhabitant.isDormant,
                progress: nil,
                awaitingStreak: false,
                revealsDomain: false,
                spriteProvider: spriteProvider,
                top: y
            )
            y += Self.rowHeight
        }

        for item in snapshot.pending {
            drawRow(
                speciesID: item.speciesID,
                discovered: false,
                discoveredOn: nil,
                vitality: 0,
                dormant: true,
                progress: item.bestStrength,
                awaitingStreak: item.awaitingStreak,
                revealsDomain: item.revealsDomain,
                spriteProvider: spriteProvider,
                top: y
            )
            y += Self.rowHeight
        }
    }

    private func drawHeader(snapshot: PetHabitatSnapshot) {
        let title = PetStrings.bestiaryHeadline(snapshot) as NSString
        title.draw(at: CGPoint(x: 20, y: 20), withAttributes: [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.12, alpha: 1)
        ])

        let subtitle = PetStrings.bestiaryExplanation as NSString
        subtitle.draw(in: CGRect(x: 20, y: 48, width: bounds.width - 40, height: 34), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor(calibratedRed: 0.40, green: 0.37, blue: 0.30, alpha: 1)
        ])
    }

    private func drawRow(
        speciesID: String,
        discovered: Bool,
        discoveredOn: Int64?,
        vitality: Double,
        dormant: Bool,
        progress: Double?,
        awaitingStreak: Bool,
        revealsDomain: Bool,
        spriteProvider: PetSpriteProvider,
        top: CGFloat
    ) {
        let card = CGRect(x: 16, y: top, width: bounds.width - 32, height: Self.rowHeight - 8)
        let path = NSBezierPath(roundedRect: card, xRadius: 12, yRadius: 12)

        if discovered {
            NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.87, alpha: 1).setFill()
        } else {
            NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.86, alpha: 1).setFill()
        }
        path.fill()
        NSColor(calibratedRed: 0.84, green: 0.79, blue: 0.66, alpha: 1).setStroke()
        path.lineWidth = 1
        path.stroke()

        // 形象。没发现的画成剪影，让人知道「有个东西在那儿等着」
        let spriteRect = CGRect(x: card.minX + 12, y: card.minY + 8, width: 52, height: 52)
        let image = spriteProvider.image(speciesID: speciesID, dormant: dormant, size: 52)
        if discovered {
            image.draw(in: spriteRect)
        } else {
            image.draw(in: spriteRect, from: .zero, operation: .sourceOver, fraction: 0.22)
        }

        let textX = card.minX + 76
        let textWidth = card.width - 92

        let name = (discovered ? PetStrings.speciesName(speciesID) : PetStrings.undiscoveredName) as NSString
        name.draw(at: CGPoint(x: textX, y: card.minY + 10), withAttributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.12, alpha: discovered ? 1 : 0.55)
        ])

        // 发现之后才揭晓条件——这是解锁那一刻的回报，也是探索感的来源
        let condition = (discovered
            ? PetStrings.speciesHint(speciesID)
            : PetStrings.pendingCondition(speciesID: speciesID, revealsDomain: revealsDomain)) as NSString
        condition.draw(in: CGRect(x: textX, y: card.minY + 30, width: textWidth, height: 18), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: discovered ? .regular : .light),
            .foregroundColor: NSColor(calibratedRed: 0.40, green: 0.37, blue: 0.30, alpha: discovered ? 1 : 0.6)
        ])

        let status: String
        if discovered {
            status = PetStrings.discoveredStatus(on: discoveredOn ?? 0, vitality: vitality, dormant: dormant)
        } else {
            status = PetStrings.pendingStatus(progress: progress ?? 0, awaitingStreak: awaitingStreak)
        }

        (status as NSString).draw(in: CGRect(x: textX, y: card.minY + 48, width: textWidth, height: 16), withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor(calibratedRed: 0.46, green: 0.42, blue: 0.33, alpha: 1)
        ])

        // 未发现的画一条进度条，让「差一点」变得可见
        if let progress, progress > 0.05 {
            let barWidth = textWidth * 0.45
            let barRect = CGRect(x: card.maxX - barWidth - 14, y: card.minY + 12, width: barWidth, height: 6)
            NSColor(calibratedRed: 0.88, green: 0.85, blue: 0.78, alpha: 1).setFill()
            NSBezierPath(roundedRect: barRect, xRadius: 3, yRadius: 3).fill()
            NSColor(calibratedRed: 0.86, green: 0.66, blue: 0.28, alpha: 1).setFill()
            NSBezierPath(
                roundedRect: CGRect(x: barRect.minX, y: barRect.minY,
                                    width: max(4, barRect.width * CGFloat(min(1, progress))), height: barRect.height),
                xRadius: 3, yRadius: 3
            ).fill()
        }
    }
}
