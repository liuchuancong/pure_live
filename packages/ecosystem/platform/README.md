# pure_live_platform

> 职责:平台契约与共享模型伞包:Extension/Source/Repository/Content/Resolver/MediaTicket/Error/Diagnostics 的数据定义

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_platform.dart`;内部实现放 `lib/src/` |

## 结构

模型按 [platform-models §18](../../docs/contracts/platform-models.md) 的关注点分目录,放在 `lib/src/models/<关注点>/`
(§18 写的是 `lib/models/...`;本包遵守"公开面只有 barrel、内部实现进 `lib/src/`"的仓库规则,分组语义不变)。
首切片 = §19 的 TVBox 播放通所需模型;`ContentIdentity` / `Task` / `PermissionGrant` / 聚合 / EPG / 音乐随各自波次补。

`MediaTrack` 是 media_core 类型的**平台镜像**,映射在 `packages/integrations/media`,理由与约束见
[ADR 0016](../../docs/adr/0016-platform-media-track-mirror.md)。

## 验证

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(本包目录内)
- 测试:`dart test` —— 37 例,覆盖 JSON 往返、枚举按名序列化、未知字段容忍、相等性规则与 §16 的 UTC/毫秒约定
