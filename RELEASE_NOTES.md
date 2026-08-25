# Pure Live v3.0.0

v3.0.0 build 4087 是播放状态机、平台接口、录制可靠性、Windows 生命周期与全平台发布链路的稳定更新。

## 上游同步与页面状态

- 以真实合并历史同步到 `liuchuancong/pure_live@c22ae2f4`，吸收关注页/热门页状态绑定、无效关注记录清理、直播页 shell 拆分、Android ABI 管理、播放器生命周期串行化、移动端画面适配、Bilibili 路线递归及画中画返回状态修复。
- 热门页只使用控制器发布的响应式平台快照构建 `TabBar` 与内容页，避免设置变化期间列表与控制器长度短暂错位。
- 关注平台列表重建时按平台 ID 保留当前选择；已移除的平台使用有界索引回退，并在下一帧同步筛选状态。
- 关注数据在启动、备份恢复和显式清理时统一过滤空平台、空/占位房间号并按平台内身份去重，损坏的旧记录不再进入首页刷新队列。
- 维护发行版继续使用 `wzgrx/pure_live` 更新源，上游批量替换的仓库地址没有覆盖维护分支的安装包、版本历史和下载入口。

## 播放器、画中画与平台接口

- 修复上游 #797：切换房间时立即清理上一直播间的宽高与竖屏标志，只有成对有效的视频尺寸才参与比例计算，避免竖屏房间后打开横屏直播被旧比例压缩。
- 修复上游 #794：Windows 进入画中画前保存全屏/宽屏表达状态，退出后按原状态恢复 UI，不再统一重置为普通窗口。
- 修复上游 #793：无参数重复启动在 Windows native runner 创建 Flutter engine 前拦截并激活已有窗口；分享链接、协议参数和显式多窗口参数仍交给 Dart 转发。
- 修复上游 #798：YY StreamManager 请求对齐当前官方 bid、SDK 版本和正文类型；遇到 `ErrAuthNotPass` 或空结果时自动使用匿名移动 HLS，并按实际视频流去重清晰度选项。
- YY 发布探针新增 #798 指定房间的 M3U8 实读；全平台公开接口门禁由 40 项扩展到 41 项。
- 抖音匿名搜索探针在同一 Cookie 会话内对 HTTP 503 等瞬态故障执行至多三次有界重试，持续故障仍直接失败并保留端点诊断。

## Android 录制与长时间稳定性

- 修复上游 #791：播放器、多画面、音频转发和录制共用同一平台播放请求头；斗鱼录制补齐房间 Referer、Origin、User-Agent 与进程级 DID Cookie。
- 移除 Bilibili CDN 请求中的错误 API authority；YY、IPTV 与虎牙录制头不再和播放器策略漂移。
- FFmpeg 正确引用带 `&` 的签名 URL和含空格的输出目录；音频或视频轨暂时缺失时使用可选映射，避免初始化阶段直接退出。
- CDN 403/404、AVERROR(EIO) 与短时输入错误会重新解析最新地址后有界重试；本地路径、权限及无效输出参数仍立即结束任务。
- 默认私有录制目录先实际探测写入能力，再决定是否申请 Android 存储权限；主播名和平台名统一处理非法字符、保留设备名与超长组件。
- FFmpeg 高频进度只更新对应任务，不再反复排序完整列表；Hive 持久化合并为两秒节流并在控制器关闭时刷新，减少长时间录制的 UI、CPU 与磁盘负载。
- FFmpeg 改为首次录制时惰性初始化，直接服务调用也执行初始化保护；一次瞬时 native/文件系统失败不会永久污染进程内初始化状态。

## 依赖、工作流与交付

- hosted 依赖统一使用官方 `pub.dev` URL与当前归档哈希；除需要全应用迁移到 `material_ui.ColorScheme` 的 `dynamic_color` 2.x 外，直接依赖均为 Flutter 3.47 当前兼容线的最新版本。
- 修复全平台工作流中 Windows artifact Action 多余字符导致的无效 SHA；第三方 Release/读文件 Action 固定到完整提交。
- Release 仅在本轮明确请求的每个平台都构建成功后创建，避免某个阶段失败时误发布不完整的“全平台”版本。
- 版本：`3.0.0+4087`；Android arm64-v8a、Windows x64、Linux x64、macOS Universal 与 iOS arm64 串行构建发布。

---

# Pure Live v2.9.7

v2.9.7 build 4086 is an Android audience-metric and ranking consistency update.

## Audience semantics

- Audited current public payloads for Douyu, Huya, Douyin, Kuaishou, NetEase CC, Twitch, SOOP Live and YY Live. Douyu `ol/hot`, Huya `totalCount/userCount/iAttendeeCount` and YY `users` remain platform heat rather than concurrent head counts.
- Douyin now reads the current anonymous feed's top-level `user_count` as concurrent viewers and no longer stores that value as cumulative views when `total_user` is an unavailable zero placeholder.
- NetEase CC now treats `webcc_visitor`, `hot_score` and `visitor` as heat aliases; only `vision_visitor/online_num` can populate the online-viewer field.
- SOOP recommendation and search cards now use `total_view_cnt`, including both PC and mobile viewers. Category `view_cnt` remains authoritative, explicit PC/mobile fields are summed as a fallback, and missing player-detail counts remain pending instead of becoming a false zero.

## Ranking and regression coverage

- Popular-platform pages now share the same descending, metric-aware and deterministic comparator as favourites, search and room pickers. Changing heat/online mode refreshes and re-ranks the active platform; CC uses a 100-room candidate window for meaningful real-online ordering.
- Existing interface probes now verify each platform's audience-field contract as part of the 40-check gate, while focused parser tests cover the Douyin, CC and SOOP regressions and heat/online ordering.
- Synchronized remotes before source freeze; upstream remains `liuchuancong/pure_live@974f4c32` with no newer commit at release preparation time.
- Version: `2.9.7+4086`.
- This release publishes Android `arm64-v8a`; Windows, Linux, macOS and iOS remain on their v2.9.4 artifacts.

---

# Pure Live v2.9.6

v2.9.6 build 4085 is an Android platform-interface and upstream synchronization update.

## Platform interfaces

- Fixed the current Douyin recommendation envelope that could otherwise index a string/list as a map and surface `type 'String' is not a subtype of type 'int' of 'index'`.
- Douyin parsing now accepts current and legacy response shapes, embedded room JSON and missing optional fields; its live probe also requires a real playback descriptor rather than only card metadata.
- Bilibili popularity uses the public `sort=online` ranking source plus deterministic descending client sorting instead of a personalized recommendation order.
- Bilibili room metadata validates signed responses before indexing, refreshes stale WBI keys and performs one bounded retry when the platform rejects the signature.
- Added playback-level live probes for Bilibili quality/CDN descriptors, Huya room/bitrate/FLV-HLS lines and CC's two-step room mapping/playback contract.

## Upstream and regression coverage

- Synchronized and merged upstream through `liuchuancong/pure_live@974f4c32`, including download confirmation, version history and fullscreen viewing-record improvements.
- Preserved the maintained repository's launch refresh, background playback continuity, quality switching, local-first serial build policy and official signing workflow.
- The final gate covers 40 public interface checks across Bilibili, Douyu, Huya, Douyin, Kuaishou, CC, Twitch, SOOP Live and YY Live, in addition to Flutter Analyze and the complete automated test suite.
- Version: `2.9.6+4085`.
- This release publishes Android `arm64-v8a`; Windows, Linux, macOS and iOS remain on their v2.9.4 artifacts.

---

# Pure Live v2.9.5

v2.9.5 build 4084 is an Android stability update for playback quality, platform interfaces and the newly synchronized YY platform.

## Quality and line switching

- Added a shared stable quality identifier and transactional switching: the UI changes only after the target source opens, stale requests are discarded, failed opens keep the previous source, line indices are clamped and duplicate/blank lines are removed.
- Bilibili now reads the server's actual `current_qn`; Huya replaces a stale `ratio` (and removes it for source quality); Douyin joins streams by `sdk_key`; Douyu preserves the platform's opaque rate order instead of numerically sorting it.
- Twitch master variants are parsed as attribute/URI pairs without shared mutable state; Kuaishou, CC, SOOP, YY and IPTV received stable IDs, defensive payload handling and deterministic playback fixtures.
- The fullscreen quality/line dialog now derives its total size from the real option rows. It removes redundant header values, gives the choice buttons the main visual area and only keeps large panes when their content actually needs scrolling.
- A handled playback error finishing after an overlay lifecycle change no longer triggers a second uncaught toast exception.

## Audience metrics and ranking

- CC `webcc_visitor` heat is separated from `vision_visitor/online_num` concurrent viewers.
- Concurrent ranking compares explicit, pending and heat-only tiers before numeric values, then uses stable room identity to stop equal cards from jumping during refresh.
- Douyin no longer treats cumulative `total_user` fields as current online viewers; SOOP joins the supported concurrent-platform settings.

## Douyu playback

- Synchronized the upstream baseline through `liuchuancong/pure_live@a161a324` with real merge ancestry, including the latest version-history transport/parser update.
- The H5 stream request now uses one session DID and consistent browser headers, refreshes stale signing descriptors, and performs one bounded retry.
- Quality and CDN parsing tolerates partial response shapes, removes duplicate lines, and validates the final decoded stream URL.
- Actual media requests now receive Douyu Referer, Origin, User-Agent and matching DID cookies on every player backend.
- The public interface gate now verifies signing, H5 metadata, CDN selection, and a real FLV header instead of stopping at the encryption descriptor.

## YY integration

- Added categories, room lists, search, room status, quality/line playback, danmaku and local Cookie settings from upstream.
- Replaced the native JavaScript runtime used for a simple page literal with a pure-Dart parser, keeping Android and desktop packages smaller and deterministic.
- Upgraded public URLs to HTTPS and switched room refresh to the direct authoritative room-detail endpoint.
- Corrected live/anchor search contracts, live-state parsing, room identifiers, and YY Cookie status display.

## Search stability and discovery

