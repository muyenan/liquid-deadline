import Foundation

struct ICSImportedItemDraft: Hashable {
    let externalIdentifier: String
    let title: String
    let detail: String
    let startDate: Date
    let endDate: Date
    let originalStartDateWasMissing: Bool
    let isAllDay: Bool
}

enum ICSCalendarService {
    static let subscriptionExpansionHorizonDays = 365

    static func fetchDrafts(
        fromRemoteURLString urlString: String,
        importedAt: Date = .now,
        calendar: Calendar = .current
    ) async throws -> [ICSImportedItemDraft] {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw DeadlineSyncError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try drafts(from: data, importedAt: importedAt, calendar: calendar, horizonDays: subscriptionExpansionHorizonDays)
    }

    static func drafts(
        from data: Data,
        importedAt: Date = .now,
        calendar: Calendar = .current,
        horizonDays: Int = subscriptionExpansionHorizonDays
    ) throws -> [ICSImportedItemDraft] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            throw DeadlineSyncError.invalidCalendarFile
        }

        let parser = ICSParser(calendar: calendar)
        let events = try parser.parse(text: text)
        let horizonEnd = calendar.date(byAdding: .day, value: horizonDays, to: importedAt) ?? importedAt

        let drafts = events.flatMap { event in
            event.makeDrafts(importedAt: importedAt, calendar: calendar, horizonEnd: horizonEnd)
        }

        guard drafts.isEmpty == false else {
            throw DeadlineSyncError.emptyImport
        }

        return drafts
    }
}

private struct ICSParser {
    let calendar: Calendar

    func parse(text: String) throws -> [ICSEvent] {
        let unfoldedLines = unfoldICSLines(in: text)
        var events: [ICSEvent] = []
        var currentProperties: [ICSProperty] = []
        var insideEvent = false

        for rawLine in unfoldedLines {
            let line = rawLine.trimmingCharacters(in: .newlines)
            if line == "BEGIN:VEVENT" {
                insideEvent = true
                currentProperties = []
                continue
            }
            if line == "END:VEVENT" {
                insideEvent = false
                if let event = makeEvent(from: currentProperties) {
                    events.append(event)
                }
                currentProperties = []
                continue
            }
            if insideEvent, let property = ICSProperty(line: line) {
                currentProperties.append(property)
            }
        }

        return events
    }

