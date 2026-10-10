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

## 任务列表这一层(2026-10-11)

`recording_manager.dart` 管的是模型没说的那四件事 —— 谁可以开、同时能开几个、磁盘够不够、被杀进程留下的
`recording` 行算什么:

- `RecordingStore`(整份列表过 `KeyValueStore`,有 `historyLimit` 上限;未知 `state`/`endReason` 名**不猜**,整行丢)
- `RecordingEngine` / `StorageProbe` 端口:编码器接线是 recorder 那一波的事,任务列表不等它
- `restore()` 把上次进程留下的 `recording` 一律判 `failed/engineLost` 并回写:引擎随进程死了,
  那一行继续占并发槽、UI 继续跳一个在涨的计时器、stop 它什么也写不出来
- `start()` 先查并发与**剩余空间**(按 `reserveBytes` 预留,不是量产出),再让引擎落笔:录到 90% 才失败的
  文件是用户以为自己已经拥有的东西
- 引擎说"不"→ 任务**留在 queued**(不是 failed),可以再点开始;`duplicateFileName` 拒同名两个在录的任务
- `stop()` 先叫引擎再落状态;`remove()` 只准删已结束的行(删掉在录的会留下没有主人指向的文件与引擎句柄)
- 时钟**注入到 store**:`RecordingTask.restore` 带 clock,否则恢复出来的行会用墙钟盖 `stoppedAt`,
  而 `beganAt` 来自注入时钟 —— 实测这样算出的 `elapsed` 是**负数**

## 验证

- 分析:`dart analyze packages/features/recorder`(2026-10-11:0 issue)
- 测试:`dart test` —— **13 例**全绿(全是生命周期模型的迁移/拒绝:`begin` 用注入时钟、终态不可复活、相等性随状态)。
  `RecordingManager` 与 `RecordingStore` **没有新增测试**;行为用仓库外一次性脚本实测:同名第二个任务被拒、
  并发=1 时第二条 `tooManyRunning`、`probe` 给 10MB 时 `notEnoughSpace`(预留 512MB)、引擎抛错后任务仍是
  `queued` 且引擎没写文件、跨重启 restore 出 `failed/engineLost` 且 `elapsed=1:30:00`(第二次 restore 不再动它)、
  未结束的行不许 remove。脚本已删除,而这一层**修掉过两个只有跑起来才暴露的缺陷**:往不可变列表按下标写、
  以及上面那条负数 `elapsed`。

## 未验证

- 真机录音/录像:引擎端口没有任何实现,`reserveBytes` 该给多大、按什么码率算时长上限都没量过。
- 并发默认 1(按手机编码器),Android TV / Windows 上能不能并行未测。
