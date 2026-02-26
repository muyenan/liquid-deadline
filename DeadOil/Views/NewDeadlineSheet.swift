import SwiftUI

struct NewDeadlineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DeadlineStore

    @State private var title: String = ""
    @State private var selectedGroup: String = ""
    @State private var detail: String = ""
    @State private var startDate: Date = .now
    @State private var endDate: Date = Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("事项信息") {
                    TextField("标题", text: $title)
                    Picker("分类", selection: $selectedGroup) {
                        ForEach(store.groups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("描述")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $detail)
                            .frame(minHeight: 90)
                    }
                }

                Section("时间设置") {
                    DatePicker("起始时间", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("结束时间", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }

                if showError {
                    Text("请保证标题不为空，且结束时间晚于起始时间。")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("新建事项")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .bold()
                }
            }
            .onAppear {
                if selectedGroup.isEmpty {
                    selectedGroup = store.groups.first ?? "未分类"
                }
            }
            .onChange(of: store.groups) { _, groups in
                if !groups.contains(selectedGroup) {
                    selectedGroup = groups.first ?? "未分类"
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
