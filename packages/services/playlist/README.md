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
- `lib/src/playlist.dart` —— `Playlist` / `PlaylistItem` / `PlaylistsService`(CRUD、按下标操作、批量写、标题与 id 校验)
- `lib/src/key_value_playlist_repository.dart` —— `PlaylistRepository` 的 `KeyValueStore` 后端(整份文档读写)
- `lib/src/m3u.dart` —— `parseM3u` / `writeM3u` / `itemsFromM3u`:外部歌单的导入导出
- `lib/src/watch_later.dart` —— `WatchLater`(内置表 id/容量)+ `WatchLaterService`(稍后再看队列)+ `importM3uAsPlaylist`

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
- **用户自己建的歌单仍然没有行数上限,也故意不加**:文档没给,而任何一个数字都是对用户编排的静默截断。
  新加的界是另一回事:导入有 `maxEntries` 且超了置 `truncated=true`(报出来,不悄悄丢),"稍后再看"有容量
  (溢出从尾部丢 —— 那是一条队列的语义,不是用户写的编排)。
- 随机模式的具体序列(种子、避免连续重复)属于 PlaybackQueue,不在这里定。
- lx-music 歌单格式互通是文档标着的远期项,`refFor` 的注入点已经留好,不需要再改本包的形状。

## M3U 那一路(2026-10-11)

外部歌单进来的形状是别人写的 M3U:每条带一个不认识的指令、时长是 `-1` 因为作者不知道、标题里有逗号、
地址或是裸路径或是绝对 URL。拒掉这些乱就等于拒掉这些文件,所以解析器**报告它看不懂的并继续往下读**:

- 时长与标题**只按第一个逗号切**(`"Amor, Amor"` 这种标题按最后一个逗号切就丢一半名字)。
- 未知指令(`#EXTVLCOPT` / `#PLAYLIST` / `#EXT-X-*` …)计入 `ignoredDirectives` 并留在 `entry.options` 里,
  所以导出方知道这趟往返**不是无损的**。
- 连续两条 `#EXTINF` 中间没有地址行 → 前一条计成 `dropped`,不继承:继承就是凭空造一条没人写过的行。
- 相对地址按 `baseUri` 解(列表旁边那个 ts 文件就是这么引用的),绝对与根路径原样保留。
- 没有 `#EXTM3U` 头的裸路径清单**照样解析**(很常见),但 `hasHeader=false` 要说出来。
- `\r\n` / `\r` / `\n` 三种换行都切:老 Windows 工具导出的纯 `\r` 文件不少,当一行读等于整份导入报废。
- `itemsFromM3u(refFor:)` / `writeM3u(urlFor:)`:地址 ↔ `ContentRef` 的映射必须由调用方给,IPTV 行是频道、
  音乐 URL 是曲目,格式解析器不该认识任何一种。

`WatchLaterService` 落"稍后再看是系统内置歌单":固定 `system.watch-later` id(改名不改身份)、首次使用自动建、
不可删(只给 `refuseDelete`)、**重复保存是把已有行挪到最前而不是再排一行**(那是"待会看"的意图,不是书签集合),
超容量从尾部丢。`importM3uAsPlaylist` 永远新建一份列表而不是并进已有那份 —— 合并需要"同行两次""同名两表"的规则,
那是 UI 的意图,导入器猜了就撤不回;标题/ id 撞车时加计数并回报 `renamed`。

## 验证

- 分析:`dart analyze packages/services/playlist`(2026-10-11:0 issue)
- 测试:`dart test -j 1` —— **16 例**全绿(顺序即语义、moveItem 的双下标、快照渲染不问源、跨源混排、
  整份文档读写与"读不懂就报错")。`m3u.dart` / `watch_later.dart` / 批量写与标题校验**没有新增测试**;
  行为用仓库外一次性脚本观测过:带逗号的标题完整保留、`#EXTGRP` 与 `#EXTINF:120` 解析出来、
  相对行按 base 解析成绝对 URL、`#PLAYLIST` 进未知指令计数、`maxEntries=4` 时 `truncated=true`、
  Watch Later 重复保存挪到最前且 5 次保存后只剩最后 3 条、`next()` 弹出首条、导入产出 4/4 行且导出能写回
  `#EXTINF:-1,Amor, Amor`。脚本已删除。

## 未验证

- 真机导入未跑过:用户手上的 IPTV 清单里那些方言(`#EXT-X-` 播放列表套播放列表、`track-id=` 属性、
  GBK 编码文件)本解析器**按未知指令处理**,能不能还原成可用的行没有样本。GBK 那条尤其:传进来的必须是
  已解码的 `String`,调用方不解码就会得到乱码标题,本包不做字节解码。
- `importM3uAsPlaylist` 的撞名计数到 1000 就抛 `duplicateId`;真实用户有没有可能撞到那一步没测。
- 批量写(`replaceItems` / `addAllItems`)在 `KeyValuePlaylistRepository` 上是整份文档重写:
  一份 5000 行的导入就是 5000 行的重新编码 + 一次落盘,大清单上的耗时没在设备上量过。