- Replaced the search page's auto-centering `TabBar` with a dedicated bounded platform strip. It remains horizontally scrollable when platforms exceed the screen width, but the first and last item are now hard boundaries and the selected state cannot drift away from the active platform.
- Keeps one stable adapter snapshot for the page, preserving pagination cursors and preventing platform order/index mismatches while results are loading.
- All-platform search now publishes each completed platform immediately, caps an individual request at 12 seconds, deduplicates results, and isolates partial failures instead of blocking the whole grid behind one slow endpoint.
- Added YY native search coverage, respected requested page sizes for Bilibili, Douyu, Huya, CC and SOOP, and kept IPTV local search separate from web continuation.
- Web result detection now supports Bilibili, Douyu, Huya, Douyin, Kuaishou, CC, Twitch, SOOP and YY, rejects navigation/lookalike URLs, preserves the detected platform identity, and suppresses duplicate room prompts.

## Regression coverage and delivery

- Multiview sorting now understands localized ten-thousand/hundred-million suffixes as well as values such as `18.3k`.
- Added deterministic Douyu/YY/search parser and bounded-scroll tests plus 36 public probes across Bilibili, Douyu, Huya, Douyin, Kuaishou, CC, Twitch, SOOP and YY.
- Version: `2.9.5+4084`.
- This release publishes Android `arm64-v8a`; Windows, Linux, macOS and iOS remain on their v2.9.4 artifacts.
- No ADB or phone automation was used; the signed APK is ready for independent device acceptance.

---

# Pure Live v2.9.4

v2.9.4 build 4083 是上游多画面同看、录制数据保护、平台播放兼容和长时间资源治理的全平台稳定更新，发布到 `wzgrx/pure_live`。

## 上游同步与多画面

- 合并发布时最新的 `liuchuancong/pure_live@99ef708c`，吸收多画面同看、斗鱼/抖音纯 Dart 签名、语言切换、Windows MSIX 数据路径、视频显示模式和房间增量合并；保留维护分支已有的弹幕、PiP、高刷新率、音频模式和横屏交互增强。
- 修正最新上游合并后的三个边界：迟到的旧房间详情先通过“代次 + 平台 + 房间号”围栏再更新；稀疏响应不再把关注房间误写为下播或覆盖本地标签；视频适配由各播放器内核直接应用，避免等待尺寸造成首帧空白及 Windows 纹理按源分辨率过度分配。
- 多画面音频焦点改为串行“最后一次选择生效”，快速连续切换不再因原生静音 Future 乱序留下多个声源。
- 播放器暂停失败时仍进入内核销毁，避免某一格释放异常阻断其他格；移动端限制 4 路同时解码，桌面端保留 9 路上限。

## 数据安全与长时间稳定性

- 修复上游 #778：自定义录制路径只作为父目录，录制、容量统计和清理统一限定在带所有权标记的 `PureLiveRecords` 子目录，选择“下载”等公共目录也不会删除无关文件。
- 自动容量限制改为一次递归快照按时间清理，覆盖平台/主播/日期多层目录；文件轮转、锁定或空目录均以有限步骤结束，消除持续循环和 CPU 异常升高风险。
- 调试日志保留最近 2000 条，EPG 模糊匹配缓存按数据源隔离并限制 1024 项；房间详情失败只回退到身份相同的当前房间，且不再原地改写活动状态。

## 关注、搜索与弹幕显示

- 修复上游 #784：关注页当前标签在响应构建阶段完成订阅，“全部 → 自定义 → 全部”可稳定往返，筛选数据与 ChoiceChip 选择态保持一致。
- 搜索结果在 Android/iOS 恢复短列表和长列表回弹；平台分类栏保持起始对齐和有界横向滚动，不再把整行拖离首尾位置。
- 修复上游 #783：弹幕原生描边由四次偏移叠加恢复为单次清晰绘制，减少重复绘制；低透明度轮廓使用连续伽马曲线，在亮色画面上保留更多边缘对比度。

## 平台接口与依赖

- 快手同时解析房间页 `{h264/hevc}` 和推荐/录播列表 `adaptationSet` 结构，同清晰度的多 CDN 地址合并为线路；房间页明确下播但卡片带有效录播地址时进入录播模式。
- 斗鱼与抖音签名统一迁移到纯 Dart，移除 JS 运行时及其桌面原生插件；斗鱼加密描述符按 Unix 秒缓存并合并并发刷新，避免每次画质/线路切换重复请求。
- 抖音签名 URL 不再改写调用方参数，保留基础 URL 既有查询；随机令牌复用单个安全随机源。新增斗鱼加密描述符和快手播放结构接口探测。
- 快手 #782 的后续反馈确认“全部无法播放”来自旧 Cookie 触发平台风控，用户刷新 Cookie 后恢复；直播/录播双结构解析继续覆盖真正的数据形状差异。
- 直接依赖已复核到 Flutter 3.47 可解析的最新兼容组合；固定 Git 依赖均再次与远端 HEAD 对齐。`dynamic_color` 维持兼容 Flutter Material `ColorScheme` 的 1.9.0 系列。
- Windows ZIP/安装程序改用当前 CMake 安装清单与必要 runner 运行时白名单，排除增量输出遗留的 QuickJS DLL、旧插件资源和开发文件。

## 交付范围

- 版本更新为 `2.9.4+4083`。
- Android arm64-v8a、Windows x64、Linux x64、macOS Universal 与 iOS arm64 按构建资源策略分阶段串行完成正式构建和校验。
- 完整门禁、近期 Issue 结论、平台产物及 SHA-256 记录见 `docs/STAGE_UPDATE_2_9_4.md`、`docs/ISSUE_AUDIT_2026_08_24.md` 和 Release 元数据。

---

# Pure Live v2.9.3

v2.9.3 build 4082 是横屏画质与线路面板内容驱动布局专项 Android 更新，发布到 `wzgrx/pure_live`。

## 画质与线路布局

- 取消手机横屏面板中画质区与线路区固定 `4:3` 比例；画质区改为按真实选项行数计算高度，线路区使用全部剩余空间。
- 四个画质在常见横屏宽度下使用均衡的 `2×2` 排列，不再出现三项占第一行、一项占第二行并留下大片空白的情况。
- 五至六个画质继续使用三列；更窄面板自动退化为两列或一列，保证文字和点击区域完整。
- 小高度视口中画质区最多占三行，同时为线路列表保留最低可操作高度，避免底部线路被裁切。

## 状态与回归

- 画质和线路的当前项统一使用状态色、强调边框和勾选图标，标题区继续展示当前选择。
- 新增常见四画质、多画质、小高度视口及选项列数平衡测试，覆盖内容高度、剩余线路空间和自适应列数边界。
- 正式交付执行 Flutter Analyze、完整自动化测试与公开接口探测，结果和构建记录随 Release 元数据一并保留。

## 交付范围

- 本轮仅构建并发布 Android `arm64-v8a` Release；其他平台继续使用 v2.9.0 对应资产。

---

# Pure Live v2.9.2

v2.9.2 build 4081 是横屏右侧半屏布局二次优化与本地弹幕实时预览专项 Android 更新，发布到 `wzgrx/pure_live`。

## 画质与线路

- 右侧半屏面板压缩总标题、分区标题、外边距、分区间距与选项卡高度，把纵向空间优先交给蓝光、超清等画质和线路内容。
- 半屏宽度允许时由双列提升为三列，每个选项保持当前状态和切换反馈，可见项目数量明显增加。
- 画质与线路仍共用原地切流逻辑，切换期间保留顶部进度提示，不重建直播页。

## 直播记录

- 缩小面板顶部工具栏以及“已开播 / 录播 / 观看记录”标签栏，减少顶部空白。
- 双栏卡片底部信息区由 48 px 收紧为 36 px，并依据可用高度动态计算卡片尺寸，横屏手机首屏可完整容纳 2×2 四张直播卡片。
- 平台、热度/观看时间、标题和主播信息继续保留，封面仍是卡片视觉主体。

## 本地弹幕样式

- 横屏面板固定占右侧约半屏，内部改为左右双栏：左侧常驻实时预览，右侧独立滚动全部设置。
- 颜色、字号、字体、透明度、字距、粗斜体、描边、阴影和位置修改即时反映到左侧；滚动弹幕速度也以真实循环动画即时呈现。
- 实时预览动画仅在编辑器打开期间运行，不增加正常播放界面的持续渲染负担。

## 验证与交付

- 增加半屏双栏、三列画质/线路和四卡完整可见的布局边界回归；Flutter Analyze 0 issue、249/249 项自动化测试与 27/27 项公开接口探测通过。
- 本轮仅构建并发布 Android `arm64-v8a` Release；质量门禁和正式签名结果随 Release 元数据记录。

---

# Pure Live v2.9.1

v2.9.1 build 4080 是横屏半屏内容面板与本地弹幕个性化专项 Android 更新，发布到 `wzgrx/pure_live`。

## 横屏内容优先面板

- 清晰度/线路、直播记录和本地弹幕样式统一从屏幕右侧打开，动态占用约半屏宽度，保留左侧直播画面作为操作参照。
- 清晰度与线路卡片压缩标题和留白，质量区域按 4:3 获得更多内容空间；切换状态继续使用原地切流和顶部进度提示。
- 直播记录在半屏宽度内使用双栏 16:9 封面卡片，平台与观看时间覆盖在封面上，标题和主播信息收敛到紧凑底栏。

## 本地弹幕个性化

- 模板由 4 组扩展到清爽、醒目、霓虹、极简、底部字幕和赛博 6 组，主色扩展为 12 种，并提供独立描边/阴影效果色。
- 新增滚动、顶部固定、底部固定三种位置；增加系统/圆润/衬线/等宽字体、透明度、字间距、粗体、斜体、描边颜色和宽度。
- 新增阴影/微光颜色、模糊、偏移，以及固定弹幕 2–10 秒停留时间；预览会跟随位置和全部效果实时变化。
- 同一持久化编辑器复用于竖屏、横屏、小窗、本地弹幕发送框、本地互动页和设置页，修改后无需重启。

## 渲染与验证

