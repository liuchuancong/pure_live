# pure_live_utils

> 全仓共享的纯 Dart 基础能力。**五个模块,没有 misc**:async_tools / collections / result / strings / time。
> 只有一个功能需要的辅助函数,放进那个功能自己的包,不放这里。

## 为什么这么窄

这个包是依赖图的叶子,任何人在任何层都能 import 它,所以这里的每一行都被整个仓库继承。
通用工具包的失败模式不是缺功能,而是变成第二个 `dart:core`:一百个没人读过的扩展、
三套做同一件事的 API。取舍写进 [doc/design-decisions.md](doc/design-decisions.md)。

## 模块

| 模块 | 提供 | 为什么是它 |
|---|---|---|
| `async_tools` | `SingleFlight`、`retryAsync`、`AsyncMemoizer`、`OperationCancelledException`、Future/Stream 扩展 | 平台会重复发同一个请求(多个 widget 开同一房间、切线路重试死链),去重与退避必须只有一处实现 |
| `collections` | `groupBy` / `mapNotNull` / `distinctBy` / `chunked` + Iterable/List/Map 扩展 | 分组要保序、去重要按计算键、有界追加要丢头部 —— SDK 不给或给得不一样 |
| `result` | `Result<T,E>`(Ok/Err)、`partition` / `collect` / `waitAll` | DEVELOPMENT_STANDARDS §3.4 禁止用异常表达正常流程;解析失败、找不到内容是可预见失败 |
| `strings` | `nullIfBlank` / `collapsedWhitespace` / `truncate`、`redactHeaders` / `redactQuery`、`Truncator` | 敏感头脱敏是 platform-models §16 的硬要求;标题是中日韩加 emoji,按码元截会撕裂字符 |
| `time` | `Clock` 缝隙、`systemClock`、`FixedClock`、时长格式化、epoch 换算 | 过期判断与重试退避都要和"现在"比;直接读 DateTime.now() 就不可测 |

## 依赖

运行时只依赖 `collection` 与 `clock`,且都是**有理由的**:`collection` 提供这里转引用的 `firstOrNull` 等实现,
`clock` 提供可被 zone 覆盖的全局时钟,于是 `systemClock()` 与测试里的 `withClock()` 是同一个源。
`async` / `meta` 之类按源码需要再加,不加"以后可能用得上"的依赖。

## 用法

```dart
import 'package:pure_live_utils/pure_live_utils.dart';

final flight = SingleFlight<int>();
final value = await flight.run('room-1', () => source.viewers('room-1'));

final settled = await futures.waitAll();
if (!settled.isAllOk) {
  log.warning('${settled.errors.length} of ${settled.count} sources failed');
}
```

公共面清单见 [doc/public-api.md](doc/public-api.md)。
