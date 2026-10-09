# pure_live_demo

> 职责:In-repo demo live source proving the capability-to-UI chain without any network access

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 + L1 plugin_api(经 host 注入的沙箱桥);同层禁互依;不得触碰 PlayerAdapter(I1/I5)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_demo.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md`
- `lib/src/demo_source.dart` —— 静态房间数据 + `FeedCapability` 实现

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
