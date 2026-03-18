//
//  DeadOilApp.swift
//  DeadOil
//
//  Created by 黔陌 on 2/13/26.
//

import BackgroundTasks
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english
    case chinese

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en")
        case .chinese:
            return Locale(identifier: "zh-Hans")
        }
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .english:
            return language.text("English", "英文")
        case .chinese:
            return language.text("Chinese", "中文")
        }
    }

    static func detectFromSystem() -> AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("zh") ? .chinese : .english
    }

    func text(_ english: String, _ chinese: String) -> String {
        self == .chinese ? chinese : english
    }
}

@MainActor
final class LanguageManager: ObservableObject {
    @Published private(set) var currentLanguage: AppLanguage

    var locale: Locale { currentLanguage.locale }

    private let defaults = DeadlineStorage.sharedDefaults
    private let storageKey = DeadlineStorage.languageSelectionKey
    private var followsSystemLanguage = false
    private var localeChangeCancellable: AnyCancellable?

    init() {
        DeadlineStorage.migrateStandardDefaultsIfNeeded()

        let storedRaw = defaults.string(forKey: storageKey)
        if let storedLanguage = AppLanguage(rawValue: storedRaw ?? "") {
            currentLanguage = storedLanguage
            followsSystemLanguage = false
        } else {
            currentLanguage = AppLanguage.detectFromSystem()
            followsSystemLanguage = true
        }

        localeChangeCancellable = NotificationCenter.default
            .publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.followsSystemLanguage else { return }
                self.refreshCurrentLanguageFromSystem()
            }
    }

    func setLanguage(_ language: AppLanguage) {
        followsSystemLanguage = false
        defaults.set(language.rawValue, forKey: storageKey)
        if currentLanguage != language {
            currentLanguage = language
        }
        DeadlineStorage.reloadWidgets()
    }

    func applySyncedLanguage(_ language: AppLanguage) {
        followsSystemLanguage = false
        defaults.set(language.rawValue, forKey: storageKey)
        if currentLanguage != language {
            currentLanguage = language
        }
        DeadlineStorage.reloadWidgets()
    }

    private func refreshCurrentLanguageFromSystem() {
        let detected = AppLanguage.detectFromSystem()
        if currentLanguage != detected {
            currentLanguage = detected
            DeadlineStorage.reloadWidgets()
        }
    }
}

@main
struct DeadOilApp: App {
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var store = DeadlineStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.locale)
                .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .backgroundTask(.appRefresh(SubscriptionRefreshScheduler.identifier)) {
            await handleBackgroundRefresh()
        }
    }

    private func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            store.extendRecurringItemsIfNeeded(at: .now)
            Task {
                await store.refreshCloudAccountStatusIfNeeded()
                await store.refreshSubscriptionsIfNeeded(now: .now)
            }
        case .background:
            SubscriptionRefreshScheduler.scheduleNextRefresh()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func handleBackgroundRefresh() async {
        await MainActor.run {
            store.extendRecurringItemsIfNeeded(at: .now)
        }
        await store.refreshSubscriptions(force: true, now: .now)
        SubscriptionRefreshScheduler.scheduleNextRefresh()
    }
}
