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
- `kuaishou/` —— `KuaishouSource`:八个静态分区与其翻页子分区、按**分区 id 长度**二选一的两个目录接口、一次性的推荐块
  (那个接口没有翻页参数,要第 2 页就是不发请求)、主播搜索(同一份答案按房间和人两种形状读)、以及房间页里
  `window.__INITIAL_STATE__` 那份文档。**房间以主播 id 寻址**,`liveStreamId` 一场一个,所以它是 `streamId` 而不是 ref。
  播放清单**按 codec 分组**:站点给 H.265 行起的名字和 H.264 行一模一样,合并就成了一条某些解码器打不开的标签;
  同 codec 同行才合并成一条清晰度的多条线路。离线页不报观看人数(v1 写 `'0'`,那是平台没许过的数),`isLiving`
  既不是真也不是假时是 `unknown` 而不是已结束。
- `baidulive/` —— `BaiduliveSource`:目录**按 session 游标**翻页(`session_id` + `refresh_index`,要第 2 页却没带回游标
  就拒绝,而不是当第 1 页回答;服务器重复自己的计数器就是列表到头,而不是再要一页同样的房间),分类表是信息流第一页
  捎带来的(站点没有独立分类接口),房间是 `371` 命令。**同一个状态在两个接口里编号不同** —— feed 用 1 表示在播,
  命令用 0 表示在播,共用一张映射会把每个在播的格子读成预告。`error_code` 只有 1 和 4 是"没这场直播"。
  拉流地址必须落在站自己的 cdn 域名、`/live/` 路径、对应扩展名,并且**路径里带着这个房间的 id**;
  `flv-live.bdstatic.com` 按站点客户端的做法**就是 http**,票据如实报 `MediaProtocol.http` 而不是谎称 https。
  预告是 `notStarted`,回放是 `ended` 且申报可回看;细细的房间答案会用列表卡片补齐展示字段,但**绝不补观看人数**。
- `bigo/` —— `BigoSource`:首页是**一份有限快照**(20 行,两页都从它切,`total` 是真的;30 秒内复用,失败不缓存),
  房间是 studio 命令。**房间是句柄不是数字**:`room_id` 是超出 javascript 精确整数范围的 int64,只能按**文本**留着,
  过一遍 double 就会指向一个不存在的场次。**被门禁的 `alive == 0` 不是"已下播"的观测**,所以登录房/密码房读作
  `unknown` + `restriction` 说明原因;反过来,门禁房或站点说没在播的房间递来 `hls_src` 是**接口变了**,直接拒绝 ——
  地址存在不等于有权播放。换地址要先走两次 jsonp(服务器时间戳 → AES-256-CBC 信封,密钥用 OpenSSL
  EVP_BytesToKey 从站点公开包里的口令派生),**回调名不是自己那个就不执行**。一路流就是一个清晰度、**没有线路轴**。
  清单级保护 `BigoHlsProtection`(TS 头两个包各 16 字节按种子 xorshift 异或)已带往返测试,但播放链还没有
  分片变换钩子,这条缺口写在台账里。
- `cc/` —— `CcSource`:菜单是 **Dashen 两块拼出来的**(公开游戏注册表给名字和图标,官方"直播入口列表"配置决定哪些
  游戏真的能翻;老的分类接口现在吐的是应用页而不是分类表)。入口找不到对应游戏、目的地不是站 own 的
  `https://cc.163.com` 路由、配置 id 没原样回来、身份重复 —— 都是**配置变了**,整份菜单失败,而不是悄悄少一行。
  列表宽度固定是站的 30(`start=(page-1)*30`),调用方要 50 也不会改,否则观众一缩放就把同批房间重抽一遍。
  同一份 payload 里**有两把观众尺**:`webcc_visitor`/`hot_score`/`visitor`/`total_visitor` 是热度,
  `vision_visitor`/`online_num` 是在看的人数;两个都留着,才不会把 50 万热度画成 50 万人在线。
  标题写着 `【重播】` 而状态字段仍说在播时,房间照播,真相记在 tag 里。清晰度是 tier(`blueray`→原画、`ultra`→蓝光,
  表里没有的键保留原名),一个 tier 内部的 cdn 家族才是线路,顺序按站自己的偏好表;原画那档不带 `vbr`,
  所以它的位置来自名字而不是缺席的码率。直播包里的线路值可能只是挂在房间 m3u8 上的 `?sign=`,不是完整地址。

## 钉住的规则

- 线路 id 是**序号不是名字**:huya 的 CDN 行没有名字,给它编 "线路2" 会让"我看第 3 路坏了"在源侧和平台侧指两件不同的事。
- 质量列表答空而不是造假:匿名通道只有一个档,造假 1080p 行是这台传输兑现不了的承诺,而只有一个选项的选择器不如没有。
- 借来的传输不由站点关闭(`_ownsClient`),站点自己 new 的才在 `dispose` 里关。
- 分类树**不完整不缓存**:一次抖动把三组钉死到进程结束,第四组不重启就再也不回来。

## 验证

- 分析:`dart analyze packages/providers/sites`
- 测试:`dart test packages/providers/sites`(312 条,每个站点目录配一份 `test/<site>/`;README 上列的只是其中几个,
  weibo / inke / kugou / missevan / kuaishou / baidulive / bigo / cc 见 CHANGELOG。传输一律用 `pure_live_network`
  的 `testing.dart` 罐头适配器,不联网)
- 架构:`dart run tool/check_architecture.dart --strict`

## 未验证

- **未录到真实响应**:两个包的 `fixtures/` 都空,字段名与状态码来自 v1 维护的站点线和 dart_simple_live 的知识,
  不是本仓库抓的样本。上游改了字段这里会在分析/测试里绿着,只在真机上炸。
- 无登录、无弹幕 socket、无账号画质档(`hint` / `rateArr`)、无超级聊天;TARS token 租约没做。
- 真机播放未测(见 [BUILD_POLICY.md](../../../BUILD_POLICY.md)):票据能构造不等于内核能开播。
