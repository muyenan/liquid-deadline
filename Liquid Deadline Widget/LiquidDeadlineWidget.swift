import AppIntents
import SwiftUI
import WidgetKit

enum WidgetSharedDefaults {
    static let appGroupID = "group.name.qianmo.DeadOil"
    static let itemsStorageKey = "deadline_oil_items_v1"
    static let groupsStorageKey = "deadline_oil_groups_v1"
    static let languageSelectionKey = "deadline_oil_language_selection_v1"
}

enum WidgetLanguage: String {
    case english
    case chinese

    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en")
        case .chinese:
            return Locale(identifier: "zh-Hans")
        }
    }

    static func current() -> WidgetLanguage {
        let defaults = UserDefaults(suiteName: WidgetSharedDefaults.appGroupID) ?? .standard
        if let stored = defaults.string(forKey: WidgetSharedDefaults.languageSelectionKey),
           let language = WidgetLanguage(rawValue: stored) {
            return language
        }

        // Match the main app: if no explicit language has been saved yet,
        // follow the current system language.
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("zh") ? .chinese : .english
    }

    static func systemCurrent() -> WidgetLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("zh") ? .chinese : .english
    }

    func text(_ english: String, _ chinese: String) -> String {
        self == .chinese ? chinese : english
    }
}

private enum WidgetDeadlineSection {
    case notStarted
    case inProgress
    case completed
    case ended
}

private struct WidgetDeadlineItem: Decodable, Identifiable {
    let id: UUID
    let title: String
    let category: String
    let detail: String
    let startDate: Date
    let endDate: Date
    let completedAt: Date?
    let createdAt: Date

    func section(at now: Date) -> WidgetDeadlineSection {
        if completedAt != nil {
            return .completed
        }
        if now < startDate {
            return .notStarted
        }
        if now >= endDate {
            return .ended
        }
        return .inProgress
    }

    func progress(at now: Date) -> Double {
        let referenceDate = completedAt ?? now

        guard endDate > startDate else {
            return referenceDate >= endDate ? 1 : 0
        }
        if referenceDate <= startDate {
            return 0
        }
        if referenceDate >= endDate {
            return 1
        }

        let total = endDate.timeIntervalSince(startDate)
        let passed = referenceDate.timeIntervalSince(startDate)
        return min(max(passed / total, 0), 1)
    }

    func progressTint(at now: Date) -> Color {
        switch section(at: now) {
        case .notStarted:
            return .blue
        case .completed:
            return .green
        case .ended:
            return .gray
        case .inProgress:
            break
        }

        let value = progress(at: now)
        if value < 0.25 {
            return .green
        }
        if value < 0.75 {
            return .orange
        }
        return .red
    }
}

struct WidgetTaskSnapshot: Identifiable {
    let id: UUID
    let title: String
    let category: String
    let startDate: Date
    let endDate: Date
    let countdownTarget: Date
    let progress: Double
    let tint: Color
    let countdownTextEnglish: String
    let countdownTextChinese: String
}

struct LiquidDeadlineWidgetEntry: TimelineEntry {
    let date: Date
    let section: WidgetTaskSectionOption
    let category: WidgetCategoryEntity
    let sort: WidgetTaskSortOption
    let tasks: [WidgetTaskSnapshot]
    let language: WidgetLanguage
}

enum LockScreenDeadlineVariant {
    case inProgress
    case startingSoon

    var kind: String {
        switch self {
        case .inProgress:
            return "LiquidDeadlineLockScreenInProgressWidget"
        case .startingSoon:
            return "LiquidDeadlineLockScreenStartingSoonWidget"
        }
    }

    var section: WidgetTaskSectionOption {
        switch self {
        case .inProgress:
            return .inProgress
        case .startingSoon:
            return .notStarted
        }
    }

    var fallbackTint: Color {
        switch self {
        case .inProgress:
            return .orange
        case .startingSoon:
            return .blue
        }
    }

    func title(in language: WidgetLanguage) -> String {
        switch self {
        case .inProgress:
            return language.text("In Progress", "进行中")
        case .startingSoon:
            return language.text("Starting Soon", "将开始")
        }
    }

    var displayNameKey: LocalizedStringResource {
        switch self {
        case .inProgress:
            return "Lock Screen In Progress"
        case .startingSoon:
            return "Lock Screen Starting Soon"
        }
    }

