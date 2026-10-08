# pure_live_utils

> 职责:通用值类型、错误分类与零依赖基础扩展

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_utils.dart`;内部实现放 `lib/src/` |

## 内容

- `time.dart` —— `Clock` 注入缝与 `FixedClock`,加时长格式化;需要"现在几点"的代码一律接 Clock,不直接读 `DateTime.now()`
- `strings.dart` —— 空白/截断/URL 判定,以及 §16 要求的敏感 header 与签名 URL 脱敏
- `result.dart` —— `Result<T,E>`:可预期失败用返回值表达,异常只留给真正的异常
- `async_tools.dart` —— `SingleFlight` 同键去重、`retryAsync` 退避重试(取消按不变量 9 直接上抛)
- `collections.dart` —— `groupBy` / `mapNotNull` / `distinctBy` / `chunked`

本包是全仓叶子:**不加运行时依赖**,也不收留只服务单个功能的helper —— 那种东西留在它自己的包里。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
