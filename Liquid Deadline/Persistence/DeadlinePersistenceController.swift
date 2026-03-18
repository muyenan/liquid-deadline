import CloudKit
import CoreData
import Foundation

struct DeadlineSyncPreferenceSnapshot: Hashable {
    var language: AppLanguage?
    var backgroundStyle: BackgroundStyleOption?
}

struct DeadlinePersistenceSnapshot: Hashable {
    var state: DeadlinePersistedState
    var groups: [String]
    var subscriptions: [DeadlineSubscription]
    var syncPreferences: DeadlineSyncPreferenceSnapshot
}

enum DeadlinePersistenceError: LocalizedError {
    case storeLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .storeLoadFailed(let description):
            return description
        }
    }
}

final class DeadlinePersistenceController {
    static let remoteChangeNotification = Notification.Name("DeadlinePersistenceRemoteChangeNotification")

    private enum EntityName {
        static let task = "DeadlineTaskRecord"
        static let recurringSeries = "DeadlineRecurringSeriesRecord"
        static let recurringOverride = "DeadlineRecurringOverrideRecord"
        static let subscription = "DeadlineSubscriptionRecord"
        static let group = "DeadlineGroupRecord"
        static let syncPreference = "DeadlineSyncPreferenceRecord"
    }

    private let container: NSPersistentCloudKitContainer
    private let context: NSManagedObjectContext
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    let isCloudSyncEnabled: Bool
    let loadIssueDescription: String?

    static func destroyPersistentStoreFiles() {
        let baseURL = DeadlineStorage.persistentStoreURL()
        let sidecarURLs = [
            baseURL,
            URL(fileURLWithPath: baseURL.path + "-shm"),
            URL(fileURLWithPath: baseURL.path + "-wal")
        ]

        for url in sidecarURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    init(
        syncEnabled: Bool,
        defaults: UserDefaults = DeadlineStorage.sharedDefaults
    ) {
        self.defaults = defaults

        let description = NSPersistentStoreDescription(url: DeadlineStorage.persistentStoreURL())
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        let model = Self.makeManagedObjectModel()
        let cloudContainerIdentifier = DeadlineStorage.cloudKitContainerIdentifier

        var resolvedLoadIssueDescription: String?
        var resolvedSyncEnabled = false

        let container = NSPersistentCloudKitContainer(name: "LiquidDeadlineModel", managedObjectModel: model)
        if syncEnabled, let cloudContainerIdentifier {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudContainerIdentifier)
        }
        container.persistentStoreDescriptions = [description]

        do {
            try Self.loadStores(for: container)
            resolvedSyncEnabled = syncEnabled && description.cloudKitContainerOptions != nil
        } catch {
            let fallbackContainer = NSPersistentCloudKitContainer(name: "LiquidDeadlineModel", managedObjectModel: model)
            let fallbackDescription = NSPersistentStoreDescription(url: DeadlineStorage.persistentStoreURL())
            fallbackDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            fallbackDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            fallbackDescription.shouldMigrateStoreAutomatically = true
            fallbackDescription.shouldInferMappingModelAutomatically = true
            fallbackContainer.persistentStoreDescriptions = [fallbackDescription]

            do {
                try Self.loadStores(for: fallbackContainer)
                resolvedLoadIssueDescription = Self.describe(error)
                self.container = fallbackContainer
                self.context = fallbackContainer.viewContext
                self.isCloudSyncEnabled = false
                self.loadIssueDescription = resolvedLoadIssueDescription
                configureContext()
                observeRemoteChanges()
                return
            } catch {
                fatalError("Failed to load Core Data stores: \(Self.describe(error))")
            }
        }

        self.container = container
        self.context = container.viewContext
        self.isCloudSyncEnabled = resolvedSyncEnabled
        self.loadIssueDescription = resolvedLoadIssueDescription
        configureContext()
        observeRemoteChanges()
    }

