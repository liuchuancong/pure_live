# pure_live_huya

> 职责:Huya live source: recommend feed and HLS resolve per the v1-maintained protocol notes

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 + L1 plugin_api(经 host 注入的沙箱桥);同层禁互依;不得触碰 PlayerAdapter(I1/I5)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_huya.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/models`
- `fixtures`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
