import ClipXCore
import ApplicationServices
import AppKit
import Darwin
import SwiftUI
import UniformTypeIdentifiers

private let localDisplayDeviceFamily: String = {
    var size = 0
    guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
        return "mac"
    }
    var model = [CChar](repeating: 0, count: size)
    guard sysctlbyname("hw.model", &model, &size, nil, 0) == 0 else {
        return "mac"
    }
    let modelIdentifier = String(cString: model).lowercased()
    if modelIdentifier.contains("macmini") {
        return "macmini"
    }
    if modelIdentifier.contains("macbook") {
        return "macbook"
    }
    if modelIdentifier.contains("imac") {
        return "imac"
    }
    if modelIdentifier.contains("macstudio") {
        return "macstudio"
    }
    if modelIdentifier.contains("macpro") {
        return "macpro"
    }
    return "mac"
}()

private let settingsControlWidth: CGFloat = 224
private let settingsControlHeight: CGFloat = 44
private var resolvedAppIconCache: [String: NSImage] = [:]

struct LauncherPanelView: View {
    @EnvironmentObject private var model: ClipXViewModel
    let onPaste: (ClipItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ClipXColor.muted)
                TextField(L10n.t("Search clipboard history..."), text: $model.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .foregroundStyle(ClipXColor.text)
                    .onSubmit {
                        if let item = model.selectedItem {
                            onPaste(item)
                        }
                    }
                Spacer()
                HStack(spacing: 5) {
                    Keycap(text: "⌘")
                    Keycap(text: "⇧")
                    Keycap(text: "V")
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 64)
            .background(ClipXColor.surface)
            .overlay(Rectangle().fill(ClipXColor.border).frame(height: 1), alignment: .bottom)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.filteredItems.isEmpty {
                        EmptyStateView(title: L10n.t("No matching clipboard items"), subtitle: L10n.t("Copy something, or try a different search."))
                            .padding(.top, 90)
                    } else {
                        ForEach(model.filteredItems) { item in
                            LauncherRow(
                                item: item,
                                isSelected: model.selectedID == item.id,
                                onSelect: {
                                    model.selectedID = item.id
                                },
                                onPaste: {
                                    onPaste(item)
                                }
                            )
                        }
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 760, height: 520)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow)
                ClipXColor.glassOverlay
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ClipXColor.borderStrong)
        )
        .preferredColorScheme(ClipXAppearance.preferredColorScheme)
        .onAppear {
            model.selectedID = model.filteredItems.first?.id
        }
    }
}

