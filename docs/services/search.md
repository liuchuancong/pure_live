# Search(聚合搜索)

## 流程

```text
SearchRequest(关键词/过滤器)
 → CapabilityRegistry 枚举 SearchProvider(用户启用的源)
 → 并发查询(超时/失败隔离,部分结果可用)
 → SearchResult[] = ContentItem[](必须 ContentRef,不允许平台 ID)
 → UI 分组呈现(直播/视频/音乐/频道)
```

## 规则

- 全局搜索 / 站内搜索 / 音乐搜索 / 影视搜索 / 插件搜索共用一套 `SearchRequest/SearchResult/SearchProvider/SearchFilter/SearchCursor`。
- 结果点击 = ContentRef → 直达;无结果源静默标记,不阻塞其他源。
- 搜索历史与热搜(热词 capability)本地化存储。
