# 果映 TV（hongguoTV）参考盘点 × `apps/pure_live/lib/modules/hongguo` 同步审查

> 盘点对象：`C:\Users\XA-158\Downloads\hongguoTV`（只读，GPL-3.0-only，非官方红果短剧客户端）与工作区 `D:\flutter\pure_live`。
> 判定标准：入口/文件/provider 存在 **不算** 同步完成；必须读到真实状态、回调、消费点和错误分支。
> 本文是代码级复核，**没有运行期目视**：未构建、未启动、未对照手机红果核对任何接口返回。
> 盘点日期：2026-10-28。参考基线：`main`，TV `0.1.11 / versionCode 52`（`kotlin-tv/app/build.gradle.kts:24-25`），工作区另含未发布的更名与三栏搜索改动。
> 目标基线：分支 `v2`，提交 `291d67c97`。`hongguo/` 磁盘上 23 个文件、约 9000 行，但 **HEAD 只有 20 个**：`controller/hongguo_social.dart`、`official/hongguo_comments.dart`、`official/hongguo_related.dart` 尚未入库（HEAD 里的系列页也不引用它们，所以 HEAD 自洽，但这条评论/弹幕/相关作品链路目前只活在工作区）。`pages/hongguo_series_page.dart` 与 `official/hongguo_web_login.dart` 另有未提交的并行改动（相关作品/评论区、手机号登录），本轮未触碰。模块已在 `app_module`/`navigation_item`/`module_navigation`/`route_names`/`settings_sections` 注册（见第 6 节）。

---

## 0. 参考项目里有三个界面，只有一个是现行的

| 目录 | 是什么 | 状态 |
|---|---|---|
| `kotlin-tv/` | **Kotlin + Android View + Media3 原生 TV 客户端**，无服务器依赖 | **现行、唯一要抄的对象**：README `:5` 「Android TV 使用 `kotlin-tv/` 中的 Kotlin 原生客户端」 |
| `desktop-mac/` | SwiftUI Mac 客户端 + Kotlin 后端（评论签名复用 core） | 已验证并入库，长期分支 `feature-mac-client`（README `:178`） |
| `src/` + `server/` + `android/` + `ios/` | 旧 React Native TV + Node 陪伴服务 | **保留但不依赖**：README `:188` 「当前原生 APK 不依赖它们」；`docs/API.md` 顶部也声明只服务旧实现 |

`kotlin-tv` 是两个 Gradle 模块：`:core`（46 个网络/加密/片单文件，无 Android 依赖）+ `:app`（32 个 UI/播放文件，`MainActivity.kt` 单文件 4230 行）。

**结论：迁移只应对照 `kotlin-tv/`；RN 与 Node 服务不是参考，`server/vendor/hongguo.cjs` 只是签名常量的来源之一。**

---

## 1. 参考的功能面

### 1.1 找剧与发现

- **首页是竖屏试播流，不是海报页**：推荐 / 漫剧 / 真人剧三类入口，上下换剧、换一批、观看全集、账户收藏；试播播的是**该作品第一集**（`HomeFeedScreen.kt`，README `:37`）。
- 首页「观看全集」进详情后按**本机与当前账号中较新的一条**记录续播（同时间优先本机）；云端分集 ID 与官网列表不一致时用有效云端集号定位（README `:38`、`docs/ACCOUNT_SYNC.md`）。
- 按登录身份隔离的 **10 分钟首屏元数据缓存**（每来源 ≤30 部，不落盘播放 URL/会话/凭据）+ 相邻作品预加载接续（`FeedStartupCache.kt:15-24`）。
- **找剧**：全部/真人剧/漫剧/AI 剧 + 服务端下发的主题/设定/背景/推荐排序/受众/上新时间/(漫剧)作品状态，**多组组合筛选**（不是本地过滤）；组内左右、组间上下、重置、收起/展开；进列表保持展开、详情返回保留条件与位置（`DiscoveryScreen.kt`）。
- **搜索**：遥控器三栏工作区（左 A–Z/0–9 键盘、中联想词+最近 8 条历史、右结果），输入停顿 350ms 打服务端联想；另有单行搜索条 + 手机局域网扫码输入（`TvSearchPanel.kt`、`SearchSuggestionsView.kt`）。
- **排行榜**：综合/真人剧/漫剧/AI 剧四榜，各读满 5 页 100 部、榜内题材筛选**保留原榜名次**、四榜并行 + 会话内 10 分钟 TTL + 过期静默后台续期、点刷新才强制重拉（`RankingScreen.kt`、`RankBrowser.kt:44-83`）。
- **连续分页**：分类按 offset+会话游标、搜索按页码，接近底部自动加载、去重追加、瞬时错误自动重试一次、失败保留列表并可手动重试（`ContinuousCatalogView.kt`）。
- **详情**：简介/完整简介、选集列表、集数分组、跳转集数；**相关作品**支持前后季浏览与下一季预约（`RelatedWorksView.kt`）。

### 1.2 追剧与账号

- 本机收藏、观看历史、断点续播、整剧已看标记；**本机收藏可检查新增集数**（1 小时/部节流，连错 3 次中止），长按管理单条记录（`FavoriteMonitor.kt`、`Library.kt:180-183`）。
- 红果**扫码登录**（手机号+验证码路径保留但受平台滑块验证阻断）；账户收藏读/增/删、账户历史（最近 50 部）与云端进度上传。
- 收藏与历史各分「本机 / 账户」子页签，来源选择被记住（`LibrarySources.kt:8-19`）。
- 账户预约分「已上线 / 待上线」，各读最近 20 部；**预约提交被接受 ≠ 账号列表已确认**，只有回读出现该季才显示「已预约」（`docs/ACCOUNT_SYNC.md:236-242`、`RELATED_WORKS.md`）。
- 退出/切换账号清云端列表、不清本机历史。

### 1.3 播放与遥控器

- 遥控器键位：← → 快退/快进（10s，连按 >4 次变 30s）、确认 播放/暂停、**↓ 选集**、**↑/菜单 更多**、返回先收控制层再退出（`MainActivity.kt:4020-4083`）。
- 「更多」面板六项：倍速 / 清晰度 / 画面 / 定时 / 从头播放 / **重置设备能力记录**（`MainActivity.kt:3733-3742`）。
- 清晰度 480/720/1080（`Watching.kt:7`）、倍速 0.75/1/1.25/1.5/1.75/2（`PlaybackSpeed.kt:5-9`）、画面 完整/等比铺满/拉伸（`PlaybackComfort.kt:4-8`）、定时 关闭/15/30/60/90 分钟/本集播完/再播完 3 集/5 集（`MainActivity.kt:3636-3653`）；均全局记忆。
- **按盒子解码能力自动选流 + 运行时学习降档**：启动探测 AVC/HEVC 上限，播放前用 MP4 头实际编码尺寸复核，虚报能力导致的失败按「编码+尺寸」持久化（`native-decoder-lessons-v1/failures`），当场自动降档（每集 ≤2 次），HUD 显示「自动降清」（`CodecCapabilities.kt`、`DecoderLessons.kt`、`MainActivity.kt:3425-3452`）。
- **音画漂移自动重同步**：平均帧偏移 ≥150ms 持续则无感重定位，冷却 30s（`PlaybackSyncGuard.kt`）。
- 播放失败：≤3 次自动重试（1s/2.5s/5s）、手动重试、切低清晰度、断网等待联网恢复并保留位置；错误文案区分空响应/HTTP/超时/分段中断（`Watching.kt:13-32`、`PlaybackSources.kt:15-41`）。
- 首页与正式播放共用**经平台注册的匿名播放设备身份**（`DeviceRegister.kt` + `PlaybackDeviceSession.kt`，仅内存、不轮换）；空播放信息最多读 3 次（间隔 700/1500ms），正式播放顺带取后两集模型（≤6 条、60s 过期）；下一集先读 32KiB 再按实际索引补齐、入同一播放器队列（`kotlin-tv/README.md` 「正式播放与下一集」）。
- **应用内检查/下载/校验/交系统安装**，前台空闲时轮询、播放中打断（`AppUpdater.kt`）。

