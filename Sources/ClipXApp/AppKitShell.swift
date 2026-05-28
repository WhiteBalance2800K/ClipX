import AppKit
import SwiftUI

extension Notification.Name {
    static let clipXFocusSearch = Notification.Name("ClipXFocusSearch")
}

final class ClipXWindow: NSWindow {
    var keyDownHandler: ((NSEvent) -> Bool)?

    private let chromeView: ClipXChromeView

    init(size: NSSize, title: String, hostedView: NSView, isFloating: Bool = false) {
        chromeView = ClipXChromeView(title: title)
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.title = title
        identifier = NSUserInterfaceItemIdentifier(title)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.fullScreenNone]
        if isFloating {
            level = .floating
        }

        chromeView.setContentView(hostedView)
        contentView = chromeView
    }

    func updateStatus(_ status: String) {
        chromeView.updateStatus(status)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyDownHandler?(event) == true {
            return
        }
        super.sendEvent(event)
    }

}

private final class ClipXChromeView: NSView {
    private static let titlebarHeight: CGFloat = 0

    private let visualEffectView = NSVisualEffectView()
    private let glassOverlay = NSView()
    private let titlebarView: ClipXTitlebarView
    private let contentContainer = NSView()
    private var appearanceObserver: NSObjectProtocol?

    init(title: String) {
        titlebarView = ClipXTitlebarView(title: title)
        super.init(frame: .zero)
        setup()
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: .clipXAppearanceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyAppearance()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
        }
    }

    func setContentView(_ view: NSView) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }

    func updateStatus(_ status: String) {
        titlebarView.updateStatus(status)
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        visualEffectView.material = ClipXAppearance.visualEffectMaterial
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        glassOverlay.wantsLayer = true
        glassOverlay.translatesAutoresizingMaskIntoConstraints = false

        titlebarView.translatesAutoresizingMaskIntoConstraints = false
        titlebarView.isHidden = true
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.wantsLayer = true
        contentContainer.layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(visualEffectView)
        addSubview(glassOverlay)
        addSubview(titlebarView)
        addSubview(contentContainer)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            glassOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassOverlay.topAnchor.constraint(equalTo: topAnchor),
            glassOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            titlebarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            titlebarView.trailingAnchor.constraint(equalTo: trailingAnchor),
            titlebarView.topAnchor.constraint(equalTo: topAnchor),
            titlebarView.heightAnchor.constraint(equalToConstant: Self.titlebarHeight),

            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: titlebarView.bottomAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        applyAppearance()
    }

    private func applyAppearance() {
        visualEffectView.material = ClipXAppearance.visualEffectMaterial
        let baseColor: NSColor = ClipXAppearance.isDarkMode ? .black : .white
        glassOverlay.layer?.backgroundColor = baseColor.withAlphaComponent(ClipXAppearance.glassOverlayAlpha).cgColor
        titlebarView.applyAppearance()
    }
}

private final class ClipXTitlebarView: NSView {
    private let statusLabel = NSTextField(labelWithString: "")
    private let brandLabel = NSTextField(labelWithString: "ClipX")
    private let titleLabel: NSTextField

