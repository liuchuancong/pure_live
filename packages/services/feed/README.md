# pure_live_feed

> 职责:首页 Feed 聚合:经 CapabilityRegistry 枚举 FeedCapability、按源分节、游标贯穿与单源失败隔离

| 项 | 规则 |
|---|---|
| 层 | services(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation + L1 的契约面(`pure_live_platform`、`pure_live_capability`);不碰网关、权限、任务与解析器 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依;**禁止点名任何源** |
| 公共面 | 只有 `lib/pure_live_feed.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/feed_aggregator.dart` —— `FeedAggregator` 契约、`FeedSection` / `FeedSkip` / `FeedResult` 与
  `CapabilityFeedAggregator`

## 规则(规范来自 docs/services/feed.md)

`FeedSource[] → FeedAggregator → FeedSection[] → Home`,而第一条规则是**Home 不直接依赖 Bilibili/Douyu/Music**:
本包因此只经 `providersFor(feed)` 选源,自己不认识任何站点。

- **没有该能力的源不出现在 Feed**。声明了却拿不出 `FeedCapability` 对象的源也归到"不出现",但不是无声消失:
  它进 `skips` 并带 `notCapable` 说明。空出来的砖位如果没有任何记录,就变成"用户装了却看不到、且没人说得清为什么"。
- **节的顺序是注册顺序,不是到达顺序**。某个源今天慢 40ms 就让它排到后面,等于用户的首页布局每天变一次。
- **一个源失败不拖垮首页**。单源超时(`perSourceTimeout`,默认 8s)与异常都收进 `skips`,其余源照常成节。
  被放弃的请求**不在这一层取消**:取消是"用户停止了观看"的形状,而这里没有人按下过任何东西。
- **游标贯穿到源,并原样带回来**。`feed(PageRequest)` 把请求交给每个源,节的 `page` / `hasMore` 是源自己的回答。
  刷新就是重新取第 1 页 —— 没有第二条 reload 路径,因为"刷新但留着旧游标"正是首页不再显示新内容的样子。
- **节内的坏数据就地处理**:指向别源的行丢弃并计入 `foreignItems`(一条指错源的结果点不开),
  同节内重复的 ref 保留第一条并计入 `duplicateItems`(`contract.feed.duplicate_ref`)。
  跨源**不去重**:ref 里带着源,两个源给同一片段是两条不同的推荐。

## 与文档草图的一处差异

feed.md 写 `FeedSection[](标题 + FeedItem[] + cursor)`。实现里 `FeedSection` **没有标题**,理由是同一个文档的
另一条:"首页模块编排(哪些 Section 显示/顺序)是用户数据(sync 范围)"。标题既然属于编排数据,聚合器再造一个
就是同一块砖位有两个真相来源。呈现名由宿主从编排里取;`FeedItem` 则是 `ContentSummary`
(见 [capability-contract.md](../../../docs/contracts/capability-contract.md) §5 的名称对应表)。

## 还没做的

- "关注更新 / 历史『继续看』"这两类 FeedSource 需要 favorites / history 服务,它们还不存在;那两种节要等它们落地。
- 分节渲染、砖位大小与"手动添加入口"是 UI 的事。
- 结果是全部落定才返回,与聚合搜索同一个理由:先到先显示需要 UI 侧的分批渲染决定。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test -j 1`(纯 Dart)或 `flutter test`(带 `-Flutter`)
