# W4 进度 — 第一参考插件:Bilibili

> 波次目标(路线图):用一条真实站点链验证完整生态链(内容链 + 媒体链)。
> 本文只记实际落到的东西,以及还差什么才能验收。

## 0. 开工就撞上的第一处无效状态:CapabilityRegistry 并不存在

以下六处都把发现这件事写成了既有事实:

| 文档 | 原文 |
|---|---|
| [../architecture/runtime.md](../architecture/runtime.md) §1 | 冷启动第 3 步 `CapabilityRegistry.resolve() 能力发现` |
| [../architecture/runtime.md](../architecture/runtime.md) §2 | CapabilityRuntime 的职责就是"发现/查询/按 capability 取 Provider 列表" |
| [../contracts/provider-contract.md](../contracts/provider-contract.md) §3 | "查询方永远通过 CapabilityRegistry 发现 Provider 列表,不硬编码源" |
| [../services/search.md](../services/search.md) | 流程第一步:`CapabilityRegistry 枚举 SearchProvider(用户启用的源)` |
| [../plugin/plugin-lifecycle.md](../plugin/plugin-lifecycle.md) | Enabled 态 = "对 CapabilityRegistry 可见,可被业务消费" |
| [../adr/0004-capability-system.md](../adr/0004-capability-system.md) | "CapabilityRegistry 按 capability 索引发现" |

代码里没有它,而 W4 的 provider 要注册的地方就是它,W5 的 search/feed 聚合如果拿不到它就只能硬编码源 ——
而硬编码正是 provider-contract §3 禁的那件事。所以先落它。

## 1. 已落:`CapabilityRegistry`(capability 包 11 测试,包内共 40)

实现在 `packages/ecosystem/capability/lib/src/capability_registry.dart`,分层依据:provider 在 L5,
查询方在 L2,注册表必须在两者之下,而它需要的 `CapabilityKind` / `CapabilitySet` 本来就住在这个包。

**两个视图,故意不一致**——这是本单元唯一值得单独写的决定:

| 视图 | 依据 | 给谁 |
|---|---|---|
| `providersFor(kind)` | 源注册时**声明**的 `CapabilitySet` | 路由与展示:"这个源有没有搜索" |
| `implementations<T>()` | 对象**实际实现**的接口 | 真要发调用的一方(search.md 的聚合循环) |

理由是"声明"与"实现"在第三方源里可以不一致:多声明一个 `search` 的源,不该让聚合循环拿到一个连
`as SearchCapability` 都过不了的对象(注册表存的是 `Object`,转型就是它的运行期失败点);但它其余的能力是
真的,不该因为一处多声明就整源不可见。两者一致由
`contract.declaration.missing_interface` 在安装前保证(provider-contract §1 规则 5),注册表自己不重复判定 ——
它不 import `testing.dart`,那份断言集是交付门,不是运行时代码。

**注册即生命周期**:`register` 同 `sourceId` 覆盖而不是拒绝(源刷新、扩展重新启用都会走到第二次注册;
拒绝的话留下的反而是旧对象在应答),并且覆盖后保持在原来的注册位置(刷新不该悄悄改变聚合顺序)。
`unregisterExtension(extensionId)` 是 Enabled 行的落点 —— 生命周期事件说的是扩展,不是它名下的每个仓库,
让调用方逐个注销就会漏掉一个仍在应答的禁用插件。

**没做的两件,连同理由**:没有 `enabled` 标志(可见性已经由"在不在注册表里"表达,再加一个布尔就是两套真相),
也没有 `priority`(哪份文档都没规定 provider 之间的顺序,搜索的并发聚合是超时与失败隔离,不是排序)。
这两个字段现在加进去只能靠猜。

## 2. W4 剩下的两处前置缺口

1. **真实响应录制的通道还没有。** provider-contract §1 规则 5 写的是"提供 fixtures(**真实响应录制**)",
   而当前环境既没有对 bilibili 的抓取授权,`fixtures/` 的入库规则也只收"被两个以上包共用"的样本。
   先猜 API 形状再写解析的结果是可以预见的:契约测试全绿,真站全红。所以顺序必须是
   录制—回放通道(每条 API 一份录制件 + 一个不联网的回放器)→ 解析 → 同一套 `checkCapabilityContract`。
