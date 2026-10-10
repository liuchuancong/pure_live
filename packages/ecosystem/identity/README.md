# pure_live_identity

> 职责:内容身份:跨源识别同一内容、置信度门槛与换源索引(身份从不重写 ContentRef)

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation(`pure_live_storage`)+ `pure_live_platform` 的模型 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依;**禁止 import 任何 provider**(身份是平台侧算的,源之间不感知) |
| 公共面 | 只有 `lib/pure_live_identity.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/identity.dart` —— `IdentityFacts` / `IdentityPolicy` / `IdentityMatcher`(纯函数,同步)
- `lib/src/identity_index.dart` —— `IdentityIndex` / `IdentityStore` 端口与 `KeyValueIdentityStore`

## 规则(规范来自 docs/content/content-identity.md)

**优先级:权威编号 → title + 创作者 + 合集 + 时长的模糊匹配(阈值可配)。** 落到代码上是四条硬规矩:

- **同 scheme 同值 = 同一内容**(置信度 1);**同 scheme 不同值 = 不同内容**,而且这条**压过**其它一切相符字段:
  两个 ISRC 不同的录音不会因为标题、歌手、时长全一样就被并成一个 —— 那正是"同一首歌的现场版/剪辑版/另一版"。
- **只有标题可比 → 永不自动并**。`fieldsCompared < 2` 时置信度被压到候选线以下。这一层存在的理由就是
  "两个源都叫《Call Me》不代表是同一内容"。
- **时长超出容差 → 也压到候选线以下**,不管其它字段多齐(理由同上:时长不一致最像另一个版本)。
- **可比字段之外的缺席不算反对票**:一侧没有创作者就把这个字段整个从分母里去掉。把缺席当惩罚等于专门罚那些
  元数据少的源,而少元数据不是"不同"的证据。
- 置信度 = **可比字段里相符的权重占比**;`autoMergeConfidence`(默认 0.9)以上自动并,`candidateConfidence`
  (默认 0.55)以上只作为候选交给用户确认一次,**确认结果被记住**(§规则 2"不强并 / 记忆")。
  这两个默认值是策略不是事实:调它们不需要改代码,但也还没有任何一份真实目录测过它们准不准。

## 身份不重写引用

规则 3 是"历史/收藏以用户**首次使用**的 ContentRef 为主键,identity 作为换源索引"。落到实现上:

- 没有权威编号的内容,身份 id **就是**第一次那个引用的 key(`sourceId/contentId/kind`),不新造 id、不改写 ref。
- `refKey` 是**不透明**的:永不从字符串反解 ref。源的 contentId 里带 `/` 是合法的,反解就会把内容撕错;
  所以成员 ref 单独存一份(`identity.refs`),`alternatives()` 返回的是当初注册时那个完整 ref(kind 也在)。
- 确认只做一件事:把后一个身份的成员并进前一个,再把 `identityOf` 改指过去。**任何一步都不改 ref 本身**,
  因此历史/收藏的主键不受身份层变动影响。

## 归属上的两处说明

1. **放哪一层**:`dependency-rules.md` §2 把 `identity` 列在 L1 ecosystem,而 content-identity.md §2 说
   "身份匹配是 services 层能力"。两句的实质是同一个约束(provider 之间不感知),所以目录按冻结的清单走 L1,
   实质由"这里不 import 任何 provider"守住。
2. **置信度存哪里**:`IdentityStore` 只存"ref → 身份 + 成员 + 事实",不存分数 —— 分数是 matcher 用事实当场
   算出来的。存分数会让一次策略调整(阈值改了)去要求重算所有历史记录,而事实重算是幂等的。

## 还没做的

- 没有接进聚合:搜索/Feed 目前不去重跨源结果,收藏/历史也没用 `alternatives()` 做"换源播放"。
- 没有 provider 侧事实来源:`IdentityFacts.from(ContentSummary)` 只读 `metadata.extra` 里那份编号键清单;
  各源要不要填、填哪些键,是 provider(W4/W6)的事。
- 阈值没有用真实目录校准过(上面写了是策略,不是事实)。

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / iOS / macOS / Windows / Linux | ✅ | 判定逻辑是纯 Dart;持久索引经 `pure_live_storage`(它用 `dart:io`)。 |
| Web | ❌ 取决于装配 | 本包自己不 import `dart:io`,但它唯一有意义的落盘形态要 `KeyValueStore`,而现有实现是文件型 —— 换 web 要么换 KV 实现,要么放弃持久索引。 |

## 未验证

- 跨源去重的**召回率**:matcher 的 11 个测试钉的是给定别名的判定,不是真实站点标题集上「该匹配的没漏、不该匹配的不是」。
- 索引增长后的读取成本:大收藏量下没有测量过。
- `identity` 目前**零消费者**(台账 §2bis 第 4 组),形状还没被第一个调用点钉住。
## 验证

- 分析:`dart analyze`(纯 Dart)
- 测试:`dart test -j 1`(19 全绿:matcher 11 + 事实序列化 2 + 索引 6)
