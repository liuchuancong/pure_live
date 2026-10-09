# pure_live_iptv_feature

> 职责:IPTV 域:M3U/Epg 频道面;数据插件(providers/iptv)解析,这里消费

| 项 | 规则 |
|---|---|
| 层 | features(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | → L0 + ecosystem + services + ui;同层禁互依 |
| 禁止依赖 | 反向依赖;应用壳(I9);providers 直接依赖(经注册表消费) |
| 公共面 | 只有 `lib/pure_live_iptv_feature.dart` |
| 结构 | `lib/src/data`(仓储实现)/ `lib/src/domain`(模型与用例)/ `lib/src/presentation`(界面) |

## 状态

骨架。业务实现按波次填(见 docs/roadmap/),先骨架后逻辑是既定顺序。
