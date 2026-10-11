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
- `showroom/` —— `ShowroomSource`:在播表是**一整份快照**(`/api/live/onlives` 没有服务端翻页,所以本地切片、`total`
  就是快照大小;30 秒内复用,失败绝不缓存成空目录)。没人播的分类里放的是 `cell_type` 消息格而不是空数组,这种行跳过,
  而**看着像直播的行照常严格校验** —— 真改了接口要响,不能跟着填充行一起被咽下。**房间有两个名字**:耐久的数字
  `room_id`(它是 ref)与公开的 `room_url_key`(分享链接里那个);句柄经 status 接口解析一次,所以主播改名不会弄丢收藏。
  **在播要 `is_onlive` 与 `live_status == 2` 两边都点头**;只有一边说是,就是 `unknown` 并记下 disagreement,resolve
  拒绝而不是播一个"也许"。`view_num` 是本场流量 ⇒ 落在累计,不是同时在线。`premium_room_type` 非零是
  `LiveRestriction.unknown`(站点说收费但没说怎么收费)。只读 `hls`/`hls_all` 两型,`hls_all` 是站自己的自动档,
  排在固定档之上。聊天主机与 key 先过形状检查才敢当 socket 地址用,两者齐了才申报握手。
- `picarto/` —— `PicartoSource`:**房间就是频道名**(`[A-Za-z0-9_]{1,50}`,且站点自己的页面词 `search`/`login`/`about`
  等是保留字,永远不会被解析成某人的频道)。explore 的答复必须**自证是这次请求**:`current_page`/`per_page`/
  `last_page`/`total` 全都核对,过了最后一页还带行就是接口变了。成人行与离线行从网格里**丢弃**(丢弃不等于把它们
  标成离线);带了分类筛选而某行不在该分类里 ⇒ 拒绝,而不是挂在这个分类下面。清晰度按**画面身份**分组
  (分辨率/帧率/codec;cdn 主机、签名路径与抖动的带宽都不算身份):同身份的多个地址是一条清晰度的两条线路,带宽只参与排序。
  清单里带外部音频时,master 作为**显式的自动选项**保留,而不是挑一个会丢声音的纯视频变体。详情里负载均衡 origin
  在拼进 url 前过形状检查;流列表匹配本频道必须**恰好一条**。
- `jdlive/` —— `JdliveSource`:所有调用都是 `api.m.jd.com/api?appid=h5-live&functionId=…&body=<json>`,
  `code`/`subCode` 在这个网关里是**文本** `'0'`(按数字比就把能用的答案读成拒绝),目录靠
  `currentCount` 续着走(整趟共用一个 timestamp,要下一页没带 count 就拒绝;count 不动就是到头)。卡片只有
  `liveId` 与 `id` 一致且模板是房间才算卡片。hls 与 flv **必须指向同一路流**(站点自己就是这么要求的),所以它们是
  一个清晰度下的两个容器 / 两条线路,而不是 v1 菜单里的两个清晰度。播之前要读一次主清单:每个子引用都得留在同一
  host、`/live/` 下、并保持这条流的文件名主干。`secret == 1` 是 app-only,resolve 时照实说。**不申报 search**:
  v1 是拿已经翻过的那几页过滤,那等于对平台上其余所有房间报"查无此人"。
- `chzzk/` —— `ChzzkSource`:目录游标是**含端点的**(续页多要一行再丢掉重复的边界行;`next` 块把刚发出去的游标原样
  还回来就是列表到头,而不是可以一直翻),房间是**频道**(`liveId` 一场一个),观众数被 `cvExposure` 挡着时
  就是**没有观众数** —— 0 会是站点选择 withheld 的那个数。能播的清单不在房间答案里:`livePlaybackJson` 是一段
  json **字符串**,里面点名的 akamaized 清单读出来才有变体;别的 mediaId 跳过而不是猜成"大概也是 hls"。
  变体缺 `RESOLUTION` 或 `BANDWIDTH` 就判清单坏了,不给它编一行菜单。同高度的 30fps 与 60fps 是两个选择
  (`{height}p{60}`),而 HLS 与 LLHLS 的同一形状**合成一个选择、两条线路**。`krOnlyViewing` 是站点拒绝本路径
  (resolve 里照实说是区域限制,不写成离线)、`adult` 是匿名会话证明不了的分组、`timeMachineActive` 才是
  "过去可看" ⇒ 只有它落进 `LiveCatchUp`。
