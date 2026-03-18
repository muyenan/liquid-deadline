import Foundation

struct DeadlineSubscriptionLocalState: Codable, Hashable {
    var lastSyncedAt: Date?
    var lastAttemptedAt: Date?
    var lastErrorMessage: String?
}

