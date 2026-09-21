# 平台接口与兼容性

本文记录 Pure Live 当前使用的直播接口、数据含义和本地验证方法。平台网页可能随时调整，合并接口改动前应执行一次探测脚本。

## 当前平台能力

2026-09-21 按 `lib/core/sites.dart` 核对：当前源码注册 **41 个直播站点 + IPTV，共 42 个适配器**。这是源码注册数量，不是已发布包或完整验收数量。小红书、niconico、微博、SHOWROOM、CHZZK、Kick、17LIVE、LiveMe、TikTok LIVE、YouTube Live、Bigo Live、PandaTV、PopkonTV、Shopee Live、VK Video Live、NimoTV、Dailymotion、Rumble、GoodGame、FC2 Live、Steam Broadcasts、京东直播和淘宝直播已接入应用入口；原生整体验收继续，当前候选与完整剩余范围以[验收状态](ACCEPTANCE_STATUS_3_2_0.md)为准。

### 09-09 及更早阶段的取证快照

OPENREC / mellow-fan 已接入复合频道身份、公开目录与 HLS 质量；其当前生产整链可达性与原生验收仍有缺口，见[应用审计](OPENREC_APPLICATION_INTEGRATION_AUDIT_2026_09_09.md)。TTingLive / FLEX TV 已接入有限首页目录、精确频道查询及按源 token 策略；应用回归 201/201，最新生产注册适配器与 24 份 HLS 列表链路通过，后续 Windows 原生短录两次采集目标失败；保留片段的合并/完整解码通过，但起始延迟及音视频时间覆盖仍待修，完整录制未通过，见[应用审计](TTING_APPLICATION_INTEGRATION_AUDIT_2026_09_09.md)、[生产链路审计](TTING_PRODUCTION_RELAY_AUDIT_2026_09_09.md)及[原生短录审计](TTING_NATIVE_RECORDING_AUDIT_2026_09_09.md)。
克拉克拉与花椒已接入公开目录、UID 收藏及播放/录制解析；两者搜索、弹幕与 Android/Windows 原生验收仍待完成，见[克拉克拉应用审计](KILAKILA_APPLICATION_INTEGRATION_AUDIT_2026_09_08.md)、[萌星目录修订](KILAKILA_RISING_STAR_AUDIT_2026_09_08.md)及[花椒应用审计](HUAJIAO_APPLICATION_INTEGRATION_AUDIT_2026_09_08.md)。花椒空页仍有 more 时沿原生游标有界继续，游标按页面和刷新批次隔离，不用结果条数代替结束信号。
当前 [Android 候选 bee143e2](OPENREC_PICARTO_ANDROID_CANDIDATE_2026_09_09.md) 已包含克拉克拉、花椒、OPENREC 和 Picarto 响应收尾修订；完整门禁/打包通过，尚未安装，后续 TTing 和源策略输入链未入包。Windows f3de664a 未随本批更新，原生能力证据仍按各平台分列。
猫耳和映客已应用接入；猫耳 Windows 原生短录有独立证据，映客当前只到公开接口和生产地址解析，见[映客应用审计](INKE_APPLICATION_INTEGRATION_AUDIT_2026_09_08.md)。
Picarto 已进入 Android 候选并取得部分原生证据，见 [接入审计](PICARTO_ADAPTER_AUDIT_2026_09_07.md)及[停止/清理补证](ANDROID_PROXY_OCCLUSION_AUDIT_2026_09_07.md)。
TwitCasting 新增公开目录、顶栏分类、详情/HLS三档、录制输入与恢复；Android 80b7431c已覆盖安装并解除首段401，low出现实际画面，但短录文件严格解码仍失败，见[修复候选复验](TWITCASTING_COOKIE_ANDROID_RETEST_2026_09_07.md)。首次high/首帧、完整文件与长录仍待验收；当前 Windows f3de664a 候选已包含源码，但没有本平台对应的新原生验收。
参考项目尚未接入的平台单列于 [平台扩展差距表](PLATFORM_EXPANSION_AUDIT_2026_09_07.md)，不计作本项目已支持。

源码开发中的 AcFun（正式 v3.1.8 发布包不含；当前 af88a032 Android Debug 候选已包含）：已接入官网直播分类与目录、包含未开播作者的
原生搜索、直播分享链接、游客取流、画质/线路、录制输入和在线人数开关。
搜索按实际条目衔接官网的稀疏分页；`onlineCount`、点赞、粉丝分别处理。
远端弹幕尚未接入，房间内会说明并保留本地互动入口。完整录制文件、实际观看和正式产物
仍待验收，见 [AcFun 接入审查](ACFUN_NAVIGATION_AUDIT_2026_09_05.md)。

### 当前源码能力表

