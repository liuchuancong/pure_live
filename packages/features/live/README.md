# pure_live_live

> 职责:直播房间的**选流状态机** —— 画质与线路两轴的已提交选择,与"只在播放器真的打开新流之后才提交"的切换规则。
> 取流与刷新在 `ecosystem`/`providers`(LiveCapability 契约),播放状态在 `integrations/media`;这里不碰它们。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `domain/live_session.dart` | `StreamVariant` / `LiveSelection` / `SwitchAttempt` / `SwitchRequest`(Accepted / Noop / Refused)/ `SwitchFailure` / 不可变 `LiveSession` | 提交时机是平台级规则,不是某个 widget 的动画细节;`LiveCapability` 契约把 `resolve(quality, line)` 交给站点,把"什么时候算换成功"留给了这一层 |

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

## 依赖

允许:`ecosystem/platform`(`MediaTicket` / `ContentRef`)与 `foundation/utils`。禁止:providers 直连、同层 feature、App 反向依赖。

## 平台矩阵

纯 Dart,无 io;Android / Android TV / Windows / iOS / web 一致。

## 未验证

- **没有 App 消费者**:13 个测试是唯一门;真机上"切线路时迟到的开播回调"这条时序**未验证**,
  它是本轮从模型上堵住的坑,不是观测到的线上问题。
- `LiveCapability` 契约里点名的类型(`QualityLine` / `QualityRef` / `LineRef` / `LiveDetail` / `StreamTicket`)
  在 `pure_live_platform` 里**还不存在**,所以这里的 `StreamVariant` 是本包自己的词汇;契约与模型对不齐这件事
  记在台账 §5。
- "画质记忆"按契约属于 settings 侧,不在本包;而 features 同层禁互依,所以那条偏好现在没人存 —— 同台账 §5 的
  偏好机制归层决策。
