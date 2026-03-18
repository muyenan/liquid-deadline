import Foundation

enum DeadlineEditConflictField: Hashable {
    case title
    case category
    case detail
    case startDate
    case endDate
}

struct DeadlineEditConflict: Hashable, Identifiable {
    let id = UUID()
    let currentItem: DeadlineItem
    let proposedTitle: String
    let proposedCategory: String
    let proposedDetail: String
    let proposedStartDate: Date
    let proposedEndDate: Date
    let scope: DeadlineRecurringChangeScope
    let fields: [DeadlineEditConflictField]
}

enum DeadlineEditSaveResult: Hashable {
    case saved
    case conflict(DeadlineEditConflict)
}