| 平台 | 分区来源 | 直播间搜索 | 弹幕 | 卡片指标含义 |
| --- | --- | --- | --- | --- |
| 哔哩哔哩 | 动态读取直播分区接口 | 原生直播间搜索，可返回未开播结果 | 访客模式动态获取 token；先连官方通用网关，再轮换 `host_list` 区域节点；认证失败后刷新凭据 | `online`/心跳为热度，`WATCHED_CHANGE` 为累计看过 |
| 斗鱼 | 动态读取移动端分类接口 | 原生直播间搜索，可返回未开播结果 | WebSocket | 热度 |
| 虎牙 | 网站业务分类与动态游戏列表 | 原生搜索当前直播间 | `wsapi.huya.com` WebSocket，按 `live:<uid>`/`chat:<uid>` 注册房间组并解析批量推送 | 列表/详情/URI 8006 均为热度 |
| 抖音 | 从直播首页动态提取分类 | 带网页签名参数的当前直播搜索 | WebSocket | 顶层/嵌套 `user_count` 为当前在线；`display_value/total_user` 为累计观看，缺少累计值时不再用在线值冒充 |
| 快手 | 网站当前直播频道、动态子分类与推荐回放 | 网页搜索入口 | 移动端增量 feed，cursor 串行轮询、断开取消；已有真实评论补证 | 在线；房间页下播但卡片仍带播放地址时按录播处理 |
| 网易 CC | 动态游戏列表，保留网站顶层入口 | 原生主播/直播间搜索，可返回未开播结果 | 当前未接入 | `webcc_visitor/hot_score/visitor` 为同一热度口径；只有 `vision_visitor/online_num` 为并发人数 |
| Twitch | 网站 GraphQL 标签与目录接口 | 原生频道搜索，可返回未开播频道 | Twitch IRC WebSocket；登录 Cookie 中的 `auth-token`/`login` 用于认证聊天 | `viewersCount` 为并发观看人数 |
| SOOP Live | 官方分类与推荐接口 | 原生搜索当前直播间 | SOOP WebSocket；账号 Cookie 可选 | 推荐/搜索以 `total_view_cnt`（PC + 移动端）为并发人数；分类使用 `view_cnt`；`current_view_cnt` 仅是 PC 端分量 |
| YY Live | 动态读取头部与分类元数据 | 原生直播间/主播搜索，可返回未开播结果 | YY WebSocket | `users` 为平台热度值 |
| AcFun | 官网直播分类与目录 | 原生作者搜索，含未开播作者；稀疏分页 | 当前未接入，页面明确说明 | `onlineCount` 为在线；点赞、粉丝分列 |
| Picarto | 公开直播目录入口；完整分类待接入 | 官网搜索入口，分享链接回流 | 当前未接入，页面明确说明 | `viewers` 为在线，详情 `total_views` 为累计观看 |
| TwitCasting | 官网顶栏分类与最多60条公开热门窗口；页面缓存后本地分页 | 官网搜索入口；仅频道根链接回流，movie/archive待接入 | 当前未接入，页面明确说明 | 目录 `current_viewer_count` 为在线；详情缺值时保留未知 |
| 猫耳 FM | 官网 catalog/tag 分类与原生推荐分页 | 当前未接入，页面明确说明 | 当前未接入 | `score` 为热度，粉丝分列；不以零值冒充当前在线 |
| 映客 | 官网有限精选及服务端频道，页面持续说明非全站列表 | 当前未接入，无虚构网页搜索入口 | 当前未接入 | 未取得人数，保持未知；主播等级不作观众数 |
| 克拉克拉 | 官方热门/萌星，type 0/107 原生分页 | 当前未接入 | 当前未接入 | `watchNumber` 未证实为并发人数，保持未知 |
| 花椒 | 官方 H5 公开视频推荐，保留原生游标 | 当前未接入，无虚构网页搜索入口 | 当前未接入 | `current_heat` 为热度，不作在线人数 |
| OPENREC / mellow-fan | 公开广播列表，频道聚合与多场歧义提示 | 当前未接入，无虚构网页搜索入口 | 当前未接入 | 公开并发人数；隐藏或多场歧义时保持未知 |
| TTingLive / FLEX TV | 有限首页公开直播快照，不宣称全站分类 | 精确频道号或频道直播链接，含未开播；不支持昵称/关键词 | 当前未接入 | 主目录 `playerCount`；详情和收藏刷新缺值时保持未知 |
| 小红书 | 公开目录/分类尚未取得，展示范围说明 | 精确直播房间/已核验分享链接；不宣称昵称搜索 | 当前未接入 | 缺少明确并发人数时保持未知 |
| niconico | 公开原生目录与分类分页 | 当前直播关键词分页及官方网页搜索 | 当前未接入 | 平台累计观看不冒充并发在线人数 |
| 微博直播 | 有限公开推荐快照，目录直播状态保持未知 | 精确场次 ID/官方观看 URL，含回放元数据；无昵称/分页查询 | 当前未接入 | 未取得人数，保持未知；不把 UID/互动数当观众数 |
| SHOWROOM | 官网公开 onlives 快照与原生分类 | 同一直播快照内的直播关键词分页；直播间链接可查询未开播状态 | 当前未接入 | `view_num` 作为本场累计观看，不当作并发在线人数 |
| CHZZK | 官方公开热门直播游标目录 | 原生频道搜索，包含开播和未开播频道 | 当前未接入 | `cvExposure=true` 时展示 `concurrentUserCount` 并发人数，否则保持未知 |
| Kick | 官方公开直播分页 | 原生有界搜索，直播匹配和未开播频道合并去重 | 当前未接入 | `show_view_count=false` 时保持未知，其他公开 `viewer_count` 作为并发人数 |
| 17LIVE | 首阶段保持范围说明；官网当前目录为个性化动态推荐 | 精确房间号及官方直播间/主播主页链接，包含未开播状态；昵称搜索待接入 | 当前未接入 | `liveViewerCount` 为当前观看，`viewerCount` 为本场累计观看，分别展示 |
| LiveMe | 官网公开热门目录，保留原生分页 | 原生主播关键词分页，包含未开播主播；直播间、主播主页和旧场次链接可回流为稳定短号 | 当前未接入 | `heat` 为平台热度、`playnumber` 为当前观看、`watchnumber` 为本场累计观看，三者分列 |
| TikTok LIVE | 游客推荐目录依赖网页会话，当前页面保留明确范围说明 | 精确账号、@账号、官方主页/直播间/直播分享链接；可返回未开播账号 | 当前未接入 | `liveRoomStats.userCount` 为当前观看，`enterCount` 为累计进房，分别展示 |
| YouTube Live | 首阶段保持范围说明；公开推荐目录依赖动态网页会话 | 精确视频 ID、观看/直播/短链/嵌入链接，以及频道或 `@handle` 的当前直播发现 | 当前未接入 | 仅使用直播页专用并发观看字段；普通 `viewCount` 不作当前在线人数 |
| Bigo Live | 官网有限公开推荐快照，本地分页且不宣称全站目录 | 精确 Bigo ID 与官方房间链接；可返回未开播或访问受限状态 | 当前未接入 | 目录 `user_count` 为当前直播在线；房间详情缺少并发字段时保持未知 |
| PandaTV（韩国） | 官方公开直播目录，原生 offset/limit 分页 | 精确频道 ID 与官方直播间/频道链接，包含未开播频道；昵称关键词待接入 | 当前未接入 | `user` 为当前在线；`playCnt` 为本场播放计数，两者分列 |
| PopkonTV | 官网公开直播目录，热门/最新/新人/热榜四种原生排序与分页 | 原生频道 ID、昵称关键词与官方直播链接搜索，包含未开播主播 | 当前未接入 | `watchCnt` 为当前在线；`totalWatchCnt` 为本场累计观看；`bookmark` 为收藏/关注，分列展示 |
| Shopee Live（印尼） | 官网首页有限公开直播推荐快照，不宣称全站目录 | 当前快照标题关键词、精确场次 ID 与官方分享链接 | 当前未接入 | 目录 `view_count` 与详情 `viewer_count` 为当前观看；`member_cnt` 不作并发人数 |
| VK Video Live | 官网公开分类与在线直播目录，保留服务端 offset 游标 | 原生频道搜索，保留 after 游标并包含未开播频道；当前与旧版官方频道链接均可回流 | 当前未接入 | `count.viewers` 为当前观看；`count.views` 为累计场次观看；频道 `subscribers` 为关注数，分列展示 |
| NimoTV | 官网首页公开推荐有限快照 | 当前快照关键词、精确频道号、频道别名与官方房间链接，包含未开播状态 | 当前未接入 | 官网卡片与直播页 `viewerNum` 为当前观看；下播或缺值时保持未知 |
| Dailymotion | 官网公开 API 的原生直播目录，保留 `page/limit/has_more` | 直播节目关键词、精确视频 ID、官方视频链接；精确频道名可返回当前直播 | 当前未接入 | 公开 API 未返回已核验的并发人数，保持未知；不以累计播放量替代 |
| Rumble | 官网公开直播目录，保留原生 `page` 与 `rel=next` | 当前直播目录内按标题、频道、分类匹配；精确直播页和频道链接 | 当前未接入 | 直播卡片及直播页动态字段为当前观看；VideoObject `userInteractionCount` 为累计观看，分列展示 |
| GoodGame | 官网 API 的 GoodGame 原生直播目录，保留每页 50 条和服务端总量 | 精确频道/播放器链接；当前目录页内按标题、主播和游戏匹配 | 当前未接入 | `viewers` 为当前观看；`rating`、premium 计数与粉丝分别处理 |
| FC2 Live | 官网普通内容有限快照；公开分类在同一快照内筛选 | 精确频道号/官网房间链接，含未开播；关键词在当前快照内匹配 | 当前未接入 | `count` 为当前观看，`total` 为本场累计观看；付费/登录/门票房间保持受限状态 |
| Steam Broadcasts | 官网热门社区直播原生分页，每页 10 条 | 当前目录页内按游戏、主播和标题匹配；精确 SteamID64/官方观看链接查询 | 当前未接入 | 目录和观看接口分别返回当前并发观看数；受限账号保持未知状态 |
| 京东直播 | 官网精选原生分页，每页最多 30 个直播卡片 | 当前目录页内按场次、作者、主播和标题匹配；精确场次 ID/官方房间链接查询 | 当前未接入 | 官网 `pv` 只标为观看，按累计观看展示，不冒充当前并发人数 |
| 淘宝直播 | 当前公开门户尚未取得经核验的消费者目录，页面持续说明范围 | 精确场次 ID、主播账号 ID、官方房间链接与 `m.tb.cn` 分享短链；保留未开播、回放和受限状态 | 当前未接入 | `viewCount` 为场次累计观看，不作并发人数；`fansNum` 为主播粉丝，分列展示 |
| IPTV | 本地导入频道分组 | 本地频道查询 | 无远端弹幕服务 | 不虚构观看人数 |

