import CoreData
import Foundation

enum DeadlineTaskStorageKind: String {
    case standalone
    case legacyRecurring
}

@objc(DeadlineTaskRecord)
final class DeadlineTaskRecord: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var category: String
    @NSManaged var detail: String
    @NSManaged var startDate: Date
    @NSManaged var endDate: Date
    @NSManaged var completedAt: Date?
    @NSManaged var createdAt: Date
    @NSManaged var sourceKindRaw: String
    @NSManaged var subscriptionID: UUID?
    @NSManaged var externalEventIdentifier: String?
    @NSManaged var originalStartDateWasMissing: Bool
    @NSManaged var isAllDay: Bool
    @NSManaged var repeatSeriesID: UUID?
    @NSManaged var repeatOccurrenceIndex: Int64
    @NSManaged var repeatRuleInterval: NSNumber?
    @NSManaged var repeatRuleUnitRaw: String?
    @NSManaged var repeatRuleEndDate: Date?
    @NSManaged var storageKindRaw: String
}

@objc(DeadlineRecurringSeriesRecord)
final class DeadlineRecurringSeriesRecord: NSManagedObject {
    @NSManaged var seriesID: UUID
    @NSManaged var seedItemID: UUID
    @NSManaged var title: String
    @NSManaged var category: String
    @NSManaged var detail: String
    @NSManaged var startDate: Date
    @NSManaged var endDate: Date
    @NSManaged var createdAt: Date
    @NSManaged var sourceKindRaw: String
    @NSManaged var subscriptionID: UUID?
    @NSManaged var externalEventIdentifier: String?
    @NSManaged var originalStartDateWasMissing: Bool
    @NSManaged var isAllDay: Bool
    @NSManaged var repeatRuleInterval: Int64
    @NSManaged var repeatRuleUnitRaw: String
    @NSManaged var repeatRuleEndDate: Date?
}

@objc(DeadlineRecurringOverrideRecord)
final class DeadlineRecurringOverrideRecord: NSManagedObject {
    @NSManaged var recordID: String
    @NSManaged var seriesID: UUID
    @NSManaged var occurrenceIndex: Int64
    @NSManaged var itemID: UUID?
    @NSManaged var title: String?
    @NSManaged var category: String?
    @NSManaged var detail: String?
    @NSManaged var startDate: Date?
    @NSManaged var endDate: Date?
    @NSManaged var completedAt: Date?
    @NSManaged var isAllDay: NSNumber?
    @NSManaged var deletionFlag: Bool
}

@objc(DeadlineSubscriptionRecord)
final class DeadlineSubscriptionRecord: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var urlString: String
    @NSManaged var category: String
    @NSManaged var createdAt: Date
}

@objc(DeadlineGroupRecord)
final class DeadlineGroupRecord: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var order: Int64
}

@objc(DeadlineSyncPreferenceRecord)
final class DeadlineSyncPreferenceRecord: NSManagedObject {
    @NSManaged var recordID: String
    @NSManaged var languageRaw: String?
    @NSManaged var backgroundStyleRaw: String?
}
