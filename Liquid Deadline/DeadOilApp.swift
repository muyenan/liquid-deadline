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
    case japanese
    case korean
    case spanishSpain
    case spanishMexico
    case french
    case german
    case thai
    case vietnamese
    case indonesian
    case russian

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en")
        case .chinese:
            return Locale(identifier: "zh-Hans")
        case .japanese:
            return Locale(identifier: "ja")
        case .korean:
            return Locale(identifier: "ko")
        case .spanishSpain:
            return Locale(identifier: "es-ES")
        case .spanishMexico:
            return Locale(identifier: "es-MX")
        case .french:
            return Locale(identifier: "fr")
        case .german:
            return Locale(identifier: "de")
        case .thai:
            return Locale(identifier: "th")
        case .vietnamese:
            return Locale(identifier: "vi")
        case .indonesian:
            return Locale(identifier: "id")
        case .russian:
            return Locale(identifier: "ru")
        }
    }

    func title(in language: AppLanguage) -> String {
        _ = language
        return displayName
    }

    static func detectFromSystem() -> AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferredLanguage.hasPrefix("zh") {
            return .chinese
        }
        if preferredLanguage.hasPrefix("ja") {
            return .japanese
        }
        if preferredLanguage.hasPrefix("ko") {
            return .korean
        }
        if preferredLanguage.hasPrefix("es-mx") {
            return .spanishMexico
        }
        if preferredLanguage.hasPrefix("es") {
            return .spanishSpain
        }
        if preferredLanguage.hasPrefix("fr") {
            return .french
        }
        if preferredLanguage.hasPrefix("de") {
            return .german
        }
        if preferredLanguage.hasPrefix("th") {
            return .thai
        }
        if preferredLanguage.hasPrefix("vi") {
            return .vietnamese
        }
        if preferredLanguage.hasPrefix("ru") {
            return .russian
        }
        if preferredLanguage.hasPrefix("id") || preferredLanguage.hasPrefix("in") {
            return .indonesian
        }
        return .english
    }

    func text(_ english: String, _ chinese: String) -> String {
        localizedText(english, chinese: chinese)
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
    @State private var foregroundRefreshTask: Task<Void, Never>?
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
            startForegroundRefreshLoop()
            store.extendRecurringItemsIfNeeded(at: .now)
            Task {
                await store.refreshCloudAccountStatusIfNeeded()
                await store.refreshCloudDataIfNeeded(now: .now)
                await store.refreshSubscriptionsIfNeeded(now: .now)
            }
        case .background:
            stopForegroundRefreshLoop()
            SubscriptionRefreshScheduler.scheduleNextRefresh()
        case .inactive:
            stopForegroundRefreshLoop()
            break
        @unknown default:
            stopForegroundRefreshLoop()
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

    private func startForegroundRefreshLoop() {
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = Task {
            while Task.isCancelled == false {
                try? await Task.sleep(
                    nanoseconds: UInt64(DeadlineStore.foregroundRefreshPollInterval * 1_000_000_000)
                )
                guard Task.isCancelled == false else { return }
                await store.refreshCloudDataIfNeeded(now: .now)
                await store.refreshSubscriptionsIfNeeded(now: .now)
            }
        }
    }

    private func stopForegroundRefreshLoop() {
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = nil
    }
}
