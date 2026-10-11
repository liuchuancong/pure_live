# pure_live_sites

> 职责:直播站点适配器合集 —— 一个站点一个目录(`api` + `site`),按 capability 契约把房间变成可播票据

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | → L0(`utils`、`network`)+ L1(`platform` 模型、`capability` 契约);同层禁互依;不得触碰 PlayerAdapter(I1/I5) |
| 禁止依赖 | 应用壳(I9);插件/脚本机制 —— 站点是普通 Dart 代码,在组合根注册 |
| 公共面 | 只有 `lib/pure_live_sites.dart` |
| 结构 | `lib/src/common/site_json.dart`(共用的响应读取规则)+ `lib/src/<site>/<site>_api.dart` + `lib/src/<site>/<site>_site.dart` |

## 为什么是一个包而不是每站一个包

后面还有三十多个站。每站一个包意味着每站一套 pubspec/README/CHANGELOG/workspace 登记,而它们真正共用的东西 —— 票据租约、
分页规则、"缺席不等于 0" 的读数规则 —— 会在三十份副本里各自漂移。参照产品 `wzgrx/pure_live` 也是这么处理的:
`packages/live_core/lib/src/sites/<site>/`,**每个站点两个文件**:

- `<site>_api.dart` —— 这个站的 url、身份常量、签名机制,以及它的响应形状怎么读才不会被一个畸形字段拖垮整页;
- `<site>_site.dart` —— 只实现 capability 接口,自己不碰 JSON。

**没有第三个 `<site>_model.dart`。** 调用方拿到的形状是 `pure_live_platform` 里那批共享模型(`ContentSummary`、
`ContentDetail`、`MediaTicket`、`StreamOption`、`LiveRoomStatus`),三十个站各自定义一套 model 就是把同一个房间/线路/
票据的形状抄三十遍。站点特有的只有"这个接口的这个字段历史上出现过几种形状",那属于 api 文件。

点播在 `pure_live_vod`,不在这个包里:视频可以反复打开,房间的地址带着会在播放中途到期的租约,`resolve`/`refresh` 对
两者的定义不同,一个类没法同时诚实服务。

## 内容

- `common/site_json.dart` —— `jsonMap` / `jsonList` / `jsonInt` / `jsonDuration` / `jsonString`:字段可能是 map、数字、
  数字字符串、`{value: …}` 盒子或者根本没有。**读不出来的值是缺席,不是 0 也不是空页** —— 把未知观看人数画成 "0" 是平台
  没许过的数,整页解析失败当成"这页没内容"是分页器会相信的谎。
- `acfun/` —— `AcfunSource`:目录按 `pcursor` **游标**翻页(没有游标的第 N 页直接拒绝,而不是当作第 1 页回答),
  分类是站自己的 `(filterType, filterId)` 对,房间按**主播 id**寻址(`liveId` 一场一个,拿它当 ref 会在下播后失效),
  换链要先做一次匿名 visitor 登录(会话按 5 分钟复用、被拒时丢弃、登录失败有退避),清晰度排序用站的 `level`
  而不是码率数字 —— 两者不同量纲。搜索页答的是包在 json 里的 **HTML**,所以卡片用 `package:html` 解析,
  而曝光属性是**一段 json 文本**:把它当 Map 取会让搜索"什么都没有且什么都没失败"。
- `huya/` —— `HuyaSource`:feed / 分类 / 搜索 / 房间状态 / CDN 线路 / guest HLS 换链。AntiCode 的 `fm` 模板**单遍**填充
  (房间名里真写着 `$2`,顺序 replaceFirst 会把签名算到服务器没模板过的串上);`rotl64` 只转低 32 位而保留高 32 位。
- `douyu/` —— `DouyuSource`:feed / 分类 / 搜索 / 签名换链。描述符按设备签发并共享一次刷新;`expire` 到点会**切断已建立的
  连接**,所以票据带 `expiresAt` + `cutsConnection: true`(huya 的租约不切,故为 false)。

## 钉住的规则

- 线路 id 是**序号不是名字**:huya 的 CDN 行没有名字,给它编 "线路2" 会让"我看第 3 路坏了"在源侧和平台侧指两件不同的事。
- 质量列表答空而不是造假:匿名通道只有一个档,造假 1080p 行是这台传输兑现不了的承诺,而只有一个选项的选择器不如没有。
- 借来的传输不由站点关闭(`_ownsClient`),站点自己 new 的才在 `dispose` 里关。
- 分类树**不完整不缓存**:一次抖动把三组钉死到进程结束,第四组不重启就再也不回来。

## 验证

- 分析:`dart analyze packages/providers/sites`
- 测试:`dart test packages/providers/sites`(114 条:acfun 29 + huya 36 + douyu 49;传输一律用 `pure_live_network`
  的 `testing.dart` 罐头适配器,不联网)
- 架构:`dart run tool/check_architecture.dart --strict`

## 未验证

- **未录到真实响应**:两个包的 `fixtures/` 都空,字段名与状态码来自 v1 维护的站点线和 dart_simple_live 的知识,
  不是本仓库抓的样本。上游改了字段这里会在分析/测试里绿着,只在真机上炸。
- 无登录、无弹幕 socket、无账号画质档(`hint` / `rateArr`)、无超级聊天;TARS token 租约没做。
- 真机播放未测(见 [BUILD_POLICY.md](../../../BUILD_POLICY.md)):票据能构造不等于内核能开播。