struct MainHistoryView: View {
    @EnvironmentObject private var model: ClipXViewModel
    let onPaste: (ClipItem) -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HistoryColumn(onPaste: onPaste, onSettings: onSettings)
            DetailPanel(onPaste: onPaste)
                .frame(width: 540)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClipXColor.appContent)
        .preferredColorScheme(ClipXAppearance.preferredColorScheme)
        .id(model.appearanceVersion)
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case privacy
    case storage
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L10n.t("General")
        case .privacy: L10n.t("Privacy")
        case .storage: L10n.t("Storage")
        case .advanced: L10n.t("Advanced")
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .privacy: "lock"
        case .storage: "externaldrive"
        case .advanced: "wrench.and.screwdriver"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: ClipXViewModel
    let onAutoFixChanged: (Bool) -> Void
    @State private var selectedSection: SettingsSection = .general
    @State private var historyShortcut = ClipXShortcut.loadHistoryShortcut()
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showStatusInMenu") private var showStatusInMenu = true
    @AppStorage("excludeSensitiveApps") private var excludeSensitiveApps = true
    @AppStorage("autoDeleteHistory") private var autoDeleteHistory = true
    @AppStorage("languageCode") private var languageCode = ClipXAppearance.selectedLanguageCode
    @AppStorage("appTheme") private var appTheme = ClipXTheme.dark.rawValue
    @AppStorage("pureBlackGlass") private var pureBlackGlass = true
    @AppStorage("reduceTransparency") private var reduceTransparency = false
    @AppStorage("showDebugStatus") private var showDebugStatus = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(SettingsSection.allCases) { section in
                    SettingsSidebarItem(
                        icon: section.icon,
                        title: section.title,
                        active: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 54)
            .padding(.bottom, 18)
            .frame(width: 236, alignment: .leading)
            .background(ClipXColor.sidebar)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(sectionHeadline)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(ClipXColor.text)
                        .frame(maxWidth: 680, alignment: .leading)

                    settingsContent
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClipXColor.appContent)
        .preferredColorScheme(ClipXAppearance.preferredColorScheme)
        .id(model.appearanceVersion)
    }

    private var sectionHeadline: String {
        switch selectedSection {
        case .general: L10n.t("Control how ClipX starts and behaves in the menu bar.")
        case .privacy: L10n.t("Keep clipboard history local unless you choose otherwise.")
        case .storage: L10n.t("Manage local history and retention.")
        case .advanced: L10n.t("Diagnostics and repair controls for clipboard edge cases.")
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedSection {
        case .general:
            SettingsCard {
                SettingsPickerRow(
                    title: "Language",
                    subtitle: L10n.t("Choose the interface language."),
                    selection: $languageCode,
                    options: ClipXLanguageOption.options.map { ($0.code, $0.title) }
                )
                .onChange(of: languageCode) { _, value in
                    ClipXAppearance.selectedLanguageCode = value
                    model.refreshPresentation()
                    ClipXAppearance.notifyLanguageChanged()
                }
                SettingsPickerRow(
                    title: L10n.t("Theme"),
                    subtitle: L10n.t("Follow the system appearance or force a specific mode."),
                    selection: $appTheme,
                    options: ClipXTheme.allCases.map { ($0.rawValue, $0.title) }
                )
                .onChange(of: appTheme) { _, value in
                    ClipXAppearance.theme = ClipXTheme(rawValue: value) ?? .system
                    model.refreshPresentation()
                    ClipXAppearance.notifyAppearanceChanged()
                }
                ShortcutRecorderRow(shortcut: $historyShortcut) { shortcut in
                    shortcut.saveHistoryShortcut()
                }
                SettingsToggleRow(title: L10n.t("Launch at login"), subtitle: L10n.t("Start ClipX automatically when you sign in."), isOn: $launchAtLogin)
                SettingsToggleRow(title: L10n.t("Show menu bar status"), subtitle: L10n.t("Keep the ClipX clipboard icon visible in the menu bar."), isOn: $showStatusInMenu)
                SettingsToggleRow(
                    title: L10n.t("Pause clipboard monitoring"),
                    subtitle: L10n.t("Temporarily stop captures without closing ClipX."),
                    isOn: Binding(
                        get: { model.isMonitoringPaused },
                        set: { value in
                            model.isMonitoringPaused = value
                            model.statusMessage = value ? L10n.t("Monitoring paused") : L10n.t("Ready")
                        }
                    )
                )
                SettingsToggleRow(title: L10n.t("Pure black glass"), subtitle: L10n.t("Use black translucent surfaces instead of colored gradients."), isOn: $pureBlackGlass)
                    .onChange(of: pureBlackGlass) { _, value in
                        ClipXAppearance.pureBlackGlass = value
                        model.refreshPresentation()
                        ClipXAppearance.notifyAppearanceChanged()
                    }
                SettingsToggleRow(title: L10n.t("Reduce transparency"), subtitle: L10n.t("Prefer more solid surfaces when the background is distracting."), isOn: $reduceTransparency)
                    .onChange(of: reduceTransparency) { _, value in
                        ClipXAppearance.reduceTransparency = value
                        model.refreshPresentation()
                        ClipXAppearance.notifyAppearanceChanged()
                    }
            }
        case .privacy:
            SettingsCard {
                AccessibilityPermissionRow()
                SettingsToggleRow(
                    title: L10n.t("RTFD auto-fix"),
                    subtitle: L10n.t("Convert Universal Clipboard RTFD packages into plain text while keeping the original item."),
                    isOn: Binding(
                        get: { model.autoFixRTFD },
                        set: { value in
                            model.autoFixRTFD = value
                            onAutoFixChanged(value)
                        }
                    )
                )
                SettingsToggleRow(title: L10n.t("Exclude sensitive apps"), subtitle: L10n.t("Ignore 1Password, Keychain Access, private browsers, and concealed pasteboard types."), isOn: $excludeSensitiveApps)
                SettingsToggleRow(title: L10n.t("Auto-delete old history"), subtitle: L10n.t("Remove old clipboard items while keeping pinned snippets."), isOn: $autoDeleteHistory)
            }
        case .storage:
            SettingsCard {
                SettingsInfoRow(title: L10n.t("History items"), subtitle: L10n.t("Items currently loaded in ClipX."), value: "\(model.items.count)")
                SettingsActionRow(
                    title: L10n.t("Storage location"),
                    subtitle: HistoryStore.defaultDirectory.path,
                    buttonTitle: L10n.t("Open"),
                    systemImage: "folder"
                ) {
                    NSWorkspace.shared.activateFileViewerSelecting([HistoryStore.defaultDirectory])
                }
            }
        case .advanced:
            SettingsCard {
                SettingsToggleRow(title: L10n.t("Show debug status"), subtitle: L10n.t("Surface clipboard conversion status in the menu bar."), isOn: $showDebugStatus)
                SettingsInfoRow(title: L10n.t("Universal Clipboard marker"), subtitle: "com.apple.is-remote-clipboard", value: L10n.t("Detected"))
                SettingsInfoRow(title: L10n.t("RTFD types"), subtitle: "public.rtfd, com.apple.flat-rtfd, NSRTFDPboardType", value: L10n.t("Watched"))
            }
        }
    }
}

