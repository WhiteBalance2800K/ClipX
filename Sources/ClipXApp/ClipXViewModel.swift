import ClipXCore
import Foundation
import SwiftUI

enum SmartFilter: String {
    case favorites
    case sensitive
}

final class ClipXViewModel: ObservableObject {
    @Published var items: [ClipItem] = []
    @Published var selectedID: ClipItem.ID?
    @Published var searchQuery = ""
    @Published var selectedCategory: ClipKind?
    @Published var selectedSmartFilter: SmartFilter?
    @Published var statusMessage = ""
    @Published var isMonitoringPaused = false
    @Published var autoFixRTFD = true
    @Published var languageCode = ClipXAppearance.selectedLanguageCode
    @Published var appearanceVersion = 0

    private let store: HistoryStoring

    init(store: HistoryStoring) {
        self.store = store
    }

    var filteredItems: [ClipItem] {
        let baseItems: [ClipItem]
        if let selectedSmartFilter {
            baseItems = items.filter { item in
                switch selectedSmartFilter {
                case .favorites:
                    item.isFavorite
                case .sensitive:
                    item.isSensitive
                }
            }
        } else if let selectedCategory {
            baseItems = items.filter { Self.matchesCategory($0, selectedCategory) }
        } else {
            baseItems = items
        }

        let sortedItems = baseItems.sorted(by: Self.sortPinnedFirst)
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sortedItems }
        return sortedItems.filter { item in
            let sourceTerms = item.metadata["remoteClipboard"] == "true"
                ? "\(item.sourceApp) Universal Clipboard Continuity iCloud Mac MacBook iPhone iPad iOS 设备 通用剪切板"
                : item.sourceApp
            return [
                item.preview,
                sourceTerms,
                item.kind.rawValue,
                item.payload.searchableText,
                item.metadata.values.joined(separator: " ")
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(query)
        }
    }

    func selectCategory(_ kind: ClipKind?) {
        selectedSmartFilter = nil
        selectedCategory = kind
        selectedID = filteredItems.first?.id
    }

    func selectSmartFilter(_ filter: SmartFilter) {
        selectedCategory = nil
        selectedSmartFilter = filter
        selectedID = filteredItems.first?.id
    }

    func count(for kind: ClipKind?) -> Int {
        guard let kind else { return items.count }
        return items.filter { Self.matchesCategory($0, kind) }.count
    }

    func count(for filter: SmartFilter) -> Int {
        switch filter {
        case .favorites:
            return items.filter(\.isFavorite).count
        case .sensitive:
            return items.filter(\.isSensitive).count
        }
    }

    func moveSelection(by offset: Int) {
        let visibleItems = filteredItems
        guard !visibleItems.isEmpty else {
            selectedID = nil
            return
        }
        guard let selectedID,
              let currentIndex = visibleItems.firstIndex(where: { $0.id == selectedID }) else {
            self.selectedID = visibleItems.first?.id
            return
        }
        let nextIndex = min(max(currentIndex + offset, 0), visibleItems.count - 1)
        self.selectedID = visibleItems[nextIndex].id
    }

    private static func sortPinnedFirst(_ lhs: ClipItem, _ rhs: ClipItem) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }
        return lhs.createdAt > rhs.createdAt
    }

    private static func matchesCategory(_ item: ClipItem, _ kind: ClipKind) -> Bool {
        switch kind {
        case .text:
            return [.text, .rtf, .rtfd, .html].contains(item.kind)
        default:
            return item.kind == kind
        }
    }

    var selectedItem: ClipItem? {
        if let selectedID, let item = filteredItems.first(where: { $0.id == selectedID }) {
            return item
        }
        return filteredItems.first
    }

    func load() {
        do {
            items = try store.fetchAll(limit: 500)
            items.sort(by: Self.sortPinnedFirst)
            selectedID = filteredItems.first?.id
            statusMessage = L10n.t("Ready")
        } catch {
            statusMessage = "\(L10n.t("Store unavailable")): \(error.localizedDescription)"
        }
    }

    func capture(_ item: ClipItem) {
        let latestItem = items.max { lhs, rhs in lhs.createdAt < rhs.createdAt }
        if latestItem?.payload == item.payload {
            return
        }
        do {
            try store.upsert(item)
            items.removeAll { $0.id == item.id }
            items.insert(item, at: 0)
            items.sort(by: Self.sortPinnedFirst)
            selectedID = item.id
            statusMessage = item.wasRTFDFixed ? L10n.t("RTFD converted to plain text") : L10n.t("Clipboard item saved")
        } catch {
            statusMessage = "\(L10n.t("Could not save clipboard item")): \(error.localizedDescription)"
        }
    }

    func deleteSelected() {
        guard let item = selectedItem else { return }
        delete(item)
    }

    func delete(_ item: ClipItem) {
        do {
            try store.delete(id: item.id)
            items.removeAll { $0.id == item.id }
            selectedID = filteredItems.first?.id
            statusMessage = L10n.t("Clipboard item deleted")
        } catch {
            statusMessage = "\(L10n.t("Could not delete item")): \(error.localizedDescription)"
        }
    }

    func toggleFavorite(_ item: ClipItem) {
        update(item) { $0.isFavorite.toggle() }
    }

    func togglePin(_ item: ClipItem) {
        update(item) { $0.isPinned.toggle() }
    }

    func recordPaste(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let currentCount = Int(items[index].metadata["pasteCount"] ?? "0") ?? 0
        items[index].metadata["pasteCount"] = "\(currentCount + 1)"
        do {
            try store.upsert(items[index])
        } catch {
            statusMessage = "\(L10n.t("Could not update item")): \(error.localizedDescription)"
        }
    }

    func refreshPresentation() {
        languageCode = ClipXAppearance.selectedLanguageCode
        appearanceVersion += 1
    }

    private func update(_ item: ClipItem, mutate: (inout ClipItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        mutate(&items[index])
        items.sort(by: Self.sortPinnedFirst)
        selectedID = item.id
        do {
            try store.updateFlags(
                id: item.id,
                favorite: items.first(where: { $0.id == item.id })?.isFavorite,
                pinned: items.first(where: { $0.id == item.id })?.isPinned
            )
        } catch {
            statusMessage = "\(L10n.t("Could not update item")): \(error.localizedDescription)"
        }
    }
}
