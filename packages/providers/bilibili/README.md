# pure_live_bilibili

> 职责:Bilibili **点播源**适配器 —— 热门列表、WBI 签名搜索、分 P 详情与**游客**播放地址。
> 实现 `BrowseCapability` / `SearchCapability` / `ResolveCapability`;不认识播放器,不认识 App。

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 + L1 契约包;同层禁互依;不得触碰 PlayerAdapter(I1/I5)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_bilibili.dart`;内部实现放 `lib/src/` |

## 模块

| 文件 | 提供 |
|---|---|
| `src/bili_wbi.dart` | `wbiMixinKey` / `wbiSignedQuery`(纯函数)+ `BiliWbiSigner`(取 key、缓存、签)+ `biliUserAgent` / `randomBuvid3` |
| `src/bilibili_vod_source.dart` | `BilibiliVodSource` + `bilibiliSourceId` / `bilibiliPopularCategory` / `bilibiliCidKey` / `bilibiliBvidKey` |

## 行为契约

### WBI 签名
- 配方:`nav` 的 `wbi_img` 两个 url 取文件 stem 拼成原 key,按 `wbiMixinKeyEncTab` 置换取前 32 位;
  参数按 key 排序、值里去掉 `'()*`、**`Uri.encodeComponent`** 编码,连 `wts` 拼串后再拼 mixinKey 取 md5 = `w_rid`。
- **签名与发送必须是同一串字节**:`wbiSignedQuery` 返回**查询字符串**而不是 map。旧写法返回 map 并签
  `Uri.encodeQueryComponent` —— 那个编码器把空格出 `+`、把 `!~*'()` 出 `%XX`,而站方客户端用的是
  JavaScript `encodeURIComponent`(空格 `%20`、`!~*'()` 原样),且 dio 自己再编码一次。带空格的关键词
  因此必然签名不符。现在字符串只构造一次,发出去的就是哈希过的那个。
- `wbiMixinKey` 对**长度不足 32** 的原 key 抛 `FormatException`:切一个截短出来的 key 会签出一个永不合法的
  请求,而站点回的是风控码,不会告诉你是这里出的问题。
- key 缓存有时限(默认 6 小时,可注入 `keyLifetime`);取 key 失败进入 `failureBackoff`(默认 2 分钟):
  没有退避时,`nav` 挂了 = 每一个签名请求都各打一次 `nav` 并各等一次超时。
- 单飞(`_pending`)让并发签名共享一次 `nav` 取 key,且完成时只清自己那一次(`identical` 检查)。
- `randomBuvid3()` 用 `Random.secure()` 出 `8-4-4-4-12` + `infoc`。旧写法从
  `microsecondsSinceEpoch` 拆段:第一段是 16 位十六进制(站点不会发成那样),且同一微秒的两次调用得到同一个值。

### 源
- **`code != 0` 一律抛,并带上站点的 `message`。** 热门列表以前不查 `code`:一个 `-352` 风控回包被解成
  "这一页没有内容",屏幕显示空列表,恢复阶梯也没有可重试的失败。
- 只有一个分类:`bilibiliPopularCategory`。`browse` 收到别的 `query.category` 直接拒,不"顺手返回热门"。
- 搜索:先签再发,`page_size` clamp 到 1..50;标题剥掉 `<em class="keyword">` **并**还原 HTML 实体
  (`&quot;` / `&amp;` 等)—— 搜索结果里带实体的标题在列表上显示成 `&quot;` 就是一行坏数据。
- 时长:`mm:ss` 文本;任何一段解析不出来就是 null(旧写法把坏段当 0,于是 `"--:--"` 变成一个 0 秒的视频,
  空字符串也变 `00:00`,都上了屏幕)。
- 详情:每一 P 是一个 child `ContentRef`,`contentId = "<bvid> P<n>"`(单 P 就用 bvid),cid 放在
  `metadata[bilibiliCidKey]` —— `resolve` 只认这一个键。
- 播放:游客路径 `platform=oc&try_look=1&fnval=1`,拿 mp4 `durl` 而不是 DASH。**cid 写进票据自己的
  `metadata.extra`**(`bilibiliBvidKey` / `bilibiliCidKey`),`refresh` 只看票据 —— 旧的实现把 cid 存在一个
  进程内的 map 里,那个 map 无上限增长,而且换进程/重启后换链直接失败。
- `quality` 请求会被记下(`bilibili.requestedQuality`)但不生效:游客码率是站点上限,静默丢掉用户的选择不该
  是看不见的。`line` 请求**拒绝**:一个分页只有一条游客流,把"第二条线路"播成第一条是骗人。
- 票据头带 `referer: https://www.bilibili.com/`(缺了它 CDN 一律 403),cover url 的 `http://` 升 `https://`。
- **一个 `NetworkClient` 与 signer 共用**:`dispose()` 关的就是那一个。旧写法在 `client == null` 时让
  `BiliWbiSigner` 自己 new 一个,而 `dispose()` 从来碰不到它 —— 每个 source 实例漏一套连接池。

## 依赖

`crypto`(md5)、`pure_live_network`、`pure_live_platform`、`pure_live_capability`、`pure_live_utils`(`Clock`)。
dev 依赖 `dio`:传输替身要实现 `HttpClientAdapter`,而 `pure_live_network` 把它当注入参数收下却不再导出。

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / Windows / iOS / macOS / Linux | ✅ | 纯 Dart + `dart:convert`;网络在 `pure_live_network`(dio) |
| Web | ⚠️ 代码可编译,但**未验证** | 签名与 buvid 都不碰 `dart:io`;真正的障碍是浏览器同源策略会拦 `api.bilibili.com` |

## 验证

- `dart analyze` → No issues found。
- `dart test` → **28 passed**:`bili_wbi_test` 11 条 + `bilibili_vod_source_test` 17 条,全部跑在
  脚本化的 `HttpClientAdapter` 替身上(临时目录、无网络)。
- WBI 的向量是**回归钉**(先由本实现算出一次,再写成字面量),不是站方 oracle —— 它能抓住配方被改动
  (置换表、排序、剔除字符、编码器),抓不住"站点改了算法"。有外部意义的那一条是空格的编码:
  `encodeURIComponent(' ')` 是 `%20`,这是公开事实,而 `encodeQueryComponent` 给 `+`。

## 未验证

- **零消费者**:`apps/pure_bili` 还不存在(台账 §2bis),所以**没有一个字节是真从 bilibili 取回来的**。
  端点、字段名、`code` 语义都来自协议笔记与 v1 那一条线,回包形状是手写的。
- WBI 的 key 轮换周期(6 小时)是**推演值**,不是观测值;`failureBackoff` 同理。真机跑起来后如果 `nav`
  返回的 key 变化更快,签名会整片失败 —— 现象是搜索全 -403 而热门仍然正常(它不签名)。
- 游客 try_look 的真实码率上限、`durl` 在多分 P 长视频上的分段形状、`-352` 之后 buvid 该不该换新:
  都要等真数据。`page_size` 50 的上限照抄协议笔记,未验证。
- `hasMore` 用"整页 = 还有"的猜测(站点不给总数);短页即止在热门表上成立,在搜索上是猜的。
- 登录、大会员清晰度、pgc/番剧、弹幕:本包**没有实现**,不是"实现但没测"。
