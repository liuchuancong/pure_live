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

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
