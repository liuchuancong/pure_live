# Feed(聚合推荐流)

> Home 不是业务数据源,只是 Feed 聚合器。

## 结构

```text
FeedSource[](各源 FeedCapability / 关注更新 / 历史"继续看")
 → FeedAggregator → FeedSection[](标题 + FeedItem[] + cursor)
 → Home
```

## 规则

- Home 不直接依赖 Bilibili/Douyu/Music;只消费 FeedSection。
- 源的推荐内容经 `RecommendationCapability/FeedCapability` 提供;无该能力的源不出现在 Feed(可由用户在首页编排中手动添加入口)。
- 分页 cursor 贯穿到 Provider;刷新 = 重新拉取头部。
- 首页模块编排(哪些 Section 显示/顺序)是用户数据(sync 范围)——生态定制化入口。
