import Foundation
import Combine

@MainActor
final class DeadlineStore: ObservableObject {
    static func defaultGroups(for language: AppLanguage) -> [String] {
        switch language {
        case .english:
            return ["Study", "Work", "Life", "Health", "Finance"]
        case .chinese:
            return ["学习", "工作", "生活", "健康", "财务"]
        }
    }

    static let fallbackGroupName = "Uncategorized"
    private static let builtInGroupSets: [[String]] = [
        defaultGroups(for: .english),
        defaultGroups(for: .chinese)
    ]

    @Published var items: [DeadlineItem] = [] {
        didSet { saveItems() }
    }
    @Published var viewStyle: DeadlineViewStyle = .progressBar {
        didSet {
            if oldValue != viewStyle {
                saveViewStyle()
            }
        }
    }
    @Published var sortOption: DeadlineSortOption = .addedDateDescending {
        didSet {
            if oldValue != sortOption {
                saveSortOption()
            }
        }
    }
    @Published var selectedFilterGroup: String? = nil {
        didSet {
            if oldValue != selectedFilterGroup {
                saveSelectedFilterGroup()
            }
        }
    }
    @Published var groups: [String] = DeadlineStore.defaultGroups(for: .english)
    @Published var backgroundStyle: BackgroundStyleOption = .white {
        didSet {
            if oldValue != backgroundStyle {
                saveBackgroundStyle()
            }
        }
    }
    @Published var liquidMotionEnabled: Bool = true {
        didSet {
            if oldValue != liquidMotionEnabled {
                saveLiquidMotionEnabled()
            }
        }
    }

    private let defaults = DeadlineStorage.sharedDefaults
    private let itemsStorageKey = DeadlineStorage.itemsStorageKey
    private let viewStyleStorageKey = DeadlineStorage.viewStyleStorageKey
    private let sortOptionStorageKey = DeadlineStorage.sortOptionStorageKey
    private let selectedFilterGroupStorageKey = DeadlineStorage.selectedFilterGroupStorageKey
    private let groupsStorageKey = DeadlineStorage.groupsStorageKey
    private let backgroundStyleStorageKey = DeadlineStorage.backgroundStyleStorageKey
    private let liquidMotionEnabledStorageKey = DeadlineStorage.liquidMotionEnabledStorageKey

    init() {
        DeadlineStorage.migrateStandardDefaultsIfNeeded()
        loadViewStyle()
        loadSortOption()
        loadGroups()
        loadSelectedFilterGroup()
        loadBackgroundStyle()
        loadLiquidMotionEnabled()
        loadItems()
        validateSelectedFilterGroup()
    }