> “热度”是平台排序/活跃度指标，不等同于唯一在线用户数。界面会按平台字段分别显示“热度”“在线”或“累计观看”，避免把不同含义的数据统一标成在线人数。

搜索页会直接显示当前平台的覆盖范围，并提供“包含未开播”筛选。平台选择栏使用独立水平列表：项目超过屏幕宽度时可横向访问，首尾为硬边界，不使用无对应内容页的 `TabBar` 自动定位。综合排序固定把直播中房间放在前面，再比较当前观看口径、粉丝数和主页平台顺序；“平台优先”直接使用“平台显示设置”的拖动顺序，“观众优先”和“粉丝优先”则调整对应字段的比较次序。粉丝字段只在平台搜索响应明确提供时参与，缺少该字段的结果保留为稳定次序；快手使用网页搜索入口，IPTV 只查找本机导入频道。每个平台单独维护翻页结束状态，空页或重复页会停止继续请求。

“全部”搜索并发请求各原生平台，但按单个平台完成顺序渐进显示，某个平台超过 12 秒会被标记为本轮部分失败，不再阻塞其他结果。搜索页生命周期内复用同一组适配器，Twitch 等游标分页状态不会因每次读取平台列表而丢失。网页继续搜索可从 Bilibili、斗鱼、虎牙、抖音、快手、网易 CC、Twitch、SOOP、YY、AcFun、Picarto、TwitCasting、SHOWROOM、CHZZK、Kick、17LIVE、LiveMe、TikTok LIVE、YouTube Live、Bigo Live、PandaTV、PopkonTV、Shopee Live、VK Video Live、NimoTV、Dailymotion、Rumble、GoodGame、FC2 Live、Steam Broadcasts、京东直播和淘宝直播的已支持直播间链接识别“平台 + 房间号”；搜索/分类页和相似伪装域名会被忽略。

