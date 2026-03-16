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
        if interval == 1 {
            switch unit {
            case .day:
                return language.text("Every day", "每天")
            case .week:
                return language.text("Every week", "每周")
            case .month:
                return language.text("Every month", "每月")
            case .year:
                return language.text("Every year", "每年")
            }
        }

        if interval == 2, unit == .week {
            return language.text("Every 2 weeks", "每两周")
        }

        return language.text("Every \(interval) \(unit.summaryUnit(in: language, pluralized: interval > 1))", "每 \(interval) \(unit.summaryUnit(in: language, pluralized: interval > 1))")
    }
}

private extension DeadlineRepeatUnit {
    func summaryUnit(in language: AppLanguage, pluralized: Bool) -> String {
        switch self {
        case .day:
            return language.text(pluralized ? "days" : "day", "天")
        case .week:
            return language.text(pluralized ? "weeks" : "week", "周")
        case .month:
            return language.text(pluralized ? "months" : "month", "月")
        case .year:
            return language.text(pluralized ? "years" : "year", "年")
        }
    }
}

struct DeadlineSubscription: Identifiable, Codable, Hashable {
    var id: UUID
    var urlString: String
    var category: String
    var createdAt: Date
    var lastSyncedAt: Date?
    var lastAttemptedAt: Date?
    var lastErrorMessage: String?

    init(
        id: UUID = UUID(),
        urlString: String,
        category: String,
        createdAt: Date = .now,
        lastSyncedAt: Date? = nil,
        lastAttemptedAt: Date? = nil,
        lastErrorMessage: String? = nil
    ) {
        self.id = id
        self.urlString = urlString
        self.category = category
        self.createdAt = createdAt
        self.lastSyncedAt = lastSyncedAt
        self.lastAttemptedAt = lastAttemptedAt
        self.lastErrorMessage = lastErrorMessage
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
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .invalidCalendarFile:
            return "The calendar file could not be parsed."
        case .unreadableFile:
            return "The selected file could not be read."
        case .emptyImport:
            return "No importable calendar events were found."
        }
    }
}
