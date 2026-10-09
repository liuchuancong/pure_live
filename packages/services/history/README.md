# pure_live_history

> 职责:跨域统一观看历史:ContentRef 为键、进度节流、parentId 剧集聚合与继续观看

| 项 | 规则 |
|---|---|
| 层 | services(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation(`pure_live_storage`)+ `pure_live_platform` 的模型;不碰网关、权限、任务、解析器与播放器 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依;**禁止出现平台前缀类型(`BilibiliHistory` 等)** |
| 公共面 | 只有 `lib/pure_live_history.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/history.dart` —— `HistoryEntry` / `HistoryDomain` / `SeriesProgress` / `HistoryRepository` 端口与 `HistoryService`
- `lib/src/key_value_history_repository.dart` —— 键值后端绑定(单份 JSON 文档)

## 规则(规范来自 docs/services/history.md)

- **键 = 内容身份 `(sourceId, contentId, kind)`**,一条内容一行记录。这里刻意不用 `ContentRef ==` 找行:
  平台的 ref 相等**包含 `parentId`**,而调用方在后续上报里少写一次父级就会把同一集拆成两行(这条是写测试时
  撞出来的,现在有两条测试钉住)。`parentId` 因此是记录的一列,由剧集聚合读,不参与身份。
  域由 `ref.kind` 推导(`domainOf`)而不是各存一份:kind 与 domain 各说各话就是同一内容的两个真相。
  `stream` / `playlist` 这类光看 kind 定不下来的落 `other` 而**不猜** —— 猜错域的代价是"历史在这一栏里找不到",
  用户读成丢了历史。
- **三个记录点**:`record(...)` 是进度,`finish(...)` 是"看完退出",`flush()` 是被节流挡下的那些行的落盘。
  `duration` 缺省保留上一次报的长度(源在会话中途不再报长度,不该把"45 分钟里看了 30"变成"长度未知")。
- **长度未知 ≠ 已看完**:`isCompleted` 只在有已知长度且位置到端点时为真。直播与没报长度的条目因此恒为"未看完",
  这正是"继续观看"里该有的样子。
- **节流是机制,数字是宿主给的**:`minWriteInterval` 默认 0(每个 tick 都写)。机制放在这层,因为只有这里知道
  这一行是"进度";数字交给看得见网络与磁盘的一方,而文档没给数,任何默认值都是猜。
- **被合掉的 tick 是延迟,不是丢弃**:节流期间的最新行留在内存,下一次到期写入或 `flush()` 落盘 ——
  所以播放器退出时必须调 `flush()`,否则最后一段进度随进程消失。删除/清空会同时丢掉挂起行,
  一条被删的历史不会因为下次 flush 又活过来(有测试)。
- **剧集聚合走 `parentId`**:`series(parentId)` 给"看到第 N 集"(最新一行 + 记录数 + 看完数);
  没有 parentId 的行不进聚合,但仍在时间线里。
- **搜索是本地标题匹配**:历史页要筛的是它已经拿着的那些行,让各源再搜一遍是 services/search 的事。
  推论写在这里是因为它会被当成 bug:**没有快照的行在搜索框里搜不到**(时间线里仍然在)。
- **快照随条目存**(`ContentSummary`):history.md 没要求,但收藏与歌单都要求;一栏显示成空白砖位是同一个
  "源失效"问题挪到另一页。这是本包唯一一处补文档没写的字段,记在这里而不是悄悄做。
- **清空没有撤销**:`clear()` 就是文档里的"清空",(带)确认是 UI 的事,这层不提供第二次机会。
- **文档读不懂就报错**(同收藏/歌单):每次写都从读到的内容重建整份文档,把解析失败当空 = 下一个 tick 删光历史。

## 端口形状

`HistoryRepository` 是细粒度的(`entries` / `upsert` / `remove` / `removeWhere` / `clear`),因为文档点名
Drift([../media/recorder.md](../../../docs/media/recorder.md) 同款模式)并把历史纳入 sync:今天的键值实现仍然
整份重写,但那不该成为接口的形状。`removeWhere` 带返回值是"删了几条"的唯一诚实来源,`removeSeries` 用它报数。

## 还没做的

- **记录点还没人调**:播放开始/退出/进度要由播放会话来触发,而会话归属仍是
  [w3-progress.md](../../../docs/roadmap/w3-progress.md) §4 的欠账;`HistoryService` 现在是可测的机制。
- 条数上限:**故意没有**。文档没给,而历史是用户数据,任何数字都是静默截断。
- v1 各域历史接入(站点 id → `sourceId` 映射)未做,见 [../migration/database-migration.md](../../../docs/migration/database-migration.md)。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test -j 1`(纯 Dart)或 `flutter test`(带 `-Flutter`)