- `soop/` —— `SoopSource`:房间是主播 id,答案里的 `BJID` 与所问不合就**拒绝**(播别人的频道不是"大概同一个")。
  在播由 `RESULT` 码说清(1 在播 / 2 没在播 / 3 被封),被封与未播是两条不同的话;`VIEWPRESET` 缺席就是**没有可签的档**,
  不申报清晰度。观众数分 PC 与移动:`total_view_cnt`/`view_cnt`/`VIEW_CNT` 优先,没有合计字段时把两路相加,
  显式的 0 就是 0、什么都没说的是 null。**档位名字就是身份**:`bps` 只在同一档内部排序(原画那一行常常不带码率,
  它仍要坐在转码档之上),表里没名字的外来档按码率排;`auto` 是播放器自己的决定,不作为选项递出去。
  换链是三步:频道 → `broad_stream_assign.html`(`return_type` 按 cdn 家族,`broad_key` 是 `bno-common-<站点原拼写>-hls`
  —— 换成小写就是向它要一个答复里从没点名的档)→ `player_live_api.php` 签 `aid`。`aid` 一次一签,所以 `refresh`
  重签而不是复用可能已经死掉的地址。**没有线路轴**:一个档只有一个地址,申报第二根轴就只会造一个永远填 1 的选择器。
  聊天 socket 的 TLS 端口是站点给的明文端口 **+1**(照原端口连 wss 会卡在握手),没有主机时按 `CHIP` 的十六进制
  重建 `chat-<hex>.sooplive.co.kr`(主机在小写化之后才拼进 url)。接受的 cookie 是操作者自己的会话,用来读匿名路径不交给它的频道;这里不登录,
  被站点挡住的房间照实说,不靠偷渡播出去。
- `twitcasting/` —— `TwitcastingSource`:**在播只由 `movie.live` 说话**。v1 实测过"已下播的答复里仍然带着另一场
  broadcast 的 HLS 地址",所以状态与清晰度都只读 streamserver(页面只负责身份与展示字段),而每个地址都必须点名
  **同一条 broadcast**:`/tc.livehls/v1/streams/<movieId>/hls/<n>.<n>/media.m3u8`,且只在站点自己的 host 上。
  目录是**一个会刷新的 60 行窗口**而不是 offset 接口:翻页是本地切片,过窗就返回空且不发一次请求。四个开关
  (`is_live`/`is_locked`/`is_group`/`is_deleted`)必须是 bool —— 变成 0/1 就是接口改了,宽松读法要么把门禁房全留下,
  要么把在播全丢掉;一行只有在 `live_url` 点名这个 channel 与这个 broadcast 时才是房间。房间页要**恰好一个**
  `twitter:creator`,且 header 的 `data-user-id` 与所问一致。搜索页不报观众数,所以那些房间就是没有数,不是 0。
  频道名是白名单(站点自己的页面词是保留字),movie/archive 链接**不会**被换成"当前那一场" —— 那是另一档节目。
  密码页报成 `private` 并把口令标记写进 extra,不报成下播;一个档一个地址 ⇒ 没有线路轴。

## 钉住的规则

- 线路 id 是**序号不是名字**:huya 的 CDN 行没有名字,给它编 "线路2" 会让"我看第 3 路坏了"在源侧和平台侧指两件不同的事。
- 质量列表答空而不是造假:匿名通道只有一个档,造假 1080p 行是这台传输兑现不了的承诺,而只有一个选项的选择器不如没有。
- 借来的传输不由站点关闭(`_ownsClient`),站点自己 new 的才在 `dispose` 里关。
- 分类树**不完整不缓存**:一次抖动把三组钉死到进程结束,第四组不重启就再也不回来。

## 验证

- 分析:`dart analyze packages/providers/sites`
- 测试:`dart test packages/providers/sites`(451 条,每个站点目录配一份 `test/<site>/`;README 上没列到的
  weibo / inke / kugou / missevan / kuaishou / baidulive 见 CHANGELOG。传输一律用 `pure_live_network`
  的 `testing.dart` 罐头适配器,不联网)
- 架构:`dart run tool/check_architecture.dart --strict`

## 未验证

- **未录到真实响应**:两个包的 `fixtures/` 都空,字段名与状态码来自 v1 维护的站点线和 dart_simple_live 的知识,
  不是本仓库抓的样本。上游改了字段这里会在分析/测试里绿着,只在真机上炸。
- 无登录、无弹幕 socket、无账号画质档(`hint` / `rateArr`)、无超级聊天;TARS token 租约没做。
- 真机播放未测(见 [BUILD_POLICY.md](../../../BUILD_POLICY.md)):票据能构造不等于内核能开播。