    var descriptionKey: LocalizedStringResource {
        switch self {
        case .inProgress:
            return "Show the nearest in-progress task on the Lock Screen."
        case .startingSoon:
            return "Show the next task that will start soon on the Lock Screen."
        }
    }

    func emptyTitle(in language: WidgetLanguage) -> String {
        switch self {
        case .inProgress:
            return language.text("No active task", "暂无进行中任务")
        case .startingSoon:
            return language.text("No upcoming task", "暂无将开始任务")
        }
    }

    func emptySubtitle(in language: WidgetLanguage) -> String {
        language.text("Open the app to review.", "打开应用查看")
    }
}

struct LockScreenDeadlineEntry: TimelineEntry {
    let date: Date
    let variant: LockScreenDeadlineVariant
    let task: WidgetTaskSnapshot?
    let language: WidgetLanguage
}

private struct LiquidDeadlineWidgetRepository {
    private let defaults = UserDefaults(suiteName: WidgetSharedDefaults.appGroupID) ?? .standard

    func availableGroupNames(language: WidgetLanguage) -> [String] {
        let fallbackGroups = WidgetCategoryCatalog.builtInCategories.map { $0.displayName(in: language) }
        return (defaults.stringArray(forKey: WidgetSharedDefaults.groupsStorageKey) ?? fallbackGroups)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func loadTasks(
        section: WidgetTaskSectionOption,
        categoryID: String,
        sort: WidgetTaskSortOption,
        now: Date
    ) -> [WidgetTaskSnapshot] {
        guard
            let data = defaults.data(forKey: WidgetSharedDefaults.itemsStorageKey),
            let items = try? JSONDecoder().decode([WidgetDeadlineItem].self, from: data)
        else {
            return []
        }

        let resolvedSection = section == .automatic ? preferredSection(now: now) : section

        let filteredItems = items.filter { item in
            switch resolvedSection {
            case .notStarted:
                guard item.section(at: now) == .notStarted else { return false }
            case .inProgress:
                guard item.section(at: now) == .inProgress else { return false }
            case .automatic:
                return false
            }

            if categoryID == WidgetCategoryEntity.allIdentifier {
                return true
            }
            return WidgetCategoryCatalog.matches(itemCategory: item.category, selectedIdentifier: categoryID)
        }

        let sortedItems = filteredItems.sorted { lhs, rhs in
            switch sort {
            case .remainingTime:
                let lhsTarget = resolvedSection == .notStarted ? lhs.startDate : lhs.endDate
                let rhsTarget = resolvedSection == .notStarted ? rhs.startDate : rhs.endDate
                return lhsTarget < rhsTarget
            case .byDeadline:
                return lhs.endDate < rhs.endDate
            }
        }

        return sortedItems.map { item in
            let countdownTarget = resolvedSection == .notStarted ? item.startDate : item.endDate
            let countdownText = countdownText(
                for: countdownTarget,
                now: now,
                prefixEnglish: resolvedSection == .notStarted ? "Starts in" : "Remaining",
                prefixChinese: resolvedSection == .notStarted ? "距开始" : "剩余"
            )

            return WidgetTaskSnapshot(
                id: item.id,
                title: item.title,
                category: item.category,
                startDate: item.startDate,
                endDate: item.endDate,
                countdownTarget: countdownTarget,
                progress: item.progress(at: now),
                tint: item.progressTint(at: now),
                countdownTextEnglish: countdownText.english,
                countdownTextChinese: countdownText.chinese
            )
        }
    }

    func preferredSection(now: Date) -> WidgetTaskSectionOption {
        let inProgressTasks = loadTasks(
            section: .inProgress,
            categoryID: WidgetCategoryEntity.allIdentifier,
            sort: .remainingTime,
            now: now
        )
        if !inProgressTasks.isEmpty {
            return .inProgress
        }

        let notStartedTasks = loadTasks(
            section: .notStarted,
            categoryID: WidgetCategoryEntity.allIdentifier,
            sort: .remainingTime,
            now: now
        )
        if !notStartedTasks.isEmpty {
            return .notStarted
        }

        return .inProgress
    }

    func nextRefreshDate(section: WidgetTaskSectionOption, categoryID: String, now: Date) -> Date {
        let tasks = loadTasks(section: section, categoryID: categoryID, sort: .remainingTime, now: now)
        let transitionDates = tasks.map(\.countdownTarget).filter { $0 > now }
        let nextTransition = transitionDates.min()
        let fallbackRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        return min(nextTransition ?? fallbackRefresh, fallbackRefresh)
    }

    private func countdownText(
        for target: Date,
        now: Date,
        prefixEnglish: String,
        prefixChinese: String
    ) -> (english: String, chinese: String) {
        let interval = max(0, Int(target.timeIntervalSince(now)))
        let days = interval / 86_400
        let hours = (interval % 86_400) / 3_600
        let minutes = (interval % 3_600) / 60

        let englishValue: String
        let chineseValue: String

        if days > 0 {
            englishValue = "\(days)d \(hours)h"
            chineseValue = "\(days)天\(hours)时"
        } else if hours > 0 {
            englishValue = "\(hours)h \(minutes)m"
            chineseValue = "\(hours)时\(minutes)分"
        } else {
            englishValue = "\(max(minutes, 1))m"
            chineseValue = "\(max(minutes, 1))分"
        }

        return ("\(prefixEnglish) \(englishValue)", "\(prefixChinese) \(chineseValue)")
    }
}

struct LiquidDeadlineWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LiquidDeadlineWidgetEntry {
        LiquidDeadlineWidgetEntry(
            date: .now,
            section: .inProgress,
            category: WidgetCategoryCatalog.allEntity(in: .current()),
            sort: .remainingTime,
            tasks: Self.sampleTasks(for: .inProgress, now: .now),
            language: .current()
        )
    }