- `flame_barrage` 支持每条消息独立的字体、位置、透明度、字距、描边、阴影和固定时长；文字效果编译进有界 Paragraph/Picture 缓存，不增加逐帧离屏图层。
- 固定弹幕轨道记录独立释放时间，避免不同停留时长互相占用；主画面与 PiP 使用相同样式映射。
- Flutter Analyze 与本地弹幕、横屏布局、弹幕缓存定向回归完成；本轮仅构建 Android `arm64-v8a` Release。

---

# Pure Live v2.9.0

v2.9.0 build 4079 是清晰度切换、横屏全屏控制层、本地弹幕样式和上游播放稳定性整合的全平台正式更新；发布到 `wzgrx/pure_live`。

## 上游同步与播放稳定性

- 真实合并上游 `liuchuancong/pure_live@25f833ea`，吸收从录制页返回直播时延迟挂载视频层的崩溃修复，并保留维护分支已有播放器生命周期与音频模式优化。
- 清晰度和线路切换改为播放器原地切流：旧流持续播放到新地址解析完成，按请求代次只应用最后一次选择，避免销毁直播页控制器、重复请求房间详情或被默认清晰度异步覆盖。
- 竖屏与横屏共用同一选择状态，切换期间显示明确进度；质量或线路数量变化时自动校正索引并保留可用回退流。

## 横屏界面、历史与本地互动

- 横屏左上角调整为返回、时间和电量，Android 小窗入口移到右上角；直播间切换/历史入口改为响应式双栏卡片，展示平台、主播、状态和最后观看时间。
- 右下角把线路与清晰度合并为横屏专用双栏选择面板，当前项、切换状态与可选线路更加直观。
- 本地弹幕增加预设、颜色、字号、速度、粗体、描边和描边宽度；横屏输入框、竖屏输入、本地互动面板及设置页共享同一持久化配置。
- 观看历史使用“平台 + 房间号”复合身份，保留详情刷新前后的时间元数据并限制为最近 50 条。

## 构建与发布

- 发布资产统一使用 `版本-构建号-平台-架构` 命名；版本更新为 `2.9.0+4079`。
- Android arm64、Windows x64、Linux x64、macOS Universal 与 iOS arm64 按资源策略串行构建和校验。
- 完整质量门禁、接口探测、平台任务、产物哈希和来源提交记录见 `docs/STAGE_UPDATE_2_9_0.md` 与 Release 元数据。

---

# Pure Live v2.8.0

v2.8.0 build 4078 是上游同步、关注状态权威刷新、抖音搜索和桌面播放增强的全平台稳定更新；仅发布到 `wzgrx/pure_live`。

## 上游同步与近期 Issue

- 真实合并上游 `liuchuancong/pure_live@4ca626d9`，吸收抖音搜索、前台恢复刷新开关、Windows PiP 几何校验、RTX VSR 可选项及结构整理。
- 针对 #774，保留逐平台可见下拉动画，并将前台恢复刷新设为新旧配置缺省行为；启动、恢复、定时和手动刷新统一使用权威快照，失败房间进入“状态待确认”，不再继续显示旧开播状态。
- 针对 #775，抖音搜索在匿名原生搜索需要登录时自动回退到公开分区检索；补全匿名 Cookie、Cookie 切换、备用域名、分页、稳定房间身份和下载链接，并增加“三角洲”真实接口探测。
- 针对 #767，继续启用 Windows 可见物理视口纹理限幅与防抖尺寸更新，避免 4K/高 DPI 小窗口维持超过实际需要的源纹理；RTX VSR 保持明确的按需开关。
- 吸收上游最新直播流 seek 调整并消除重复原生属性写入；补齐旧版 Windows 小窗扁平几何字段和播放器归属开关向当前窗口设置的无损迁移。

## 稳定性与构建

- 关注刷新只失效本次核验的平台/标签范围，其他平台卡片和排序保持不动，减少刷新期间的视觉跳动。
- 横屏/全屏弹幕设置面板移除固定深色背景和白色文字，背景、标题、边框、按钮及内部卡片实时继承应用当前浅色、深色或跟随系统主题。
- 保留维护仓库更新源、Windows 覆盖升级 AppId、本机优先构建、Android 正式签名与串行全平台发布策略。
- 版本更新为 `2.8.0+4078`；Android arm64、Windows x64、Linux x64、macOS Universal 与 iOS arm64 按平台串行构建。
- Flutter Analyze 0 issue、236/236 项单元/Widget 测试与 27/27 项公开接口探测通过。
- 完整质量门禁、接口结果、平台任务、产物哈希与运行采样记录见 `docs/STAGE_UPDATE_2_8_0.md` 和 Release 附带元数据。

---

# Pure Live v2.7.0

v2.7.0 build 4077 是最新上游整合、热门页生命周期和全平台交付更新；Android 资产已用关注刷新修复后的源码重新构建，仅发布到 `wzgrx/pure_live`。

## 上游同步

- 真实合并上游 `liuchuancong/pure_live@81ec372a`，保留完整提交关系，后续同步可继续按共同祖先合并。
- 吸收热门页关闭状态、加载代次、平台配置防抖及延迟预热隔离，防止页面销毁或平台列表重建后旧任务继续刷新当前界面。
- 吸收取消关注弹窗路由修复，并进一步让按钮绑定弹窗自己的 `BuildContext`，避免导航转场期间误退直播页面。
- 对上游 Windows 小窗、图片缓存、更新源、应用 AppId、ABI 清单与全平台工作流逐项审查；保留维护版已经验证的位置/大小记忆、跨屏边界恢复、有界图片缓存、覆盖升级 AppId、`wzgrx` 更新源及串行构建策略。

## 稳定性与兼容性

- 热门页控制器在关闭时取消切换计时器、相邻平台预热和设置监听，并以 generation 隔离过期异步结果。
- 平台开关或排序变化后按平台 ID 恢复选中项；控制器按需重建并保持滚动状态，降低快速横滑时的数据竞争。
- 关注页下拉刷新二次加固：改用 `EasyRefresh.builder`，将刷新器提供的滚动物理直接安装到当前平台的唯一纵向列表；Material 刷新头、空列表和短列表均通过真实拖动回归。
- 启动、恢复、定时和手动刷新统一为串行快照事务；冷启动先显示位置稳定的“正在核验”状态，成功结果一次性发布，网络失败保留“状态待确认”，不再沿用上次进程的开播位。
- CC、Twitch、SOOP 使用严格状态刷新语义；虎牙回放进入录播分组，平台返回规范房间号时仍绑定原收藏身份。
- 继续保留播放器、弹幕、PiP 返回、音频/视频切换、首页批量刷新及长时间资源治理的既有回归覆盖。
- 版本更新清单只声明实际发布的 Android `arm64-v8a`，所有下载地址继续指向维护仓库正式 Release。

## 构建与验证

- 版本更新为 `2.7.0+4077`。
- Android arm64、Windows x64、Linux x64、macOS Universal 与 iOS arm64 按资源策略串行构建；最新 Android APK 在本机完成 Flutter/Gradle 编译，远端任务只执行正式证书签名与资产校验。
- Flutter Analyze 0 issue、229/229 项单元/Widget 测试及 26/26 项公开接口探测通过。
- 完整质量门禁、平台任务、产物哈希与运行采样记录见 `docs/STAGE_UPDATE_2_7_0.md` 和 Release 附带元数据。

---

# Pure Live v2.6.0

v2.6.0 build 4076 是上游同步、近期 Issue 修复、播放器与长时间资源治理的阶段稳定版；仅发布到 `wzgrx/pure_live`。

## 上游与近期问题

- 真实合并上游 `liuchuancong/pure_live@c3ae29bb`，保留其关注刷新、房间详情补全、版本历史容错和弹幕模板状态修复。
- 吸收上游 BetterPlayer 尺寸修复和 Windows 小窗记忆入口；合并时保留非 Exo 首帧防死锁、iOS 新配置 IJK 默认值、维护仓库更新源及完整位置/大小越界校正。
- 修复链接解析或普通入口进入直播间后关注状态不更新：关注按钮直接观察持久化收藏列表，并统一使用“平台 + 房间号”身份。
- 修复多文件字体目录不一致、重启后选择丢失、弹幕字体未即时注册；下载完成后多字重字体进入明确选择页。
- Windows 小窗增加记忆开关与重置入口，保存用户调整后的位置和大小；默认在应用所在显示器打开，跨显示器恢复时保持可见，并与主窗口尺寸持久化分离。
- 醒目留言列表实时观察消息集合，切换直播间时用房间代次隔离异步结果；列表边界改为有界滚动物理效果。
- iOS 新安装默认使用已有画面的 IJK 内核，并通过原生通道回报设备最高刷新率；已有用户的播放器选择保持不变。
- 修复 Xcode 26 下隐式 Flutter 引擎插件 registrar 为可选值时的 iOS 编译错误，重新完成 unsigned app 与 TrollStore IPA 构建。

## 播放、画面与资源

- 非 Exo 播放器原生纹理先挂载再等待真实视频尺寸，消除强制销毁、换核或重新进入后的初始化死锁和持续转圈。
- 画面适配只更新呈现尺寸，不再通过重新请求数据源实现缩放；Windows 高 DPI 下按可见视口约束纹理合成面积。
- 首页封面、头像和分区图片恢复有界解码缓存，取消每张卡片首次挂载时主动删除磁盘缓存，减少重复网络、解码、CPU 与卡片跳动。
- 直播间、弹幕、醒目留言、PiP 和播放器继续使用房间/加载代次、队列上限及显式订阅释放，阻止旧房间异步结果回写当前会话。

## 依赖与构建

- `scrollview_observer` 更新至 1.27.1；其余 Dart 直接依赖已处于解析器可升级的最新兼容组合。
- `dynamic_color` 保持 1.9.0：2.x 的 `material_ui.ColorScheme` 与当前 Flutter Material 类型边界不同，待完整主题迁移后单独升级。
- Android 保持官方 AGP 9.3.1 推荐的 Gradle 9.5.0、Google Services 4.5.0、compile/target SDK 37 与 Built-in Kotlin。
- Android 本轮只构建正式签名 `arm64-v8a`；Windows x64、Linux x64、macOS Universal 与 iOS arm64 按平台串行构建。
- Flutter Analyze 0 issue、224 项单元/Widget 测试与 26/26 项公开接口探测通过；各平台产物结果写入 `docs/STAGE_UPDATE_2_6_0.md` 与 Release 元数据。
- Windows Release 完成 6 分钟隔离实例烟雾采样，工作集保持平稳；全部平台产物均复核 SHA-256 与归档结构。