### 1.4 评论与弹幕（只读）

- 详情页与正式播放页均可开本集评论：连续加载、游标续读、去重、手动加载更多、失败重试、到底自动续读、追加保持阅读位置（`TvSocial.kt:228-416`）。
- 常见表情用**随包 webp 图片**替代表情符号，兼容旧电视字库；未识别标签保留原文（`CommentEmoji.kt:17-47`）。
- **真实时间轴弹幕**：原生 Canvas 逐帧绘制，默认 2 行 / 24dp / 慢速；开关、字号(24→28→32→20)、密度(1–4 行)、速度存 `social` prefs；暂停冻结、拖动按目标时间段读取（`TvSocial.kt:29`、`:443-460`）。
- 整剧剧评仍是官网公开节选；**没有发送/回复/点赞**；首页首集试播未接入评论与弹幕（`SOCIAL.md`）。

### 1.5 账号与本机数据的同步边界（易被误判为已完成）

`docs/ACCOUNT_SYNC.md` 反复标注：账户收藏分页契约、云端逐秒双向续播、新增预约的跨设备效果、扫码手机号登录 **均未经真实账号验收**。抄功能时不要把「接口调通」写成「同步已验收」。

---

## 2. 参考的 UI 面

### 2.1 设计令牌（`TvStyle.kt:12-26`）

背景 `rgb(11,15,21)`、面板 `rgb(23,30,40)`、抬起 `rgb(32,42,54)`、强调 `rgb(255,137,100)`、正文 `rgb(243,244,246)`、次要 `rgb(147,160,178)`、描边 `rgb(43,55,70)`；海报宽高比 `0.7`；卡片圆角 10dp + 2dp 边框；焦点=面板色→抬起色 + 透明→强调色边框；**明确不用模糊、位图背景和焦点动画**。

### 2.2 顶栏（`MainActivity.kt:812-842`）

品牌图标 + 「果映 TV」（22f，`widthDp()<800` 时 17f）+ 七个入口，顺序即 tab 序号：
`首页 · 找剧 · 排行榜 · 收藏 · 观看历史 · 账户预约 · 设置`（`:823`）。导航字号 15f（`<1000` 时 13f）；焦点=白底+背景色字，选中=深橘底 `rgb(48,32,29)`+强调色+粗体。

### 2.3 逐屏要点（细节见代理盘点原文，此处只留会影响观感的决定）

| 屏 | 版式与交互上不能丢的东西 |
|---|---|
| 首页 `HomeFeedScreen.kt` | 48dp 类型条（推荐/漫剧/真人剧/换一批，各 weight=1）+ **舞台 weight 2.2 : 信息列 weight 1**；画面按比例显示**不裁竖屏**；左上角半透明标签、底部半透明状态条；信息列固定字号层级 25f 标题 / 13f 强调色 meta / 15f 简介，全部定 `maxLines` 以免换剧时回流；底部按键提示 `↑ ↓ 换一部 / 确定 打开操作 / 返回 顶部导航`；舞台四向焦点锁死自身，上下由代码换剧 |
| 找剧 `DiscoveryScreen.kt` | 类型 chips 行 + `收起筛选/重置/刷新`；筛选区高度 = `min(260dp, 视口 48%)`，非类型组带 40dp 名称列与小一号 chips；**6 列**海报网格；浏览时头部按 `row/6` 步长自动收起，焦点离开列表即复位 |
| 通用海报网格 `ContinuousCatalogView.kt` | 6 列（搜索面板按宽度 2/3/4）；卡片=海报 + `第 N 名` 左上角标（前三名强调色）+ 徽标行（热度优先于 badge）+ 2 行标题；**整卡单焦点**；`fitHeight()` 逐级降级（2 行→1 行→隐藏徽标→缩小海报，地板 32dp）；底部状态文案 5 种 + `加载更多`/`回到顶部` |
| 排行榜 `RankingScreen.kt` | 25f 榜名 + 提示 `方向键选剧 · 确定看详情 · 长按更多`；榜按钮固定 92dp、副标题带来源与「正在后台更新…」、`筛选题材`四列网格、`刷新`；筛选后仍标原榜名次 |
| 三栏搜索 `TvSearchPanel.kt` | 左栏固定 230dp（窄屏 190dp）、键盘 6 列 34dp 键 + 3 列动作键（删除/清空/搜索/中文输入/手机输入/返回分类）；中栏 160dp 联想词 + 最近 8 条；右栏结果；**默认屏蔽系统输入法**，只有「中文输入」打开 |
| 详情（在 `MainActivity` 内） | `开始观看/继续第 N 集/重新观看`、`评论 · 第 N 集`、账户收藏、本机收藏、`完整简介/收起简介`；选集 20 个一组 + `跳转集数` 数字键盘；图例 `橙色为当前集 · 上次为续播位置`；相关作品=水平条，142dp 卡 / 176dp 海报 |
| 选集面板 `EpisodePanel.kt` | 右侧无边框 Dialog（宽 `min(520dp,80%)`、高 90%）、5 列 × 20 一组、焦点格=强调色、当前格=`rgb(61,39,34)`、格内后缀 ` · 当前/ · 已看/ · 上次` |
| 播放 HUD `MainActivity.kt:2820-2867` | 底部渐变 + 标题 `剧名 · 第 N 集` + 状态行（`正在播放 · mm:ss / mm:ss · 1080P · 1.5×  · 定时 30 分钟后`）+ 进度条 + 固定帮助行；播放中 4500ms 自动隐藏 |
| 评论/弹幕面板 `TvSocial.kt` | 侧边停靠（END、`dimAmount 0`）不遮画面；评论行 `作者 · 赞 N · 日期` + 20f 正文 + 6dp 行距；整卡聚焦，点开全文再返回原焦点 |
| 收藏/历史/预约 | 标题 + 条件按钮（`检查更新`/`管理本机记录`/`刷新收藏|历史|预约`/`账号管理`）+ 本机/账户子页签 + 来源说明行；卡片徽标行是**两行**「总集数(新增 N) / 看到第 M 集」 |
| 设置 | 头部 `按你的习惯播放`，两张卡并排：左「播放偏好」4 行 + 「红果账户」1 行，右「应用与更新」3 行；**没有**弹幕默认值、内容分类、缓存清理、备份恢复入口（`MainActivity.kt:2149-2261`） |

### 2.4 焦点/返回的硬规则

- BACK 阶梯：`首页收操作栏 → 搜索面板回分类 → 找剧回顶并聚焦「找剧」→ 播放收 HUD/回详情 → 详情出 detailTrail(≤10) → 列表聚焦顶栏 → 退出`（`MainActivity.kt:3972-4015`）。
- 每屏都手写了 `nextFocusUp/Down/Left/RightId`（顶栏向下随屏别重定向），Flutter 侧要有等价的显式焦点图。
- 断点会改变**焦点拓扑**而非只是尺寸：`widthDp()<800/1000/1200`、`fontScale<=1.2` 时类型按钮并入顶栏（`MainActivity.kt:699-700`）。

