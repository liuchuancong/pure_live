# Favorites(收藏)

> 跨域收藏夹/分组,键 = ContentRef;与"关注"(平台侧关注列表)区分——关注来自源,收藏在本地。

## 结构

```text
FavoriteFolder(id, name, sortKey)
FavoriteEntry(ref, folderId, addedAt, snapshot 元数据)
```

## 规则

- 快照元数据(title/cover)随条目存储,源失效仍可见(降级显示)。
- 直播收藏附加"开播状态"能力查询(进入收藏页时按 capability 批量查询)。
- 排序手动 + 按时间;同步纳入 sync;v1 收藏迁移按 ContentRef 重写(见 [../migration/v1-to-v2.md](../migration/v1-to-v2.md))。