    func bootstrapIfNeeded(
        fallbackGroups: [String]
    ) {
        guard hasBootstrappedData == false else { return }

        let state = legacyPersistedStateFromDefaults()
        let groups = legacyGroupsFromDefaults(fallbackGroups: fallbackGroups)
        let subscriptions = legacySubscriptionsFromDefaults()
        let syncPreferences = legacySyncPreferencesFromDefaults()

        let snapshot = DeadlinePersistenceSnapshot(
            state: state,
            groups: groups,
            subscriptions: subscriptions.map {
                DeadlineSubscription(
                    id: $0.id,
                    urlString: $0.urlString,
                    category: $0.category,
                    createdAt: $0.createdAt
                )
            },
            syncPreferences: syncPreferences
        )

        saveSnapshot(snapshot)
    }

    func loadSnapshot() -> DeadlinePersistenceSnapshot {
        context.performAndWait {
            DeadlinePersistenceSnapshot(
                state: loadPersistedState(),
                groups: loadGroups(),
                subscriptions: loadSubscriptions(),
                syncPreferences: loadSyncPreferences()
            )
        }
    }

    func savePersistedState(_ state: DeadlinePersistedState) {
        context.performAndWait {
            let sanitizedState = state.removingDerivedSubscriptionData()
            upsertTasks(sanitizedState.standaloneItems, kind: .standalone)
            upsertTasks(sanitizedState.legacyRecurringItems, kind: .legacyRecurring)
            upsertRecurringSeries(sanitizedState.recurringSeries)
            upsertRecurringOverrides(sanitizedState.recurringOverrides)
            persistContextIfNeeded()
        }
    }

    func saveGroups(_ groups: [String]) {
        context.performAndWait {
            let request = NSFetchRequest<DeadlineGroupRecord>(entityName: EntityName.group)
            let existing = (try? context.fetch(request)) ?? []
            let existingByName = Dictionary(uniqueKeysWithValues: existing.map { ($0.name, $0) })
            let desired = Set(groups)

            for record in existing where desired.contains(record.name) == false {
                context.delete(record)
            }

            for (index, group) in groups.enumerated() {
                let record = existingByName[group] ?? DeadlineGroupRecord(context: context)
                record.name = group
                record.order = Int64(index)
            }

            persistContextIfNeeded()
        }
    }

    func saveSubscriptions(_ subscriptions: [DeadlineSubscription]) {
        context.performAndWait {
            let request = NSFetchRequest<DeadlineSubscriptionRecord>(entityName: EntityName.subscription)
            let existing = (try? context.fetch(request)) ?? []
            let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
            let desiredIDs = Set(subscriptions.map(\.id))

            for record in existing where desiredIDs.contains(record.id) == false {
                context.delete(record)
            }

            for subscription in subscriptions {
                let record = existingByID[subscription.id] ?? DeadlineSubscriptionRecord(context: context)
                record.id = subscription.id
                record.urlString = subscription.urlString
                record.category = subscription.category
                record.createdAt = subscription.createdAt
            }

            persistContextIfNeeded()
        }
    }

    func saveSyncPreferences(_ preferences: DeadlineSyncPreferenceSnapshot) {
        context.performAndWait {
            let request = NSFetchRequest<DeadlineSyncPreferenceRecord>(entityName: EntityName.syncPreference)
            request.fetchLimit = 1
            let record = ((try? context.fetch(request))?.first) ?? DeadlineSyncPreferenceRecord(context: context)
            record.recordID = "sync_preferences"
            record.languageRaw = preferences.language?.rawValue
            record.backgroundStyleRaw = preferences.backgroundStyle?.rawValue
            persistContextIfNeeded()
        }
    }

    private var hasBootstrappedData: Bool {
        context.performAndWait {
            let entities = [
                EntityName.task,
                EntityName.recurringSeries,
                EntityName.recurringOverride,
                EntityName.subscription,
                EntityName.group
            ]

            return entities.contains { entityName in
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                request.fetchLimit = 1
                return ((try? context.count(for: request)) ?? 0) > 0
            }
        }
    }

    private func configureContext() {
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.transactionAuthor = "DeadlineStore"
    }