---

# Pure Live v2.5.3

v2.5.3 build 4075 是竖屏弹幕导航约束与横屏小窗快捷入口专项更新，来源为合并后的 `master`。

## 竖屏弹幕功能栏

- “弹幕列表 / 醒目留言 / 弹幕设置 / 屏蔽管理”由自由横向滚动改为四栏等宽固定布局。
- 标签栏本身不再被连续拖离原位；对应内容页仍可在第一页到最后一页的有效范围内左右切换。
- 较窄屏幕使用紧凑标签间距，四项入口保持完整、稳定且容易点击。

## 横屏小窗入口

- Android 横屏全屏控制栏左上角在返回按钮旁新增小窗图标。
- 横竖屏复用既有 PiP 入口与播放器生命周期，避免产生第二套状态切换逻辑。
- Windows 原有窗口模式入口保持不变。

## 构建与验证

- 新增固定标签布局、拖动约束及 Android 横屏小窗动作顺序测试。
- Flutter 3.47.0 / Dart 3.13.0；217 项单元与 Widget 测试全部通过。
- 构建使用本机资源互斥、Gradle 增量缓存与正式签名记录；Android 本轮仅生成 `arm64-v8a` Release。
- Windows 与其他平台继续使用 v2.5.0 对应构建。

---

# Pure Live v2.5.2

v2.5.2 build 4074 是启动关注刷新、动态高刷联动、弹幕帧同步和竖屏列表手势专项更新，来源为合并后的 `master`。

## 启动刷新

- 关注核验在 Flutter 首帧后立即开始，与启动页动画重叠；启动页结束时仅保留 350 ms 有界等待，慢平台继续在后台完成。
- 哔哩哔哩、斗鱼、虎牙、快手新增轻量元数据刷新路径，收藏卡片不再提前请求播放线路、签名和弹幕凭据。
- 同一刷新批次复用平台适配器、设备 Cookie、WBI 密钥和会话初始化；请求继续由 4 路有界异步 I/O 调度。

## 刷新率与弹幕

- 通用界面刷新率统一为省电、均衡、最高（设备上限）三档；切换后立即作用于现有界面和自动弹幕渲染器。
- 省电档主画面/小窗弹幕上限为 60/30 FPS，均衡档为 60/60 FPS，最高档两者跟随当前设备检测上限。
- 主画面与小窗保留各自的自动跟随开关；关闭后使用该画面的独立手动 FPS，不影响全局档位和另一个画面。
- `flame_barrage` 从周期计时器切换为 Flutter `Ticker`，弹幕推进对齐 vsync，并按真实经过时间保持统一移动速度。

## 列表手势与验证

- 手指按下竖屏弹幕列表时立即使排队中的自动追尾失效，避免帧尾 `jumpTo` 取消快速上滑。
- 自动恢复前重新核对活动指针、滚动状态和列表版本；保留反向懒构建与“新消息/回到最新”入口。
- Flutter 3.47.0 / Dart 3.13.0；Flutter Analyze 0 issue，215 项单元与 Widget 测试全部通过。
- Android `arm64-v8a` 正式签名更新；Windows 与其他平台继续使用 v2.5.0 对应构建。

---

# Pure Live v2.5.1

v2.5.1 build 4073 是关注页平台横滑与收藏完整性专项更新，来源为合并后的 `master`。

## 关注页与平台横滑

- 当前平台筛选为空时继续保留完整 `TabBarView`，滑到零结果平台后仍可横滑返回。
- 平台控制器改为按平台 ID 保持选中项；平台显示开关或排序变化时同步视觉页面、数据索引和独立纵向滚动位置。
- 收藏标签条移到分页外层，减少两个同方向横向列表争抢手势。
- 空结果区分“尚未关注”和“当前开播筛选为空”，保留下拉刷新，并可直接进入未开播列表。

## 刷新与数据完整性

- 平台、开播状态和标签重置合并为单次筛选事务；收藏快照未变化时跳过延迟的第二次全量筛选与排序。
- 收藏、标签、房间刷新和卡片状态统一使用“平台 + 房间号”复合身份，修复不同平台相同房间号互相覆盖的问题。
- 启动和备份导入时规范化平台 ID 的大小写与首尾空白，并迁移旧房间号标签映射。

## 构建与验证

- Flutter 3.47.0 / Dart 3.13.0。
- Flutter Analyze：0 issue。
- 211 项单元与 Widget 测试全部通过。
- Android arm64-v8a 正式更新；Windows 与其他平台继续使用 v2.5.0 对应构建。

---

# Pure Live v2.5.0

v2.5.0 build 4072 聚焦首页首刷速度、设备刷新率分档、Windows 视频纹理资源边界和可复现本机构建，并以真实 merge 同步上游至 `b84a847d`。

## 首页与列表

- 收藏核验从“固定批次整批等待”改为 4 路有界异步工作池；完成一个网络任务后立即领取下一个，慢平台不再阻塞同批后续房间。
- 房间超时从 12 秒收紧为 10 秒；后台版本检查延后到首帧后 2 秒，降低启动时的带宽与调度竞争。
- 刷新结果完整后一次性发布，保留旧卡片、稳定排序和滚动位置，避免加载期间卡片分批插入和跳动。
- 修复首次收藏快照为空时被“相同空列表”短路的问题；空收藏现在立即进入空状态，不再让隐藏的无限加载动画持续占用 Windows CPU/GPU。
- 热门接口短时失败时保留上一份可用快照；分区卡片尺寸和切换房间滚动物理效果同步上游修复。

## 刷新率与功耗

- 新增省电、均衡、高性能三档刷新率模式；设置页展示当前刷新率、设备最高刷新率和各档耗电提示。
- 新安装默认省电，由系统动态选择刷新率；均衡在触摸、滚动和转场时请求最高刷新率，稳定 1.5 秒后释放；高性能在应用前台持续请求最高刷新率。
- 旧版高刷开关自动迁移为均衡档；播放器视频帧率与界面刷新率保持独立，避免低帧率直播重复渲染。

## Windows 与播放器

- Windows MediaKit 原生视频输出按可见控件的物理像素尺寸设置，保持源视频比例且不超过源分辨率。
- 窗口尺寸变化使用 180 ms 去抖，降低拖动、缩放和小窗场景的纹理重建频率。
- 保留既有播放器/弹幕会话代次、PiP 返回重订阅、长时间队列上限与资源释放回归。

## 依赖、构建与上游

- 更新 `ffmpeg_kit_extended_flutter` 0.6.0、`flutter_color` 2.1.1；`dynamic_color` 使用 Flutter 3.47 可直接兼容的 1.9.0。
- FFmpeg builders v0.11.0 的 Android AAR 和 Windows Native Assets ZIP 在构建前执行 SHA-256 校验并复用持久缓存。
- `tool/local_ci.ps1` 在一次锁文件解析后使用 `--no-pub` 完成 Analyze/测试，减少重复网络和原生资产准备。
- 同步上游 `b84a847d`，同时保留维护仓库发布地址、Windows 数据目录和升级迁移逻辑。

## 构建目标

- Flutter Analyze 0 issue、208 项单元/Widget 测试、26/26 平台公开接口探测通过。
- Android `arm64-v8a` 正式安装包。
- Windows x64 便携包与可选安装程序。
- Linux x64、macOS Universal、iOS arm64 设备归档由对应系统的阶段构建补齐。
- 同一 Release 提供 `SHA256SUMS.txt` 与 `BUILD_METADATA.json`，记录源码提交、签名状态和平台来源。

完整设计和验收边界见 [v2.5.0 阶段稳定版](docs/STAGE_UPDATE_2_5_0.md)。

---

# Pure Live v2.3.0

v2.3.0 build 4070 聚焦系统画中画返回后的弹幕会话、高刷设备 CPU、全局滚动流畅度，以及 Windows/Android 长时间运行的资源边界；维护分支已同步至上游 `e51df666`，包含 SC、平台目录整理、虎牙增强、SOOP/Twitch 和播放器/导航修复，并修复同步后斗鱼同包普通弹幕与 SC 解析回归。

## 弹幕生命周期

- 修复 GetX 响应式流桥接的真实断点：旧实现创建广播流时就注册上游监听，却把返回的注销函数交给 `onCancel`；竖屏列表进入 PiP 被销毁后，最后一个监听者会永久注销上游，随后重建只能订阅到仍打开但已断流的广播控制器。新实现严格在 0→1 个监听者时挂载上游、1→0 时卸载，取消后重订阅继续收到更新。
- Android 从系统画中画返回全屏或竖屏时，由持续存活的直播控制器发布恢复 revision；恢复先检查同房间传输健康度，健康连接保留，已断开的连接才原位重建。
- 弹幕列表重建后在首帧重新获取当前 500 条快照、提交待处理批次并恢复实时跟随；Android 只有存在真实触摸指针时才把拖动通知视为用户上滑，转场遗留通知不再暂停列表。
- 弹幕列表仅在 80 ms UI 批次落地时复制可见快照；本地消息仍立即同步到列表与画面。
- 弹幕文本解析、段落布局、图片和表情 Token 缓存全部改为有界 LRU；主画面和小窗分别使用符合轨道规模的缓存/对象池上限。

## 启动刷新与横屏交互

- 收藏房间在控制器初始化阶段先清除上一进程遗留的开播位，再立即核验；每个有界批次先更新内存状态，至少 20 个房间再合并持久化，兼顾新鲜度与滑动流畅度。
- 应用在后台停留超过 15 秒后返回，刷新当前热门/分区平台；单房间请求设置 12 秒上限，单个平台异常不会阻塞其余收藏。
- 横屏弹幕设置改为靠右紧凑侧栏，不再把小窗的长设置表单重复塞入直播设置；模板和数值继续实时作用于画面。
- 全屏底部左右控制组之间增加本地弹幕输入，沿用当前房间代次和 2 秒投递队列，防止延迟消息串入下一直播间。

