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
    var reminders: [DeadlineReminder]

    var id: UUID { seriesID }

    init(
        seriesID: UUID,
        seedItemID: UUID,
        title: String,
        category: String,
        detail: String,
        startDate: Date,
        endDate: Date,
        createdAt: Date,
        sourceKind: DeadlineItemSourceKind,
        subscriptionID: UUID? = nil,
        externalEventIdentifier: String? = nil,
        originalStartDateWasMissing: Bool = false,
        isAllDay: Bool = false,
        repeatRule: DeadlineRepeatRule,
        reminders: [DeadlineReminder] = []
    ) {
        self.seriesID = seriesID
        self.seedItemID = seedItemID
        self.title = title
        self.category = category
        self.detail = detail
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.sourceKind = sourceKind
        self.subscriptionID = subscriptionID
        self.externalEventIdentifier = externalEventIdentifier
        self.originalStartDateWasMissing = originalStartDateWasMissing
        self.isAllDay = isAllDay
        self.repeatRule = repeatRule
        self.reminders = reminders
    }

    private enum CodingKeys: String, CodingKey {
        case seriesID
        case seedItemID
        case title
        case category
        case detail
        case startDate
        case endDate
        case createdAt
        case sourceKind
        case subscriptionID
        case externalEventIdentifier
        case originalStartDateWasMissing
        case isAllDay
        case repeatRule
        case reminders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seriesID = try container.decode(UUID.self, forKey: .seriesID)
        seedItemID = try container.decode(UUID.self, forKey: .seedItemID)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(String.self, forKey: .category)
        detail = try container.decode(String.self, forKey: .detail)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        sourceKind = try container.decodeIfPresent(DeadlineItemSourceKind.self, forKey: .sourceKind) ?? .manual
        subscriptionID = try container.decodeIfPresent(UUID.self, forKey: .subscriptionID)
        externalEventIdentifier = try container.decodeIfPresent(String.self, forKey: .externalEventIdentifier)
        originalStartDateWasMissing = try container.decodeIfPresent(Bool.self, forKey: .originalStartDateWasMissing) ?? false
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        repeatRule = try container.decode(DeadlineRepeatRule.self, forKey: .repeatRule)
        reminders = try container.decodeIfPresent([DeadlineReminder].self, forKey: .reminders) ?? []
    }
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
    var reminders: [DeadlineReminder]? = nil
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
        reminders == nil &&
        isDeleted == false
    }

    private enum CodingKeys: String, CodingKey {
        case seriesID
        case occurrenceIndex
        case itemID
        case title
        case category
        case detail
        case startDate
        case endDate
        case completedAt
        case isAllDay
        case reminders
        case isDeleted
    }

    init(
        seriesID: UUID,
        occurrenceIndex: Int,
        itemID: UUID? = nil,
        title: String? = nil,
        category: String? = nil,
        detail: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        completedAt: Date? = nil,
        isAllDay: Bool? = nil,
        reminders: [DeadlineReminder]? = nil,
        isDeleted: Bool = false
    ) {
        self.seriesID = seriesID
        self.occurrenceIndex = occurrenceIndex
        self.itemID = itemID
        self.title = title
        self.category = category
        self.detail = detail
        self.startDate = startDate
        self.endDate = endDate
        self.completedAt = completedAt
        self.isAllDay = isAllDay
        self.reminders = reminders
        self.isDeleted = isDeleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seriesID = try container.decode(UUID.self, forKey: .seriesID)
        occurrenceIndex = try container.decode(Int.self, forKey: .occurrenceIndex)
        itemID = try container.decodeIfPresent(UUID.self, forKey: .itemID)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay)
        reminders = try container.decodeIfPresent([DeadlineReminder].self, forKey: .reminders)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
}

struct DeadlinePersistedState: Codable, Hashable {
    var schemaVersion: Int
    var standaloneItems: [DeadlineItem]
    var legacyRecurringItems: [DeadlineItem]
    var recurringSeries: [DeadlineRecurringSeries]
    var recurringOverrides: [DeadlineRecurringOverride]

    init(
        schemaVersion: Int = 3,
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
