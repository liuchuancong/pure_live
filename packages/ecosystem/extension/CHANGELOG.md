# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- W2:`Extension` / `ExtensionRuntime` / `Source` / `ExtensionContext` 契约,`ManagedExtensionGateway` 生命周期
  状态机与运行时选择,`NetworkClientTransport`(平台 `ExtensionNetwork` 落在 `pure_live_network` 上)。
- `PersistentExtensionCache` / `PersistentExtensionStorage` / `ExtensionNamespace`:按
  `extension.<id>.<area>.<key>` 隔离的落盘视图;TTL 存**到期时刻**而不是时长,unreadable 行按未命中处理并被剔除。
- `ManagedExtensionGateway` 新增 `cacheFactory` / `storageFactory` 接缝。默认仍是内存视图且随记录一起丢弃,
  因此本次改动不改变任何现有扩展的行为。
