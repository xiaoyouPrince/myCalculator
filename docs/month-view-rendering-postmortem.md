# 月视图跨月日期渲染问题复盘

## 背景

2026-06-30 修复月视图中“当月日期应为正常黑色、非当月日期应淡化灰色”的问题时，曾出现多次误判：编译通过后就认为修复完成，但用户实际运行截图仍然显示错误。

典型操作路线：

1. 启动 App，默认在 2026 年 6 月视图。
2. 点击月视图右上角下一月按钮，进入 2026 年 7 月视图。
3. 期望 7/1-7/31 正常显示，6/29、6/30、8/1、8/2 淡化显示。

实际错误表现：

- 6/30 在 7 月视图中仍然被蓝色高亮，像是当前月/今天。
- 7/1-7/5 被淡化，像是非当前月。
- 左侧 compact 日期选择器一度把年份解析成 `0004`，导致标题出现 `Jul 30, 4`、`0004年7月`。

## 根因

这次问题不是单一原因，而是两个问题叠加。

### 1. 日期输入控件在紧凑模式下容易误解析

左侧栏根据窗口高度切换到 compact `DatePicker`。在 macOS 的 compact 日期输入框里，用户/系统输入焦点可能导致年份被解析成异常值，例如公元 4 年。

处理方式：

- 左侧日期选择器固定使用 `.graphical`。
- 不再在低窗口高度下切换到 compact 日期输入框。

相关文件：

- `myCalculator/Views/SidebarView.swift`

### 2. SwiftUI 网格复用导致旧月份首周状态残留

月视图使用 `LazyVGrid`，并且 `ForEach(Array(monthData.enumerated()), id: \.offset)` 以行下标作为 identity。切换月份后，SwiftUI 可能复用上一月对应位置的视图。第一周尤其容易出问题，因为 6 月和 7 月首周的格子位置相同，但“是否当前月”的状态完全不同。

单纯修改 `MonthDay.isCurrentMonth` 的计算方式不够，因为渲染层仍可能复用旧视图状态。

最终处理方式：

- `MonthDayCell` 不只依赖传入的 `day.isCurrentMonth`，而是根据 `displayedMonthDate` 和 `day.id` 实时计算 `isInDisplayedMonth`。
- 当前月数字使用明确的深色：`Color.black.opacity(0.82)`。
- 非当前月数字和摘要使用明确淡化色：`Color.secondary.opacity(0.45)`。
- 给整个月网格添加月份级 `.id(monthIdentity)`，月份变化时强制重建网格，避免复用旧月份首周的渲染状态。

相关文件：

- `myCalculator/Views/MonthView.swift`

## 修复原则

### 日期归属判断

判断一个日期是否属于当前展示月份时，优先比较年/月组件：

```swift
let calendar = Calendar.current
let isInDisplayedMonth =
    calendar.component(.year, from: dayDate) == calendar.component(.year, from: displayedMonthDate) &&
    calendar.component(.month, from: dayDate) == calendar.component(.month, from: displayedMonthDate)
```

避免把 UI 显示状态绑定到容易受时区、日期区间边界或旧视图状态影响的中间值。

### SwiftUI 网格刷新

当网格内容的语义整体切换时，例如从 6 月切到 7 月，不能只依赖相同位置的 cell 更新。需要给外层网格一个语义 identity：

```swift
LazyVGrid(columns: gridColumns, spacing: 0) {
    ...
}
.id(monthIdentity)
```

`monthIdentity` 应由展示月份的 `year-month` 组成。

### 颜色语义

不要只依赖 `.primary` / `.secondary` 判断视觉差异，截图里它们在淡色界面下可能不够明显。

建议：

- 当前月：明确深色。
- 非当前月：明确降低 opacity。
- 今日高亮：必须同时满足“今天”和“属于当前展示月份”。

```swift
.background(day.isToday && isInDisplayedMonth ? Color.blue.opacity(0.14) : Color.clear)
```

## 验证流程

这次最大的教训是：编译通过不等于 UI 修复通过。后续处理 SwiftUI 视觉/状态复用类问题时，必须做真实界面验证。

推荐流程：

1. 构建：

```bash
xcodebuild -project myCalculator.xcodeproj \
  -scheme myCalculator \
  -configuration Debug \
  -derivedDataPath /tmp/myCalculatorDerived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

2. 退出旧实例，避免 Xcode、DerivedData、`/tmp` 多个版本同时运行：

```bash
pkill -f '/myCalculator.app/Contents/MacOS/myCalculator'
```

3. fresh 启动最新构建产物，避免 macOS 窗口恢复状态干扰：

```bash
open -n -F /tmp/myCalculatorDerived/Build/Products/Debug/myCalculator.app
```

4. 获取 App 主窗口 ID：

```bash
swift -module-cache-path /tmp/swift-module-cache -e '
import CoreGraphics
let wins = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
for w in wins {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    let name = w[kCGWindowName as String] as? String ?? ""
    if owner == "myCalculator", name == "myCalculator" {
        print(w[kCGWindowNumber as String] ?? "?")
    }
}'
```

5. 只截取 App 主窗口：

```bash
screencapture -x -l <window_id> /tmp/myCalculator-window.png
```

6. 打开截图人工确认：

- 月标题是目标月份，例如 `2026年7月`。
- 7/1-7/31 为正常深色。
- 6/29、6/30、8/1、8/2 为淡化灰色。
- 如果今天不是目标月日期，不应显示今日蓝色高亮。
- 左侧栏日期、周标题、月标题与当前选中日期一致。

## 代码级补充验证

视觉验证之外，还可以用 Swift 脚本快速验证月份归属算法。以 2026 年 7 月为例：

期望结果：

- `06/29`、`06/30` 为 `outside`
- `07/01` 到 `07/31` 为 `current`
- `08/01`、`08/02` 为 `outside`

如果代码级验证通过但截图仍错误，优先怀疑 SwiftUI identity、视图复用、状态缓存，而不是日期算法本身。

## 后续同类问题处理清单

遇到“数据正确但 UI 显示错位/颜色错乱/上一页状态残留”时，按以下顺序处理：

1. 确认是否有多个 App 实例在运行，先清理旧实例。
2. 用 fresh 模式启动最新构建产物，避免窗口恢复和旧包干扰。
3. 截取 App 主窗口，不要用全屏截图判断，被终端/Xcode/Finder 遮挡时容易误判。
4. 检查 `ForEach` 的 identity 是否只用了数组下标。
5. 检查 `LazyVGrid`、`List`、`LazyVStack` 是否复用了旧语义下的 cell。
6. 对整块语义切换区域加 `.id(...)`，例如月份、年份、筛选条件。
7. 让 cell 根据当前展示上下文实时计算关键显示状态，不要只依赖创建数据时算好的布尔值。
8. 编译通过后必须做截图验证，尤其是用户已经给出明确复现路径时。

## 本次最终确认结果

最终截图验证结果：

- `7/1-7/31` 正常深色显示。
- `6/29`、`6/30`、`8/1`、`8/2` 淡化灰色显示。
- `6/30` 没有再显示蓝色今日高亮。
- 左侧栏显示 `Jul 2026`、`2026年7月`，未再出现异常年份。

