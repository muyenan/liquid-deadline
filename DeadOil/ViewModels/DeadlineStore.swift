import Foundation
import Combine

@MainActor
final class DeadlineStore: ObservableObject {
    static let defaultGroups: [String] = [
        "学习",
        "工作",
        "生活",
        "健康",
        "财务"
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
    @Published var sortOption: DeadlineSortOption = .recentAdded {
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
    @Published var groups: [String] = DeadlineStore.defaultGroups
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

    private let itemsStorageKey = "deadline_oil_items_v1"
    private let viewStyleStorageKey = "deadline_oil_view_style_v1"
    private let sortOptionStorageKey = "deadline_oil_sort_option_v1"
    private let selectedFilterGroupStorageKey = "deadline_oil_selected_filter_group_v1"
    private let groupsStorageKey = "deadline_oil_groups_v1"
    private let backgroundStyleStorageKey = "deadline_oil_background_style_v1"
    private let liquidMotionEnabledStorageKey = "deadline_oil_liquid_motion_enabled_v1"

    init() {
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
            category: trimmedCategory.isEmpty ? (groups.first ?? "未分类") : trimmedCategory,
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
        items[index].category = trimmedCategory.isEmpty ? (groups.first ?? "未分类") : trimmedCategory
        items[index].detail = trimmedDetail
        items[index].startDate = startDate
        items[index].endDate = endDate
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
        case .recentAdded:
            result.sort { $0.createdAt > $1.createdAt }
        case .byDate:
            result.sort { lhs, rhs in
                if section == .finished {
                    return lhs.endDate > rhs.endDate
                }
                return lhs.endDate < rhs.endDate
            }
        }
        return result
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
        groups = Self.defaultGroups
        saveGroups()
        validateSelectedFilterGroup()
    }

    private func loadItems() {
        guard
            let data = UserDefaults.standard.data(forKey: itemsStorageKey),
            let decoded = try? JSONDecoder().decode([DeadlineItem].self, from: data)
        else { return }
        items = decoded
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: itemsStorageKey)
    }

    private func loadViewStyle() {
        guard
            let raw = UserDefaults.standard.string(forKey: viewStyleStorageKey),
            let style = DeadlineViewStyle(rawValue: raw)
        else { return }
        viewStyle = style
    }

    private func saveViewStyle() {
        UserDefaults.standard.set(viewStyle.rawValue, forKey: viewStyleStorageKey)
    }

    private func loadSortOption() {
        guard
            let raw = UserDefaults.standard.string(forKey: sortOptionStorageKey),
            let option = DeadlineSortOption(rawValue: raw)
        else { return }
        sortOption = option
    }

    private func saveSortOption() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: sortOptionStorageKey)
    }

    private func loadSelectedFilterGroup() {
        selectedFilterGroup = UserDefaults.standard.string(forKey: selectedFilterGroupStorageKey)
    }

    private func saveSelectedFilterGroup() {
        UserDefaults.standard.set(selectedFilterGroup, forKey: selectedFilterGroupStorageKey)
    }

    private func loadGroups() {
        let stored = UserDefaults.standard.stringArray(forKey: groupsStorageKey) ?? Self.defaultGroups
        let normalized = stored
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var unique: [String] = []
        for group in normalized where !unique.contains(group) {
            unique.append(group)
        }
        groups = unique.isEmpty ? Self.defaultGroups : unique
    }

    private func saveGroups() {
        UserDefaults.standard.set(groups, forKey: groupsStorageKey)
    }

    private func validateSelectedFilterGroup() {
        guard let selectedFilterGroup else { return }
        if !groups.contains(selectedFilterGroup) {
            self.selectedFilterGroup = nil
        }
    }

    private func loadBackgroundStyle() {
        guard
            let raw = UserDefaults.standard.string(forKey: backgroundStyleStorageKey),
            let style = BackgroundStyleOption(rawValue: raw)
        else { return }
        backgroundStyle = style
    }

    private func saveBackgroundStyle() {
        UserDefaults.standard.set(backgroundStyle.rawValue, forKey: backgroundStyleStorageKey)
    }

    private func loadLiquidMotionEnabled() {
        if UserDefaults.standard.object(forKey: liquidMotionEnabledStorageKey) == nil {
            liquidMotionEnabled = true
            return
        }
        liquidMotionEnabled = UserDefaults.standard.bool(forKey: liquidMotionEnabledStorageKey)
    }

    private func saveLiquidMotionEnabled() {
        UserDefaults.standard.set(liquidMotionEnabled, forKey: liquidMotionEnabledStorageKey)
    }
}
