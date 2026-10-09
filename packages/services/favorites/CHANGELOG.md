# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `FavoriteFolder` / `FavoriteEntry` / `FavoritesService`:跨域收藏,键是完整 `ContentRef`,
  快照(`ContentSummary`)随条目存,因此收藏页从不问源(源失效仍可见)。
- `FavoriteRepository` 端口给细粒度操作(换 Drift 绑定时上面一层不动),今天由 `KeyValueFavoriteRepository` 绑定。
- 分组顺序取用户的 `sortKey`;条目没有排序权重所以按 `addedAt` 倒序;删非空分组直接拒,
  重复添加只刷新快照不改 `addedAt`;读不懂的文档抛 `FormatException` 而不是当空处理。
