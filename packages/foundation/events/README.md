# pure_live_events

> 职责:进程内事件总线,不替代正常接口依赖

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_events.dart`;内部实现放 `lib/src/` |

## 内容

- `event_bus.dart` —— `AppEvent` / `SimpleEvent` / `EventBus`:按声明类型投递,订阅前的事件不回放(要当前状态去问拥有它的组件,这正是"不许拿事件总线代替接口依赖"的落点),`dispose` 后 `emit` 静默返回而不是抛

## 
## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