private struct MarkView: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .stroke(Color.white.opacity(0.18))
                )
            Image(systemName: "command")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(ClipXColor.text)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.35), radius: 16, y: 8)
    }
}

private struct ToolbarIconSurface: View {
    let systemName: String
    var active = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 38, height: 38)
            .foregroundStyle(active ? ClipXColor.accent : ClipXColor.textSoft)
            .background(active ? ClipXColor.selection : ClipXColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(active ? ClipXColor.selectionBorder : ClipXColor.border, lineWidth: 0.8)
            )
    }
}

private struct FilterMenuButton: View {
    @EnvironmentObject private var model: ClipXViewModel
    @State private var showingFilters = false

    private let filters: [ClipKind?] = [nil, .text, .url, .image, .file, .color]

    var body: some View {
        Button {
            showingFilters.toggle()
        } label: {
            ToolbarIconSurface(
                systemName: "line.3.horizontal.decrease",
                active: model.selectedCategory != nil
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingFilters, arrowEdge: .bottom) {
            filterPopover
                .preferredColorScheme(ClipXAppearance.isDarkMode ? .dark : .light)
                .presentationBackground(ClipXColor.panel)
        }
        .help(L10n.t("Filter"))
    }

    private var filterPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(filters.indices, id: \.self) { index in
                let kind = filters[index]
                let selected = model.selectedCategory == kind
                Button {
                    model.selectCategory(kind)
                    showingFilters = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: filterIcon(for: kind))
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18)
                        Text(kind?.displayName ?? L10n.t("All items"))
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                }
                .buttonStyle(FilterPopoverRowStyle(active: selected))
            }
        }
        .padding(8)
        .frame(width: 220)
        .background(ClipXColor.panel.ignoresSafeArea())
    }

    private func filterIcon(for kind: ClipKind?) -> String {
        guard let kind else { return "doc.on.clipboard" }
        return icon(for: kind)
    }
}

private struct FilterPopoverRowStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(active ? ClipXColor.text : ClipXColor.textSoft)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background(active || configuration.isPressed ? ClipXColor.selection : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TopIconButton: View {
    let systemName: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarIconSurface(systemName: systemName, active: active)
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryColumn: View {
    @EnvironmentObject private var model: ClipXViewModel
    let onPaste: (ClipItem) -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                SearchField(text: $model.searchQuery)
                    .onChange(of: model.searchQuery) { _, _ in
                        model.selectedID = model.filteredItems.first?.id
                    }
                FilterMenuButton()
                TopIconButton(
                    systemName: model.selectedSmartFilter == .favorites ? "star.fill" : "star",
                    active: model.selectedSmartFilter == .favorites,
                    action: toggleFavoritesFilter
                )
                .help(L10n.t("Favorites"))
                TopIconButton(systemName: "gearshape", action: onSettings)
                    .help(L10n.t("Settings"))
            }
            .padding(.leading, 78)
            .padding(.trailing, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(ClipXColor.panel)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if model.filteredItems.isEmpty {
                            EmptyStateView(title: L10n.t("No matching clipboard items"), subtitle: L10n.t("Try searching by app, type, tag, or copied text."))
                                .padding(.top, 110)
                        } else {
                            ForEach(model.filteredItems) { item in
                                ClipRow(item: item, selected: model.selectedID == item.id, onSelect: {
                                    model.selectedID = item.id
                                }, onDelete: {
                                    model.delete(item)
                                }, onPaste: {
                                    model.selectedID = item.id
                                    onPaste(item)
                                })
                                .id(item.id)
                            }
                        }
                    }
                    .padding(14)
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
                .onChange(of: model.selectedID) { _, selectedID in
                    guard let selectedID else { return }
                    withAnimation(.snappy(duration: 0.18)) {
                        proxy.scrollTo(selectedID, anchor: .center)
                    }
                }
            }
        }
        .background(ClipXColor.panel)
    }

    private func toggleFavoritesFilter() {
        if model.selectedSmartFilter == .favorites {
            model.selectCategory(nil)
        } else {
            model.selectSmartFilter(.favorites)
        }
    }
}

private struct DetailPanel: View {
    @EnvironmentObject private var model: ClipXViewModel
    let onPaste: (ClipItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let item = model.selectedItem {
                VStack(spacing: 0) {
                    PayloadPreview(item: item)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    if item.wasRTFDFixed {
                        InfoCard(title: L10n.t("Recognition"), text: L10n.t("ClipX detected an RTFD package, preserved the original item, and wrote plain text back to the system clipboard."))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }

                    DetailMetaStrip(item: item)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    DetailActionBar(item: item, onPaste: onPaste)
                }
            } else {
                EmptyStateView(title: L10n.t("No item selected"), subtitle: L10n.t("Copy something to start building history."))
                    .padding(.top, 160)
            }
        }
        .background(ClipXColor.panel)
    }
}

