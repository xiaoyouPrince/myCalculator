# 研发记录：出勤与工时

> 只记关键节点与文档引用，细节写在各 REQ / 复盘里。

## 节点

| 日期 | 节点 | 说明 / 引用 |
| --- | --- | --- |
| 2026-10-23 | 方向确认 | 曾拆分 dayRole + logKind（见 REQ-001～003） |
| 2026-10-23 | REQ-001 / 002 验收 | 见各 REQ |
| 2026-10-23 | REQ-003 提验 | rest-day-overtime；后因复杂取消 |
| 2026-10-26 | 纠偏 | 放弃双层编辑；改为简洁出勤四选一 |
| 2026-10-26 | 取消 REQ-003 | 由 [REQ-004](./requirements/REQ-004-simple-attendance-model.md) 取代 |
| 2026-10-26 | REQ-004 提验 | 正常上班 / 周末加班 / 周末调休 / 不上班；两本账 |

## 待验收

- [REQ-004](./requirements/REQ-004-simple-attendance-model.md)

## 已验收

- [REQ-001](./requirements/REQ-001-day-role-and-edit-panel.md)（2026-10-23 17:07，通过）
- [REQ-002](./requirements/REQ-002-month-cell-visual.md)（2026-10-23 17:23，通过）

## 已取消

- [REQ-003](./requirements/REQ-003-calc-export-by-day-role.md)（2026-10-26，被 REQ-004 取代）
