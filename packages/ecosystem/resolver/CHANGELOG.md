# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `Resolver` / `ResolverException`:解析契约与带码的失败(`resolver.unsupported` / `resolver.failed` /
  `resolver.timeout` / `media.expired` / `task.cancelled`),`canResolve` 要求离线可答。
- `ResolverRegistry` / `ResolverChain`:优先级排序 + 插入序破平;候选降级、`allowFallback == false` 时首个失败
  原抛且不再问后续候选、取消直接上抛不外溢成降级。
- `CapabilityResolver` / `CapabilityTicketRefresher`:把源的 `ResolveCapability` 提升成平台侧 `Resolver`,
  过期票据在门口挡下;换链时 `policy.allowRefresh` 与 `refresh.supported` 两道闸各测其分。
- 同层例外 `pure_live_resolver -> pure_live_capability` 进入护栏白名单与依赖规则 §4(见 [ADR 0021](../../../docs/adr/0021-resolver-capability-edge.md));
  正例与反例由 `tool/test_check_architecture.ps1` 钉住。
