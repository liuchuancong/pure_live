# pure_live_logging

> 职责:结构化日志与 talker 适配,统一应用日志出口

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_logging.dart`;内部实现放 `lib/src/` |

## 内容

- `record.dart` —— `LogLevel` 与不可变 `LogRecord`(时间进构造即转 UTC;字段在**构造时**脱敏,sink 不可能忘记)
- `redaction.dart` —— 字段脱敏规则表:名字命中(`token` / `authorization` / `cookie` / `wts` …,取自 `utils` 的
  `sensitiveHeaderNames` ∪ `sensitiveQueryKeys` 再加只在 body 出现的几个)整值遮;`*header*` 映射走 `utils.redactHeaders`;
  值里嵌着的凭据走 `utils.redactQuery`(是 url 时)或"赋值形状"正则(自由文本时)。**自由文本那条必须吃下整段值**:
  `Authorization: Bearer <token>` 只遮第一个词等于把凭据留在遮罩后面
- `logger.dart` —— `LogSink` 契约、`ConsoleLogSink`、`MemoryLogSink`(**默认上限 1000 + `droppedCount`**)、
  `LogRouter`(前缀阈值最长优先、**注入 `Clock`**、`dispatch` 逐 sink 隔离异常并经 `onDispatchError` 报出)、
  `formatRecordJson`、`Logger.named()` / `Logger.withFields()`(派生带上下文的 logger;上下文与普通字段一样先脱敏)
- `sinks.dart` —— `RotatingFileSink`(`maxBytesPerFile` × `maxFiles`,写时轮转,`.1/.2` 递增,磁盘满/文件被锁时
  记 `droppedCount` + `lastFailure` 而**绝不把异常抛回业务路径**)、`RateLimitedSink`(同 `level|logger|message`
  指纹每窗口最多 N 条,超出只计数,并周期性写一条"被抑制了 M 条"的 warning 让日志自己说明缺口)、
  `BufferedSink`(有界队列 + 定时 drain,满了丢最旧并计数,`dispose()` 先 drain)、`JsonLineSink`(每行一个 JSON,
  `includeStackTrace` 可关,因为设备日志的字节预算常被栈吃光)

应用只持有 **一个** `LogRouter`,从它取 `Logger` 下发;功能代码不 `print`、不装 Zone,测试直接塞一个 `MemoryLogSink` 断言。
talker 之类的外部后端在应用侧实现成 `LogSink` 接进来,本包不引它。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 平台矩阵

`logger.dart` / `sinks.dart` 引 `dart:io`(`stdout` 与文件轮转),因此本包**不含 web**。Android / Android TV / Windows /
Linux / macOS / iOS 可用;要接 web 需要把 `ConsoleLogSink` 的 `stdout` 换成注入的 `StringSink`,
`RotatingFileSink` 在 web 上没有对应物。

## 验证

- 分析:`dart analyze packages/foundation/logging`(2026-10-11:0 issue);同轮 `network` / `events` / `diagnostics` / `storage` 也 0 issue
- 测试:`dart test` —— **10 例**全绿(含"签名 url 字段被脱敏"、字段不可变、UTC 归一、前缀阈值)。
  本轮新增的 4 个 sink、`withFields`、`onDispatchError`、自由文本遮罩**没有新增测试**;10 例只证明旧语义没被打破。

## 未验证

- **`RotatingFileSink` 没在真机目录上跑过**:轮转的 rename 链、`.1/.2` 递增、Android 外部存储与 Windows AppData
  的权限差异,都只在代码里成立。`dispose()` 里 `unawaited(_sink?.close())` 与 `flush()` 的交错顺序未观测 ——
  崩溃前最后几行是否落盘不知道。
- `RateLimitedSink` 的默认阈值(10 秒 20 条)是拍的,没有对过真实弹幕/进度事件的条数;指纹不含字段值,
  **同一 sentence 不同上下文会被合并计数**,这对"风暴"是对的,对"逐房间排查"是错的。
- 自由文本赋值正则按**整词**名单匹配(`\bsign\b` 不会命中 `design:`,实测过),但它的值部分会吃掉凭据后面同一行里的
  空格分隔词:一行里同时有 `passwd:` 和 `sign=` 时,后一段被一并遮掉 —— 安全上偏保守,可读性上有代价。
  真实日志样本上的误遮率未测。
- 应用侧尚未装配:`grep -rn "pure_live_logging" apps` 为空,`LogRouter` 目前只在测试里被构造过。
