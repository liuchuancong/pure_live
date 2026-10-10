# 公共面(pure_live_utils)

包 barrel `lib/pure_live_utils.dart` 导出五个模块 barrel;下表是全部公开符号与其归属文件。
新增公开符号必须同时出现在这里与 CHANGELOG,否则视为内部实现。

## async_tools

| 符号 | 文件 | 作用 |
|---|---|---|
| `SingleFlight<T>` | `single_flight.dart` | 同键并发只跑一次,结果共享给在途调用者 |
| `retryAsync<T>` | `retry.dart` | 带上限指数退避的重试;`Sleeper` 可注入 |
| `OperationCancelledException` | `retry.dart` | 取消不是失败:重试循环见它立即上抛(platform-models §20 不变量 9) |
| `Sleeper` | `retry.dart` | 等待的时间缝 |
| `AsyncMemoizer<T>` | `async_memoizer.dart` | 按键缓存异步结果,带 TTL 与 `maxEntries` 上限 |
| `FutureUtils<T>` | `future_extensions.dart` | `nullable` / `orFallback` / `ignore` |
| `StreamUtils<T>` | `stream_extensions.dart` | `debounce` / `distinctByKey` / `firstOrNull` |

## collections

| 符号 | 文件 | 作用 |
|---|---|---|
| `groupBy` / `mapNotNull` / `distinctBy` / `chunked` | `collection_helpers.dart` | 顶层函数,保持既有调用点不变 |
| `IterableUtils<T>` | `iterable_extensions.dart` | `head` / `singleOrNull` / `uniqueBy` / `sumBy` / `partitionBy` |
| `ListUtils<T>` | `list_extensions.dart` | `elementAtOrNull` / `move` / `appended` / `indexOfOrNull` |
| `MapUtils<K,V>` | `map_extensions.dart` | `getOrPut` / `mergedWith` / `whereValue` / `readWhere` |

## result

| 符号 | 文件 | 作用 |
|---|---|---|
| `Result<T,E>` / `OkResult` / `ErrResult` | `result.dart` | 可预见失败的载体 |
| `ResultUtils<T,E>` | `result_extensions.dart` | `requireValue` / `fold` / `tapErr` |
| `ResultFailureException<E>` | `result_extensions.dart` | 仅由 `requireValue` 抛出 |
| `ResultCollection<T,E>` | `result_transformers.dart` | `values` / `errors` / `isAllOk` / `count` |
| `ResultIterable<T,E>` | `result_transformers.dart` | `partition` / `collect` |
| `ResultFutureIterable<T,E>` | `result_transformers.dart` | `waitAll` |

## strings

| 符号 | 文件 | 作用 |
|---|---|---|
| `StringExtras` | `string_extensions.dart` | `nullIfBlank` / `collapsedWhitespace` / `isBlank` / `truncate` |
| `sensitiveHeaderNames` / `redactedPlaceholder` / `sensitiveQueryKeys` | `string_normalizer.dart` | 脱敏常量(platform-models §16) |
| `isHttpUrl` / `hostOf` / `redactHeaders` / `redactQuery` | `string_normalizer.dart` | URL 文本判定与脱敏 |
| `Truncator.at` / `TruncateMode` | `string_truncator.dart` | 显式截断策略:hard / word / grapheme |

## time

| 符号 | 文件 | 作用 |
|---|---|---|
| `Clock` / `systemClock` / `FixedClock` | `time_source.dart` | 时间缝;`systemClock` 经 package:clock,`FixedClock` 可调用 |
| `DurationFormatting` | `date_time_extensions.dart` | `asHms` / `asCompact` |
| `DateTimeComparison` | `date_time_extensions.dart` | `sameDayAs` / `startOfDay` |
| `Timestamps` | `timestamp_converter.dart` | 秒/毫秒/微秒 epoch 双向与 `parseAmbiguous` |
