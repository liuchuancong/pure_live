# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `SearchAggregator` / `CapabilitySearchAggregator`:按 CapabilityRegistry 枚举搜索源、并发查询,
  每源超时与失败隔离、部分结果可用;空关键词不发任何请求。
- **新增(2026-10-10)**:`search(query, {cancellation})`。搜索框被改词是常态,而以前没有中止的缝:
  被取代的那次运行会以「十二个源 failed」的形式落地,那恰好是把健康 provider 写成病态的报告。
  已发出的每源请求仍不由这层取消(与 `perProviderTimeout` 同一条界),但中止的调用不再谎报源失败。
- `SearchProviderOutcome` 区分 `answered` / `empty` / `timedOut` / `failed`,并把指向别源的结果丢弃
  (`contract.search.foreign_source` 的第二道,针对没跑契约测试就发布的第三方源)。