2. **Danmaku / Auth 的方法集还没有定义。** `capability-contract.md` §3 只给了内容类能力的四个方法集,
   `CapabilityKind.danmaku` / `auth` / `subtitle` / `epg` 在代码里没有接口,包注释也写明"随定义其调用的那一批
   一起补上断言"。W4 说要覆盖 Danmaku / Auth,那就不是写实现而是**定契约**,需要各自的 ADR;
   在没有规范的情况下先编一套签名,后面 W6/W7 只能迁就它。

于是本波的落地顺序:注册表(已落)→ 录制通道 → Bilibili 内容链(browse / detail / search / feed / resolve / refresh,
跑同一套契约断言)→ danmaku 与 auth 契约定稿 → 媒体链接到 W3 的 resolver 与 media 映射。

## 3. 主体被卡住期间先落的消费端:聚合搜索(13 测试)

§2 那两条前置(真实响应录制、danmaku/auth 的方法集)都不是我一个人能定的:前者要么有联网授权、要么先造录制通道,
后者是改契约。但**消费 discovery 的那一侧不需要等它**,而 provider-contract §3 与 services/search.md 都已经把
发现入口写死了 —— 所以先把聚合搜索落下来,等第一个 provider 出现时它面对的是"接进一条已经在跑的链",
而不是再交一个孤立对象。

L2 的第一个包因此是 `pure_live_search`,依赖只有 `pure_live_platform`(词表)与 `pure_live_capability`(能力接口 +
`CapabilityRegistry`)。这条 L2→L1 的边我写进了依赖规则 §3 并限定在**契约面**:L2 可以用能力接口和注册表,
**不**用网关/权限/任务/解析器这些运行时服务 —— 那些是组合根注进来的。护栏只查方向,所以这条界线由 review 守,
文档里也这么写了(不假装它是机械强制的)。

实现照 services/search.md 的四条失败规则逐条落,每条都有测试:

| 规则 | 落法 | 被钉住的测试 |
|---|---|---|
| 并发查询 + 超时 | `perProviderTimeout`(默认 8s),到点的源记 `timedOut` | 一个永不完成的源 + 一个快源:快源的结果仍然返回 |
| 失败隔离 | 源抛出的异常收进 `failed.detail`,不外溢 | `test_search_sourceThrows_isRecordedNotRethrown` |
| 部分结果可用 | 结果按源分桶,`answered` / `problems` 两个视图 | 同上两条 |
| 无结果源静默标记 | `empty` 与 `failed` 是两种结局(empty 不带 detail) | `test_search_answersWithNothing_isMarkedEmptyNotFailed` |
| 结果必须是自己的内容 | 指向别源的条目在这里丢弃并计数(`contract.search.foreign_source` 的第二道) | `test_search_dropsItemsBelongingToAnotherSource` |
| 不硬编码源 | 只经 `providersFor(search)` 选择,`onlySources` 是站内搜索的收窄 | 两条 onlySources 测试 |

两处刻意的不做:结果**先到先显示**需要一条流式接口,而那是 UI 的分批渲染决定,现在加等于猜;按
直播/视频/音乐/频道分组是呈现规则,留在 UI。空关键词则相反 —— 它必须**一个请求都不发**,因为 N 个源的
空关键词就是 N 次无意义请求,包 README 把这条与它的理由写在一起。
## 4. 消费端的另一半:Feed 聚合(13 测试)

`packages/services/feed` 与搜索同一个理由:`feed.md` 已经把 `FeedSource[] → FeedAggregator → FeedSection[] → Home`
与"Home 不直接依赖 Bilibili/Douyu/Music"写死,这一段不需要 provider 就能落。三条判断值得单独记:

- **节的顺序是注册顺序**,不是到达顺序。测试故意让第一个源慢 40ms、第二个秒回,断言出来仍是 `[slow, quick]` ——
  否则用户的首页会因为某站点今天响应慢而换一次布局,而布局是用户自己排的。
