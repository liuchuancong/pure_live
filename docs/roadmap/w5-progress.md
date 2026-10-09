# W5 进度 — Universal Content 业务面

> 波次目标:ContentRef 的业务面 —— History / Favorite / Playlist / Feed / Search / Link。
> 本文记实际落到的东西与还差什么。

## 0. 为什么先动这一波

[W4](w4-progress.md) 的 provider 本体卡在两处**不由我定**的前置上:真实响应录制(要联网授权与录制通道)与
`danmaku` / `auth` 的方法集(那是改契约,不是写实现)。这两条在 w4-progress §2 已经登记。
W5 的收藏/历史面不吃这两条:它们只吃 `ContentRef`、时间戳与一个能落盘的 KV —— 三件在前面都已经落了
(`FileKeyValueStore`、按属主分命名空间的视图、`KeyValuePermissionStore`)。所以先把无阻塞的一面做掉,
W4 的 provider 一到就能直接接进搜索/Feed/收藏这条消费链。

顺序上这是**跳波**,不是改序:W4 没做完,只是它剩下的部分需要外部输入。

## 1. 已落:`packages/services/favorites`(13 测试)

规范来自 [../services/favorites.md](../services/favorites.md)。三处判断值得单独写,因为它们都是
"文档没写全时怎么办":

- **条目不设手动顺序**。文档给了 `FavoriteEntry(ref, folderId, addedAt, snapshot)` —— 里面没有任何排序权重,
  而"排序手动 + 按时间"同时出现在规则里。所以手动顺序落在**分组**(`FavoriteFolder.sortKey`),
  条目按 `addedAt` 倒序。要真支持"手动排条目"得先给条目加权重字段,那是改模型,不是在排序函数里假装。
- **删非空分组直接拒**。可选项是"连带删掉收藏"或"把它们搬去默认分组",两条都动了这层没有权限动的数据;
  拒了并给 `folderNotEmpty` 是唯一不猜的做法,也留了 UI 的出口(先移动再删)。
- **文档读不懂 ≠ 空**。键值绑定每次写都从读到的内容重建整份文档,所以把"解析不出来"当成"本来是空",
  下一次添加就会抹掉其余收藏 —— 抛 `FormatException`。这与 `FileKeyValueStore` 的"读不懂就不覆盖"、
  授权记录的"读不懂按没问过并删掉"是同一条规则在不同数据等级上的三种落法:**缓存可以丢一行,收藏不行**。

`FavoriteRepository` 端口给的是细粒度操作(`upsertEntry` / `removeEntry`),不是"读整份":今天的键值实现
内部整份重写无所谓,但文档点名 Drift 并把收藏纳入 sync,若把"整份读写"写进接口,换到数据库那天它就是灾难。
这条与 §1.9 的 `KeyValuePermissionStore` 同一个划法。

### 1.5 已落:`packages/services/playlist`(16 测试)

规范来自 [../content/playlist.md](../content/playlist.md)。与收藏最要紧的区别是**行的身份**:歌单是序列,
所以身份是下标而不是 ref,同一条内容可以排两次(M3U 就这么干)。这条差异决定了三个 API 形状:

- `removeItem(index)` / `moveItem(from, to)` 按下标操作,`indexOfFirst(ref)` 只回答"第一个在哪" ——
  它不假装能定位用户心里那一行。
- `moveItem` 的两个下标**按移动前的列表读**,因为那是拖拽手柄报出来的坐标;删除留下的空位在服务里补齐,
  而不是让每个调用方各自记住。`to` 允许等于长度(拖过最后一行)。第一版按"删除后的空间"实现,
  是那条 `moveItem(0, 2)` 的测试把它拽回来的 —— 单元测试在这里的作用是把 API 直觉固定住。
- 收藏是集合(ref 唯一,重复添加刷新快照),歌单是序列(允许重复)。两包同一个 `ContentRef`,
  两种身份规则,README 各写各的,不合并成一个"通用列表"。

