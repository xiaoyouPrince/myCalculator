# REQ-003：计算规则读 dayRole；导出与扩展字段对齐（P2）

| 字段 | 内容 |
| --- | --- |
| 状态 | 取消 |
| 阶段 | P2 |
| 创建 | 2026-10-23 |
| 验收时间 | — |
| 验收意见 | 2026-10-26 取消：双层 dayRole 设计过于复杂，由 [REQ-004](./REQ-004-simple-attendance-model.md) 取代 |

## 目标

工时/加班算法与导出、浏览器扩展能感知「休息日加班 vs 工作日/补班」，规则可解释、数据可对齐。

## 范围

1. 计算规则（或新规则）读取 `dayRole`：例如周末 / 法定假上班按休息日加班语义；`makeupWorkday` 按工作日语义
2. CSV / JSON 导出带上 `dayRole`（及必要说明）
3. 更新 `docs/browser-extension-autofill.md` 与扩展侧预期；扩展若暂不消费 `dayRole`，文档写明兼容策略
4. 更新 README / 计算规则说明中的用例表

## 不做

- 强制扩展立刻支持全部新字段的自动填报（可分步）
- 节日自动数据源

## 验收标准

- [ ] 同组上下班时间，在不同 `dayRole` 下结果符合约定用例
- [ ] 导出文件含 `dayRole`，旧导入/缺省字段仍可读
- [ ] 扩展文档与 App 导出约定一致
- [ ] 工具栏规则切换后，侧栏与年视图汇总与新规则一致

## 依赖

- REQ-001 已验收
- 建议 REQ-002 已验收（展示与算法语义一致更易验收）

## 约定用例（`rest-day-overtime`）

同组 `09:00–18:00`：

| dayRole | 工时申报 | 加班 | 有效加班 |
| --- | ---: | ---: | ---: |
| workday / makeupWorkday | 8.00 | 0.00 | 0.00 |
| weekend / publicHoliday | 0.00 | 9.00 | 9.00 |

## 关联

- [`../calculation-rules-guide.md`](../calculation-rules-guide.md)
- [`../browser-extension-autofill.md`](../browser-extension-autofill.md)
- 规则 id：`rest-day-overtime`
