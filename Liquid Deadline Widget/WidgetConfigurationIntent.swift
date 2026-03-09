import AppIntents
import Foundation

enum WidgetTaskSectionOption: String, AppEnum {
    case notStarted
    case inProgress

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Status / 状态")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .notStarted: DisplayRepresentation(title: "Not Started / 未开始"),
        .inProgress: DisplayRepresentation(title: "In Progress / 进行中")
    ]
}

enum WidgetTaskSortOption: String, AppEnum {
    case remainingTime
    case byDeadline

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sort / 排序")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .remainingTime: DisplayRepresentation(title: "Remaining Time / 剩余时间"),
        .byDeadline: DisplayRepresentation(title: "Deadline / 截止时间")
    ]
}

struct WidgetCategoryEntity: AppEntity, Identifiable, Hashable {
    static let allIdentifier = "__all__"

    let id: String
    let name: String

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Category / 分类")
    static let defaultQuery = WidgetCategoryQuery()

    static var all: WidgetCategoryEntity {
        WidgetCategoryEntity(id: allIdentifier, name: "All / 全部")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct WidgetCategoryQuery: EntityQuery {
    func entities(for identifiers: [WidgetCategoryEntity.ID]) async throws -> [WidgetCategoryEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WidgetCategoryEntity] {
        let defaults = UserDefaults(suiteName: WidgetSharedDefaults.appGroupID) ?? .standard
        let fallbackGroups: [String] = {
            let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
            if preferredLanguage.hasPrefix("zh") {
                return ["学习", "工作", "生活", "健康", "财务"]
            }
            return ["Study", "Work", "Life", "Health", "Finance"]
        }()

        let storedGroups = (defaults.stringArray(forKey: WidgetSharedDefaults.groupsStorageKey) ?? fallbackGroups)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var uniqueGroups: [String] = []

        for group in storedGroups where !uniqueGroups.contains(group) {
            uniqueGroups.append(group)
        }

        return [WidgetCategoryEntity.all] + uniqueGroups.map { WidgetCategoryEntity(id: $0, name: $0) }
    }
}

struct DeadlineWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Widget Settings / 小组件设置" }
    static var description: IntentDescription { "Choose task status, category, and sort order. / 选择任务状态、分类与排序方式。" }

    @Parameter(title: "Status / 状态")
    var section: WidgetTaskSectionOption

    @Parameter(title: "Category / 分类")
    var category: WidgetCategoryEntity

    @Parameter(title: "Sort / 排序")
    var sort: WidgetTaskSortOption

    init() {
        section = .inProgress
        category = .all
        sort = .remainingTime
    }
}
