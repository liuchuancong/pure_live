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

- "关注更新 / 历史『继续看』"这两类 FeedSource:**服务已经落地**(favorites / history,组合根已装配,
  见 [../../../docs/roadmap/w5-progress.md](../../../docs/roadmap/w5-progress.md) §1.8),但**接不进本包的形状**。
  `FeedSection` 带 `sourceId`,而聚合器把 `item.ref.sourceId != section.sourceId` 的行判成 foreign 丢掉
  (`lib/src/feed_aggregator.dart:159`)—— "继续看"天生跨源,照今天的形状进去会被整节清空。要么加一层
  `FeedSource` 抽象、由来源自己声明是否按源过滤,要么回到 feed.md 的原形状(标题 + items + cursor)再补源
  信息;两种都是改契约,要 ADR,不在本包顺手做。"关注更新"还另外缺一个源侧关注模型(favorites.md 明确说
  关注不是收藏)。
- 分节渲染、砖位大小与"手动添加入口"是 UI 的事。
- **流的"全部落定才返回"仍是一条**:聚合搜索那条已经补了流式接口(见 `pure_live_search` 的 `LiveSearchAggregator`),
  本包没补 —— feed 的每一节都是首屏砖位,先到先显示需要 Home 的编排(features/home)先决定"某源晚到 3 秒时那块砖
  先亮灰还是先不出现",那是编排层的决定,不在这里猜。

## 分页那一路(2026-10-11 补上)

`aggregator.feed(page)` 把**同一个页号**发给每个源 —— 第一页这么做是对的,往下就错了:各源在不同的深度耗尽,
继续问一个已经说"没有了"的源,就是"加载更多"把用户看过的行再排一遍。所以 `paging.dart` 加:

- `continuationFor(FeedSection)`:按**源自己报的 mode** 决定下一次问什么(fixedPage 加页号、cursor 带回 token、
  singleShot 明确没有下一页),问不了的话给出原因 `exhausted` / `missingCursor` / `notPaged`。
  猜是"续问把第一页重发一遍还管它叫第二页"的成因;拿别源的 token 更不是猜,那是别人的状态。
- `FeedCursorBook`:**只存游标源的 token**(数字源靠页号继续,把页号也存进来就是同一事实放两处、还各有各的寿命,
  典型后果是刷新之后数字源开始跳页);`reset()` 就是 feed.md 说的"刷新 = 重新拉头部"。
- `FeedPager`:按源各自续问,只有"还能继续"的源被问;`refresh()` 清游标并清累计;
  `maxPagesPerRun` 给一次手势封顶(计数在 refresh 时归零,所以滚得深的用户不为已经翻过的页被惩罚);
  某源被问了却没回任何一节 → 把它的末节 `hasMore` 关掉,免得下一次 `next()` 靠一节它从没返回过的页继续问。

## 验证

- 分析:`dart analyze packages/services/feed`(2026-10-11:0 issue)
- 测试:`dart test -j 1` —— **23 例**全绿(游标贯穿到源并原样带回、坏数据就地处理、单源超时/抛错不外溢、
  丢弃行跨全 feed 计数)。`paging.dart` **没有新增测试**;行为用仓库外一次性脚本观测:数字源页号 1→2→3 后
  报 `exhausted`、游标源第二问带回 `tok1` 且 token 簿在 refresh 后清空、`allItems` 按源累计不乱序、
  `canAdvance` 随 `maxPagesPerRun` 变。脚本已删除。

## 未验证

- 真实源的深度与不均衡耗尽(一个源 3 页就空、另一个 30 页)没在任何线上源上观测过,`maxPagesPerRun` 默认 1 是保守值。
- `FeedPager` 的累计只在内存里;Home 被杀之后的续问起点要靠宿主自己存游标(那是 sync/编排的事)。
- 上面"接不进本包形状"那条差异**仍然存在**,`FeedSource` 抽象需要 ADR。