private struct DetailMetaStrip: View {
    let item: ClipItem

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            MiniMetaPair(title: L10n.t("Source app"), value: displaySource(for: item))
            MiniMetaPair(title: L10n.t("Character count"), value: characterCountText(for: item))
            MiniMetaPair(title: L10n.t("Paste count"), value: pasteCountText(for: item))
            MiniMetaPair(title: L10n.t("Copied"), value: item.createdAt.formatted(date: .numeric, time: .shortened))
        }
    }
}

private struct MiniMetaPair: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(ClipXColor.muted)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ClipXColor.textSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background(ClipXColor.raised)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct DetailActionBar: View {
    @EnvironmentObject private var model: ClipXViewModel
    let item: ClipItem
    let onPaste: (ClipItem) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    onPaste(item)
                } label: {
                    Label(L10n.t("Paste"), systemImage: "doc.on.clipboard")
                }
                .buttonStyle(DetailActionButtonStyle(tone: .primary))

                Button {
                    PasteboardWriter.write(item.payload)
                    model.statusMessage = L10n.t("Copied again")
                } label: {
                    Label(L10n.t("Copy again"), systemImage: "doc.on.doc")
                }
                .buttonStyle(DetailActionButtonStyle(tone: .secondary))
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        model.togglePin(item)
                    }
                } label: {
                    Label(L10n.t("Pin"), systemImage: item.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(DetailActionButtonStyle(tone: .secondary))

                Button {
                    model.toggleFavorite(item)
                } label: {
                    Label(L10n.t("Favorite"), systemImage: item.isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(DetailActionButtonStyle(tone: .secondary))

                Button {
                    model.deleteSelected()
                } label: {
                    Label(L10n.t("Delete"), systemImage: "trash")
                }
                .buttonStyle(DetailActionButtonStyle(tone: .danger))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(actionBarGradient)
    }

    private var actionBarGradient: LinearGradient {
        if ClipXAppearance.isDarkMode {
            return LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color.white.opacity(0.0), Color.white.opacity(0.86)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct DetailActionButtonStyle: ButtonStyle {
    enum Tone {
        case primary
        case secondary
        case danger
    }

    let tone: Tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.titleAndIcon)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? pressedBackground : background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(border, lineWidth: 0.7)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch tone {
        case .primary:
            ClipXColor.text
        case .secondary:
            ClipXColor.text
        case .danger:
            ClipXColor.danger
        }
    }

    private var background: Color {
        switch tone {
        case .primary:
            ClipXAppearance.isDarkMode ? Color.white.opacity(0.14) : ClipXColor.accentSoft
        case .secondary:
            ClipXAppearance.isDarkMode ? Color.white.opacity(0.075) : ClipXColor.raised
        case .danger:
            ClipXColor.danger.opacity(0.12)
        }
    }

    private var pressedBackground: Color {
        switch tone {
        case .primary:
            ClipXAppearance.isDarkMode ? Color.white.opacity(0.20) : ClipXColor.raisedStrong
        case .secondary:
            ClipXAppearance.isDarkMode ? Color.white.opacity(0.12) : ClipXColor.surfaceStrong
        case .danger:
            ClipXColor.danger.opacity(0.18)
        }
    }

    private var border: Color {
        switch tone {
        case .primary:
            ClipXAppearance.isDarkMode ? Color.white.opacity(0.10) : ClipXColor.selectionBorder
        case .secondary:
            ClipXAppearance.isDarkMode ? Color.white.opacity(0.055) : ClipXColor.border
        case .danger:
            ClipXColor.danger.opacity(0.16)
        }
    }
}

private struct LauncherRow: View {
    let item: ClipItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void

    var body: some View {
        Button {
            onSelect()
            onPaste()
        } label: {
            HStack(spacing: 12) {
                SourceIcon(item: item)
                RowCopy(item: item)
                Spacer()
                HStack(spacing: 6) {
                    Keycap(text: "↵")
                    Text(L10n.t("Paste"))
                    if item.wasRTFDFixed {
                        ClipTag(text: L10n.t("RTFD fixed"), tone: .mint)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ClipXColor.muted)
            }
            .padding(.horizontal, 12)
            .frame(height: 64)
            .background(isSelected ? ClipXColor.accentSoft : ClipXColor.raised)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? ClipXColor.accent.opacity(0.36) : Color.clear, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ClipRow: View {
    let item: ClipItem
    let selected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onPaste: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                SourceIcon(item: item)
                RowCopy(item: item)
                Spacer()
                HStack(spacing: 8) {
                    if item.isPinned {
                        Image(systemName: "pin.fill").foregroundStyle(ClipXColor.accent)
                    }
                    if item.isFavorite {
                        Image(systemName: "star.fill").foregroundStyle(ClipXColor.amber)
                    }
                    RowDeleteButton(action: onDelete)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 62)
            .background(selected ? ClipXColor.selection : ClipXColor.raised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? ClipXColor.selectionBorder : Color.clear, lineWidth: 0.9)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded { onPaste() }
        )
    }
}

private struct RowDeleteButton: View {
    @State private var hovering = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10.5, weight: .bold))
                .frame(width: 22, height: 22)
                .foregroundStyle(hovering ? ClipXColor.danger : ClipXColor.muted)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(L10n.t("Delete"))
    }
}

private struct RowCopy: View {
    let item: ClipItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.isSensitive ? "••••••••••••••••" : rowPreview(for: item))
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(ClipXColor.text)
                .lineLimit(1)
            HStack(spacing: 7) {
                Text(displaySource(for: item))
                Circle().fill(ClipXColor.muted).frame(width: 3, height: 3)
                Text(relativeAgeText(for: item.createdAt))
                ClipTag(text: displayKind(for: item), tone: tagTone(for: item))
            }
            .font(.system(size: 11.5))
            .foregroundStyle(ClipXColor.muted)
        }
    }
}