- **`FeedSection` 没有标题**。文档草图写了"标题",但同一篇文档又说"首页模块编排是用户数据(sync 范围)";
  标题既然属于编排,聚合器再造一个就是同一块砖位有两个真相。这条差异写进包 README,而不是悄悄改掉。
- **"不出现在 Feed"不等于"无声消失"**。声明了 feed 却拿不出 `FeedCapability` 的源被跳过,但进 `skips` 带
  `notCapable` 与原因;空结果、超时、异常同样各留一条。用户装了插件却看不到砖位时,得有人说得清为什么。

坏数据按节就地处理:指向别源的行丢弃并计入 `foreignItems`,同节内重复 ref 保留第一条并计入 `duplicateItems`
(`contract.feed.duplicate_ref`);**跨源不去重** —— ref 里带着源,两个源给同一片段是两条不同的推荐。
没做的:"关注更新 / 历史『继续看』"两类 FeedSource 要 favorites / history 服务,它们还不存在。

## 5. 验证证据
| 命令 | 结果 |
|---|---|
| `packages/ecosystem/capability` → `dart analyze .` | No issues found |
| `packages/ecosystem/capability` → `dart test -j 1` | **40 全绿** = 原有 29(接口词汇 8 + 契约断言 21)+ 注册表 11 |
| 注册表的声明/实现分歧 | 专门一条 `test_overDeclaration_isNotHandedToTheTypedCaller`:同一个源,`providersFor(search)` 列出它,`implementations<SearchCapability>()` 不列 |
| `dart analyze packages` | No issues found |
| `dart run tool/check_architecture.dart --strict` | `packages=26 errors=0 warnings=0`(注册表落在 capability 包内,没有新增依赖边) |
| `dart format --output=none --set-exit-if-changed packages tool/check_architecture.dart` | 148 文件 0 changed |
| `powershell -File tool/test_check_architecture.ps1` | PASS: 23 assertions across 21 cases |
| `packages/services/search` → `dart analyze .` / `dart test -j 1` | No issues found;**13 全绿**(并发与收窄 5 + 失败隔离 4 + 数据规则 4) |
| `packages/services/feed` → `dart analyze .` / `dart test -j 1` | No issues found;**13 全绿**(选源 3 + 隔离 4 + 数据规则 4 + 分页 2) |
| 两个 L2 包之后 | `packages=28 errors=0 warnings=0`;`dart analyze packages` No issues found;格式化 156 文件 0 changed |

## 6. 已知欠账

- `CapabilityRegistry` 现在**在组合根里**(`runtime.capabilities`,见 w2-progress.md §1.7),但**注册动作还没有人做**:
  谁在扩展 enable 时把 provider 放进去、谁在 unload 时 `unregisterExtension`,要等第一个真实 provider(W4 的 Bilibili)
  或第一个内置扩展出现才有主语。在那之前它仍然只是一份可测的机制。
- 注册表不校验声明真伪(见上)。若将来出现"声明与实现都齐但语义不符"的源,`providersFor` 会照单全收,
  而那属于契约测试的更细断言面,不是索引该补的东西。
- `ContentPriority` 一类的排序需求一旦真的出现(例如多源聚合里"优先某站"),得先定它属于
  `SourceConfig` 还是注册表条目,不要在两个地方各放一份。

- 聚合搜索还**没有装配点**:`CapabilitySearchAggregator` 要的是 `CapabilityRegistry`,而注册表现在是空的
  (上一条欠账)。`onlySources` 是为 provider-contract §3 的"站内搜索共用一套类型"留的参数,不是已经接好的流程。
- 结果是**全部落定才返回**。首屏要先到先显示需要一条流式接口,而它取决于 UI 怎么分批渲染 —— 现在定等于猜。
- 搜索历史与热搜没做:历史记录归业务面(W5),热词(`hotword`)在 capability-contract §3 里还没有调用面。
- 两个消费端(搜索、Feed)还**没有在组合根里出现**:`CapabilitySearchAggregator` 与 `CapabilityFeedAggregator`
  都要 `CapabilityRegistry`,而注册表仍是空的(§1 的欠账)。它们现在是可测的机制,不是跑起来的流程。
