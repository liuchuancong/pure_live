# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `FeedAggregator` / `CapabilityFeedAggregator`:按 `CapabilityRegistry` 枚举 feed 源、单源超时与失败隔离、
  节顺序取注册顺序而不是到达顺序,游标贯穿到源并原样带回(刷新 = 重新取第 1 页)。
- `FeedSection` 不带标题:首页编排(哪些节显示、顺序、名字)是用户数据,聚合器再造一个标题就是两处真相。
- 节内丢弃指向别源的行(`foreignItems`)与重复 ref(`duplicateItems`);跨源不去重。