## 性能与稳定性

- 切换清晰度、线路或刷新播放器前完整释放旧 `VideoController` 的弹幕引擎、计时器和订阅，修复 Windows 多次换线后的资源累积。
- 修复音量隐藏和配置去抖计时器未保存引用的问题；所有播放器计时器在销毁时统一取消。
- media_kit/mpv 直播前向缓存限制为 32 MiB、回看缓存限制为 4 MiB，保留 2 秒预读；该预算仍可覆盖约 8 秒的 32 Mbit/s 码流，同时缩短原生内存预热爬升。
- 同一 Bilibili 实时房间对照采样中，32/4 MiB 预算把 private bytes 峰值从 951.5 MiB 压到 738.2 MiB；6.5 分钟结束时 private bytes/工作集分别少 30.3/35.4 MiB，最后一分钟 private bytes 回落 5.1 MiB，句柄和线程没有单调增长。
- Windows 恢复鼠标拖动滚动，连续滚轮脉冲使用可重定向的 Chromium EaseInOut 轨迹合并；主画面弹幕限制高峰入场频率、可见数量和过期队列。
- 应用 UI 继续请求设备最高刷新率；自动弹幕渲染主画面限制 60 FPS、小窗限制 30 FPS，手动模式仍支持最高 240 FPS，避免视频、UI 与弹幕三套高频时钟同时拉满 CPU。
- 首页/设置阶段不再提前创建 MediaKit 原生播放器；FFmpeg、录制、解析与账号服务按真实功能入口加载，空 SC 列表也不再保留每秒唤醒定时器。
- Flame 弹幕引擎在等待队列和活动弹幕都为空时停止显示刷新循环，收到新弹幕再唤醒；热门卡片的加载占位改为静态图标，网格恢复独立重绘边界。
- 直播页和二、三级控制器显式释放全局 GetX Worker、滚动/刷新控制器、DLNA/FFmpeg 订阅与表情解码 Codec，避免关闭页面后仍保留整棵播放器和消息缓存。
- 播放器适配器公开类型安全的引擎/原生播放器访问接口；导航设置至少保留一个主页入口，修复全部隐藏后主页空白且无法返回设置的问题。
- 进入录制中心前先等待弹窗退场并卸载一帧原生视频层，返回后恢复同一直播会话，修复 media_kit 在路由叠加时的崩溃与画面遮挡竞态。

## 构建与核验

- Flutter 3.47.0 / Dart 3.13.0；Built-in Kotlin 审计和 Flutter Analyze 零问题。
- 189 项单元/Widget 测试及 26/26 平台公开接口探测通过。
- Android arm64 与 Windows x64 由本机构建；每个产物的提交、签名类型、ABI、版本与 SHA-256 记录在 `BUILD_METADATA.json` 和 `SHA256SUMS.txt`。

---

# Pure Live v2.2.0

这是播放器生命周期、弹幕稳定性与 Windows 桌面体验的阶段性稳定更新，并同步上游 `2f553c8b` 的弹幕字体粗细和相似文本过滤。

## 音频/视频无重开切换

- 音频与视频模式复用同一播放器、直播地址和纹理；前台保留视频热状态，优先实现即时返回。
- 后台立即停用视频轨以节省解码、GPU 和电量，回到前台后静默预热。
- 深度恢复使用最新目标栅栏、首帧合成宽限和有界等待；恢复期间显示可操作的渐变音频卡片和明确进度，不再用黑屏或整页转圈遮挡操作。
- 连续点击、房间重进、悬浮窗交接、横竖屏和后台恢复统一进入串行状态机，解决白屏、黑屏、永久加载和控制器错配。

## 弹幕与设置

- 竖屏、横屏和全屏共用同一弹幕设置界面，所有参数实时作用于画面。
- 主画面和小窗支持字体粗细；最佳/舒适/高密度模板及自定义模板同步保存和恢复粗细值。
- 增加精确重复文本合并和相似弹幕过滤；本地弹幕不参与过滤。
- 相似过滤的模糊比较上限固定为每条 96 次，屏蔽列表改用懒构建 Sliver，降低高弹幕量和长列表滚动时的主线程尖峰。

## Windows 与稳定性

- Windows 支持带独立数据目录的多实例启动，并防护非法实例 ID 和路径穿越。
- 优化二、三级页面鼠标滚轮、并行 Release 编译和非必要原生启动任务。
- 保留可选安装目录与安装目录 `AppData` 数据策略；旧配置、关注和缓存继续按升级迁移规则处理。
- 录制意外退出后按配置恢复监控；GitHub 更新源支持官方直连并限制镜像探测时间。

## 验证

- Flutter 3.47.0 / Dart 3.13.0；Built-in Kotlin 审计和 Flutter Analyze 零问题。
- 151 项单元/Widget 测试及 26/26 平台公开接口探测通过。
- Android 16 / 120 Hz arm64 真机覆盖安装，完成视频/音频重复切换、前台长驻、后台省电和回前台恢复回归。

---

# Pure Live v2.1.8

本版本撤销音频模式切换时销毁并重建原生播放器的高风险链路，修复点击耳机后持续加载、按钮锁死，以及音频模式返回/小窗重进后播放器状态错乱。

## 音频模式生命周期

- 音频/视频模式改为在同一个播放器与直播流上切换视频轨道，不再重新请求地址、关闭 CDN 流或重建 MediaCodec。
- 切换期间保留房间、弹幕、手势和播放器监听，不再调用会永久移除错误/音量/电池订阅的 `clearListener()`。
- 页面不再进入整块播放器加载态；原生轨道切换和媒体服务绑定均有 5 秒上限，失败后恢复原模式并释放按钮锁。
- `AudioService` 初始化改为共享同一个可完成 Future；初始化异常会传递给所有等待者并允许下次重试，不再以轮询方式永久等待空 handler。
- 退出直播统一经过媒体服务停止与播放器关闭流程，音频模式不再绕过媒体服务清理。

## 回归门禁

- 新增播放器身份、直播地址复用、超时回滚和按钮解锁测试。
- 正式包发布前必须完成 Android 真机“视频→音频→视频、返回→小窗→重进、连续重复点击”验收。

---

# Pure Live v2.1.6

本版本修复 Android 音频模式与视频模式反复切换后播放器区域变成灰白错误占位，以及音频模式退到桌面或锁屏后需要从通知栏再次点播放的问题。

## 音频/视频模式切换

- 模式切换由房间级局部防抖升级为播放器级串行队列；切换过程中收到多次操作时合并为最后一次目标状态，避免多个播放器初始化与销毁交叉执行。
- 先从 Flutter 组件树移除旧视频组件，等待原生 Surface 脱离后再销毁 MediaCodec/播放器，避免已销毁的视频控制器继续参与构建并触发发布模式灰色 `ErrorWidget`。
- 单次播放器构建固定使用同一个播放器引用，并校正历史画面适配索引；异步销毁无法再在外层空值检查与内层视频构建之间插入，触发空值断言。
- 新控制器暴露可等待的初始化任务，队列在播放初始化结束前保持占用；播放器硬销毁同时作废旧会话，迟到结果不会重新绑定已销毁的播放器。
- 重播保留当前音频模式，不再因重试路径遗漏 `audioOnly` 状态而意外切回视频。

## 后台音频（issue #750）

- 后台播放策略显式包含“当前房间处于音频模式”，即使通用后台播放开关关闭，主动切入音频模式后退到桌面或锁屏也会继续播放。
- 前台生命周期不再对允许后台播放的流主动调用 `resume()`，避免把用户手动暂停的直播错误恢复。
- 通知栏媒体会话、CPU/Wi-Fi 保活与 Flutter 生命周期共用同一后台策略；播放器重绑定改为可等待操作，并消除音频会话尚未初始化完成的竞争窗口。

## 验证

- Flutter 3.47.0 / Dart 3.13.0，Built-in Kotlin 审计、Flutter Analyze、完整自动化测试与公开接口探测。
- Android 16 / ColorOS 真机覆盖安装，执行连续音频/视频切换、退到桌面和媒体会话状态回归。

---

# Pure Live v2.1.5

本版本集中修复本地弹幕投递、Android 弹幕列表阅读、弹幕模板状态和 Windows 鼠标滚轮顿挫，并从同一源码提交重新生成全平台安装包。

## 本地弹幕与列表阅读

- 本地用户发送弹幕后等待 2 秒，由同一投递回调同步加入弹幕列表和直播画面；播放器启动或短暂缓冲期间也保留本地画面弹幕。
- 待发送消息绑定当前房间代次，切换直播间或关闭控制器时统一取消，避免延迟消息进入其他直播间。
- Android 竖屏列表在第一次真实手指拖动时立即暂停自动跟随，不再等待移动超过固定距离；阅读期间冻结可见快照并累计新消息数量。
- 程序自动滚动不会误触发阅读暂停；回到底部或点击“回到底部”后一次同步当前消息。

## 弹幕模板

- “最佳观看、舒适、高密度、默认”改为根据当前实际区域、速度、字号、描边、透明度和动态 FPS 参数计算选中状态。
- 切换模板后选中项立即跟随；手动调整任意参数后清除模板选中，解决操作结果与界面标记不一致。

## Windows 平滑滚动

- Windows 离散鼠标滚轮增量使用 Chromium Impulse 动画轨迹，连续滚轮输入合并到同一目标，减少逐格跳变造成的顿挫。
- 首页、热门、分区、收藏、搜索、直播弹幕列表、节目单和弹幕设置页统一接入；Android 触控继续使用原生滚动控制器。
- Windows 安装程序继续支持选择其他磁盘，便携包和安装器均保持安装目录 `AppData` 数据策略。

## 验证与构建

- Flutter 3.47.0 / Dart 3.13.0，Built-in Kotlin 审计与 Flutter Analyze 零问题。
- 92 项单元/Widget 测试及 26/26 平台公开接口探测通过。
- Android arm64、Windows x64、Linux x64、macOS universal 和 iOS arm64 设备归档从 v2.1.5 源码重新构建；Android 使用正式持久签名。

---

# Pure Live v2.1.4

