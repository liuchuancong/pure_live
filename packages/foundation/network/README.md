# pure_live_network

> 职责:dio 封装:超时、重试、代理与网络错误分类

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_network.dart`;内部实现放 `lib/src/` |

## 内容

- `failure.dart` —— `NetworkFailureKind` + `NetworkFailure`,`code` 直接对齐 platform-models §14 的 network 命名空间(5xx / 重定向 / 未知三类是**对 §14 列表的扩展**,因为把 5xx 说成 `network.unreachable` 会让重试看板骗人)
- `client.dart` —— `NetworkSettings` + `NetworkClient`:超时、`attempts` 次退避重试、响应体大小上限、`getJson` 的形状校验;`validateStatus` 全放行,状态判定集中在这里

重试规则:timeout / unreachable / 429 / 5xx 可重试,**取消不重试**(§20 不变量 9)。日志里的 url 走 `redactQuery`,签名参数不落盘。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
