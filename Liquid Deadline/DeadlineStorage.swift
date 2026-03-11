import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum DeadlineStorage {
    static let appGroupID = "group.name.qianmo.LiquidDeadline"
    static let languageSelectionKey = "deadline_oil_language_selection_v1"
    static let itemsStorageKey = "deadline_oil_items_v1"
    static let viewStyleStorageKey = "deadline_oil_view_style_v1"
    static let sortOptionStorageKey = "deadline_oil_sort_option_v1"
    static let selectedFilterGroupStorageKey = "deadline_oil_selected_filter_group_v1"
    static let groupsStorageKey = "deadline_oil_groups_v1"
    static let backgroundStyleStorageKey = "deadline_oil_background_style_v1"
    static let liquidMotionEnabledStorageKey = "deadline_oil_liquid_motion_enabled_v1"

    static let sharedDefaults: UserDefaults = {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }()

    private static let migrationFlagKey = "deadline_oil_shared_defaults_migrated_v1"
    private static let migratableKeys = [
        languageSelectionKey,
        itemsStorageKey,
        viewStyleStorageKey,
        sortOptionStorageKey,
        selectedFilterGroupStorageKey,
        groupsStorageKey,
        backgroundStyleStorageKey,
        liquidMotionEnabledStorageKey
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
}
