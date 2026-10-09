# pure_live_douyu

> 职责:douyu 源插件(骨架):按 capability 契约实现,协议取数参照既定参考仓,fixtures 录制真实响应。

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | → L0 + L1 plugin_api(经 host 注入的沙箱桥);同层禁互依;不得触碰 PlayerAdapter(I1/I5) |
| 禁止依赖 | 反向依赖;应用壳(I9) |
| 公共面 | 只有 `lib/pure_live_douyu.dart` |
| 结构 | `lib/src/live/models`(capability 分域)+ fixtures(录制的真实响应,不猜) |

## 状态

骨架。协议实现在插件细节阶段按波次填;JS/py 形态的源走 external_tvbox 的 spider 宿主,本包承载需要原生 Dart 协议的形态。
