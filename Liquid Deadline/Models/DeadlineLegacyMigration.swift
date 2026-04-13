import Foundation

enum DeadlineLegacyMigration {
    enum OccurrenceOverrideField: String, Hashable {
        case title
        case category
        case detail
        case startDate
        case endDate
        case completedAt
        case isAllDay
        case reminders
        case missingOccurrence
    }

    struct OccurrenceOverride: Identifiable, Hashable {
        let seriesID: UUID
        let occurrenceIndex: Int
        let modifiedFields: Set<OccurrenceOverrideField>

        var id: String {
            "\(seriesID.uuidString)#\(occurrenceIndex)"
        }
    }

    struct RecurringSeriesPlan: Identifiable, Hashable {
        let seriesID: UUID
        let seedItem: DeadlineItem
        let occurrenceCount: Int
        let overrides: [OccurrenceOverride]

        var id: UUID {
            seriesID
        }
    }

    struct Report: Hashable {
        let recurringSeriesPlans: [RecurringSeriesPlan]
        let standaloneItemIDs: [UUID]
        let subscriptionItemIDs: [UUID]
        let unconvertibleItemIDs: [UUID]
    }

    struct MigrationResult: Hashable {
        let state: DeadlinePersistedState
        let report: Report
    }

    static func normalizeDecodedItems(_ items: [DeadlineItem]) -> [DeadlineItem] {
        let canonicalItems = deduplicatedSubscriptionItems(
            items.map { item in
                var normalized = item
                if normalized.subscriptionID != nil {
                    normalized.sourceKind = .subscribedURL
                }
                return normalized
            }
        )

        var seenIDs = Set<UUID>()

        return canonicalItems.map { item in
            var normalized = item

            while seenIDs.contains(normalized.id) {
                normalized.id = UUID()
            }

            seenIDs.insert(normalized.id)
            return normalized
        }
    }

    private static func deduplicatedSubscriptionItems(_ items: [DeadlineItem]) -> [DeadlineItem] {
        var result: [DeadlineItem] = []
        var subscriptionIndexByKey: [String: Int] = [:]

        for item in items {
            guard
                let subscriptionID = item.subscriptionID,
                let externalEventIdentifier = item.externalEventIdentifier,
                externalEventIdentifier.isEmpty == false
            else {
                result.append(item)
                continue
            }

            let key = "\(subscriptionID.uuidString)#\(externalEventIdentifier)"
            if let existingIndex = subscriptionIndexByKey[key] {
                result[existingIndex] = mergeSubscriptionDuplicate(
                    current: result[existingIndex],
                    incoming: item
                )
                continue
            }

            subscriptionIndexByKey[key] = result.count
            result.append(item)
        }

        return result
    }

    private static func mergeSubscriptionDuplicate(
        current: DeadlineItem,
        incoming: DeadlineItem
    ) -> DeadlineItem {
        var preferred = subscriptionDuplicateRank(incoming) >= subscriptionDuplicateRank(current)
            ? incoming
            : current
        let secondary = preferred.id == current.id ? incoming : current

        preferred.sourceKind = .subscribedURL
        preferred.subscriptionID = preferred.subscriptionID ?? secondary.subscriptionID
        preferred.externalEventIdentifier = preferred.externalEventIdentifier ?? secondary.externalEventIdentifier
        preferred.completedAt = preferred.completedAt ?? secondary.completedAt
        preferred.createdAt = min(preferred.createdAt, secondary.createdAt)
        preferred.originalStartDateWasMissing = preferred.originalStartDateWasMissing || secondary.originalStartDateWasMissing
        if preferred.reminders.isEmpty {
            preferred.reminders = secondary.reminders
        }
        return preferred
    }

    private static func subscriptionDuplicateRank(_ item: DeadlineItem) -> Int {
        var score = 0
        if item.sourceKind == .subscribedURL {
            score += 4
        }
        if item.subscriptionID != nil {
            score += 2
        }
        if item.externalEventIdentifier?.isEmpty == false {
            score += 1
        }
        return score
    }

    static func buildReport(from items: [DeadlineItem]) -> Report {
        migrateLegacyItems(items).report
    }

