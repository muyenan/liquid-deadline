import SwiftUI
import UniformTypeIdentifiers

struct NewDeadlineDraft: Identifiable {
    let id: UUID
    let title: String
    let category: String
    let detail: String

    init(id: UUID = UUID(), title: String = "", category: String = "", detail: String = "") {
        self.id = id
        self.title = title
        self.category = category
        self.detail = detail
    }

    init(item: DeadlineItem) {
        self.init(
            title: item.title,
            category: item.category,
            detail: item.detail
        )
    }
}

struct NewDeadlineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject var store: DeadlineStore

    @State private var title: String
    @State private var selectedGroup: String
    @State private var detail: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var reminders: [DeadlineReminder] = []
    @State private var selectedReminder: ReminderSelection?
    @State private var repeatSelection: RepeatMenuSelection = .none
    @State private var customRepeatUnit: DeadlineRepeatUnit = .day
    @State private var customRepeatInterval = 1
    @State private var repeatEndMode: RepeatEndMode = .never
    @State private var repeatEndDate: Date
    @State private var showingIntervalPicker = false
    @State private var showValidationError = false
    @State private var actionErrorMessage: String?
    @State private var showingURLSubscriptionSheet = false
    @State private var showingFileImportSetup = false
    @State private var showingFileImporter = false
    @State private var importCategory = ""

    init(store: DeadlineStore, draft: NewDeadlineDraft = NewDeadlineDraft()) {
        self.store = store

        let now = Date.now
        _title = State(initialValue: draft.title)
        _selectedGroup = State(initialValue: draft.category)
        _detail = State(initialValue: draft.detail)
        _startDate = State(initialValue: now)
        _endDate = State(initialValue: Calendar.current.date(byAdding: .hour, value: 4, to: now) ?? now)
        _repeatEndDate = State(initialValue: now)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        languageManager.currentLanguage.text(english, chinese)
    }

    private var isRepeating: Bool {
        repeatSelection != .none
    }

    private var repeatSummaryText: String {
        switch repeatSelection {
        case .none:
            return t("Never", "永不")
        case .daily:
            return t("Every Day", "每天")
        case .weekly:
            return t("Every Week", "每周")
        case .biweekly:
            return t("Every 2 Weeks", "每两周")
        case .monthly:
            return t("Every Month", "每月")
        case .yearly:
            return t("Every Year", "每年")
        case .custom:
            return t("Custom", "自定义")
        }
    }

    private var repeatIntervalSummaryText: String {
        languageManager.currentLanguage.repeatIntervalSummary(
            interval: customRepeatInterval,
            unit: customRepeatUnit
        )
    }

    private var repeatRule: DeadlineRepeatRule? {
        switch repeatSelection {
        case .none:
            return nil
        case .daily:
            return DeadlineRepeatRule(interval: 1, unit: .day, endDate: effectiveRepeatEndDate)
        case .weekly:
            return DeadlineRepeatRule(interval: 1, unit: .week, endDate: effectiveRepeatEndDate)
        case .biweekly:
            return DeadlineRepeatRule(interval: 2, unit: .week, endDate: effectiveRepeatEndDate)
        case .monthly:
            return DeadlineRepeatRule(interval: 1, unit: .month, endDate: effectiveRepeatEndDate)
        case .yearly:
            return DeadlineRepeatRule(interval: 1, unit: .year, endDate: effectiveRepeatEndDate)
        case .custom:
            return DeadlineRepeatRule(interval: customRepeatInterval, unit: customRepeatUnit, endDate: effectiveRepeatEndDate)
        }
    }

    private var effectiveRepeatEndDate: Date? {
        guard repeatEndMode == .onDate else { return nil }
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: repeatEndDate)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: startDate)

        var mergedComponents = DateComponents()
        mergedComponents.year = dayComponents.year
        mergedComponents.month = dayComponents.month
        mergedComponents.day = dayComponents.day
        mergedComponents.hour = timeComponents.hour
        mergedComponents.minute = timeComponents.minute
        mergedComponents.second = timeComponents.second
        return calendar.date(from: mergedComponents) ?? repeatEndDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(t("Title", "标题"), text: $title)
                    Picker(t("Category", "分类"), selection: $selectedGroup) {
                        ForEach(store.groups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("Description", "描述"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $detail)
                            .frame(minHeight: 90)
                    }
                } header: {
                    Text(t("Task Info", "事项信息"))
                }

                Section {
                    DatePicker(t("Start Time", "起始时间"), selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker(t("End Time", "结束时间"), selection: $endDate, displayedComponents: [.date, .hourAndMinute])

                    Toggle(isOn: repeatEnabledBinding) {
                        Text(t("Repeat", "重复"))
                    }

                    if isRepeating {
                        LabeledContent(t("Repeat Rule", "重复规则")) {
                            repeatMenu
                        }

                        if repeatSelection == .custom {
                            LabeledContent(t("Frequency Unit", "频率单位")) {
                                customUnitMenu
                            }

                            LabeledContent(t("Every", "每")) {
                                Button(repeatIntervalSummaryText) {
                                    showingIntervalPicker = true
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        LabeledContent(t("End Repeat", "结束重复")) {
                            repeatEndMenu
                        }

                        if repeatEndMode == .onDate {
                            DatePicker(
                                t("End Date", "结束日期"),
                                selection: $repeatEndDate,
                                in: startDate...,
                                displayedComponents: .date
                            )
                        }
                    }
                } header: {
                    Text(t("Time", "时间设置"))
                }

                Section {
                    ReminderListEditor(
                        language: languageManager.currentLanguage,
                        reminders: $reminders,
                        selectedReminder: $selectedReminder
                    )
                } header: {
                    Text(languageManager.currentLanguage.reminderTitle)
                }

                Section {
                    ImportActionButton(
                        title: t("Use URL Subscription", "使用URL订阅"),
                        subtitle: t("Subscribe to an external calendar feed.", "通过外部日历链接订阅事项。"),
                        systemImage: "link.badge.plus"
                    ) {
                        showingURLSubscriptionSheet = true
                    }

                    ImportActionButton(
                        title: t("Select File to Import", "选取文件导入"),
                        subtitle: t("Import tasks from a standard .ics file.", "通过标准 .ics 文件导入事项。"),
                        systemImage: "doc.badge.plus"
                    ) {
                        importCategory = selectedGroup
                        showingFileImportSetup = true
                    }
                } header: {
                    Text(t("Calendar Import", "日历导入"))
                }

                if showValidationError {
                    Text(t("Title cannot be empty, and end time must be later than start time.", "请保证标题不为空，且结束时间晚于起始时间。"))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(t("New Task", "新建事项"))
            .overlay {
                if let selectedReminder {
                    ReminderWheelPickerOverlay(
                        language: languageManager.currentLanguage,
                        reminder: $reminders.reminderBinding(for: selectedReminder.id)
                    ) {
                        self.selectedReminder = nil
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("Cancel", "取消")) { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Save", "保存")) { save() }
                        .bold()
                }
            }
            .sheet(isPresented: $showingURLSubscriptionSheet) {
                URLSubscriptionSheet(
                    store: store,
                    initialGroup: selectedGroup
                ) {
                    dismiss()
                }
                .environmentObject(languageManager)
            }
            .sheet(isPresented: $showingFileImportSetup) {
                FileImportSetupSheet(
                    groups: store.groups,
                    initialGroup: importCategory.isEmpty ? selectedGroup : importCategory
                ) { chosenGroup in
                    importCategory = chosenGroup
                    showingFileImportSetup = false
                    DispatchQueue.main.async {
                        showingFileImporter = true
                    }
                }
                .environmentObject(languageManager)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.icsCalendar],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showingIntervalPicker) {
                RepeatIntervalPickerSheet(
                    selectedValue: $customRepeatInterval,
                    title: t("Every", "每")
                )
                .presentationDetents([.height(280)])
            }
            .alert(t("Import Failed", "导入失败"), isPresented: actionErrorBinding) {
                Button(t("OK", "好的"), role: .cancel) {
                    actionErrorMessage = nil
                }
            } message: {
                Text(actionErrorMessage ?? "")
            }
            .onAppear {
                syncSelectedGroupsIfNeeded(with: store.groups)
            }
            .onChange(of: store.groups) { _, groups in
                syncSelectedGroupsIfNeeded(with: groups)
            }
            .onChange(of: repeatEndDate) { _, newValue in
                if newValue < startDate {
                    repeatEndDate = startDate
                }
            }
            .onChange(of: startDate) { _, newValue in
                if repeatEndDate < newValue {
                    repeatEndDate = newValue
                }
            }
        }
    }

    private var repeatEnabledBinding: Binding<Bool> {
        Binding(
            get: { isRepeating },
            set: { newValue in
                if newValue {
                    if repeatSelection == .none {
                        repeatSelection = .daily
                    }
                } else {
                    repeatSelection = .none
                }
            }
        )
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { actionErrorMessage != nil },
            set: { newValue in
                if newValue == false {
                    actionErrorMessage = nil
                }
            }
        )
    }

    private var repeatMenu: some View {
        Menu {
            Button(t("Never", "永不")) { repeatSelection = .none }
            Button(t("Every Day", "每天")) { repeatSelection = .daily }
            Button(t("Every Week", "每周")) { repeatSelection = .weekly }
            Button(t("Every 2 Weeks", "每两周")) { repeatSelection = .biweekly }
            Button(t("Every Month", "每月")) { repeatSelection = .monthly }
            Button(t("Every Year", "每年")) { repeatSelection = .yearly }
            Divider()
            Button(t("Custom", "自定义")) { repeatSelection = .custom }
        } label: {
            HStack(spacing: 6) {
                Text(repeatSummaryText)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(Color.accentColor)
        }
    }

    private var customUnitMenu: some View {
        Menu {
            ForEach(DeadlineRepeatUnit.allCases) { unit in
                Button(unit.title(in: languageManager.currentLanguage)) {
                    customRepeatUnit = unit
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(customRepeatUnit.title(in: languageManager.currentLanguage))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(Color.accentColor)
        }
    }

    private var repeatEndMenu: some View {
        Menu {
            Button(t("Never", "永不")) { repeatEndMode = .never }
            Button(t("On Date", "于日期")) { repeatEndMode = .onDate }
        } label: {
            HStack(spacing: 6) {
                Text(repeatEndMode.title(in: languageManager.currentLanguage))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(Color.accentColor)
        }
    }

    private func syncSelectedGroupsIfNeeded(with groups: [String]) {
        if selectedGroup.isEmpty || groups.contains(selectedGroup) == false {
            selectedGroup = groups.first ?? DeadlineStore.fallbackGroupName
        }
        if importCategory.isEmpty || groups.contains(importCategory) == false {
            importCategory = groups.first ?? DeadlineStore.fallbackGroupName
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            let securityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            try store.importICSFile(data: data, category: importCategory, importedAt: .now)
            dismiss()
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard
            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            endDate > startDate
        else {
            showValidationError = true
            return
        }

        store.addItem(
            title: title,
            category: selectedGroup,
            detail: detail,
            startDate: startDate,
            endDate: endDate,
            reminders: reminders,
            repeatRule: repeatRule
        )
        dismiss()
    }
}

private enum RepeatMenuSelection {
    case none
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly
    case custom
}

private enum RepeatEndMode {
    case never
    case onDate

    func title(in language: AppLanguage) -> String {
        switch self {
        case .never:
            return language.text("Never", "永不")
        case .onDate:
            return language.text("On Date", "于日期")
        }
    }
}

private struct ImportActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct URLSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject var store: DeadlineStore

    let initialGroup: String
    let onSuccess: () -> Void

    @State private var urlText = ""
    @State private var selectedGroup = ""
    @State private var reminders: [DeadlineReminder] = []
    @State private var selectedReminder: ReminderSelection?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private func t(_ english: String, _ chinese: String) -> String {
        languageManager.currentLanguage.text(english, chinese)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/calendar.ics", text: $urlText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)

                    Picker(t("Category", "分类"), selection: $selectedGroup) {
                        ForEach(store.groups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                } header: {
                    Text(t("Subscription", "订阅"))
                } footer: {
                    Text(t("If an event in the feed has no start time, the import time is used as the start time. Future refreshes keep the first seen start time.", "如果订阅里的事件没有开始时间，会使用首次导入时间作为开始时间；后续刷新会保留第一次出现时的开始时间。"))
                }

                Section {
                    ReminderListEditor(
                        language: languageManager.currentLanguage,
                        reminders: $reminders,
                        selectedReminder: $selectedReminder
                    )
                } header: {
                    Text(languageManager.currentLanguage.reminderTitle)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(t("Use URL Subscription", "使用URL订阅"))
            .overlay {
                if let selectedReminder {
                    ReminderWheelPickerOverlay(
                        language: languageManager.currentLanguage,
                        reminder: $reminders.reminderBinding(for: selectedReminder.id)
                    ) {
                        self.selectedReminder = nil
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("Cancel", "取消")) { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        subscribe()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(t("Subscribe", "订阅"))
                                .bold()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                selectedGroup = store.groups.contains(initialGroup) ? initialGroup : (store.groups.first ?? DeadlineStore.fallbackGroupName)
            }
        }
    }

    private func subscribe() {
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedURL.isEmpty == false else {
            errorMessage = t("Please enter a valid URL.", "请输入有效的 URL。")
            return
        }

        errorMessage = nil
        isSaving = true

        Task {
            do {
                try await store.addSubscription(
                    urlString: trimmedURL,
                    category: selectedGroup,
                    reminders: reminders
                )
                isSaving = false
                dismiss()
                onSuccess()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private struct FileImportSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    let groups: [String]
    let initialGroup: String
    let onContinue: (String) -> Void

    @State private var selectedGroup = ""

    private func t(_ english: String, _ chinese: String) -> String {
        languageManager.currentLanguage.text(english, chinese)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(t("Category", "分类"), selection: $selectedGroup) {
                        ForEach(groups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                } header: {
                    Text(t("Import Options", "导入选项"))
                } footer: {
                    Text(t("If an imported event has no start time, the import time is used as the start time.", "如果导入的事件没有开始时间，会使用导入时刻作为开始时间。"))
                }
            }
            .navigationTitle(t("Select File to Import", "选取文件导入"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("Cancel", "取消")) { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Choose File", "选择文件")) {
                        onContinue(selectedGroup)
                    }
                    .bold()
                }
            }
            .onAppear {
                selectedGroup = groups.contains(initialGroup) ? initialGroup : (groups.first ?? DeadlineStore.fallbackGroupName)
            }
        }
    }
}

private struct RepeatIntervalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    @Binding var selectedValue: Int

    let title: String

    private func t(_ english: String, _ chinese: String) -> String {
        languageManager.currentLanguage.text(english, chinese)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(title, selection: $selectedValue) {
                    ForEach(1...999, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Done", "完成")) { dismiss() }
                }
            }
        }
    }
}

private extension UTType {
    static var icsCalendar: UTType {
        UTType(filenameExtension: "ics") ?? .data
    }
}
