# pure_live_resolver

> 职责:解析契约:Resolver 与注册表、按能力解析的适配器、候选降级与票据换链

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation + 契约模型包 `pure_live_platform`;并按 [ADR 0021](../../../docs/adr/0021-resolver-capability-edge.md) 定向依赖 `pure_live_capability`(只用于把 `ResolveCapability` 提升成 `Resolver`) |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_resolver.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/resolver.dart` —— `Resolver` 接口与 `ResolverException`(带 `platform-models.md` §14 的错误码)
- `lib/src/resolver_registry.dart` —— `ResolverRegistry`(候选与优先级)与 `ResolverChain`(降级 / 禁止降级)
- `lib/src/capability_resolver.dart` —— `CapabilityResolver` 与 `CapabilityTicketRefresher`,票据进出 `ResolveResult` 的唯一通道

## 边界

- `canResolve` 必须离线可答:注册表对每个候选都问一遍,这里发请求就等于一次解析打了 N 个源。
- 已经过期的票据**不**交出去。放它过去只会让失败发生在播放器内部,而那里的恢复阶梯回不到"换个源"。
- 取消不是失败(`platform-models.md` §20 不变量 9):`ResolverChain` 遇到 `task.cancelled` 直接上抛,不会去试下一个候选。
- `allowFallback == false` 时首个失败原样上抛,且不再问后面的候选——播放中换源会连带换掉字幕线与清晰度承诺。

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / iOS / macOS / Windows / Linux | ✅ | 纯 Dart:只有 `dart:async` 的 `Future.timeout`,没有文件、没有插件、没有 Flutter。 |
| Web | ✅ 编译层面无障碍,**本轮没跑过** | 本包不碰 `dart:io`;但换链的成败由被解析的站点决定,浏览器侧还多出 CORS 与预检这一层,而这条路径没有任何测试跑在 web 上。 |

## 验证

- 分析:`dart analyze packages/ecosystem/resolver`(0 issue)
- 测试:`dart test`(35 例,纯 Dart)

## 未验证(2026-10-10 复核)

- 超时预算的**默认值 12s 是这里定的经验数**,没有对着真实源测过:慢线路的 douyu/huya 解析在弱网下
  究竟多久算卡,需要一次真机测量再调;调的是常量,不是机制。
- `.timeout()` 只让等待方放弃,**不提供取消已发出请求的能力**(与 services 层聚合器同一条界)。
  挂死的 provider 请求仍在跑,直到 dio 自己结束。
