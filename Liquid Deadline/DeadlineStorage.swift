import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum DeadlineStorage {
    static let appGroupID = "group.name.qianmo.LiquidDeadline"
    static let cloudKitContainerIdentifierInfoKey = "DeadlineCloudKitContainerIdentifier"
    static let languageSelectionKey = "deadline_oil_language_selection_v1"
    static let itemsStorageKey = "deadline_oil_items_v1"
    static let compactStateStorageKey = "deadline_oil_compact_state_v1"
    static let syncOptionsStorageKey = "deadline_oil_sync_options_v1"
    static let viewStyleStorageKey = "deadline_oil_view_style_v1"
    static let sortOptionStorageKey = "deadline_oil_sort_option_v1"
    static let selectedFilterGroupStorageKey = "deadline_oil_selected_filter_group_v1"
    static let groupsStorageKey = "deadline_oil_groups_v1"
    static let backgroundStyleStorageKey = "deadline_oil_background_style_v1"
    static let liquidMotionEnabledStorageKey = "deadline_oil_liquid_motion_enabled_v1"
    static let subscriptionsStorageKey = "deadline_oil_subscriptions_v1"
    static let subscriptionLocalStateStorageKey = "deadline_oil_subscription_local_state_v1"
    static let lastSubscriptionRefreshStorageKey = "deadline_oil_last_subscription_refresh_v1"
    static let cloudAccountFingerprintStorageKey = "deadline_oil_cloud_account_fingerprint_v1"

    static let sharedDefaults: UserDefaults = {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }()

    static var cloudKitContainerIdentifier: String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: cloudKitContainerIdentifierInfoKey) as? String,
           value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return value
        }
        return "iCloud.name.qianmo.LiquidDeadline"
    }

    private static let migrationFlagKey = "deadline_oil_shared_defaults_migrated_v1"
    private static let migratableKeys = [
        languageSelectionKey,
        itemsStorageKey,
        compactStateStorageKey,
        syncOptionsStorageKey,
        viewStyleStorageKey,
        sortOptionStorageKey,
        selectedFilterGroupStorageKey,
        groupsStorageKey,
        backgroundStyleStorageKey,
        liquidMotionEnabledStorageKey,
        subscriptionsStorageKey,
        subscriptionLocalStateStorageKey,
        lastSubscriptionRefreshStorageKey,
        cloudAccountFingerprintStorageKey
    ]

    static func migrateStandardDefaultsIfNeeded() {
        let standardDefaults = UserDefaults.standard

        guard sharedDefaults != standardDefaults else { return }
        guard sharedDefaults.bool(forKey: migrationFlagKey) == false else { return }

        for key in migratableKeys {
            guard let value = standardDefaults.object(forKey: key) else { continue }
            sharedDefaults.set(value, forKey: key)
        }

        sharedDefaults.set(true, forKey: migrationFlagKey)
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func persistentStoreURL() -> URL {
        let baseURL: URL
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            baseURL = appGroupURL
        } else {
            baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }

        let directoryURL = baseURL.appendingPathComponent("Persistence", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        return directoryURL.appendingPathComponent("LiquidDeadline.sqlite")
    }
}
