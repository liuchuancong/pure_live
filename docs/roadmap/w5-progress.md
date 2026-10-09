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

## 2. W5 剩下的

| 件 | 状态 | 缺什么 |
|---|---|---|
| History | 未落 | 记录点(播放开始/退出/进度节流)要接到播放会话上;会话归属这件事在 w3-progress §4 还是欠账 |
| Playlist | 未落 | 未读 [../content/playlist.md](../content/playlist.md) 与 [../content/collection.md](../content/collection.md) 定型;大概率与收藏共用一套仓库形状 |
| Link | 未落 | [../services/links.md](../services/links.md) 的分享/解析链路要先确认它是否依赖 W4 的解析结果 |
| Feed 的另两类源 | 未落 | "关注更新 / 历史继续看"分别要 favorites 之外的关注模型与 History 落地 |
| 收藏的开播状态 | 未落 | 需要一个能批量问"开播了没"的 capability;capability-contract §3 里没有这个方法集,定了就是猜 |
| sync / v1 迁移 | 未落 | 要 [../migration/v1-to-v2.md](../migration/v1-to-v2.md) 的 ContentRef 重写表 |

## 3. 验证证据

| 命令 | 结果 |
|---|---|
| `packages/services/favorites` → `dart analyze .` / `dart test -j 1` | No issues found;**13 全绿**(快照 4 + 分组 7 + 列表 2) |
| `packages/services/favorites` → `dart test -j 1`(持久化组) | 含真文件往返与"文档不是列表就报错"两条,合计 13 = 4 + 7 + 2 |
| 源失效可见这条规则 | `test_list_rendersFromTheStoredSnapshotWithNoSourceAnywhere`:整条读路只碰仓库,收藏页要渲染不需要任何源在场 |
| `dart run tool/check_architecture.dart --strict` | `packages=29 errors=0 warnings=0`(feed 与 favorites 两包入册后) |
| `dart analyze packages` / `dart format --output=none --set-exit-if-changed packages tool/check_architecture.dart` | No issues found;160 文件 0 changed |
| `powershell -File tool/test_check_architecture.ps1` | PASS: 23 assertions across 21 cases |

## 4. 已知欠账

- `FavoritesService` 还没有装配点:组合根里没有它(app 现在装的是 store/权限/网关/注册表那一层),
  UI 也没有消费方。它是可测的机制,不是跑起来的流程。
- 收藏没有条数上限,也**故意**没有:文档没给上限,而这里任何一个数字都是用户数据的静默丢失。
  真需要界时应该由 sync/设置面给策略,而不是由存储层猜。
- `add` 每次要扫一遍全部条目找同 ref(O(n))。今天这个量级无所谓,Drift 绑定应当按 ref 直接定位 ——
  这条留在端口实现里,不污染接口。