    private func observeRemoteChanges() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: nil
        ) { _ in
            NotificationCenter.default.post(name: Self.remoteChangeNotification, object: nil)
        }
    }

    private static func loadStores(for container: NSPersistentCloudKitContainer) throws {
        var capturedError: Error?
        container.loadPersistentStores { _, error in
            capturedError = error
        }
        if let capturedError {
            throw capturedError
        }
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
        let recoverySuggestion = nsError.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String
        let underlyingError = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.localizedDescription
        let partialErrorsDescription = describePartialErrors(from: nsError)

        return [
            describeNSError(nsError),
            failureReason,
            recoverySuggestion,
            underlyingError
            ,
            partialErrorsDescription
        ]
        .compactMap { value in
            guard let value, value.isEmpty == false else { return nil }
            return value
        }
        .joined(separator: "\n")
    }

    private static func describeNSError(_ error: NSError) -> String {
        if error.domain == CKErrorDomain {
            let codeName = describeCloudKitCode(error.code)
            if codeName.isEmpty == false {
                return "\(error.localizedDescription) [\(codeName)]"
            }
        }

        return error.localizedDescription
    }

    private static func describePartialErrors(from error: NSError) -> String? {
        guard
            error.domain == CKErrorDomain,
            let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: NSError],
            partialErrors.isEmpty == false
        else {
            return nil
        }

        let lines = partialErrors.map { key, value in
            let item = String(describing: key)
            return "\(item): \(describe(value))"
        }
        .sorted()

        return lines.isEmpty ? nil : "Partial errors:\n" + lines.joined(separator: "\n")
    }

    private static func describeCloudKitCode(_ rawValue: Int) -> String {
        switch CKError.Code(rawValue: rawValue) {
        case .internalError:
            return "CKError.internalError"
        case .partialFailure:
            return "CKError.partialFailure"
        case .networkUnavailable:
            return "CKError.networkUnavailable"
        case .networkFailure:
            return "CKError.networkFailure"
        case .badContainer:
            return "CKError.badContainer"
        case .serviceUnavailable:
            return "CKError.serviceUnavailable"
        case .requestRateLimited:
            return "CKError.requestRateLimited"
        case .missingEntitlement:
            return "CKError.missingEntitlement"
        case .notAuthenticated:
            return "CKError.notAuthenticated"
        case .permissionFailure:
            return "CKError.permissionFailure"
        case .unknownItem:
            return "CKError.unknownItem"
        case .invalidArguments:
            return "CKError.invalidArguments"
        case .serverRecordChanged:
            return "CKError.serverRecordChanged"
        case .serverRejectedRequest:
            return "CKError.serverRejectedRequest"
        case .constraintViolation:
            return "CKError.constraintViolation"
        case .changeTokenExpired:
            return "CKError.changeTokenExpired"
        case .zoneBusy:
            return "CKError.zoneBusy"
        case .badDatabase:
            return "CKError.badDatabase"
        case .quotaExceeded:
            return "CKError.quotaExceeded"
        case .zoneNotFound:
            return "CKError.zoneNotFound"
        case .limitExceeded:
            return "CKError.limitExceeded"
        case .userDeletedZone:
            return "CKError.userDeletedZone"
        case .managedAccountRestricted:
            return "CKError.managedAccountRestricted"
        case .serverResponseLost:
            return "CKError.serverResponseLost"
        case .accountTemporarilyUnavailable:
            return "CKError.accountTemporarilyUnavailable"
        case .some(let code):
            return "CKError(\(code.rawValue))"
        case .none:
            return ""
        }
    }

    private func saveSnapshot(_ snapshot: DeadlinePersistenceSnapshot) {
        context.performAndWait {
            let sanitizedState = snapshot.state.removingDerivedSubscriptionData()
            upsertTasks(sanitizedState.standaloneItems, kind: .standalone)
            upsertTasks(sanitizedState.legacyRecurringItems, kind: .legacyRecurring)
            upsertRecurringSeries(sanitizedState.recurringSeries)
            upsertRecurringOverrides(sanitizedState.recurringOverrides)
            upsertGroups(snapshot.groups)
            upsertSubscriptions(snapshot.subscriptions)
            upsertSyncPreferences(snapshot.syncPreferences)
            persistContextIfNeeded()
        }
    }

    private func upsertTasks(_ items: [DeadlineItem], kind: DeadlineTaskStorageKind) {
        let request = NSFetchRequest<DeadlineTaskRecord>(entityName: EntityName.task)
        request.predicate = NSPredicate(format: "storageKindRaw == %@", kind.rawValue)
        let existing = (try? context.fetch(request)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let desiredIDs = Set(items.map(\.id))

        for record in existing where desiredIDs.contains(record.id) == false {
            context.delete(record)
        }

        for item in items {
            let record = existingByID[item.id] ?? DeadlineTaskRecord(context: context)
            apply(item, to: record, kind: kind)
        }
    }

    private func upsertRecurringSeries(_ series: [DeadlineRecurringSeries]) {
        let request = NSFetchRequest<DeadlineRecurringSeriesRecord>(entityName: EntityName.recurringSeries)
        let existing = (try? context.fetch(request)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.seriesID, $0) })
        let desiredIDs = Set(series.map(\.seriesID))

        for record in existing where desiredIDs.contains(record.seriesID) == false {
            context.delete(record)
        }

        for item in series {
            let record = existingByID[item.seriesID] ?? DeadlineRecurringSeriesRecord(context: context)
            apply(item, to: record)
        }
    }

    private func upsertRecurringOverrides(_ overrides: [DeadlineRecurringOverride]) {
        let request = NSFetchRequest<DeadlineRecurringOverrideRecord>(entityName: EntityName.recurringOverride)
        let existing = (try? context.fetch(request)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.recordID, $0) })
        let desiredIDs = Set(overrides.map(\.id))

        for record in existing where desiredIDs.contains(record.recordID) == false {
            context.delete(record)
        }

        for override in overrides {
            let record = existingByID[override.id] ?? DeadlineRecurringOverrideRecord(context: context)
            apply(override, to: record)
        }
    }

    private func upsertGroups(_ groups: [String]) {
        let request = NSFetchRequest<DeadlineGroupRecord>(entityName: EntityName.group)
        let existing = (try? context.fetch(request)) ?? []
        let existingByName = Dictionary(uniqueKeysWithValues: existing.map { ($0.name, $0) })
        let desired = Set(groups)

        for record in existing where desired.contains(record.name) == false {
            context.delete(record)
        }

        for (index, group) in groups.enumerated() {
            let record = existingByName[group] ?? DeadlineGroupRecord(context: context)
            record.name = group
            record.order = Int64(index)
        }
    }

    private func upsertSubscriptions(_ subscriptions: [DeadlineSubscription]) {
        let request = NSFetchRequest<DeadlineSubscriptionRecord>(entityName: EntityName.subscription)
        let existing = (try? context.fetch(request)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let desiredIDs = Set(subscriptions.map(\.id))

        for record in existing where desiredIDs.contains(record.id) == false {
            context.delete(record)
        }

        for subscription in subscriptions {
            let record = existingByID[subscription.id] ?? DeadlineSubscriptionRecord(context: context)
            record.id = subscription.id
            record.urlString = subscription.urlString
            record.category = subscription.category
            record.createdAt = subscription.createdAt
        }
    }

    private func upsertSyncPreferences(_ preferences: DeadlineSyncPreferenceSnapshot) {
        let request = NSFetchRequest<DeadlineSyncPreferenceRecord>(entityName: EntityName.syncPreference)
        request.fetchLimit = 1
        let record = ((try? context.fetch(request))?.first) ?? DeadlineSyncPreferenceRecord(context: context)
        record.recordID = "sync_preferences"
        record.languageRaw = preferences.language?.rawValue
        record.backgroundStyleRaw = preferences.backgroundStyle?.rawValue
    }

    private func loadPersistedState() -> DeadlinePersistedState {
        let standaloneRequest = NSFetchRequest<DeadlineTaskRecord>(entityName: EntityName.task)
        standaloneRequest.predicate = NSPredicate(format: "storageKindRaw == %@", DeadlineTaskStorageKind.standalone.rawValue)
        let legacyRequest = NSFetchRequest<DeadlineTaskRecord>(entityName: EntityName.task)
        legacyRequest.predicate = NSPredicate(format: "storageKindRaw == %@", DeadlineTaskStorageKind.legacyRecurring.rawValue)

        let standaloneItems = ((try? context.fetch(standaloneRequest)) ?? [])
            .compactMap(makeDeadlineItem(from:))
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.startDate < rhs.startDate
            }

        let legacyRecurringItems = ((try? context.fetch(legacyRequest)) ?? [])
            .compactMap(makeDeadlineItem(from:))
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.startDate < rhs.startDate
            }

        let seriesRequest = NSFetchRequest<DeadlineRecurringSeriesRecord>(entityName: EntityName.recurringSeries)
        let recurringSeries = ((try? context.fetch(seriesRequest)) ?? [])
            .compactMap(makeRecurringSeries(from:))
            .sorted { $0.createdAt < $1.createdAt }

        let overrideRequest = NSFetchRequest<DeadlineRecurringOverrideRecord>(entityName: EntityName.recurringOverride)
        let recurringOverrides = ((try? context.fetch(overrideRequest)) ?? [])
            .map(makeRecurringOverride(from:))
            .sorted { lhs, rhs in
                if lhs.seriesID == rhs.seriesID {
                    return lhs.occurrenceIndex < rhs.occurrenceIndex
                }
                return lhs.seriesID.uuidString < rhs.seriesID.uuidString
            }

        return DeadlinePersistedState(
            standaloneItems: standaloneItems,
            legacyRecurringItems: legacyRecurringItems,
            recurringSeries: recurringSeries,
            recurringOverrides: recurringOverrides
        )
    }

    private func loadGroups() -> [String] {
        let request = NSFetchRequest<DeadlineGroupRecord>(entityName: EntityName.group)
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        return ((try? context.fetch(request)) ?? []).map(\.name)
    }

    private func loadSubscriptions() -> [DeadlineSubscription] {
        let request = NSFetchRequest<DeadlineSubscriptionRecord>(entityName: EntityName.subscription)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return ((try? context.fetch(request)) ?? []).map { record in
            DeadlineSubscription(
                id: record.id,
                urlString: record.urlString,
                category: record.category,
                createdAt: record.createdAt
            )
        }
    }

    private func loadSyncPreferences() -> DeadlineSyncPreferenceSnapshot {
        let request = NSFetchRequest<DeadlineSyncPreferenceRecord>(entityName: EntityName.syncPreference)
        request.fetchLimit = 1
        guard let record = (try? context.fetch(request))?.first else {
            return DeadlineSyncPreferenceSnapshot()
        }

        return DeadlineSyncPreferenceSnapshot(
            language: record.languageRaw.flatMap(AppLanguage.init(rawValue:)),
            backgroundStyle: record.backgroundStyleRaw.flatMap(BackgroundStyleOption.init(rawValue:))
        )
    }

    private func apply(_ item: DeadlineItem, to record: DeadlineTaskRecord, kind: DeadlineTaskStorageKind) {
        record.id = item.id
        record.title = item.title
        record.category = item.category
        record.detail = item.detail
        record.startDate = item.startDate
        record.endDate = item.endDate
        record.completedAt = item.completedAt
        record.createdAt = item.createdAt
        record.sourceKindRaw = item.sourceKind.rawValue
        record.subscriptionID = item.subscriptionID
        record.externalEventIdentifier = item.externalEventIdentifier
        record.originalStartDateWasMissing = item.originalStartDateWasMissing
        record.isAllDay = item.isAllDay
        record.repeatSeriesID = item.repeatSeriesID
        record.repeatOccurrenceIndex = Int64(item.repeatOccurrenceIndex)
        record.repeatRuleInterval = item.repeatRule.map { NSNumber(value: $0.interval) }
        record.repeatRuleUnitRaw = item.repeatRule?.unit.rawValue
        record.repeatRuleEndDate = item.repeatRule?.endDate
        record.storageKindRaw = kind.rawValue
    }

    private func makeDeadlineItem(from record: DeadlineTaskRecord) -> DeadlineItem? {
        let repeatRule: DeadlineRepeatRule?
        if let repeatRuleInterval = record.repeatRuleInterval?.intValue,
           let repeatRuleUnitRaw = record.repeatRuleUnitRaw,
           let repeatRuleUnit = DeadlineRepeatUnit(rawValue: repeatRuleUnitRaw) {
            repeatRule = DeadlineRepeatRule(
                interval: repeatRuleInterval,
                unit: repeatRuleUnit,
                endDate: record.repeatRuleEndDate
            )
        } else {
            repeatRule = nil
        }

        guard let sourceKind = DeadlineItemSourceKind(rawValue: record.sourceKindRaw) else {
            return nil
        }

        return DeadlineItem(
            id: record.id,
            title: record.title,
            category: record.category,
            detail: record.detail,
            startDate: record.startDate,
            endDate: record.endDate,
            completedAt: record.completedAt,
            createdAt: record.createdAt,
            sourceKind: sourceKind,
            subscriptionID: record.subscriptionID,
            externalEventIdentifier: record.externalEventIdentifier,
            originalStartDateWasMissing: record.originalStartDateWasMissing,
            isAllDay: record.isAllDay,
            repeatSeriesID: record.repeatSeriesID,
            repeatOccurrenceIndex: Int(record.repeatOccurrenceIndex),
            repeatRule: repeatRule
        )
    }

    private func apply(_ series: DeadlineRecurringSeries, to record: DeadlineRecurringSeriesRecord) {
        record.seriesID = series.seriesID
        record.seedItemID = series.seedItemID
        record.title = series.title
        record.category = series.category
        record.detail = series.detail
        record.startDate = series.startDate
        record.endDate = series.endDate
        record.createdAt = series.createdAt
        record.sourceKindRaw = series.sourceKind.rawValue
        record.subscriptionID = series.subscriptionID
        record.externalEventIdentifier = series.externalEventIdentifier
        record.originalStartDateWasMissing = series.originalStartDateWasMissing
        record.isAllDay = series.isAllDay
        record.repeatRuleInterval = Int64(series.repeatRule.interval)
        record.repeatRuleUnitRaw = series.repeatRule.unit.rawValue
        record.repeatRuleEndDate = series.repeatRule.endDate
    }

    private func makeRecurringSeries(from record: DeadlineRecurringSeriesRecord) -> DeadlineRecurringSeries? {
        guard
            let sourceKind = DeadlineItemSourceKind(rawValue: record.sourceKindRaw),
            let unit = DeadlineRepeatUnit(rawValue: record.repeatRuleUnitRaw)
        else {
            return nil
        }

        return DeadlineRecurringSeries(
            seriesID: record.seriesID,
            seedItemID: record.seedItemID,
            title: record.title,
            category: record.category,
            detail: record.detail,
            startDate: record.startDate,
            endDate: record.endDate,
            createdAt: record.createdAt,
            sourceKind: sourceKind,
            subscriptionID: record.subscriptionID,
            externalEventIdentifier: record.externalEventIdentifier,
            originalStartDateWasMissing: record.originalStartDateWasMissing,
            isAllDay: record.isAllDay,
            repeatRule: DeadlineRepeatRule(
                interval: Int(record.repeatRuleInterval),
                unit: unit,
                endDate: record.repeatRuleEndDate
            )
        )
    }

    private func apply(_ override: DeadlineRecurringOverride, to record: DeadlineRecurringOverrideRecord) {
        record.recordID = override.id
        record.seriesID = override.seriesID
        record.occurrenceIndex = Int64(override.occurrenceIndex)
        record.itemID = override.itemID
        record.title = override.title
        record.category = override.category
        record.detail = override.detail
        record.startDate = override.startDate
        record.endDate = override.endDate
        record.completedAt = override.completedAt
        record.isAllDay = override.isAllDay.map(NSNumber.init(value:))
        record.deletionFlag = override.isDeleted
    }

    private func makeRecurringOverride(from record: DeadlineRecurringOverrideRecord) -> DeadlineRecurringOverride {
        DeadlineRecurringOverride(
            seriesID: record.seriesID,
            occurrenceIndex: Int(record.occurrenceIndex),
            itemID: record.itemID,
            title: record.title,
            category: record.category,
            detail: record.detail,
            startDate: record.startDate,
            endDate: record.endDate,
            completedAt: record.completedAt,
            isAllDay: record.isAllDay?.boolValue,
            isDeleted: record.deletionFlag
        )
    }

    private func legacyPersistedStateFromDefaults() -> DeadlinePersistedState {
        if let compactData = defaults.data(forKey: DeadlineStorage.compactStateStorageKey),
           let state = try? decoder.decode(DeadlinePersistedState.self, from: compactData) {
            return state.removingDerivedSubscriptionData()
        }

        guard
            let data = defaults.data(forKey: DeadlineStorage.itemsStorageKey),
            let decoded = try? decoder.decode([DeadlineItem].self, from: data)
        else {
            return DeadlinePersistedState()
        }

        return DeadlineLegacyMigration.migrateLegacyItems(
            DeadlineLegacyMigration.normalizeDecodedItems(decoded)
        ).state.removingDerivedSubscriptionData()
    }

    private func legacyGroupsFromDefaults(fallbackGroups: [String]) -> [String] {
        let stored = defaults.stringArray(forKey: DeadlineStorage.groupsStorageKey) ?? fallbackGroups
        let normalized = stored
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        var unique: [String] = []
        for group in normalized where unique.contains(group) == false {
            unique.append(group)
        }
        return unique.isEmpty ? fallbackGroups : unique
    }

    private func legacySubscriptionsFromDefaults() -> [DeadlineSubscription] {
        guard
            let data = defaults.data(forKey: DeadlineStorage.subscriptionsStorageKey),
            let decoded = try? decoder.decode([DeadlineSubscription].self, from: data)
        else {
            return []
        }
        return decoded
    }

    private func legacySyncPreferencesFromDefaults() -> DeadlineSyncPreferenceSnapshot {
        DeadlineSyncPreferenceSnapshot(
            language: defaults.string(forKey: DeadlineStorage.languageSelectionKey).flatMap(AppLanguage.init(rawValue:)),
            backgroundStyle: defaults.string(forKey: DeadlineStorage.backgroundStyleStorageKey).flatMap(BackgroundStyleOption.init(rawValue:))
        )
    }

    private func persistContextIfNeeded() {
        guard context.hasChanges else { return }
        try? context.save()
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            makeTaskEntity(),
            makeRecurringSeriesEntity(),
            makeRecurringOverrideEntity(),
            makeSubscriptionEntity(),
            makeGroupEntity(),
            makeSyncPreferenceEntity()
        ]
        return model
    }

    private static func makeTaskEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.task
        entity.managedObjectClassName = NSStringFromClass(DeadlineTaskRecord.self)
        entity.properties = [
            attribute("id", .UUIDAttributeType, isOptional: false, defaultValue: UUID()),
            attribute("title", .stringAttributeType, isOptional: false, defaultValue: ""),
            attribute("category", .stringAttributeType, isOptional: false, defaultValue: ""),
            attribute("detail", .stringAttributeType, isOptional: false, defaultValue: ""),
            attribute("startDate", .dateAttributeType, isOptional: false, defaultValue: Date(timeIntervalSinceReferenceDate: 0)),
            attribute("endDate", .dateAttributeType, isOptional: false, defaultValue: Date(timeIntervalSinceReferenceDate: 0)),
            attribute("completedAt", .dateAttributeType),
            attribute("createdAt", .dateAttributeType, isOptional: false, defaultValue: Date(timeIntervalSinceReferenceDate: 0)),
            attribute("sourceKindRaw", .stringAttributeType, isOptional: false, defaultValue: DeadlineItemSourceKind.manual.rawValue),
            attribute("subscriptionID", .UUIDAttributeType),
            attribute("externalEventIdentifier", .stringAttributeType),
            attribute("originalStartDateWasMissing", .booleanAttributeType, isOptional: false, defaultValue: false),
            attribute("isAllDay", .booleanAttributeType, isOptional: false, defaultValue: false),
            attribute("repeatSeriesID", .UUIDAttributeType),
            attribute("repeatOccurrenceIndex", .integer64AttributeType, isOptional: false, defaultValue: 0),
            attribute("repeatRuleInterval", .integer64AttributeType),
            attribute("repeatRuleUnitRaw", .stringAttributeType),
            attribute("repeatRuleEndDate", .dateAttributeType),
            attribute("storageKindRaw", .stringAttributeType, isOptional: false, defaultValue: DeadlineTaskStorageKind.standalone.rawValue)
        ]
        return entity
    }

    private static func makeRecurringSeriesEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.recurringSeries
        entity.managedObjectClassName = NSStringFromClass(DeadlineRecurringSeriesRecord.self)
        entity.properties = [
            attribute("seriesID", .UUIDAttributeType, isOptional: false, defaultValue: UUID()),
            attribute("seedItemID", .UUIDAttributeType, isOptional: false, defaultValue: UUID()),
            attribute("title", .stringAttributeType, isOptional: false, defaultValue: ""),
            attribute("category", .stringAttributeType, isOptional: false, defaultValue: ""),
            attribute("detail", .stringAttributeType, isOptional: false, defaultValue: ""),
            attribute("startDate", .dateAttributeType, isOptional: false, defaultValue: Date(timeIntervalSinceReferenceDate: 0)),
            attribute("endDate", .dateAttributeType, isOptional: false, defaultValue: Date(timeIntervalSinceReferenceDate: 0)),
            attribute("createdAt", .dateAttributeType, isOptional: false, defaultValue: Date(timeIntervalSinceReferenceDate: 0)),
            attribute("sourceKindRaw", .stringAttributeType, isOptional: false, defaultValue: DeadlineItemSourceKind.manual.rawValue),
            attribute("subscriptionID", .UUIDAttributeType),
            attribute("externalEventIdentifier", .stringAttributeType),
            attribute("originalStartDateWasMissing", .booleanAttributeType, isOptional: false, defaultValue: false),
            attribute("isAllDay", .booleanAttributeType, isOptional: false, defaultValue: false),
            attribute("repeatRuleInterval", .integer64AttributeType, isOptional: false, defaultValue: 1),
            attribute("repeatRuleUnitRaw", .stringAttributeType, isOptional: false, defaultValue: DeadlineRepeatUnit.day.rawValue),
            attribute("repeatRuleEndDate", .dateAttributeType)
        ]
        return entity
    }

    private static func makeRecurringOverrideEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.recurringOverride
        entity.managedObjectClassName = NSStringFromClass(DeadlineRecurringOverrideRecord.self)
        entity.properties = [
            attribute("recordID", .stringAttributeType, isOptional: false, defaultValue: ""),
            attribute("seriesID", .UUIDAttributeType, isOptional: false, defaultValue: UUID()),
            attribute("occurrenceIndex", .integer64AttributeType, isOptional: false, defaultValue: 0),
            attribute("itemID", .UUIDAttributeType),
            attribute("title", .stringAttributeType),
            attribute("category", .stringAttributeType),
            attribute("detail", .stringAttributeType),
            attribute("startDate", .dateAttributeType),
            attribute("endDate", .dateAttributeType),
            attribute("completedAt", .dateAttributeType),
            attribute("isAllDay", .booleanAttributeType),
            attribute("deletionFlag", .booleanAttributeType, isOptional: false, defaultValue: false)
        ]
        return entity
    }

    private static func makeSubscriptionEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.subscription
        entity.managedObjectClassName = NSStringFromClass(DeadlineSubscriptionRecord.self)
        entity.properties = [
            attribute("id", .UUIDAttributeType, isOptional: false, defaultValue: UUID()),
            attribute("urlString", .stringAttributeType, isOptional: false, defaultValue: ""),
            attribute("category", .stringAttributeType, isOptional: false, defaultValue: ""),
            attribute("createdAt", .dateAttributeType, isOptional: false, defaultValue: Date(timeIntervalSinceReferenceDate: 0))
        ]
        return entity
    }

    private static func makeGroupEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.group
        entity.managedObjectClassName = NSStringFromClass(DeadlineGroupRecord.self)
        entity.properties = [
            attribute("name", .stringAttributeType, isOptional: false, defaultValue: ""),
            attribute("order", .integer64AttributeType, isOptional: false, defaultValue: 0)
        ]
        return entity
    }

    private static func makeSyncPreferenceEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.syncPreference
        entity.managedObjectClassName = NSStringFromClass(DeadlineSyncPreferenceRecord.self)
        entity.properties = [
            attribute("recordID", .stringAttributeType, isOptional: false, defaultValue: "sync_preferences"),
            attribute("languageRaw", .stringAttributeType),
            attribute("backgroundStyleRaw", .stringAttributeType)
        ]
        return entity
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        isOptional: Bool = true,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