    func addItem(title: String, category: String, detail: String, startDate: Date, endDate: Date) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, endDate > startDate else { return }
        let item = DeadlineItem(
            title: trimmedTitle,
            category: trimmedCategory.isEmpty ? (groups.first ?? Self.fallbackGroupName) : trimmedCategory,
            detail: trimmedDetail,
            startDate: startDate,
            endDate: endDate
        )
        items.append(item)
    }

    func updateItem(id: UUID, title: String, category: String, detail: String, startDate: Date, endDate: Date) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, endDate > startDate else { return }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].title = trimmedTitle
        items[index].category = trimmedCategory.isEmpty ? (groups.first ?? Self.fallbackGroupName) : trimmedCategory
        items[index].detail = trimmedDetail
        items[index].startDate = startDate
        items[index].endDate = endDate
    }

    func updateClosedItemDetail(id: UUID, detail: String) {
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].detail = trimmedDetail
    }

    func completeItem(id: UUID, at completedAt: Date = .now) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard items[index].canComplete(at: completedAt) else { return }
        items[index].completedAt = completedAt
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func items(in section: DeadlineSection, at now: Date) -> [DeadlineItem] {
        var result = items.filter { $0.section(at: now) == section }
        if let selectedFilterGroup {
            result = result.filter { $0.category == selectedFilterGroup }
        }

        switch sortOption {
        case .addedDateAscending:
            result.sort { $0.createdAt < $1.createdAt }
        case .addedDateDescending:
            result.sort { $0.createdAt > $1.createdAt }
        case .remainingTimeAscending:
            result.sort { sortReferenceDate(for: $0, in: section) < sortReferenceDate(for: $1, in: section) }
        case .remainingTimeDescending:
            result.sort { sortReferenceDate(for: $0, in: section) > sortReferenceDate(for: $1, in: section) }
        }
        return result
    }

    private func sortReferenceDate(for item: DeadlineItem, in section: DeadlineSection) -> Date {
        switch section {
        case .notStarted:
            return item.startDate
        case .inProgress, .ended:
            return item.endDate
        case .completed:
            return item.completedAt ?? item.endDate
        }
    }

    func toggleViewStyle() {
        viewStyle = (viewStyle == .progressBar) ? .grid : .progressBar
    }

    func setViewStyle(_ style: DeadlineViewStyle) {
        viewStyle = style
    }

    func addGroup(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !groups.contains(trimmed) else { return }
        groups.append(trimmed)
        saveGroups()
    }

    func removeGroups(at offsets: IndexSet) {
        var updated = groups
        for index in offsets.sorted(by: >) {
            updated.remove(at: index)
        }
        guard !updated.isEmpty else { return }
        groups = updated
        saveGroups()
        validateSelectedFilterGroup()
    }

    func removeGroup(named name: String) {
        guard let index = groups.firstIndex(of: name), groups.count > 1 else { return }
        let fallbackGroup = groups.first(where: { $0 != name }) ?? groups[0]
        groups.remove(at: index)

        for itemIndex in items.indices where items[itemIndex].category == name {
            items[itemIndex].category = fallbackGroup
        }

        if selectedFilterGroup == name {
            selectedFilterGroup = nil
        }

        saveGroups()
        validateSelectedFilterGroup()
    }

    func renameGroup(from oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName else { return }
        guard !groups.contains(trimmed) else { return }
        guard let index = groups.firstIndex(of: oldName) else { return }

        groups[index] = trimmed

        for itemIndex in items.indices where items[itemIndex].category == oldName {
            items[itemIndex].category = trimmed
        }

        if selectedFilterGroup == oldName {
            selectedFilterGroup = trimmed
        }

        saveGroups()
    }

    func resetGroupsToDefault() {
        groups = Self.defaultGroups(for: .english)
        saveGroups()
        validateSelectedFilterGroup()
    }

    func applyDefaultGroupLocalizationIfNeeded(language: AppLanguage) {
        let targetGroups = Self.defaultGroups(for: language)
        if groups == targetGroups {
            return
        }

        guard let sourceGroups = Self.builtInGroupSets.first(where: { $0 == groups }) else {
            return
        }

        let groupMap = Dictionary(uniqueKeysWithValues: zip(sourceGroups, targetGroups))
        groups = targetGroups

        for index in items.indices {
            if let mapped = groupMap[items[index].category] {
                items[index].category = mapped
            }
        }

        if let selectedFilterGroup, let mapped = groupMap[selectedFilterGroup] {
            self.selectedFilterGroup = mapped
        }

        saveGroups()
        validateSelectedFilterGroup()
    }

    private func loadItems() {
        guard
            let data = defaults.data(forKey: itemsStorageKey),
            let decoded = try? JSONDecoder().decode([DeadlineItem].self, from: data)
        else { return }
        items = decoded
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: itemsStorageKey)
        DeadlineStorage.reloadWidgets()
    }

    private func loadViewStyle() {
        guard
            let raw = defaults.string(forKey: viewStyleStorageKey),
            let style = DeadlineViewStyle(rawValue: raw)
        else { return }
        viewStyle = style
    }

    private func saveViewStyle() {
        defaults.set(viewStyle.rawValue, forKey: viewStyleStorageKey)
    }

    private func loadSortOption() {
        guard
            let raw = defaults.string(forKey: sortOptionStorageKey),
            let option = DeadlineSortOption.fromStoredValue(raw)
        else { return }
        sortOption = option
    }

    private func saveSortOption() {
        defaults.set(sortOption.rawValue, forKey: sortOptionStorageKey)
    }

    private func loadSelectedFilterGroup() {
        selectedFilterGroup = defaults.string(forKey: selectedFilterGroupStorageKey)
    }

    private func saveSelectedFilterGroup() {
        defaults.set(selectedFilterGroup, forKey: selectedFilterGroupStorageKey)
    }

    private func loadGroups() {
        let stored = defaults.stringArray(forKey: groupsStorageKey) ?? Self.defaultGroups(for: .english)
        let normalized = stored
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var unique: [String] = []
        for group in normalized where !unique.contains(group) {
            unique.append(group)
        }
        groups = unique.isEmpty ? Self.defaultGroups(for: .english) : unique
    }

    private func saveGroups() {
        defaults.set(groups, forKey: groupsStorageKey)
        DeadlineStorage.reloadWidgets()
    }

    private func validateSelectedFilterGroup() {
        guard let selectedFilterGroup else { return }
        if !groups.contains(selectedFilterGroup) {
            self.selectedFilterGroup = nil
        }
    }

    private func loadBackgroundStyle() {
        guard
            let raw = defaults.string(forKey: backgroundStyleStorageKey),
            let style = BackgroundStyleOption(rawValue: raw)
        else { return }
        backgroundStyle = style
    }

    private func saveBackgroundStyle() {
        defaults.set(backgroundStyle.rawValue, forKey: backgroundStyleStorageKey)
    }

    private func loadLiquidMotionEnabled() {
        if defaults.object(forKey: liquidMotionEnabledStorageKey) == nil {
            liquidMotionEnabled = true
            return
        }
        liquidMotionEnabled = defaults.bool(forKey: liquidMotionEnabledStorageKey)
    }

    private func saveLiquidMotionEnabled() {
        defaults.set(liquidMotionEnabled, forKey: liquidMotionEnabledStorageKey)
    }
}