---

## 3. 参考的网络面（抄的时候按这张表逐条对齐）

三套域名，签名规则不同：

1. **官网** `hongguoduanju.com`（无签名，读 `_ROUTER_DATA`/`data-fn-*`）：`/rank/hot-{drama|real-drama|comic-drama|ai-drama}?page=`（**必须读满 5 页**，>5 页直接报错）、`/category?tab=1&sort_type=1`、`/category/{real-drama|comic-drama|ai-drama}/{topic}?page=`、`/incent_resource/suggestion`（联想词，`app_id=8662`、`count=8`）、`/api/search/result`、`/detail?series_id=`、`/player/{series}/{episode}`+`/detail`（公开剧评与评分）——`ContentRepository.kt:312-463,630-645`、`PublicComments.kt`。
2. **App 域名** `api5-normal-sinfonline{a,b,c,hl,lf}.fqnovel.com`（gorgon/argus/ladon/helios/medusa 签名）：landpage 分类筛选（版本覆盖 `73532/7.3.5.32`）、`bookmall/tab/v1`（推荐流，`tab_type=16,bottom_tab_type=7`）、`bookapi/plan/v`（相关作品 `scene=10`）、`novel/player/multi_video_model/v1`（播放模型，**只带注册设备身份、不带签名头**）、`bookapi/search/tab/v`（`tab_type=11` 短剧 / `19` 漫剧）、书架读/写、历史列表 + `multi-detail` 补集数、预约列表/写入（**gzip**）、进度上传、`novel/commentapi/comment/list/{episode}/v1`（评论+弹幕，独立签名体系）——`ContentRepository.kt:465-836`、`CloudAccount.kt`、`RecommendationFeed.kt`、`AppCommentPages.kt`、`TimedComments.kt`。
3. **其它**：`log5-applog-lf.fqnovel.com/service/2/device_register/`（ttEncrypt+gzip，匿名设备注册）；`is.snssdk.com/passport/mobile/*`（手机验证码登录四段链路，含滑块拒绝）；`hongguoduanju.com/passport/web/{get_qrcode,check_qrconnect,send_code,sms_login}` + `/passport/account/info/v2`（扫码登录）；`api.gitcode.com`+`file-cdn.gitcode.com`（更新清单，sha256 + 主机白名单 + ≤80MiB）；视频 CDN Range 读（`Referer: novel.snssdk.com`、`Accept-Encoding: identity`、256KiB 探测 + moov 补齐 + `warm()`+`trackInfo()`）。

---

## 4. 参考里的死代码 —— **不要迁**

审计时发现这些在参考当前分支已不可达，照着抄会凭空造入口：

- **`HomeScreen` 的整片「货架首页」**（`接着看 / 收藏有更新 / 稍后看 / 热门发现 · X` + `更多热门 ›` + `‹ 返回首页` 的 collection 覆盖层）：`showCatalog()` 在 `tab == 0` 于 `MainActivity.kt:878` 就 return，`renderHome()`（`:1876`）与 `showCollection()`（`:690`）**没有活调用者**。已核实。
- `tab == 0` 的第二个分支（`:909` 的「片库」类型按钮行 + `长按确认 · 管理片单`）同样被上面的 return 遮蔽。
- `Library.toggleLater / hide / unhideAll`、「稍后看」入口、**手机备份恢复页**（`TvTools.libraryTransfer`，`:423-519`）在 `app/` 内**无调用点**——README `:27` 也承认「当前设置页没有接入入口」。
- 语音搜索已整体移除（`SEARCH_INPUT.md`）。

---

## 5. 目标模块现状（`apps/pure_live/lib/modules/hongguo`）

分层：`official/`（11 文件，直连官方协议：签名、设备注册、媒体解密、本地代理、评论、账号、相关、扫码登录、home feed、vendor 常量）→ `controller/`（7 文件，Riverpod Notifier 状态）→ `pages/`（入口页、系列页+播放器、设置面板）→ `widgets/`。`hongguo.dart` 平铺导出。

已经**真实接通**的部分（逐行读过）：

- 找剧走 App landpage 的 `select_items` 组合筛选，游标(offset/session/page)分页，服务端分组渲染成 `HongguoFilterRowView` 的「全部 + 选项」chips 行（`hongguo_official.dart:391-502`、`hongguo_feeds.dart:33-126`）。
- 排行榜四榜 + 搜索页优先、官网页兜底（`hongguo_official.dart:260-282`、`hongguo_feeds.dart:218-354`）。
- 扫码登录（QR 取码+轮询+redirect 链+存凭据）、账户收藏读/写、账户历史、预约两类、云端进度上传（`hongguo_web_login.dart`、`hongguo_account.dart:198-485`、`hongguo_account_state.dart`）。
- 播放链路：注册设备身份 → 播放模型 → 内嵌 `video_meta/encrypt_info` 解密 → 本地解密代理 loopback → `media_core` 播放；选档规则「≤ 请求档 且优先 h264」（`hongguo_client.dart:37-51`、`hongguo_proxy.dart`）。
- 系列页：详情+选集 chips、自动连播、进度保存(5s 节流)与上传、相关作品与预约、本集评论分页、全屏/PIP 呈现、明暗/音量/倍速(0.5–2)、硬件解码与超分等引擎项跟随全局设置。
- 本机收藏(≤500)/历史(≤200)+删除+清空、`hongguoSettingsProvider` 清晰度、`resetDevice`。
- 8 个 `NavigationItem` 入口、`/hongguo/series/:seriesId` 路由、设置 `SettingsSection.hongguo`、中英双份 l10n（136 个 key）。

---

## 6. 差距与同步清单

### P0 · 正确性缺陷（协议层写错，功能看着在但会失败）

| # | 位置 | 问题 | 参考 |
|---|---|---|---|
| 1 | `official/hongguo_vendor.dart:55` | **AesV3 s-box 被抄短**：目标 base64 **1352** 字符，参考与 `server/vendor/hongguo.cjs` 均为 **1368**（缺 12 字节），且从第 421 位起逐字符错位。它喂 `hongguo_signer.dart:84` 的签名 → 所有签名请求的 `x-gorgon/x-medusa` 都可能被判非法。文件头注释却写「exactly as the reference ships them」 | `VendorConstants.kt:39-41`（实测长度 1368） |
| 2 | `official/hongguo_vendor.dart:121` | hashTable 有一项错：`0x0284ba07`；参考是 `0x284ba7`(=`0x00284ba7`)。逐项比对后 **64 项里仅此 1 项真不同**（另 3 项是前导零，等价） | `VendorConstants.kt:106` |
| 3 | `official/hongguo_official.dart:751` | 播放兜底接口的 `key_seed` 按 **hex** 解（`_hexBytes`）；参考按 **Base64** 解后送同一套 CBC-KDF。凡是走 `fallback_api` 且带 seed 的分集，解出的密钥是垃圾 | `ContentRepository.kt:821` + `Bytes.kt:22-26` |
| 4 | `official/hongguo_related.dart:136` | 预约写请求头带 `Content-Encoding: gzip`，但 body 是 `utf8.encode(jsonEncode(...))` **未压缩** → 服务器收到「声明 gzip 的明文」。目标自己在 `hongguo_account.dart:167` 有 `gzipBody` 正解，但**没有任何调用点用它** | `CloudAccount.kt:300` + `:124-130` |
| 5 | `official/hongguo_official.dart:521` | `tab_type` 写死 `'11'`（短剧）；参考按内容类型取 `11 / 19`。**漫剧的应用内搜索永远走不到**，只会被兜底到不限类型的官网搜索 | `ContentType.kt:5-6`、`ContentRepository.kt:481` |
| 6 | `official/hongguo_account.dart:146`、`hongguo_home_feed.dart:21` | 签名器用 `HongguoSigner()` 默认厂商身份（`device_id 1905892595378490` / `version_name 7.1.3.32`），而 query 里塞的是登录设备 + `7.3.9.32`：`_device['device_id']`/`version_name` 正是 medusa 的 field 4/5/14（`hongguo_signer.dart:435,516,542`）→ **头与 query 身份、版本自相矛盾** | `CloudAccount.kt:132-133`（`Signer(device = device)`）、`RecommendationFeed.kt:154,168` |
| 7 | `official/hongguo_official.dart:156-171` | Cookie jar 是 host→name 平面 map，**不做过期、不按 name+domain+path 覆盖**；参考显式过滤过期 cookie 并按三元组替换。预约/榜单会话 cookie 语义因此不同 | `ContentRepository.kt:21-43` |
| 8 | `official/hongguo_proxy.dart:16,92` | 分片上限 2MiB，播放器的更大 Range 会拿到**被静默截断的 206**；参考校验 `begin/finish/total` 稳定并允许 8MiB/请求 | `RemoteVideo.kt:55-57` |

