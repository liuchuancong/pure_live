# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Fixed(DoD 体积/超时项)**:`CapabilityResolver` 与 `CapabilityTicketRefresher` 现在真的有超时预算
  (`timeout`,默认 `CapabilityResolver.kDefaultResolveTimeout` = 12s;`Duration.zero` 表示不设限)。
  `ResolverException.timedOut` 从第一版就定义好了,却**没有任何代码抛它** —— 适配器直接 await 提供方的
  网络调用,于是一个卡死的源能把起播无限期拖住,而"换一路恢复"的阶梯根本轮不到执行。
- 超时抛的是带 `resolver.timeout` 码、`category: timeout`、`retryable: true` 的分类失败,而不是 sdk 的
  `TimeoutException`,也不是被泛化 catch 折成的 `resolver.failed`:调用方按码分支,拒绝与超时必须是两个码
  (不可解析的内容不该重试,超时该重试并换源)。
- 刷新路径同样受预算约束:刷新发生在播放器已经在跑的时候,卡住的表现是声音还在、画面冻住。

- `Resolver` / `ResolverException`:解析契约与带码的失败(`resolver.unsupported` / `resolver.failed` /
  `resolver.timeout` / `media.expired` / `task.cancelled`),`canResolve` 要求离线可答。
- `ResolverRegistry` / `ResolverChain`:优先级排序 + 插入序破平;候选降级、`allowFallback == false` 时首个失败
  原抛且不再问后续候选、取消直接上抛不外溢成降级。
- `CapabilityResolver` / `CapabilityTicketRefresher`:把源的 `ResolveCapability` 提升成平台侧 `Resolver`,
  过期票据在门口挡下;换链时 `policy.allowRefresh` 与 `refresh.supported` 两道闸各测其分。
- 同层例外 `pure_live_resolver -> pure_live_capability` 进入护栏白名单与依赖规则 §4(见 [ADR 0021](../../../docs/adr/0021-resolver-capability-edge.md));
  正例与反例由 `tool/test_check_architecture.ps1` 钉住。
