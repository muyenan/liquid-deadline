import Foundation
import SwiftUI

enum DeadlineSection: String, CaseIterable, Identifiable, Codable {
    case notStarted = "未开始"
    case inProgress = "进行中"
    case completed = "已完成"
    case ended = "已结束"

    var id: String { rawValue }

    var storageValue: String {
        switch self {
        case .notStarted:
            return "not_started"
        case .inProgress:
            return "in_progress"
        case .completed:
            return "completed"
        case .ended:
            return "ended"
        }
    }

    init(storageValue: String) {
        switch storageValue {
        case Self.notStarted.storageValue:
            self = .notStarted
        case Self.completed.storageValue:
            self = .completed
        case Self.ended.storageValue:
            self = .ended
        default:
            self = .inProgress
        }
    }

    var tint: Color {
        switch self {
        case .notStarted:
            return Color.blue
        case .inProgress:
            return Color.orange
        case .completed:
            return Color.green
        case .ended:
            return Color.gray
        }
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .notStarted:
            return language.text("Not Started", "未开始")
        case .inProgress:
            return language.text("In Progress", "进行中")
        case .completed:
            return language.text("Completed", "已完成")
        case .ended:
            return language.text("Ended", "已结束")
        }
    }
}

enum DeadlineViewStyle: String, CaseIterable, Identifiable, Codable {
    case progressBar = "进度条"
    case grid = "网格"

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .progressBar:
            return language.text("Progress Bar", "进度条")
        case .grid:
            return language.text("Grid", "网格")
        }
    }
}

enum DeadlineSortOption: String, CaseIterable, Identifiable, Codable {
    case recentAdded = "按照最近添加排序"
    case remainingTime = "按剩余时间"
    case byDate = "按截止时间"

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .recentAdded:
            return language.text("Sort by Recently Added", "按照最近添加排序")
        case .remainingTime:
            return language.text("Sort by Remaining Time", "按剩余时间")
        case .byDate:
            return language.text("Sort by Deadline", "按截止时间")
        }
    }
}

enum BackgroundStyleOption: String, CaseIterable, Identifiable, Codable {
    case white = "纯白色"
    case pinkWhiteGradient = "粉白色渐变"
    case blueWhiteGradient = "蓝白色渐变"

    var id: String { rawValue }

    var usesLightForeground: Bool {
        switch self {
        case .white, .pinkWhiteGradient, .blueWhiteGradient:
            return false
        }
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .white:
            return language.text("Pure White", "纯白色")
        case .pinkWhiteGradient:
            return language.text("Pink-White Gradient", "粉白色渐变")
        case .blueWhiteGradient:
            return language.text("Blue-White Gradient", "蓝白色渐变")
        }
    }
}

struct DeadlineItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var category: String
    var detail: String
    var startDate: Date
    var endDate: Date
    var completedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        detail: String = "",
        startDate: Date,
        endDate: Date,
        completedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.detail = detail
        self.startDate = startDate
        self.endDate = endDate
        self.completedAt = completedAt
        self.createdAt = createdAt
    }

    func section(at now: Date) -> DeadlineSection {
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

    func canComplete(at now: Date) -> Bool {
        completedAt == nil && now < endDate
    }

    var isClosed: Bool {
        completedAt != nil
    }
}

extension DeadlineItem {
    func progressTint(at now: Date) -> Color {
        switch section(at: now) {
        case .completed:
            return .green
        case .ended:
            return .gray
        case .notStarted, .inProgress:
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

extension DeadlineItem {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case detail
        case startDate
        case endDate
        case completedAt
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(String.self, forKey: .category)
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(category, forKey: .category)
        try container.encode(detail, forKey: .detail)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