> P0 第 1/2/3 项属于「一次性抄错」型，修法是逐字符从 `kotlin-tv/core/VendorConstants.kt` 复核，而不是重写；第 4–6 项是设计时漏了参数化。全部需要真实账号/网络验收才算闭合，本地无法自证。

### P1 · 参考有、目标完全没有的功能

1. **搜索联想词**：参考 `/incent_resource/suggestion`（350ms 防抖、≤8 条、失败不阻断直接搜）。目标 `grep suggestion` = 0 命中；UI 也没有联想列。
2. **排行榜完整快照**：参考读满 5 页/100 部、跨页校验、保留原榜名次 + 热度/评分/收藏/点赞 + `updatedText`，四榜并行 + 10 分钟 TTL + 静默续期。目标 `websiteRank(page)` 一次一页、名次/热度只取一个 `rank` 字段，无 TTL、无后台续期、无「保留原榜名次」语义（`hongguo_official.dart:260-282`）。
3. **首页试播流**（参考的 `首页` 本体）：目标 `HongguoView.home` 是**海报 CardGrid + 三个 genre chip**（`hongguo_page.dart:192-254`），既不是视频舞台、也没有上下换剧/换一批/观看全集操作栏。另外参考 `first_vid`/`video_list[vid_index==1]` 的首集提示目标完全没解析（`grep first_vid` = 0）。
4. **收藏更新检测**：参考 `FavoriteMonitor`（1h 节流、串行、连错 3 次中止、`新增 N 集 · 更新至 M 集` 标签、首页徽标）。目标 library 只存 `episodeCount`，无检查、无标签。
5. **定时停止**（关闭/15/30/60/90 分钟/本集播完/再播完 3·5 集）与 **画面模式** 三项：目标播放条只有 播放/静音/音量/下一集/倍速/全屏（`hongguo_series_page.dart:791-851`）。
6. **解码能力探测 + 学习降档 + 重置能力记录**：目标只有静态 `maxHeight` 选档（`hongguo_client.dart:37`）。注意：`重置设备能力记录` 在目标设置面板里被做成了 `resetDevice`（清匿名设备身份），**与参考同名条目不是同一件事**（参考是 `CodecCapabilities.resetLearned()`）。
7. **播放失败恢复预算**：参考 ≤3 次自动重试(1s/2.5s/5s)、断网等待联网、失败面板四按钮。目标播放失败只显示一条 `_error` 文本 + 一次 `retry`。
8. **批量取后两集播放模型 + 预加载接续**（`metadataAhead` 在目标 0 命中）、**按登录身份隔离的首屏缓存**、相邻作品预加载 —— 目标 `playbackLadder` 一次一 vid。
9. **手机局域网扫码输入**（含私有 IPv4 枚举、口令、来源校验）—— 目标 0。
10. **弹幕渲染层**：目标数据链在（`hongguo_social.dart:91-170` 会 start/轮询），但 `hongguoDanmakuProvider` 的消费者**只有 series page 的 `stop()`**，没有任何 CustomPaint/overlay —— 弹幕取到却不画；也没有弹幕设置面板（开关/字号/密度/速度）。同理 `CommentEmoji` 替代表情图也没有。
11. **手机号+验证码登录**（`passport/mobile` 四段链路 + 滑块拒绝文案）：目标 `grep passport/mobile` = 0；扫码之外没有第二条登录路。
12. **官网公开剧评/评分**（`PublicComments`）与**评论游标校验**（session_id/offset 结构、必须前进、行内 `expand.book_id` 绑定）：目标游标只做了长度检查。
13. **整剧已看标记 / 单条记录管理 / 管理本机记录 / 清空历史确认**：目标历史行只有一颗删除按钮（`hongguo_page.dart:896-903`）。
14. **预约的多集补号**（缺 total 时批量 `multi-detail` 补 `drama_chapter_number`）：目标 `multi-detail` 只用于历史。
15. **应用内更新**：目标 0（`grep gitcode` = 0）。是否要迁是产品决定，见 P3。
16. **重试预算差异**：参考空播放信息读 3 次(700/1500ms)，目标 1 次 700ms（`hongguo_official.dart:628-641`）；参考榜单用收紧的独立超时客户端，目标共用 30s。

### P2 · UI/信息架构分叉（功能在，观感与手感不是那回事）

1. **首页语义**：参考首页=竖屏试播播放器（画面 2.2 : 信息 1）。目标=海报网格。这条决定了 1.1/3 的其余差异，需要你先定：**TV 语义照搬**，还是按 pure_live 的「非直播模块公共子集」保留网格（记忆里已裁决过：直播不动、非直播用公共子集，且不臆造入口）。
2. **卡片徽标行**：参考收藏/预约卡是**两行**（总集数(新增) / 看到第 N 集 / 近50条无记录），目标 `hongguoSeriesSubtitle` 是「集数 · 热度 · 分类」一行，历史行才带时间。参考明确的 `共 N 集（+M）`、`总集数待更新`、`待上线/暂不可观看` 等标签全缺（`EpisodeSummary.kt:14-36`）。
3. **筛选面板**：参考有 `收起/展开筛选`、`重置`、`刷新`、当前条件摘要、滚动自动收起、返回保留条件+滚动位。目标把分组常驻展开（`hongguo_page.dart:308-313`），只有「点亮的再点一次=清除」，没有重置/收起/摘要。
4. **搜索**：参考两套（单行条 + 三栏遥控器面板）+ 历史弹窗(≤20) + 手机输入。目标一个输入框 + 一个按钮（`hongguo_page.dart:765-802`），无历史、无联想。
5. **网格降级策略**：参考 `fitHeight()` 有 2行→1行→隐藏徽标→缩海报 的地板；目标固定 `aspectRatio: 0.62`（≈ 参考 `0.7` 但不同），窄屏/大字号时不会重排 —— 参考的 `widthDp()`/`fontScale` 断点会**改变焦点拓扑**，目标只改列数。
6. **选集**：参考详情选集是 20 个一组 + `跳转集数` 数字键盘 + `当前/上次/已看` 三色标记；目标是一次铺开的编号 chips（1000+ 集时会是长列表），无跳转、无已看标记。
7. **播放 HUD**：参考状态行带 `清晰度 · 倍速 · 定时` 且 4500ms 自动隐藏、有固定按键帮助行；目标常显、无清晰度/定时显示。
8. **评论**：参考是侧边不遮挡面板 + `本集评论/整剧剧评` 双 tab + 到底自动续读 + 表情图；目标是系列页底部一段卡片列表，只有 `加载更多`。
9. **设置**：参考 8 行两卡；目标 2 行（清晰度、重置设备）。缺 倍速/画面/自动连播 的**模块内**入口（这些在 pure_live 是全局 `playbackSettingsProvider`，属可接受折衷，但需明确记为「由全局承担」而不是遗漏）。
10. **文案**：参考每个空/错/加载态都有专属中文话术（约 120 条，见 §2.3 与代理盘点原文）；目标大量复用 `t.common.empty` 与通用 `loadFailed`，错误只显示原始字符串。

