import Foundation

struct DeadlineSyncOptions: Codable, Hashable {
    var automaticSyncEnabled: Bool
    var syncLanguage: Bool
    var syncBackgroundStyle: Bool
    var syncGroups: Bool
    var syncTasks: Bool
    var syncSubscriptions: Bool

    static let `default` = DeadlineSyncOptions(
        automaticSyncEnabled: true,
        syncLanguage: false,
        syncBackgroundStyle: false,
        syncGroups: true,
        syncTasks: true,
        syncSubscriptions: true
    )

    mutating func setAutomaticSyncEnabled(_ isEnabled: Bool) {
        automaticSyncEnabled = isEnabled
    }

    mutating func setSyncLanguage(_ isEnabled: Bool) {
        syncLanguage = isEnabled
    }

    mutating func setSyncBackgroundStyle(_ isEnabled: Bool) {
        syncBackgroundStyle = isEnabled
    }

    mutating func setSyncGroups(_ isEnabled: Bool) {
        syncGroups = isEnabled
        if isEnabled == false {
            syncTasks = false
            syncSubscriptions = false
        }
    }

    mutating func setSyncTasks(_ isEnabled: Bool) {
        syncTasks = isEnabled
        if isEnabled {
            syncGroups = true
        }
    }

    mutating func setSyncSubscriptions(_ isEnabled: Bool) {
        syncSubscriptions = isEnabled
        if isEnabled {
            syncGroups = true
        }
    }
}
