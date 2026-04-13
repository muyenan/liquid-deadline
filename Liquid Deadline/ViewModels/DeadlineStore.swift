import Foundation
import Combine
import CloudKit

@MainActor
final class DeadlineStore: ObservableObject {
    static func defaultGroups(for language: AppLanguage) -> [String] {
        switch language {
        case .english:
            return ["Study", "Work", "Life", "Health", "Finance"]
        case .chinese:
            return ["学习", "工作", "生活", "健康", "财务"]
        case .japanese:
            return ["勉強", "仕事", "生活", "健康", "家計"]
        case .korean:
            return ["공부", "업무", "생활", "건강", "재정"]
        case .spanishSpain:
            return ["Estudio", "Trabajo", "Vida", "Salud", "Finanzas"]
        case .spanishMexico:
            return ["Estudio", "Trabajo", "Vida", "Salud", "Finanzas"]
        case .french:
            return ["Études", "Travail", "Vie", "Santé", "Finances"]
        case .german:
            return ["Lernen", "Arbeit", "Leben", "Gesundheit", "Finanzen"]
        case .thai:
            return ["การเรียน", "งาน", "ชีวิต", "สุขภาพ", "การเงิน"]
        case .vietnamese:
            return ["Học tập", "Công việc", "Cuộc sống", "Sức khỏe", "Tài chính"]
        case .indonesian:
            return ["Belajar", "Kerja", "Hidup", "Kesehatan", "Keuangan"]
        case .russian:
            return ["Учёба", "Работа", "Жизнь", "Здоровье", "Финансы"]
        }
    }

    static var fallbackGroupName: String {
        AppLanguage.currentForLocalization().text("Uncategorized", "未分类")
    }
    static let foregroundRefreshInterval: TimeInterval = 15 * 60
    static let backgroundRefreshRequestInterval: TimeInterval = 60 * 60
    static let foregroundRefreshPollInterval: TimeInterval = 30
    static let foregroundCloudRefreshInterval: TimeInterval = 30
    private static let recurrenceHorizonDays = 180
    private static let builtInGroupSets: [[String]] = AppLanguage.allCases.map { defaultGroups(for: $0) }

    private struct SectionItemsCache {
        let timeBucket: Int
        let sections: [DeadlineSection: [DeadlineItem]]
    }

