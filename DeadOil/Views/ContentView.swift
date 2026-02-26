import SwiftUI

struct ContentView: View {
    @StateObject private var store = DeadlineStore()
    @State private var motion = MotionManager()
    @State private var showingCreateSheet = false
    @State private var showingSettingsSheet = false
    @State private var editingItem: DeadlineItem?
    
    private var usesLightText: Bool {
        store.backgroundStyle.usesLightForeground
    }

    var body: some View {
        TabView {
            ForEach(DeadlineSection.allCases) { section in
                NavigationStack {
                    ZStack {
                        LiquidBackgroundView(
                            backgroundStyle: store.backgroundStyle
                        )

                        ScrollView {
                            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                                let currentNow = timeline.date
                                VStack(spacing: 14) {
                                    DeadlineSectionView(
                                        section: section,
                                        items: store.items(in: section, at: currentNow),
                                        style: store.viewStyle,
                                        now: currentNow,
                                        usesLightText: usesLightText,
                                        liquidMotionEnabled: store.liquidMotionEnabled,
                                        onSelectItem: { item in
                                            editingItem = item
                                        }
                                    )
                                }
                                .padding(14)
                                .padding(.bottom, 22)
                            }
                        }
                    }
                    .navigationTitle(section.rawValue)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            topMenu
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingSettingsSheet = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .fontWeight(.semibold)
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingCreateSheet = true
                            } label: {
                                Image(systemName: "plus")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .tabItem {
                    Label(section.rawValue, systemImage: section.tabIcon)
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            NewDeadlineSheet(store: store)
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView(store: store)
        }
        .sheet(item: $editingItem) { item in
            EditDeadlineSheet(
                item: item,
                groups: store.groups,
                onSave: { id, title, category, detail, startDate, endDate in
                    store.updateItem(
                        id: id,
                        title: title,
                        category: category,
                        detail: detail,
                        startDate: startDate,
                        endDate: endDate
                    )
                },
                onDelete: { id in
                    store.removeItem(id: id)
                }
            )
        }
        .environmentObject(motion)
    }

    private var topMenu: some View {
        Menu {
            Button {
                commitMenuSelection {
                    store.sortOption = .recentAdded
                }
            } label: {
                MenuCheckRow(
                    title: DeadlineSortOption.recentAdded.rawValue,
                    systemImage: nil,
                    isSelected: store.sortOption == .recentAdded
                )
            }

            Button {
                commitMenuSelection {
                    store.sortOption = .byDate
                }
            } label: {
                MenuCheckRow(
                    title: DeadlineSortOption.byDate.rawValue,
                    systemImage: nil,
                    isSelected: store.sortOption == .byDate
                )
            }

            Divider()

            Menu {
                Button {
                    commitMenuSelection {
                        store.selectedFilterGroup = nil
                    }
                } label: {
                    MenuCheckRow(
                        title: "全部",
                        systemImage: nil,
                        isSelected: store.selectedFilterGroup == nil
                    )
                }

                ForEach(store.groups, id: \.self) { group in
                    Button {
                        commitMenuSelection {
                            store.selectedFilterGroup = group
                        }
                    } label: {
                        MenuCheckRow(
                            title: group,
                            systemImage: nil,
                            isSelected: store.selectedFilterGroup == group
                        )
                    }
                }
            } label: {
                Text("筛选")
            }

            Menu {
                Button {
                    commitMenuSelection {
                        store.setViewStyle(.progressBar)
                    }
                } label: {
                    MenuCheckRow(
                        title: "进度条视图",
                        systemImage: DeadlineViewStyle.progressBar.menuIcon,
                        isSelected: store.viewStyle == .progressBar
                    )
                }

                Button {
                    commitMenuSelection {
                        store.setViewStyle(.grid)
                    }
                } label: {
                    MenuCheckRow(
                        title: "网格视图",
                        systemImage: DeadlineViewStyle.grid.menuIcon,
                        isSelected: store.viewStyle == .grid
                    )
                }
            } label: {
                Text("显示选项")
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .fontWeight(.semibold)
        }
    }

    private func commitMenuSelection(_ action: @escaping () -> Void) {
        DispatchQueue.main.async(execute: action)
    }
}

private struct MenuCheckRow: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool

    var body: some View {
        HStack {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
            Spacer(minLength: 16)
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}

private extension DeadlineViewStyle {
    var menuIcon: String {
        switch self {
        case .progressBar:
            return "list.bullet"
        case .grid:
            return "square.grid.2x2"
        }
    }
}

private extension DeadlineSection {
    var tabIcon: String {
        switch self {
        case .notStarted:
            return "clock"
        case .inProgress:
            return "drop.fill"
        case .finished:
            return "checkmark.circle.fill"
        }
    }
}

private struct DeadlineSectionView: View {
    let section: DeadlineSection
    let items: [DeadlineItem]
    let style: DeadlineViewStyle
    let now: Date
    let usesLightText: Bool
    let liquidMotionEnabled: Bool
    let onSelectItem: (DeadlineItem) -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var primaryTextColor: Color {
        usesLightText ? .white : .black
    }

    private var secondaryTextColor: Color {
        usesLightText ? .white.opacity(0.75) : .black.opacity(0.72)
    }

    private var badgeBackground: Color {
        usesLightText ? .white.opacity(0.2) : .black.opacity(0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.rawValue)
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)
                Spacer()
                Text("\(items.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeBackground, in: Capsule())
            }

            if items.isEmpty {
                Text("暂无事项")
                    .font(.footnote)
                    .foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else if style == .progressBar {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        DeadlineRowView(
                            item: item,
                            now: now,
                            usesLightText: usesLightText,
                            onTap: { onSelectItem(item) }
                        )
                    }
                }
            } else {
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(items) { item in
                        OilGridCellView(
                            item: item,
                            now: now,
                            usesLightText: usesLightText,
                            liquidMotionEnabled: liquidMotionEnabled,
                            onTap: { onSelectItem(item) }
                        )
                    }
                }
            }
        }
        .liquidGlassCard(cornerRadius: 22)
    }
}