### P3 · 建议明确「不迁」，并写进文档免得下轮又被当成缺口

`HomeScreen` 货架首页与 collection 覆盖层（参考死代码）；稍后看；手机备份/片单传输服务；`LibraryTransferServer`/`Probe` 开发工具；React Native + Node 陪伴服务；Mac 客户端；应用内 GitCode 更新（pure_live 有自己的分发方式，除非你要求）。

---

## 7. 建议的同步顺序（粗粒度）

1. 先修 P0 八条（协议正确性），其中 1/2 逐字符复核常量表，3 换 Base64，4 改走已有 `gzipBody`，5 参数化 `tab_type`，6 让签名器接收与 query 同一份 device，7 补 cookie 语义，8 放开 Range 上限。
2. 弹幕渲染层 + 弹幕设置（数据已在，纯消费端）；评论表情图替换。
3. 搜索联想 + 搜索历史 + 排行榜快照/TTL。
4. 收藏更新检测 + 两行集数标签 + 本机记录管理。
5. 播放侧：定时停止、画面模式、失败恢复预算、后两集模型预取。
6. 首页形态决策（TV 试播流 vs 网格子集）后再动首页；同时补 `first_vid` 首集提示。
7. 空/错/加载态文案全量化 + 设置页补齐全局/模块归属表。
8. P3 写进本文件末尾作为已裁决项。

---

## 8. 本轮（2026-10-28）已落实

### 8.1 P0 协议正确性：9 条全部改完

| 改动 | 位置 |
|---|---|
| s-box 逐字符按参考重写（1352→1368 字符，解码 1024 字节，与 `VendorConstants.kt` 比对为等值） | `official/hongguo_vendor.dart` |
| hashTable 错项 `0x0284ba07`→`0x00284ba7`；改后 64 项与参考逐项等值 | 同上 |
| `key_seed` 改走 `HongguoVendor.decode64`（Base64），删掉误导的 `_hexBytes` | `official/hongguo_official.dart` |
| 预约写请求真的 gzip，并对**压缩后**的字节签名（与参考 `CloudAccount.kt:124-133` 一致） | `official/hongguo_related.dart` |
| `appSearch` 按 shelf 取 `tab_type 11/19`，控制器与搜索页把类型带到请求上 | `hongguo_official.dart`、`controller/hongguo_feeds.dart`、`pages/hongguo_page.dart` |
| 账号与首页 feed 的签名器改用它要发出去的那份 device（头与 query 同一身份） | `hongguo_account.dart`、`hongguo_home_feed.dart` |
| cookie 带 `Max-Age`/`Expires` 语义，过期即摘除 | `hongguo_official.dart` |
| 代理分段响应校验 CDN 回显的 begin/finish 与字节数；单响应上限按参考放到 8 MiB | `hongguo_proxy.dart` |
| 播放模型空响应改回「最多三次读取，700/1500ms，只换 ticket」 | `hongguo_official.dart` |

> 这些都还需要真实网络/账号验收；本轮只做到 `dart analyze lib/modules/hongguo` 0 issues。

### 8.2 首页改成货架式（按红果桌面端 + 手机端参考，用本模块自己的组件）

`pages/hongguo_page.dart` 的 `_HomeView` 从「genre chips + 一整面 CardGrid」改为可滚动货架页：

- 类型 chips（推荐/短剧/漫剧/AI短剧）→ 决定下面三个货架的来源榜单与分类维度；
- **分类** chips 行：取该 shelf 服务端 `category_dim_theme` 分组，选中即把条件打到 landpage 上（不是本地过滤），`全部`清除；
- **为你推荐** 货架：官方推荐流一行，动作 `换一批`（取下一批，不追加到画面里）；
- **正在热播** 货架：该类型的官网榜（综合/真人/漫剧/AI），动作 `查看完整榜单`（跳到排行榜视图）与 `刷新片单`；选了分类后标题换成分类名、动作换成 `更多`（跳到找剧）；
- **新剧** 货架：`上新` 流按类型分签（真人剧/漫剧/AI剧上新），动作 `刷新片单`。此前 `hongguoLatestProvider` 没有任何消费者，这一轮接上。

新增 `HongguoShelf`（`widgets/hongguo_widgets.dart`）：标题 + 右侧动作 + **一行**海报，列数沿用 `browseSettingsProvider` 的间距与列数上限，加载时给等宽骨架，失败时给原因与重试。

海报卡 `HongguoSeriesCard` 补成参考的形状：左上名次角标（前三走强调色）、右上 `全 N 集`/今日/评分、封面底部热度、标题右侧**本机收藏书签**（找剧/榜单/搜索的网格也一并开启）。

找剧页的条件摘要与筛选入口见 8.3（条件已收进 `DsPanel`）。

l10n：`hongguo` 新增 14 个 key（中英各一份，`dart run slang` 已重生成）。

### 8.3 第二轮（同日续做）：排行榜、搜索联想、筛选面板

**排行榜改成满榜快照**（对齐 `RankBrowser.kt:44-83`）：

- `websiteRank` 回 `totalPages`；新增 `websiteRankSnapshot(board)` 读满整榜（>5 页明确报错、中途空页报「榜单未读完整」，不把半榜当完整）。
- `HongguoRankController` 从「一次一榜+翻页」改成 **每榜一份会话快照**：`Map<board, {items, readAt, loading, renewing, error}>`、TTL 10 分钟、同榜一次只发一个请求、过期时展示旧榜并后台静默续期、只有 `刷新` 强制重拉。
- 榜内题材筛选：从整榜的标签统计（过滤纯数字、按出现次数排序），筛选后 **保留原榜名次**；副标题带 `来源 · N 部 · 题材 M 部（保留原榜名次） · 正在后台更新…`。
- 首页「正在热播」货架改用同一快照源，`刷新片单` 走强制刷新。

**搜索补联想与历史**（对齐 `ContentRepository.kt:417-436` + `SearchSuggestionsView.kt`）：

- `searchSuggestions(keyword)`：`/incent_resource/suggestion?app_id=8662&web_id=<会话随机>&query=&count=8`，取 `name` 否则 `display_words[0]`，去空去重截 8、≤80 字。
- 控制器：输入停顿 350ms 才发问、旧请求作废、失败只提示 `联想暂不可用，可直接按搜索` 不阻断搜索；提交搜索即清空联想。
- 本机搜索历史：`hongguo.search.history`，≤20 条、去重、最新在前，可一键清空；空查询时历史词作为 chips 出现。
- 顺手修掉审计里的 D7：官网搜索接口不再强塞 `appUa`，回到与参考一致的默认 UA。