这是一次阶段性全平台更新：同步上游 `5d3e526a` 的 SOOP Live 当前播放与链接兼容修复，并汇总 Bilibili 热门封面、Windows 高刷新率、桌面交互性能、安装目录数据迁移和跨平台构建工程。

## 上游同步与平台接口

- SOOP Live 同步当前 `player_live_api`、RMD/CDN 地址分配、聊天室端口和播放令牌逻辑，并同时识别 `sooplive.com` 与 `sooplive.co.kr` 链接。
- Bilibili 热门由持续触发 `-352` 风控的旧分区接口切换到当前匿名推荐接口，提供有界重试、独立匿名回退和响应结构校验。
- 推荐分页增加房间去重、无进展终止和最大请求数；固定批量或重复响应不会生成重复卡片或无限补页。
- Bilibili 图片域名补齐浏览器请求头；房间、头像与分区封面统一使用稳定磁盘缓存键，避免刷新时间戳造成重复下载与缓存膨胀。

## Windows 高刷新率与流畅度

- 原生 Runner 读取窗口所在显示器的分辨率、当前刷新率、同分辨率最高刷新率与支持列表；跨显示器或显示模式变化后自动刷新。
- 本机 3840 × 2400 / 200 Hz 已正确识别。Flutter 渲染跟随 Windows 垂直同步，不在应用内强制修改系统显示模式。
- Windows 次级页面使用轻量前进转场，滚动统一桌面夹持物理模型，拖动时自动收起键盘。
- 修复收藏页在响应式重建中重复注册平台切换监听器的问题，减少运行时间增长后的切页和刷新抖动。
- 头像取消列表批量淡入动画，封面复用稳定缓存；窗口移动时先做轻量显示器身份判断，避免每个移动消息枚举全部显示模式。

## 安装、数据与全平台构建

- Windows EXE 保留目录选择和安装目录 `AppData`；设置、关注、历史、IPTV、录制与缓存继续支持旧安装位置合并和迁移前回滚备份。
- Android 保持正式包名 `com.mystyle.purelive`，提供 arm64-v8a 持久签名 APK，可覆盖旧正式版。
- 构建矩阵包含 Android arm64、Windows x64 EXE/便携包、Linux x64、macOS universal ZIP/DMG 与 iOS arm64 未签名设备应用归档。
- 阶段工作流统一使用带 build number 的规范化附件名，普通提交不自动触发跨平台构建。

## 验证

- Flutter 3.47.0 / Dart 3.13.0，Built-in Kotlin 审计与 Flutter Analyze 零问题。
- 82 项单元/Widget 测试、26/26 平台公开接口探测通过。
- Windows x64 release、本机高刷新率信息、Bilibili 热门页与封面完成编译和界面烟雾验证。

---

# Pure Live v2.1.2

本版本是 Windows 数据安全与流畅度专项更新，重点解决换盘安装、从 2.0.x/2.1.1 升级后关注丢失，以及桌面端列表、切页和窗口缩放时的卡顿。已同步上游 `222b3bfb`。

## Windows 安装与集中数据

- EXE 安装向导保留目录选择页，可安装到 C 盘之外的可写目录，并统一使用当前稳定 AppId。
- Hive 配置、关注、历史、屏蔽规则、IPTV、录制、图片/表情/插件缓存和应用临时文件统一收口到 `{app}\AppData`。
- `path_provider`、`shared_preferences`、IPTV/EPG 同步临时文件和录制缓存共用安装目录路径，避免持续在系统盘分散业务数据。
- 卸载/重装保留 `AppData`；换盘时安装器记录上一个安装位置，新版首次启动再自动导入。

## 配置升级与关注恢复

- 修复 2.0.x 使用 `List<String>`、2.1.x 使用 JSON `{"list": [...]}` 后，仅复制 Hive 文件却读取为空的根因。
- 在所有设置控制器初始化前执行原始 Hive 升级，合并历史安装目录、Documents 旧数据和大小写不同的 `PureLive/pure_live`。
- 关注按平台与房间号去重，同时合并历史、分区、WebDAV、屏蔽用户/关键词和菜单配置；目标已有新配置时不被旧标量覆盖。
- 迁移前创建带来源清单的 Hive 回滚备份；导入指纹避免重复，锁定/损坏源留待后续启动重试。
- 应用正常退出前主动 `flush()` 设置，降低快速重启或更新过程中末次配置丢失的概率。

## Windows 滑动与交互性能

- 移除同一列表的重复指针与滚动通知监听，回到顶部/底部动画按距离动态控制时长。
- 首页和分区页只在 Tab 完全停稳后触发数据加载，避免横滑中间帧发起网络请求与网格重建。
- 收藏、首页、分区、搜索根据桌面端使用适应的懒加载范围和稳定 Key，避免重复 keep-alive/repaint 层。
- 分区封面加载状态改用静态占位，降低多张动画在滚动中同时重绘的压力。
- Windows 窗口拖动和缩放时把密集原生尺寸请求合并到 80 ms 稳定帧，减少布局颠簸。

## 更新链路与构建

- 应用内版本检查、历史记录、Issue 和 Release 链接恢复到 `liuchuancong/pure_live`。
- 修正 Android arm64、Windows EXE/便携 ZIP 和 macOS universal ZIP 的实际附件名，不再展示本轮没有生成的 arm32/x86_64 APK 与 MSIX。
- 更新源按平台发布状态选择版本，Windows 专项版不会让 Android/macOS 客户端获取到尚未发布的附件。
- 本机质量门禁通过：Built-in Kotlin 审计、Flutter Analyze 零问题、76 项单元/Widget 测试、25/25 平台接口探测通过。

---

# Pure Live v2.1.1

本版本集中修复观看口径设置空白、首页平台横滑掉帧和跨平台搜索能力不透明的问题，并继续以 Android arm64 与 Windows x64 为本机优先构建目标。

## 设置与首页流畅度

- 修复“真实在线平台开关”中仅提供热度的平台仍被错误包入无响应式读取的 `Obx`，导致 GetX 拒绝构建并只留下大块灰色卡片的问题。
- 支持真实在线的平台继续提供独立开关；Bilibili、斗鱼、虎牙等仅提供热度的平台显示禁用状态、数据来源和口径说明。
- 首页手势横滑到半程时不再提前启动目标平台网络请求和网格重建；页面完全停稳后再加载，并保留已构建页面、列表与滚动位置。
- 平台目录一次建立 ID 索引，避免按每个已启用平台重复实例化全部适配器；直播卡片使用稳定 Key，减少切页时的无效重建。

## 跨平台搜索

- 搜索页增加“包含未开播”筛选，以及综合、平台顺序、观众优先、粉丝优先四种排序。
- 综合排序固定直播中的房间优先，再比较当前观看口径、粉丝数和主页平台顺序；平台优先直接使用用户在主页平台设置中的拖动顺序。
- 每个平台独立维护翻页结束状态，空页、重复页和非分页来源会停止继续请求，避免反复拉取相同结果。
- 搜索页动态显示当前平台覆盖范围：Bilibili、斗鱼、网易 CC、Twitch 可返回部分未开播结果；虎牙、抖音、SOOP 主要返回当前直播；快手使用网页搜索；IPTV 搜索本机导入频道。
- Bilibili 与网易 CC 搜索结果补充可用粉丝字段；平台响应缺少粉丝数时保持稳定次序，不以热度冒充粉丝。

## Windows 安装与小窗

- Windows 安装向导固定显示安装目录页，首次安装和覆盖更新都可以浏览并选择其他磁盘，同时保留用户上次选择的目录。
- Windows 小窗改为默认普通窗口层级，切换到其他应用后可以被其覆盖；播放行为设置增加“小窗始终置顶”开关，需要时可恢复置顶并立即生效。

## 构建与验证

- Built-in Kotlin 审计与 Flutter Analyze 零问题，71 项单元/Widget 测试通过。
- 25/25 平台公开接口探测通过，覆盖分类、推荐、搜索、弹幕节点、房间元数据和播放令牌。
- Android 继续使用正式包名 `com.mystyle.purelive`，优先生成 `arm64-v8a` release；Windows 生成 x64 便携 ZIP 与可选择安装目录的安装程序；Linux、macOS 与 iOS 补齐对应平台归档。

---

# Pure Live v2.1.0

这是一次阶段性大更新：同步上游 `24ff92b6`（2026-08-18）的 Twitch、SOOP Live 与网页内核更新，并汇总此前完成的弹幕稳定性、小窗、120 Hz、播放、助眠、本地互动、Built-in Kotlin 和本机发布工程。

## 上游同步、Twitch 与 SOOP Live

- 新增 Twitch 分类、推荐、频道搜索、房间详情、直播清晰度、外部打开、Cookie 设置和 IRC 弹幕。
- Twitch `viewersCount` 作为真实并发人数进入显示、筛选和排行；本地互动同步增加 Twitch 徽章、Bits、订阅等级与礼物体验包。
- Twitch IRC 解析支持无颜色用户、转义显示名、用户 ID、消息 ID、平台时间与多行数据；登录 Cookie 中的 `auth-token`/`login` 用于聊天认证。
- 新增 SOOP Live 分类、推荐、搜索、房间详情、播放线路、Cookie、弹幕、并发在线人数、链接识别与本地互动体验包。
- 接口探测从 15 项扩展为 25 项，覆盖 Twitch 与 SOOP Live 的分类、目录/推荐、搜索、房间元数据和播放令牌。

## 弹幕、依赖与界面

- 主画面和小窗增加“纯文字模式”，小窗预览实时反映该开关；兼容上游旧存储键。
- 合并 `file_picker 12.0.0` 稳定 API、`windows_single_instance 1.2.0`、锁定修订版 `flutter_inappwebview 6.2.0-beta.3`、默认音量百分比修正和网页关闭清理；补齐网页内核的 AGP 9 / R8 兼容补丁，Linux 网页搜索使用系统浏览器。
- 继续保留统一 px/s 速度、动态跟随屏幕最高刷新率、过期队列淘汰、房间会话隔离、手机固定小窗预览和 AGP 9 Built-in Kotlin 修复。
- 更新仓库说明、平台兼容表、依赖审计和阶段更新文档。

