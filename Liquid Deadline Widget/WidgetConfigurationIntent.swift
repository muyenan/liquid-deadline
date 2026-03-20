import AppIntents
import Foundation

enum WidgetCategoryCatalog {
    static let allIdentifier = "__all__"
    static let builtInCategoryIdentifiers = ["study", "work", "life", "health", "finance"]

    static func allEntity(in language: WidgetLanguage) -> WidgetCategoryEntity {
        WidgetCategoryEntity(id: allIdentifier, name: language.text("All Categories", "全部分类"))
    }

    static func displayName(for identifier: String, language: WidgetLanguage) -> String? {
        language.builtInCategoryName(for: identifier)
    }

    static func canonicalIdentifier(for rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if trimmed == allIdentifier {
            return allIdentifier
        }

        for identifier in builtInCategoryIdentifiers {
            if identifier == trimmed {
                return identifier
            }
            for language in WidgetLanguage.allCases {
                if displayName(for: identifier, language: language) == trimmed {
                    return identifier
                }
            }
        }

        return trimmed
    }

    static func entity(for identifier: String, language: WidgetLanguage, availableGroupNames: [String]) -> WidgetCategoryEntity {
        let normalizedIdentifier = canonicalIdentifier(for: identifier)

        if normalizedIdentifier == allIdentifier {
            return allEntity(in: language)
        }

        if let builtInName = displayName(for: normalizedIdentifier, language: language) {
            return WidgetCategoryEntity(id: normalizedIdentifier, name: builtInName)
        }

        if let availableName = availableGroupNames.first(where: { canonicalIdentifier(for: $0) == normalizedIdentifier }) {
            return WidgetCategoryEntity(id: normalizedIdentifier, name: availableName)
        }

        return WidgetCategoryEntity(id: normalizedIdentifier, name: identifier)
    }

    static func suggestedEntities(from storedGroups: [String], language: WidgetLanguage) -> [WidgetCategoryEntity] {
        var entities: [WidgetCategoryEntity] = [allEntity(in: language)]
        var seenIdentifiers: Set<String> = [allIdentifier]

        for group in storedGroups {
            let identifier = canonicalIdentifier(for: group)
            guard !identifier.isEmpty else { continue }
            guard !seenIdentifiers.contains(identifier) else { continue }

            seenIdentifiers.insert(identifier)
            entities.append(entity(for: identifier, language: language, availableGroupNames: storedGroups))
        }

        return entities
    }

    static func matches(itemCategory: String, selectedIdentifier: String) -> Bool {
        let normalizedIdentifier = canonicalIdentifier(for: selectedIdentifier)

        if normalizedIdentifier == allIdentifier {
            return true
        }

        return canonicalIdentifier(for: itemCategory) == normalizedIdentifier
    }
}

enum WidgetTaskSectionOption: String, AppEnum {
    case notStarted
    case inProgress

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Status")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .notStarted: DisplayRepresentation(title: "Not Started"),
        .inProgress: DisplayRepresentation(title: "In Progress")
    ]
}

enum WidgetTaskSortOption: String, AppEnum {
    case addedDate
    case remainingTime

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sort")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .addedDate: DisplayRepresentation(title: "Added Date"),
        .remainingTime: DisplayRepresentation(title: "Remaining Time"),
    ]
}

struct WidgetCategoryEntity: AppEntity, Identifiable, Hashable {
    static let allIdentifier = WidgetCategoryCatalog.allIdentifier

    let id: String
    let name: String

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Category")
    static let defaultQuery = WidgetCategoryQuery()
    static var all: WidgetCategoryEntity {
        WidgetCategoryCatalog.allEntity(in: WidgetLanguage.systemCurrent())
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct WidgetCategoryQuery: EntityQuery {
    func entities(for identifiers: [WidgetCategoryEntity.ID]) async throws -> [WidgetCategoryEntity] {
        let language = WidgetLanguage.systemCurrent()
        let storedGroups = loadStoredGroups(language: language)
        return identifiers.map { identifier in
            WidgetCategoryCatalog.entity(for: identifier, language: language, availableGroupNames: storedGroups)
        }
    }

    func suggestedEntities() async throws -> [WidgetCategoryEntity] {
        let language = WidgetLanguage.systemCurrent()
        let storedGroups = loadStoredGroups(language: language)
        return WidgetCategoryCatalog.suggestedEntities(from: storedGroups, language: language)
    }

    private func loadStoredGroups(language: WidgetLanguage) -> [String] {
        let defaults = UserDefaults(suiteName: WidgetSharedDefaults.appGroupID) ?? .standard
        let fallbackGroups = WidgetCategoryCatalog.builtInCategoryIdentifiers.compactMap { WidgetCategoryCatalog.displayName(for: $0, language: language) }

        return (defaults.stringArray(forKey: WidgetSharedDefaults.groupsStorageKey) ?? fallbackGroups)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct DeadlineWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Widget Settings"
    static let description = IntentDescription("Choose task status, category, and sort order.")

    @Parameter(title: "Status", default: .inProgress)
    var section: WidgetTaskSectionOption

    @Parameter(title: "Category")
    var category: WidgetCategoryEntity?

    @Parameter(title: "Sort", default: .remainingTime)
    var sort: WidgetTaskSortOption

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$section) · \(\.$category) · \(\.$sort)")
    }

    init() {
        section = .inProgress
        category = .all
        sort = .remainingTime
    }
}
