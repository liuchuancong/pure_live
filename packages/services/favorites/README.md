# pure_live_favorites

> 职责:跨域收藏夹:ContentRef 为键、快照元数据留存、分组与手动/时间排序

| 项 | 规则 |
|---|---|
| 层 | services(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation(今天用到 `pure_live_storage`)+ `pure_live_platform` 的模型;不碰网关、权限、任务与解析器 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依;**禁止直接问源**(收藏页在源全挂时也要能渲染) |
| 公共面 | 只有 `lib/pure_live_favorites.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/favorites.dart` —— `FavoriteFolder` / `FavoriteEntry` / `FavoriteRepository` 端口与 `FavoritesService`
- `lib/src/key_value_favorite_repository.dart` —— 键值后端绑定(两条 JSON 文档)

## 规则(规范来自 docs/services/favorites.md)

- **键是完整的 `ContentRef`**,不是平台 id:同一条 contentId 在两个源上是两件不同的东西,`list` 与 `remove`
  都按整个 ref 走(测试专门放了两条同名不同源的收藏)。
- **快照随条目存**(`ContentSummary`:标题/封面/副标题/描述/元数据)。收藏页因此**从不问源**——
  "源失效仍可见"在这里不是降级逻辑,而是这个列表压根没有一条通往源的路。
- **重复添加只刷新快照,不改 `addedAt`**。重新打开一个收藏不等于重新收藏:日期是用户的历史,
  每次打开都改写它就等于在他脚下重排整个列表。
- **分组顺序是用户数据**(`sortKey`),同权重按名字兜底,保证顺序是全序。条目**没有**手动顺序 ——
  文档给的条目形状里没有任何排序权重,所以列表按 `addedAt` 倒序;要做"手动排条目"得先改模型,
  而不是在这里假装已经支持。
- **删分组只删空的分组**。里面有收藏就拒(`folderNotEmpty`):用户要删的是一个标签,
  而"顺手删掉他的收藏"和"把收藏搬去他没选的地方"都动了这层没有权限动的数据。
- **文档读不懂就报错,不按空处理**(`FormatException`)。键值绑定每次写都从读到的内容重建整份文档,
  所以这里把"空"当答案 = 下一次写入把其余收藏一起抹掉。与 § `FileKeyValueStore` 的"读不懂就不覆盖"同一条规则。

## 端口为什么是这个形状

`FavoriteRepository` 给的是细粒度操作(`upsertEntry` / `removeEntry` / …),不是"读整份收藏"。
今天的键值绑定内部仍然整份重写,但**接口不能替 Drift 做这个决定**:
[docs/services/favorites.md](../../../docs/services/favorites.md) 点名 Drift 并把收藏纳入 sync 范围,
而"每次写都重写全表"进了数据库就是一个灾难。把形状定在细粒度上,换后端时上面这一层不用动 ——
与 `KeyValuePermissionStore` 同一个划法。

## 还没做的

- **直播收藏的"开播状态"**:`favorites.md` 要求进入收藏页时按 capability 批量查。代码里能批量查开播的能力
  还没有定义(capability-contract §3 只给了内容类四个方法集),所以现在做等于猜签名。
- **"关注"不在这里**:关注来自源,收藏留在本地(文档明确区分)。
- sync 与 v1 收藏迁移(`docs/migration/v1-to-v2.md`)没有绑定:需要 ContentRef 重写的映射表与同步范围数据。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test -j 1`(纯 Dart)或 `flutter test`(带 `-Flutter`)