**找剧的筛选条件收进面板**（按项目既定规则「多条件筛选只留头部入口，条件放 DsPanel」，抄 `live/history` 的面板版式）：头部只留摘要 + `筛选` 入口，`DsPanel` 内是服务端分组、页脚 `重置 / 完成`，选一条即打一次服务端条件（不是本地过滤）。删掉了本轮先前加的 `收起/展开筛选` 与两个未用到的文案 key。

l10n 累计新增 27 个 key（中英各一份，`dart run slang` 已重生成）。

### 8.4 第三轮：账号页资料头与历史筛选

- **账户页**（`_AccountView`）：头像 + 昵称 + `红果号：<id>` + `复制`（写系统剪贴板并提示已复制）；下面一栏是**三块云端数据各自的读取状态行**（收藏/历史/预约：`正在读取…` / `已读取 N 部` / `尚未读取` / 失败原因），每行点一下只刷自己那块；退出登录保留。原来那一个「刷新账户数据」大按钮被拆成三行，避免出现两套刷新入口。
  - 参考的 关注/粉丝/获赞 三项**没有做**：`/reading/user/info/v1` 只回 `biz_user_id` 与 `user_name`，没有可核对的取数接口，不伪造。
  - 收藏/历史/预约仍是模块菜单里的独立入口（既往 IA 裁决），不把三块折进「账户」页内做子页签，否则同一项出现两个入口。
- **观看历史**：本机页签下加 `全部 / 已看完 / 未看完` 筛选行（对齐手机端「我的-历史」的三 chip）；`_readCount` 统一三块云端列表的状态话术。
- l10n 再 +8 key（中英各一份，已 `dart run slang`）。

### 8.5 第四轮：收藏更新检测

对齐 `FavoriteMonitor.kt` + `Library.kt:180-183`：

- 本机片单新增 `hongguo.library.favoriteUpdates` 持久层：每部记 `{total, seen, checkedAt}`（`seen` = 收藏当时的集数）。
- `HongguoLibraryController.checkUpdates({force})`：**串行**逐部读详情集数，**每部 1 小时节流**（`force` 忽略），**连续 3 次失败即停**，边跑边把 `done/total/failures/原因` 写回状态；跑完落盘。
- 收藏页（本机）头部一颗 `检查更新`（跑动中禁用）+ 一行状态：`正在检查 i/N…` / `已检查 i/N 部 · 检查完成` / `… · M 部失败，稍后可重试 · 原因` / `收藏更新 K 部` / `最近一小时已检查，可手动刷新`；每部收藏的副标题变 `新增 N 集` 或 `更新至 M 集`。
- `HongguoLibraryState` 改成带 `copyWith`，四个 mutator 不再手工重建状态（原先会丢掉新增字段）。

> 本轮发现并行 lane 已在做 **定时停止 / 画面模式 / 播放失败重试 / 解码能力记录 / 官网剧评**（新增未跟踪 `controller/hongguo_comfort.dart`、`controller/hongguo_decoder.dart`、`official/hongguo_public_reviews.dart`，并已把 `sleep*`/`frame*`/`retry*`/`decoder*`/`reviews*`/`favorite*` 文案写进两份 l10n）。我的收藏检测因此**改用他们已存在的 key 名**（`favoriteChecking(done,total)`、`favoriteAdded(count)`、`favoriteBadge(count)` 等），没有再新增重复文案，也**没有去碰**上面那三块，避免双写。

### 8.6 第五轮：播放舒适度与公开剧评（并行 lane 收口）

`hongguo_comfort.dart` / `hongguo_decoder.dart` / `hongguo_public_reviews.dart` 三块落地，并接进了播放页与设置页：

- **定时停止**（`HongguoSleepTimer`，照 `PlaybackComfort.kt`）：播放条一颗 `定时` 菜单——关闭 / 15 / 30 / 60 / 90 分钟 / 本集播完 / 再播完 3、5 集；按分钟计时时按钮每分钟刷新一次剩余，到点暂停、保存位置并提示「定时停止已生效 · 观看位置已保存 · 按播放可继续」；按集计时在 `_handleFinished` 里扣减，归零即停。
- **画面模式**：按 8.6 下方既有裁决**不做模块副本**；播放条新增 `画面` 菜单，直接写全局 `playbackSettingsProvider.fit`（完整画面/等比铺满/拉伸铺满 = `PlaybackFit.contain/cover/fill`），与「同项只留一个入口」一致。
- **解码能力学习降档**（照 `CodecCapabilities.kt` + `LearningDowngrade`）：流已打开后引擎报错，就把这次 `codec|宽|高` 记进 `hongguo.decoderFailures`（持久化），选档时跳过已学习失败的档位；同一集自动降一档、至多两次，再失败才出面板。设置页新增「设备解码记录」行（显示条数、可重置），与参考的 `CodecCapabilities.resetLearned()` 对齐——注意它**不是**既有的「重置设备」（那是清匿名身份）。
- **失败恢复预算**（照 `RecoveryBudget` + `scheduleRecovery`）：同一集 ≤3 次自动重试，间隔 1s / 2.5s / 5s，重试从失败位置续播；播放器上盖失败面板：`立即重试` / `尝试 NP`（面板自己的降档，同时把偏好降下去）/ `返回选集`（全屏时退出全屏）/ `停止自动重试`。**未做**参考的「断网时等联网再续播」——没有联网监听，改为按预算重试。
- **后两集模型预取**（照 `streamLadder(id, metadataAhead)`）：`playbackLadder(vid, {ahead})` 一次请求带当前集 + 后两集，后两集的 inline 档位在内存留 60 秒、领用即删、最多 6 条；切集命中缓存不再请求。
- **官网公开剧评/评分**（照 `PublicComments.kt`）：`official/hongguo_public_reviews.dart` 读 `hongguoduanju.com/player/<series>/<episode>` 与 `detail?series_id=` 的 loaderData，取整剧剧评、本集评论、评分与评分人数；**不带任何账号凭证**，详情页每剧缓存 30 秒、最多 16 条。系列页新增「剧评」区（评分徽标 + 评论卡）。
- **手机号登录**：`HongguoWebLogin.sendCode/verifyCode`（官网 passport 的 `send_code → sms_login`，与扫码共用同一会话）接进登录控制器；账户页未登录时 `扫码登录 / 用手机号登录` 两枚 chip，手机号表单带发送倒计时与错误行。**与参考的差异**：参考走设备签名的 `passport/mobile` 四段链路，这里复用已在库的官网 passport 三段，登录态与会话 cookie 同源。
- 收藏更新检测的副标题按 8.5 补成 `新增 N 集 · 更新至 M 集`；打开系列页即 `acknowledgeUpdates`（把 `seen` 追到本次读到的集数），取消收藏时连带删掉它的 update 行。
- 设置清单：`kSettingsProviders` 补 `hongguoAccount/ Library/ Search/ Settings/ DecoderLessons`；备份补 `hongguo.quality` / `decoderFailures` / 三个 library 键 / `search.history`；设置搜索补 2 行（清晰度、设备解码记录）；l10n 中英各 +30 左右（`dart run slang` 已重生成）。

验证：`dart analyze lib`（apps/pure_live）0 issues；`check_settings_ia.ps1` 的 hongguo 条目通过（剩 music 三页与 roomCard 别名属并行 lane）；`check_prefs_manifest.ps1` 对 hongguo 只剩两类：`hongguo.account.credentials`（登录凭证，有意不备份）与 `hongguo_device.dart` 里 `value/pick` 两个局部 helper 的**误报**（门禁把它们当 pref helper，报出的是设备字段名，不是 pref 键）。未验证：真机播放的定时/降档/续播、公开剧评的真实页面结构、手机号真实验证码。

