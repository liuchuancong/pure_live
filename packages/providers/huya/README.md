# pure_live_huya

> 职责:虎牙**直播源**适配器 —— 推荐流/分类浏览、搜索、房间状态与 CDN 线路菜单、**匿名 HLS** 取流(AntiCode 重签)。
> 实现 `FeedCapability` / `BrowseCapability` / `SearchCapability` / `ResolveCapability` / `LineCapability` /
> `QualityCapability` / `LiveStatusCapability`;不碰播放器,不碰登录,不碰弹幕协议(见文末)。

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 + L1 契约包;同层禁互依;不得触碰 PlayerAdapter(I1/I5) |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_huya.dart`;内部实现放 `lib/src/` |

## 模块

目录按 [package-architecture.md §2.1](../../../docs/architecture/package-architecture.md) 分,**一个类型一个文件**:

| 目录/文件 | 提供 |
|---|---|
| `src/constant/huya_identity.dart` | `huyaSourceId` + 票据 metadata 三个键 |
| `src/constant/huya_endpoints.dart` | 四个 url、四个顶部分组、UA/请求头、封面缩略参数 |
| `src/api/huya_anti_code.dart` | `buildAntiCode` / `fillAntiCodeTemplate` |
| `src/api/huya_viewer_uid.dart` | `rotateViewerUid32` / `createFallbackViewerUid` |
| `src/api/huya_profile_request_failure.dart` | `HuyaProfileRequestFailure`(profileRoom 拒绝的具名失败) |
| `src/model/huya_stream_entry.dart` | `HuyaStreamEntry`(一条 CDN,含 hls/flv 两套 url + antiCode + 后缀) |
| `src/model/huya_room_profile.dart` | `HuyaRoomProfile`(profileRoom 一次读四问) |
| `src/model/huya_list_row.dart` | `HuyaListRow`(列表行与搜索行统一成一种行) |
| `src/site/huya_source.dart` | `HuyaSource` —— 唯一实现能力接口的类 |

## AntiCode 配方

`fm` 字段是服务端给的 base64 模板,`$0..$3` 四个占位分别是(uid、流名、seqid 哈希、wsTime);填完取 md5 就是
CDN 认的 `wsSecret`。**没有 `fm` 的 antiCode 已经是签好的,原样透传。**

- 模板填充是**一趟从左到右**,每个占位只填第一次出现的位置,且**写进去的内容不再被扫**。逐条
  `replaceFirst` 会先塞流名再去找 `$2` —— 房间名里带 `$2` 时它替的是房间名里那个,真正的占位留空,
  签出来的串没人认识(测试 `neverSignsOverWhatItJustWroteIn` 钉住这条)。
- 四个占位缺任何一个 → `FormatException`(缺一个是**形状变了**,不是"租约短一点")。
- `wsTime` 解析不出来 → `FormatException`;超过 `wsTime + 5min` → `StateError('... lease expired')`,
  也就是"别开这个 url",而不是开出去吃一个 403。
- 发出的 query 里**去掉 `fm`**(站方播放器本地消费它,从不含进 CDN 地址),并重建
  `wsSecret/wsTime/seqid/ctype/ver/fs/t`;其他字段原样保留 —— 服务端加一个新字段不该被白名单抹掉。
- `rotateViewerUid32` 只转 32 位低半区,保留高半区(真游客 uid > 2^32 时截断会 403)。
- `createFallbackViewerUid()` 用 `Random.secure()` 落在 `1.4e12` 那个带内。

## 源行为契约

- **取流优先用服务端的 `sHlsUrl`**。只有在它缺席时才退回 `sFlvUrl.replaceFirst('flv','hls')` —— 那个改写命中的
  是串里**第一个** `flv`,可能在主机名里,也可能在路径段里(测试的 2 号线就是 `.../flv/src`,改写会把路径段换掉)。
  容器后缀只在用了 `sHlsUrl` 时才信 `sHlsUrlSuffix`,否则固定 `m3u8`:用着 flv 的 base 却保留 `.flv` 后缀,
  就是交出一个与票据声明协议不符的地址。
- **线路是序号,不是名字**:`SelectionRef('2')` 取第二条 CDN;解析不出数字、或超出条数 → `StateError`,
  不会"没匹配上就回第一条" —— 静默换 CDN 会把"这条线坏了"变成"每条线都坏"。
  选中的线路与总条数写进票据 `extra`(`huyaLineKey` / `huyaLineCountKey`),**`refresh` 沿用同一条线**
  (在三号线上换链却回到号线一是另一类欺骗)。
- `quality` 只记录不生效(`huya.requestedQuality`):这一片只有匿名流,清晰度上限在服务端;把用户的选择静默
  丢掉是最难查的那种"设置没生效"。
- 列表解析**不对任何字段做硬 cast**:`gid` 历史上出过 map / double / int / string 四种形状,`_gid` 收敛成一种;
  行不是 Map 就跳过(一行怪数据不该让整页失败)。
- `datas` **缺失**是坏答案(`FormatException`),`datas: []` 是合法的末页;`totalPage` 缺席时 `hasMore` 给
  false —— 声称"还有"会让翻页器一直翻下去。
- 分类树:四个大组各 `1/2/8/3`,**某组失败只丢那一组**(`on Object`,不只是 `FormatException`:一个断掉的 socket
  或非 JSON 体就是一组挂掉的常态),并且**只有完整树才进缓存** —— 缓存半棵树等于把缺的那组钉到进程结束。
- `lines(ref)` 把 CDN 列表报成 **1 基序号的 `StreamOption`**:`label` 留 null(虎牙的 CDN 行根本没有名字),
  `isDefault` 给第一条(= 不选线时 resolve 会拿到的那条),`available` 跟 `isUsable` 一致。平台不替源编"线路2"。
- `qualities(ref)` **答空**:匿名路径只有一个码率,账户清晰度菜单(`hint`/`rateArr`)是后面的切片。
  答空而不是造一个 1080p 行 —— 单个选项的选择器比没有选择器更糟,而假的选项是一个兑现不了的承诺。
- `liveStatus(ref)`:`liveStatus==1` → live,`0` → ended,**字段缺失 → unknown**(不是 ended)。
  关注列表把 unknown 读成"下播",就会静默停止看一个正在直播的台。
- `dispose()` **只关自己造的 client**:传进来的传输属于组合根,源关掉它会带走别的消费者的连接。
- `status != 200` 抛 `StateError` 并带上站点的 `message`(房间不存在与房间没开播是两回事)。
- 票据头带 `referer/origin`(缺了拿不到流),`createdAt` 走注入的 `Clock`。
- 封面没带 query 时才追加 OSS 缩略图参数(已有的不重复加)。

## 依赖

`crypto`(md5)、`pure_live_network`、`pure_live_platform`、`pure_live_capability`、`pure_live_utils`(`Clock`)。
dev 依赖 `dio`:传输替身要实现 `HttpClientAdapter`,而 `pure_live_network` 把它当注入参数收下却不再导出。

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / Windows / iOS / macOS / Linux | ✅ | 纯 Dart + `dart:convert` |
| Web | ⚠️ 代码可编译,**未验证** | 不碰 `dart:io`;障碍是浏览器同源策略会拦 `mp.huya.com` / `search.cdn.huya.com` |

## 验证

- `dart analyze` → No issues found。
- `dart test` → **36 passed**(`huya_signing_test` 13 条 + `huya_source_test` 23 条),后者跑在按
  `host+path` 脚本化的 `HttpClientAdapter` 替身上,零网络。
- 签名的固定向量是**先由本实现算出一次再写成字面量**的回归钉(置换、剔除字段、哈希输入),不是站方 oracle。
  查询按**解析后的参数表**比较,不比字符串顺序 —— 线序不是签名依赖,拿它当断言只会制造脆测试。

## 未验证

- **零消费者**,且**没有一个字节真从虎牙取回来**:端点、字段名、`fm` 模板形状、`wsTime` 的 5 分钟租约都来自
  协议笔记与 v1 那条线;fixture 是手写的。
- `sHlsUrl` 与 `sFlvUrl` 在不同 CDN 上到底差多少主机名:测试里那条"只有 flv base"的 2 号线是**编的**,
  真机上是否还需要 `/hls` 之类的路径段未验证(这也是本文件不再猜路径、优先信服务端字段的原因)。
- 分类树 4 个 bussType 的稳定性、`totalPage` 在末页是否真的等于 `page`、搜索 `typ=-5` 的语义:同样待真数据。
- 登录态、TARS token 租约、真清晰度选择、弹幕协议、主播搜索(`AnchorSearchCapability`):**没有实现**,不是"实现了没测"。
  弹幕与主播搜索要的是新的端点与协议知识(huya 的 danmaku 走 wup/ws 双址),按 §2.1 的形状等第一个消费者出现时补;这里不实现也不申报对应能力。