    @Published var items: [DeadlineItem] = [] {
        didSet {
            invalidateSectionItemsCache()
            if isHydratingPersistence == false, isPerformingBulkMutation == false {
                saveItems()
            }
            if isPerformingBulkMutation == false {
                queueReminderRefresh()
            }
        }
    }
    @Published var subscriptions: [DeadlineSubscription] = [] {
        didSet {
            if isHydratingPersistence == false, isPerformingBulkMutation == false {
                saveSubscriptions()
            }
        }
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
                invalidateSectionItemsCache()
                saveSortOption()
            }
        }
    }
    @Published var selectedFilterGroup: String? = nil {
        didSet {
            if oldValue != selectedFilterGroup {
                invalidateSectionItemsCache()
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
    @Published var syncOptions: DeadlineSyncOptions = .default {
        didSet {
            if oldValue != syncOptions {
                saveSyncOptions()
            }
        }
    }
    @Published var isRefreshingSubscriptions = false
    @Published private(set) var isCloudSyncInProgress = false
    @Published var lastSyncErrorMessage: String?
    @Published var pendingCloudAccountPrompt: DeadlineCloudAccountPrompt?
    @Published private(set) var syncedLanguageSelection: AppLanguage?
    @Published private(set) var lastSubscriptionRefreshAt: Date? {
        didSet { saveLastSubscriptionRefreshAt() }
    }

    private let defaults = DeadlineStorage.sharedDefaults
    private let languageSelectionStorageKey = DeadlineStorage.languageSelectionKey
    private let itemsStorageKey = DeadlineStorage.itemsStorageKey
    private let compactStateStorageKey = DeadlineStorage.compactStateStorageKey
    private let subscriptionsStorageKey = DeadlineStorage.subscriptionsStorageKey
    private let subscriptionLocalStateStorageKey = DeadlineStorage.subscriptionLocalStateStorageKey
    private let syncOptionsStorageKey = DeadlineStorage.syncOptionsStorageKey
    private let cloudAccountFingerprintStorageKey = DeadlineStorage.cloudAccountFingerprintStorageKey
    private let lastSubscriptionRefreshStorageKey = DeadlineStorage.lastSubscriptionRefreshStorageKey
    private let viewStyleStorageKey = DeadlineStorage.viewStyleStorageKey
    private let sortOptionStorageKey = DeadlineStorage.sortOptionStorageKey
    private let selectedFilterGroupStorageKey = DeadlineStorage.selectedFilterGroupStorageKey
    private let groupsStorageKey = DeadlineStorage.groupsStorageKey
    private let backgroundStyleStorageKey = DeadlineStorage.backgroundStyleStorageKey
    private let liquidMotionEnabledStorageKey = DeadlineStorage.liquidMotionEnabledStorageKey
    private var persistence: DeadlinePersistenceController?
    private var persistedState = DeadlinePersistedState()
    private var isHydratingPersistence = false
    private var isRunningSubscriptionRefresh = false
    private var lastForegroundCloudRefreshAt: Date?
    private var persistenceRemoteChangeCancellable: AnyCancellable?
    private var persistenceCloudSyncEventCancellable: AnyCancellable?
    private var reminderRefreshTask: Task<Void, Never>?
    private var persistenceGeneration = 0
    private var isPerformingBulkMutation = false
    private var sectionItemsCache: SectionItemsCache?
    private var activeCloudSyncEventIDs = Set<UUID>()
    private var cloudSyncRequestCount = 0
    private var queuedImmediateCloudReloadTask: Task<Void, Never>?
    private var hasPendingImmediateCloudReload = false

    init() {
        DeadlineStorage.migrateStandardDefaultsIfNeeded()
        loadSyncOptions()
        persistence = DeadlinePersistenceController(syncEnabled: syncOptions.automaticSyncEnabled)
        persistence?.bootstrapIfNeeded(fallbackGroups: Self.defaultGroups(for: .english))
        observePersistenceRemoteChanges()
        observePersistenceCloudSyncEvents()
        loadViewStyle()
        loadSortOption()
        loadSelectedFilterGroup()
        loadBackgroundStyle()
        loadLiquidMotionEnabled()
        loadLastSubscriptionRefreshAt()
        loadSyncedSnapshot(now: .now)
        if syncOptions.syncBackgroundStyle,
           let syncedBackgroundStyle = persistence?.loadSnapshot().syncPreferences.backgroundStyle {
            backgroundStyle = syncedBackgroundStyle
        }
        if let issue = persistence?.loadIssueDescription,
           syncOptions.automaticSyncEnabled {
            lastSyncErrorMessage = issue
        }
        extendRecurringItemsIfNeeded(at: .now)
        validateSelectedFilterGroup()
    }

    var isSyncActivityInProgress: Bool {
        isRefreshingSubscriptions || isCloudSyncInProgress
    }

    func addItem(
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        reminders: [DeadlineReminder] = [],
        repeatRule: DeadlineRepeatRule? = nil
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = normalizedCategoryName(from: category)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false, endDate > startDate else { return }

        if let repeatRule {
            var state = persistedState
            state.recurringSeries.append(
                DeadlineRecurringSeries(
                    seriesID: UUID(),
                    seedItemID: UUID(),
                    title: trimmedTitle,
                    category: normalizedCategory,
                    detail: trimmedDetail,
                    startDate: startDate,
                    endDate: endDate,
                    createdAt: .now,
                    sourceKind: .manual,
                    originalStartDateWasMissing: false,
                    isAllDay: false,
                    repeatRule: repeatRule,
                    reminders: reminders
                )
            )
            applyPersistedState(state, now: startDate)
            return
        }

        var state = persistedState
        state.standaloneItems.append(
            DeadlineItem(
                title: trimmedTitle,
                category: normalizedCategory,
                detail: trimmedDetail,
                startDate: startDate,
                endDate: endDate,
                reminders: reminders
            )
        )
        applyPersistedState(state, now: endDate)
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

    func addSubscription(urlString: String, category: String, reminders: [DeadlineReminder] = []) async throws {
        let normalizedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedURL.isEmpty == false else {
            throw DeadlineSyncError.invalidURL
        }

        let normalizedCategory = normalizedCategoryName(from: category)
        let subscription = DeadlineSubscription(
            urlString: normalizedURL,
            category: normalizedCategory,
            reminders: reminders
        )
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
        guard isRunningSubscriptionRefresh == false else { return }

        if force == false, let lastSubscriptionRefreshAt, now.timeIntervalSince(lastSubscriptionRefreshAt) < Self.foregroundRefreshInterval {
            return
        }

        isRunningSubscriptionRefresh = true
        isRefreshingSubscriptions = true
        lastSyncErrorMessage = nil
        defer {
            isRunningSubscriptionRefresh = false
            isRefreshingSubscriptions = false
        }

        await refreshCloudDataForSubscriptionRefresh(
            now: now,
            reloadPersistence: true,
            forceReload: force,
            trackActivity: force
        )

        let subscriptionIDs = subscriptions.map(\.id)
        guard subscriptionIDs.isEmpty == false else {
            lastSubscriptionRefreshAt = now
            return
        }

        for subscriptionID in subscriptionIDs {
            do {
                _ = try await refreshSubscription(id: subscriptionID, importedAt: now, manageLoadingState: false)
            } catch {
                lastSyncErrorMessage = error.localizedDescription
            }
        }

        await refreshCloudDataForSubscriptionRefresh(
            now: now,
            reloadPersistence: false,
            forceReload: false,
            trackActivity: false
        )
    }

    func refreshSubscriptionsIfNeeded(now: Date = .now) async {
        await refreshSubscriptions(force: false, now: now)
    }

    func refreshCloudDataIfNeeded(now: Date = .now) async {
        guard syncOptions.automaticSyncEnabled else { return }
        if let lastForegroundCloudRefreshAt,
           now.timeIntervalSince(lastForegroundCloudRefreshAt) < Self.foregroundCloudRefreshInterval {
            return
        }

        await refreshCloudDataForSubscriptionRefresh(
            now: now,
            reloadPersistence: true,
            forceReload: false,
            trackActivity: false
        )
    }

    func refreshCloudDataNow(now: Date = .now) async {
        await refreshCloudDataForSubscriptionRefresh(
            now: now,
            reloadPersistence: true,
            forceReload: true,
            trackActivity: true
        )
    }

    func extendRecurringItemsIfNeeded(at now: Date = .now) {
        guard persistedState.standaloneItems.isEmpty == false ||
                persistedState.legacyRecurringItems.isEmpty == false ||
                persistedState.recurringSeries.isEmpty == false else {
            return
        }

        let horizonEnd = Calendar.current.date(byAdding: .day, value: Self.recurrenceHorizonDays, to: now) ?? now
        let compactSeriesIDs = Set(persistedState.recurringSeries.map(\.seriesID))
        var updatedItems = materializedItems(from: persistedState, now: now)
        let legacySeedItems = updatedItems.filter { item in
            item.isRepeatSeed &&
            (item.repeatSeriesID.map { compactSeriesIDs.contains($0) } ?? false) == false
        }

        for seed in legacySeedItems {
            extendRecurringSeries(for: seed, through: horizonEnd, items: &updatedItems)
        }

        if updatedItems != items {
            items = updatedItems
        }
    }

    func updateItem(
        id: UUID,
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        reminders: [DeadlineReminder]
    ) {
        applyUpdateItem(
            id: id,
            title: title,
            category: category,
            detail: detail,
            startDate: startDate,
            endDate: endDate,
            reminders: reminders,
            scope: .thisEvent
        )
    }

    func updateItem(
        baseItem: DeadlineItem,
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        reminders: [DeadlineReminder],
        scope: DeadlineRecurringChangeScope
    ) -> DeadlineEditSaveResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = normalizedCategoryName(from: category)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false, endDate > startDate else { return .saved }
        guard let currentItem = items.first(where: { $0.id == baseItem.id }) else { return .saved }

        let conflictFields = conflictingFields(
            baseItem: baseItem,
            currentItem: currentItem,
            proposedTitle: trimmedTitle,
            proposedCategory: normalizedCategory,
            proposedDetail: trimmedDetail,
            proposedStartDate: startDate,
            proposedEndDate: endDate,
            proposedReminders: reminders
        )

        if conflictFields.isEmpty == false {
            return .conflict(
                DeadlineEditConflict(
                    currentItem: currentItem,
                    proposedTitle: trimmedTitle,
                    proposedCategory: normalizedCategory,
                    proposedDetail: trimmedDetail,
                    proposedStartDate: startDate,
                    proposedEndDate: endDate,
                    proposedReminders: reminders,
                    scope: scope,
                    fields: conflictFields
                )
            )
        }

        applyUpdateItem(
            id: baseItem.id,
            title: trimmedTitle,
            category: normalizedCategory,
            detail: trimmedDetail,
            startDate: startDate,
            endDate: endDate,
            reminders: reminders,
            scope: scope
        )
        return .saved
    }

    private func applyUpdateItem(
        id: UUID,
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        reminders: [DeadlineReminder],
        scope: DeadlineRecurringChangeScope
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = normalizedCategoryName(from: category)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false, endDate > startDate else { return }
        guard let item = items.first(where: { $0.id == id }) else { return }

        if scope == .thisEvent,
           applyRecurringOccurrenceEditIfPossible(
            item: item,
            title: trimmedTitle,
            category: normalizedCategory,
            detail: trimmedDetail,
            startDate: startDate,
            endDate: endDate,
            reminders: reminders
           ) {
            return
        }

        if scope == .futureEvents,
           applyRecurringFutureEditIfPossible(
            item: item,
            title: trimmedTitle,
            category: normalizedCategory,
            detail: trimmedDetail,
            startDate: startDate,
            endDate: endDate,
            reminders: reminders
           ) {
            return
        }

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
            items[index].reminders = reminders
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
            reminders: reminders,
            repeatRule: repeatRule,
            sourceKind: item.sourceKind,
            previousItems: futureItems
        )

        updatedItems.append(contentsOf: rebuiltItems)
        items = updatedItems
    }

    func updateClosedItemDetail(baseItem: DeadlineItem, detail: String) -> DeadlineEditSaveResult {
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let currentItem = items.first(where: { $0.id == baseItem.id }) else { return .saved }

        let conflictFields = conflictingFields(
            baseItem: baseItem,
            currentItem: currentItem,
            proposedTitle: currentItem.title,
            proposedCategory: currentItem.category,
            proposedDetail: trimmedDetail,
            proposedStartDate: currentItem.startDate,
            proposedEndDate: currentItem.endDate,
            proposedReminders: currentItem.reminders
        )

        if conflictFields.isEmpty == false {
            return .conflict(
                DeadlineEditConflict(
                    currentItem: currentItem,
                    proposedTitle: currentItem.title,
                    proposedCategory: currentItem.category,
                    proposedDetail: trimmedDetail,
                    proposedStartDate: currentItem.startDate,
                    proposedEndDate: currentItem.endDate,
                    proposedReminders: currentItem.reminders,
                    scope: .thisEvent,
                    fields: conflictFields
                )
            )
        }

        applyClosedItemDetail(id: baseItem.id, detail: trimmedDetail)
        return .saved
    }

    private func applyClosedItemDetail(id: UUID, detail: String) {
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let item = items.first(where: { $0.id == id }) else { return }

        if applyRecurringOccurrenceEditIfPossible(
            item: item,
            title: item.title,
            category: item.category,
            detail: trimmedDetail,
            startDate: item.startDate,
            endDate: item.endDate,
            reminders: item.reminders
        ) {
            return
        }

        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].detail = trimmedDetail
    }

    func applyLocalConflictResolution(_ conflict: DeadlineEditConflict) -> Bool {
        applyUpdateItem(
            id: conflict.currentItem.id,
            title: conflict.proposedTitle,
            category: conflict.proposedCategory,
            detail: conflict.proposedDetail,
            startDate: conflict.proposedStartDate,
            endDate: conflict.proposedEndDate,
            reminders: conflict.proposedReminders,
            scope: conflict.scope
        )
        return true
    }

    func completeItem(id: UUID, at completedAt: Date = .now) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard items[index].canComplete(at: completedAt) else { return }

        if applyRecurringCompletionIfPossible(
            item: items[index],
            completedAt: completedAt
        ) {
            return
        }

        items[index].completedAt = completedAt
        if items[index].belongsToRepeatSeries {
            extendRecurringItemsIfNeeded(at: completedAt)
        }
    }

    @discardableResult
    func markItemIncomplete(id: UUID, at now: Date = .now) -> DeadlineSection? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }

        if let section = applyRecurringIncompleteIfPossible(item: items[index], now: now) {
            return section
        }

        items[index].completedAt = nil
        return items[index].section(at: now)
    }

    func removeItem(id: UUID) {
        removeItem(id: id, scope: .thisEvent)
    }

    func removeItem(id: UUID, scope: DeadlineRecurringChangeScope) {
        guard let item = items.first(where: { $0.id == id }) else { return }

        if applyRecurringRemovalIfPossible(item: item, scope: scope) {
            return
        }

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

    func updateSubscription(id: UUID, category: String, reminders: [DeadlineReminder]) {
        guard let subscriptionIndex = subscriptions.firstIndex(where: { $0.id == id }) else { return }

        let normalizedCategory = normalizedCategoryName(from: category)
        subscriptions[subscriptionIndex].category = normalizedCategory
        subscriptions[subscriptionIndex].reminders = reminders

        for itemIndex in items.indices where items[itemIndex].subscriptionID == id {
            items[itemIndex].category = normalizedCategory
            items[itemIndex].reminders = reminders
        }
    }

    func refreshReminderNotifications() {
        queueReminderRefresh()
    }

    func items(in section: DeadlineSection, at now: Date) -> [DeadlineItem] {
        let timeBucket = timeBucket(for: now)
        if let sectionItemsCache, sectionItemsCache.timeBucket == timeBucket {
            return sectionItemsCache.sections[section] ?? []
        }

        let cache = buildSectionItemsCache(at: now, timeBucket: timeBucket)
        sectionItemsCache = cache
        return cache.sections[section] ?? []
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
        var grouped: [UUID: DeadlineItem] = [:]

        for item in items {
            guard
                item.belongsToRepeatSeries,
                item.completedAt == nil,
                item.endDate > now,
                let seriesID = item.repeatSeriesID
            else {
                continue
            }

            if let currentVisible = grouped[seriesID] {
                let shouldReplace =
                    item.startDate < currentVisible.startDate ||
                    (item.startDate == currentVisible.startDate &&
                     item.repeatOccurrenceIndex < currentVisible.repeatOccurrenceIndex)
                if shouldReplace {
                    grouped[seriesID] = item
                }
            } else {
                grouped[seriesID] = item
            }
        }

        var visibleIDs = Set<UUID>()

        for item in grouped.values {
            visibleIDs.insert(item.id)
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

    private func invalidateSectionItemsCache() {
        sectionItemsCache = nil
    }

    private func timeBucket(for date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate.rounded(.down))
    }

    private func buildSectionItemsCache(at now: Date, timeBucket: Int) -> SectionItemsCache {
        let visibleRecurringOpenItemIDs = visibleRecurringOpenItemIDs(at: now)
        var sections = Dictionary(uniqueKeysWithValues: DeadlineSection.allCases.map { ($0, [DeadlineItem]()) })

        for item in items {
            let section = item.section(at: now)
            guard shouldDisplay(item, in: section, visibleRecurringOpenItemIDs: visibleRecurringOpenItemIDs, now: now) else {
                continue
            }
            if let selectedFilterGroup, item.category != selectedFilterGroup {
                continue
            }
            sections[section, default: []].append(item)
        }

        for section in DeadlineSection.allCases {
            sortItems(&sections[section, default: []], in: section)
        }

        return SectionItemsCache(
            timeBucket: timeBucket,
            sections: sections
        )
    }

    private func sortItems(_ items: inout [DeadlineItem], in section: DeadlineSection) {
        switch sortOption {
        case .addedDateAscending:
            items.sort { $0.createdAt < $1.createdAt }
        case .addedDateDescending:
            items.sort { $0.createdAt > $1.createdAt }
        case .remainingTimeAscending:
            items.sort { sortReferenceDate(for: $0, in: section) < sortReferenceDate(for: $1, in: section) }
        case .remainingTimeDescending:
            items.sort { sortReferenceDate(for: $0, in: section) > sortReferenceDate(for: $1, in: section) }
        }
    }

    func toggleViewStyle() {
        viewStyle = (viewStyle == .progressBar) ? .grid : .progressBar
    }

    func setViewStyle(_ style: DeadlineViewStyle) {
        viewStyle = style
    }

    func setAutomaticSyncEnabled(_ isEnabled: Bool) {
        var updated = syncOptions
        updated.setAutomaticSyncEnabled(isEnabled)
        syncOptions = updated
        reconfigurePersistence(syncEnabled: isEnabled)
        persistEnabledSyncDomains()
    }

    func setLanguageSyncEnabled(_ isEnabled: Bool) {
        var updated = syncOptions
        updated.setSyncLanguage(isEnabled)
        syncOptions = updated
        if isEnabled {
            saveSyncPreferencesIfNeeded()
        } else {
            syncedLanguageSelection = nil
        }
    }

    func setBackgroundSyncEnabled(_ isEnabled: Bool) {
        var updated = syncOptions
        updated.setSyncBackgroundStyle(isEnabled)
        syncOptions = updated
        if isEnabled {
            saveSyncPreferencesIfNeeded()
        }
    }

    func setGroupsSyncEnabled(_ isEnabled: Bool) {
        var updated = syncOptions
        updated.setSyncGroups(isEnabled)
        syncOptions = updated
        if updated.syncGroups {
            saveGroups()
        }
    }

    func setTasksSyncEnabled(_ isEnabled: Bool) {
        var updated = syncOptions
        updated.setSyncTasks(isEnabled)
        syncOptions = updated
        if updated.syncTasks {
            saveItems()
        }
    }

    func setSubscriptionsSyncEnabled(_ isEnabled: Bool) {
        var updated = syncOptions
        updated.setSyncSubscriptions(isEnabled)
        syncOptions = updated
        if updated.syncSubscriptions {
            saveSubscriptions()
        }
    }

    func handleLocalLanguageSelectionChange(_ language: AppLanguage) {
        guard syncOptions.syncLanguage else { return }
        saveSyncPreferencesIfNeeded(currentLanguage: language)
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
        groups = Self.defaultGroups(for: currentStoredLanguageSelection() ?? .english)
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
        performBulkMutation(
            {
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
            },
            persistItems: true,
            persistSubscriptions: true,
            refreshReminders: true
        )

        saveGroups()
        validateSelectedFilterGroup()
    }

    private func performBulkMutation(
        _ updates: () -> Void,
        persistItems: Bool = false,
        persistSubscriptions: Bool = false,
        refreshReminders: Bool = false
    ) {
        isPerformingBulkMutation = true
        updates()
        isPerformingBulkMutation = false

        guard isHydratingPersistence == false else { return }

        if persistItems {
            saveItems()
        }
        if persistSubscriptions {
            saveSubscriptions()
        }
        if refreshReminders {
            queueReminderRefresh()
        }
    }

    private func makeRecurringItems(
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        reminders: [DeadlineReminder],
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
            repeatRule: repeatRule,
            reminders: reminders
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
        var existingOccurrenceIndexes = Set(existingSeriesItems.map(\.repeatOccurrenceIndex))

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
            if existingOccurrenceIndexes.contains(occurrenceIndex) {
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
                    repeatOccurrenceIndex: occurrenceIndex,
                    reminders: seed.reminders
                )
            )
            existingOccurrenceIndexes.insert(occurrenceIndex)

            nextStartDate = candidateStartDate
        }
    }

    private func mergeSubscriptionDrafts(
        _ drafts: [ICSImportedItemDraft],
        with subscription: DeadlineSubscription,
        importedAt: Date,
        into currentItems: [DeadlineItem]
    ) -> [DeadlineItem] {
        var updatedItems = DeadlineLegacyMigration.normalizeDecodedItems(currentItems)
        let existingIndexes: [String: Int] = updatedItems.enumerated().reduce(into: [:]) { partialResult, entry in
            let index = entry.offset
            let item = entry.element
            guard item.subscriptionID == subscription.id, let externalEventIdentifier = item.externalEventIdentifier else {
                return
            }
            partialResult[externalEventIdentifier] = index
        }

        let seenIdentifiers = Set(drafts.map(\.externalIdentifier))
        var usedExistingIndexes = Set<Int>()
        var obsoleteDuplicateItemIDs = Set<UUID>()

        for draft in drafts {
            let directExistingIndex = existingIndexes[draft.externalIdentifier].flatMap { index in
                usedExistingIndexes.contains(index) ? nil : index
            }
            let localExistingIndex = matchingSubscriptionItemIndex(
                for: draft,
                subscription: subscription,
                in: updatedItems,
                excluding: usedExistingIndexes
            )
            let existingIndex = preferredSubscriptionMatchIndex(
                directExistingIndex,
                localExistingIndex,
                in: updatedItems
            )

            if let existingIndex {
                for duplicateIndex in [directExistingIndex, localExistingIndex].compactMap({ $0 })
                    where duplicateIndex != existingIndex {
                    obsoleteDuplicateItemIDs.insert(updatedItems[duplicateIndex].id)
                }
                usedExistingIndexes.insert(existingIndex)
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
                updatedItems[existingIndex].reminders = subscription.reminders
                if draft.originalStartDateWasMissing {
                    if existingItem.startDate < draft.endDate {
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
                        reminders: subscription.reminders,
                        createdAt: importedAt
                    )
                )
            }
        }

        updatedItems.removeAll { item in
            if obsoleteDuplicateItemIDs.contains(item.id) {
                return true
            }
            guard item.subscriptionID == subscription.id else { return false }
            guard let externalEventIdentifier = item.externalEventIdentifier else { return false }
            return seenIdentifiers.contains(externalEventIdentifier) == false
        }

        return DeadlineLegacyMigration.normalizeDecodedItems(updatedItems)
    }

    private func preferredSubscriptionMatchIndex(
        _ lhs: Int?,
        _ rhs: Int?,
        in items: [DeadlineItem]
    ) -> Int? {
        switch (lhs, rhs) {
        case (nil, nil):
            return nil
        case (let index?, nil), (nil, let index?):
            return index
        case (let lhs?, let rhs?):
            let lhsItem = items[lhs]
            let rhsItem = items[rhs]

            if lhsItem.completedAt != nil, rhsItem.completedAt == nil {
                return lhs
            }
            if rhsItem.completedAt != nil, lhsItem.completedAt == nil {
                return rhs
            }
            if lhsItem.startDate != rhsItem.startDate {
                return lhsItem.startDate < rhsItem.startDate ? lhs : rhs
            }
            if lhsItem.createdAt != rhsItem.createdAt {
                return lhsItem.createdAt < rhsItem.createdAt ? lhs : rhs
            }
            return lhs
        }
    }

    private func matchingSubscriptionItemIndex(
        for draft: ICSImportedItemDraft,
        subscription: DeadlineSubscription,
        in items: [DeadlineItem],
        excluding usedIndexes: Set<Int>
    ) -> Int? {
        let sourceCandidates = items.indices.filter { index in
            guard usedIndexes.contains(index) == false else { return false }
            let item = items[index]
            guard
                item.subscriptionID == subscription.id,
                item.sourceKind == .subscribedURL,
                item.externalEventIdentifier != draft.externalIdentifier
            else {
                return false
            }
            return true
        }

        if let uidMatchIndex = matchingSubscriptionUIDItemIndex(
            for: draft,
            in: items,
            candidates: sourceCandidates
        ) {
            return uidMatchIndex
        }

        return matchingSubscriptionSignatureItemIndex(
            for: draft,
            subscription: subscription,
            in: items,
            candidates: sourceCandidates
        )
    }

    private func matchingSubscriptionUIDItemIndex(
        for draft: ICSImportedItemDraft,
        in items: [DeadlineItem],
        candidates: [Int]
    ) -> Int? {
        guard let draftUID = subscriptionEventUID(from: draft.externalIdentifier) else { return nil }
        let uidCandidates = candidates.filter { index in
            guard let existingIdentifier = items[index].externalEventIdentifier else { return false }

            return subscriptionEventUID(from: existingIdentifier) == draftUID
        }

        if draft.originalStartDateWasMissing,
           let matchingEndDateIndex = uidCandidates.first(where: { subscriptionDatesMatch(items[$0].endDate, draft.endDate) }) {
            return matchingEndDateIndex
        }

        if let matchingDatesIndex = uidCandidates.first(where: {
            subscriptionDatesMatch(items[$0].startDate, draft.startDate) &&
            subscriptionDatesMatch(items[$0].endDate, draft.endDate)
        }) {
            return matchingDatesIndex
        }

        if uidCandidates.count == 1 {
            return uidCandidates[0]
        }

        return nil
    }

    private func matchingSubscriptionSignatureItemIndex(
        for draft: ICSImportedItemDraft,
        subscription: DeadlineSubscription,
        in items: [DeadlineItem],
        candidates: [Int]
    ) -> Int? {
        let matchingSignatureCandidates = candidates.filter { index in
            let item = items[index]
            return subscriptionTextMatches(item.title, draft.title) &&
                subscriptionTextMatches(item.category, subscription.category) &&
                subscriptionTextMatches(item.detail, draft.detail) &&
                subscriptionDatesMatch(item.endDate, draft.endDate)
        }

        if matchingSignatureCandidates.count <= 1 {
            return matchingSignatureCandidates.first
        }

        if let exactStartDateIndex = matchingSignatureCandidates.first(where: {
            subscriptionDatesMatch(items[$0].startDate, draft.startDate)
        }) {
            return exactStartDateIndex
        }

        if draft.originalStartDateWasMissing,
           let earliestCreatedIndex = matchingSignatureCandidates.min(by: {
               items[$0].createdAt < items[$1].createdAt
           }) {
            return earliestCreatedIndex
        }

        return nil
    }

    private func subscriptionTextMatches(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines) ==
            rhs.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func subscriptionEventUID(from externalIdentifier: String) -> String? {
        let identifier = externalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separatorIndex = identifier.lastIndex(of: "#") else {
            return identifier.isEmpty ? nil : identifier
        }

        let suffixStartIndex = identifier.index(after: separatorIndex)
        let suffix = String(identifier[suffixStartIndex...])
        let rawUID = isSubscriptionOccurrenceIdentifierSuffix(suffix)
            ? String(identifier[..<separatorIndex])
            : identifier
        let uid = rawUID.trimmingCharacters(in: .whitespacesAndNewlines)
        return uid.isEmpty ? nil : uid
    }

    private func isSubscriptionOccurrenceIdentifierSuffix(_ suffix: String) -> Bool {
        if suffix.hasPrefix("occurrence-") {
            return Int(suffix.dropFirst("occurrence-".count)) != nil
        }

        return Self.subscriptionIdentifierDateFormatter.date(from: suffix) != nil
    }

    private func subscriptionDatesMatch(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 1
    }

    private static let subscriptionIdentifierDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func makeImportedItem(
        from draft: ICSImportedItemDraft,
        category: String,
        sourceKind: DeadlineItemSourceKind,
        subscriptionID: UUID?,
        reminders: [DeadlineReminder] = [],
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
            isAllDay: draft.isAllDay,
            reminders: reminders
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
        reminders: [DeadlineReminder],
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
            reminders: reminders,
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
        loadSyncedSnapshot(now: .now)
    }

    private func saveItems() {
        let normalizedItems = DeadlineLegacyMigration.normalizeDecodedItems(items)
        let migration = DeadlineLegacyMigration.migrateLegacyItems(normalizedItems)
        persistedState = migration.state

        if syncOptions.syncTasks {
            persistence?.savePersistedState(migration.state)
            queueImmediateCloudReloadIfNeeded()
        }

        if let compactData = try? JSONEncoder().encode(migration.state) {
            defaults.set(compactData, forKey: compactStateStorageKey)
        }

        guard let data = try? JSONEncoder().encode(normalizedItems) else { return }
        defaults.set(data, forKey: itemsStorageKey)
        DeadlineStorage.reloadWidgets()
    }

    private func materializedItems(from state: DeadlinePersistedState, now: Date) -> [DeadlineItem] {
        var result = state.standaloneItems
        result.append(contentsOf: state.legacyRecurringItems)

        let calendar = Calendar.current
        let overridesBySeries = Dictionary(grouping: state.recurringOverrides, by: \.seriesID)

        for series in state.recurringSeries {
            let occurrenceOverrides = Dictionary(
                uniqueKeysWithValues: (overridesBySeries[series.seriesID] ?? []).map { ($0.occurrenceIndex, $0) }
            )

            let futureHorizon = calendar.date(byAdding: .day, value: Self.recurrenceHorizonDays, to: now) ?? now
            let seedHorizon = calendar.date(byAdding: .day, value: Self.recurrenceHorizonDays, to: series.startDate) ?? series.endDate
            let seriesHorizon = max(futureHorizon, seedHorizon)

            var occurrenceIndex = 0
            var nextStartDate = series.startDate

            while occurrenceIndex < 1024 {
                let baseEndDate = nextStartDate.addingTimeInterval(series.endDate.timeIntervalSince(series.startDate))

                if occurrenceIndex > 0 {
                    if nextStartDate > seriesHorizon {
                        break
                    }
                    if let repeatEndDate = series.repeatRule.endDate, nextStartDate > repeatEndDate {
                        break
                    }
                }

                let override = occurrenceOverrides[occurrenceIndex]
                if override?.isDeleted != true {
                    result.append(
                        materializedRecurringItem(
                            for: series,
                            occurrenceIndex: occurrenceIndex,
                            baseStartDate: nextStartDate,
                            baseEndDate: baseEndDate,
                            occurrenceOverride: override
                        )
                    )
                }

                occurrenceIndex += 1
                guard let candidateStartDate = series.repeatRule.nextDate(after: nextStartDate) else { break }
                nextStartDate = candidateStartDate
            }
        }

        return DeadlineLegacyMigration.normalizeDecodedItems(result)
    }

    private func materializedRecurringItem(
        for series: DeadlineRecurringSeries,
        occurrenceIndex: Int,
        baseStartDate: Date,
        baseEndDate: Date,
        occurrenceOverride: DeadlineRecurringOverride?
    ) -> DeadlineItem {
        DeadlineItem(
            id: resolvedRecurringItemID(
                for: series,
                occurrenceIndex: occurrenceIndex,
                occurrenceOverride: occurrenceOverride
            ),
            title: occurrenceOverride?.title ?? series.title,
            category: occurrenceOverride?.category ?? series.category,
            detail: occurrenceOverride?.detail ?? series.detail,
            startDate: occurrenceOverride?.startDate ?? baseStartDate,
            endDate: occurrenceOverride?.endDate ?? baseEndDate,
            completedAt: occurrenceOverride?.completedAt,
            createdAt: series.createdAt,
            sourceKind: series.sourceKind,
            subscriptionID: series.subscriptionID,
            externalEventIdentifier: series.externalEventIdentifier,
            originalStartDateWasMissing: series.originalStartDateWasMissing,
            isAllDay: occurrenceOverride?.isAllDay ?? series.isAllDay,
            repeatSeriesID: series.seriesID,
            repeatOccurrenceIndex: occurrenceIndex,
            repeatRule: occurrenceIndex == 0 ? series.repeatRule : nil,
            reminders: occurrenceOverride?.reminders ?? series.reminders
        )
    }

    private func resolvedRecurringItemID(
        for series: DeadlineRecurringSeries,
        occurrenceIndex: Int,
        occurrenceOverride: DeadlineRecurringOverride?
    ) -> UUID {
        if let itemID = occurrenceOverride?.itemID {
            return itemID
        }
        if occurrenceIndex == 0 {
            return series.seedItemID
        }
        return DeadlineRecurringIdentity.itemID(seriesID: series.seriesID, occurrenceIndex: occurrenceIndex)
    }

    private func applyPersistedState(_ state: DeadlinePersistedState, now: Date = .now) {
        persistedState = state
        items = materializedItems(from: state, now: now)
    }

    private func applyRecurringOccurrenceEditIfPossible(
        item: DeadlineItem,
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        reminders: [DeadlineReminder]
    ) -> Bool {
        guard
            let seriesID = item.repeatSeriesID,
            let seriesIndex = persistedState.recurringSeries.firstIndex(where: { $0.seriesID == seriesID })
        else {
            return false
        }

        var state = persistedState
        let series = state.recurringSeries[seriesIndex]
        let baseDates = recurringBaseDates(for: series, occurrenceIndex: item.repeatOccurrenceIndex)

        var override = recurringOverride(
            in: state,
            seriesID: seriesID,
            occurrenceIndex: item.repeatOccurrenceIndex
        ) ?? DeadlineRecurringOverride(
            seriesID: seriesID,
            occurrenceIndex: item.repeatOccurrenceIndex
        )

        override.title = title == series.title ? nil : title
        override.category = category == series.category ? nil : category
        override.detail = detail == series.detail ? nil : detail
        override.startDate = startDate == baseDates.startDate ? nil : startDate
        override.endDate = endDate == baseDates.endDate ? nil : endDate
        override.completedAt = item.completedAt
        override.isAllDay = item.isAllDay == series.isAllDay ? nil : item.isAllDay
        override.reminders = reminders == series.reminders ? nil : reminders
        override.isDeleted = false

        if override.isEmpty {
            removeRecurringOverride(
                from: &state,
                seriesID: seriesID,
                occurrenceIndex: item.repeatOccurrenceIndex
            )
        } else {
            override.itemID = recurringItemIDOverride(for: item)
            upsertRecurringOverride(&state, override: override)
        }

        applyPersistedState(state)
        return true
    }

    private func applyRecurringFutureEditIfPossible(
        item: DeadlineItem,
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        reminders: [DeadlineReminder]
    ) -> Bool {
        guard
            let seriesID = item.repeatSeriesID,
            let seriesIndex = persistedState.recurringSeries.firstIndex(where: { $0.seriesID == seriesID })
        else {
            return false
        }

        let originalState = persistedState
        var state = persistedState
        let originalSeries = state.recurringSeries[seriesIndex]

        if item.repeatOccurrenceIndex == 0 {
            state.recurringSeries[seriesIndex].title = title
            state.recurringSeries[seriesIndex].category = category
            state.recurringSeries[seriesIndex].detail = detail
            state.recurringSeries[seriesIndex].startDate = startDate
            state.recurringSeries[seriesIndex].endDate = endDate
            state.recurringSeries[seriesIndex].reminders = reminders

            if var seedOverride = recurringOverride(in: state, seriesID: seriesID, occurrenceIndex: 0) {
                seedOverride.itemID = recurringItemIDOverride(for: item)
                seedOverride.title = nil
                seedOverride.category = nil
                seedOverride.detail = nil
                seedOverride.startDate = nil
                seedOverride.endDate = nil
                seedOverride.reminders = nil
                seedOverride.isDeleted = false

                if seedOverride.isEmpty {
                    removeRecurringOverride(from: &state, seriesID: seriesID, occurrenceIndex: 0)
                } else {
                    upsertRecurringOverride(&state, override: seedOverride)
                }
            }

            applyPersistedState(state, now: startDate)
            return true
        }

        guard
            let previousStartDate = recurringStartDate(
                for: originalSeries,
                occurrenceIndex: item.repeatOccurrenceIndex - 1,
                in: originalState
            )
        else {
            return false
        }

        let newSeries = DeadlineRecurringSeries(
            seriesID: UUID(),
            seedItemID: item.id,
            title: title,
            category: category,
            detail: detail,
            startDate: startDate,
            endDate: endDate,
            createdAt: item.createdAt,
            sourceKind: originalSeries.sourceKind,
            subscriptionID: originalSeries.subscriptionID,
            externalEventIdentifier: originalSeries.externalEventIdentifier,
            originalStartDateWasMissing: originalSeries.originalStartDateWasMissing,
            isAllDay: item.isAllDay,
            repeatRule: originalSeries.repeatRule,
            reminders: reminders
        )

        let futureOverrides = originalState.recurringOverrides
            .filter { $0.seriesID == seriesID && $0.occurrenceIndex >= item.repeatOccurrenceIndex }
            .sorted { $0.occurrenceIndex < $1.occurrenceIndex }

        state.recurringSeries[seriesIndex].repeatRule.endDate = previousStartDate
        state.recurringOverrides.removeAll {
            $0.seriesID == seriesID && $0.occurrenceIndex >= item.repeatOccurrenceIndex
        }
        state.recurringSeries.append(newSeries)

        var translatedState = state
        for sourceOverride in futureOverrides {
            let translatedIndex = sourceOverride.occurrenceIndex - item.repeatOccurrenceIndex
            guard let translatedOverride = translatedRecurringOverride(
                sourceOverride,
                from: originalSeries,
                oldOccurrenceIndex: sourceOverride.occurrenceIndex,
                to: newSeries,
                newOccurrenceIndex: translatedIndex,
                originalState: originalState,
                translatedState: translatedState
            ) else {
                continue
            }

            upsertRecurringOverride(&state, override: translatedOverride)
            upsertRecurringOverride(&translatedState, override: translatedOverride)
        }

        applyPersistedState(state, now: startDate)
        return true
    }

    private func applyRecurringCompletionIfPossible(
        item: DeadlineItem,
        completedAt: Date
    ) -> Bool {
        guard
            let seriesID = item.repeatSeriesID,
            persistedState.recurringSeries.contains(where: { $0.seriesID == seriesID })
        else {
            return false
        }

        var state = persistedState
        var override = recurringOverride(
            in: state,
            seriesID: seriesID,
            occurrenceIndex: item.repeatOccurrenceIndex
        ) ?? DeadlineRecurringOverride(
            seriesID: seriesID,
            occurrenceIndex: item.repeatOccurrenceIndex
        )

        override.itemID = recurringItemIDOverride(for: item)
        override.completedAt = completedAt
        override.isDeleted = false
        upsertRecurringOverride(&state, override: override)
        applyPersistedState(state, now: completedAt)
        return true
    }

    private func applyRecurringIncompleteIfPossible(
        item: DeadlineItem,
        now: Date
    ) -> DeadlineSection? {
        guard
            let seriesID = item.repeatSeriesID,
            persistedState.recurringSeries.contains(where: { $0.seriesID == seriesID })
        else {
            return nil
        }

        var state = persistedState
        if var override = recurringOverride(
            in: state,
            seriesID: seriesID,
            occurrenceIndex: item.repeatOccurrenceIndex
        ) {
            override.completedAt = nil
            if override.isEmpty {
                removeRecurringOverride(
                    from: &state,
                    seriesID: seriesID,
                    occurrenceIndex: item.repeatOccurrenceIndex
                )
            } else {
                upsertRecurringOverride(&state, override: override)
            }
        }

        applyPersistedState(state, now: now)
        return items.first(where: { $0.id == item.id })?.section(at: now)
    }

    private func applyRecurringRemovalIfPossible(
        item: DeadlineItem,
        scope: DeadlineRecurringChangeScope
    ) -> Bool {
        guard
            let seriesID = item.repeatSeriesID,
            let seriesIndex = persistedState.recurringSeries.firstIndex(where: { $0.seriesID == seriesID })
        else {
            return false
        }

        var state = persistedState

        switch scope {
        case .thisEvent:
            var override = recurringOverride(
                in: state,
                seriesID: seriesID,
                occurrenceIndex: item.repeatOccurrenceIndex
            ) ?? DeadlineRecurringOverride(
                seriesID: seriesID,
                occurrenceIndex: item.repeatOccurrenceIndex
            )
            override.itemID = recurringItemIDOverride(for: item)
            override.title = nil
            override.category = nil
            override.detail = nil
            override.startDate = nil
            override.endDate = nil
            override.completedAt = nil
            override.isAllDay = nil
            override.isDeleted = true
            upsertRecurringOverride(&state, override: override)
            applyPersistedState(state)
            return true
        case .futureEvents:
            if item.repeatOccurrenceIndex == 0 {
                state.recurringSeries.remove(at: seriesIndex)
                state.recurringOverrides.removeAll { $0.seriesID == seriesID }
                applyPersistedState(state)
                return true
            }

            guard
                let previousStartDate = recurringStartDate(
                    for: state.recurringSeries[seriesIndex],
                    occurrenceIndex: item.repeatOccurrenceIndex - 1,
                    in: state
                )
            else {
                return false
            }

            state.recurringSeries[seriesIndex].repeatRule.endDate = previousStartDate
            state.recurringOverrides.removeAll {
                $0.seriesID == seriesID && $0.occurrenceIndex >= item.repeatOccurrenceIndex
            }
            applyPersistedState(state)
            return true
        }
    }

    private func recurringOverride(
        in state: DeadlinePersistedState,
        seriesID: UUID,
        occurrenceIndex: Int
    ) -> DeadlineRecurringOverride? {
        state.recurringOverrides.first {
            $0.seriesID == seriesID && $0.occurrenceIndex == occurrenceIndex
        }
    }

    private func recurringBaseDates(
        for series: DeadlineRecurringSeries,
        occurrenceIndex: Int
    ) -> (startDate: Date, endDate: Date) {
        recurringBaseDates(for: series, occurrenceIndex: occurrenceIndex, in: persistedState)
    }

    private func recurringBaseDates(
        for series: DeadlineRecurringSeries,
        occurrenceIndex: Int,
        in state: DeadlinePersistedState
    ) -> (startDate: Date, endDate: Date) {
        let startDate = recurringStartDate(for: series, occurrenceIndex: occurrenceIndex, in: state) ?? series.startDate
        return (
            startDate: startDate,
            endDate: startDate.addingTimeInterval(series.endDate.timeIntervalSince(series.startDate))
        )
    }

    private func recurringItemIDOverride(for item: DeadlineItem) -> UUID? {
        item.repeatOccurrenceIndex == 0 ? nil : item.id
    }

    private func translatedRecurringOverride(
        _ sourceOverride: DeadlineRecurringOverride,
        from originalSeries: DeadlineRecurringSeries,
        oldOccurrenceIndex: Int,
        to translatedSeries: DeadlineRecurringSeries,
        newOccurrenceIndex: Int,
        originalState: DeadlinePersistedState,
        translatedState: DeadlinePersistedState
    ) -> DeadlineRecurringOverride? {
        let translatedItemID = newOccurrenceIndex == 0 ? nil : sourceOverride.itemID

        if sourceOverride.isDeleted {
            var deletedOverride = DeadlineRecurringOverride(
                seriesID: translatedSeries.seriesID,
                occurrenceIndex: newOccurrenceIndex
            )
            deletedOverride.itemID = translatedItemID
            deletedOverride.isDeleted = true
            return deletedOverride
        }

        let originalBaseDates = recurringBaseDates(
            for: originalSeries,
            occurrenceIndex: oldOccurrenceIndex,
            in: originalState
        )
        let originalItem = materializedRecurringItem(
            for: originalSeries,
            occurrenceIndex: oldOccurrenceIndex,
            baseStartDate: originalBaseDates.startDate,
            baseEndDate: originalBaseDates.endDate,
            occurrenceOverride: sourceOverride
        )

        let translatedBaseDates = recurringBaseDates(
            for: translatedSeries,
            occurrenceIndex: newOccurrenceIndex,
            in: translatedState
        )
        let translatedBaseItem = materializedRecurringItem(
            for: translatedSeries,
            occurrenceIndex: newOccurrenceIndex,
            baseStartDate: translatedBaseDates.startDate,
            baseEndDate: translatedBaseDates.endDate,
            occurrenceOverride: nil
        )

        return recurringOverride(
            matching: originalItem,
            against: translatedBaseItem,
            seriesID: translatedSeries.seriesID,
            occurrenceIndex: newOccurrenceIndex,
            itemID: translatedItemID
        )
    }

    private func recurringOverride(
        matching actualItem: DeadlineItem,
        against expectedItem: DeadlineItem,
        seriesID: UUID,
        occurrenceIndex: Int,
        itemID: UUID?
    ) -> DeadlineRecurringOverride? {
        var override = DeadlineRecurringOverride(
            seriesID: seriesID,
            occurrenceIndex: occurrenceIndex
        )

        override.itemID = itemID
        override.title = actualItem.title == expectedItem.title ? nil : actualItem.title
        override.category = actualItem.category == expectedItem.category ? nil : actualItem.category
        override.detail = actualItem.detail == expectedItem.detail ? nil : actualItem.detail
        override.startDate = actualItem.startDate == expectedItem.startDate ? nil : actualItem.startDate
        override.endDate = actualItem.endDate == expectedItem.endDate ? nil : actualItem.endDate
        override.completedAt = actualItem.completedAt == expectedItem.completedAt ? nil : actualItem.completedAt
        override.isAllDay = actualItem.isAllDay == expectedItem.isAllDay ? nil : actualItem.isAllDay
        override.reminders = actualItem.reminders == expectedItem.reminders ? nil : actualItem.reminders

        return override.isEmpty ? nil : override
    }

    private func recurringStartDate(
        for series: DeadlineRecurringSeries,
        occurrenceIndex: Int,
        in state: DeadlinePersistedState
    ) -> Date? {
        guard occurrenceIndex >= 0 else { return nil }
        if occurrenceIndex == 0 {
            return state.recurringOverrides.first {
                $0.seriesID == series.seriesID && $0.occurrenceIndex == 0
            }?.startDate ?? series.startDate
        }

        var nextDate = series.startDate
        for index in 1...occurrenceIndex {
            guard let candidateDate = series.repeatRule.nextDate(after: nextDate) else { return nil }
            nextDate = candidateDate
            if let overrideStartDate = state.recurringOverrides.first(where: {
                $0.seriesID == series.seriesID && $0.occurrenceIndex == index
            })?.startDate {
                nextDate = overrideStartDate
            }
        }
        return nextDate
    }

    private func upsertRecurringOverride(
        _ state: inout DeadlinePersistedState,
        override: DeadlineRecurringOverride
    ) {
        if let existingIndex = state.recurringOverrides.firstIndex(where: {
            $0.seriesID == override.seriesID && $0.occurrenceIndex == override.occurrenceIndex
        }) {
            state.recurringOverrides[existingIndex] = override
        } else {
            state.recurringOverrides.append(override)
        }
    }

    private func removeRecurringOverride(
        from state: inout DeadlinePersistedState,
        seriesID: UUID,
        occurrenceIndex: Int
    ) {
        state.recurringOverrides.removeAll {
            $0.seriesID == seriesID && $0.occurrenceIndex == occurrenceIndex
        }
    }

    private func conflictingFields(
        baseItem: DeadlineItem,
        currentItem: DeadlineItem,
        proposedTitle: String,
        proposedCategory: String,
        proposedDetail: String,
        proposedStartDate: Date,
        proposedEndDate: Date,
        proposedReminders: [DeadlineReminder]
    ) -> [DeadlineEditConflictField] {
        var fields: [DeadlineEditConflictField] = []

        appendConflictField(
            to: &fields,
            field: .title,
            baseValue: baseItem.title,
            currentValue: currentItem.title,
            proposedValue: proposedTitle
        )
        appendConflictField(
            to: &fields,
            field: .category,
            baseValue: baseItem.category,
            currentValue: currentItem.category,
            proposedValue: proposedCategory
        )
        appendConflictField(
            to: &fields,
            field: .detail,
            baseValue: baseItem.detail,
            currentValue: currentItem.detail,
            proposedValue: proposedDetail
        )
        appendConflictField(
            to: &fields,
            field: .startDate,
            baseValue: baseItem.startDate,
            currentValue: currentItem.startDate,
            proposedValue: proposedStartDate
        )
        appendConflictField(
            to: &fields,
            field: .endDate,
            baseValue: baseItem.endDate,
            currentValue: currentItem.endDate,
            proposedValue: proposedEndDate
        )
        appendConflictField(
            to: &fields,
            field: .reminders,
            baseValue: baseItem.reminders,
            currentValue: currentItem.reminders,
            proposedValue: proposedReminders
        )

        return fields
    }

    private func appendConflictField<Value: Equatable>(
        to fields: inout [DeadlineEditConflictField],
        field: DeadlineEditConflictField,
        baseValue: Value,
        currentValue: Value,
        proposedValue: Value
    ) {
        guard proposedValue != baseValue else { return }
        guard currentValue != baseValue else { return }
        guard proposedValue != currentValue else { return }
        fields.append(field)
    }

    private func queueReminderRefresh() {
        let itemSnapshot = items
        let language = currentStoredLanguageSelection() ?? .english

        reminderRefreshTask?.cancel()
        reminderRefreshTask = Task {
            await DeadlineReminderScheduler.shared.refreshNotifications(
                for: itemSnapshot,
                language: language
            )
        }
    }

    private func loadSubscriptions() {
        loadSyncedSnapshot(now: .now)
    }

    private func saveSubscriptions() {
        let definitions = subscriptionDefinitions(from: subscriptions)
        if syncOptions.syncSubscriptions {
            persistence?.saveSubscriptions(definitions)
            queueImmediateCloudReloadIfNeeded()
        }
        if let data = try? JSONEncoder().encode(definitions) {
            defaults.set(data, forKey: subscriptionsStorageKey)
        }

        let localStates = Dictionary(uniqueKeysWithValues: subscriptions.map { subscription in
            (
                subscription.id.uuidString,
                DeadlineSubscriptionLocalState(
                    lastSyncedAt: subscription.lastSyncedAt,
                    lastAttemptedAt: subscription.lastAttemptedAt,
                    lastErrorMessage: subscription.lastErrorMessage
                )
            )
        })

        if let data = try? JSONEncoder().encode(localStates) {
            defaults.set(data, forKey: subscriptionLocalStateStorageKey)
        }
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

    private func loadSyncOptions() {
        guard
            let data = defaults.data(forKey: syncOptionsStorageKey),
            let decoded = try? JSONDecoder().decode(DeadlineSyncOptions.self, from: data)
        else {
            syncOptions = .default
            return
        }
        syncOptions = decoded
    }

    private func saveSyncOptions() {
        guard let data = try? JSONEncoder().encode(syncOptions) else { return }
        defaults.set(data, forKey: syncOptionsStorageKey)
    }

    private func loadGroups() {
        loadSyncedSnapshot(now: .now)
    }

    private func saveGroups() {
        if syncOptions.syncGroups {
            persistence?.saveGroups(groups)
            queueImmediateCloudReloadIfNeeded()
        }
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
        saveSyncPreferencesIfNeeded()
    }

    private func loadLiquidMotionEnabled() {
        guard MotionRuntimeSupport.isSupported else {
            liquidMotionEnabled = false
            return
        }

        if defaults.object(forKey: liquidMotionEnabledStorageKey) == nil {
            liquidMotionEnabled = true
            return
        }
        liquidMotionEnabled = defaults.bool(forKey: liquidMotionEnabledStorageKey)
    }

    private func saveLiquidMotionEnabled() {
        defaults.set(liquidMotionEnabled, forKey: liquidMotionEnabledStorageKey)
    }

    private func observePersistenceRemoteChanges() {
        persistenceRemoteChangeCancellable = NotificationCenter.default
            .publisher(for: DeadlinePersistenceController.remoteChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.loadSyncedSnapshot(now: .now)
            }
    }

    private func observePersistenceCloudSyncEvents() {
        persistenceCloudSyncEventCancellable = NotificationCenter.default
            .publisher(for: DeadlinePersistenceController.cloudSyncEventNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard
                    let self,
                    let event = notification.object as? DeadlineCloudSyncEvent
                else {
                    return
                }

                self.handleCloudSyncEvent(event)
            }
    }

    private func reconfigurePersistence(syncEnabled: Bool) {
        persistenceGeneration += 1
        persistenceRemoteChangeCancellable = nil
        persistenceCloudSyncEventCancellable = nil
        clearCloudSyncEventState()
        persistence = DeadlinePersistenceController(syncEnabled: syncEnabled)
        persistence?.bootstrapIfNeeded(
            fallbackGroups: Self.defaultGroups(for: currentStoredLanguageSelection() ?? .english)
        )
        observePersistenceRemoteChanges()
        observePersistenceCloudSyncEvents()
        loadSyncedSnapshot(now: .now)
        lastSyncErrorMessage = nil
        if let issue = persistence?.loadIssueDescription,
           syncEnabled {
            lastSyncErrorMessage = issue
        }
    }

    private func refreshCloudDataForSubscriptionRefresh(
        now: Date,
        reloadPersistence: Bool,
        forceReload: Bool,
        trackActivity: Bool
    ) async {
        guard syncOptions.automaticSyncEnabled else { return }

        if trackActivity {
            beginCloudSyncRequest()
        }
        defer {
            if trackActivity {
                endCloudSyncRequest()
            }
        }

        await refreshCloudAccountStatusIfNeeded()
        guard syncOptions.automaticSyncEnabled else { return }

        let shouldReloadPersistence = reloadPersistence && (
            forceReload ||
            lastForegroundCloudRefreshAt.map { now.timeIntervalSince($0) >= 5 } ?? true
        )

        if shouldReloadPersistence {
            reconfigurePersistence(syncEnabled: true)
            lastForegroundCloudRefreshAt = now
        } else {
            loadSyncedSnapshot(now: now)
        }

        if let issue = persistence?.loadIssueDescription {
            lastSyncErrorMessage = issue
        }
    }

    private func beginCloudSyncRequest() {
        cloudSyncRequestCount += 1
        updateCloudSyncActivityState()
    }

    private func endCloudSyncRequest() {
        cloudSyncRequestCount = max(cloudSyncRequestCount - 1, 0)
        updateCloudSyncActivityState()
    }

    private func resetCloudSyncActivity() {
        queuedImmediateCloudReloadTask?.cancel()
        queuedImmediateCloudReloadTask = nil
        hasPendingImmediateCloudReload = false
        clearCloudSyncEventState()
        cloudSyncRequestCount = 0
        updateCloudSyncActivityState()
    }

    private func clearCloudSyncEventState() {
        activeCloudSyncEventIDs.removeAll()
        updateCloudSyncActivityState()
    }

    private func updateCloudSyncActivityState() {
        isCloudSyncInProgress = cloudSyncRequestCount > 0 || activeCloudSyncEventIDs.isEmpty == false
    }

    private func handleCloudSyncEvent(_ event: DeadlineCloudSyncEvent) {
        if event.isFinished {
            activeCloudSyncEventIDs.remove(event.identifier)
            if let errorDescription = event.errorDescription, errorDescription.isEmpty == false {
                lastSyncErrorMessage = errorDescription
            }
        } else {
            activeCloudSyncEventIDs.insert(event.identifier)
        }

        updateCloudSyncActivityState()
        attemptQueuedImmediateCloudReload()
    }

    private func queueImmediateCloudReloadIfNeeded() {
        guard syncOptions.automaticSyncEnabled else { return }

        hasPendingImmediateCloudReload = true
        queuedImmediateCloudReloadTask?.cancel()
        queuedImmediateCloudReloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run {
                self?.attemptQueuedImmediateCloudReload()
            }
        }
    }

    private func attemptQueuedImmediateCloudReload() {
        guard hasPendingImmediateCloudReload else { return }
        guard syncOptions.automaticSyncEnabled else {
            hasPendingImmediateCloudReload = false
            return
        }
        guard activeCloudSyncEventIDs.isEmpty else { return }

        hasPendingImmediateCloudReload = false
        queuedImmediateCloudReloadTask?.cancel()
        queuedImmediateCloudReloadTask = nil

        Task { [weak self] in
            guard let self else { return }
            await self.refreshCloudDataNow(now: .now)
        }
    }

    private func loadSyncedSnapshot(now: Date) {
        let snapshot = persistence?.loadSnapshot() ?? DeadlinePersistenceSnapshot(
            state: DeadlinePersistedState(),
            groups: [],
            subscriptions: [],
            syncPreferences: DeadlineSyncPreferenceSnapshot()
        )
        let fallbackGroups = Self.defaultGroups(for: currentStoredLanguageSelection() ?? .english)

        let baseState = syncOptions.syncTasks ? snapshot.state : localPersistedStateFromDefaults()
        let resolvedGroups = syncOptions.syncGroups
            ? normalizedGroups(
                snapshot.groups.isEmpty
                ? localGroupsFromDefaults(fallbackGroups: fallbackGroups)
                : snapshot.groups,
                fallbackGroups: fallbackGroups
            )
            : localGroupsFromDefaults(fallbackGroups: fallbackGroups)
        let resolvedSubscriptions = syncOptions.syncSubscriptions
            ? mergeLocalSubscriptionState(
                into: snapshot.subscriptions.isEmpty
                ? loadLocalSubscriptionsFromDefaults()
                : snapshot.subscriptions
            )
            : loadLocalSubscriptionsFromDefaults()
        let resolvedSubscriptionIDs = Set(resolvedSubscriptions.compactMap(\.id))
        let mergedStateResult = persistedStateByMergingLocalSubscriptionItems(
            into: baseState,
            validSubscriptionIDs: resolvedSubscriptionIDs,
            now: now
        )
        let resolvedState = mergedStateResult.state
        let syncedLanguage = syncOptions.syncLanguage ? snapshot.syncPreferences.language : nil
        let syncedBackgroundStyle = syncOptions.syncBackgroundStyle ? snapshot.syncPreferences.backgroundStyle : nil

        isHydratingPersistence = true
        persistedState = resolvedState
        items = materializedItems(from: resolvedState, now: now)
        groups = resolvedGroups
        subscriptions = resolvedSubscriptions
        syncedLanguageSelection = syncedLanguage
        if let syncedBackgroundStyle {
            backgroundStyle = syncedBackgroundStyle
        }
        isHydratingPersistence = false

        defaults.set(resolvedGroups, forKey: groupsStorageKey)
        if let compactData = try? JSONEncoder().encode(resolvedState) {
            defaults.set(compactData, forKey: compactStateStorageKey)
        }
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: itemsStorageKey)
        }
        mirrorSubscriptionsToLocalDefaults(resolvedSubscriptions)
        DeadlineStorage.reloadWidgets()
        validateSelectedFilterGroup()

        if mergedStateResult.didMerge, syncOptions.syncTasks {
            persistence?.savePersistedState(resolvedState)
            queueImmediateCloudReloadIfNeeded()
        }
    }

    private func persistedStateByMergingLocalSubscriptionItems(
        into state: DeadlinePersistedState,
        validSubscriptionIDs: Set<UUID>,
        now: Date
    ) -> (state: DeadlinePersistedState, didMerge: Bool) {
        let localSubscriptionItems = loadLocalDerivedSubscriptionItemsFromDefaults().filter { item in
            guard let subscriptionID = item.subscriptionID else { return false }
            return validSubscriptionIDs.contains(subscriptionID)
        }
        guard localSubscriptionItems.isEmpty == false else {
            return (state, false)
        }

        let stateItems = materializedItems(from: state, now: now)
        let mergedItems = mergedSubscriptionItems(
            stateItems,
            with: localSubscriptionItems
        )
        let mergedState = DeadlineLegacyMigration.migrateLegacyItems(
            DeadlineLegacyMigration.normalizeDecodedItems(mergedItems)
        ).state

        return (mergedState, mergedState != state)
    }

    private func mergedSubscriptionItems(
        _ baseItems: [DeadlineItem],
        with localSubscriptionItems: [DeadlineItem]
    ) -> [DeadlineItem] {
        var result = baseItems

        for localItem in localSubscriptionItems {
            guard let existingIndex = matchingPersistedSubscriptionItemIndex(
                for: localItem,
                in: result
            ) else {
                result.append(localItem)
                continue
            }

            result[existingIndex] = mergedPersistedSubscriptionItem(
                result[existingIndex],
                with: localItem
            )
        }

        return result
    }

    private func matchingPersistedSubscriptionItemIndex(
        for item: DeadlineItem,
        in items: [DeadlineItem]
    ) -> Int? {
        guard item.sourceKind == .subscribedURL, let subscriptionID = item.subscriptionID else {
            return nil
        }

        let candidates = items.indices.filter { index in
            let existingItem = items[index]
            return existingItem.sourceKind == .subscribedURL &&
                existingItem.subscriptionID == subscriptionID &&
                existingItem.id != item.id
        }

        if let externalEventIdentifier = item.externalEventIdentifier,
           let exactIdentifierIndex = candidates.first(where: {
               items[$0].externalEventIdentifier == externalEventIdentifier
           }) {
            return exactIdentifierIndex
        }

        if let itemIdentifier = item.externalEventIdentifier,
           let itemUID = subscriptionEventUID(from: itemIdentifier),
           let matchingUIDIndex = candidates.first(where: { index in
               guard let existingIdentifier = items[index].externalEventIdentifier else { return false }
               return subscriptionEventUID(from: existingIdentifier) == itemUID
           }) {
            return matchingUIDIndex
        }

        return candidates.first { index in
            let existingItem = items[index]
            return subscriptionTextMatches(existingItem.title, item.title) &&
                subscriptionTextMatches(existingItem.category, item.category) &&
                subscriptionTextMatches(existingItem.detail, item.detail) &&
                subscriptionDatesMatch(existingItem.endDate, item.endDate)
        }
    }

    private func mergedPersistedSubscriptionItem(
        _ lhs: DeadlineItem,
        with rhs: DeadlineItem
    ) -> DeadlineItem {
        var merged = preferredPersistedSubscriptionItem(lhs, rhs)
        let secondary = merged.id == lhs.id ? rhs : lhs

        merged.sourceKind = .subscribedURL
        merged.subscriptionID = merged.subscriptionID ?? secondary.subscriptionID
        merged.externalEventIdentifier = preferredSubscriptionIdentifier(
            merged.externalEventIdentifier,
            secondary.externalEventIdentifier
        )
        merged.completedAt = merged.completedAt ?? secondary.completedAt
        merged.createdAt = min(merged.createdAt, secondary.createdAt)
        merged.originalStartDateWasMissing = merged.originalStartDateWasMissing || secondary.originalStartDateWasMissing
        if merged.originalStartDateWasMissing, secondary.startDate < merged.startDate, secondary.startDate < merged.endDate {
            merged.startDate = secondary.startDate
        }
        if merged.reminders.isEmpty {
            merged.reminders = secondary.reminders
        }
        return merged
    }

    private func preferredPersistedSubscriptionItem(
        _ lhs: DeadlineItem,
        _ rhs: DeadlineItem
    ) -> DeadlineItem {
        if lhs.completedAt != nil, rhs.completedAt == nil {
            return lhs
        }
        if rhs.completedAt != nil, lhs.completedAt == nil {
            return rhs
        }
        if lhs.startDate != rhs.startDate {
            return lhs.startDate < rhs.startDate ? lhs : rhs
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt ? lhs : rhs
        }
        return lhs
    }

    private func preferredSubscriptionIdentifier(
        _ lhs: String?,
        _ rhs: String?
    ) -> String? {
        guard let lhs, lhs.isEmpty == false else { return rhs }
        guard let rhs, rhs.isEmpty == false else { return lhs }
        return subscriptionIdentifierLooksStable(lhs) ? lhs : rhs
    }

    private func subscriptionIdentifierLooksStable(_ identifier: String) -> Bool {
        guard let suffix = identifier.split(separator: "#").last.map(String.init) else {
            return false
        }
        return isSubscriptionOccurrenceIdentifierSuffix(suffix) == false
    }

    private func subscriptionDefinitions(from subscriptions: [DeadlineSubscription]) -> [DeadlineSubscription] {
        subscriptions.map { subscription in
            DeadlineSubscription(
                id: subscription.id,
                urlString: subscription.urlString,
                category: subscription.category,
                reminders: subscription.reminders,
                createdAt: subscription.createdAt
            )
        }
    }

    private func mergeLocalSubscriptionState(into subscriptions: [DeadlineSubscription]) -> [DeadlineSubscription] {
        let localStates = loadSubscriptionLocalStates()
        return subscriptions.map { subscription in
            var merged = subscription
            if let localState = localStates[subscription.id.uuidString] {
                merged.lastSyncedAt = localState.lastSyncedAt
                merged.lastAttemptedAt = localState.lastAttemptedAt
                merged.lastErrorMessage = localState.lastErrorMessage
            }
            return merged
        }
    }

    private func loadSubscriptionLocalStates() -> [String: DeadlineSubscriptionLocalState] {
        guard
            let data = defaults.data(forKey: subscriptionLocalStateStorageKey),
            let decoded = try? JSONDecoder().decode([String: DeadlineSubscriptionLocalState].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private func saveSyncPreferencesIfNeeded(currentLanguage: AppLanguage? = nil) {
        guard syncOptions.syncLanguage || syncOptions.syncBackgroundStyle else { return }
        let existingPreferences = persistence?.loadSnapshot().syncPreferences ?? DeadlineSyncPreferenceSnapshot()
        persistence?.saveSyncPreferences(
            DeadlineSyncPreferenceSnapshot(
                language: syncOptions.syncLanguage ? (currentLanguage ?? currentStoredLanguageSelection()) : existingPreferences.language,
                backgroundStyle: syncOptions.syncBackgroundStyle ? backgroundStyle : existingPreferences.backgroundStyle
            )
        )
        queueImmediateCloudReloadIfNeeded()
    }

    private func currentStoredLanguageSelection() -> AppLanguage? {
        defaults.string(forKey: languageSelectionStorageKey).flatMap(AppLanguage.init(rawValue:)) ?? AppLanguage.detectFromSystem()
    }

    private func localPersistedStateFromDefaults() -> DeadlinePersistedState {
        if let compactData = defaults.data(forKey: compactStateStorageKey),
           let state = try? JSONDecoder().decode(DeadlinePersistedState.self, from: compactData) {
            return state.removingDerivedSubscriptionData()
        }

        guard
            let data = defaults.data(forKey: itemsStorageKey),
            let decoded = try? JSONDecoder().decode([DeadlineItem].self, from: data)
        else {
            return DeadlinePersistedState()
        }

        return DeadlineLegacyMigration.migrateLegacyItems(
            DeadlineLegacyMigration.normalizeDecodedItems(decoded)
        ).state.removingDerivedSubscriptionData()
    }

    private func localGroupsFromDefaults(fallbackGroups: [String]) -> [String] {
        normalizedGroups(
            defaults.stringArray(forKey: groupsStorageKey) ?? fallbackGroups,
            fallbackGroups: fallbackGroups
        )
    }

    private func normalizedGroups(_ groups: [String], fallbackGroups: [String]) -> [String] {
        let trimmed = groups
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        var unique: [String] = []
        for group in trimmed where unique.contains(group) == false {
            unique.append(group)
        }
        return unique.isEmpty ? fallbackGroups : unique
    }

    private func loadLocalSubscriptionsFromDefaults() -> [DeadlineSubscription] {
        guard
            let data = defaults.data(forKey: subscriptionsStorageKey),
            let decoded = try? JSONDecoder().decode([DeadlineSubscription].self, from: data)
        else {
            return []
        }
        return mergeLocalSubscriptionState(into: decoded)
    }

    private func loadLocalDerivedSubscriptionItemsFromDefaults() -> [DeadlineItem] {
        guard
            let data = defaults.data(forKey: itemsStorageKey),
            let decoded = try? JSONDecoder().decode([DeadlineItem].self, from: data)
        else {
            return []
        }

        return DeadlineLegacyMigration.normalizeDecodedItems(decoded).filter {
            $0.subscriptionID != nil && $0.belongsToRepeatSeries == false
        }
    }

    private func mirrorSubscriptionsToLocalDefaults(_ subscriptions: [DeadlineSubscription]) {
        let definitions = subscriptionDefinitions(from: subscriptions)
        if let data = try? JSONEncoder().encode(definitions) {
            defaults.set(data, forKey: subscriptionsStorageKey)
        }

        let localStates = Dictionary(uniqueKeysWithValues: subscriptions.map { subscription in
            (
                subscription.id.uuidString,
                DeadlineSubscriptionLocalState(
                    lastSyncedAt: subscription.lastSyncedAt,
                    lastAttemptedAt: subscription.lastAttemptedAt,
                    lastErrorMessage: subscription.lastErrorMessage
                )
            )
        })

        if let data = try? JSONEncoder().encode(localStates) {
            defaults.set(data, forKey: subscriptionLocalStateStorageKey)
        }
    }

    private func persistEnabledSyncDomains() {
        if syncOptions.syncTasks {
            saveItems()
        }
        if syncOptions.syncGroups {
            saveGroups()
        }
        if syncOptions.syncSubscriptions {
            saveSubscriptions()
        }
        if syncOptions.syncLanguage || syncOptions.syncBackgroundStyle {
            saveSyncPreferencesIfNeeded()
        }
    }

    func refreshCloudAccountStatusIfNeeded() async {
        guard syncOptions.automaticSyncEnabled else { return }
        let expectedPersistenceGeneration = persistenceGeneration

        let snapshot = await DeadlineCloudSyncMonitor.fetchCurrentAccountSnapshot()
        guard expectedPersistenceGeneration == persistenceGeneration else { return }
        guard syncOptions.automaticSyncEnabled else { return }
        let storedFingerprint = defaults.string(forKey: cloudAccountFingerprintStorageKey)

        switch snapshot.status {
        case .available:
            guard let fingerprint = snapshot.fingerprint else { return }

            if let storedFingerprint, storedFingerprint != fingerprint {
                pendingCloudAccountPrompt = DeadlineCloudAccountPrompt(fingerprint: fingerprint)
                var updated = syncOptions
                updated.setAutomaticSyncEnabled(false)
                syncOptions = updated
                reconfigurePersistence(syncEnabled: false)
            } else if storedFingerprint == nil {
                defaults.set(fingerprint, forKey: cloudAccountFingerprintStorageKey)
            }
        case .noAccount, .restricted:
            if storedFingerprint != nil {
                pendingCloudAccountPrompt = DeadlineCloudAccountPrompt(fingerprint: nil)
                var updated = syncOptions
                updated.setAutomaticSyncEnabled(false)
                syncOptions = updated
                reconfigurePersistence(syncEnabled: false)
            }
        case .temporarilyUnavailable, .couldNotDetermine:
            break
        @unknown default:
            break
        }
    }

    func resolveCloudAccountPromptByMerging() async {
        if let fingerprint = pendingCloudAccountPrompt?.fingerprint {
            defaults.set(fingerprint, forKey: cloudAccountFingerprintStorageKey)
        }
        pendingCloudAccountPrompt = nil
        setAutomaticSyncEnabled(true)
        await refreshCloudAccountStatusIfNeeded()
    }

    func resolveCloudAccountPromptByReplacingLocalData() async {
        if let fingerprint = pendingCloudAccountPrompt?.fingerprint {
            defaults.set(fingerprint, forKey: cloudAccountFingerprintStorageKey)
        }

        pendingCloudAccountPrompt = nil
        persistenceGeneration += 1
        persistenceRemoteChangeCancellable = nil
        persistenceCloudSyncEventCancellable = nil
        resetCloudSyncActivity()
        persistence = nil
        DeadlinePersistenceController.destroyPersistentStoreFiles()
        persistence = DeadlinePersistenceController(syncEnabled: true)
        observePersistenceRemoteChanges()
        observePersistenceCloudSyncEvents()

        var updated = syncOptions
        updated.setAutomaticSyncEnabled(true)
        syncOptions = updated

        loadSyncedSnapshot(now: .now)
        if let issue = persistence?.loadIssueDescription {
            lastSyncErrorMessage = issue
        }
    }

    func resolveCloudAccountPromptByDisablingSync() {
        pendingCloudAccountPrompt = nil
        setAutomaticSyncEnabled(false)
    }
}
