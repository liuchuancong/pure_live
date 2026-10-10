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
- `lib/src/search_aggregator.dart` —— `SearchAggregator` 契约、`SearchProviderOutcome` / `SearchAggregate`、
  `CapabilitySearchAggregator`,以及抽出来给两条路径共用的 `askSearchSource` / `selectSearchTargets` /
  `continuationFor`(分页续问的三种答案)
- `lib/src/live_search.dart` —— `LiveSearchAggregator.stream`(先到先报)、`SearchFanout`(并发上限)、
  `SourceHealthLedger`(坏源记账)、`firstAnswer` + `SearchWaitNotice`、`more()`(同源下一页)

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

## 流式那一路(2026-10-11 补上)

规范原文是"部分结果可用"。`Future.wait` 那一路做不到这条:20 个源的搜索要等最慢那个把预算烧完才一次性出现,
用户读到的是"没结果",不是"还在搜"。所以加了 `LiveSearchAggregator.stream`(旧那条保留,两条共用同一个
`askSearchSource` —— 两份实现迟早有一份不再丢外来结果或不再超时):

- `SearchFanout.maxConcurrent`(默认 6)限同时问几个源;不限就是一次搜索向最弱的那个源发二十条请求。
- **冷却中的源排到最后问**,而不是被剔除:用户启用的源恢复了还得能用;但一上来就问它,首屏预算就花在一个已知慢的源上。
- `SourceHealthLedger` 记住每源连续失败次数与冷却截止(`failuresBeforeCooldown=3`、`cooldown=30s`、
  跟踪源数有上界 `sourceLimit=128` 并按最久未见淘汰);`empty` 是"没搜到",**不算失败**。
- `firstAnswer` 有两种诚实的答案:第一个可用结果,或者 `SearchWaitNotice`(预算烧完,还没有源回话)。
  把后者做成异常或 null,就等于把"这条慢"的唯一线索抹掉。
- `continuationFor` / `more()` 按 `PageResult.mode` 续问:fixedPage 加页号、cursor 带回 token、singleShot 明确没有下一页;
  页号无法前进(0 或负)时报"续不下去",否则会在第一页上永远打转。

## 还没做的

- 结果按"直播/视频/音乐/频道"分组是 UI 的呈现规则,不在这里做。
- 搜索历史与热搜(`hotword` capability)需要存储与一个能力定义,两者都还没有:历史记录归 W5 的业务面,
  热词的调用面要先在 capability-contract §3 定下来。
- 跨源去重(同一部剧在两个源里都出现)没有做:合并会丢掉"另一个源也能播"这条信息,而那是换源的理由。

## 验证

- 分析:`dart analyze packages/services/search`(2026-10-11:0 issue)
- 测试:`dart test -j 1` —— **16 例**全绿(源超时不外溢、抛错被收进该源、空结果与失败可分、外来结果丢弃并计数、
  声明未实现的源被报出来、取消算取消不算坏源、空白关键词拒发)。
  流式那一路**没有新增测试**;行为用仓库外一次性脚本观测过:4 源(10ms / 120ms / 挂住 / 外来)在
  `maxConcurrent=2`、`perSourceTimeout=300ms` 下先到先报 `[fast:answered, mid:answered, other:empty, hang:timedOut]`、
  5ms 预算拿到 `SearchWaitNotice(4 sources)`、挂住的源两次超时后 `healthOf=degraded` 且剩 ~30s 冷却、
  `more()` 真的发了第二页(源侧调用数增加)、空白关键词返回 `refused` 且 0 个请求。脚本已删除。

## 未验证

- 真机弱网下的并发上限与超时预算(6 / 8s)没测过;上限是按"浏览器每主机 6"类比定的,不是按移动网络实测。
- `SourceHealthLedger` 与真实源的交互未验证:一个源在别的关键词上好好的、只在这个关键词慢,也会被记成 degraded;
  记分粒度是"每源",不是"每源每关键词"。
- 取消语义仍是"这一层不取消 transport 请求"(见 `perProviderTimeout` 的注释);`CancellationToken` 只阻止装配结果,
  已经发出的请求还是会跑完它自己的超时。