    static func migrateLegacyItems(_ items: [DeadlineItem]) -> MigrationResult {
        let normalizedItems = normalizeDecodedItems(items)

        let standaloneItems = normalizedItems.filter {
            $0.belongsToRepeatSeries == false
        }
        let standaloneItemIDs = standaloneItems
            .filter { $0.sourceKind != .subscribedURL }
            .map(\.id)

        let subscriptionItemIDs = standaloneItems
            .filter { $0.sourceKind == .subscribedURL }
            .map(\.id)

        let groupedSeries = Dictionary(grouping: normalizedItems.filter {
            $0.belongsToRepeatSeries
        }) { item in
            item.repeatSeriesID ?? UUID()
        }

        var plans: [RecurringSeriesPlan] = []
        var migratedRecurringSeries: [DeadlineRecurringSeries] = []
        var migratedRecurringOverrides: [DeadlineRecurringOverride] = []
        var legacyRecurringItems: [DeadlineItem] = []

        for (_, seriesItems) in groupedSeries {
            guard let migration = migrateRecurringSeries(from: seriesItems) else {
                legacyRecurringItems.append(contentsOf: seriesItems)
                continue
            }

            plans.append(migration.plan)
            migratedRecurringSeries.append(migration.series)
            migratedRecurringOverrides.append(contentsOf: migration.overrides)
        }

        plans.sort { lhs, rhs in
            lhs.seedItem.createdAt < rhs.seedItem.createdAt
        }

        let report = Report(
            recurringSeriesPlans: plans,
            standaloneItemIDs: standaloneItemIDs,
            subscriptionItemIDs: subscriptionItemIDs,
            unconvertibleItemIDs: legacyRecurringItems.map(\.id).sorted { $0.uuidString < $1.uuidString }
        )

        let state = DeadlinePersistedState(
            standaloneItems: standaloneItems,
            legacyRecurringItems: legacyRecurringItems.sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.startDate < rhs.startDate
            },
            recurringSeries: migratedRecurringSeries.sorted { lhs, rhs in
                lhs.createdAt < rhs.createdAt
            },
            recurringOverrides: migratedRecurringOverrides.sorted { lhs, rhs in
                if lhs.seriesID == rhs.seriesID {
                    return lhs.occurrenceIndex < rhs.occurrenceIndex
                }
                return lhs.seriesID.uuidString < rhs.seriesID.uuidString
            }
        )

