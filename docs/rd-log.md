# 研发记录：日子角色与编辑体验

> 只记关键节点与文档引用，细节写在各 REQ / 复盘里。

## 节点

| 日期 | 节点 | 说明 / 引用 |
| --- | --- | --- |
| 2026-10-23 | 方向确认 | 拆分「日历角色 `dayRole`」与「实际记录 `logKind`」；调休休息 vs 调休补班语义分开 |
| 2026-10-23 | 立项 | 需求清单：[requirements/README.md](./requirements/README.md) |
| 2026-10-23 | 开工 REQ-001 | [REQ-001](./requirements/REQ-001-day-role-and-edit-panel.md) 进入开发中 |
| 2026-10-23 | REQ-001 提验 | 模型 / 持久化 / 日周月录入面板已落地，构建通过；见 REQ-001 |
| 2026-10-23 | REQ-001 验收 | 通过（17:07） |
| 2026-10-23 | 开工 REQ-002 | [REQ-002](./requirements/REQ-002-month-cell-visual.md) 进入开发中 |
| 2026-10-23 | REQ-002 提验 | 月格角色底色 / 角标 / 短标签；未录入日仍按日历预填角色 |
| 2026-10-23 | REQ-002 验收 | 通过（17:23）；用户先试用观察效果，REQ-003 暂缓 |
| 2026-10-23 | 开工 REQ-003 | [REQ-003](./requirements/REQ-003-calc-export-by-day-role.md) 进入开发中 |
| 2026-10-23 | REQ-003 提验 | 新增 `rest-day-overtime`；CSV 含日历角色；扩展文档写明不消费 dayRole |

## 待验收

- [REQ-003](./requirements/REQ-003-calc-export-by-day-role.md)

## 已验收

- [REQ-001](./requirements/REQ-001-day-role-and-edit-panel.md)（2026-10-23 17:07，通过）
- [REQ-002](./requirements/REQ-002-month-cell-visual.md)（2026-10-23 17:23，通过）
