# pure_live_home

> 职责:Home 是 Feed 聚合的消费面:聚合各源首页内容,自身不是业务数据源(services/feed.md)

| 项 | 规则 |
|---|---|
| 层 | features(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | → L0 + ecosystem + services + ui;同层禁互依 |
| 禁止依赖 | 反向依赖;应用壳(I9);providers 直接依赖(经注册表消费) |
| 公共面 | 只有 `lib/pure_live_home.dart` |
| 结构 | `lib/src/data`(仓储实现)/ `lib/src/domain`(模型与用例)/ `lib/src/presentation`(界面) |

## 状态

骨架。业务实现按波次填(见 docs/roadmap/),先骨架后逻辑是既定顺序。
