# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## 0.1.0

- 按模块拆分目录:`lib/src/<module>/`,每模块一个 barrel,包 barrel 只导出五个模块。
- 新增 `AsyncMemoizer`(带 TTL 与条数上限的异步记忆化)、`Stream.debounce` / `distinctByKey` /
  `firstOrNull`、`Future.nullable` / `orFallback` / `ignore`。
- 新增 collections 扩展:`head` / `singleOrNull` / `uniqueBy` / `sumBy` / `partitionBy`、
  `elementAtOrNull` / `move` / `appended` / `indexOfOrNull`、`getOrPut` / `mergedWith` /
  `whereValue` / `readWhere`。
- 新增 result:`ResultCollection`、`partition` / `collect` / `waitAll`、`requireValue` / `fold` / `tapErr`。
- 新增 `Truncator`(hard / word / grapheme 三种截断策略)与 `isBlank`;`truncate` 保留为按码元的简版。
- 新增 `Timestamps`(秒 / 毫秒 / 微秒 epoch 与 `parseAmbiguous`)、`Duration.asHms` / `asCompact`、
  `DateTime.sameDayAs` / `startOfDay`。
- **行为变化**:`systemClock()` 改为经 `package:clock` 读取,zone 内覆盖时钟现在会影响默认值。
- `redactHeaders` 增加 `extraSensitiveNames`;默认敏感查询键提为具名常量 `sensitiveQueryKeys`。
