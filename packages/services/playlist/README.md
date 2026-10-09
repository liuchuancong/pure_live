# pure_live_playlist

> 职责:用户播放队列:歌单/连播/稍后再看,ContentRef 有序条目加快照,可跨源混排

| 项 | 规则 |
|---|---|
| 层 | services(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation(`pure_live_storage`)+ `pure_live_platform` 的模型;不碰网关、权限、任务与解析器 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依 |
| 公共面 | 只有 `lib/pure_live_playlist.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/playlist.dart` —— `Playlist` / `PlaylistItem` / `PlaylistRepository` 端口与 `PlaylistsService`
- `lib/src/key_value_playlist_repository.dart` —— 键值后端绑定(单份 JSON 文档)

## 规则(规范来自 docs/content/playlist.md)

- **顺序就是语义**:行的身份是**下标**,不是 ref。同一条内容可以排两次(M3U 就这么干),
  所以这里没有"按 ref 去重";`removeItem(index)` / `moveItem(from, to)` 按下标操作,
  `indexOfFirst(ref)` 明确只回答"第一个在哪",不假装能定位用户心里那一行。
  这与收藏相反 —— 收藏是集合(ref 唯一),队列是序列。
- **`moveItem` 的两个下标都按移动前的列表读**。这正是拖拽手柄报出来的坐标,
  删除留下的空位在这里补齐,而不是让每个调用方各自记住;`to` 允许等于长度(拖过最后一行)。
- **快照随条目存**(`ContentSummary`):列表渲染从不问源,源全挂时队列照样完整可见。
- **跨源混排**:一条队列里 B 站视频与音乐可以并存,每一行按自己的源去 resolve(那是 W4 之后播放侧的事)。
- **`playMode` 只存不执行**:顺序/随机/单曲循环是用户的意图;选下一行属于 `PlaybackQueue`(会话状态),
  文档把两者分成两件事,本包就一行都不做 —— 在这里实现随机策略等于把会话状态搬进用户资产。
- **空队列是合法的**:用户先建列表再往里加。`clear` 只清行,不删列表。
- **文档读不懂就报错**(同收藏):每次写都从读到的内容重建整份文档,把"解析不出"当"空"就等于下次写入删掉其余歌单。

## 端口形状

`PlaylistRepository` 按**整份列表**给操作(`all` / `upsert` / `remove`),与收藏的细粒度端口不同。理由是这里
不是"少一个字段",而是模型本身如此:有序列表就是这条记录的形状,把每行操作塞进接口只会把下标数学藏起来。
文档点名的后续后端(settings_repository / backup、sync 范围)都还是同一份用户资产,不需要按行寻址。

## 还没做的

- "播放歌单"= Playlist → 实例化 `PlaybackQueue`:那一半属于媒体侧,而播放会话归属仍是
  [w3-progress.md](../../../docs/roadmap/w3-progress.md) §4 的欠账。
- 条目数没有上限,也**故意**没有:文档没给,而任何一个数字都是用户编排的静默截断。
- 随机模式的具体序列(种子、避免连续重复)属于 PlaybackQueue,不在这里定。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test -j 1`(纯 Dart)或 `flutter test`(带 `-Flutter`)
