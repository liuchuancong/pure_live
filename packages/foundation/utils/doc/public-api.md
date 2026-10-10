# 公共面(pure_live_utils)

包 barrel `lib/pure_live_utils.dart` 导出十三个模块(async / collections / conversion / equality / errors /
identifiers / math / numbers / result / strings / time / types / validation);result 的三个组成文件由包
barrel 直接导出,因为它是"类型 + 三种用法"而非一个 barrel。
新增公开符号必须同时出现在这里与 CHANGELOG,否则视为内部实现。
每个模块为什么存在,见 [design-decisions.md](design-decisions.md) §1 的实测重复计数。

## async

| 符号 | 文件 | 作用 |
|---|---|---|
| `SingleFlight<T>` | `single_flight.dart` | 同键并发只跑一次,结果共享给在途调用者 |
| `retryAsync<T>` | `retry.dart` | 带上限指数退避的重试;`Sleeper` 与全局 `jitter` 可注入 |
| `Sleeper` | `retry.dart` | 等待的时间缝 |
| `OperationCancelledException` | `cancellation_token.dart` | 取消不是失败:重试循环见它立即上抛(platform-models §20 不变量 9) |
| `CancellationToken` | `cancellation_token.dart` | 单向闩:`addListener` / `cancel` / `throwIfCancelled` / `guard` |
| `AsyncOnce<T>` | `async_once.dart` | 每键至多算一次并保留结果;失败不记,`reset` 才重来;`maxEntries` 有界 |
| `AsyncMemoizer<T>` | `async_memoizer.dart` | 按键缓存异步结果,带 TTL 与 `maxEntries` 上限;按写入序淘汰 |
| `Disposable` / `Disposer` / `ReleaseAction` | `disposable.dart` | 收集本对象拥有的句柄,倒序释放一次,首个错误重抛 |
| `OperationGuard` / `OperationInProgressException` | `operation_guard.dart` | 同一时刻只允许一个用户动作;重复触发是**具名拒绝**而非共享结果 |
| `FutureUtils<T>` | `future_extensions.dart` | `nullable` / `orFallback` / `ignore` |
| `StreamUtils<T>` | `stream_extensions.dart` | `debounce` / `distinctByKey` / `firstOrNull` |

## collections

| 符号 | 文件 | 作用 |
|---|---|---|
| `groupBy` / `mapNotNull` / `distinctBy` / `chunked` | `collection_helpers.dart` | 顶层函数,保持既有调用点不变 |
| `IterableUtils<T>` | `iterable_extensions.dart` | `head` / `singleOrNull` / `uniqueBy` / `sumBy` / `partitionBy` |
| `ListUtils<T>` | `list_extensions.dart` | `elementAtOrNull` / `move` / `appended` / `indexOfOrNull` |
| `MapUtils<K,V>` | `map_extensions.dart` | `getOrPut` / `mergedWith` / `whereValue` / `readWhere` |

## conversion

| 符号 | 文件 | 作用 |
|---|---|---|
| `intFrom` / `doubleFrom` / `boolFrom` | `safe_convert.dart` | 运行时形状转数值/布尔,不猜:转不了就是 null |
| `stringFrom` / `stringOrNull` | `safe_convert.dart` | 显示文本默认 `''`,必填字段用后者 |
| `jsonMapFrom` / `listFrom` / `stringListFrom` | `safe_convert.dart` | json 容器整体校验,键型不符就整份拒绝 |

## equality

| 符号 | 文件 | 作用 |
|---|---|---|
| `ValueEquality` | `field_equality.dart` | mixin:声明 `equalityFields` 一处,`==` 与 `hashCode` 不会漂移 |
| `sameFieldList` / `deepEquals` / `deepHashAll` / `deepHash` | `field_equality.dart` | 嵌套 List/Set/Map 按内容比较与哈希 |

## errors

| 符号 | 文件 | 作用 |
|---|---|---|
| `DomainFailure` | `domain_failure.dart` | 跨包上报的失败形状:`reason` + `cause` + 稳定 toString |
| `UnexpectedFailure` | `domain_failure.dart` | 没有具名类型的错误在边界处被包住,而不是裸抛 |

## identifiers

| 符号 | 文件 | 作用 |
|---|---|---|
| `identityKey` | `identity_key.dart` | 带长度前缀的复合键,`['a','bc']` 与 `['ab','c']` 不撞 |
| `normalizeToken` / `sameToken` | `identity_key.dart` | 跨源 id 比较前的折叠(trim + 小写 + 空白折叠) |

## math

| 符号 | 文件 | 作用 |
|---|---|---|
| `ClosedInterval` | `interval.dart` | 闭区间值:`clamp` / `contains` / `fractionOf` / `pointAt`,零宽区间不产 NaN |

## numbers

| 符号 | 文件 | 作用 |
|---|---|---|
| `clampInt` / `clampDouble` | `number_utils.dart` | 返回具体类型的钳位(sdk 的 `clamp` 返回 `num`) |
| `lerpDouble` / `roundTo` / `percentOf` | `number_utils.dart` | 插值、定点舍入、占比(总量为 0 时答 0) |
| `ByteSize` | `byte_size.dart` | 带单位名与 `humanReadable` 的字节数;单位是二进制 KiB/MiB/GiB |

## result

| 符号 | 文件 | 作用 |
|---|---|---|
| `Result<T,E>` / `OkResult` / `ErrResult` | `result.dart` | 可预见失败的载体 |
| `ResultUtils<T,E>` | `result_extensions.dart` | `requireValue` / `fold` / `tapErr` |
| `ResultFailureException<E>` | `result_extensions.dart` | 仅由 `requireValue` 抛出 |
| `ResultCollection<T,E>` | `result_sequence.dart` | `values` / `errors` / `isAllOk` / `count` |
| `ResultIterable<T,E>` | `result_sequence.dart` | `partition` / `collect` |
| `ResultFutureIterable<T,E>` | `result_sequence.dart` | `waitAll`(被拒绝的 future 直接上抛) |
| `captureResult` / `captureAsync` | `result_transformers.dart` | 会抛的调用进入 Result 的唯一缝,`onFailure` 必填 |
| `ResultFutureUtils<T,E>` | `result_transformers.dart` | `andThen` / `recover` |

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

## types

| 符号 | 文件 | 作用 |
|---|---|---|
| `Unit` | `type_utils.dart` | 无产出操作的成功值,让 `Result<Unit, E>` 写得出来 |
| `TypeChecks` | `type_utils.dart` | `asOrNull<T>()` / `or<T>(fallback)`:形状不符是数据,不是类型错误 |

## validation

| 符号 | 文件 | 作用 |
|---|---|---|
| `requireNonBlank` / `requireInRange` / `requireNotEmpty` / `requireNonNull` | `require.dart` | 公共边界处的参数拒绝,统一抛 `ArgumentError` 并带上参数名 |