`playMode`(顺序/随机/单曲循环)**只存不执行**:文档明确 Playlist 是用户资产、`PlaybackQueue` 是会话状态,
所以随机序列的种子与"避免连续重复"这类事不在这里定,现在定就是把会话状态搬进用户资产。
端口也刻意与收藏不同形状(`all`/`upsert`/`remove` 整份列表),因为有序列表本身就是记录的形状,
按行寻址只会把下标数学藏起来。

### 1.6 已落:`packages/services/history`(23 测试)

规范来自 [../services/history.md](../services/history.md)。这一包里有两条是被测试逼出来的判断,不是先想好的:

- **行身份不能是 `ContentRef ==`**。第一次实现按 ref 相等找行,于是
  `record(parentedRef, …)` 之后再 `record(bareRef, …)` 会把同一集写成两行 —— 平台的 ref 相等**含 `parentId`**。
  现在身份是 `(sourceId, contentId, kind)`,`parentId` 退回它本来的角色:记录的一列,由剧集聚合读。
  两条测试钉住它(一条"少写父级仍是同一行",一条"同 id 不同 kind 是两行")。
- **节流挡下的行必须会回来,且不能复活**。`minWriteInterval` 期间最新行留在内存,到期写入或 `flush()` 落盘;
  而 `remove` / `removeSeries` / `clear` 必须同时清掉挂起行,否则用户删掉的历史会在下一次 flush 里回来。
  默认节流为 0:机制放在知道"这一行是进度"的那层,数字交给看得见网络与磁盘的一方 —— 文档没给数。

其余按文档落:长度未知**不等于**已看完(`isCompleted` 只在有长度且到端点时为真)、时间线按 `updatedAt` 倒序、
域由 kind 推导且 `stream`/`playlist` 落 `other` 不猜、`series(parentId)` 出"看到第 N 集"、
搜索是本地标题匹配(推论:**没快照的行在搜索框里搜不到**,写成了一条测试而不是留着当惊喜)。

快照字段是文档没写而我补的:history.md 没要求存 title/cover,但收藏与歌单都要求,而一栏空白砖位是同一个
"源失效"问题挪到另一页。补在何处、为何补,写在包 README 而不是悄悄做。

### 1.7 已落:`packages/ecosystem/identity`(19 测试)

"换源播放"的前提层。规范是 [../content/content-identity.md](../content/content-identity.md):权威编号优先,
然后 title + 创作者 + 合集 + 时长的模糊匹配,阈值可配,置信度不足**不强并**而是让用户确认一次并记住。

四条门槛值得单独写,因为它们都是"宁可不并"的方向:

| 情形 | 结论 | 为什么 |
|---|---|---|
| 同 scheme 同值 | 同一(1.0) | 编号就是为这个用的 |
| 同 scheme 不同值 | **不同**,且压过其它全部相符 | 两个 ISRC 不同的录音不会因为标题/歌手/时长全一样就是一首歌 —— 那正是现场版/剪辑版/另一版 |
| 只有标题可比 | 最多候选,永不自动并 | 这层存在的理由就是"两个源都叫《Call Me》不代表同一内容" |
| 时长超出容差 | 最多候选 | 时长不一致最像另一个版本,而不是元数据打错了 |

置信度是**可比字段里相符的权重占比**:一侧没有的字段整个从分母里去掉 —— 把缺席当反对票,等于专门罚元数据少的源。
门槛(自动并 0.9 / 候选 0.55)写在 `IdentityPolicy` 里可调,README 明确标它们是**策略不是事实**:还没有拿真实
目录校准过。

身份与引用的关系按规则 3 落死:没有权威编号的内容,身份 id 就是**首次使用那个 ref 的 key**;成员 ref 另外存一份,
`refKey` 当成不透明字符串**永不反解**(contentId 里带 `/` 是合法的,反解会把内容撕错),`alternatives()` 返回
当初注册时的完整 ref(kind 也在)。确认只并身份、不改 ref,所以历史/收藏的主键不受身份层影响。

两处冲突记下来:①`dependency-rules.md` §2 把 `identity` 放 L1,content-identity.md §2 说"是 services 层能力"
—— 实质(provider 之间不感知)由"本包不 import 任何 provider"守,目录按冻结清单走;②分数不落库,只存
ref→身份 + 成员 + 事实,策略调整后重算幂等,存分数反而要迁移历史。

