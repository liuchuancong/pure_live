# pure_live_search

> 职责:聚合搜索:经 CapabilityRegistry 枚举搜索源、并发查询、超时与失败隔离、按源分桶的部分结果

| 项 | 规则 |
|---|---|
| 层 | services(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation + L1 的契约与能力包(`pure_live_platform`、`pure_live_capability`);本包不碰网关、权限与任务调度,那些由组合根注入 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外);**禁止点名任何源** |
| 公共面 | 只有 `lib/pure_live_search.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/search_aggregator.dart` —— `SearchAggregator` 契约、`SearchProviderOutcome` / `SearchAggregate` 与
  `CapabilitySearchAggregator`

## 规则(规范来自 docs/services/search.md)

流程是 `SearchQuery → CapabilityRegistry 枚举 SearchProvider → 并发查询 → 按源分组的结果 → UI`。
这里落的是中间那段,四条与"失败"有关:

- **一个源的超时不变成没有结果**。`perProviderTimeout`(默认 8s)到点的源记 `timedOut`,其余源的答案照旧返回。
  超时的请求不在这一层取消:取消是用户动作的形状,而这里没有任何人按下过取消。
- **一个源抛错不外溢**。源的异常被收进 `failed` 的结果里带上 `detail`,调用方因此能显示"这两个源失败了",
  而不是整个搜索变成一次 try/catch。
- **"这个源没搜到"≠"这个源坏了"**。空结果记 `empty` 且不带 detail(规则原文:"无结果源静默标记");
  UI 要能区分"没匹配"和"没答案",否则用户会以为站点挂了。
- **多声明能力的源被报出来,而不是被静默跳过**。注册表的两个视图可以不一致(声明 vs 实现),
  消费端只把真正 `is SearchCapability` 的对象拿去调用,同时留一条失败记录说明为什么这块牌子是空的。

另外两条与数据有关:

- **只保留属于该源的结果**(同 `contract.search.foreign_source`)。契约测试已经断言过这条,这里是第二道:
  第三方源可以在没跑契约测试的情况下发布,而一条指向别人源的结果点不开。
- **空关键词一个请求都不发**。N 个源的空关键词就是 N 次无意义请求,而且每个都会被自己的契约判成空搜索。

分页游标从 `PageResult` 原样带出(本包不改写源的翻页语义,聚合不改协议)。

## 还没做的

- 结果按"直播/视频/音乐/频道"分组是 UI 的呈现规则,不在这里做。
- 搜索历史与热搜(`hotword` capability)需要存储与一个能力定义,两者都还没有:历史记录归 W5 的业务面,
  热词的调用面要先在 capability-contract §3 定下来。
- 结果是"全部落定才返回"。首屏想要先到先显示的话,需要一条流式接口,而那需要 UI 侧的分批渲染决定,现在加等于猜。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test -j 1`(纯 Dart)或 `flutter test`(带 `-Flutter`)