“设置 → 通用 → 观看数据与排行口径”提供两个全局模式和分平台开关：

- **平台热度优先**：按平台列表提供的热度或累计观看显示、降序排序；快手等只公开当前观看人数的平台继续保留“在线”标签。热门页、收藏、搜索与房间选择器共用同一个数值解析和稳定排序器。
- **真实在线人数优先**：抖音、快手、网易 CC、Twitch、SOOP Live、CHZZK、Kick、17LIVE、LiveMe、TikTok LIVE、YouTube Live、Bigo Live、PandaTV、PopkonTV、Shopee Live、VK Video Live、NimoTV、Rumble、GoodGame、FC2 Live、Steam Broadcasts 仅在拿到明确并发人数时按在线显示、排序；支持平台尚未取得列表值或房间消息时明确显示“待刷新”，不再回退为一个被误标或参与在线排行的热度值。
- 哔哩哔哩的列表 `online` 与弹幕心跳、斗鱼公开 `ol/hot`、虎牙 `totalCount/userCount/iAttendeeCount` 都是热度，均不换写成真实人数。由此避免把几百万热度显示为几百万人同时在线。
- 切换全局口径或分平台开关后，收藏与搜索现有结果会立即重新排序，热门页会刷新当前平台的候选池后重排；在线模式把已启用且支持并发人数的平台排在仅提供热度/累计值的平台之前。网易 CC 在线模式一次取 100 个热度候选后按并发人数排序，避免只在每 20 张卡片内部重排。

## 画质与播放线路契约

画质按钮不再只代表一段显示文字。每项必须同时具备稳定平台标识、请求参数、可播放线路和（平台支持时）服务端实际生效值。公共播放器仅在新媒体源成功打开后提交选中状态；解析失败、播放器拒绝、旧请求迟到、服务端降级或两个按钮最终得到同一组线路时，保留旧画面和旧选中项。

