import SwiftUI

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
    @State private var showError = false

    init(store: DeadlineStore, draft: NewDeadlineDraft = NewDeadlineDraft()) {
        self.store = store

        let now = Date.now
        _title = State(initialValue: draft.title)
        _selectedGroup = State(initialValue: draft.category)
        _detail = State(initialValue: draft.detail)
        _startDate = State(initialValue: now)
        _endDate = State(initialValue: Calendar.current.date(byAdding: .hour, value: 4, to: now) ?? now)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        languageManager.currentLanguage.text(english, chinese)
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
                } header: {
                    Text(t("Time", "时间设置"))
                }

                if showError {
                    Text(t("Title cannot be empty, and end time must be later than start time.", "请保证标题不为空，且结束时间晚于起始时间。"))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(t("New Task", "新建事项"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("Cancel", "取消")) { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Save", "保存")) { save() }
                        .bold()
                }
            }
            .onAppear {
                if selectedGroup.isEmpty {
                    selectedGroup = store.groups.first ?? DeadlineStore.fallbackGroupName
                }
            }
            .onChange(of: store.groups) { _, groups in
                if !groups.contains(selectedGroup) {
                    selectedGroup = groups.first ?? DeadlineStore.fallbackGroupName
                }
            }
        }
    }

    private func save() {
        guard
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            endDate > startDate
        else {
            showError = true
            return
        }
        store.addItem(
            title: title,
            category: selectedGroup,
            detail: detail,
            startDate: startDate,
            endDate: endDate
        )
        dismiss()
    }
}