    func snapshot(for configuration: DeadlineWidgetConfigurationIntent, in context: Context) async -> LiquidDeadlineWidgetEntry {
        let now = Date()
        let language = WidgetLanguage.current()
        let repository = LiquidDeadlineWidgetRepository()
        let availableGroups = repository.availableGroupNames(language: language)
        let section = configuration.section == .automatic
            ? repository.preferredSection(now: now)
            : configuration.section
        let categoryIdentifier = configuration.category?.id ?? WidgetCategoryEntity.allIdentifier
        let category = WidgetCategoryCatalog.entity(
            for: categoryIdentifier,
            language: language,
            availableGroupNames: availableGroups
        )
        let sort = configuration.sort
        let tasks = repository.loadTasks(
            section: section,
            categoryID: category.id,
            sort: sort,
            now: now
        )

        return LiquidDeadlineWidgetEntry(
            date: now,
            section: section,
            category: category,
            sort: sort,
            tasks: tasks.isEmpty ? Self.sampleTasks(for: section, now: now) : tasks,
            language: language
        )
    }

    func timeline(for configuration: DeadlineWidgetConfigurationIntent, in context: Context) async -> Timeline<LiquidDeadlineWidgetEntry> {
        let now = Date()
        let language = WidgetLanguage.current()
        let repository = LiquidDeadlineWidgetRepository()
        let availableGroups = repository.availableGroupNames(language: language)
        let section = configuration.section == .automatic
            ? repository.preferredSection(now: now)
            : configuration.section
        let categoryIdentifier = configuration.category?.id ?? WidgetCategoryEntity.allIdentifier
        let category = WidgetCategoryCatalog.entity(
            for: categoryIdentifier,
            language: language,
            availableGroupNames: availableGroups
        )
        let sort = configuration.sort
        let tasks = repository.loadTasks(
            section: section,
            categoryID: category.id,
            sort: sort,
            now: now
        )

        let entry = LiquidDeadlineWidgetEntry(
            date: now,
            section: section,
            category: category,
            sort: sort,
            tasks: tasks,
            language: language
        )

        let refreshDate = repository.nextRefreshDate(
            section: section,
            categoryID: category.id,
            now: now
        )

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    fileprivate static func sampleTasks(for section: WidgetTaskSectionOption, now: Date) -> [WidgetTaskSnapshot] {
        let baseStart = Calendar.current.date(byAdding: .hour, value: section == .notStarted ? 2 : -1, to: now) ?? now
        let baseEnd = Calendar.current.date(byAdding: .hour, value: 6, to: baseStart) ?? baseStart

        return [
            WidgetTaskSnapshot(
                id: UUID(),
                title: section == .notStarted ? "Mock Exam" : "Project Review",
                category: section == .notStarted ? "Study" : "Work",
                startDate: baseStart,
                endDate: baseEnd,
                countdownTarget: section == .notStarted ? baseStart : baseEnd,
                progress: section == .notStarted ? 0 : 0.42,
                tint: section == .notStarted ? .blue : .orange,
                countdownTextEnglish: section == .notStarted ? "Starts in 2h" : "Remaining 5h",
                countdownTextChinese: section == .notStarted ? "距开始 2时" : "剩余 5时"
            ),
            WidgetTaskSnapshot(
                id: UUID(),
                title: section == .notStarted ? "Morning Run" : "Submit Report",
                category: section == .notStarted ? "Health" : "Work",
                startDate: Calendar.current.date(byAdding: .hour, value: 4, to: baseStart) ?? baseStart,
                endDate: Calendar.current.date(byAdding: .hour, value: 8, to: baseStart) ?? baseEnd,
                countdownTarget: Calendar.current.date(byAdding: .hour, value: section == .notStarted ? 4 : 8, to: baseStart) ?? baseEnd,
                progress: section == .notStarted ? 0 : 0.74,
                tint: .green,
                countdownTextEnglish: section == .notStarted ? "Starts in 6h" : "Remaining 7h",
                countdownTextChinese: section == .notStarted ? "距开始 6时" : "剩余 7时"
            )
        ]
    }
}

struct LiquidDeadlineWidget: Widget {
    let kind = "LiquidDeadlineWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DeadlineWidgetConfigurationIntent.self,
            provider: LiquidDeadlineWidgetProvider()
        ) { entry in
            LiquidDeadlineWidgetView(entry: entry)
                .containerBackground(
                    LinearGradient(
                        colors: [Color.white, Color.blue.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    for: .widget
                )
        }
        .configurationDisplayName("Liquid Deadline")
        .description("Show the nearest deadlines with progress and countdown.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct LockScreenInProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: LockScreenDeadlineVariant.inProgress.kind,
            provider: LockScreenDeadlineProvider(variant: .inProgress)
        ) { entry in
            LockScreenDeadlineWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName(LockScreenDeadlineVariant.inProgress.displayNameKey)
        .description(LockScreenDeadlineVariant.inProgress.descriptionKey)
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LockScreenStartingSoonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: LockScreenDeadlineVariant.startingSoon.kind,
            provider: LockScreenDeadlineProvider(variant: .startingSoon)
        ) { entry in
            LockScreenDeadlineWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName(LockScreenDeadlineVariant.startingSoon.displayNameKey)
        .description(LockScreenDeadlineVariant.startingSoon.descriptionKey)
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LockScreenDeadlineProvider: TimelineProvider {
    let variant: LockScreenDeadlineVariant

    func placeholder(in context: Context) -> LockScreenDeadlineEntry {
        let language = WidgetLanguage.current()
        return LockScreenDeadlineEntry(
            date: .now,
            variant: variant,
            task: LiquidDeadlineWidgetProvider.sampleTasks(for: variant.section, now: .now).first,
            language: language
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenDeadlineEntry) -> Void) {
        let now = Date()
        let language = WidgetLanguage.current()
        let repository = LiquidDeadlineWidgetRepository()
        let task = repository.loadTasks(
            section: variant.section,
            categoryID: WidgetCategoryEntity.allIdentifier,
            sort: .remainingTime,
            now: now
        ).first

        let resolvedTask = task ?? (context.isPreview ? LiquidDeadlineWidgetProvider.sampleTasks(for: variant.section, now: now).first : nil)
        completion(
            LockScreenDeadlineEntry(
                date: now,
                variant: variant,
                task: resolvedTask,
                language: language
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenDeadlineEntry>) -> Void) {
        let now = Date()
        let language = WidgetLanguage.current()
        let repository = LiquidDeadlineWidgetRepository()
        let task = repository.loadTasks(
            section: variant.section,
            categoryID: WidgetCategoryEntity.allIdentifier,
            sort: .remainingTime,
            now: now
        ).first

        let entry = LockScreenDeadlineEntry(
            date: now,
            variant: variant,
            task: task,
            language: language
        )

        let refreshDate = repository.nextRefreshDate(
            section: variant.section,
            categoryID: WidgetCategoryEntity.allIdentifier,
            now: now
        )

        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

private struct LiquidDeadlineWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: LiquidDeadlineWidgetEntry

    private var visibleTasks: [WidgetTaskSnapshot] {
        Array(entry.tasks.prefix(maxItemCount))
    }

    private var maxItemCount: Int {
        switch family {
        case .systemSmall:
            return 1
        case .systemMedium:
            return 1
        case .systemLarge:
            return 2
        default:
            return 1
        }
    }

    var body: some View {
        if visibleTasks.isEmpty {
            emptyState
        } else {
            Group {
                if family == .systemMedium, let task = visibleTasks.first {
                    mediumLayout(task: task)
                } else {
                    VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 12) {
                        header

                        ForEach(visibleTasks) { task in
                            WidgetTaskRow(
                                task: task,
                                language: entry.language,
                                compact: family == .systemSmall,
                                roomy: false,
                                medium: false
                            )
                        }
                    }
                    .padding(family == .systemSmall ? 12 : 14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .environment(\.locale, entry.language.locale)
        }
    }

    private func mediumLayout(task: WidgetTaskSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            WidgetTaskRow(task: task, language: entry.language, compact: false, roomy: false, medium: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.section == .notStarted ? entry.language.text("Not Started", "未开始") : entry.language.text("In Progress", "进行中"))
                .font(headerFont)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(entry.category.id == WidgetCategoryEntity.allIdentifier ? entry.language.text("All Categories", "全部分类") : entry.category.name)
                .font(family == .systemMedium ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var headerFont: Font {
        switch family {
        case .systemSmall:
            return .headline
        case .systemMedium:
            return .headline.weight(.semibold)
        default:
            return .title3.weight(.semibold)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(entry.language.text("No matching tasks", "没有匹配的任务"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Text(entry.language.text("Try another category or status.", "可以尝试切换分类或任务状态。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(family == .systemMedium ? 18 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.locale, entry.language.locale)
    }
}

private struct WidgetTaskRow: View {
    let task: WidgetTaskSnapshot
    let language: WidgetLanguage
    let compact: Bool
    let roomy: Bool
    let medium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            Text(task.title)
                .font(titleFont)
                .foregroundStyle(.primary)
                .lineLimit(compact ? 2 : 1)

            Text(language.text(task.countdownTextEnglish, task.countdownTextChinese))
                .font(countdownFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            WidgetProgressBar(progress: task.progress, tint: task.tint)
                .frame(height: progressHeight)

            HStack(spacing: 8) {
                Text(language.text("Start", "起") + " " + formatted(task.startDate))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Text(language.text("End", "止") + " " + formatted(task.endDate))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.95), lineWidth: 0.8)
        )
    }

    private var titleFont: Font {
        if compact {
            return .subheadline.weight(.semibold)
        }
        if medium {
            return .headline.weight(.semibold)
        }
        return .headline
    }

    private var countdownFont: Font {
        if compact {
            return .caption.weight(.semibold)
        }
        if medium {
            return .subheadline.weight(.semibold)
        }
        return .subheadline.weight(.semibold)
    }

    private var progressHeight: CGFloat {
        if compact {
            return 6
        }
        if medium {
            return 6
        }
        return roomy ? 9 : 8
    }

    private var verticalSpacing: CGFloat {
        if compact {
            return 6
        }
        if medium {
            return 6
        }
        return roomy ? 10 : 8
    }

    private var verticalPadding: CGFloat {
        if compact {
            return 10
        }
        if medium {
            return 8
        }
        return roomy ? 16 : 12
    }

    private var cornerRadius: CGFloat {
        if compact {
            return 16
        }
        if medium {
            return 18
        }
        return roomy ? 20 : 18
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(language.locale)
                .month(.defaultDigits)
                .day()
                .hour()
                .minute()
        )
    }
}

private struct WidgetProgressBar: View {
    let progress: Double
    let tint: Color

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ProgressView(value: clampedProgress)
            .progressViewStyle(.linear)
            .tint(tint)
    }
}

private struct LockScreenDeadlineWidgetView: View {
    let entry: LockScreenDeadlineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.variant.title(in: entry.language))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(entry.task?.title ?? entry.variant.emptyTitle(in: entry.language))
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(countdownText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.task?.tint ?? entry.variant.fallbackTint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .environment(\.locale, entry.language.locale)
    }

    private var countdownText: String {
        if let task = entry.task {
            return formattedRemainingTime(until: task.countdownTarget)
        }
        return entry.variant.emptySubtitle(in: entry.language)
    }

    private func formattedRemainingTime(until target: Date) -> String {
        let interval = max(0, Int(target.timeIntervalSince(entry.date)))
        let days = interval / 86_400
        let hours = (interval % 86_400) / 3_600
        let minutes = (interval % 3_600) / 60

        if days > 0 {
            return entry.language.text("\(days)d \(hours)h", "\(days)天\(hours)时")
        }
        if hours > 0 {
            return entry.language.text("\(hours)h \(minutes)m", "\(hours)时\(minutes)分")
        }
        return entry.language.text("\(max(minutes, 1))m", "\(max(minutes, 1))分")
    }
}