| 平台 | 稳定画质标识 | 切流校验 |
| --- | --- | --- |
| 哔哩哔哩 | `qn` | 以响应 `current_qn` 回写实际画质；访客被降级时不再显示成已切到原画 |
| 斗鱼 | `rate` | `rate` 是请求代码而非码率，严格保留接口 `multirates` 顺序；每个 CDN 使用同一目标 `rate` 重新取流 |
| 虎牙 | `iBitRate` | 切换时总是替换旧 `ratio`；原画删除 `ratio`，转码写入目标码率；不再虚构平台未返回的高清选项 |
| 抖音 | `sdk_key` | `stream_data`、FLV 和 HLS 按键名关联，禁止依赖 JSON Map 插入顺序 |
| 快手 | 清晰度名称 + 等级 | 同清晰度多 CDN 合并为线路，AVC 优先、HEVC 仅作回退 |
| 网易 CC | resolution key | 清晰度 key 与自身 CDN Map 绑定，优先线路在前、其他有效线路继续保留 |
| Twitch | HLS variant attributes | `EXT-X-STREAM-INF` 与紧随其后的 URI 成对解析，支持相对 URL；并发多画面不共享可变 URL 列表 |
| SOOP Live | preset name | 过滤 `auto` 和重复 preset，按平台 `bps` 排序，请求沿用同一 preset 名称 |
| YY Live | gear | 同名但不同 gear 保持独立并编号，播放响应只接收有效 HTTP(S) CDN 地址 |
| 猫耳 FM | `hls` / `flv` | 保留协议身份；刷新当前房间、同协议匹配，不将协议名虚构为分辨率 |
| 映客 | `flv` | UID 与当前广播 ID 双重匹配官网公开精选；恢复重新查询，签名期限仍待实证 |
| 克拉克拉 | `flv` / `hls` | 持久 UID 重新查询当前广播，匹配主播/广播身份；恢复保持同协议 |
| 花椒 | `hls` / `flv` / `unknown` | URL 格式不是分辨率/编码证据；播放和录制重新查询 UID→当前广播并匹配串号，恢复保持同格式 |
| IPTV | `default` | 单一导入源，空地址不生成伪画质 |
| AcFun | representation 解析所得稳定 ID | 同档多个有效 URL 合并；续签重新读取详情，按 ID 找回对应画质 |
| Picarto | HLS 分辨率/fps/编解码与音视频组 | 同档线路合并；恢复重新读详情及列表；外置音轨保留主列表并标 HLS Auto |
| TwitCasting | `high` / `medium` / `low` | 保留平台档名，不推断分辨率；匹配当前 movie 的 HLS，恢复保持请求档位，明确下播忽略陈旧地址 |
| OPENREC / mellow-fan | HLS 源族、分辨率、帧率 | 重新核对频道与当前广播；按解析列表匹配质量，外置音轨保留 master |
| TTingLive / FLEX TV | API `resolution`（0 为 Auto） | ncp / ncp_llh 源保留精确 URL token 策略；过期/recovery 重读频道与 stream，按 owner 和请求画质匹配；已核验保留成品 720p 解码；实时采集、音视频覆盖及其他画质仍待验收 |
| SHOWROOM | `hls_all` 或带码率的 HLS 源 ID | 自动/原画/中/低档按官方码率分组；恢复重新读取房间与流地址，保持当前档位 |
| CHZZK | HLS master 分辨率与帧率 | 合并普通 HLS 与 LL-HLS 同档线路；签名到期后重新读取 live-detail 和 master，按稳定质量 ID 恢复 |
| Kick | AWS HLS master 分辨率与帧率 | 忽略 master 的会话诊断标签，保留明确视频变体；恢复重读频道、签名播放地址与 master，并按稳定质量 ID 匹配 |
| 17LIVE | API 明确返回的增强高清、高清、H.264、标准 FLV | 同档聚合并保留官方多 CDN 顺序；恢复重新读取房间状态与媒体并保持稳定质量 ID，不跨档静默降级 |
| LiveMe | `source-flv` / `smooth-flv` / `hls` | 合并官方同档多线路，HTTP 媒体升级到 HTTPS；恢复重新解析短号到当前场次并保持稳定画质 ID，不跨档静默降级 |
| TikTok LIVE | `codec:quality:protocol` | 按官方 `sdk_params` 绑定 H.264/H.265、画质、分辨率和 FLV/HLS；恢复重查稳定账号并保持精确画质 ID，不跨档或跨协议静默降级 |
| YouTube Live | HLS master 分辨率/帧率/编码、直连 `itag`，以及 DASH 自动源 | 稳定 ID 区分协议与画质；解析签名到期时间，恢复时重取播放器响应与 manifest，不把加密签名源伪装成可播直链 |
| Bigo Live | `live` owned input | 每次播放/录制及恢复重新取得 Web token 与 HLS；私有 relay 按清单 seed 还原前两个 TS 包的受保护前缀，官网地址不直接暴露给 native |
| PandaTV（韩国） | AWS IVS HLS master 分辨率与帧率 | 官方观看会话取得短时 token；解析 master 为稳定 1080p60/720p60 等画质，播放和录制恢复重取会话并保持同一质量 ID |
| PopkonTV | 官方 HLS master 分辨率与带宽 | 每次播放、录制与恢复重新建立游客观看会话并按稳定分辨率 ID 匹配；成年、密码和其他访问条件保持明确状态 |
| Shopee Live（印尼） | 官方 FLV URL 的 `resolution` 稳定 ID | 普通 HTTP 优先；遇到官网动态校验时由无界面 WebView 复用官方指纹/SAP 中间件。播放、录制与恢复重新取得短时地址，并按 `expire_ts` 提前续期 |
| VK Video Live | 官方 HLS master 分辨率与带宽 | 合并主线路与共享线路的同档变体；从 URL 路径 `expires` 解析过期时间，播放、录制与恢复重取房间和签名 HLS 后保持稳定分辨率 ID |
| NimoTV | 官方签名 FLV 的 `ratio` 五档 | 移动房间页解码时效媒体包，固定使用 HTTPS；播放、录制与恢复重取 `wsSecret/wsTime`，并保持稳定 ratio ID |
| Dailymotion | 官方嵌入播放器 HLS master 的 `NAME` / 分辨率 / 带宽 | 浏览器上下文读取动态签名 master，仅接受同视频 ID 的 `*.dmcdn.net` rendition；播放恢复与录制入口重新解析并保持稳定 rendition ID |
| Rumble | 官方直播页 HLS master 的分辨率与带宽 | 浏览器上下文观察当前页面的 `/live-hls[-dvr]/…/playlist.m3u8`，只接收 `*.rumble.cloud` / `*.rmbl.ws` 变体；播放与录制恢复重载同一公开页面身份并保持稳定分辨率 ID |
| GoodGame | API `source` 与数字分辨率 key | 仅接受同一 stream ID 的 `hls.goodgame.ru/hls/…m3u8` 短时地址；播放与录制恢复重新查询频道并按 `source` / `NNNp` 稳定 ID 找回档位 |
| FC2 Live | `auto` owned HLS input | 每次原生打开重新取得房间版本、控制令牌和同频道 HLS master；控制 WebSocket 与私有 relay 同生命周期，恢复时建立新会话，不暴露可复用的短时媒体 URL |
| Steam Broadcasts | `auto` HLS master | 每次播放、录制与恢复重新查询同一 SteamID64，验证 Steam media host、广播身份、`broadcast_origin` 与 master 子清单后再交给原生消费者 |
| 京东直播 | `hls` / `flv` 原始线路 | 每次播放、录制与恢复重新查询同一场次；HLS 清单和子资源绑定同一 JD Cloud 主机与流标识，默认优先 HLS |
| 淘宝直播 | `newDefinition` / `definition` 的 `lld`～`ud` 稳定档位 | 匿名 MTop 会话动态签名并按物理媒体去重；每档同时保留 HLS/FLV 线路，播放、录制与恢复重新查询同一场次或主播身份，并按 `auth_key` 提前续期 |

