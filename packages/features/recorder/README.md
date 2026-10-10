# pure_live_recorder

> 职责:一个录制任务的**生命周期契约** —— 录哪个流、写到哪个文件名、处于哪个状态、为什么结束、录了多久。
> 真正写文件的引擎(ffmpeg_kit / media_core)属于录制波,`lib/src/data/` 现在还是空的 —— 这是刻意的:
> 状态契约先立住,引擎来了才没有"UI 自己猜状态机"的第二套真相。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `domain/recording_task.dart` | 不可变 `RecordingTask` + `RecordingState` / `RecordingEndReason` / `RecordingFailure` / `requireSafeFileName` | 任务列表与播放器回调是不同代码,转换表只能有一份;时长与原因只能由状态算出来 |

## 状态机

```
queued --begin()--> recording --stop(reason)--> stopped
                          \\--fail(reason)-----> failed
```
- 终态不可逆:`begin` / `stop` / `fail` 在终态一律抛 `RecordingFailure`
  (旧实现把 `state` 做成公开可写字段,"迟到的编码器回调不能复活已结束的任务"这句话一行代码就能违反)。
- `stop` 与 `fail` **必须给原因**;`fail(userStopped)` 直接拒绝 —— 用户按停和磁盘满是两块不同的屏。
- `elapsed`:queued 为 0;recording 用注入时钟减 `beganAt`;终态用 `stoppedAt` 冻结
  (旧实现从创建时间算,排队一小时的录制在列表上显示"已录 1 小时")。
- 时间一律经 `Clock`(默认 `systemClock`),不读 `DateTime.now()` —— 否则这条条规则根本没法测。

## 文件与标识

- `fileName` 校验:非空白、不含 `/` `\` `..` 与内部控制字符。宿主会把它拼到录制目录后面,这里是最后一道能约束
  路径的地方;`requireSafeFileName` 也导出给"用户自己选文件"的导入路径用。
- `id` 用长度前缀的 `identityKey(source, content, createdAt)`,不再用 `/` 直拼(带分隔符的 contentId 会让两个
  房间撞成同一个 id),并且在状态转换间**保持稳定**,任务列表不会因为开始录制换了 key。

## 依赖

允许:`ecosystem/platform` + `foundation/utils`。禁止:providers 直连、同层 feature、App 反向依赖。

## 平台矩阵

纯 Dart(模型不含 io)。引擎波次落地时会引入平台相关依赖,那时本包 README 的平台矩阵要一起改。

## 未验证

- **没有 App 消费者**,13 个测试是唯一的门。
- `RecordingEndReason.engineLost` / `streamEnded` 谁来上报、重试几次,取决于还没写的引擎接线;
  这里只保证状态与原因是分开的。
- 没有实现"暂停 / 分段续录":契约没写,不发明。
