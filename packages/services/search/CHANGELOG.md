# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `SearchAggregator` / `CapabilitySearchAggregator`:按 CapabilityRegistry 枚举搜索源、并发查询,
  每源超时与失败隔离、部分结果可用;空关键词不发任何请求。
- `SearchProviderOutcome` 区分 `answered` / `empty` / `timedOut` / `failed`,并把指向别源的结果丢弃
  (`contract.search.foreign_source` 的第二道,针对没跑契约测试就发布的第三方源)。