横屏“清晰度与播放线路”面板根据画质数、线路数和可用高度计算整体尺寸。一个画质/一条线路时收紧面板；常见四画质使用均衡 `2×2`；项目多时只让按钮网格滚动，不用固定比例制造空白。按钮区域是主要视觉，标题、留白和重复的当前值标签均已压缩。

## 本地接口探测

2026-09-21 的 YouTube Live 首阶段生产探测使用本机 Clash 请求官方 Sky News 当前直播：频道 `/@SkyNews/live` 的 canonical 稳定回流到视频 `xDWQ3LkccY8`；watch page、Innertube player 与 HLS master 均返回 HTTP 200，播放器同时给出 HLS/DASH，HLS master 含 144p～1080p60 共 6 个音视频复合变体，页面专用 renderer 返回 `watching now` 并发数。该证据验证公开接口与媒体合同，不代替 Android/Windows 原生播放或录制验收。实现契约同时对照 [Streamlink 当前 YouTube 插件](https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/youtube.py)与 [yt-dlp 当前字段合同](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/common.py)。

2026-09-21 的 Bigo Live token 流程已在线取得公开直播状态与 HLS 地址；本机到媒体 authority 的非标准 1453 端口在 TLS 握手阶段收到 EOF，因此没有把该 URL 记作原生媒体通过。当前源码已按 [Streamlink Bigo 插件](https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/bigo.py)接入 token、受保护 HLS 标签、两包 TS 前缀转换与 owned playback/recording relay；详细边界见 [Bigo Web 媒体检查点](BIGO_WEB_MEDIA_CHECKPOINT_2026_09_21.md)。

