# pure_live_sync

> 职责:云同步数据面,依赖 integrations/firebase

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包 + L0 叶子(utils、logging);远端是端口,厂商 SDK 由组合根绑定。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_sync.dart`;内部实现放 `lib/src/` |

## 内容

- `sync_engine.dart` —— `SyncRecord`(删除走 tombstone)、`SyncCursor`、`RemoteBatch`、`ConflictPolicy`
  (remoteWins / localWins / newestWins,**时间戳相同按远端**,因为对端已经应用过那一版)、`SyncEngine.pull` /
  `pullAll` / `push`、`SyncReport`(+ `conflictKeys` 有界名单、`pages`、`stopReason`、`isCapped`)、`SyncStopReason`
- `coordinator.dart` —— `SyncCoordinator`(`request()` 去抖合并成一次、single-flight 不并发跑、失败走
  `SyncSchedule.backoffFor` 的指数退避并有上限、失败账本有上界 `failureLedgerLimit`=32、`stop()` 幂等且
  不会把在途失败的异常甩给"只想关停"的调用方)、`SyncSchedule`、`SyncFailure`
- `local_store.dart` —— `MemoryLocalStore`(参考实现:测试与 app 早期装配用,DB 版落地前不必每家自写一个)、
  `PendingQueue`(同键后写覆盖前写并**保持原位**,重排会把用户的编辑顺序打乱;上限 1024,满了丢最旧并计数)、
  `TombstonePolicy`(**按时间 + 按条数**双重上限:只看时间会让十万条墓碑再存三十天,只看条数会忘掉最近的删除)

远端是**端口**不是依赖:[dependency-rules §4](../../../docs/architecture/dependency-rules.md) 把 sync → firebase 列为批准例外,但厂商 SDK 由应用绑定,这样这个包不需要网络也能测。凭据两端都不参与同步。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze packages/foundation/sync`(2026-10-11:0 issue)
- 测试:`dart test` —— **18 例**全绿(游标前进、同游标不谎报、空 key/同批重复计数、凭据双向拒、冲突三策略、
  JSON 往返保 tombstone)。`pullAll` / `SyncCoordinator` / `MemoryLocalStore` / `PendingQueue` / 墓碑清理
  **没有新增测试**;它们的行为用一份仓库外的一次性脚本跑通(两页拉到 `exhausted` 且游标到 `p2`、
  两次 `request()` 合并成 1 个 pass、远端抛错 → `isWaitingForBackoff=true` 且账本 1 条、push 把删除墓碑发出),
  脚本已删除,这组观测不可重放。

## 行为契约(2026-10-10 起)

- **游标必须随批次前进**:`RemoteStore.fetchSince` 返回 `RemoteBatch(records, cursor)`。
  引擎拿不到新位置就没有「增量」可言 —— 旧实现把收到的 `from` 原样回显,于是
  `pull(from: lastReport.cursor)` 每次都重拉全部历史,而且看起来完全正常。
- **「这一趟没学到位置」要能表达**:`SyncReport.nextCursor` 可空,继续用 `report.cursorAfter(held)`。
  旧的 `push()` 在无待推送时返回 `SyncCursor.start`,照着它走的调用方每次空闲都重置成全量。
- 远端交回同样的游标**不算前进**(不谎报进度)。
- 不可用的行**计数而不是悄悄丢**:空 key → `rejected`;同批重复 key 保留后一条并计数;
  凭据键单独计数(那是远端在违反规则,不是它发了垃圾)。
- `SyncCursor` 有值相等:「这一趟是否前进了」是比较,比身份会对每个相同 token 答「没前进」。
- **翻页必须自己判定三种停止**:`exhausted` / `noAdvance` / `pageCap`。远端每页都回同一个游标是一种很常见的
  坏实现,没有 `noAdvance` 这条,翻页循环就是一条长得跟"同步进行中"一模一样的无限下载。
  `isCapped` 把"到达上限、远端还有剩余"说清楚 —— 把封顶当全量同步完,永远同步不完。

## 依赖与边界

允许:`foundation/utils`、`foundation/logging`(叶子)。禁止:任何厂商 SDK —— 远端是端口,Firebase 由组合根绑定
(docs/services/sync.md:同步是用户内容的数据面,凭据永不下发,`isCredentialKey` 在这层双向强制)。

## 未验证

- **零消费者**:测试都跑在假 remote / 假 local 上。真实 Firebase 的游标语义
  (是否单调、分页边界、重放同一 token 会怎样)**完全未验证** —— 而「同一游标不算前进」这条就是为它准备的保险。
- `SyncStopReason.noAdvance` 这条分支只在代码里推演过,一次性脚本用的是会前进的假远端,没打出过这个值。
- `SyncCoordinator` 的退避与去抖是**墙钟 + Timer** 驱动的:注入 `Clock` 只影响时间戳与退避计算,
  `Timer` 仍按真实时间走,所以 `minInterval`/`debounce` 的到点行为在测试里不可复现。
- 时钟偏移:两边各写各的 `updatedAt`,`newestWins` 直接比较。设备快 5 分钟就会**总是赢**,这不是本层能修的
  (需要向量时钟或服务端时间),真机双设备未验证。
- `MemoryLocalStore` 不落盘,进程退出即失;app 侧的 DB 绑定与 `purgeTombstones` 的调用时机都还没接。
