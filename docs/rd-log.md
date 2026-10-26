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
| 2026-10-26 | REQ-004 修订 | 休息日：补班=工作日规则；加班=出勤全计加班工资；换调休=出勤进调休额度 |
| 2026-10-26 | 算法再调 | 休息日加班工资=平时规则；换调休覆盖 12:00–13:00 扣 1h |
| 2026-10-26 | 算法澄清 | 休息日加班=出勤全计加班再扣饭（非超 10h 才计）；18 日应对约 7.08 |
| 2026-10-26 | 知识库 | 定稿规则写入 [attendance-and-overtime-rules.md](./attendance-and-overtime-rules.md) |
| 2026-10-26 | REQ-004 验收 | 基本满足当前需求（用户确认） |

## 待验收

- （无）

## 已验收

- [REQ-001](./requirements/REQ-001-day-role-and-edit-panel.md)（2026-10-23 17:07，通过）
- [REQ-002](./requirements/REQ-002-month-cell-visual.md)（2026-10-23 17:23，通过）
- [REQ-004](./requirements/REQ-004-simple-attendance-model.md)（2026-10-26 15:19，基本满足当前需求）

## 已取消

- [REQ-003](./requirements/REQ-003-calc-export-by-day-role.md)（2026-10-26，被 REQ-004 取代）
