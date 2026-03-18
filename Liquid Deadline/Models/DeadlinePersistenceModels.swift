import CryptoKit
import Foundation

struct DeadlineRecurringSeries: Identifiable, Codable, Hashable {
    var seriesID: UUID
    var seedItemID: UUID
    var title: String
    var category: String
    var detail: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var sourceKind: DeadlineItemSourceKind
    var subscriptionID: UUID?
    var externalEventIdentifier: String?
    var originalStartDateWasMissing: Bool
    var isAllDay: Bool
    var repeatRule: DeadlineRepeatRule

    var id: UUID { seriesID }
}

struct DeadlineRecurringOverride: Identifiable, Codable, Hashable {
    var seriesID: UUID
    var occurrenceIndex: Int
    var itemID: UUID? = nil
    var title: String? = nil
    var category: String? = nil
    var detail: String? = nil
    var startDate: Date? = nil
    var endDate: Date? = nil
    var completedAt: Date? = nil
    var isAllDay: Bool? = nil
    var isDeleted: Bool = false

    var id: String {
        "\(seriesID.uuidString)#\(occurrenceIndex)"
    }

    var isEmpty: Bool {
        itemID == nil &&
        title == nil &&
        category == nil &&
        detail == nil &&
        startDate == nil &&
        endDate == nil &&
        completedAt == nil &&
        isAllDay == nil &&
        isDeleted == false
    }
}

struct DeadlinePersistedState: Codable, Hashable {
    var schemaVersion: Int
    var standaloneItems: [DeadlineItem]
    var legacyRecurringItems: [DeadlineItem]
    var recurringSeries: [DeadlineRecurringSeries]
    var recurringOverrides: [DeadlineRecurringOverride]

    init(
        schemaVersion: Int = 2,
        standaloneItems: [DeadlineItem] = [],
        legacyRecurringItems: [DeadlineItem] = [],
        recurringSeries: [DeadlineRecurringSeries] = [],
        recurringOverrides: [DeadlineRecurringOverride] = []
    ) {
        self.schemaVersion = schemaVersion
        self.standaloneItems = standaloneItems
        self.legacyRecurringItems = legacyRecurringItems
        self.recurringSeries = recurringSeries
        self.recurringOverrides = recurringOverrides
    }

    func removingDerivedSubscriptionData() -> DeadlinePersistedState {
        let filteredSeries = recurringSeries.filter { $0.subscriptionID == nil && $0.sourceKind != .subscribedURL }
        let validSeriesIDs = Set(filteredSeries.map(\.seriesID))

        return DeadlinePersistedState(
            schemaVersion: schemaVersion,
            standaloneItems: standaloneItems.filter { $0.subscriptionID == nil && $0.sourceKind != .subscribedURL },
            legacyRecurringItems: legacyRecurringItems.filter { $0.subscriptionID == nil && $0.sourceKind != .subscribedURL },
            recurringSeries: filteredSeries,
            recurringOverrides: recurringOverrides.filter { validSeriesIDs.contains($0.seriesID) }
        )
    }
}

enum DeadlineRecurringIdentity {
    static func itemID(seriesID: UUID, occurrenceIndex: Int) -> UUID {
        var bytes = [UInt8]()
        let uuid = seriesID.uuid
        bytes.append(contentsOf: [
            uuid.0, uuid.1, uuid.2, uuid.3,
            uuid.4, uuid.5, uuid.6, uuid.7,
            uuid.8, uuid.9, uuid.10, uuid.11,
            uuid.12, uuid.13, uuid.14, uuid.15
        ])

        var encodedIndex = Int64(occurrenceIndex).bigEndian
        withUnsafeBytes(of: &encodedIndex) { rawBuffer in
            bytes.append(contentsOf: rawBuffer)
        }

        let digest = SHA256.hash(data: Data(bytes))
        var digestBytes = Array(digest.prefix(16))
        digestBytes[6] = (digestBytes[6] & 0x0F) | 0x50
        digestBytes[8] = (digestBytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            digestBytes[0], digestBytes[1], digestBytes[2], digestBytes[3],
            digestBytes[4], digestBytes[5], digestBytes[6], digestBytes[7],
            digestBytes[8], digestBytes[9], digestBytes[10], digestBytes[11],
            digestBytes[12], digestBytes[13], digestBytes[14], digestBytes[15]
        ))
    }
}