### 8.7 下一轮继续

P1 已清零：首页/侧栏的新集徽标见 8.10，断网等待见 8.11。P2：弹幕渲染层（#7）见 8.9，选集分组/跳转/已看标记（#6）见 8.12，评论双 tab 见 8.13，HUD 状态行见 8.14，收藏卡片文案见 8.15；剩评论面板的侧边停靠版式与表情图、筛选面板收放、搜索联想/历史、榜单快照 TTL。

### 8.8 第六轮（2026-10-29）：签名器与 ttEncrypt 的四处错位

用户报「打开页面报错、接口参数错误」。用一个临时探测测试直接打真实接口后定位到**签名与注册两层都是坏的**，与页面无关：

| 位置 | 错法 | 后果 |
|---|---|---|
| `hongguo_signer.dart` `_rol32/_ror32` | 位数未按 32 取模，`count+1` 可到 255，`32-n` 变负 | Dart `<<` 抛 `Invalid argument(s): -N`，所有签名请求在本地就崩 |
| 同上 `_proto` | 字符串字段只有两个元素，却直接取 `field[2]` | 同上，`RangeError 0..1: 2` |
| 同上 `_hashF13` | `di` 按小端**有符号**读、`r1/r2` 把异或写成加法、压缩轮 `n2/n5` 把异或写成加法；`_getIv/_sumMd5` 把普通左移写成循环左移 | 签名值错，服务端回 HTTP 200 + 空体 |
| 同上 `hongguoAesCbc` | 把 `decrypt` 直接传给 PointyCastle 的 `init(forEncryption)`，语义取反 | ttEncrypt 产出垃圾字节 → `device_register` 回 `device_id:0` → 播放「设备注册失败」；spade_a / URL 解密同样取反 |
| 同上 `HongguoAesV3` 密钥扩展 | 轮常量触发条件 `i%3==0`，参考是 `(i&3)==0` | x-medusa 错 |

修法：逐段对照 `server/vendor/hongguo.cjs`（同一套算法的纯 JS 版）。用固定设备表、body、时钟与随机流，把参考实现的 `x-gorgon / x-helios / x-medusa` 跑出向量，Dart 侧逐字节相等后才收工；`hongguoAesCbc` 用 NIST AES-128-CBC 向量与 `openssl` 双向对齐。为此给 `HongguoSigner` 加了可注入的 `clock`（与既有 `random` 对称）。

真实网络复核（临时探测，跑完即删）：推荐 feed `3` 条、分类 landpage `24` 条、设备注册拿到 `device_id/install_id`、播放模型拿到档位——全通。**应用内搜索仍回空体**，但用参考 JS 实现原样请求也是空体，属服务端/风控变化，不是移植问题；搜索页已按原设计回落官网搜索（`hongguo_feeds.dart` 首屏 catch 后走 `websiteSearch`）。

新增回归测试（`apps/pure_live/test/hongguo/`、`test/music/`，共 17 项）：签名向量（含 GET 无 body 形态）、睡眠定时器与恢复预算、选档/降档与已学失败档位、歌单去重/排序/移除/导出导入往返/坏文件拒绝。`dart analyze lib/modules/hongguo test` 0 issues。

**旁注**：`fjs: ^3.3.2`（音乐模块新加的 QuickJS 运行时，未入库）在 Windows 上编不过——它 cargokit 的签名 recipe 只列 Apple 的 Rust target，本机又无 cargo 可退源码编译；这是 `flutter run` 失败的原因，与红果模块无关。

### 8.9 第七轮（2026-10-29）：弹幕渲染层（P2 #7）

`hongguo_social.dart` 早就把一集的弹幕按 5 秒轮询窗口取进 `hongguoDanmakuProvider.items`，但唯一消费者是系列页的 `stop()`——取到却不画。本轮补上消费端：

- **`controller/hongguo_danmaku.dart`**（新）：`HongguoDanmakuSettings`（开/关、字号 14–40、不透明度 0.2–1、速度 0.5×–2×、密度 1/3·2/3·全屏行数）+ `fromJson` 逐项夹取 + `lanesFor(height)`（按行高 `fontSize × 1.7` 折行、按密度取份、1–8 行封顶）；`HongguoDanmakuSettingsController` 存 `hongguo.danmaku`；`HongguoDanmakuPlanner` 管同一行两个弹幕的最小间隔（默认 700ms，全忙则丢弃，与参考一致），seek 时 `reset()`。
- **`widgets/hongguo_danmaku_layer.dart`**（新）：`Ticker` 驱动的 `CustomPaint` 覆盖层。时钟取播放器 `position`，帧间用墙钟插值——暂停即冻结；位置跳变超过 1.5s 视为 seek，清空在途弹幕并按新位置找游标。每条弹幕从右缘出发，按 `(width + textWidth) / 9000ms × speed` 飞完全程，离开左缘即回收；行号由 planner 分配，文字带双层阴影。
- **接线**：`hongguo_series_page.dart` 在播放器 Stack 里插入该层（仅在有 handle、开关打开且本集有弹幕时），控制条加一枚 `captions/captionsOff` 开关，直接写同一个偏好；`hongguo_settings_pane.dart` 新增「弹幕」一节（开关 + 字号 + 不透明度 + 速度 + 密度五类行，`SettingsConfigRow`/`SettingsChoiceRow`）。l10n 中英各 +11 键。
- **清单**：模块 barrel 导出两个新文件；`kSettingsProviders` 补 `hongguoDanmakuSettingsProvider`；备份补 `hongguo.danmaku`；设置搜索补一行（弹幕/字号/透明度/速度/密度）。

新增 `test/hongguo/hongguo_danmaku_test.dart` 7 项：越界字段夹取、缺省值、各密度下的行数预算、planner 轮流/全忙/重置、控制器读盘与写盘。`dart analyze lib/modules/hongguo lib/features/settings lib/features/backup/document/backup_settings.dart lib/app/providers/settings test/hongguo` 0 issues；`flutter test test/hongguo` 19 项全绿。**未验证**：真机上的观感（字号/速度的默认值、密度在 16:9 外的画面比例、长时间播放的帧率）。

### 8.10 第八轮（2026-10-29）：收藏新集徽标（P1）

收藏检测（8.6）已经算出每部剧 `added = total - seen`，但数字只出现在收藏页的行内文案里，侧栏的「收藏」入口看不出来。参考把新集数挂在菜单项上，本轮照做：

- `HongguoLibraryState.addedCount`：整个书架的新集合计（负值按 0 计，平台回退集数时不会出现负数）。
- `DesktopLayout`/`MobileLayout` 各加一个可选 `badges: Map<NavigationItem, int>`，行的 `count` 直接用 `DsSidebarItem.count`（>99 显示 `99+`，折叠侧栏退化成圆点），无障碍读作 `t.hongguo.favoriteAdded(count: N)`——复用已有的「新增 {count} 集」文案，不新增词条。
- `AppLayout` 只在 `AppModule.hongguo` 时订阅书架（其他模块不持有该 provider），有值才传 `{hongguoFavorites: N}`。
- 手机底部导航没有徽标位（`DsBottomNavItem` 无 count），因此这道徽标只出现在桌面侧栏与手机抽屉；参考的底部栏同样没有。

新增 `test/hongguo/hongguo_library_test.dart` 2 项：合计与负数夹取、打开一部剧后其余徽标保留。`dart analyze lib/layouts lib/modules/hongguo` 0 issues；`flutter test test/hongguo` 21 项全绿。**未验证**：真机上的徽标观感（折叠侧栏的圆点、电视遥控聚焦时的行高）。