private struct DeadlineRowView: View {
    let item: DeadlineItem
    let now: Date
    let usesLightText: Bool
    let onTap: () -> Void

    private var section: DeadlineSection {
        item.section(at: now)
    }

    private var progress: Double {
        item.progress(at: now)
    }

    private var liquidTint: Color {
        item.progressTint(at: now)
    }

    private var statusText: String {
        switch section {
        case .notStarted:
            return "距开始 \(Self.durationText(from: now, to: item.startDate))"
        case .inProgress:
            return "剩余 \(Self.durationText(from: now, to: item.endDate))"
        case .finished:
            return "已结束"
        }
    }

    private var primaryTextColor: Color {
        usesLightText ? .white : .black
    }

    private var secondaryTextColor: Color {
        usesLightText ? .white.opacity(0.8) : .black.opacity(0.78)
    }

    private var tertiaryTextColor: Color {
        usesLightText ? .white.opacity(0.72) : .black.opacity(0.68)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)
                        Text(item.category)
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                    }
                    Spacer()
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryTextColor)
                }

                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(2)
                }

                OilProgressBarView(progress: progress, tint: liquidTint)

                HStack {
                    Text("起 \(item.startDate.formatted(date: .omitted, time: .shortened))")
                    Spacer()
                    Text("止 \(item.endDate.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.caption2)
                .foregroundStyle(tertiaryTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .liquidGlassCard(cornerRadius: 16)
    }

    private static func durationText(from now: Date, to target: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        let interval = max(target.timeIntervalSince(now), 0)
        return formatter.string(from: interval) ?? "0m"
    }
}

private struct EditDeadlineSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: DeadlineItem
    let groups: [String]
    let onSave: (UUID, String, String, String, Date, Date) -> Void
    let onDelete: (UUID) -> Void

    @State private var title: String = ""
    @State private var selectedGroup: String = ""
    @State private var detail: String = ""
    @State private var startDate: Date = .now
    @State private var endDate: Date = .now
    @State private var showError = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("事项信息") {
                    TextField("标题", text: $title)
                    Picker("分类", selection: $selectedGroup) {
                        ForEach(groups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("描述")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $detail)
                            .frame(minHeight: 110)
                    }
                }

                Section("时间设置") {
                    DatePicker("起始时间", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("结束时间", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    Button("删除事项", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .confirmationDialog("确认删除该事项？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                        Button("删除", role: .destructive) {
                            onDelete(item.id)
                            dismiss()
                        }
                        Button("取消", role: .cancel) { }
                    }
                }

                if showError {
                    Text("请保证标题不为空，且结束时间晚于起始时间。")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("编辑事项")
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
                title = item.title
                detail = item.detail
                startDate = item.startDate
                endDate = item.endDate
                selectedGroup = groups.contains(item.category) ? item.category : (groups.first ?? "未分类")
            }
            .onChange(of: groups) { _, newGroups in
                if !newGroups.contains(selectedGroup) {
                    selectedGroup = newGroups.first ?? "未分类"
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
        onSave(item.id, title, selectedGroup, detail, startDate, endDate)
        dismiss()
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DeadlineStore

    @State private var newGroupName: String = ""
    @State private var renameTargetGroup: String?
    @State private var renameInputText: String = ""
    @State private var showingRenameAlert = false

    private var canAddGroup: Bool {
        !newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("背景") {
                    Picker("背景样式", selection: $store.backgroundStyle) {
                        ForEach(BackgroundStyleOption.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                }

                Section {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            TextField("新增分组", text: $newGroupName)
                                .textFieldStyle(.plain)
                                .submitLabel(.done)
                                .onSubmit {
                                    guard canAddGroup else { return }
                                    store.addGroup(name: newGroupName)
                                    newGroupName = ""
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                store.addGroup(name: newGroupName)
                                newGroupName = ""
                            } label: {
                                Text("添加")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(canAddGroup ? Color.accentColor : Color.gray)
                            .background(
                                Capsule()
                                    .fill((canAddGroup ? Color.accentColor : Color.gray).opacity(0.14))
                            )
                            .disabled(!canAddGroup)
                        }
                        .frame(minHeight: 48)
                        .padding(.horizontal, 14)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(uiColor: .separator).opacity(0.22), lineWidth: 0.6)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

                    ForEach(store.groups, id: \.self) { group in
                        GroupTagRow(
                            group: group
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(uiColor: .separator).opacity(0.22), lineWidth: 0.6)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .contextMenu {
                            Button("编辑 \(group)", systemImage: "pencil") {
                                renameTargetGroup = group
                                renameInputText = group
                                showingRenameAlert = true
                            }

                            if store.groups.count > 1 {
                                Button("删除 \(group)", systemImage: "trash", role: .destructive) {
                                    store.removeGroup(named: group)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if store.groups.count > 1 {
                                Button(role: .destructive) {
                                    store.removeGroup(named: group)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("分组")
                } footer: {
                    Text("标签支持长按编辑/删除，也支持左滑删除。至少保留一个分组。")
                }

                Section {
                    Toggle("液态动效", isOn: $store.liquidMotionEnabled)
                } header: {
                    Text("动效")
                } footer: {
                    Text("关闭后，网格视图中的液体将不再随手机晃动变化。")
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("编辑分组：\(renameTargetGroup ?? "")", isPresented: $showingRenameAlert) {
                TextField("分组名称", text: $renameInputText)
                Button("取消", role: .cancel) { }
                Button("保存") {
                    guard let oldName = renameTargetGroup else { return }
                    store.renameGroup(from: oldName, to: renameInputText)
                }
            }
        }
    }
}

private struct GroupTagRow: View {
    let group: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag")
                .foregroundStyle(.secondary)
            Text(group)
            Spacer()
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }
}
