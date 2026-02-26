import Foundation
import SwiftUI

enum DeadlineSection: String, CaseIterable, Identifiable, Codable {
    case notStarted = "未开始"
    case inProgress = "进行中"
    case finished = "已结束"

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .notStarted:
            return Color.blue
        case .inProgress:
            return Color.orange
        case .finished:
            return Color.gray
        }
    }
}

enum DeadlineViewStyle: String, CaseIterable, Identifiable, Codable {
    case progressBar = "进度条"
    case grid = "网格"

    var id: String { rawValue }
}

enum DeadlineSortOption: String, CaseIterable, Identifiable, Codable {
    case recentAdded = "按照最近添加排序"
    case byDate = "按截止时间"

    var id: String { rawValue }
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
}

struct DeadlineItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var category: String
    var detail: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        detail: String = "",
        startDate: Date,
        endDate: Date,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.detail = detail
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
    }

    func section(at now: Date) -> DeadlineSection {
        if now < startDate {
            return .notStarted
        }
        if now >= endDate {
            return .finished
        }
        return .inProgress
    }

    func progress(at now: Date) -> Double {
        guard endDate > startDate else {
            return now >= endDate ? 1 : 0
        }
        if now <= startDate {
            return 0
        }
        if now >= endDate {
            return 1
        }
        let total = endDate.timeIntervalSince(startDate)
        let passed = now.timeIntervalSince(startDate)
        return min(max(passed / total, 0), 1)
    }
}

extension DeadlineItem {
    func progressTint(at now: Date) -> Color {
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
        try container.encode(createdAt, forKey: .createdAt)
    }
}
