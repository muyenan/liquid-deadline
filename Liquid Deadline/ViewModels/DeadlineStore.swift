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
    static let foregroundRefreshInterval: TimeInterval = 15 * 60
    static let backgroundRefreshRequestInterval: TimeInterval = 60 * 60
    private static let recurrenceHorizonDays = 180
    private static let builtInGroupSets: [[String]] = [
        defaultGroups(for: .english),
        defaultGroups(for: .chinese)
    ]

    @Published var items: [DeadlineItem] = [] {
        didSet { saveItems() }
    }
    @Published var subscriptions: [DeadlineSubscription] = [] {
        didSet { saveSubscriptions() }
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
    @Published var isRefreshingSubscriptions = false
    @Published var lastSyncErrorMessage: String?
    @Published private(set) var lastSubscriptionRefreshAt: Date? {
        didSet { saveLastSubscriptionRefreshAt() }
    }

    private let defaults = DeadlineStorage.sharedDefaults
    private let itemsStorageKey = DeadlineStorage.itemsStorageKey
    private let subscriptionsStorageKey = DeadlineStorage.subscriptionsStorageKey
    private let lastSubscriptionRefreshStorageKey = DeadlineStorage.lastSubscriptionRefreshStorageKey
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
        loadSubscriptions()
        loadLastSubscriptionRefreshAt()
        loadItems()
        extendRecurringItemsIfNeeded(at: .now)
        validateSelectedFilterGroup()
    }

    func addItem(
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        repeatRule: DeadlineRepeatRule? = nil
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = normalizedCategoryName(from: category)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false, endDate > startDate else { return }

        if let repeatRule {
            items.append(contentsOf: makeRecurringItems(
                title: trimmedTitle,
                category: normalizedCategory,
                detail: trimmedDetail,
                startDate: startDate,
                endDate: endDate,
                repeatRule: repeatRule,
                sourceKind: .manual
            ))
            return
        }

        items.append(
            DeadlineItem(
                title: trimmedTitle,
                category: normalizedCategory,
                detail: trimmedDetail,
                startDate: startDate,
                endDate: endDate
            )
        )
    }

    func importICSFile(data: Data, category: String, importedAt: Date = .now) throws {
        let drafts = try ICSCalendarService.drafts(from: data, importedAt: importedAt)
        let normalizedCategory = normalizedCategoryName(from: category)
        let importedItems = drafts.map { draft in
            makeImportedItem(
                from: draft,
                category: normalizedCategory,
                sourceKind: .importedFile,
                subscriptionID: nil,
                createdAt: importedAt
            )
        }
        items.append(contentsOf: importedItems)
    }

    func addSubscription(urlString: String, category: String) async throws {
        let normalizedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedURL.isEmpty == false else {
            throw DeadlineSyncError.invalidURL
        }

        let normalizedCategory = normalizedCategoryName(from: category)
        let subscription = DeadlineSubscription(urlString: normalizedURL, category: normalizedCategory)
        subscriptions.append(subscription)

        do {
            _ = try await refreshSubscription(id: subscription.id, importedAt: subscription.createdAt)
        } catch {
            throw error
        }
    }

    @discardableResult
    func refreshSubscription(id: UUID, importedAt: Date = .now, manageLoadingState: Bool = true) async throws -> Int {
        guard let subscriptionIndex = subscriptions.firstIndex(where: { $0.id == id }) else { return 0 }
        if manageLoadingState {
            isRefreshingSubscriptions = true
            lastSyncErrorMessage = nil
        }

        var subscription = subscriptions[subscriptionIndex]
        subscription.lastAttemptedAt = importedAt

        do {
            let drafts = try await ICSCalendarService.fetchDrafts(
                fromRemoteURLString: subscription.normalizedURLString,
                importedAt: importedAt
            )

            items = mergeSubscriptionDrafts(
                drafts,
                with: subscription,
                importedAt: importedAt,
                into: items
            )

            subscription.lastSyncedAt = importedAt
            subscription.lastErrorMessage = nil
            subscriptions[subscriptionIndex] = subscription
            lastSubscriptionRefreshAt = importedAt
            if manageLoadingState {
                isRefreshingSubscriptions = false
            }
            return drafts.count
        } catch {
            subscription.lastErrorMessage = error.localizedDescription
            subscriptions[subscriptionIndex] = subscription
            lastSyncErrorMessage = error.localizedDescription
            if manageLoadingState {
                isRefreshingSubscriptions = false
            }
            throw error
        }
    }

    func refreshSubscriptions(force: Bool = false, now: Date = .now) async {
        guard subscriptions.isEmpty == false else { return }

        if force == false, let lastSubscriptionRefreshAt, now.timeIntervalSince(lastSubscriptionRefreshAt) < Self.foregroundRefreshInterval {
            return
        }

        isRefreshingSubscriptions = true
        lastSyncErrorMessage = nil

        for subscription in subscriptions {
            do {
                _ = try await refreshSubscription(id: subscription.id, importedAt: now, manageLoadingState: false)
            } catch {
                lastSyncErrorMessage = error.localizedDescription
            }
        }

        isRefreshingSubscriptions = false
    }

    func refreshSubscriptionsIfNeeded(now: Date = .now) async {
        await refreshSubscriptions(force: false, now: now)
    }

    func extendRecurringItemsIfNeeded(at now: Date = .now) {
        guard items.isEmpty == false else { return }

        let horizonEnd = Calendar.current.date(byAdding: .day, value: Self.recurrenceHorizonDays, to: now) ?? now
        var updatedItems = items
        let seedItems = updatedItems.filter(\.isRepeatSeed)

        for seed in seedItems {
            extendRecurringSeries(for: seed, through: horizonEnd, items: &updatedItems)
        }

        if updatedItems != items {
            items = updatedItems
        }
    }

    func updateItem(id: UUID, title: String, category: String, detail: String, startDate: Date, endDate: Date) {
        updateItem(
            id: id,
            title: title,
            category: category,
            detail: detail,
            startDate: startDate,
            endDate: endDate,
            scope: .thisEvent
        )
    }

    func updateItem(
        id: UUID,
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        scope: DeadlineRecurringChangeScope
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = normalizedCategoryName(from: category)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false, endDate > startDate else { return }
        guard let item = items.first(where: { $0.id == id }) else { return }

        guard
            item.belongsToRepeatSeries,
            scope == .futureEvents,
            let repeatContext = recurringContext(for: item),
            let repeatRule = repeatContext.seedItem.repeatRule
        else {
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items[index].title = trimmedTitle
            items[index].category = normalizedCategory
            items[index].detail = trimmedDetail
            items[index].startDate = startDate
            items[index].endDate = endDate
            return
        }

        let futureItems = Array(repeatContext.seriesItems.dropFirst(repeatContext.currentPosition))
        var updatedItems = items

        if let previousItem = repeatContext.previousItem {
            updatedItems[repeatContext.seedIndex].repeatRule?.endDate = previousItem.startDate
        }

        updatedItems.removeAll { candidate in
            candidate.repeatSeriesID == repeatContext.seriesID &&
            candidate.repeatOccurrenceIndex >= repeatContext.currentItem.repeatOccurrenceIndex
        }

        let rebuiltItems = rebuildRecurringSegment(
            title: trimmedTitle,
            category: normalizedCategory,
            detail: trimmedDetail,
            startDate: startDate,
            endDate: endDate,
            repeatRule: repeatRule,
            sourceKind: item.sourceKind,
            previousItems: futureItems
        )

        updatedItems.append(contentsOf: rebuiltItems)
        items = updatedItems
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
        if items[index].belongsToRepeatSeries {
            extendRecurringItemsIfNeeded(at: completedAt)
        }
    }

    @discardableResult
    func markItemIncomplete(id: UUID, at now: Date = .now) -> DeadlineSection? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        items[index].completedAt = nil
        return items[index].section(at: now)
    }

    func removeItem(id: UUID) {
        removeItem(id: id, scope: .thisEvent)
    }

    func removeItem(id: UUID, scope: DeadlineRecurringChangeScope) {
        guard let item = items.first(where: { $0.id == id }) else { return }

        guard item.belongsToRepeatSeries, let repeatContext = recurringContext(for: item) else {
            items.removeAll { $0.id == id }
            return
        }

        switch scope {
        case .thisEvent:
            handleSingleRecurringRemoval(for: repeatContext)
        case .futureEvents:
            handleFutureRecurringRemoval(for: repeatContext)
        }

        extendRecurringItemsIfNeeded(at: .now)
    }

    func removeSubscription(id: UUID) {
        subscriptions.removeAll { $0.id == id }
        items.removeAll { $0.subscriptionID == id }
    }

    func items(in section: DeadlineSection, at now: Date) -> [DeadlineItem] {
        let visibleRecurringOpenItemIDs = visibleRecurringOpenItemIDs(at: now)
        var result = items.filter {
            $0.section(at: now) == section &&
            shouldDisplay($0, in: section, visibleRecurringOpenItemIDs: visibleRecurringOpenItemIDs, now: now)
        }
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

    private func shouldDisplay(
        _ item: DeadlineItem,
        in section: DeadlineSection,
        visibleRecurringOpenItemIDs: Set<UUID>,
        now: Date
    ) -> Bool {
        guard item.belongsToRepeatSeries else { return true }

        switch section {
        case .notStarted, .inProgress:
            guard item.completedAt == nil, item.endDate > now else { return true }
            return visibleRecurringOpenItemIDs.contains(item.id)
        case .completed, .ended:
            return true
        }
    }

    private func visibleRecurringOpenItemIDs(at now: Date) -> Set<UUID> {
        let recurringOpenItems = items.filter {
            $0.belongsToRepeatSeries &&
            $0.completedAt == nil &&
            $0.endDate > now
        }

        let grouped = Dictionary(grouping: recurringOpenItems) { $0.repeatSeriesID ?? UUID() }
        var visibleIDs = Set<UUID>()

        for (_, candidates) in grouped {
            let nextVisible = candidates.min { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.repeatOccurrenceIndex < rhs.repeatOccurrenceIndex
                }
                return lhs.startDate < rhs.startDate
            }

            if let nextVisible {
                visibleIDs.insert(nextVisible.id)
            }
        }

        return visibleIDs
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
        guard trimmed.isEmpty == false, groups.contains(trimmed) == false else { return }
        groups.append(trimmed)
        saveGroups()
    }

    func removeGroups(at offsets: IndexSet) {
        var updated = groups
        for index in offsets.sorted(by: >) {
            updated.remove(at: index)
        }
        guard updated.isEmpty == false else { return }
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
        for subscriptionIndex in subscriptions.indices where subscriptions[subscriptionIndex].category == name {
            subscriptions[subscriptionIndex].category = fallbackGroup
        }

        if selectedFilterGroup == name {
            selectedFilterGroup = nil
        }

        saveGroups()
        validateSelectedFilterGroup()
    }

    func renameGroup(from oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed != oldName else { return }
        guard groups.contains(trimmed) == false else { return }
        guard let index = groups.firstIndex(of: oldName) else { return }

        groups[index] = trimmed

        for itemIndex in items.indices where items[itemIndex].category == oldName {
            items[itemIndex].category = trimmed
        }
        for subscriptionIndex in subscriptions.indices where subscriptions[subscriptionIndex].category == oldName {
            subscriptions[subscriptionIndex].category = trimmed
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
        for index in subscriptions.indices {
            if let mapped = groupMap[subscriptions[index].category] {
                subscriptions[index].category = mapped
            }
        }

        if let selectedFilterGroup, let mapped = groupMap[selectedFilterGroup] {
            self.selectedFilterGroup = mapped
        }

        saveGroups()
        validateSelectedFilterGroup()
    }

    private func makeRecurringItems(
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        repeatRule: DeadlineRepeatRule,
        sourceKind: DeadlineItemSourceKind,
        seriesID: UUID = UUID(),
        createdAt: Date = .now
    ) -> [DeadlineItem] {
        let seed = DeadlineItem(
            title: title,
            category: category,
            detail: detail,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            sourceKind: sourceKind,
            repeatSeriesID: seriesID,
            repeatOccurrenceIndex: 0,
            repeatRule: repeatRule
        )

        var generatedItems = [seed]
        let horizonEnd = Calendar.current.date(byAdding: .day, value: Self.recurrenceHorizonDays, to: startDate) ?? endDate
        extendRecurringSeries(for: seed, through: horizonEnd, items: &generatedItems)
        return generatedItems
    }

    private func extendRecurringSeries(for seed: DeadlineItem, through horizonEnd: Date, items: inout [DeadlineItem]) {
        guard
            let repeatSeriesID = seed.repeatSeriesID,
            let repeatRule = seed.repeatRule
        else {
            return
        }

        let existingSeriesItems = items
            .filter { $0.repeatSeriesID == repeatSeriesID }
            .sorted { $0.repeatOccurrenceIndex < $1.repeatOccurrenceIndex }

        guard let lastExistingItem = existingSeriesItems.last else { return }

        let duration = lastExistingItem.endDate.timeIntervalSince(lastExistingItem.startDate)
        let limitDate = repeatRule.endDate ?? horizonEnd
        var occurrenceIndex = lastExistingItem.repeatOccurrenceIndex
        var nextStartDate = lastExistingItem.startDate

        while occurrenceIndex < 1024 {
            guard let candidateStartDate = repeatRule.nextDate(after: nextStartDate) else { break }
            if candidateStartDate > limitDate || candidateStartDate > horizonEnd {
                break
            }

            occurrenceIndex += 1
            if items.contains(where: {
                $0.repeatSeriesID == repeatSeriesID &&
                $0.repeatOccurrenceIndex == occurrenceIndex
            }) {
                nextStartDate = candidateStartDate
                continue
            }

            items.append(
                DeadlineItem(
                    title: seed.title,
                    category: seed.category,
                    detail: seed.detail,
                    startDate: candidateStartDate,
                    endDate: candidateStartDate.addingTimeInterval(duration),
                    sourceKind: seed.sourceKind,
                    repeatSeriesID: repeatSeriesID,
                    repeatOccurrenceIndex: occurrenceIndex
                )
            )

            nextStartDate = candidateStartDate
        }
    }

    private func mergeSubscriptionDrafts(
        _ drafts: [ICSImportedItemDraft],
        with subscription: DeadlineSubscription,
        importedAt: Date,
        into currentItems: [DeadlineItem]
    ) -> [DeadlineItem] {
        var updatedItems = currentItems
        let existingIndexes: [String: Int] = updatedItems.enumerated().reduce(into: [:]) { partialResult, entry in
            let index = entry.offset
            let item = entry.element
            guard item.subscriptionID == subscription.id, let externalEventIdentifier = item.externalEventIdentifier else {
                return
            }
            partialResult[externalEventIdentifier] = index
        }

        let seenIdentifiers = Set(drafts.map(\.externalIdentifier))

        for draft in drafts {
            if let existingIndex = existingIndexes[draft.externalIdentifier] {
                let existingItem = updatedItems[existingIndex]
                updatedItems[existingIndex].title = draft.title
                updatedItems[existingIndex].category = subscription.category
                updatedItems[existingIndex].detail = draft.detail
                updatedItems[existingIndex].endDate = draft.endDate
                updatedItems[existingIndex].isAllDay = draft.isAllDay
                updatedItems[existingIndex].sourceKind = .subscribedURL
                updatedItems[existingIndex].subscriptionID = subscription.id
                updatedItems[existingIndex].externalEventIdentifier = draft.externalIdentifier
                updatedItems[existingIndex].originalStartDateWasMissing = draft.originalStartDateWasMissing
                updatedItems[existingIndex].completedAt = existingItem.completedAt
                if draft.originalStartDateWasMissing {
                    if existingItem.originalStartDateWasMissing {
                        updatedItems[existingIndex].startDate = existingItem.startDate
                    } else if existingItem.createdAt < draft.endDate {
                        updatedItems[existingIndex].startDate = existingItem.createdAt
                    } else {
                        updatedItems[existingIndex].startDate = draft.endDate.addingTimeInterval(-1)
                    }
                } else {
                    updatedItems[existingIndex].startDate = draft.startDate
                }
            } else {
                updatedItems.append(
                    makeImportedItem(
                        from: draft,
                        category: subscription.category,
                        sourceKind: .subscribedURL,
                        subscriptionID: subscription.id,
                        createdAt: importedAt
                    )
                )
            }
        }

        updatedItems.removeAll { item in
            guard item.subscriptionID == subscription.id else { return false }
            guard let externalEventIdentifier = item.externalEventIdentifier else { return false }
            return seenIdentifiers.contains(externalEventIdentifier) == false
        }

        return updatedItems
    }

    private func makeImportedItem(
        from draft: ICSImportedItemDraft,
        category: String,
        sourceKind: DeadlineItemSourceKind,
        subscriptionID: UUID?,
        createdAt: Date
    ) -> DeadlineItem {
        DeadlineItem(
            title: draft.title,
            category: category,
            detail: draft.detail,
            startDate: draft.startDate,
            endDate: draft.endDate,
            createdAt: createdAt,
            sourceKind: sourceKind,
            subscriptionID: subscriptionID,
            externalEventIdentifier: draft.externalIdentifier,
            originalStartDateWasMissing: draft.originalStartDateWasMissing,
            isAllDay: draft.isAllDay
        )
    }

    private func normalizedCategoryName(from category: String) -> String {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCategory.isEmpty ? (groups.first ?? Self.fallbackGroupName) : trimmedCategory
    }

    private func recurringContext(for item: DeadlineItem) -> RecurringContext? {
        guard let repeatSeriesID = item.repeatSeriesID else { return nil }

        let seriesItems = items
            .filter { $0.repeatSeriesID == repeatSeriesID }
            .sorted { $0.repeatOccurrenceIndex < $1.repeatOccurrenceIndex }

        guard
            let currentPosition = seriesItems.firstIndex(where: { $0.id == item.id }),
            let seedItem = seriesItems.first(where: { $0.repeatRule != nil }),
            let seedIndex = items.firstIndex(where: { $0.id == seedItem.id })
        else {
            return nil
        }

        return RecurringContext(
            seriesID: repeatSeriesID,
            seedItem: seedItem,
            seedIndex: seedIndex,
            seriesItems: seriesItems,
            currentItem: seriesItems[currentPosition],
            currentPosition: currentPosition
        )
    }

    private func handleSingleRecurringRemoval(for context: RecurringContext) {
        var updatedItems = items
        let removedItem = context.currentItem

        updatedItems.removeAll { $0.id == removedItem.id }

        if context.currentItem.id == context.seedItem.id {
            guard
                let nextItem = context.nextItem,
                let nextIndex = updatedItems.firstIndex(where: { $0.id == nextItem.id })
            else {
                items = updatedItems
                return
            }

            updatedItems[nextIndex].repeatRule = context.seedItem.repeatRule
        }

        items = updatedItems
    }

    private func handleFutureRecurringRemoval(for context: RecurringContext) {
        if context.currentItem.id == context.seedItem.id {
            items.removeAll { $0.repeatSeriesID == context.seriesID }
            return
        }

        var updatedItems = items
        if let previousItem = context.previousItem {
            updatedItems[context.seedIndex].repeatRule?.endDate = previousItem.startDate
        }

        updatedItems.removeAll { candidate in
            candidate.repeatSeriesID == context.seriesID &&
            candidate.repeatOccurrenceIndex >= context.currentItem.repeatOccurrenceIndex
        }
        items = updatedItems
    }

    private func rebuildRecurringSegment(
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        repeatRule: DeadlineRepeatRule,
        sourceKind: DeadlineItemSourceKind,
        previousItems: [DeadlineItem]
    ) -> [DeadlineItem] {
        var rebuiltItems = makeRecurringItems(
            title: title,
            category: category,
            detail: detail,
            startDate: startDate,
            endDate: endDate,
            repeatRule: repeatRule,
            sourceKind: sourceKind,
            createdAt: previousItems.first?.createdAt ?? .now
        )

        for index in rebuiltItems.indices {
            guard index < previousItems.count else { continue }
            rebuiltItems[index].completedAt = previousItems[index].completedAt
            rebuiltItems[index].createdAt = previousItems[index].createdAt
        }

        return rebuiltItems
    }

    private struct RecurringContext {
        let seriesID: UUID
        let seedItem: DeadlineItem
        let seedIndex: Int
        let seriesItems: [DeadlineItem]
        let currentItem: DeadlineItem
        let currentPosition: Int

        var previousItem: DeadlineItem? {
            guard currentPosition > 0 else { return nil }
            return seriesItems[currentPosition - 1]
        }

        var nextItem: DeadlineItem? {
            guard currentPosition + 1 < seriesItems.count else { return nil }
            return seriesItems[currentPosition + 1]
        }
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

    private func loadSubscriptions() {
        guard
            let data = defaults.data(forKey: subscriptionsStorageKey),
            let decoded = try? JSONDecoder().decode([DeadlineSubscription].self, from: data)
        else { return }
        subscriptions = decoded
    }

    private func saveSubscriptions() {
        guard let data = try? JSONEncoder().encode(subscriptions) else { return }
        defaults.set(data, forKey: subscriptionsStorageKey)
    }

    private func loadLastSubscriptionRefreshAt() {
        lastSubscriptionRefreshAt = defaults.object(forKey: lastSubscriptionRefreshStorageKey) as? Date
    }

    private func saveLastSubscriptionRefreshAt() {
        defaults.set(lastSubscriptionRefreshAt, forKey: lastSubscriptionRefreshStorageKey)
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
            .filter { $0.isEmpty == false }
        var unique: [String] = []
        for group in normalized where unique.contains(group) == false {
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
        if groups.contains(selectedFilterGroup) == false {
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
