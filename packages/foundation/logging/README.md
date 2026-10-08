# pure_live_logging

> 职责:结构化日志与 talker 适配,统一应用日志出口

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_logging.dart`;内部实现放 `lib/src/` |

## 内容

- `record.dart` —— `LogLevel` 与不可变 `LogRecord`(时间进构造即转 UTC;`*header*` / `*url*` 字段在构造时就脱敏,sink 不可能忘记)
- `logger.dart` —— `LogSink` 契约、`ConsoleLogSink`、`MemoryLogSink`、`LogRouter`(按 logger 前缀设阈值,最长前缀优先)、`Logger.named()` 层级命名

应用只持有 **一个** `LogRouter`,从它取 `Logger` 下发;功能代码不 `print`、不装 Zone,测试直接塞一个 `MemoryLogSink` 断言。talker 之类的外部后端在应用侧实现成 `LogSink` 接进来,本包不引它。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