private struct SourceIcon: View {
    let item: ClipItem
    @State private var appIcon: NSImage?

    var body: some View {
        ZStack {
            if isUniversalSource(item) {
                UniversalSourceIcon()
            } else {
                Image(systemName: deviceIcon(for: item))
                    .font(.system(size: 23, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(sourceIconForeground(for: item))
            }

            VStack {
                HStack {
                    Spacer()
                    if item.wasRTFDFixed, !isUniversalSource(item) {
                        Circle()
                            .fill(ClipXColor.mint)
                            .frame(width: 8, height: 8)
                    }
                }
                Spacer()
            }
            .padding(6)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if shouldShowSourceAppBadge(for: item) {
                        SourceAppBadge(appIcon: appIcon, fallbackIcon: sourceFallbackIcon(for: item))
                    }
                }
            }
        }
        .frame(width: 38, height: 38)
        .onAppear {
            if shouldShowSourceAppBadge(for: item) {
                appIcon = resolvedAppIcon(for: item)
            }
        }
    }
}

private struct UniversalSourceIcon: View {
    var body: some View {
        ZStack {
            Image(systemName: "macbook")
                .font(.system(size: 18, weight: .semibold))
                .offset(x: -4, y: 3)
            Image(systemName: "iphone")
                .font(.system(size: 16, weight: .semibold))
                .offset(x: 8, y: -3)
        }
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(ClipXColor.textSoft)
        .frame(width: 30, height: 28)
    }
}

private struct SourceAppBadge: View {
    let appIcon: NSImage?
    let fallbackIcon: String

    var body: some View {
        ZStack {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(ClipXColor.text)
            }
        }
        .frame(width: 18, height: 18)
        .offset(x: 2, y: 2)
    }
}

private struct TypeIcon: View {
    let kind: ClipKind
    var fixed = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(iconBackground)
            Image(systemName: icon(for: kind))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(iconForeground)
            if fixed {
                Circle()
                    .fill(ClipXColor.mint)
                    .frame(width: 9, height: 9)
                    .offset(x: 1, y: 1)
            }
        }
        .frame(width: 42, height: 42)
    }

    private var iconBackground: Color {
        switch kind {
        case .url: ClipXColor.mintSoft
        case .color: ClipXColor.amberSoft
        case .rtfd, .rtf, .html: ClipXColor.accentSoft
        default: ClipXColor.surfaceStrong
        }
    }

    private var iconForeground: Color {
        switch kind {
        case .url: ClipXColor.mint
        case .color: ClipXColor.amber
        case .rtfd, .rtf, .html: ClipXColor.accent
        default: ClipXColor.textSoft
        }
    }
}

private struct SearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ClipXColor.muted)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(L10n.t("Search clipboard history..."))
                        .foregroundStyle(ClipXAppearance.isDarkMode ? Color.white.opacity(0.58) : ClipXColor.muted)
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(ClipXColor.text)
                    .focused($isFocused)
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 42)
        .background(isFocused ? ClipXColor.surfaceStrong : ClipXColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? ClipXColor.borderStrong : Color.clear, lineWidth: 0.8)
        )
        .onReceive(NotificationCenter.default.publisher(for: .clipXFocusSearch)) { _ in
            isFocused = true
        }
    }
}

private struct PayloadPreview: View {
    let item: ClipItem

