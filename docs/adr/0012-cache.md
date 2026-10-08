# ADR 0012:缓存系统(Cache System)

- 状态:已接受(2026-10-08)

## 背景

v1 缓存散落(flutter_cache_manager/各域自建),无配额、无统一清理,插件化后还有隔离需求。

## 决策

缓存为 Foundation 能力:CacheStore/CachePolicy/CacheEntry/CacheNamespace/CacheEviction;命名空间 image/media/music/subtitle/danmaku/plugin/metadata/epg/fonts;每空间独立配额与淘汰;插件只能用自己命名空间。flutter_cache_manager 归入 image 命名空间统一配额。见 [../services/cache.md](../services/cache.md)。

## 后果

- 正:用户可控(查看/清理);插件卸载可全清;磁盘占用可预期。
- 负:所有读写要走 CacheStore 门面(纪律成本,由包边界保证)。