    private func unfoldICSLines(in text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var result: [String] = []
        for line in normalized {
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                guard result.isEmpty == false else { continue }
                result[result.count - 1].append(line.trimmingCharacters(in: .whitespaces))
            } else {
                result.append(line)
            }
        }
        return result
    }

    private func makeEvent(from properties: [ICSProperty]) -> ICSEvent? {
        let uid = properties.first(for: "UID")?.normalizedIdentifier
        let summary = properties.first(for: "SUMMARY")?.decodedText ?? ""
        let description = properties.first(for: "DESCRIPTION")?.decodedText ?? ""
        let recurrenceID = properties.first(for: "RECURRENCE-ID").flatMap(parseDateValue)
        let startValue = properties.first(for: "DTSTART").flatMap(parseDateValue)
        let endValue = properties.first(for: "DTEND").flatMap(parseDateValue)
        let dueValue = properties.first(for: "DUE").flatMap(parseDateValue)
        let recurrenceRule = properties.firstValue(for: "RRULE").flatMap(parseRecurrenceRule)

        guard
            summary.isEmpty == false ||
            description.isEmpty == false ||
            startValue != nil ||
            endValue != nil ||
            dueValue != nil
        else {
            return nil
        }

        return ICSEvent(
            uid: uid ?? fallbackUID(summary: summary, description: description, startValue: startValue, endValue: endValue, dueValue: dueValue),
            title: summary.isEmpty ? "Untitled" : summary,
            detail: description,
            startValue: startValue,
            endValue: endValue,
            dueValue: dueValue,
            recurrenceRule: recurrenceRule,
            recurrenceID: recurrenceID
        )
    }

    private func parseDateValue(from property: ICSProperty) -> ICSDateValue? {
        let raw = property.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.isEmpty == false else { return nil }

        let isDateOnly = property.parameters["VALUE"]?.uppercased() == "DATE" || raw.count == 8
        if isDateOnly {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd"
            formatter.timeZone = TimeZone.current
            guard let date = formatter.date(from: raw) else { return nil }
            return ICSDateValue(date: date, isDateOnly: true)
        }

        let timezoneIdentifier = property.parameters["TZID"]
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if raw.hasSuffix("Z") {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        } else {
            formatter.timeZone = timezoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? TimeZone.current
            formatter.dateFormat = raw.count == 15 ? "yyyyMMdd'T'HHmmss" : "yyyyMMdd'T'HHmm"
        }

        if let date = formatter.date(from: raw) {
            return ICSDateValue(date: date, isDateOnly: false)
        }

        let compactFormatter = DateFormatter()
        compactFormatter.calendar = calendar
        compactFormatter.locale = Locale(identifier: "en_US_POSIX")
        compactFormatter.timeZone = formatter.timeZone
        compactFormatter.dateFormat = raw.hasSuffix("Z") ? "yyyyMMdd'T'HHmm'Z'" : "yyyyMMdd'T'HHmm"
        if let date = compactFormatter.date(from: raw) {
            return ICSDateValue(date: date, isDateOnly: false)
        }

        return nil
    }

    private func parseRecurrenceRule(from value: String) -> ICSRecurrenceRule? {
        let attributes = value
            .split(separator: ";")
            .reduce(into: [String: String]()) { partialResult, chunk in
                let pair = chunk.split(separator: "=", maxSplits: 1).map(String.init)
                guard pair.count == 2 else { return }
                partialResult[pair[0].uppercased()] = pair[1]
            }

        guard let frequency = attributes["FREQ"]?.uppercased() else { return nil }
        let interval = max(Int(attributes["INTERVAL"] ?? "1") ?? 1, 1)

        let unit: DeadlineRepeatUnit
        switch frequency {
        case "DAILY":
            unit = .day
        case "WEEKLY":
            unit = .week
        case "MONTHLY":
            unit = .month
        case "YEARLY":
            unit = .year
        default:
            return nil
        }

        var untilDate: Date?
        if let until = attributes["UNTIL"] {
            let property = ICSProperty(key: "UNTIL", parameters: [:], value: until)
            untilDate = parseDateValue(from: property)?.date
        }

        let count = attributes["COUNT"].flatMap(Int.init)

        return ICSRecurrenceRule(unit: unit, interval: interval, untilDate: untilDate, count: count)
    }

    private func fallbackUID(
        summary: String,
        description: String,
        startValue: ICSDateValue?,
        endValue: ICSDateValue?,
        dueValue: ICSDateValue?
    ) -> String {
        let parts = [
            summary,
            description,
            startValue.map { Self.identifierFormatter.string(from: $0.date) } ?? "",
            endValue.map { Self.identifierFormatter.string(from: $0.date) } ?? "",
            dueValue.map { Self.identifierFormatter.string(from: $0.date) } ?? ""
        ]
        return parts.joined(separator: "|")
    }

    private static let identifierFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct ICSEvent {
    let uid: String
    let title: String
    let detail: String
    let startValue: ICSDateValue?
    let endValue: ICSDateValue?
    let dueValue: ICSDateValue?
    let recurrenceRule: ICSRecurrenceRule?
    let recurrenceID: ICSDateValue?

    func makeDrafts(importedAt: Date, calendar: Calendar, horizonEnd: Date) -> [ICSImportedItemDraft] {
        let baseStart = resolvedStart(importedAt: importedAt, calendar: calendar)
        let baseEnd = resolvedEnd(startDate: baseStart, importedAt: importedAt, calendar: calendar)
        let isAllDay = startValue?.isDateOnly == true || endValue?.isDateOnly == true || dueValue?.isDateOnly == true
        let originalStartMissing = shouldUseImportedAtAsStart

        if let recurrenceID {
            let occurrenceStart = recurrenceID.date
            let duration = max(baseEnd.timeIntervalSince(baseStart), 1)
            let occurrenceEnd = occurrenceStart.addingTimeInterval(duration)
            return [
                ICSImportedItemDraft(
                    externalIdentifier: externalIdentifier(for: occurrenceStart),
                    title: title,
                    detail: detail,
                    startDate: occurrenceStart,
                    endDate: occurrenceEnd,
                    originalStartDateWasMissing: false,
                    isAllDay: isAllDay
                )
            ]
        }

        guard let recurrenceRule else {
            return [
                ICSImportedItemDraft(
                    externalIdentifier: externalIdentifier(for: startValue?.date ?? baseEnd),
                    title: title,
                    detail: detail,
                    startDate: baseStart,
                    endDate: baseEnd,
                    originalStartDateWasMissing: originalStartMissing,
                    isAllDay: isAllDay
                )
            ]
        }

        var drafts: [ICSImportedItemDraft] = []
        var occurrenceStart = baseStart
        var index = 0
        let duration = max(baseEnd.timeIntervalSince(baseStart), 1)
        while index < recurrenceRule.maxOccurrences {
            if let untilDate = recurrenceRule.untilDate, occurrenceStart > untilDate {
                break
            }
            if occurrenceStart > horizonEnd {
                break
            }

            drafts.append(
                ICSImportedItemDraft(
                    externalIdentifier: externalIdentifier(for: occurrenceStart),
                    title: title,
                    detail: detail,
                    startDate: occurrenceStart,
                    endDate: occurrenceStart.addingTimeInterval(duration),
                    originalStartDateWasMissing: originalStartMissing,
                    isAllDay: isAllDay
                )
            )

            guard let next = calendar.date(
                byAdding: recurrenceRule.unit.calendarComponent,
                value: recurrenceRule.interval,
                to: occurrenceStart
            ) else {
                break
            }
            occurrenceStart = next
            index += 1
        }

        return drafts
    }

    private var shouldUseImportedAtAsStart: Bool {
        if startValue == nil {
            return true
        }

        if let startValue, let dueValue, datesMatch(startValue.date, dueValue.date) {
            return true
        }

        if let startValue, let endValue, datesMatch(startValue.date, endValue.date) {
            return true
        }

        return false
    }

    private func resolvedStart(importedAt: Date, calendar: Calendar) -> Date {
        guard shouldUseImportedAtAsStart else {
            return startValue?.date ?? importedAt
        }

        guard let deadlineDate = deadlineDate(calendar: calendar) else {
            return importedAt
        }

        if importedAt < deadlineDate {
            return importedAt
        }

        if let oneMinuteBeforeDeadline = calendar.date(byAdding: .minute, value: -1, to: deadlineDate),
           oneMinuteBeforeDeadline < deadlineDate {
            return oneMinuteBeforeDeadline
        }

        return deadlineDate.addingTimeInterval(-1)
    }

    private func resolvedEnd(startDate: Date, importedAt: Date, calendar: Calendar) -> Date {
        if shouldUseImportedAtAsStart, let deadlineDateValue = preferredDeadlineValue {
            let dueDate = normalizedDeadlineDate(for: deadlineDateValue, calendar: calendar)
            return max(dueDate, startDate.addingTimeInterval(1))
        }

        if let endValue {
            if endValue.isDateOnly {
                return endValue.date
            }
            return max(endValue.date, startDate.addingTimeInterval(1))
        }

        if let dueValue {
            if dueValue.isDateOnly {
                let allDayDueEnd = calendar.date(byAdding: .day, value: 1, to: dueValue.date) ?? dueValue.date
                return max(allDayDueEnd, startDate.addingTimeInterval(1))
            }
            return max(dueValue.date, startDate.addingTimeInterval(1))
        }

        if startValue?.isDateOnly == true {
            return calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate.addingTimeInterval(60 * 60 * 24)
        }

        if startValue != nil {
            return calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate.addingTimeInterval(60 * 60)
        }

        return calendar.date(byAdding: .hour, value: 1, to: importedAt) ?? importedAt.addingTimeInterval(60 * 60)
    }

    private var preferredDeadlineValue: ICSDateValue? {
        dueValue ?? endValue ?? startValue
    }

    private func deadlineDate(calendar: Calendar) -> Date? {
        preferredDeadlineValue.map { normalizedDeadlineDate(for: $0, calendar: calendar) }
    }

    private func normalizedDeadlineDate(for value: ICSDateValue, calendar: Calendar) -> Date {
        if value.isDateOnly {
            return calendar.date(byAdding: .day, value: 1, to: value.date) ?? value.date
        }
        return value.date
    }

    private func datesMatch(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 1
    }

    private func externalIdentifier(for occurrenceDate: Date) -> String {
        "\(uid)#\(Self.identifierFormatter.string(from: occurrenceDate))"
    }

    private static let identifierFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct ICSDateValue {
    let date: Date
    let isDateOnly: Bool
}

private struct ICSRecurrenceRule {
    let unit: DeadlineRepeatUnit
    let interval: Int
    let untilDate: Date?
    let count: Int?

    var maxOccurrences: Int {
        min(count ?? 512, 512)
    }
}

private struct ICSProperty {
    let key: String
    let parameters: [String: String]
    let value: String

    init?(line: String) {
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }
        let leftPart = String(line[..<colonIndex])
        value = String(line[line.index(after: colonIndex)...])

        let segments = leftPart.split(separator: ";").map(String.init)
        guard let rawKey = segments.first else { return nil }
        key = rawKey.uppercased()

        var parsedParameters: [String: String] = [:]
        for parameter in segments.dropFirst() {
            let parts = parameter.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            parsedParameters[parts[0].uppercased()] = parts[1]
        }
        parameters = parsedParameters
    }

    init(key: String, parameters: [String: String], value: String) {
        self.key = key
        self.parameters = parameters
        self.value = value
    }

    var decodedText: String {
        value
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedIdentifier: String {
        decodedText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element == ICSProperty {
    func firstValue(for key: String) -> String? {
        first(where: { $0.key == key })?.value
    }

    func first(for key: String) -> ICSProperty? {
        first(where: { $0.key == key })
    }
}
