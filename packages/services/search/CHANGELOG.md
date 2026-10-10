# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `LiveSearchAggregator.stream`: outcomes land as their sources answer. The collected `Future.wait` path could
  not satisfy "partial results stay usable" - a twenty-source search showed an empty screen until the slowest
  source burned its whole budget, which a user reads as "no results".
- `SearchFanout.maxConcurrent` bounds how many sources one search asks at once; unbounded, a search is twenty
  simultaneous requests against whichever source is weakest.
- `SourceHealthLedger`: timeouts and failures recorded per source with a cooldown, tracked-source ceiling, and
  the rule that an empty answer is not a failure. Cooling-down sources are asked last rather than dropped - a
  source the user enabled is theirs to use again when it recovers.
- `firstAnswer` answers with either the first usable outcome or a `SearchWaitNotice`; making the slow path a
  null or an exception would delete the one clue that says "this is slow", which is what a spinner needs to say.
- `continuationFor` / `more()` read `PageResult.mode` instead of guessing: fixed-page advances the number,
  cursor re-sends the token, single-shot has no next page, and a page number that cannot advance is reported
  rather than looped.
- `askSearchSource` and `selectSearchTargets` are shared by both paths, so foreign-source filtering, the timeout
  and the "declared but not searchable" report exist once.

- `SearchAggregator` / `CapabilitySearchAggregator`:按 CapabilityRegistry 枚举搜索源、并发查询,
  每源超时与失败隔离、部分结果可用;空关键词不发任何请求。
- **新增(2026-10-10)**:`search(query, {cancellation})`。搜索框被改词是常态,而以前没有中止的缝:
  被取代的那次运行会以「十二个源 failed」的形式落地,那恰好是把健康 provider 写成病态的报告。
  已发出的每源请求仍不由这层取消(与 `perProviderTimeout` 同一条界),但中止的调用不再谎报源失败。
- `SearchProviderOutcome` 区分 `answered` / `empty` / `timedOut` / `failed`,并把指向别源的结果丢弃
  (`contract.search.foreign_source` 的第二道,针对没跑契约测试就发布的第三方源)。