### 8.11 第九轮（2026-10-29）：断网等待（P1 收尾）

参考在断网时不自耗重试次数，而是等联网回来续播；目标之前只有 1s/2.5s/5s 三次定时重试，断网时三次必然全废。本轮补上等待：

- `network_type_provider.dart` 新增纯函数 `isOnlineReading(state)` 与 `isOnlineProvider`：只有**唯一**接口是 `none` 才算离线；后端未就绪或读数为空一律按在线，缺插件不能反过来卡住播放（沿用 `NetworkConnectivity.isOnline` 的语义）。
- 系列页 `_onPlaybackFailure` 在设置失败面板后先看在线状态：离线则 `_waitForNetwork()`——取消失败计时、置 `_waitingForNetwork`，用 `ref.listenManual(isOnlineProvider)` 等第一条在线读数，到了就按原位置 `_openEpisode(recovering: true)` 续播，**不消耗**恢复预算。面板状态行显示 `waitingForNetwork`（「当前没有网络 · 联网后会自动接着播」），手动重试/降档/换集都会关掉等待订阅。
- 在线时的行为不变（预算 1s/2.5s/5s，面板四按钮也在）。

新增 `test/app/network_type_test.dart` 3 项：`none` 独占才离线、live 与 `none+vpn` 在线、空读数/未就绪在线。`dart analyze lib/app/providers/network lib/modules/hongguo test/app` 0 issues；`flutter test test/app test/hongguo` 24 项全绿。**未验证**：真机拔网线的完整往返（依赖 `live_device` 的 `watch()` 推送；桌面若只给轮询读数，则等待可能直到下一次显式读数才结束）。

### 8.12 第十轮（2026-10-29）：选集分组、跳转与已看标记（P2 #6）

目标把整部剧的集数一次铺成 chips，千集剧会拉成一条长列表，也没有跳转和已看标记。本轮照参考补：

- **分组**：选集区每 20 集一组（`_kEpisodeGroup`），标题行右侧显示 `起始–结束 / 总数` 与上一组/下一组（`DsButton.icon`），打开某集时自动切到它所在的组（`_groupOf` 按它在已加载列表里的位置算，不假设集号连续）。
- **跳转集数**：`跳转集数` 按钮弹 `DsDialog` + 数字键盘输入（`FilteringTextInputFormatter.digitsOnly`），先按集号找、找不到再按序号夹取；回车或确认即打开，空/非法输入不动页面。
- **三色标记**：当前集仍用 `selected`；**上次看到**的那集（历史行的 `episodeIndex`，未看完时）加播放图标；`已看`（更早的集，或历史行标记 completed）加对勾。历史行不存在时全部不标。
- l10n 中英各 +3（`episodesJump/episodesPrevious/episodesNext`）。

`dart analyze lib/modules/hongguo test/hongguo test/app` 0 issues；`flutter test test/hongguo test/app` 24 项全绿。**未验证**：真机观感（chips 内小图标与数字的间距、千集列表切组时的滚动位置、遥控器上跳转弹窗的数字输入）。

### 8.13 第十一轮（2026-10-29）：评论双 tab（P2 #8 的前半）

参考的评论面板有「本集评论 / 整剧剧评」两个 tab；目标一直只画整剧那一路，本集评论虽然已经取到（`HongguoPublicReviews.episode`）却没有任何入口。本轮把它接出来：

- `_SeriesReviewsSection` 加 `DsSegmentedControl<bool>`（默认本集），列表按 tab 读 `data.episode.items` / `data.series.items`；评分徽标仍挂在整剧行，加载/错误/空态共用一套。
- l10n 中英各 +2（`reviewsEpisode/reviewsSeries`）。

**没做**：参考的「侧边停靠、不遮画面」版式（`TvSocial.kt` 的 END 抽屉）、到底自动续读、表情图替换——前者要重排系列页的播放器区域，留待版式决策。`dart analyze lib/modules/hongguo` 0 issues。

### 8.14 第十二轮（2026-10-29）：播放 HUD 状态行（P2 #7 的前半）

参考在控制条上方有一行 `清晰度 · 倍速 · 定时` 状态；目标只有一排按钮，选了哪档、倍速多少、定时还剩多久都要点开菜单才知道。本轮在控制条第一行加一条右对齐的只读状态行：当前档位（`_attempted.quality`，未知时不显示）、倍速、运行中的定时（复用 `_sleep.label(t)`），用数字字体渲染。

**没照搬**：参考的 4500ms 自动隐藏、固定按键帮助行。pure_live 的控制条在各模块是常显的固定版式（且本页需要遥控器逐项聚焦），自动隐藏会让遥控操作多一次唤醒；帮助行信息在当前按钮的 `semanticLabel` 里已有。`dart analyze lib/modules/hongguo` 0 issues。**未验证**：真机观感（状态行在窄宽度下与进度条挤不挤、长定时文案是否换行）。

### 8.15 第十三轮（2026-10-29）：收藏卡片的参考文案（P2 #2 的内容面）

目标收藏页的行只有「新增 N 集 · 更新至 M 集」，没有参考的 `共 N 集（+M）`、`总集数待更新`，也不显示看到第几集。本轮把 `_favoriteLine` 提成公开的 `hongguoFavoriteLine`（`widgets/hongguo_widgets.dart`）并照参考重写：

- 检查过且涨了：`共 N 集（+M）`；检查过没涨：`共 N 集`；没检查过但列表带集数：`共 N 集`；两者都没有：`总集数待更新`。
- 有本机观看记录时再追加 `看到第 N 集`，合成一行并仍走卡片副标题（卡片高度按列宽算，加第二行会溢出，故不再加行）。
- l10n：新增 `favoriteTotal/favoriteTotalAdded/favoriteTotalPending/favoriteWatchedTo`，删掉不再有人用的 `favoriteUpTo`。

新增 3 项测试（合计/带记录、检查过没涨、未检查的两种回落）。`dart analyze lib/modules/hongguo test/hongguo` 0 issues；`flutter test test/hongguo test/app` 27 项全绿。**没做**：参考的「两行」卡片版式与 `待上线/暂不可观看` 状态标签（前者要改共享卡片的可计算高度，后者要预约行带状态字段）。

---

## 附：本文的验证方式与未验证项
- 参考侧结论来自逐行读 `README.md`、`docs/*.md`、`kotlin-tv/*.md` 与 `kotlin-tv/{core,app}` 源码；P0 的 8 条我逐条用 grep/长度比对复核（s-box 1352 vs 1368、hashTable 唯一真差异、`_hexBytes` vs `decode64`、未压缩却带 gzip 头、写死 `tab_type '11'`、`HongguoSigner()` 默认设备、cookie 平面 map、2MiB 分片）。
- 「`tab == 0` 在 `:878` 提前 return，货架首页不可达」是我自己读 `MainActivity.kt:845-914` 复核的，不是转述。
- **未验证**：任何真实网络往返、账号可见性、电视解码表现、遥控器手感、接口参数是否已被平台改动。参考文档本身也把其中多项标为「尚待用户账号实机验收」。
- 目标模块：盘点那一轮只读代码未改动；此后 8.1–8.4 的改动都过了 `dart analyze lib/modules/hongguo`（0 issues），但**未构建、未起窗口、未做运行期目视**。工作区里 `hongguo_series_page.dart`、`hongguo_web_login.dart`、`hongguo_social.dart` 等是并行 lane 的未提交改动，本轮未触碰。