    var body: some View {
        switch item.payload {
        case .image(let data):
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 330)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(ClipXColor.codeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contextMenu {
                        Button {
                            saveImage(data)
                        } label: {
                            Label(L10n.t("Save image"), systemImage: "square.and.arrow.down")
                        }
                    }
            } else {
                InfoCard(title: L10n.t("Image"), text: item.preview)
            }
        case .fileURLs(let urls):
            CodePreview(text: urls.map(\.path).joined(separator: "\n"))
        case .rtf, .rtfd:
            TextPreview(text: item.metadata["rtfdPlainText"] ?? RTFDNormalizer.plainText(from: item.payload) ?? item.preview)
        case .html:
            TextPreview(text: displayPreview(for: item))
        case .unknown:
            CodePreview(text: item.metadata["types"] ?? item.preview)
        default:
            TextPreview(text: displayPreview(for: item))
        }
    }

    private func saveImage(_ data: Data) {
        guard let image = NSImage(data: data),
              let pngData = pngData(from: image) else {
            NSSound.beep()
            return
        }

        let panel = NSSavePanel()
        panel.title = L10n.t("Save image")
        panel.nameFieldStringValue = "ClipX Image.png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try pngData.write(to: url, options: .atomic)
            } catch {
                NSSound.beep()
            }
        }
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}

private struct TextPreview: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(ClipXColor.textSoft)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(14)
        }
        .frame(minHeight: 360, maxHeight: .infinity)
        .background(ClipXColor.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct CodePreview: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ClipXColor.textSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(14)
        }
        .frame(minHeight: 360, maxHeight: .infinity)
        .background(ClipXColor.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct InfoCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ClipXColor.text)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(ClipXColor.muted)
                .lineSpacing(4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ClipXColor.raised)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 9) {
            TypeIcon(kind: .unknown)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ClipXColor.textSoft)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(ClipXColor.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsSidebarItem: View {
    let icon: String
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 18)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .foregroundStyle(active ? ClipXColor.text : ClipXColor.textSoft)
            .background(active ? ClipXColor.selection : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(active ? ClipXColor.selectionBorder : Color.clear, lineWidth: 0.8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(ClipXColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ClipXColor.separator)
        )
    }
}

private struct AccessibilityPermissionRow: View {
    @State private var isTrusted = ForegroundPaster().hasAccessibilityPermission(promptForPermission: false)

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: isTrusted ? "checkmark.shield" : "exclamationmark.shield")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isTrusted ? ClipXColor.mint : ClipXColor.amber)
                .frame(width: 30, height: 30)
                .background((isTrusted ? ClipXColor.mintSoft : ClipXColor.amberSoft))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.t("Accessibility permission"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ClipXColor.text)
            }
            Spacer()
            Button {
                openAccessibilitySettings()
            } label: {
                Label(L10n.t("Open Settings"), systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(16)
        .overlay(Rectangle().fill(ClipXColor.separator).frame(height: 1), alignment: .bottom)
        .onAppear {
            isTrusted = ForegroundPaster().hasAccessibilityPermission(promptForPermission: false)
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ClipXColor.text)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(16)
        .overlay(Rectangle().fill(ClipXColor.separator).frame(height: 1), alignment: .bottom)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ClipXColor.text)
            }
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(ClipXColor.textSoft)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(ClipXColor.raised)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(16)
        .overlay(Rectangle().fill(ClipXColor.separator).frame(height: 1), alignment: .bottom)
    }
}

private struct SettingsPickerRow: View {
    let title: String
    let subtitle: String
    @Binding var selection: String
    let options: [(String, String)]

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ClipXColor.text)
            }
            Spacer()
            SettingsPopoverPicker(selection: $selection, options: options)
        }
        .padding(16)
        .overlay(Rectangle().fill(ClipXColor.separator).frame(height: 1), alignment: .bottom)
    }
}

private struct SettingsPopoverPicker: View {
    @Binding var selection: String
    let options: [(String, String)]
    @State private var showingOptions = false

    private var selectedLabel: String {
        options.first { $0.0 == selection }?.1 ?? selection
    }

    var body: some View {
        Button {
            showingOptions.toggle()
        } label: {
            HStack(spacing: 8) {
                Text(selectedLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ClipXColor.muted)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ClipXColor.text)
            .padding(.horizontal, 12)
            .frame(width: settingsControlWidth, height: settingsControlHeight)
            .background(settingsControlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(settingsControlBorder, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .popover(isPresented: $showingOptions, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(options, id: \.0) { value, label in
                    let active = selection == value
                    Button {
                        selection = value
                        showingOptions = false
                    } label: {
                        HStack(spacing: 10) {
                            Text(label)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if active {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                    }
                    .buttonStyle(FilterPopoverRowStyle(active: active))
                }
            }
            .padding(8)
            .frame(width: settingsControlWidth)
            .background(ClipXColor.panel.ignoresSafeArea())
            .preferredColorScheme(ClipXAppearance.isDarkMode ? .dark : .light)
            .presentationBackground(ClipXColor.panel)
        }
    }

    private var settingsControlBackground: Color {
        ClipXAppearance.isDarkMode ? Color.white.opacity(0.10) : Color.black.opacity(0.055)
    }

    private var settingsControlBorder: Color {
        ClipXAppearance.isDarkMode ? Color.white.opacity(0.13) : Color.black.opacity(0.13)
    }
}

private struct SettingsActionRow: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ClipXColor.text)
            }
            Spacer()
            Button(action: action) {
                Label(buttonTitle, systemImage: systemImage)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(16)
        .overlay(Rectangle().fill(ClipXColor.separator).frame(height: 1), alignment: .bottom)
    }
}

private struct ShortcutRecorderRow: View {
    @Binding var shortcut: ClipXShortcut
    let onChange: (ClipXShortcut) -> Void

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.t("History shortcut"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ClipXColor.text)
            }
            Spacer()
            ShortcutRecorderField(shortcut: $shortcut, onChange: onChange)
                .frame(width: settingsControlWidth, height: settingsControlHeight)
        }
        .padding(16)
        .overlay(Rectangle().fill(ClipXColor.separator).frame(height: 1), alignment: .bottom)
    }
}

private struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: ClipXShortcut
    let onChange: (ClipXShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.shortcut = shortcut
        view.onShortcutChange = { newShortcut in
            shortcut = newShortcut
            onChange(newShortcut)
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.shortcut = shortcut
        nsView.onShortcutChange = { newShortcut in
            shortcut = newShortcut
            onChange(newShortcut)
        }
        nsView.applyAppearance()
    }
}

private final class ShortcutRecorderNSView: NSView {
    var shortcut: ClipXShortcut = .defaultHistory {
        didSet { updateLabel() }
    }
    var onShortcutChange: ((ClipXShortcut) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false {
        didSet {
            guard oldValue != isRecording else {
                updateLabel()
                return
            }
            NotificationCenter.default.post(name: .clipXShortcutRecordingChanged, object: isRecording)
            updateLabel()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: settingsControlWidth, height: settingsControlHeight)
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            isRecording = false
            return
        }
        guard let newShortcut = ClipXShortcut.from(event: event) else {
            NSSound.beep()
            return
        }
        shortcut = newShortcut
        onShortcutChange?(newShortcut)
        isRecording = false
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    func applyAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        let fill = ClipXAppearance.isDarkMode ? NSColor.white : NSColor.black
        layer?.backgroundColor = fill.withAlphaComponent(ClipXAppearance.isDarkMode ? 0.10 : 0.055).cgColor
        layer?.borderColor = fill.withAlphaComponent(isRecording ? 0.34 : 0.13).cgColor
        layer?.borderWidth = 0.8
        label.textColor = ClipXAppearance.isDarkMode
            ? NSColor(calibratedWhite: 0.88, alpha: 1)
            : NSColor(calibratedWhite: 0.18, alpha: 1)
    }

    private func setup() {
        wantsLayer = true
        label.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setAccessibilityRole(.button)
        setAccessibilityLabel(L10n.t("History shortcut"))
        applyAppearance()
        updateLabel()
    }

    private func updateLabel() {
        label.stringValue = isRecording ? L10n.t("Press shortcut") : shortcut.displayText
        applyAppearance()
    }
}

private func icon(for kind: ClipKind) -> String {
    switch kind {
    case .text: "doc.text"
    case .url: "link"
    case .image: "photo"
    case .file: "doc"
    case .rtf: "doc.richtext"
    case .rtfd: "doc.badge.gearshape"
    case .html: "chevron.left.forwardslash.chevron.right"
    case .color: "eyedropper"
    case .unknown: "questionmark.square"
    }
}

private func displaySource(for item: ClipItem) -> String {
    if isUniversalSource(item) {
        return "Universal"
    }
    return item.sourceApp
}

private func displayKind(for item: ClipItem) -> String {
    switch item.payload {
    case .rtf, .rtfd, .html:
        return ClipKind.text.displayName
    default:
        return item.kind.displayName
    }
}

private func displayPreview(for item: ClipItem) -> String {
    switch item.payload {
    case .html:
        return RTFDNormalizer.plainText(from: item.payload) ?? stripHTMLForDisplay(item.preview) ?? item.preview
    case .rtf, .rtfd:
        return item.metadata["rtfdPlainText"] ?? RTFDNormalizer.plainText(from: item.payload) ?? item.preview
    default:
        return item.payload.searchableText.isEmpty ? item.preview : item.payload.searchableText
    }
}

private func rowPreview(for item: ClipItem) -> String {
    switch item.payload {
    case .text(let value), .color(let value):
        return value
    case .url(let url):
        return url.absoluteString
    case .rtf, .rtfd:
        return item.metadata["rtfdPlainText"] ?? item.preview
    case .html:
        return stripHTMLForDisplay(item.preview) ?? item.preview
    case .image, .fileURLs, .unknown:
        return item.preview
    }
}

private func characterCountText(for item: ClipItem) -> String {
    "\(displayPreview(for: item).count)"
}

private func pasteCountText(for item: ClipItem) -> String {
    item.metadata["pasteCount"] ?? "0"
}

