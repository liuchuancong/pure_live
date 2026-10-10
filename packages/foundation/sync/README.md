# pure_live_sync

> 职责:云同步数据面,依赖 integrations/firebase

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_sync.dart`;内部实现放 `lib/src/` |

## 内容

- `sync_engine.dart` —— `SyncRecord`(删除走 tombstone)、`SyncCursor`、`ConflictPolicy`(remoteWins / localWins / newestWins,**时间戳相同按远端**,因为对端已经应用过那一版)、`SyncEngine.pull` / `push`

远端是**端口**不是依赖:[dependency-rules §4](../../../docs/architecture/dependency-rules.md) 把 sync → firebase 列为批准例外,但厂商 SDK 由应用绑定,这样这个包不需要网络也能测。凭据两端都不参与同步。

## 
## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)

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

## 依赖与边界

允许:`foundation/utils`。禁止:任何厂商 SDK —— 远端是端口,Firebase 由组合根绑定
(docs/services/sync.md:同步是用户内容的数据面,凭据永不下发,`isCredentialKey` 在这层双向强制)。

## 未验证

- **零消费者**:18 个测试都跑在假 remote / 假 local 上。真实 Firebase 的游标语义
  (是否单调、分页边界、重放同一 token 会怎样)**完全未验证** —— 而「同一游标不算前进」这条就是为它准备的保险。
- 没有重试 / 断点续传 / 幂等 push:那属于这层之上的编排,这里只保证一趟 pass 的形状正确。
