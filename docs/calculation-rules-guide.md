# 计算规则扩展指南

myCalculator 的工时、加班、摘要展示都通过**可插拔计算规则**完成。App 顶部工具栏的「计算规则」菜单用于全局切换；所有日 / 周 / 月 / 年视图、侧边栏汇总和 CSV 导出使用同一套规则。

## 架构概览

```text
WorkCalculationContext (日期 + WorkSchedule)
        ↓
WorkCalculationRule (你实现的规则)
        ↓
WorkMetrics + MonthScheduleSummary
        ↓
WorkCalculationEngine (统一入口，负责聚合)
```

核心文件：

| 文件 | 作用 |
| --- | --- |
| `myCalculator/Calculation/WorkCalculationContext.swift` | 计算输入 |
| `myCalculator/Calculation/WorkCalculationRule.swift` | 规则协议 |
| `myCalculator/Calculation/WorkCalculationEngine.swift` | 统一入口 |
| `myCalculator/Calculation/WorkCalculationRegistry.swift` | 规则注册表 |
| `myCalculator/Calculation/Rules/*.swift` | 各条内置规则 |

## 5 分钟新增一条规则

1. 复制 `myCalculator/Calculation/Rules/LegacyTenHourRule.swift` 为新文件，例如 `DinnerBreakRule.swift`。
2. 修改 `id`、`title`、`summary`。
3. 实现 `metrics(for:)` 和 `daySummary(for:)`。
4. 在 `WorkCalculationRegistry.all` 数组中追加你的规则实例。
5. 用 README 2.2 节的表格做 golden case 对照。

示例骨架：

```swift
struct DinnerBreakRule: WorkCalculationRule {
    let id = "dinner-break-v2"
    let title = "晚饭扣减"
    let summary = "基础休息 1 小时；20:00 后下班再扣 1 小时"

    func metrics(for context: WorkCalculationContext) -> WorkMetrics {
        // 纯函数：只读 context，返回 WorkMetrics
    }

    func daySummary(for context: WorkCalculationContext) -> MonthScheduleSummary {
        guard context.schedule.isWorkLog else {
            return NonWorkLogSummaryBuilder.summary(for: context.schedule)
        }
        let metrics = metrics(for: context)
        // 组装 lines，参考 LegacyTenHourRule
    }
}
```

## 输入输出契约

### WorkCalculationContext

- `date`：记录所属日历日。当前默认规则不使用，后续「周末 / 补班 / 法定日」规则会用到。
- `schedule`：上下班时间与记录类型。

### WorkMetrics 四字段

| 字段 | 含义 |
| --- | --- |
| `workMinutes` | 原始工作分钟 |
| `declaredWorkHours` | 工时申报 |
| `overtimeHours` | 加班时长 |
| `effectiveOvertimeHours` | 有效加班（年视图、侧边栏高亮用） |

非工作记录（放假、调休、年假等）四项均为 `0`。

### MonthScheduleSummary

- `lines`：Cell 与详情面板逐行展示的内容。
- `isWorkLog`：是否为工作时间记录（影响月视图颜色）。
- 非工作记录可复用 `NonWorkLogSummaryBuilder.summary(for:)`。

## 聚合约定

`WorkCalculationEngine.aggregateSummary` 对标准四字段求和，用于侧边栏周 / 月汇总：

- `workHours` = 总 `workMinutes / 60`
- `declaredWorkHours`、`overtimeHours`、`effectiveOvertimeHours` 直接累加

年视图只展示 `effectiveOvertimeHours` 月合计。

若未来规则需要额外指标（如调休额度），可先扩展 `WorkMetrics`，再在 Engine 中增加对应聚合方法。

## 测试建议

使用 README「2.2 工时与加班计算规则」表格作为 golden cases。对每条规则至少验证：

- 09:00–18:00 → 申报 8.00，加班 0
- 09:00–20:00 → 申报 9.00，有效加班 1.00
- 09:00–19:54 → 有效加班 0（不足 1 小时门槛）

本地编译：

```bash
xcodebuild \
  -project myCalculator.xcodeproj \
  -scheme myCalculator \
  -configuration Debug \
  -derivedDataPath /tmp/myCalculatorDerived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 后续规则模板（未实现）

### 休息日加班（rest-day-overtime）

```swift
func metrics(for context: WorkCalculationContext) -> WorkMetrics {
    guard context.schedule.isWorkLog else { return zeroMetrics }
    if isRestDay(context.date) {
        // 全部出勤算加班，有效加班 = 0，可写入 extensions 供调休
    } else {
        // 沿用工作日逻辑
    }
}
```

### 浏览器扩展

扩展目前固定使用 `legacy-ten-hour`（见「浏览器扩展自动填报」说明）。App 导出 CSV 首行会写入 `# calculationRuleID: ...`，便于后续同步。

自定义 JavaScript 规则引擎计划在 v2.x 实现。

## 路线图

| 版本 | 规则 id | 说明 |
| --- | --- | --- |
| 当前 | `legacy-ten-hour` | 10 小时阈值，与历史行为一致 |
| v1.3 | `dinner-break-v2` | 晚饭语义扣减 |
| v1.4 | `rest-day-overtime` | 周末 / 补班 / 法定日 |
| v1.5 | `compensatory-leave` | 调休额度 |
| v2.x | 脚本 / 导出同步 | App 与浏览器扩展共享规则 |
