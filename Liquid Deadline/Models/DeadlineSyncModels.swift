import Foundation

enum DeadlineItemSourceKind: String, Codable, Hashable {
    case manual
    case importedFile
    case subscribedURL
}

enum DeadlineRecurringChangeScope: String, Codable, Hashable {
    case thisEvent
    case futureEvents
}

enum DeadlineReminderRelation: String, CaseIterable, Identifiable, Codable, Hashable {
    case beforeStart
    case afterStart
    case beforeEnd

    var id: String { rawValue }

    nonisolated func title(in language: AppLanguage) -> String {
        language.reminderRelationTitle(self)
    }

    nonisolated fileprivate func referenceDate(for item: DeadlineItem) -> Date {
        switch self {
        case .beforeStart, .afterStart:
            return item.startDate
        case .beforeEnd:
            return item.endDate
        }
    }
}

enum DeadlineReminderUnit: String, CaseIterable, Identifiable, Codable, Hashable {
    case minute
    case hour
    case day

    var id: String { rawValue }

    nonisolated func title(in language: AppLanguage, value: Int) -> String {
        language.reminderUnitTitle(self, value: value)
    }

    nonisolated fileprivate func timeInterval(for value: Int) -> TimeInterval {
        let normalizedValue = min(max(value, 1), 999)
        switch self {
        case .minute:
            return Double(normalizedValue) * 60
        case .hour:
            return Double(normalizedValue) * 60 * 60
        case .day:
            return Double(normalizedValue) * 60 * 60 * 24
        }
    }
}

struct DeadlineReminder: Identifiable, Codable, Hashable {
    var id: UUID
    var relation: DeadlineReminderRelation
    var value: Int
    var unit: DeadlineReminderUnit

    init(
        id: UUID = UUID(),
        relation: DeadlineReminderRelation,
        value: Int,
        unit: DeadlineReminderUnit
    ) {
        self.id = id
        self.relation = relation
        self.value = min(max(value, 1), 999)
        self.unit = unit
    }

    static var defaultValue: DeadlineReminder {
        DeadlineReminder(relation: .beforeEnd, value: 15, unit: .minute)
    }

    nonisolated func triggerDate(for item: DeadlineItem) -> Date {
        let referenceDate = relation.referenceDate(for: item)
        let interval = unit.timeInterval(for: value)

        switch relation {
        case .beforeStart, .beforeEnd:
            return referenceDate.addingTimeInterval(-interval)
        case .afterStart:
            return referenceDate.addingTimeInterval(interval)
        }
    }

    nonisolated func summary(in language: AppLanguage) -> String {
        language.reminderSummary(relation: relation, value: value, unit: unit)
    }
}

enum DeadlineRepeatUnit: String, CaseIterable, Identifiable, Codable, Hashable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .day:
            return language.text("Day", "天")
        case .week:
            return language.text("Week", "周")
        case .month:
            return language.text("Month", "月")
        case .year:
            return language.text("Year", "年")
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        case .year:
            return .year
        }
    }
}

struct DeadlineRepeatRule: Codable, Hashable {
    var interval: Int
    var unit: DeadlineRepeatUnit
    var endDate: Date?

    init(interval: Int, unit: DeadlineRepeatUnit, endDate: Date? = nil) {
        self.interval = min(max(interval, 1), 999)
        self.unit = unit
        self.endDate = endDate
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: unit.calendarComponent, value: interval, to: date)
    }

    func summary(in language: AppLanguage) -> String {
        language.repeatRuleSummary(interval: interval, unit: unit)
    }
}

private extension DeadlineRepeatUnit {
    func summaryUnit(in language: AppLanguage, pluralized: Bool) -> String {
        language.repeatUnitTitle(self, pluralized: pluralized)
    }
}

struct DeadlineSubscription: Identifiable, Codable, Hashable {
    var id: UUID
    var urlString: String
    var category: String
    var reminders: [DeadlineReminder]
    var createdAt: Date
    var lastSyncedAt: Date?
    var lastAttemptedAt: Date?
    var lastErrorMessage: String?

    init(
        id: UUID = UUID(),
        urlString: String,
        category: String,
        reminders: [DeadlineReminder] = [],
        createdAt: Date = .now,
        lastSyncedAt: Date? = nil,
        lastAttemptedAt: Date? = nil,
        lastErrorMessage: String? = nil
    ) {
        self.id = id
        self.urlString = urlString
        self.category = category
        self.reminders = reminders
        self.createdAt = createdAt
        self.lastSyncedAt = lastSyncedAt
        self.lastAttemptedAt = lastAttemptedAt
        self.lastErrorMessage = lastErrorMessage
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case urlString
        case category
        case reminders
        case createdAt
        case lastSyncedAt
        case lastAttemptedAt
        case lastErrorMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        urlString = try container.decode(String.self, forKey: .urlString)
        category = try container.decode(String.self, forKey: .category)
        reminders = try container.decodeIfPresent([DeadlineReminder].self, forKey: .reminders) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        lastAttemptedAt = try container.decodeIfPresent(Date.self, forKey: .lastAttemptedAt)
        lastErrorMessage = try container.decodeIfPresent(String.self, forKey: .lastErrorMessage)
    }

    var normalizedURLString: String {
        urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayName: String {
        guard let url = URL(string: normalizedURLString) else {
            return normalizedURLString
        }

        let host = url.host(percentEncoded: false) ?? url.host ?? normalizedURLString
        if let lastPathComponent = url.pathComponents.last, lastPathComponent.isEmpty == false, lastPathComponent != "/" {
            return "\(host)/\(lastPathComponent)"
        }
        return host
    }
}

enum DeadlineSyncError: LocalizedError {
    case invalidURL
    case invalidCalendarFile
    case unreadableFile
    case emptyImport

    var errorDescription: String? {
        let language = AppLanguage.currentForLocalization()
        switch self {
        case .invalidURL:
            return language.text("The URL is invalid.", "URL 无效。")
        case .invalidCalendarFile:
            return language.text("The calendar file could not be parsed.", "无法解析日历文件。")
        case .unreadableFile:
            return language.text("The selected file could not be read.", "无法读取所选文件。")
        case .emptyImport:
            return language.text("No importable calendar events were found.", "没有找到可导入的日历事件。")
        }
    }
}
