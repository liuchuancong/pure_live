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

## 行为契约(2026-10-10 起)

- **一个事件类型一条 channel**,不是每次 `on<T>()` 一条:重复调用返回同一个 broadcast 流,
  忘记 cancel 只会泄漏一个订阅而不再泄漏一整个被 retain 的 controller。
- `hasListeners` = "有没有任何人在听";按类型问要用 `hasListenersFor<T>()`。
  以前这个 getter 声称能按类型回答 —— 它是 getter,拿不到类型参数,那是一句假话。
- **投递是异步的**:`sync: true` 会把监听者的异常沿 `emit()` 同步抛回发布者,
  于是设置页的一个 bug 能让"会话过期"事件整条链断掉。现在错误归创建订阅的那个 zone,总线继续给别人送。
- `dispose()` 幂等;之后 `emit` / `on` 变为惰性无害(拆除期的迟到发布者不该崩应用)。
- 规则没变也不打算变:§6 禁止用总线替代接口依赖。只有一个组件负责反应时,它该暴露方法。

## 未验证

- **零消费者**(catalog 里那行仍然成立)。11 个测试是唯一的门。
- 异步投递带来的"同一次 emit 内多类型监听者的相对顺序"不再有保证 —— 这是换取隔离的代价,
  有真实消费者时需要按事实复核。
