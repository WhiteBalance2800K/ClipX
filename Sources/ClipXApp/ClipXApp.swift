import AppKit
import ClipXCore
import Combine
import SwiftUI

@main
enum ClipXMain {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var monitor: PasteboardMonitor?
    private var hotKey: GlobalHotKey?
    private var historyWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let paster = ForegroundPaster()
    private var lastPasteTarget: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?
    private var shortcutObserver: NSObjectProtocol?
    private var shortcutRecordingObserver: NSObjectProtocol?
    private var appearanceObserver: NSObjectProtocol?
    private var languageObserver: NSObjectProtocol?
    private var cancellables: Set<AnyCancellable> = []
    private var isShortcutRecording = false
    private var viewModel: ClipXViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store: HistoryStoring
        do {
            store = try HistoryStore()
        } catch {
            store = InMemoryFallbackStore()
        }

        viewModel = ClipXViewModel(store: store)
        viewModel.load()
        bindViewModel()
        configurePasteTargetTracking()
        configureMonitor()
        configureStatusItem()
        configureHotKey()
        configurePreferenceObservers()
    }

    private func bindViewModel() {
        viewModel.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateOpenWindowStatus()
                self?.refreshMenu()
            }
            .store(in: &cancellables)

        viewModel.$isMonitoringPaused
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] paused in
                self?.monitor?.isPaused = paused
                self?.refreshMenu()
            }
            .store(in: &cancellables)
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        if let shortcutObserver {
            NotificationCenter.default.removeObserver(shortcutObserver)
        }
        if let shortcutRecordingObserver {
            NotificationCenter.default.removeObserver(shortcutRecordingObserver)
        }
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
        }
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

    private func configurePasteTargetTracking() {
        rememberPasteTarget(NSWorkspace.shared.frontmostApplication)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.rememberPasteTarget(application)
        }
    }

    private func configureMonitor() {
        let monitor = PasteboardMonitor()
        monitor.autoFixRTFD = viewModel.autoFixRTFD
        monitor.onItemCaptured = { [weak self] item in
            DispatchQueue.main.async {
                self?.viewModel.capture(item)
                self?.refreshMenu()
            }
        }
        monitor.onRTFDFixed = { [weak self] _ in
            DispatchQueue.main.async {
                self?.viewModel.statusMessage = L10n.t("RTFD converted to plain text")
                self?.refreshMenu()
            }
        }
        monitor.start()
        self.monitor = monitor
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipX")
        statusItem.button?.imagePosition = .imageOnly
        self.statusItem = statusItem
        refreshMenu()
    }

    private func configureHotKey() {
        guard !isShortcutRecording else {
            hotKey = nil
            return
        }
        hotKey = nil
        hotKey = GlobalHotKey(shortcut: ClipXShortcut.loadHistoryShortcut()) { [weak self] in
            DispatchQueue.main.async {
                guard self?.isShortcutRecording == false else { return }
                self?.showHistory()
            }
        }
    }

    private func configurePreferenceObservers() {
        shortcutObserver = NotificationCenter.default.addObserver(
            forName: .clipXShortcutChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureHotKey()
            self?.viewModel.statusMessage = L10n.t("Shortcut updated")
            self?.refreshMenu()
        }
        shortcutRecordingObserver = NotificationCenter.default.addObserver(
            forName: .clipXShortcutRecordingChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let recording = notification.object as? Bool ?? false
            isShortcutRecording = recording
            if recording {
                hotKey = nil
            } else {
                configureHotKey()
            }
        }
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: .clipXAppearanceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.viewModel.refreshPresentation()
            self?.historyWindow?.appearance = nil
            self?.settingsWindow?.appearance = nil
        }
        languageObserver = NotificationCenter.default.addObserver(
            forName: .clipXLanguageChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.viewModel.refreshPresentation()
            self?.refreshMenu()
            self?.updateOpenWindowStatus()
        }
    }

    private func refreshMenu() {
        let menu = NSMenu()
        let status = NSMenuItem(title: viewModel.statusMessage.isEmpty ? L10n.t("Ready") : viewModel.statusMessage, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        addRecentItems(to: menu)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.t("Open history"), action: #selector(showHistory), keyEquivalent: "v"))
        menu.addItem(.separator())

        let pauseTitle = viewModel.isMonitoringPaused ? L10n.t("Resume monitoring") : L10n.t("Pause monitoring")
        menu.addItem(NSMenuItem(title: pauseTitle, action: #selector(toggleMonitoring), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: L10n.t("Quit ClipX"), action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    private func addRecentItems(to menu: NSMenu) {
        let recentItems = Array(viewModel.items.prefix(5))
        let header = NSMenuItem(title: L10n.t("Recent clipboard items"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        guard !recentItems.isEmpty else {
            let empty = NSMenuItem(title: L10n.t("No clipboard history yet"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for item in recentItems {
            let menuItem = NSMenuItem(title: menuTitle(for: item), action: #selector(pasteFromMenu(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item.id.uuidString
            menuItem.image = NSImage(systemSymbolName: iconName(for: item.kind), accessibilityDescription: nil)
            menu.addItem(menuItem)
        }
    }

    private func menuTitle(for item: ClipItem) -> String {
        let raw = item.preview.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = raw.isEmpty ? item.kind.displayName : raw
        let limit = 54
        if preview.count > limit {
            return "\(String(preview.prefix(limit - 1)))…"
        }
        return preview
    }

    private func iconName(for kind: ClipKind) -> String {
        switch kind {
        case .text, .rtf, .rtfd, .html:
            return "doc.text"
        case .url:
            return "link"
        case .image:
            return "photo"
        case .file:
            return "doc"
        case .color:
            return "eyedropper"
        case .unknown:
            return "questionmark.square"
        }
    }

    @objc func showHistory() {
        rememberPasteTarget(NSWorkspace.shared.frontmostApplication)
        let window = showWindow(
            historyWindow,
            size: NSSize(width: 1200, height: 800),
            title: L10n.t("Clipboard history"),
            activate: false
        ) {
            MainHistoryView(onPaste: { [weak self] item in
                self?.paste(item)
            }, onSettings: { [weak self] in
                self?.showSettings()
            })
            .environmentObject(viewModel)
        }
        window.keyDownHandler = { [weak self] event in
            self?.handleHistoryKey(event) ?? false
        }
        historyWindow = window
    }

    @objc func showSettings() {
        let window = showWindow(
            settingsWindow,
            size: NSSize(width: 980, height: 700),
            title: L10n.t("Settings"),
            activate: true
        ) {
            SettingsView(onAutoFixChanged: { [weak self] enabled in
                self?.monitor?.autoFixRTFD = enabled
            })
            .environmentObject(viewModel)
        }
        window.keyDownHandler = { [weak self, weak window] event in
            self?.handleSettingsKey(event, window: window) ?? false
        }
        settingsWindow = window
    }

    @objc func toggleMonitoring() {
        viewModel.isMonitoringPaused.toggle()
        monitor?.isPaused = viewModel.isMonitoringPaused
        viewModel.statusMessage = viewModel.isMonitoringPaused ? L10n.t("Monitoring paused") : L10n.t("Ready")
        refreshMenu()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    @objc func pasteFromMenu(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let item = viewModel.items.first(where: { $0.id == id }) else {
            return
        }
        paste(item)
    }

    private func paste(_ item: ClipItem) {
        monitor?.write(item)
        viewModel.recordPaste(item)
        guard paster.hasAccessibilityPermission(promptForPermission: true) else {
            viewModel.statusMessage = L10n.t("Copied. Enable Accessibility to paste automatically.")
            refreshMenu()
            return
        }

        guard let target = lastPasteTarget, !target.isTerminated else {
            viewModel.statusMessage = L10n.t("Copied. Open a target app, then paste again.")
            refreshMenu()
            return
        }

        historyWindow?.orderOut(nil)
        settingsWindow?.orderOut(nil)
        paster.paste(into: target) { [weak self] success in
            guard let self else { return }
            self.viewModel.statusMessage = success
                ? L10n.t("Pasted into frontmost app")
                : L10n.t("Copied. Open a target app, then paste again.")
            self.refreshMenu()
        }
    }

    private func rememberPasteTarget(_ application: NSRunningApplication?) {
        guard
            let application,
            !application.isTerminated,
            application.bundleIdentifier != Bundle.main.bundleIdentifier
        else {
            return
        }
        lastPasteTarget = application
    }

    private func handleHistoryKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53 {
            historyWindow?.close()
            return true
        }
        if modifiers.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "f" {
            focusSearch()
            return true
        }

        let allowedModifiers: NSEvent.ModifierFlags = [.shift, .numericPad, .function]
        guard modifiers.subtracting(allowedModifiers).isEmpty else { return false }
        switch event.keyCode {
        case 123, 126:
            withAnimation(.snappy(duration: 0.18)) {
                viewModel.moveSelection(by: -1)
            }
            return true
        case 124, 125:
            withAnimation(.snappy(duration: 0.18)) {
                viewModel.moveSelection(by: 1)
            }
            return true
        case 36, 76:
            if let item = viewModel.selectedItem {
                paste(item)
                return true
            }
            return false
        case 51:
            guard !viewModel.searchQuery.isEmpty else { return false }
            viewModel.searchQuery.removeLast()
            viewModel.selectedID = viewModel.filteredItems.first?.id
            focusSearch()
            return true
        default:
            guard let characters = event.characters,
                  characters.count == 1,
                  let scalar = characters.unicodeScalars.first,
                  !CharacterSet.controlCharacters.contains(scalar) else {
                return false
            }
            viewModel.searchQuery.append(characters)
            viewModel.selectedID = viewModel.filteredItems.first?.id
            focusSearch()
            return true
        }
    }

    private func handleSettingsKey(_ event: NSEvent, window: NSWindow?) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53 {
            window?.close()
            return true
        }
        if modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "w" {
            window?.close()
            return true
        }
        return false
    }

    private func focusSearch() {
        NotificationCenter.default.post(name: .clipXFocusSearch, object: nil)
    }

    private func updateOpenWindowStatus() {
        let status = viewModel.statusMessage.isEmpty ? L10n.t("Ready") : viewModel.statusMessage
        (historyWindow as? ClipXWindow)?.updateStatus(status)
        (settingsWindow as? ClipXWindow)?.updateStatus(status)
    }

    private func showWindow<Content: View>(
        _ existing: NSWindow?,
        size: NSSize,
        title: String,
        isPanel: Bool = false,
        activate: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> ClipXWindow {
        NSApp.setActivationPolicy(.regular)
        if let existing, existing.isVisible {
            if activate {
                existing.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                existing.orderFrontRegardless()
            }
            if let window = existing as? ClipXWindow {
                window.updateStatus(viewModel.statusMessage)
                return window
            }
        }

        let hostingView = NSHostingView(rootView: content())
        let window = ClipXWindow(size: size, title: title, hostedView: hostingView, isFloating: isPanel)
        window.delegate = self
        window.updateStatus(viewModel.statusMessage)
        window.center()
        if activate {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window.orderFrontRegardless()
        }
        return window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === historyWindow {
            historyWindow = nil
        } else if window === settingsWindow {
            settingsWindow = nil
        }
        updateActivationPolicyForOpenWindows()
    }

    private func updateActivationPolicyForOpenWindows() {
        guard historyWindow == nil, settingsWindow == nil else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

private final class InMemoryFallbackStore: HistoryStoring {
    private var items: [ClipItem] = []

    func upsert(_ item: ClipItem) throws {
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
    }

    func fetchAll(limit: Int) throws -> [ClipItem] {
        Array(items.prefix(limit))
    }

    func delete(id: UUID) throws {
        items.removeAll { $0.id == id }
    }

    func updateFlags(id: UUID, favorite: Bool?, pinned: Bool?) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let favorite {
            items[index].isFavorite = favorite
        }
        if let pinned {
            items[index].isPinned = pinned
        }
    }

    func purge(before date: Date) throws {
        items.removeAll { $0.createdAt < date && !$0.isPinned }
    }
}