    init(title: String) {
        titleLabel = NSTextField(labelWithString: title)
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    func updateStatus(_ status: String) {
        statusLabel.stringValue = status
    }

    func applyAppearance() {
        let titlebarColor = ClipXAppearance.isDarkMode
            ? NSColor.white.withAlphaComponent(ClipXAppearance.titlebarAlpha)
            : NSColor.white.withAlphaComponent(ClipXAppearance.titlebarAlpha)
        layer?.backgroundColor = titlebarColor.cgColor
        brandLabel.textColor = NSColor(calibratedWhite: ClipXAppearance.isDarkMode ? 0.96 : 0.15, alpha: 1)
        titleLabel.textColor = NSColor(calibratedWhite: ClipXAppearance.isDarkMode ? 0.62 : 0.34, alpha: 1)
        statusLabel.textColor = NSColor(calibratedWhite: ClipXAppearance.isDarkMode ? 0.58 : 0.42, alpha: 1)
        subviews.forEach { $0.needsDisplay = true }
    }

    private func setup() {
        wantsLayer = true

        let close = TrafficLightButton(color: NSColor(red: 1, green: 0.37, blue: 0.34, alpha: 1), symbolName: "xmark")
        let minimize = TrafficLightButton(color: NSColor(red: 1, green: 0.74, blue: 0.18, alpha: 1), symbolName: "minus")
        let zoom = TrafficLightButton(color: NSColor(red: 0.16, green: 0.78, blue: 0.25, alpha: 1), symbolName: "plus")
        close.target = self
        close.action = #selector(closeWindow)
        minimize.target = self
        minimize.action = #selector(minimizeWindow)
        zoom.target = self
        zoom.action = #selector(zoomWindow)

        let trafficStack = NSStackView(views: [close, minimize, zoom])
        trafficStack.orientation = .horizontal
        trafficStack.spacing = 8
        trafficStack.alignment = .centerY
        trafficStack.translatesAutoresizingMaskIntoConstraints = false

        let mark = SymbolTileView()
        mark.translatesAutoresizingMaskIntoConstraints = false

        brandLabel.font = .systemFont(ofSize: 20, weight: .bold)
        brandLabel.lineBreakMode = .byTruncatingTail

        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = NSColor(calibratedWhite: 0.62, alpha: 1)
        titleLabel.lineBreakMode = .byTruncatingTail

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = NSColor(calibratedWhite: 0.58, alpha: 1)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.alignment = .right

        let stack = NSStackView(views: [trafficStack, mark, brandLabel, titleLabel])
        stack.orientation = .horizontal
        stack.spacing = 14
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            close.widthAnchor.constraint(equalToConstant: 13),
            close.heightAnchor.constraint(equalToConstant: 13),
            minimize.widthAnchor.constraint(equalToConstant: 13),
            minimize.heightAnchor.constraint(equalToConstant: 13),
            zoom.widthAnchor.constraint(equalToConstant: 13),
            zoom.heightAnchor.constraint(equalToConstant: 13),

            mark.widthAnchor.constraint(equalToConstant: 30),
            mark.heightAnchor.constraint(equalToConstant: 30),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 17),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -18),

            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 320)
        ])

        applyAppearance()
    }

    @objc private func closeWindow() {
        window?.close()
    }

    @objc private func minimizeWindow() {
        window?.miniaturize(nil)
    }

    @objc private func zoomWindow() {
        window?.zoom(nil)
    }
}

private final class SymbolTileView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0.8
        applyAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        applyAppearance()
        let image = NSImage(systemSymbolName: "command", accessibilityDescription: "ClipX")
        image?.isTemplate = true
        (ClipXAppearance.isDarkMode ? NSColor(calibratedWhite: 0.96, alpha: 1) : NSColor(calibratedWhite: 0.18, alpha: 1)).set()
        let rect = bounds.insetBy(dx: 7.2, dy: 7.2)
        image?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private func applyAppearance() {
        let base = ClipXAppearance.isDarkMode ? NSColor.white : NSColor.black
        layer?.backgroundColor = base.withAlphaComponent(ClipXAppearance.isDarkMode ? 0.10 : 0.07).cgColor
        layer?.borderColor = base.withAlphaComponent(ClipXAppearance.isDarkMode ? 0.14 : 0.10).cgColor
    }
}

private final class TrafficLightButton: NSButton {
    private let fillColor: NSColor
    private let symbolName: String
    private var isHovering = false
    private var tracking: NSTrackingArea?

    init(color: NSColor, symbolName: String) {
        self.fillColor = color
        self.symbolName = symbolName
        super.init(frame: NSRect(x: 0, y: 0, width: 13, height: 13))
        isBordered = false
        setButtonType(.momentaryChange)
        imagePosition = .imageOnly
        setAccessibilityLabel(symbolName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 13, height: 13)
    }

    override func updateTrackingAreas() {
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5))
        fillColor.setFill()
        circle.fill()
        NSColor.black.withAlphaComponent(0.12).setStroke()
        circle.lineWidth = 0.7
        circle.stroke()

        guard isHovering,
              let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: symbolName) else {
            return
        }
        image.isTemplate = true
        NSColor.black.withAlphaComponent(0.58).set()
        let rect = NSRect(x: 3.35, y: 3.35, width: 6.3, height: 6.3)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}
