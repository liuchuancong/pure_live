# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- W2:`PermissionManager` 端口与最小授权实现(descriptor 天花板、未注册即无授权、拒绝留存、过期报 unknown)、
  `ExtensionNetwork` 唯一网络出口(权限 → 超时夹取 → 并发闸 → 落地后 `finalUri` 复核 → 体积上限)、
  `ExtensionCookieStore` 按扩展隔离与 Cookie 脱敏。

- `KeyValuePermissionStore`:grant 存进 L0 的 `KeyValueStore`,授权与拒绝因此能跨重启;
  键用 `permission.<extensionId>/<permission>` 的形状,避免 `purelive.a` 的前缀清扫到 `purelive.ab`。
- `UnaskedPrompts`:占位 prompt 答 `unknown` 而不是 `denied`。持久化之后这两者不再等价 ——
  被记下来的 `denied` 永不重问,占位实现等于替用户做了个他不曾做过的否定决定。