**没接进任何流程**:搜索/Feed 还不跨源去重,收藏/历史还没用 `alternatives()` 换源,provider 侧要不要往
`metadata.extra` 里填编号是 W4/W6 的事。这层现在是可测的机制。

### 1.8 装配点:三个用户数据服务与两个聚合器进组合根

§4 的第一条欠账("没有装配点")收了:`PureLiveRuntime.boot` 现在装 `favorites` / `history` / `playlists`,
并把 `search` / `feed` 两个聚合器指向**同一个** `CapabilityRegistry`。

- **一个域一个文件**(`favorites.json` / `history.json` / `playlists.json`,与 `extensions.json`、
  `permissions.json` 并列)。理由是文件正好是 `docs/migration/` 与备份/sync 各自操作的那个单位:一个域的
  文档损坏不该把另一个域带走,而用户数据也不该住在扩展的命名空间里 —— 那条 `extension.<id>.<area>.<key>`
  前缀规则意味着二者即便同库也不会撞键,但"不撞键"不等于"该放在一起"。
- **`favorites.initialize()` 在 boot 里调用**:`add()` 要求默认分组已存在(`_requireFolder`),而"服务什么时候
  算可给用户用"是宿主决定、包不能自己知道的事(包不知道自己是不是在开机流程里)。测试里那一次首装 add
  没有让调用方先 initialize,就是在钉这条。
- **两个聚合器共用一份注册表**:如果各自持一份,一个源就可能"能搜到但永不上首页",而 provider 的
  Enabled 状态就失去唯一含义(provider-contract §3 要求注册表是它唯一要拨的东西)。
- **节流数字仍然不给**:`HistoryService.minWriteInterval` 保持 `Duration.zero`。history.md 把"进度节流"列成
  记录点却没给间隔,而任何一个这里填上的数字都是"崩溃可以丢多少进度"的静默策略。等播放会话归属那条
  欠账(w3-progress §4)落地、有一个真能看到网络与磁盘的调用方时再定;`flush()` 的调用方按包 README 是
  **会话退出**,不是根。

装配的是机制,不是流程:三个服务从此有 durable 的落点,但 `record` / `finish` 仍无人调用,UI 也没有
消费方。这一条与 §2 的"继续看 / 关注更新"是同一件事的两半。

一个只有组合根才会暴露的坑,记在这里:boot 里那次 `initialize()` 让 `test_host` 那个 widget 测试**挂死**
(不是失败)。`testWidgets` 的 body 跑在 binding 的假时钟里,真文件 I/O 的 await 在里面永远不会返回,
而 `--timeout=45s` 也不会触发 —— 表现为"最后一条测试之后再无输出"。改法是把它包进
`tester.runAsync(...)`,这也是这条约束今后在 app 侧测试里的写法。

## 2. W5 剩下的

| 件 | 状态 | 缺什么 |
|---|---|---|
| History | **数据面已落**(§1.6) | 三个记录点(`record` / `finish` / `flush`)还没有调用方:播放会话归属是 w3-progress §4 的欠账;v1 各域历史的站点 id → sourceId 映射也没接 |
| Playlist | **已落**(§1.5) | 队列与 `PlaybackQueue` 的实例化衔接还没做(要播放会话归属) |
| Link | 未落 | [../services/links.md](../services/links.md) 的分享/解析链路要先确认它是否依赖 W4 的解析结果 |
| Feed 的另两类源 | 部分可做 | "继续看"现在能接了(`HistoryService.continueWatching`);"关注更新"仍要一个源侧关注模型,favorites.md 明确说那不是收藏 |
| 历史『继续看』真接进 Feed | **卡在一个形状问题,不是缺代码** | `FeedSection` 带 `sourceId`,而聚合器把 `item.ref.sourceId != section.sourceId` 的行判成 foreign 丢掉(`feed_aggregator.dart:159`)—— "继续看"天生跨源,照今天的形状进去会被整节清空。要么给 `FeedSource` 一层抽象、由来源自己声明是否按源过滤,要么回到 feed.md 的原形状(标题 + items + cursor)再补源信息;两种都是改契约,要 ADR,不在这里顺手做 |
| 收藏的开播状态 | 未落 | 需要一个能批量问"开播了没"的 capability;capability-contract §3 里没有这个方法集,定了就是猜 |
| sync / v1 迁移 | 未落 | 要 [../migration/v1-to-v2.md](../migration/v1-to-v2.md) 的 ContentRef 重写表 |

