# pure_live_iptv

> 职责:IPTV 源插件:一份 M3U 清单 + 可选 XMLTV 节目单,按 capability 契约提供浏览/搜索/换链

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | → L0(`utils`)+ L1(`platform` 模型、`capability` 契约、`external_tvbox` 的 M3U 解析);同层禁互依;不得触碰 PlayerAdapter(I1/I5) |
| 禁止依赖 | 反向依赖;应用壳(I9) |
| 公共面 | 只有 `lib/pure_live_iptv.dart` |
| 结构 | `lib/src/iptv_source.dart`(BrowseCapability + SearchCapability + ResolveCapability)、`lib/src/xmltv_parser.dart`(EPG) |

## 内容

- `iptv_source.dart` —— `IptvSource`:分组浏览(`categories` / `browse(category)`,分页带 `total`)、`search`(名字或分组子串,**保持清单原顺序**并且 `hasMore:false` + 实到条数 —— 几千行的清单没有"翻页",假装能翻是谎报)、
  `resolve`(取清单第一个地址,协议按扩展名判 hls/http,`user-agent` 等每流行头 **优先于** 全局头:IPTV cdn 不给对 referrer 就 403)、
  `nowPlaying` / `programmeFor` / `schedule`(EPG  joins 在频道名上)、`guideReport`(把"这份节目单有多少条、多少条不可用、有没有被截断"说给诊断视图)
- `xmltv_parser.dart` —— `XmltvParser`(有界:`maxChannels` / `maxProgrammes`,越界置 `truncated`)、`XmltvGuide`(`nowOn` / `upcoming` / `onAir` / `between` / `channelFor`)、`parseXmltvTime`(`20260109120000 +0800` → UTC)

## 钉住的规则

- **属性按名字取,不按位置;`<programme … />` 自闭合是合法元素**。旧实现在正则里写死了 `start=… stop=… channel=…` 的顺序并强制要求闭合标签,而真实节目单常把 `channel=` 放在最前、常没有 description ——
  **一份正常 EPG 会被解析成 0 条节目且不报任何错**,这是解析器最坏的失效形状。
- **CDATA 要先解包再去标签**:`<![CDATA[新闻]]>` 整段会被标签正则一路吃到 `>`,先去标签等于把所有 CDATA 描述变成空串。
- 名字里的 `&amp;` 等五个实体解掉,连续空白折叠;`<programme-guide>` 不算 `<programme>`(前缀匹配要检查后一个字符)。
- 坏行**跳过并计数**(`skippedEntries`):`start` 读不出、标题为空、`stop` 不晚于 `start`(全天占位行很常见,留着会让 `between` 永远命中)。
  "节目单是空的"与"节目单有 40% 是烂的"在屏幕上长得一样,而修法完全不同。
- 未闭合的元素**跳过而不是吞掉后面全部**:一行坏了不该删掉它之后的整个节目单。
- M3U 只有名字可 join,所以 `channelFor` 先按 id 精确、再按显示名做**去空格/连字符/中点**的松匹配("CCTV-1综合" 找到 "CCTV 1 综合")。
- 时间一律转 UTC 比较;节目单偏移写错 12 小时这里没有任何其他检查会抓到 —— 它会照常渲染,只是每个"现在演什么"都答错。
- `Clock` 注入:`nowPlaying` / `schedule` / `resolve` 的 `createdAt` 都取自它,"18:00 演什么"因此可以不睡觉地问。
- 无节目单时 EPG 面全部回 null/空,不猜标题;换不到本包频道的 ref 抛 `StateError`(与其他 provider 同一形状)。

## 验证

- 分析:`dart analyze packages/providers/iptv`(2026-10-11:0 issue)
- 测试:**本包一个测试都没有**。行为用仓库外一次性脚本对一份含畸形行的节目单实测:两种属性顺序 + 自闭合行都能解析、
  `News &amp; more` 解成 `News & more`、CDATA 描述取回 `晚间新闻`、`skipped=3`(坏 start / 时间倒置 / 无标题)、
  松匹配 join 到 `cctv1.cbn`、`onAir`/`between`/`upcoming` 各 1 条、`search` 命中并带上"现在演什么"、
  `resolve` 给出 hls 与 `user-agent: Box` 且时间来自注入时钟。脚本已删除,观测不可重放。

## 未验证

- **没有真机 IPTV**:真实运营商标单的方言(`#EXTVLCOPT` 变体、`tvg-id=`/`group-title=` 属性写法、GBK 编码文件、
  gzip 的 `.xmltv.gz`)本包**按未知内容处理**,`external_tvbox` 的 M3U 解析器是否吃 `tvg-id=` 也没对账过 ——
  若清单带 `tvg-id`,现在这条靠名字的松匹配就是白跑的。
- 大节目单的性能未量:`_scanElements` 是 `indexOf` 线性扫,20 万行 + 每行再扫子元素的复杂度是 O(总行数 × 平均深度);
  上限只是防 OOM,不防慢。
- `search` 没有排序分数(子串命中即算),几千行清单上"最相关的排第一"要靠上层,不在本包。
- 换链只做静态地址:时移/回看(`timeshift`、`catchup` 参数拼法)完全没实现,`refresh` 明确抛不支持。
