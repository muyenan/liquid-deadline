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
    let countdownPrefixEnglish: String
    let countdownPrefixChinese: String
}

struct LiquidDeadlineWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: DeadlineWidgetConfigurationIntent
    let tasks: [WidgetTaskSnapshot]
    let language: WidgetLanguage
}

private struct LiquidDeadlineWidgetRepository {
    private let defaults = UserDefaults(suiteName: WidgetSharedDefaults.appGroupID) ?? .standard

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

        let filteredItems = items.filter { item in
            switch section {
            case .notStarted:
                guard item.section(at: now) == .notStarted else { return false }
            case .inProgress:
                guard item.section(at: now) == .inProgress else { return false }
            }

            if categoryID == WidgetCategoryEntity.allIdentifier {
                return true
            }
            return item.category == categoryID
        }

        let sortedItems = filteredItems.sorted { lhs, rhs in
            switch sort {
            case .remainingTime:
                let lhsTarget = section == .notStarted ? lhs.startDate : lhs.endDate
                let rhsTarget = section == .notStarted ? rhs.startDate : rhs.endDate
                return lhsTarget < rhsTarget
            case .byDeadline:
                return lhs.endDate < rhs.endDate
            }
        }

        return sortedItems.map { item in
            WidgetTaskSnapshot(
                id: item.id,
                title: item.title,
                category: item.category,
                startDate: item.startDate,
                endDate: item.endDate,
                countdownTarget: section == .notStarted ? item.startDate : item.endDate,
                progress: item.progress(at: now),
                tint: item.progressTint(at: now),
                countdownPrefixEnglish: section == .notStarted ? "Starts in" : "Remaining",
                countdownPrefixChinese: section == .notStarted ? "距开始" : "剩余"
            )
        }
    }

    func nextRefreshDate(section: WidgetTaskSectionOption, categoryID: String, now: Date) -> Date {
        let tasks = loadTasks(section: section, categoryID: categoryID, sort: .remainingTime, now: now)
        let transitionDates = tasks.map(\.countdownTarget).filter { $0 > now }
        let nextTransition = transitionDates.min()
        let fallbackRefresh = Calendar.current.date(byAdding: .minute, value: 10, to: now) ?? now.addingTimeInterval(600)
        return min(nextTransition ?? fallbackRefresh, fallbackRefresh)
    }
}

struct LiquidDeadlineWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LiquidDeadlineWidgetEntry {
        LiquidDeadlineWidgetEntry(
            date: .now,
            configuration: DeadlineWidgetConfigurationIntent(),
            tasks: Self.sampleTasks(for: .inProgress, now: .now),
            language: .current()
        )
    }

    func snapshot(for configuration: DeadlineWidgetConfigurationIntent, in context: Context) async -> LiquidDeadlineWidgetEntry {
        let now = Date()
        let language = WidgetLanguage.current()
        let repository = LiquidDeadlineWidgetRepository()
        let tasks = repository.loadTasks(
            section: configuration.section,
            categoryID: configuration.category.id,
            sort: configuration.sort,
            now: now
        )

        return LiquidDeadlineWidgetEntry(
            date: now,
            configuration: configuration,
            tasks: tasks.isEmpty ? Self.sampleTasks(for: configuration.section, now: now) : tasks,
            language: language
        )
    }

    func timeline(for configuration: DeadlineWidgetConfigurationIntent, in context: Context) async -> Timeline<LiquidDeadlineWidgetEntry> {
        let now = Date()
        let language = WidgetLanguage.current()
        let repository = LiquidDeadlineWidgetRepository()
        let tasks = repository.loadTasks(
            section: configuration.section,
            categoryID: configuration.category.id,
            sort: configuration.sort,
            now: now
        )

        let entry = LiquidDeadlineWidgetEntry(
            date: now,
            configuration: configuration,
            tasks: tasks,
            language: language
        )

        let refreshDate = repository.nextRefreshDate(
            section: configuration.section,
            categoryID: configuration.category.id,
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
                countdownPrefixEnglish: section == .notStarted ? "Starts in" : "Remaining",
                countdownPrefixChinese: section == .notStarted ? "距开始" : "剩余"
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
                countdownPrefixEnglish: section == .notStarted ? "Starts in" : "Remaining",
                countdownPrefixChinese: section == .notStarted ? "距开始" : "剩余"
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
        .description("Show the nearest deadlines with progress and countdown. / 用进度条与倒计时显示最近任务。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
        case .systemLarge:
            return 4
        default:
            return 2
        }
    }

    var body: some View {
        if visibleTasks.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 12) {
                header

                ForEach(visibleTasks) { task in
                    WidgetTaskRow(task: task, language: entry.language, compact: family == .systemSmall)
                }

                Spacer(minLength: 0)
            }
            .padding(family == .systemSmall ? 12 : 14)
            .environment(\.locale, entry.language.locale)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.configuration.section == .notStarted ? entry.language.text("Not Started", "未开始") : entry.language.text("In Progress", "进行中"))
                .font(family == .systemSmall ? .headline : .title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(entry.configuration.category.id == WidgetCategoryEntity.allIdentifier ? entry.language.text("All Categories", "全部分类") : entry.configuration.category.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Spacer()
            Text(entry.language.text("No matching tasks", "没有匹配的任务"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Text(entry.language.text("Try another category or status.", "可以尝试切换分类或任务状态。"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .environment(\.locale, entry.language.locale)
    }
}

private struct WidgetTaskRow: View {
    let task: WidgetTaskSnapshot
    let language: WidgetLanguage
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(compact ? .subheadline.weight(.semibold) : .headline)
                        .foregroundStyle(.primary)
                        .lineLimit(compact ? 2 : 1)

                    Text(task.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(language.text(task.countdownPrefixEnglish, task.countdownPrefixChinese))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(task.countdownTarget, style: .timer)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            }

            WidgetProgressBar(progress: task.progress, tint: task.tint)
                .frame(height: compact ? 8 : 10)

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
        .padding(compact ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
                .fill(.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
                .stroke(.white.opacity(0.95), lineWidth: 0.8)
        )
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
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.62)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width * clampedProgress, clampedProgress > 0 ? 6 : 0))
            }
        }
    }
}
