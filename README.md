# myCalculator（工时日历 Demo）

基于 SwiftUI 的 macOS 日历式工时记录应用。  
当前已实现日 / 周 / 月 / 年四种视图，并支持按日期录入上下班时间、自动计算工时与加班时长、JSON 本地持久化。

## 1. 项目结构

当前项目已完成模块化拆分（View / Model / Store）：

- `myCalculator.xcodeproj`：Xcode 工程文件
- `myCalculator/myCalculatorApp.swift`：应用入口与窗口默认尺寸配置
- `myCalculator/ContentView.swift`：主容器（分栏、顶部工具栏、视图模式切换）
- `myCalculator/Views/`：页面与组件
  - `SidebarView.swift`：左侧菜单栏（日期选择、当日/周/月汇总、固定底部按钮）
  - `CalendarContentView.swift`：日/周/月/年视图路由
  - `DayView.swift`、`WeekView.swift`、`MonthView.swift`、`YearView.swift`
  - `Components/WorkPanels.swift`：录入面板、详情面板、时间输入组件
  - `Components/WeekCells.swift`：周视图表格单元组件
- `myCalculator/Models/WorkScheduleModels.swift`：数据模型与工时计算模型
- `myCalculator/Stores/WorkScheduleStore.swift`：JSON 持久化读写
- `myCalculator/Assets.xcassets`：图标与资源

## 2. 已实现功能

### 2.1 视图模式

- **日视图**
  - 展示当前选中日期的明细数据
  - 右上角 `编辑` 按钮可打开上下班时间录入面板
- **周视图**
  - 显示“当前 xx 年第 yy 周”
  - 支持上一周 / 下一周切换
  - 周一到周日逐日展示日期与工时细节
  - 点击当天行：
    - 有历史数据：先展示放大详情面板，再点编辑进入录入
    - 无历史数据：直接进入录入
- **月视图**
  - 按真实日历规则对齐每月日期（含周序号）
  - 支持上一月 / 下一月切换
  - 每个日期格展示工时摘要
  - 点击格子同样支持“有数据先详情、无数据直接录入”
- **年视图**
  - 12 个月总览
  - 点击某个月跳转到对应月份月视图

### 2.2 工时与加班计算规则

针对每条上下班记录，系统自动计算：

- 工作时间（`xx小时xx分钟`）
- 工作时间（`xx.yy 小时`）
- 加班时长（`max(下班-上班-10小时, 0)`）
- 有效加班时长：
  - 加班 < 1 小时，记 0
  - 加班 >= 1 小时，按 0.5 小时档位递增统计（当前实现为向下取到最近 0.5）

### 2.3 左侧栏信息

- 选择日期（纵向标签，窗口较低时自动切换为紧凑日期选择器）
- 当日数据
- 当周汇总（含周标题）
- 当月汇总（含月标题）
- 左侧主体内容支持滚动，避免小窗口溢出
- `查看 JSON` 按钮固定悬浮在底部，可直接打开持久化文件

### 2.4 时间录入交互

- 录入字段：上班时间 / 下班时间
- 时间格式：**强制 24 小时制**（`HH:mm`）
- 选择方式：小时（00-23）+ 分钟（00-59）

### 2.5 数据持久化

- 存储格式：JSON
- 存储位置：`Application Support/myCalculator/work-schedules.json`（用户域）
- 启动时自动加载，保存后实时刷新 UI

## 3. 开发环境与版本建议

当前项目运行环境为 macOS 桌面应用，建议：

- **系统**：macOS 13 及以上（推荐 macOS 14/15+）
- **Xcode**：Xcode 15 及以上
- **语言/框架**：Swift 5 + SwiftUI（macOS App）

> 若你本机是更新版本（如 Xcode 16 / macOS 15+），可直接使用，不影响本项目。

## 4. 运行方式

### 4.1 使用 Xcode 运行（推荐）

1. 打开工程：
   - 双击 `myCalculator.xcodeproj`
2. 在 Xcode 顶部选择 Scheme：`myCalculator`
3. 运行目标选择 `My Mac`
4. 点击运行（`⌘R`）

### 4.2 命令行构建（可选）

在项目根目录执行：

```bash
xcodebuild -project "myCalculator.xcodeproj" -scheme "myCalculator" -sdk macosx build
```

> 若遇到本地权限或沙盒导致的 DerivedData 写入问题，可在 Xcode 内直接运行，或自定义 `-derivedDataPath` 到项目目录。

## 5. 后续可迭代方向

- 增加输入校验（如下班时间不得早于上班时间）
- 增加导出、清空、备份与恢复
- 增加年度统计与图表展示
