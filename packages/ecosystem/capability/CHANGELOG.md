# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Added**: `LiveRoomCapability.room(ref) -> LiveRoom`, and `CapabilityKind.live` now requires it in the contract
  checker alongside `BrowseCapability` / `ResolveCapability`. A source that can only hand back a tile with the
  room's facts under string keys was declaring a feed, not the live surface: the anchor, the 分区, the audience
  figure and the paywall flag are the room, and they belong in the model that says so.
- `CapabilityKind` 与四个有方法集的接口(`BrowseCapability` / `SearchCapability` / `ResolveCapability` /
  `FeedCapability`)、注册上报用的 `CapabilitySet`(W1 首切片)。
- `lib/testing.dart`:契约断言,返回带稳定 `code` 的 `List<ContractViolation>`,内置源与脚本源跑同一套(W2)。
- `CapabilityRegistry` / `ProviderRegistration`:按 sourceId 注册与覆盖、按 `CapabilityKind` 路由声明面、
  按接口类型取实现面、按 extensionId 批量注销(provider-contract.md §3 与 plugin-lifecycle.md 的 Enabled 行)。
