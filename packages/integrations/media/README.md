# pure_live_media

> 职责:media_core 播放内核接线与引擎适配

| 项 | 规则 |
|---|---|
| 层 | integrations(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;厂商 SDK 只允许出现在本层。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_media.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