2026-09-21 的 PandaTV 生产探测从官方目录取得当前直播，精确频道接口确认主播身份，观看接口返回带时效 token 的 AWS IVS HLS。使用官网 Origin/Referer 请求主清单得到 HTTP 200 与 `#EXTM3U`，并解析出 1080p60、720p60、480p、360p、160p 五档变体；源码已接入目录、精确频道、访问状态、画质、播放/录制恢复与链接回流。详细证据和边界见 [PandaTV 合同检查点](PANDALIVE_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的 PopkonTV 生产探测从官网 `/broadcast/v3.1/livelist` 取得当前直播与原生分页，从 `/broadcast/v1.1/search/all` 同时取得直播和未开播主播，并由游客观看接口生成时效 HLS。使用官网 Origin/Referer 读取主清单返回 HTTP 200、`application/vnd.apple.mpegurl` 与 `#EXTM3U`，当前样本列出 1080p 变体；源码已接入四种目录排序、搜索、访问状态、在线/累计口径、播放/录制刷新与链接回流。详细证据见 [PopkonTV 合同检查点](POPKONTV_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的 Shopee Live 生产探测从 Indonesia 官网首页接口取得 10 条当前直播推荐及实时观看字段；官网会话模块在同一浏览器上下文生成动态指纹/SAP 请求头并返回短时 FLV。使用官网 Referer 读取该媒体返回 HTTP 200、`video/x-flv`，字节前缀为标准 `FLV` 文件头。源码已接入有限目录、快照关键词与精确场次搜索、官方分享链接、动态浏览器解析、FLV 画质、到期续期和录制恢复。详细证据见 [Shopee Live 合同检查点](SHOPEE_LIVE_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的 VK Video Live 生产探测从官网当前页面取得公开分类、在线目录与原生频道搜索请求；搜索包含开播和未开播频道，房间接口返回并发、累计观看、主播身份与两条带签名 HLS master。使用官网 Origin/Referer 读取 master 返回 HTTP 200、`application/vnd.apple.mpegurl` 与 `#EXTM3U`，当前样本解析出 1080p、720p、480p、360p、240p 五档变体，实际变体清单同样返回 HTTP 200。源码已接入分类、目录、搜索、链接迁移、画质/线路、到期续期和录制恢复；详细证据见 [VK Video Live 合同检查点](VK_VIDEO_LIVE_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的 NimoTV 生产探测从官网当前首页取得公开直播样本，移动房间页直接返回稳定房间号、主播、标题、分类、当前观看与十六进制媒体包。解码后按平台 ratio 生成 1080p、720p、480p、360p、240p 五档 HTTPS FLV；当前签名样本读取返回 HTTP 200，字节前缀为标准 `FLV` 文件头。源码已接入精确频道/别名、官方链接、状态、五档画质、到期续期与录制恢复；详细证据见 [NimoTV 合同检查点](NIMOTV_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的 Dailymotion 生产探测从官网公开 API 取得原生直播分页、搜索、节目/频道身份与明确 `mode/onair` 状态；官方嵌入播放器动态取得签名 HLS master，当前样本返回 380p、240p、480@60 三档 `*.dmcdn.net` rendition，独立 rendition 请求返回 HTTP 200 与 HLS 清单字节。源码已接入目录、搜索、链接回流、动态画质、播放/录制恢复；详细证据见 [Dailymotion 合同检查点](DAILYMOTION_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的 Rumble 生产探测从官网 `/browse/live` 取得原生分页与当前直播卡片，卡片 `videostream__number` 和累计 `data-views` 分开保存。直播页确认公开页面 ID 与嵌入播放器 ID 是两套身份；浏览器会话观察到 `/live-hls-dvr/…/playlist.m3u8`，读取返回 HTTP 200，并解析 1080p、720p、360p 三档 `*.rumble.cloud` 变体。源码已接入目录、本机目录匹配、精确链接、动态画质、播放/录制恢复；详细证据见 [Rumble 合同检查点](RUMBLE_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的 GoodGame 生产探测从官网 API v4 取得 84 条直播的服务端总量、每页 50 条目录、频道身份、游戏、当前观看、粉丝和短时 HLS。当前样本返回 `source`、720p、480p、240p 四档，720p 清单读取为 HTTP 200 与标准 `#EXTM3U`，声明 H.264/AAC、1280×720、24fps。源码已接入分页目录、精确频道/播放器链接、目录内搜索、动态画质、到期刷新与播放/录制恢复；详细证据见 [GoodGame 合同检查点](GOODGAME_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的 FC2 Live 生产探测从官网动态接口取得 64 个当前目录条目；房间接口分列当前 `count` 与累计 `total`，控制接口签发短时 WebSocket。保持控制会话后取得同频道 HLS master，实际读取返回 HTTP 200 与标准 `#EXTM3U`，当前样本含 270 kbps、720 kbps、2.16 Mbps、3.6 Mbps 四个 H.264/AAC 变体。源码已接入有限目录、分类、本机关键词与精确房间搜索、访问状态、owned playback/recording relay 和恢复；详细证据见 [FC2 Live 合同检查点](FC2LIVE_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的 Steam Broadcasts 生产探测从官网匿名热门接口连续取得两页、每页 10 条当前直播；目录卡片同时提供 SteamID64、游戏、主播、封面和当前观看。`getbroadcastmpd` 对当前样本返回 `ready`、当前观看数、DASH 与 HLS，HLS master 实际读取为 HTTP 200，含 1080p60、720p30、480p30、360p30 四档 H.264/AAC 变体。源码已接入原生分页、页内搜索、精确链接、身份/媒体域约束、自适应 HLS、播放/录制恢复；详细证据见 [Steam Broadcasts 合同检查点](STEAM_BROADCAST_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的京东直播生产探测从官网匿名精选接口取得第一页 30 个直播卡片及第二页另外 30 个直播卡片；卡片提供场次、作者、主播、标题、封面和累计观看。当前样本的播放接口返回直播状态、HLS 与 FLV；HLS 实际读取为 HTTP 200 和连续 TS 分片，FLV 前缀实测为标准 `FLV`。源码已接入原生分页、页内搜索、精确链接、状态与媒体域约束、HLS/FLV 线路和播放/录制恢复；详细证据见 [京东直播合同检查点](JD_LIVE_CONTRACT_CHECKPOINT_2026_09_21.md)。

2026-09-21 的淘宝直播生产探测先由匿名 MTop 响应签发短时 `_m_h5_tk` 会话，再以 `MD5(token&t&appKey&data)` 取得当前直播详情；主播账号 `1759494485` 解析到当前场次并返回五档定义、累计观看与粉丝字段。HLS 主清单实际读取为 HTTP 200 和连续 TS 分片，FLV 前缀实测为标准 `FLV`。源码已接入精确场次/主播身份、官方链接与分享短链、匿名签名、状态、画质去重、HLS/FLV、到期续期和播放/录制恢复；详细证据见 [淘宝直播合同检查点](TAOBAO_LIVE_CONTRACT_CHECKPOINT_2026_09_21.md)。

```powershell
python tool/interface_probe.py
```

The probe covers categories, recommendations, searches, room metadata, danmaku discovery and playback contracts; its runtime summary is the authoritative count. The 2026-09-07 af88a032 full gate passed 42/42 checks, not a new run for every later documentation change. Recommendation checks also validate the audience-field contract for Douyu `ol`, Huya `totalCount`, Douyin `user_count`, Kuaishou `watchingCount`, CC heat/concurrent pairs, Twitch `viewersCount`, SOOP PC/mobile totals and YY `users`. Douyu executes signing, H5 metadata retrieval, CDN selection and a real FLV-header request with player-equivalent headers; Bilibili, Huya and CC verify quality/line descriptors; YY verifies categories, searches, room status and playback lines. These probes do not establish native playback, full-file recording or complete AcFun coverage; AcFun has separate adapter/navigation evidence.

2026-08-17 再次完成哔哩哔哩访客 WebSocket 实连：`uid=0` 会话连续取得当前房间弹幕，但平台把 legacy 与 rich user 两处昵称和 UID 一并脱敏。客户端会优先读取平台 rich user 的完整昵称；访客数据仍为脱敏值时在弹幕列表提示来源。公开直播的弹幕接收继续使用访客会话，登录账号用于完整昵称、发送平台弹幕、关注、会员清晰度和其他账号功能。

虎牙协议变更后可额外运行 `python .\tool\huya_danmaku_probe.py`，动态选择当前直播间并验证 WebSocket 注册、心跳和真实推送接收；当前客户端使用网页同款房间组注册和批量推送格式。脚本仅使用 Python 标准库，此网络回归不并入默认单元测试，避免平台限流导致本地门禁波动。

## 回归重点

1. 进入各平台首页和任意二级分区，下拉刷新后仍可显示封面。
2. 使用“全部”搜索验证跨平台去重、直播优先排序和单平台故障提示。
3. 哔哩哔哩直播间需在认证回应后显示“弹幕服务器已连接”，断线时自动轮换节点。
4. 平台接口返回的图片若为 `//host/path`，客户端会统一补全 HTTPS；设置页可清空图片缓存并强制刷新当前封面。
5. 接口响应字段变动时，先保留原始失败信息，再更新对应 `lib/core/site/*_site.dart` 与本文件。

## 本地构建策略

- Android：默认仅构建 `arm64-v8a`，适用于主流 64 位手机。
- Windows：仅构建 `windows-x64`。
- Linux：构建 `linux-x64` 便携归档。
- macOS：构建包含 x86_64 与 arm64 的 universal 应用归档。
- iOS：执行 `--no-codesign` 设备编译并归档 `.app`，随后在证书环境签名封装。
- GitHub Actions：保留五平台手动构建入口；Android/Windows 日常验证优先使用 `tool/build_local_release.ps1`，减少远程构建用量。