        return MigrationResult(state: state, report: report)
    }

    private static func migrateRecurringSeries(
        from seriesItems: [DeadlineItem]
    ) -> (series: DeadlineRecurringSeries, overrides: [DeadlineRecurringOverride], plan: RecurringSeriesPlan)? {
        let seeds = seriesItems.filter { $0.repeatRule != nil }
        guard seeds.count == 1, let seed = seeds.first else { return nil }
        guard let seriesID = seed.repeatSeriesID else { return nil }
        guard seed.repeatOccurrenceIndex == 0, let repeatRule = seed.repeatRule else { return nil }

        let sortedItems = seriesItems.sorted { lhs, rhs in
            lhs.repeatOccurrenceIndex < rhs.repeatOccurrenceIndex
        }

        var itemsByOccurrenceIndex: [Int: DeadlineItem] = [:]
        for item in sortedItems {
            if itemsByOccurrenceIndex[item.repeatOccurrenceIndex] != nil {
                return nil
            }
            itemsByOccurrenceIndex[item.repeatOccurrenceIndex] = item
        }

        let maxOccurrenceIndex = sortedItems.map(\.repeatOccurrenceIndex).max() ?? 0
        var overrides: [DeadlineRecurringOverride] = []
        var reportOverrides: [OccurrenceOverride] = []

        if seed.completedAt != nil {
            overrides.append(
                DeadlineRecurringOverride(
                    seriesID: seriesID,
                    occurrenceIndex: 0,
                    itemID: seed.id,
                    completedAt: seed.completedAt,
                    isDeleted: false
                )
            )
            reportOverrides.append(
                OccurrenceOverride(
                    seriesID: seriesID,
                    occurrenceIndex: 0,
                    modifiedFields: [.completedAt]
                )
            )
        }

        if maxOccurrenceIndex > 0 {
            for occurrenceIndex in 1...maxOccurrenceIndex {
                guard let expectedItem = expectedRecurringItem(for: seed, occurrenceIndex: occurrenceIndex) else {
                    return nil
                }

                guard let actualItem = itemsByOccurrenceIndex[occurrenceIndex] else {
                    overrides.append(
                        DeadlineRecurringOverride(
                            seriesID: seriesID,
                            occurrenceIndex: occurrenceIndex,
                            isDeleted: true
                        )
                    )
                    reportOverrides.append(
                        OccurrenceOverride(
                            seriesID: seriesID,
                            occurrenceIndex: occurrenceIndex,
                            modifiedFields: [.missingOccurrence]
                        )
                    )
                    continue
                }

                let modifiedFields = modifiedFields(in: actualItem, comparedTo: expectedItem)
                if modifiedFields.isEmpty == false {
                    overrides.append(
                        makeOverride(
                            seriesID: seriesID,
                            occurrenceIndex: occurrenceIndex,
                            actualItem: actualItem,
                            modifiedFields: modifiedFields
                        )
                    )
                    reportOverrides.append(
                        OccurrenceOverride(
                            seriesID: seriesID,
                            occurrenceIndex: occurrenceIndex,
                            modifiedFields: modifiedFields
                        )
                    )
                }
            }
        }

        let series = DeadlineRecurringSeries(
            seriesID: seriesID,
            seedItemID: seed.id,
            title: seed.title,
            category: seed.category,
            detail: seed.detail,
            startDate: seed.startDate,
            endDate: seed.endDate,
            createdAt: seed.createdAt,
            sourceKind: seed.sourceKind,
            subscriptionID: seed.subscriptionID,
            externalEventIdentifier: seed.externalEventIdentifier,
            originalStartDateWasMissing: seed.originalStartDateWasMissing,
            isAllDay: seed.isAllDay,
            repeatRule: repeatRule,
            reminders: seed.reminders
        )

        let plan = RecurringSeriesPlan(
            seriesID: seriesID,
            seedItem: seed,
            occurrenceCount: maxOccurrenceIndex + 1,
            overrides: reportOverrides
        )

        return (series: series, overrides: overrides, plan: plan)
    }

    private static func makeOverride(
        seriesID: UUID,
        occurrenceIndex: Int,
        actualItem: DeadlineItem,
        modifiedFields: Set<OccurrenceOverrideField>
    ) -> DeadlineRecurringOverride {
        DeadlineRecurringOverride(
            seriesID: seriesID,
            occurrenceIndex: occurrenceIndex,
            itemID: actualItem.id,
            title: modifiedFields.contains(.title) ? actualItem.title : nil,
            category: modifiedFields.contains(.category) ? actualItem.category : nil,
            detail: modifiedFields.contains(.detail) ? actualItem.detail : nil,
            startDate: modifiedFields.contains(.startDate) ? actualItem.startDate : nil,
            endDate: modifiedFields.contains(.endDate) ? actualItem.endDate : nil,
            completedAt: modifiedFields.contains(.completedAt) ? actualItem.completedAt : nil,
            isAllDay: modifiedFields.contains(.isAllDay) ? actualItem.isAllDay : nil,
            reminders: modifiedFields.contains(.reminders) ? actualItem.reminders : nil,
            isDeleted: false
        )
    }

    private static func expectedRecurringItem(for seed: DeadlineItem, occurrenceIndex: Int) -> DeadlineItem? {
        guard occurrenceIndex >= 0 else { return nil }
        guard let repeatRule = seed.repeatRule else { return nil }

        let duration = seed.endDate.timeIntervalSince(seed.startDate)
        var expectedStartDate = seed.startDate

        if occurrenceIndex > 0 {
            for _ in 0..<occurrenceIndex {
                guard let nextDate = repeatRule.nextDate(after: expectedStartDate) else { return nil }
                if let endDate = repeatRule.endDate, nextDate > endDate {
                    return nil
                }
                expectedStartDate = nextDate
            }
        }

        return DeadlineItem(
            id: seed.id,
            title: seed.title,
            category: seed.category,
            detail: seed.detail,
            startDate: expectedStartDate,
            endDate: expectedStartDate.addingTimeInterval(duration),
            completedAt: nil,
            createdAt: seed.createdAt,
            sourceKind: seed.sourceKind,
            subscriptionID: seed.subscriptionID,
            externalEventIdentifier: seed.externalEventIdentifier,
            originalStartDateWasMissing: seed.originalStartDateWasMissing,
            isAllDay: seed.isAllDay,
            repeatSeriesID: seed.repeatSeriesID,
            repeatOccurrenceIndex: occurrenceIndex,
            repeatRule: occurrenceIndex == 0 ? seed.repeatRule : nil,
            reminders: seed.reminders
        )
    }

    private static func modifiedFields(
        in actualItem: DeadlineItem,
        comparedTo expectedItem: DeadlineItem
    ) -> Set<OccurrenceOverrideField> {
        var fields = Set<OccurrenceOverrideField>()

        if actualItem.title != expectedItem.title {
            fields.insert(.title)
        }
        if actualItem.category != expectedItem.category {
            fields.insert(.category)
        }
        if actualItem.detail != expectedItem.detail {
            fields.insert(.detail)
        }
        if actualItem.startDate != expectedItem.startDate {
            fields.insert(.startDate)
        }
        if actualItem.endDate != expectedItem.endDate {
            fields.insert(.endDate)
        }
        if actualItem.completedAt != expectedItem.completedAt {
            fields.insert(.completedAt)
        }
        if actualItem.isAllDay != expectedItem.isAllDay {
            fields.insert(.isAllDay)
        }
        if actualItem.reminders != expectedItem.reminders {
            fields.insert(.reminders)
        }

        return fields
    }
}
