# Cache(缓存)

> 缓存是 Foundation 能力:命名空间化 + 策略化,业务/插件不得自建缓存目录。

## 模型

```text
CacheStore / CachePolicy(ttl/大小上限/淘汰)/ CacheEntry / CacheNamespace / CacheEviction
```

## 命名空间

`image` / `media`(含视频背景资源)/ `music` / `subtitle` / `danmaku` / `plugin` / `metadata` / `epg` / `fonts`

## 规则

- 不同插件不能操作其他插件命名空间(隔离);每命名空间独立容量配额与清理。
- 设置页提供按命名空间的缓存查看与清理。
- 图片缓存继续走 cached_network_image + flutter_cache_manager,但归入 image 命名空间统一配额。