## 全平台构建

- Android arm64 与 Windows x64 继续优先在本机完成质量门禁、正式构建和启动验证。
- 阶段工作流扩展到 Linux x64、macOS universal 和 iOS arm64 设备编译；Apple 两个平台共用一次 macOS 作业。
- Linux 使用 Ubuntu 24.04 构建，以匹配当前锁定 `libmpv` 的 glibc/GLIBCXX 基线；macOS 主程序实测同时包含 x86_64 与 arm64。
- iOS 生成无签名设备 `.app` 归档，供后续证书签名与 IPA 封装。
- Built-in Kotlin 审计与 Flutter Analyze 零问题，64 项单元/Widget 测试及 25/25 平台接口探测通过。

---

# Pure Live v2.0.36

本版本集中修复 Android 系统画中画切换停顿、手机长设置页看不到小窗弹幕预览、哔哩哔哩访客昵称脱敏来源不清，以及热度/在线人数切换与排行不一致的问题。

## 画中画与设置预览

- 进入 Android 系统画中画前先构建并渲染紧凑视频层，复用同一播放器 Element，减少 Texture 重新挂载时出现的应用图标、黑帧和画面延迟。
- 向系统传入当前视频物理边界 `sourceRectHint`；Android 12+ 启用视频无缝缩放，并移除播放器上内容相同的二次 `AnimatedSwitcher`。
- 画中画状态探测周期从 10 ms 调整为 100 ms，显著减少普通播放期间持续的平台通道压力。
- 手机端小窗弹幕设置改为“上方固定预览 + 下方独立滚动参数”，桌面/平板使用双栏布局；字号、颜色、速度、密度、透明度、区域和 FPS 继续实时作用于预览。

## 弹幕昵称

- 当前哔哩哔哩访客 WebSocket 会话实测会同时脱敏旧用户名、rich user 名称与 UID；这是平台返回数据，并非客户端把昵称改成星号。
- 解析器优先读取新版 `info[0][15].user.base.name`，登录会话返回完整 rich user 时直接显示完整昵称；访客仍收到脱敏值时，弹幕列表只提示一次数据来源与登录入口。
- 新增新版 rich user、脱敏兼容和累计观看消息回归测试。

## 热度、在线与累计观看

- WebSocket 观看更新改为带类型数据：哔哩哔哩 operation 3 只更新热度，`WATCHED_CHANGE` 只更新本场累计看过；抖音 `onlineUserForAnchor` 只更新并发在线。
- 虎牙弹幕同步到当前网页协议：使用 `wsapi.huya.com`、房间组注册与批量推送；实连确认列表/详情的 `totalCount/userCount` 及直播间 URI 8006 `iAttendeeCount` 都处于同一热度口径，不再标成真实在线人数。
- 平台能力与房间当前是否已取得数值分离：抖音/快手/网易 CC 可从列表或详情取在线；哔哩哔哩、斗鱼和虎牙公开数据继续按热度/累计口径标注。
- 真实在线模式下，支持平台尚未取得明确值时显示“待刷新”，几百万热度不再代替在线数参与排行；不支持并发人数的平台排在支持平台之后。
- 收藏和搜索结果监听全局口径与分平台开关，切换后立即重新排序。

## 验证与构建

- Flutter Analyze 零问题，59 项单元/Widget 测试通过；15/15 平台公开接口探测与虎牙当前 WebSocket 实连通过。
- Android 继续优先构建正式包名 `com.mystyle.purelive` 的正式签名 `arm64-v8a` APK，并在连接设备上覆盖安装验证。

---

# Pure Live v2.0.35

本版本修复真机回归中发现的哔哩哔哩热门直播间热度偶发显示为 `1`，并完成 Android 120 Hz、游客弹幕、横竖屏、小窗、纯音频和后台播放链路验收。

## 观看指标稳定性

- 进入同一直播间时合并列表、详情接口和弹幕心跳中的观看指标，详情接口短暂返回哨兵值时保留列表中的可靠热度。
- 哔哩哔哩热门房间从千级以上瞬时骤降至 `1` 时不再覆盖现有热度；后续数值合理的实时心跳仍会正常刷新。
- 运行时观看指标忽略无效零值，在线人数、累计观看与平台热度继续使用各自独立字段和标签。

## 真机验收

- OnePlus Android 16 arm64 真机覆盖安装保留应用数据；多次冷启动无崩溃，前台窗口和弹幕动画以设备最高 120 Hz 运行。
- 哔哩哔哩游客直播间弹幕连续刷新；竖屏、横屏、全屏及系统画中画均验证画面弹幕，设置页字号预览实时变化。
- 纯音频切换、系统媒体会话、前台服务通知、Partial WakeLock 与 Wi-Fi Lock 均通过后台探测。

## 构建与验证

- 本机质量门禁覆盖 Built-in Kotlin 审计、Flutter Analyze、完整测试及 15 个平台接口探测。
- Android 继续优先生成正式包名 `com.mystyle.purelive` 的正式签名 `arm64-v8a` APK。

---

# Pure Live v2.0.34

本版本完成 Android AGP 9 Built-in Kotlin 迁移，并升级本机构建工具链，重点解决第三方插件各自加载不同 Kotlin/AGP 版本造成的配置冲突和后续 Flutter 兼容风险。

## Android 构建工具链

- Android Gradle Plugin 升级到 9.3.1，Gradle Wrapper 升级到 9.5.0；compileSdk/targetSdk 继续使用 API 37。
- 主应用和本地插件移除 `kotlin-android`、独立 KGP classpath、旧 `android.kotlinOptions` 以及把 Kotlin 目录挂到 Java source set 的旧配置。
- Java 25 用作 Gradle/lint 构建运行时，应用和插件产出的 Java/Kotlin 字节码统一为 17，兼顾新工具链与 Android 运行版本。
- 长路径 Windows 工作区继续使用稳定短盘符；针对 Pub Cache 与工作区跨盘，关闭会损坏可迁移缓存的 Kotlin 增量模式。

## 插件兼容与依赖

- 内置 `better_player_plus`、`floating`、`flutter_exit_app`、`flutter_js`、`mobile_scanner`、`share_handler_android` 的最小兼容补丁，并保留各自许可证、上游地址和原版本。
- `flv_lzc` 同步迁移到 Built-in Kotlin；所有本地插件统一复用根项目 AGP，不再把旧 AGP 带入 lint/构建 classpath。
- 所有直接运行时依赖仍处于当前可解析最新版；`pub outdated` 剩余更新均为 Flutter SDK或上游约束锁定的传递依赖，未使用破坏兼容性的强制覆盖。

## 自动回归

- 新增 `tool/audit_built_in_kotlin.py`，在本地 CI 中检查工具链下限、Built-in Kotlin 开关和所有本地 Gradle 模块，阻止旧 KGP/AGP classpath 重新进入项目。
- GitHub 手动构建同步使用 Java 25；本机仍优先生成正式包名 `com.mystyle.purelive` 的 `arm64-v8a` APK，Windows x64 按需构建。

## 验证结果

- Built-in Kotlin 审计和 Flutter Analyze 零问题，49 项单元/Widget 测试及 15/15 平台接口探测通过。
- Android `arm64-v8a` release 编译通过，APK 包名 `com.mystyle.purelive`、版本 `2.0.34 (2045)`、targetSdk 37、单一 arm64 ABI 与 v2 签名结构核验通过。
- Windows x64 release 编译通过；便携程序持续启动 20 秒，进程存活、主窗口响应、MediaKit D3D11 与 FFmpeg Kit 正常加载。

---

# Pure Live v2.0.33

本版本集中重构弹幕房间会话、协议去重、积压队列和高刷新率运动时钟，修复串房、旧消息重放、偶发停更、重复循环以及横竖屏/小窗切换后的不稳定问题，并同步优化 Android 与 Windows 的弹幕列表和设置页面滚动。

## 弹幕连接与房间隔离

- 所有房间切换、设置开关和小窗销毁操作进入串行会话队列；回调携带平台、房间与会话编号，旧 WebSocket 的迟到消息不会进入新房间。
- 房间详情请求增加代次校验，快速切房或切换线路时丢弃上一房间的迟到响应，避免旧详情重新覆盖当前播放器和弹幕连接。
- WebSocket 关闭改为可等待的完整清理，连接代次同时约束消息、错误和关闭事件；Bilibili、抖音、斗鱼、虎牙都在重启前释放旧连接并清空全部回调。
- 应用悬浮窗离开直播页后保留轻量弹幕会话，关闭悬浮窗时再按顺序停止连接、清空画面和释放控制器；重新进房不会继承残留队列。

## 平台协议稳定性

- Bilibili 读取弹幕时间戳和消息随机 ID；抖音校验消息内房间 ID，并保存消息 ID、用户 ID 和发送时间；斗鱼校验 `rid/cid/cst`，虎牙补充用户 ID。
- 稳定平台消息 ID 使用 10 分钟重放窗口，无 ID 平台使用 2.5 秒短指纹窗口；超过 45 秒的平台历史消息直接丢弃，兼顾断线去重和正常重复发言。
- 修正抖音 ACK 将扩展游标误写到 `payloadType` 的问题，并兼容压缩标记缺失但具有 GZip 文件头的响应。
- 斗鱼现在解析同一 WebSocket 帧内的全部协议包，不再只处理第一条造成热门房间间歇性漏弹幕。

## 渲染、速度与列表

- 主画面与小窗等待队列分别限制为 120/36 条，并淘汰 5/3 秒未取得轨道的消息，轨道拥堵或应用恢复后不再补放几分钟前的内容。
- Flame 弹幕改用受帧间隔约束的逻辑时钟，后台恢复不产生大跨度跳动；所有轨道严格使用用户设置的同一 px/s 速度，Android、横竖屏、小窗与 Windows 表现一致。
- 修正 20% 显示区域被重复计算成 4% 的轨道高度问题；补全字体、描边与颜色缓存键，样式调整后相同文字也会立即使用新画面。
- 弹幕历史按 32 ms 批量合并，移除逐条复制 500 条列表和重建直播页的路径；上滑阅读时只更新独立新消息计数，列表使用反向懒加载并降低预缓存范围。
- 屏蔽管理改为虚拟化 Sliver 列表，弹幕设置按区域局部响应式更新；移除列表每行阴影，改善 Android 120 Hz 与 Windows 鼠标滚轮滚动。

