# pure_live_vod_sites

> 职责:点播站点适配器合集 —— 一个站点一个目录(`api` + `site`),按 capability 契约把视频条目变成可播票据

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | → L0(`utils`、`network`)+ L1(`platform` 模型、`capability` 契约);同层禁互依;不得触碰 PlayerAdapter(I1/I5) |
| 禁止依赖 | 应用壳(I9);插件/脚本机制 —— 站点是普通 Dart 代码,在组合根注册 |
| 公共面 | 只有 `lib/pure_live_vod_sites.dart` |
| 结构 | `lib/src/<site>/<site>_api.dart` + `lib/src/<site>/<site>_site.dart`(与 `pure_live_sites` 同一形态) |

## 为什么单开一个包

`site 是 site,视频是视频`。直播站点在 `pure_live_sites`,这里放点播适配器(参照产品的 `live_core` 与 `live_vod` 也是两个包):

- 房间的地址带租约,到期会中断已经在放的流;视频的 `durl` 过期了重新要一条就是了,`refresh` 的语义完全不同。
- 直播的"线路"是同一内容的不同 CDN;点播的"线路"在这类站上根本不存在,只有 `qn` 画质档。
- 把两者塞进一个 `resolve`,就必须让一个方法同时回答"现在能不能播"和"这一集能不能播",而它对 `expiresAt` 的取值规则相反。

规则本身和站点包一样:**一站一目录,一站两文件,模型是共享的**(`pure_live_platform` 的 `ContentSummary` /
`ContentDetail` / `MediaTicket`),不给每个站配一套 model。

## 内容

- `bilibili/bilibili_api.dart` —— 这一站的 url(`nav` / `popular` / `view` / `search/type` / `player/playurl`)、
  `buvid3` 与浏览器头、以及 WBI 签名:mixin key 置换表 + 对排序后的 query 做 md5。签名步骤是纯函数
  (`wbiMixinKey` / `wbiSignedQuery`),测试用固定向量钉住;外层 `BiliWbiSigner` 只管网络和缓存。
- `bilibili/bilibili_vod_site.dart` —— `BilibiliVodSource`:`BrowseCapability`(热门表 + 分页)、`SearchCapability`
  (WBI 签名搜索)、`ResolveCapability`(guest `try_look` 的 mp4 `durl`)。`detail` 把每个 `page` 展开成可播的子 ref,
  `cid` 走 ref metadata,和 spider 适配器的分集坐标同一形状。

## 钉住的规则

- **签名返回字符串而不是 map**:交回 map 会让调用方二次编码,而哈希算过的字节和线上的字节就不再相同 —— 旧版本用
  `Uri.encodeQueryComponent`(空格→`+`)签名、dio 用 `%20` 发送,任何带空格的关键词都被判成签名错误。
  `Uri.encodeComponent` 才是服务端自己客户端里那个 `encodeURIComponent`。
- `code != 0` 是站点在拒绝,不是"这页没有内容":风控 / `-403`(guest 要了账号才有的东西)/ `-352`(buvid3 没过)
  都要带站点的 message 抛出去,否则日志里三周后没人能诊断。
- 传输由组合根借入时不关;`randomBuvid3` 用 `Random.secure()`,旧版用微秒推导,既不是站点会发的形状又可被猜。
- 时长解析不出来是"没说",不是 0 秒:旧实现把坏值当 0,界面就把一条视频显示成 `00:00` 这个事实。

## 验证

- 分析:`dart analyze packages/providers/vod`
- 测试:`dart test packages/providers/vod`(wbi 固定向量 + 签名器缓存/退避;source 的列表/详情/搜索/换链用
  `pure_live_network` 的 `testing.dart` 罐头传输)
- 架构:`dart run tool/check_architecture.dart --strict`

## 未验证

- **未录到真实响应**:`fixtures/` 空,端点知识来自 newBV 的 bilibili-api 客户端与 v1 维护的 WBI 配方。
- 无登录、无大会员画质、无 pgc/bangumi、无弹幕:guest 只拿 `try_look` 的封顶档。
- dash 清单(`fnval=16`)未支持,只走 `durl` mp4;真机播放未测。
