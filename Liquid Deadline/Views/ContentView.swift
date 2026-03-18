import SwiftUI
import CloudKit

struct ContentView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("deadline_selected_section_v1") private var selectedSectionStorage = DeadlineSection.inProgress.storageValue
    @ObservedObject var store: DeadlineStore
    @State private var motion = MotionManager()
    @State private var createDraft: NewDeadlineDraft?
    @State private var showingSettingsSheet = false
    @State private var editingItem: DeadlineItem?

    private var usesLightText: Bool {
        store.backgroundStyle.usesLightForeground
    }

    private var language: AppLanguage {
        languageManager.currentLanguage
    }

    private func t(_ english: String, _ chinese: String) -> String {
        language.text(english, chinese)
    }

    private var selectedSectionBinding: Binding<DeadlineSection> {
        Binding(
            get: { DeadlineSection(storageValue: selectedSectionStorage) },
            set: { selectedSectionStorage = $0.storageValue }
        )
    }

    private var syncErrorBinding: Binding<Bool> {
        Binding(
            get: { store.lastSyncErrorMessage != nil },
            set: { newValue in
                if newValue == false {
                    store.lastSyncErrorMessage = nil
                }
            }
        )
    }

    private var cloudAccountPromptBinding: Binding<Bool> {
        Binding(
            get: { store.pendingCloudAccountPrompt != nil },
            set: { newValue in
                if newValue == false {
                    store.pendingCloudAccountPrompt = nil
                }
            }
        )
    }

    var body: some View {
        TabView(selection: selectedSectionBinding) {
            ForEach(DeadlineSection.allCases) { section in
                NavigationStack {
                    ZStack {
                        LiquidBackgroundView(
                            backgroundStyle: store.backgroundStyle
                        )

                        ScrollView {
                            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                                let currentNow = timeline.date
                                let sectionItems = store.items(in: section, at: currentNow)
                                VStack(alignment: .leading, spacing: 14) {
                                    SectionPageHeaderView(
                                        section: section,
                                        itemCount: sectionItems.count,
                                        usesLightText: usesLightText
                                    )

                                    DeadlineSectionView(
                                        items: sectionItems,
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
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            topMenu
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            subscriptionRefreshButton
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
                                createDraft = NewDeadlineDraft()
                            } label: {
                                Image(systemName: "plus")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .tabItem {
                    Label(section.title(in: language), systemImage: section.tabIcon)
                }
                .tag(section)
            }
        }
        .sheet(item: $createDraft) { draft in
            NewDeadlineSheet(store: store, draft: draft)
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView(store: store)
        }
        .sheet(item: $editingItem) { item in
            EditDeadlineSheet(
                item: item,
                groups: store.groups,
                onSaveActive: { baseItem, title, category, detail, startDate, endDate, scope in
                    store.updateItem(
                        baseItem: baseItem,
                        title: title,
                        category: category,
                        detail: detail,
                        startDate: startDate,
                        endDate: endDate,
                        scope: scope
                    )
                },
                onSaveClosedDetail: { baseItem, detail in
                    store.updateClosedItemDetail(baseItem: baseItem, detail: detail)
                },
                onComplete: { id in
                    store.completeItem(id: id)
                },
                onApplyLocalConflictResolution: { conflict in
                    store.applyLocalConflictResolution(conflict)
                },
                onCreateNew: { draft in
                    createDraft = draft
                },
                onMarkIncomplete: { id in
                    if let destination = store.markItemIncomplete(id: id) {
                        selectedSectionStorage = destination.storageValue
                    }
                },
                onDelete: { id, scope in
                    store.removeItem(id: id, scope: scope)
                }
            )
        }
        .alert(t("Sync Failed", "同步失败"), isPresented: syncErrorBinding) {
            Button(t("OK", "好的"), role: .cancel) {
                store.lastSyncErrorMessage = nil
            }
        } message: {
            Text(store.lastSyncErrorMessage ?? "")
        }
        .confirmationDialog(
            t("Detected an iCloud account change", "检测到 iCloud 账号发生变化"),
            isPresented: cloudAccountPromptBinding,
            titleVisibility: .visible
        ) {
            Button(t("Merge Local Data and Sync", "合并本地数据并同步")) {
                Task {
                    await store.resolveCloudAccountPromptByMerging()
                }
            }
            Button(t("Delete Local Data and Resync", "删除本地数据并重新同步"), role: .destructive) {
                Task {
                    await store.resolveCloudAccountPromptByReplacingLocalData()
                }
            }
            Button(t("Turn Off Automatic Sync", "关闭自动同步"), role: .cancel) {
                store.resolveCloudAccountPromptByDisablingSync()
            }
        } message: {
            Text(
                t(
                    "A different iCloud account is now available. Choose whether to merge your local data into the current account, clear local synced data and download from iCloud again, or keep data local with automatic sync turned off.",
                    "当前检测到可用的 iCloud 账号与之前不同。请选择将本地数据与当前账号合并、清空本地可同步数据并重新从 iCloud 拉取，或仅保留本地数据并关闭自动同步。"
                )
            )
        }
        .environmentObject(motion)
        .onAppear {
            store.applyDefaultGroupLocalizationIfNeeded(language: languageManager.currentLanguage)
            if let syncedLanguageSelection = store.syncedLanguageSelection,
               syncedLanguageSelection != languageManager.currentLanguage {
                languageManager.applySyncedLanguage(syncedLanguageSelection)
            }
            store.handleLocalLanguageSelectionChange(languageManager.currentLanguage)
            store.extendRecurringItemsIfNeeded(at: .now)
            Task {
                await store.refreshCloudAccountStatusIfNeeded()
                await store.refreshSubscriptionsIfNeeded(now: .now)
            }
        }
        .onChange(of: languageManager.currentLanguage) { _, newLanguage in
            store.applyDefaultGroupLocalizationIfNeeded(language: newLanguage)
            store.handleLocalLanguageSelectionChange(newLanguage)
        }
        .onChange(of: store.syncedLanguageSelection) { _, newLanguage in
            guard let newLanguage, newLanguage != languageManager.currentLanguage else { return }
            languageManager.applySyncedLanguage(newLanguage)
        }
    }

    private var topMenu: some View {
        Menu {
            ForEach(DeadlineSortOption.allCases) { option in
                Button {
                    commitMenuSelection {
                        store.sortOption = option
                    }
                } label: {
                    MenuCheckRow(
                        title: option.title(in: language),
                        systemImage: nil,
                        isSelected: store.sortOption == option
                    )
                }
            }

            Divider()

            Menu {
                Button {
                    commitMenuSelection {
                        store.selectedFilterGroup = nil
                    }
                } label: {
                    MenuCheckRow(
                        title: t("All", "全部"),
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
                Text(t("Filter", "筛选"))
            }

            Menu {
                Button {
                    commitMenuSelection {
                        store.setViewStyle(.progressBar)
                    }
                } label: {
                    MenuCheckRow(
                        title: t("Progress Bar View", "进度条视图"),
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
                        title: t("Grid View", "网格视图"),
                        systemImage: DeadlineViewStyle.grid.menuIcon,
                        isSelected: store.viewStyle == .grid
                    )
                }
            } label: {
                Text(t("Display Options", "显示选项"))
            }

            Divider()

            Button {
                Task {
                    await store.refreshSubscriptions(force: true, now: .now)
                }
            } label: {
                Label(t("Refresh Subscriptions", "刷新订阅"), systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .fontWeight(.semibold)
        }
    }

    private var subscriptionRefreshButton: some View {
        Group {
            if store.isRefreshingSubscriptions {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task {
                        await store.refreshSubscriptions(force: true, now: .now)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func commitMenuSelection(_ action: @escaping () -> Void) {
        DispatchQueue.main.async(execute: action)
    }
}

private struct SectionPageHeaderView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let section: DeadlineSection
    let itemCount: Int
    let usesLightText: Bool

    private var primaryTextColor: Color {
        usesLightText ? .white : .black
    }

    private var badgeBackground: Color {
        usesLightText ? .white.opacity(0.2) : .black.opacity(0.12)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(section.title(in: languageManager.currentLanguage))
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(primaryTextColor)

            Text("\(itemCount)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(primaryTextColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(badgeBackground, in: Capsule())

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
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
        case .completed:
            return "checkmark.circle.fill"
        case .ended:
            return "xmark.circle.fill"
        }
    }
}

private struct DeadlineSectionView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let items: [DeadlineItem]
    let style: DeadlineViewStyle
    let now: Date
    let usesLightText: Bool
    let liquidMotionEnabled: Bool
    let onSelectItem: (DeadlineItem) -> Void

    private let gridSpacing: CGFloat = 8
    private let gridItemWidth: CGFloat = 172
    private let compactGridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var secondaryTextColor: Color {
        usesLightText ? .white.opacity(0.75) : .black.opacity(0.72)
    }

    private var usesAdaptivePadGrid: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                Text(languageManager.currentLanguage.text("No items yet", "暂无事项"))
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
                if usesAdaptivePadGrid {
                    FixedWidthGridLayout(itemWidth: gridItemWidth, spacing: gridSpacing) {
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
                } else {
                    LazyVGrid(columns: compactGridColumns, spacing: gridSpacing) {
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
        }
        .liquidGlassCard(cornerRadius: 22)
    }
}

private struct FixedWidthGridLayout: Layout {
    let itemWidth: CGFloat
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let containerWidth = max(proposal.width ?? itemWidth, itemWidth)
        let columns = columnCount(for: containerWidth)
        let rowHeights = measuredRowHeights(for: subviews, columns: columns)
        let totalHeight = rowHeights.reduce(0, +) + CGFloat(max(rowHeights.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? containerWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let columns = columnCount(for: bounds.width)
        let rowHeights = measuredRowHeights(for: subviews, columns: columns)
        let totalItemsWidth = CGFloat(columns) * itemWidth + CGFloat(max(columns - 1, 0)) * spacing
        let originX = bounds.minX + max((bounds.width - totalItemsWidth) / 2, 0)

        var y = bounds.minY
        for row in 0..<rowHeights.count {
            let rowStart = row * columns
            let rowEnd = min(rowStart + columns, subviews.count)
            for column in 0..<(rowEnd - rowStart) {
                let index = rowStart + column
                let x = originX + CGFloat(column) * (itemWidth + spacing)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: itemWidth, height: rowHeights[row])
                )
            }
            y += rowHeights[row] + spacing
        }
    }

    private func columnCount(for width: CGFloat) -> Int {
        let rawCount = Int((width + spacing) / (itemWidth + spacing))
        return max(rawCount, 1)
    }

    private func measuredRowHeights(for subviews: Subviews, columns: Int) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { start in
            let end = min(start + columns, subviews.count)
            return subviews[start..<end]
                .map { $0.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil)).height }
                .max() ?? 0
        }
    }
}

private struct DeadlineRowView: View {
    @EnvironmentObject private var languageManager: LanguageManager
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
        let language = languageManager.currentLanguage
        switch section {
        case .notStarted:
            return language.text(
                "Starts in \(Self.durationText(from: now, to: item.startDate, language: language))",
                "距开始 \(Self.durationText(from: now, to: item.startDate, language: language))"
            )
        case .inProgress:
            return language.text(
                "Remaining \(Self.durationText(from: now, to: item.endDate, language: language))",
                "剩余 \(Self.durationText(from: now, to: item.endDate, language: language))"
            )
        case .completed:
            return language.text("Completed", "已完成")
        case .ended:
            return language.text("Ended", "已结束")
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
                    Text(languageManager.currentLanguage.text("Start", "起") + " \(item.startDate.formatted(date: .abbreviated, time: .shortened))")
                    Spacer()
                    Text(languageManager.currentLanguage.text("End", "止") + " \(item.endDate.formatted(date: .abbreviated, time: .shortened))")
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

    private static func durationText(from now: Date, to target: Date, language: AppLanguage) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        var calendar = Calendar.current
        calendar.locale = language.locale
        formatter.calendar = calendar
        let interval = max(target.timeIntervalSince(now), 0)
        return formatter.string(from: interval) ?? language.text("0m", "0分钟")
    }
}

private struct EditDeadlineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    let item: DeadlineItem
    let groups: [String]
    let onSaveActive: (DeadlineItem, String, String, String, Date, Date, DeadlineRecurringChangeScope) -> DeadlineEditSaveResult
    let onSaveClosedDetail: (DeadlineItem, String) -> DeadlineEditSaveResult
    let onComplete: (UUID) -> Void
    let onApplyLocalConflictResolution: (DeadlineEditConflict) -> Bool
    let onCreateNew: (NewDeadlineDraft) -> Void
    let onMarkIncomplete: (UUID) -> Void
    let onDelete: (UUID, DeadlineRecurringChangeScope) -> Void

    @State private var title: String = ""
    @State private var selectedGroup: String = ""
    @State private var detail: String = ""
    @State private var startDate: Date = .now
    @State private var endDate: Date = .now
    @State private var showError = false
    @State private var showDeleteConfirm = false
    @State private var showCompleteConfirm = false
    @State private var showRepeatSaveOptions = false
    @State private var showRepeatDeleteOptions = false
    @State private var pendingCreateDraft: NewDeadlineDraft?
    @State private var shouldMarkIncomplete = false
    @State private var pendingConflict: DeadlineEditConflict?

    private func t(_ english: String, _ chinese: String) -> String {
        languageManager.currentLanguage.text(english, chinese)
    }

    private var currentSection: DeadlineSection {
        item.section(at: .now)
    }

    private var isClosedTask: Bool {
        currentSection == .completed || currentSection == .ended
    }

    private var canMarkComplete: Bool {
        item.canComplete(at: .now)
    }

    private var isSubscriptionManaged: Bool {
        item.subscriptionID != nil || item.sourceKind == .subscribedURL
    }

    private var isRecurringTask: Bool {
        item.belongsToRepeatSeries
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isClosedTask {
                        LabeledContent(t("Title", "标题"), value: title)
                        LabeledContent(t("Category", "分类"), value: selectedGroup)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("Description", "描述"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $detail)
                                .frame(minHeight: 110)
                        }
                    } else if isSubscriptionManaged {
                        LabeledContent(t("Title", "标题"), value: title)
                        LabeledContent(t("Category", "分类"), value: selectedGroup)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("Description", "描述"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(detail.isEmpty ? t("No description", "无描述") : detail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(detail.isEmpty ? .secondary : .primary)
                        }
                    } else {
                        TextField(t("Title", "标题"), text: $title)
                        Picker(t("Category", "分类"), selection: $selectedGroup) {
                            ForEach(groups, id: \.self) { group in
                                Text(group).tag(group)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("Description", "描述"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $detail)
                                .frame(minHeight: 110)
                        }
                    }
                } header: {
                    Text(t("Task Info", "事项信息"))
                }

                Section {
                    if isClosedTask {
                        LabeledContent(t("Start Time", "起始时间"), value: startDate.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent(t("End Time", "结束时间"), value: endDate.formatted(date: .abbreviated, time: .shortened))
                        if let completedAt = item.completedAt {
                            LabeledContent(t("Completed At", "完成时间"), value: completedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    } else if isSubscriptionManaged {
                        LabeledContent(t("Start Time", "起始时间"), value: startDate.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent(t("End Time", "结束时间"), value: endDate.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        DatePicker(t("Start Time", "起始时间"), selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker(t("End Time", "结束时间"), selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    }
                } header: {
                    Text(t("Time", "时间设置"))
                } footer: {
                    if isClosedTask {
                        Text(
                            t(
                                "Closed tasks keep their original time. You can still update the description, create a new task, or delete them.",
                                "已关闭任务会保留原始时间，你仍然可以修改描述、创建新事项或删除。"
                            )
                        )
                    } else if isSubscriptionManaged {
                        Text(
                            t(
                                "Tasks from URL subscriptions are refreshed by the feed. Change the source calendar or manage the subscription in Settings.",
                                "通过 URL 订阅导入的事项会随订阅源刷新。请在源日历中修改，或前往设置管理订阅。"
                            )
                        )
                    }
                }

                if canMarkComplete {
                    Section {
                        Button(t("Mark as Completed", "标记为已完成")) {
                            showCompleteConfirm = true
                        }
                        .confirmationDialog(t("Mark this task as completed?", "确认将该任务标记为已完成？"), isPresented: $showCompleteConfirm, titleVisibility: .visible) {
                            Button(t("Complete", "完成"), role: .none) {
                                onComplete(item.id)
                                dismiss()
                            }
                            Button(t("Cancel", "取消"), role: .cancel) { }
                        }
                    }
                }

                if isClosedTask {
                    Section {
                        Button(t("Create New Task", "创建新事项")) {
                            pendingCreateDraft = NewDeadlineDraft(
                                title: title,
                                category: selectedGroup,
                                detail: detail
                            )
                            dismiss()
                        }

                        if currentSection == .completed {
                            Button(t("Mark as Incomplete", "标记为未完成")) {
                                shouldMarkIncomplete = true
                                dismiss()
                            }
                        }
                    }
                }

                if !isSubscriptionManaged {
                    Section {
                        Button(t("Delete Task", "删除事项"), role: .destructive) {
                            if isRecurringTask {
                                showRepeatDeleteOptions = true
                            } else {
                                showDeleteConfirm = true
                            }
                        }
                        .confirmationDialog(t("Delete this task?", "确认删除该事项？"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button(t("Delete", "删除"), role: .destructive) {
                                onDelete(item.id, .thisEvent)
                                dismiss()
                            }
                            Button(t("Cancel", "取消"), role: .cancel) { }
                        }
                        .confirmationDialog(t("Delete recurring task", "删除重复事项"), isPresented: $showRepeatDeleteOptions, titleVisibility: .visible) {
                            Button(t("Only This Event", "仅删除本次日程"), role: .destructive) {
                                onDelete(item.id, .thisEvent)
                                dismiss()
                            }
                            Button(t("This and Future Events", "删除将来所有日程"), role: .destructive) {
                                onDelete(item.id, .futureEvents)
                                dismiss()
                            }
                            Button(t("Cancel", "取消"), role: .cancel) { }
                        } message: {
                            Text(t("Choose whether to delete only this event or this event and all following events in the series.", "选择只删除本次日程，或删除本次及之后的所有日程。"))
                        }
                    }
                }

                if showError {
                    Text(t("Title cannot be empty, and end time must be later than start time.", "请保证标题不为空，且结束时间晚于起始时间。"))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(t("Edit Task", "编辑事项"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSubscriptionManaged ? t("Done", "完成") : t("Save", "保存")) { save() }
                        .bold()
                }
            }
            .confirmationDialog(t("Edit recurring task", "修改重复事项"), isPresented: $showRepeatSaveOptions, titleVisibility: .visible) {
                Button(t("Only This Event", "仅修改本次日程")) {
                    performSave(scope: .thisEvent)
                }
                Button(t("This and Future Events", "修改将来所有日程")) {
                    performSave(scope: .futureEvents)
                }
                Button(t("Cancel", "取消"), role: .cancel) { }
            } message: {
                Text(t("Choose whether the changes apply only to this event or to this event and all following events in the series.", "选择本次修改仅作用于当前日程，或作用于当前及之后的所有日程。"))
            }
            .confirmationDialog(
                t("Detected a data conflict", "检测到数据冲突"),
                isPresented: Binding(
                    get: { pendingConflict != nil },
                    set: { newValue in
                        if newValue == false {
                            pendingConflict = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(t("Keep Local Data", "保留本地数据")) {
                    if let pendingConflict, onApplyLocalConflictResolution(pendingConflict) {
                        dismiss()
                    }
                }
                Button(t("Keep Cloud Data", "保留云端数据")) {
                    guard let pendingConflict else { return }
                    applyCloudVersion(from: pendingConflict.currentItem)
                    self.pendingConflict = nil
                }
                Button(t("Cancel", "取消"), role: .cancel) {
                    pendingConflict = nil
                }
            } message: {
                if let pendingConflict {
                    Text(conflictDescription(for: pendingConflict))
                }
            }
            .onAppear {
                title = item.title
                detail = item.detail
                startDate = item.startDate
                endDate = item.endDate
                selectedGroup = groups.contains(item.category) ? item.category : (groups.first ?? DeadlineStore.fallbackGroupName)
            }
            .onChange(of: groups) { _, newGroups in
                if !newGroups.contains(selectedGroup) {
                    selectedGroup = newGroups.first ?? DeadlineStore.fallbackGroupName
                }
            }
            .onDisappear {
                if let pendingCreateDraft {
                    onCreateNew(pendingCreateDraft)
                }
                if shouldMarkIncomplete {
                    onMarkIncomplete(item.id)
                }
            }
        }
    }

    private func save() {
        if isSubscriptionManaged {
            dismiss()
            return
        }

        if isClosedTask {
            let result = onSaveClosedDetail(item, detail)
            handleSaveResult(result)
            return
        }

        guard
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            endDate > startDate
        else {
            showError = true
            return
        }

        if isRecurringTask {
            showRepeatSaveOptions = true
            return
        }

        performSave(scope: .thisEvent)
    }

    private func performSave(scope: DeadlineRecurringChangeScope) {
        let result = onSaveActive(item, title, selectedGroup, detail, startDate, endDate, scope)
        handleSaveResult(result)
    }

    private func handleSaveResult(_ result: DeadlineEditSaveResult) {
        switch result {
        case .saved:
            dismiss()
        case .conflict(let conflict):
            pendingConflict = conflict
        }
    }

    private func applyCloudVersion(from item: DeadlineItem) {
        title = item.title
        selectedGroup = groups.contains(item.category) ? item.category : (groups.first ?? DeadlineStore.fallbackGroupName)
        detail = item.detail
        startDate = item.startDate
        endDate = item.endDate
    }

    private func conflictDescription(for conflict: DeadlineEditConflict) -> String {
        let labels = conflict.fields.map(conflictFieldTitle(_:))
        let joinedFields = ListFormatter.localizedString(byJoining: labels)
        return t(
            "The field(s) \(joinedFields) were changed on another device while you were editing. Choose whether to keep your local changes or use the latest iCloud values.",
            "你编辑期间，字段 \(joinedFields) 已在其他设备上被修改。请选择保留本地修改，或使用最新的云端数据。"
        )
    }

    private func conflictFieldTitle(_ field: DeadlineEditConflictField) -> String {
        switch field {
        case .title:
            return t("Title", "标题")
        case .category:
            return t("Category", "分类")
        case .detail:
            return t("Description", "描述")
        case .startDate:
            return t("Start Time", "起始时间")
        case .endDate:
            return t("End Time", "结束时间")
        }
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject var store: DeadlineStore

    @State private var newGroupName: String = ""
    @State private var renameTargetGroup: String?
    @State private var renameInputText: String = ""
    @State private var showingRenameAlert = false

    private var canAddGroup: Bool {
        !newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func t(_ english: String, _ chinese: String) -> String {
        languageManager.currentLanguage.text(english, chinese)
    }

    private var selectedLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { languageManager.currentLanguage },
            set: { languageManager.setLanguage($0) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(t("Language", "语言"), selection: selectedLanguageBinding) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.title(in: languageManager.currentLanguage)).tag(option)
                        }
                    }
                } header: {
                    Text(t("Language", "语言"))
                }

                Section {
                    Picker(t("Background Style", "背景样式"), selection: $store.backgroundStyle) {
                        ForEach(BackgroundStyleOption.allCases) { style in
                            Text(style.title(in: languageManager.currentLanguage)).tag(style)
                        }
                    }
                } header: {
                    Text(t("Background", "背景"))
                }

                Section {
                    NavigationLink {
                        SyncSettingsView(store: store)
                    } label: {
                        HStack {
                            Label(t("Sync Options", "同步选项"), systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            Text(store.syncOptions.automaticSyncEnabled ? t("On", "已开启") : t("Off", "已关闭"))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(t("Sync", "同步"))
                }

                Section {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            TextField(t("New Group", "新增分组"), text: $newGroupName)
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
                                Text(t("Add", "添加"))
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
                            Button(t("Edit \(group)", "编辑 \(group)"), systemImage: "pencil") {
                                renameTargetGroup = group
                                renameInputText = group
                                showingRenameAlert = true
                            }

                            if store.groups.count > 1 {
                                Button(t("Delete \(group)", "删除 \(group)"), systemImage: "trash", role: .destructive) {
                                    store.removeGroup(named: group)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if store.groups.count > 1 {
                                Button(role: .destructive) {
                                    store.removeGroup(named: group)
                                } label: {
                                    Label(t("Delete", "删除"), systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text(t("Groups", "分组"))
                } footer: {
                    Text(t("Please keep at least one group.", "请至少保留一个分组。"))
                }

                Section {
                    if store.subscriptions.isEmpty {
                        Text(t("No URL subscriptions yet.", "还没有 URL 订阅。"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.subscriptions) { subscription in
                            SubscriptionRow(
                                subscription: subscription,
                                language: languageManager.currentLanguage
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.removeSubscription(id: subscription.id)
                                } label: {
                                    Label(t("Delete", "删除"), systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button {
                        Task {
                            await store.refreshSubscriptions(force: true, now: .now)
                        }
                    } label: {
                        HStack {
                            if store.isRefreshingSubscriptions {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(t("Refresh All Subscriptions", "刷新全部订阅"))
                        }
                    }
                    .disabled(store.isRefreshingSubscriptions || store.subscriptions.isEmpty)
                } header: {
                    Text(t("Subscriptions", "订阅"))
                } footer: {
                    Text(t("Deleting a subscription also removes the tasks imported from that URL.", "删除订阅时，也会删除从该 URL 导入的事项。"))
                }

                Section {
                    Toggle(t("Liquid Motion", "液态动效"), isOn: $store.liquidMotionEnabled)
                } header: {
                    Text(t("Motion", "动效"))
                } footer: {
                    Text(t("When off, liquid in the grid view no longer responds to device movement.", "关闭后，网格视图中的液体将不再随手机晃动变化。"))
                }

                Section {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label(t("Privacy Policy", "隐私政策"), systemImage: "hand.raised")
                    }
                } header: {
                    Text(t("Legal", "法律"))
                }
            }
            .navigationTitle(t("Settings", "设置"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Done", "完成")) { dismiss() }
                }
            }
            .alert(t("Edit Group: \(renameTargetGroup ?? "")", "编辑分组：\(renameTargetGroup ?? "")"), isPresented: $showingRenameAlert) {
                TextField(t("Group Name", "分组名称"), text: $renameInputText)
                Button(t("Cancel", "取消"), role: .cancel) { }
                Button(t("Save", "保存")) {
                    guard let oldName = renameTargetGroup else { return }
                    store.renameGroup(from: oldName, to: renameInputText)
                }
            }
        }
    }
}

private struct SyncSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject var store: DeadlineStore

    private func t(_ english: String, _ chinese: String) -> String {
        languageManager.currentLanguage.text(english, chinese)
    }

    private var automaticSyncBinding: Binding<Bool> {
        Binding(
            get: { store.syncOptions.automaticSyncEnabled },
            set: { store.setAutomaticSyncEnabled($0) }
        )
    }

    private var languageSyncBinding: Binding<Bool> {
        Binding(
            get: { store.syncOptions.syncLanguage },
            set: { store.setLanguageSyncEnabled($0) }
        )
    }

    private var backgroundSyncBinding: Binding<Bool> {
        Binding(
            get: { store.syncOptions.syncBackgroundStyle },
            set: { store.setBackgroundSyncEnabled($0) }
        )
    }

    private var groupSyncBinding: Binding<Bool> {
        Binding(
            get: { store.syncOptions.syncGroups },
            set: { store.setGroupsSyncEnabled($0) }
        )
    }

    private var taskSyncBinding: Binding<Bool> {
        Binding(
            get: { store.syncOptions.syncTasks },
            set: { store.setTasksSyncEnabled($0) }
        )
    }

    private var subscriptionSyncBinding: Binding<Bool> {
        Binding(
            get: { store.syncOptions.syncSubscriptions },
            set: { store.setSubscriptionsSyncEnabled($0) }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(t("Automatic Sync", "自动同步"), isOn: automaticSyncBinding)
            } footer: {
                Text(
                    t(
                        "Turn this on to sync data through iCloud on your Apple devices signed in to the same account.",
                        "打开后，将通过 iCloud 在登录同一账号的 Apple 设备之间同步数据。"
                    )
                )
            }

            if store.syncOptions.automaticSyncEnabled {
                Section {
                    Toggle(t("Language", "语言"), isOn: languageSyncBinding)
                    Toggle(t("Background Style", "背景样式"), isOn: backgroundSyncBinding)
                    Toggle(t("Group List", "标签列表"), isOn: groupSyncBinding)
                    Toggle(t("Tasks", "事项"), isOn: taskSyncBinding)
                    Toggle(t("Subscriptions", "订阅"), isOn: subscriptionSyncBinding)
                } header: {
                    Text(t("Sync Content", "同步内容"))
                } footer: {
                    Text(
                        t(
                            "Turning off group sync also turns off task and subscription sync.",
                            "关闭标签列表同步时，事项同步和订阅同步也会一并关闭。"
                        )
                    )
                }
            }
        }
        .navigationTitle(t("Sync Options", "同步选项"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SubscriptionRow: View {
    let subscription: DeadlineSubscription
    let language: AppLanguage

    private func t(_ english: String, _ chinese: String) -> String {
        language.text(english, chinese)
    }

    private var secondaryText: String {
        if let lastErrorMessage = subscription.lastErrorMessage, lastErrorMessage.isEmpty == false {
            return lastErrorMessage
        }

        if let lastSyncedAt = subscription.lastSyncedAt {
            return t("Last synced", "上次同步") + " " + lastSyncedAt.formatted(date: .abbreviated, time: .shortened)
        }

        if let lastAttemptedAt = subscription.lastAttemptedAt {
            return t("Last attempted", "上次尝试") + " " + lastAttemptedAt.formatted(date: .abbreviated, time: .shortened)
        }

        return t("Not synced yet", "尚未同步")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(subscription.displayName)
                .font(.body.weight(.semibold))

            Text(subscription.category)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(secondaryText)
                .font(.caption2)
                .foregroundStyle(subscription.lastErrorMessage == nil ? Color.secondary : Color.red)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title2.weight(.bold))

                Text("Effective date: March 12, 2026")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                languageHeader("English")
                policySection(
                    title: "1. Data Processing",
                    body: "Liquid Deadline does not collect, upload, sell, rent, or share your personal information. Your tasks, categories, descriptions, and settings are stored locally on your device only."
                )
                policySection(
                    title: "2. Network Services",
                    body: "The app does not provide account registration, cloud sync, or server-side storage. If you choose to subscribe to an external calendar URL, the app fetches that feed directly from your device to import or refresh tasks. The developer does not receive or store that calendar data on a server."
                )
                policySection(
                    title: "3. Third-Party Sharing",
                    body: "The app does not share your personal information with third parties for advertising, analytics, or profiling."
                )
                policySection(
                    title: "4. Your Responsibility",
                    body: "You are responsible for how you use this app and for verifying any task, reminder, or deadline information you enter. The developer is not liable for losses, delays, missed deadlines, or other adverse consequences arising from the use of this app, to the extent permitted by applicable law."
                )
                policySection(
                    title: "5. Contact",
                    body: "If you have privacy questions, contact the developer through the contact method provided on the App Store product page."
                )

                Divider()
                    .padding(.vertical, 4)

                languageHeader("中文")
                policySection(
                    title: "1. 数据处理",
                    body: "Liquid Deadline 不会收集、上传、出售、出租或共享你的个人信息。你的事项、分类、描述和设置仅保存在你的设备本地。"
                )
                policySection(
                    title: "2. 网络服务",
                    body: "本应用不提供账号注册、云同步或服务器端存储。如果你选择订阅外部日历 URL，应用会仅在你的设备上直接拉取该日历内容，用于导入或刷新事项。开发者不会在服务器端接收或存储这些日历数据。"
                )
                policySection(
                    title: "3. 第三方共享",
                    body: "本应用不会为了广告、分析或画像目的向第三方共享你的个人信息。"
                )
                policySection(
                    title: "4. 用户责任",
                    body: "你应自行决定如何使用本应用，并自行核对你录入的事项、提醒和截止时间信息。在适用法律允许的范围内，开发者不对因使用本应用而产生的损失、延误、错过截止时间或其他不良后果承担责任。"
                )
                policySection(
                    title: "5. 联系方式",
                    body: "如果你对隐私问题有疑问，请通过 App Store 产品页提供的联系方式联系开发者。"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func languageHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.primary)
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
