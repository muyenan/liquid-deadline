# Deadline Oil App (SwiftUI / iOS 26)

## 在 Xcode 中运行
1. 在 Xcode 新建 `iOS App` 工程（推荐命名：`DeadlineOilApp`，Interface 选 `SwiftUI`）。
2. 将下列源码文件拖入工程并勾选 `Copy items if needed`：
   - `DeadlineOilApp/DeadlineOilAppApp.swift`
   - `DeadlineOilApp/Models/DeadlineItem.swift`
   - `DeadlineOilApp/ViewModels/DeadlineStore.swift`
   - `DeadlineOilApp/Services/MotionManager.swift`
   - `DeadlineOilApp/Views/ContentView.swift`
   - `DeadlineOilApp/Views/NewDeadlineSheet.swift`
   - `DeadlineOilApp/Views/OilProgressBarView.swift`
   - `DeadlineOilApp/Views/OilGridCellView.swift`
   - `DeadlineOilApp/Views/OilProgressShapes.swift`
   - `DeadlineOilApp/Views/LiquidGlass.swift`
   - `DeadlineOilApp/Views/LiquidBackgroundView.swift`
3. iOS Deployment Target 设为 `iOS 26.0`。
4. 在真机或模拟器运行，网格/进度条样式可在首页顶部切换。

## 功能点
- 三段状态：`未开始 / 进行中 / 已结束`（自动按当前时间归类）。
- 创建事项字段：标题、分类、起始时间、结束时间。
- 动态刷新：秒级刷新截止状态和进度。
- 两种视图：`进度条` 与 `网格`。
- 液体效果：正弦波液面动画 + 陀螺仪倾斜联动。
- iOS 26 视觉：优先使用 `glassEffect`，低版本自动回退到 `Material`。