private func stripHTMLForDisplay(_ value: String) -> String? {
    let withoutTags = value.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
    let decoded = withoutTags.replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
    let compact = decoded.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return compact.isEmpty ? nil : compact
}

private func isRemoteClipboard(_ item: ClipItem) -> Bool {
    item.metadata["remoteClipboard"] == "true"
}

private func isUniversalSource(_ item: ClipItem) -> Bool {
    isRemoteClipboard(item) || item.sourceApp == "iOS Device" || item.sourceApp == "Universal Clipboard"
}

private func rawSourceDeviceFamily(for item: ClipItem) -> String? {
    guard let value = item.metadata["sourceDeviceFamily"]?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }
    return value.lowercased()
}

private func isMobileDeviceFamily(_ family: String?) -> Bool {
    guard let family else { return false }
    return family.contains("iphone") || family.contains("ipad") || family.contains("ios") || family.contains("watch")
}

private func hasRemoteMobileEvidence(_ item: ClipItem) -> Bool {
    let inference = item.metadata["sourceInference"]?.lowercased() ?? ""
    if inference.contains("mobile") {
        return true
    }
    return item.wasRTFDFixed
        || item.kind == .rtfd
        || item.metadata["rtfdPlainText"] != nil
        || item.metadata["rtfdSource"] != nil
}

private func isMobileSource(_ item: ClipItem) -> Bool {
    guard isMobileDeviceFamily(rawSourceDeviceFamily(for: item)) else { return false }
    return !isRemoteClipboard(item) || hasRemoteMobileEvidence(item)
}

private func shouldShowSourceAppBadge(for item: ClipItem) -> Bool {
    !isUniversalSource(item)
}

private func resolvedAppIcon(for item: ClipItem) -> NSImage? {
    guard !isUniversalSource(item) else { return nil }
    let cacheKey = item.metadata["sourceBundleIdentifier"] ?? "app:\(item.sourceApp)"
    if let cachedIcon = resolvedAppIconCache[cacheKey] {
        return cachedIcon
    }
    let icon: NSImage?
    if let bundleIdentifier = item.metadata["sourceBundleIdentifier"],
       let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
        icon = NSWorkspace.shared.icon(forFile: url.path)
    } else {
        icon = NSWorkspace.shared.runningApplications
            .first { $0.localizedName == item.sourceApp }?
            .icon
    }
    if let icon {
        resolvedAppIconCache[cacheKey] = icon
    }
    return icon
}

private func sourceFallbackIcon(for item: ClipItem) -> String {
    if isUniversalSource(item) {
        return "app.dashed"
    }
    let source = item.sourceApp.lowercased()
    if source.contains("safari") {
        return "safari"
    }
    if source.contains("chrome") || source.contains("browser") {
        return "globe"
    }
    if source.contains("finder") {
        return "folder"
    }
    if source.contains("obsidian") {
        return "note.text"
    }
    if source.contains("codex") || source.contains("terminal") || source.contains("iterm") {
        return "terminal"
    }
    switch item.kind {
    case .url:
        return "link"
    case .image:
        return "photo"
    case .file:
        return "folder"
    default:
        return "app.dashed"
    }
}

private func deviceIcon(for item: ClipItem) -> String {
    let family = rawSourceDeviceFamily(for: item) ?? (isRemoteClipboard(item) ? "" : localDisplayDeviceFamily)
    if isRemoteClipboard(item), isMobileDeviceFamily(family), !hasRemoteMobileEvidence(item) {
        return "macwindow"
    }
    if family.contains("iphone") {
        return "iphone"
    }
    if family.contains("ipad") {
        return "ipad"
    }
    if family.contains("watch") {
        return "applewatch"
    }
    if family.contains("macmini") {
        return "macmini"
    }
    if family.contains("macbook") {
        return "macbook"
    }
    if family.contains("imac") {
        return "desktopcomputer"
    }
    if family.contains("macstudio") {
        return "macstudio"
    }
    if family.contains("macpro") {
        return "macpro.gen3"
    }
    return "macwindow"
}

private func sourceIconBackground(for item: ClipItem) -> Color {
    return ClipXColor.surfaceStrong
}

private func sourceIconForeground(for item: ClipItem) -> Color {
    return ClipXColor.textSoft
}

private func tagTone(for item: ClipItem) -> ClipTag.Tone {
    if item.isSensitive {
        return .danger
    }
    if item.wasRTFDFixed {
        return .mint
    }
    switch item.kind {
    case .url:
        return .mint
    case .color:
        return .amber
    case .rtf, .rtfd, .html:
        return .accent
    default:
        return .neutral
    }
}

private func relativeAgeText(for date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    let hours = max(1, seconds / 3600)
    if hours < 24 {
        return String(format: L10n.t("%d hours ago"), hours)
    }
    return String(format: L10n.t("%d days ago"), max(1, hours / 24))
}