## 3. 验证证据

| 命令 | 结果 |
|---|---|
| `packages/services/favorites` → `dart analyze .` / `dart test -j 1` | No issues found;**13 全绿**(快照 4 + 分组 7 + 列表 2) |
| `packages/ecosystem/identity` → `dart analyze .` / `dart test -j 1` | No issues found;**19 全绿**(matcher 12 + 序列化 2 + 索引 5) |
| `packages/services/favorites` → `dart test -j 1`(持久化组) | 含真文件往返与"文档不是列表就报错"两条,合计 13 = 4 + 7 + 2 |
| `packages/services/playlist` → `dart analyze .` / `dart test -j 1` | No issues found;**16 全绿**(顺序 7 + 条目 3 + 登记 3 + 持久化 3) |
| `packages/services/history` → `dart analyze .` / `dart test -j 1` | No issues found;**23 全绿**(记录 7 + 节流 5 + 剧集 3 + 时间线 5 + 域映射 1 + 持久化 2) |
| 源失效可见这条规则 | `test_list_rendersFromTheStoredSnapshotWithNoSourceAnywhere`:整条读路只碰仓库,收藏页要渲染不需要任何源在场 |
| `dart run tool/check_architecture.dart --strict` | `packages=32 errors=0 warnings=0`(identity 入册后) |
| `dart analyze packages` / `dart format --output=none --set-exit-if-changed packages tool/check_architecture.dart` | No issues found;160 文件 0 changed |
| `powershell -File tool/test_check_architecture.ps1` | PASS: 23 assertions across 21 cases |

§1.8 的装配点(组合根侧),全部经 `tool/build_resource_guard.ps1` 租约、`tool/flutterw.ps1` 在 `apps/pure_live` 下执行:

| 命令 | 结果 |
|---|---|
| `apps/pure_live` → `flutter pub get --offline` | Got dependencies;app 新增 5 个 workspace 路径包(favorites / feed / history / playlist / search),`pubspec.lock` **无变化**(workspace 内路径依赖不入锁文件) |
| `apps/pure_live` → `flutter test --no-pub --concurrency=1 test/runtime_assembly_test.dart` | **10 全绿** = 装配 4 + 持久化 3 + 服务装配 2 + 宿主 1 |
| `apps/pure_live` → `flutter analyze --no-pub` | No issues found |
| 挂死诊断(记录一次非失败的现象) | 加入服务后 `test_host` 不再返回,`--timeout=45s` 也不触发,日志停在 `+9: test_host` 且没有 `(tearDownAll)` 行 —— 定位到 widget 测试的假时钟不派发真 I/O,`tester.runAsync` 包好后同一条命令回到 10 全绿 |
| `dart run tool/check_architecture.dart --strict` | `packages=32 errors=0 warnings=0` —— 本次没有新包,护栏也**不覆盖** `apps/`:组合根可以看见所有层是 AGENTS.md I9 的既定例外,不是护栏漏检 |
| `dart format` 本次改动的三个 Dart 文件 | runtime.dart / runtime_assembly_test.dart 有换行级重排,绿跑之后复跑同一条命令确认(§3 第一行即复跑结果) |

## 4. 已知欠账

- ~~`FavoritesService` 还没有装配点~~ —— 已落(§1.8):三个用户数据服务与两个聚合器都进了组合根,
  各域一个文件,聚合器共用那一份 `CapabilityRegistry`。**UI 消费方仍然没有**,所以它们是"装了且能持久",
  还不是"跑起来的流程"。
- 收藏没有条数上限,也**故意**没有:文档没给上限,而这里任何一个数字都是用户数据的静默丢失。
  真需要界时应该由 sync/设置面给策略,而不是由存储层猜。
- `add` 每次要扫一遍全部条目找同 ref(O(n))。今天这个量级无所谓,Drift 绑定应当按 ref 直接定位 ——
  这条留在端口实现里,不污染接口。