## 验证与构建

- Android 继续优先构建正式包名 `com.mystyle.purelive` 的 `arm64-v8a` 安装包。
- Windows x64 使用同一会话、队列、逻辑时钟和滚动实现，并重新生成便携包/安装器。
- 新增平台消息时间、房间校验、重复抑制、斗鱼合帧解析和渲染队列上限回归测试。
- Flutter Analyze 零问题，49 项单元/Widget 测试和 15/15 平台接口探测通过；Android arm64、Windows x64 编译及 Windows 启动响应探测通过。

---

# Pure Live v2.0.32

本版本重新校正观看数据口径，重做三类定时器的名称与交互，完善画面弹幕的实时样式、模板和点击操作，并将本地互动扩展为六个平台体验包。

## 观看数据与排行

- `LiveRoom` 分别保存平台热度、真实并发在线和本场累计观看，旧版 `watching` 字段只用于备份兼容。
- 增加“平台热度优先 / 真实在线人数优先”全局排行方式，以及抖音、快手、网易 CC 的独立真实在线开关。
- 虎牙列表/详情的 `totalCount`、`userCount` 以及房间 URI 8006 `iAttendeeCount` 都按热度处理；抖音 `display_value/total_user` 保留为累计观看，`user_count/onlineUserForAnchor` 按在线人数处理。
- 哔哩哔哩 `online`/心跳和斗鱼 `ol/hot` 保留热度标签，避免把几百万热度误显示为同时在线人数。

## 助眠与定时器

- “新直播间自动助眠”仅决定新房间是否自动进入纯音频；耳机按钮只切换当前房间，电视按钮仍为投屏。
- 自动助眠停止时长支持快捷选项和 1 分钟至 365 天任意分钟输入，重新排版输入框与操作按钮，解决窄屏文字重叠。
- 直播间菜单改名为“当前直播间播放定时器”，到时暂停当前直播和后台音频；通用设置改名为“应用定时退出”，到时退出整个应用，三种行为互相独立。

## 弹幕与交互

- “最佳观看”模板调整为画面顶部约 20%，速度 118 px/s、字号 16 px、描边 1.5 px；舒适与高密度模板分别占顶部约 35% 和 55%。
- 设置页的区域、速度、字号、描边、透明度和帧率通过同一响应式控制器立即更新直播画面，并补充单位和实时生效说明。
- 修正描边值被错误映射成字体粗细的问题；描边宽度改为 0–4 px 连续值。
- 画面弹幕点击/长按默认启用，指针统一从全局坐标换算到弹幕画布坐标，竖屏、横屏和全屏均与单击播放、双击全屏等手势分流。
- 弹幕操作面板打开时暂停画面弹幕，下滑关闭后继续；弹幕列表上滑阅读时冻结快照，回到底部后再同步新消息。

## 本地互动与播放器

- 六个平台体验包分别提供主题色、身份徽章、等级称呼、本地体验币和礼物目录，可单独控制身份、等级与礼物画面效果。
- 高价值本地礼物在直播画面显示更醒目的主题横幅；所有充值、等级、弹幕和礼物记录仍只保存在本机。
- `video_player` 更新至 2.14.0，`better_player_plus` 1.3.5 与 MediaKit 修订分支最新固定提交完成兼容复核。

## 构建目标

- Android 正式包名保持 `com.mystyle.purelive`，本地优先构建 `arm64-v8a`。
- Windows 构建继续按需执行，本版本发布先提供 Android arm64 安装包。
- Flutter Analyze 零问题，39 项单元/Widget 测试与 15/15 平台接口探测通过。

---

# Pure Live v2.0.31

本版本修正直播间顶部栏空间分配与音频/投屏图标语义，并完成 ASMR 自动助眠和房间纯音频的最终解耦。

## 直播间布局

- 手机端将“已关注/关注”和“录制/监控中”收敛为带长按提示的紧凑图标，主播头像、名称和分区使用剩余宽度并自动省略。
- 平板和桌面继续显示文字按钮，关注、录制状态与原操作流程保持一致。
- 修复主播昵称为空时取消关注弹窗的空值崩溃点。

## 音频、投屏与 ASMR

- 播放画面右上控制顺序统一为“耳机纯音频 → 电视投屏 → 小窗播放”；耳机在启用纯音频后保持耳机形状并高亮，电视图标仅表示 DLNA 投屏。
- 移除房间月亮按钮和播放器内核页的遗留全局纯音频默认项，手动耳机切换仅对当前房间生效，切换房间后重新遵循 ASMR 设置。
- 新增一次性配置迁移，清理旧版 `audioOnly` 持久值；ASMR 关闭时，新打开或切换的直播间从视频模式开始。
- ASMR 开启时，新房间自动进入纯音频、启用后台保活和停止计时；手动恢复视频同步结束该次助眠计时。
- 关闭设置页 ASMR 开关时立即撤销活动中的助眠计时。
- 纯音频和视频切换复用当前清晰度与播放线路，省去房间详情、清晰度和地址的重复网络获取，缩短切换等待。

## 验证

- Flutter Analyze 零问题。
- 30 项单元测试与 Widget 测试全部通过。
- Android 优先构建 `arm64-v8a`。

---

# Pure Live v2.0.30

本版本集中修复 ASMR 状态、Bilibili 访客弹幕、横屏弹幕、列表阅读、首次启动与直播首帧问题，并补齐动态弹幕帧率、平台人数口径和本地互动输入。

## ASMR 与后台播放

- 设置页“进入直播自动启动助眠”只控制新房间默认行为；直播间月亮按钮只控制当前会话；通用纯音频偏好保持独立。
- 增加 v2.0.29 遗留状态一次性迁移，关闭 ASMR 后新房间恢复画面。
- 停止时间支持预设和 1–720 分钟自定义输入。
- 音频模式直接使用播放器原生音频输出，移除 FFmpeg 二次解码、固定等待和管道超时。
- 媒体前台服务在短暂中断期间保持，CPU/Wi-Fi 锁按播放会话同步；定时到点完整停止并释放资源。

## 弹幕

- Bilibili 房间播放和弹幕发现解耦；token、buvid 与 WebSocket 节点支持后台刷新、认证拒绝重取和有界重连。针对部分移动 DNS 不解析区域 comet 域名的情况，优先连接官方通用网关，再轮换区域节点。
- 访客 `uid=0` WebSocket 实连通过，公开直播弹幕接收不依赖账号登录。
- 横竖屏切换只保留一个 Flame 弹幕引擎，修复共享控制器被旧过渡页面解绑的问题。
- 弹幕 FPS 参数进入引擎更新调度；主播放器与小窗支持动态跟随设备最高刷新率。
- 新增最佳、舒适、高密度模板，支持保存和恢复自定义模板。
- 画面弹幕提供可选点击和长按操作；弹幕列表长按/右键可复制、屏蔽用户或屏蔽关键词。
- 用户上滑列表后冻结当前快照并累计新消息，回到底部时一次同步；列表容量提升到 500 条并以 80 ms 合帧更新。
- 修正自定义字体与描边下的顶部裁切，轨道高度随字号动态调整。

## 互动、人数与流畅度

- 本地互动开关启用后，弹幕列表底部直接显示输入框；本地弹幕可进入列表和画面弹幕。
- 六个平台分别提供礼物目录、等级徽章和高价值礼物效果标记，充值、等级、头衔和历史仅保存在本机。
- 新增“优先显示真实在线人数”和平台支持说明；虎牙/快手显示在线人数，其他平台保留热度、累计观看或粉丝等原生统计口径。
- Android 与桌面列表采用夹持滚动物理模型，iOS/macOS 保留弹性模型；全应用页面移除统一强制弹簧阻尼。
- 收藏刷新改为整批只持久化一次并保留本地标签，减少热门房间定时刷新造成的 Hive 放大写入与界面抖动。
- MediaKit 修正探测参数名，将直播流分析窗口缩短至 2 秒、网络超时收紧至 15 秒；Bilibili CDN 请求头移除错误的 API authority。
- 播放器原生音量、房间持久值和控制栏改用同一响应式状态。

## 启动与稳定性

- 数据库、设置、自定义字体和直播页必需依赖在首屏前完成注册，修复更新安装后首次点击闪退与搜索结果快速进房竞态。
- 保留 Room 生成数据库的反射构造器，修复 release 混淆后 WorkManager 在 Flutter 首帧前崩溃。
- 内置修订版 `flv_lzc`，移除插件注册阶段创建临时 `SurfaceTexture` 的探测代码，修复 Flutter 3.47 下偶发原生 `registerTexture` 终止。
- 后台媒体通知只显示直播流实际支持的播放/暂停与停止动作，并保留其图标资源，消除 release 资源压缩后的通知动作异常。
- 直播路由增加防重复推入，避免连续点击创建多个播放器会话。
- 自定义字体在首个 ThemeData 构建前注册，重启后首次界面直接应用选择。

## 依赖与验证

- `synchronized` 更新至 3.4.1+2；其余直接运行时依赖复核为当前上游版本或固定 Git 提交。
- Flutter Analyze 零问题（固定的第三方播放器源码独立排除）。
- 28 项单元测试与 Widget 测试全部通过。
- 平台接口探测 15/15 通过；Bilibili 访客弹幕 WebSocket 认证与通知帧实连通过。
- Android 16 / 120 Hz 真机覆盖安装后连续 5 次冷启动均一次进入，启动耗时 239–274 ms；崩溃缓冲区中 `FATAL`、WorkDatabase 与 `registerTexture` 均为 0。
- 同一真机确认 Bilibili 视频与实时弹幕在竖屏、横屏均显示，本地弹幕输入框可用；系统为应用分配并请求 120 Hz。
- Android 优先构建 `arm64-v8a`，Windows 仅构建 x64。

## 下载说明

- Android 正式包名保持 `com.mystyle.purelive`。
- 使用 `SHA256SUMS.txt` 校验本机构建产物。
