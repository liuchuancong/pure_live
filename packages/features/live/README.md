# pure_live_live

> 职责:直播房间的**选流状态机** —— 画质与线路两轴的已提交选择,与"只在播放器真的打开新流之后才提交"的切换规则。
> 取流与刷新在 `ecosystem`/`providers`(LiveCapability 契约),播放状态在 `integrations/media`;这里不碰它们。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `domain/live_session.dart` | `StreamVariant` / `LiveSelection` / `SwitchAttempt` / `SwitchRequest`(Accepted / Noop / Refused)/ `SwitchFailure` / 不可变 `LiveSession` | 提交时机是平台级规则,不是某个 widget 的动画细节;`LiveCapability` 契约把 `resolve(quality, line)` 交给站点,把"什么时候算换成功"留给了这一层 |
| `domain/live_recovery.dart` | `LineDegrader` / `LineDegradeStep` / `LastWatched` / `LastWatchedStore` | 线路挂了该试哪条、下次启动该重开哪个房间,是**源内**的策略;跨源是 `ResolverChain` 的事,把两件事放一起就会出现"播着播着换到了别站的同id线路" |

## 行为契约

- 切换是**带身份的尝试**,不是一个 pending 标志:`requestSwitch` 返回 `SwitchAttempt`,`commitSwitch(attempt)`
  只认当前在飞的那个 id。被取代的尝试的迟到回调 → `SwitchFailure`,不改选择。
- 两轴独立:画质与线路各有自己的在飞尝试;换画质不会作废线路的尝试。
- 目标必须是源**本次提供过的**变体,否则 `SwitchRefused`;已提交在同一轴上的当前变体 → `SwitchNoop`
  (遥控器重复事件不是错误,不该弹错误提示)。
- 没有可播票据(`ticket.uri` 为空)→ `SwitchRefused`。
- 提交失败(`abandonSwitch`)不动已提交选择,也不报错;迟到/无效的失败报告被忽略。
- `withVariants` 换表:消失的变体会释放它的已提交选择与在飞尝试。
- `withTicket`(换票/刷新)保留选择,**作废在飞尝试** —— 旧 url 的回调描述的是已经不存在的流。
- 不可变:`variants` 与 `offered()` 给的快照都不能改;`active/pending/currentTicket` 不再公开可写
  (旧版本可以绕过提交规则直接赋值)。

### 线路阶梯与恢复记录(`live_recovery.dart`)

- `LineDegrader` 只走**本源提供过的线路**,默认线路排在最前,其后按源自己的顺序;`fail(lineId)` 记账并给出
  下一步,`peek()` 只问不记(给"要不要再试一条"的确认弹窗用)。
- 阶梯**永不跨源**:换站会连带换掉清晰度与线路的词汇表,那是 `ResolverChain` 的职责(source-contract.md §45
  的同一条理由)。
- 线路失败**不会顺手动清晰度** —— 一条线路死了说明不了用户选的码率;所以这个类根本不接受画质变体
  (`_ordered` 只留 `isLine`),而不是"有一个开关默认关掉"。
- `maxSwitches`(默认 4,`< 1` 直接 `ArgumentError`)是每间的重试上限;`initialLineId` 不在 offered 里 →
  `ArgumentError`,因为记一个不存在的 id 会让阶梯白跑一格。
- `LastWatched` 带 `v` 版本号:`v` 更大或不是整数 → 解析返回 null,即**读不了就什么都不开**,不猜形状;
  `at` 解析失败退回 epoch(等于"过期"),`line/quality` 非字符串按未选处理。
- `LastWatchedStore` 的每个 key 都带 `namespace` 前缀,两个 host 共用一个 `KeyValueStore` 也读不到彼此的记录;
  `selectionFor` 只接受源**此刻**还提供的变体 id,对不上就退回会话当前选择 —— 复活一条上周的线路 id 不是"恢复",
  是一次注定失败的 resolve。

## 依赖

允许:`ecosystem/platform`(`MediaTicket` / `ContentRef`)、`foundation/storage`(恢复记录落盘)与
`foundation/utils`。禁止:providers 直连、同层 feature、App 反向依赖。

## 平台矩阵

- `live_session.dart` 是纯 Dart,任何平台一致。
- `live_recovery.dart` 依赖 `pure_live_storage`,而该包的 barrel 里含 `FileKeyValueStore`(`dart:io`),
  所以**引入本包即不可编译到 web**。pure_live / pure_tvbox 的目标平台是 Android / Android TV / Windows,
  这条限制目前不挡任何交付;要恢复 web,得把 storage 的 io 实现拆成第二个 library(`pure_live_storage/io.dart`),
  那会动 6 处以上现有 importer,已记台账 §5 作为独立事项,不在本轮顺手改。

## 验证

- `dart analyze` → No issues found;`dart test` → 13 passed(全部在 `live_session.dart`)。
- `live_recovery.dart` 的行为是用一次性脚本 `dart run` 真跑过一遍后删掉的:阶梯顺序(默认线路在前 →
  `[a, b, c]`)、`maxSwitches=2` 在第 2 次失败处收口、单线路房间直接 `exhausted`、空表不抛且 `exhausted`、
  未知 `initialLineId` 与 `maxSwitches=0` 各抛 `ArgumentError`、恢复记录 round-trip / `v=99` 与 `'<html>'` 与
  双重编码都返回 null / 坏日期退到 epoch、namespace 隔离(两个 store 共用一个 KV 互不可见)、损坏 JSON 读出 null、
  `selectionFor` 对已消失的 line id 退回当前选择。**这些观测不可复现**(脚本已删),且本包**没有为恢复记录写过测试**。

## 未验证

- **没有 App 消费者**:真机上"切线路时迟到的开播回调"这条时序**未验证**,它是本轮从模型上堵住的坑,
  不是观测到的线上问题;阶梯与恢复记录同样没有任何 UI/播放器接入点。
- `LiveCapability` 契约里点名的类型(`QualityLine` / `QualityRef` / `LineRef` / `LiveDetail` / `StreamTicket`)
  在 `pure_live_platform` 里**还不存在**,所以这里的 `StreamVariant` 是本包自己的词汇;契约与模型对不齐这件事
  记在台账 §5。
- "画质记忆"作为**全局偏好**按契约属于 settings 侧,不在本包,现在仍然没人存(台账 §5 的偏好机制归层决策);
  `LastWatched.quality` 只是**这一间上次看的码率**,是恢复记录的字段,不是那条偏好的替身 —— 别把它当同一个东西读。
