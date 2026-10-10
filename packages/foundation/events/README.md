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
  - 诊断面:`recentEvents`(上限 `kEventLedgerLimit`=64 的环形账本)、`countOf(name)` / `emissionCount`("这东西是不是每帧都在发")、`channelCount`(channel 数应当跟**事件类型数**走,跟"开过几个页面"走就说明有人没 cancel)
  - `observe(sink)` —— **不是订阅**:看得见没有任何监听者时的 emit,返回摘除函数;诊断与日志走这条路,不走 `on<T>()`(那要求先有一个业务订阅者)
  - `subscribe<T>(handler, into: Disposer)` —— 把"每个订阅都要记得 cancel"压成"每个组件 dispose 一次"
  - `onReplaying<T>(length)` —— 显式要旧事件时才给旧的:新界面在 `session.expired` 之后打开时**必须**知道它发生过
  - `expect<T>(within)` —— 等一个事实,不是轮询;轮询里的 sleep 是把竞态藏起来
  - `emitAll` / `countOf` / `fresherThan` 用的 `Clock` 由 `EventPublisher` 注入,固定时钟可以重放一段录制数据
- `operators.dart` —— 事件流的时间形状:`throttled`(首个立即过 + **窗口内最后一个**兜尾)、`coalescedBy(window, key)`(按 key 各自限速,`position(3:00)` 不会被 `position(2:10)` 挤掉)、`debounced`、`buffered`(窗口或条数谁先到就刷,只给条数=涓流永不刷,只给窗口=洪水全压在内存)、`named`(一个界面听 20 个事件里的 3 个,而不是订阅基类看全部)、`fresherThan`(恢复后别把十分钟前的"正在播放"当刚发生的)
- `sinks.dart` —— `EventLogSink`(每事件一行,**只记名字与时间不记 payload**:事件体里可能带含 token 的 url;`suspendAfter` 洪水保护,超限后自我挂起并 `isSuspended` 说清楚"日志停了而总线还在跑")、`EventRecorder`(有界环形,给诊断页与测试)、`EventPublisher`(用注入的 `Clock` 打 UTC 时间戳)

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze packages/foundation/events`(2026-10-11:0 issue)
- 测试:`dart test` —— **11 例**全绿(channel 归并、监听者抛错不影响他人、dispose 后 emit 惰性、payload 透传)。
  本轮新增的 `observe` / `onReplaying` / `expect` / 六个操作符 / 两个 sink **没有新增测试**。

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

- **整包零消费者**(台账 §2bis):没有任何 app 或包 `import 'package:pure_live_events'`,所以"哪些事实真该上总线"还没有一次实际投票。11 个测试是唯一的门。
- 异步投递带来的"同一次 emit 内多类型监听者的相对顺序"不再有保证 —— 这是换取隔离的代价,
  有真实消费者时需要按事实复核。
- 操作符的时序只按代码推演:窗口边界的竞态(`onCancel` 与 `Timer` 已触发交错)、`coalescedBy` 在 key 返回 `null` 时的合并、`buffered` 在流关闭时残余批次的顺序,都没有观测。
- `EventLogSink` 挂起阈值(200)是拍的;真机上弹幕/进度事件的实际每秒条数未测,所以"多久会挂起"不知道。
- `onReplaying` 返回**新**的单订阅流(与 `on<T>()` 的共享 broadcast 不同),调用方必须 cancel;这条差异只在文档里,没有测试钉住。
