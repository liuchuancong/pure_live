
<p align="center">
  <img src="assets/icons/icon.png" width="150" alt="Pure Live 图标"/>
</p>

<h1 align="center">纯粹直播（Pure Live）</h1>

<h4 align="center">基于 Flutter 的开源多平台直播聚合播放器</h4>

<p align="center">
  A third-party live stream aggregator built with Flutter.
</p>

<p align="center">
  <a href="https://github.com/wzgrx/pure_live/releases/latest">
    <img alt="Latest Release" src="https://img.shields.io/github/v/release/wzgrx/pure_live">
  </a>
  <a href="https://github.com/wzgrx/pure_live/actions/workflows/feature-build.yml">
    <img alt="Manual Build" src="https://github.com/wzgrx/pure_live/actions/workflows/feature-build.yml/badge.svg">
  </a>
  <a href="https://github.com/liuchuancong/pure_live">
    <img alt="Stars" src="https://img.shields.io/github/stars/liuchuancong/pure_live?color=yellow">
  </a>
  <a href="https://github.com/wzgrx/pure_live/releases">
    <img alt="Downloads" src="https://img.shields.io/github/downloads/wzgrx/pure_live/total?style=flat-square">
  </a>
  <a href="LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/liuchuancong/pure_live?color=blue">
  </a>
</p>

> 纯粹直播（Pure Live）是一款开源的第三方多平台直播聚合播放器，使用 Flutter 构建，支持 Android、Android TV、Windows、Linux、macOS 和 iOS 等平台。

> 本维护分支基于 [liuchuancong/pure_live](https://github.com/liuchuancong/pure_live)，维护本机优先构建、正式签名、接口探测、Windows 数据迁移及高刷新率优化。上游变更按独立审查流程处理；当前 3.2.0 验收阶段不合并上游。

## 维护分支说明（请先阅读）

<!-- maintenance-readme-markers: maintenance-scope; android-first; windows-maintained; upstream-feature-routing; bugfix-release-default -->

- 本仓库重点维护 **Android / Android TV 与 Windows**。当前日常使用 Android 更多，因此多数修复、功能整合和安装包会优先更新 Android；Windows 继续作为主要桌面维护目标。
- Linux、macOS 和 iOS 保留源码及上游兼容性，但缺少持续使用的对应设备，列为社区验证范围，不承诺每轮构建、更新时效或运行结果。
- 本分支更新频繁、历史定制较多，仍可能出现较多回归、接口时效和设备兼容问题。若更看重低频变更或原项目行为，可切换到[原项目](https://github.com/liuchuancong/pure_live)。
- 本仓库 Issue 仅受理**可复现的维护型 Bug**。新增功能、产品方向和全新平台适配请提交到[原项目 Issue](https://github.com/liuchuancong/pure_live/issues/new/choose)。
- 每个完成的 Bug 修复批次默认递增版本，优先构建 Android `arm64-v8a` 正式更新包，并同步源码、版本标签、安装包与校验文件到本仓库 GitHub Release；其他平台仍按本轮明确范围串行构建。
- 每次同步上游、分析 Bug 和审查原项目 Issue 的来源判定、根因、兼容、验证与回滚流程见[维护范围与问题处置策略](MAINTENANCE_POLICY.md)及[上游同步审查策略](UPSTREAM_REVIEW_POLICY.md)。

- **最新稳定版**：[v3.1.8](https://github.com/wzgrx/pure_live/releases/tag/v3.1.8)
- **下一稳定版目标**：3.2.0，当前处于完整验收阶段，尚未发布。本轮只维护本仓库、不合并上游；优先源码审查、确定性回归和本地验证，手机操作按本轮明确安排执行，不把连接设备作为修复前置条件。进度、缺口与发布门禁见 [3.2.0 验收入口](docs/ACCEPTANCE_3_2_0.md)，开发包及旧版通过记录不等于最终版已通过。
- **当前 Android 验收输入**：精确构建提交 `c6817e74`（产品修订 `98f5472a`）的 288823157 B arm64 Debug（SHA-256 `55F94C97…F2B3`）已完成同签名覆盖安装与设备 APK 哈希核对；在 K90 上通过冷/热/重复口令、口令与附件混合输入释放、单 M3U、真实 `ACTION_SEND_MULTIPLE` 的 M3U+XMLTV，以及异常 Provider 后续处理。类型/查询异常没有抑制后续附件，查询异常按 URI 文件名回退；包含中文、emoji、控制字符的超长显示名按 UTF-8 安全清洗为 175 字节 basename，两份后续频道各精确一条，插件暂存树为空。同源码另生成 127835744 B 的 R8/资源收缩 Release 测试包（`4BF85571…6B82`），完成冷/热/重复口令、混合附件、单 M3U 和三个 Debug 探针排除；随后由独立系统包 DocumentsUI（UID 10096）真实选中 M3U+XMLTV，经系统分享面板把 `ACTION_SEND_MULTIPLE` 交给 Pure Live（UID 10946）。两份 `com.android.externalstorage.documents` 内容 URI 均明确授权给目标包，Provider/频道、EPG 来源/频道/节目各精确一条，17/17 原生检查通过。三轮 IPTV/Hive 均精确恢复，外部夹具精确删除，应用停止、桌面和常亮状态复原。本机未配置正式密钥，文件明确标记 `debug-signed`；候选仍是测试包，不作为稳定版下载入口。本批详见[Android 外部分享接收审计](docs/ANDROID_INCOMING_SHARE_INTAKE_AUDIT_2026_09_13.md)，更广的播放/弹幕/音频/PiP 基线仍见较早累计候选的[原生证据](docs/CURRENT_ANDROID_CANDIDATE_2026_09_12.md)。
- **Android 弹幕设置补证**：嵌入页现始终提供恢复模板，模板先完整校验再一次提交，覆盖纯文字和全部视觉字段；开关、七类滑块、计数器及小窗颜色均补齐具名语义。确定性 52/52 与全库 analyze 通过，原生小窗和主模板往返结束后规范 Hive 逐字节恢复、应用停止。A2-04 处于 RUN，Windows GUI、其余样式逐项输入、真实小窗完整视觉对照与长测继续；详见[主模板与辅助语义原生审计](docs/ANDROID_DANMAKU_TEMPLATE_ACCESSIBILITY_NATIVE_AUDIT_2026_09_12.md)。
- **源码平台范围（未发布）**：目前 21 个直播站点 + IPTV，共 22 个适配器。新增 OPENREC / mellow-fan、TTingLive / FLEX TV、niconico 与微博直播；目录、搜索、弹幕和原生证据各自分列，注册不等于完整支持。见[平台能力表](docs/PLATFORM_COMPATIBILITY.md)、[OPENREC 应用审计](docs/OPENREC_APPLICATION_INTEGRATION_AUDIT_2026_09_09.md)、[TTing 应用审计](docs/TTING_APPLICATION_INTEGRATION_AUDIT_2026_09_09.md)与[微博应用审计](docs/WEIBO_APPLICATION_INTEGRATION_2026_09_11.md)。其余 6 组参考平台和已接入平台的完整能力仍待验收。
- **当前累计验收候选（未发布）**：Android `48154d15` 已完成 4072 项完整测试、42 项公共接口及 arm64 Debug 包检查，尚未安装；Windows `2fb471d3` 已生成 Debug 便携包并完成有限 GUI 冒烟。两者都早于当前源码，不含 09-11 的后续平台与设置修订，也不是 3.2.0 最终验收包。见[Android 候选审计](docs/ANDROID_CUMULATIVE_CANDIDATE_2026_09_10.md)与[Windows 候选审计](docs/HLS_WINDOWS_CANDIDATE_2026_09_10.md)。
- **斗鱼弹幕完整性修复（源码未发布）**：新安装、3.1.4 升级和缺字段备份默认显示平台收到的全部非空房间聊天，不再把缺少 `dms` / `if` 装饰标记当作不可见；疑似自动消息过滤保留为明确选择，设置即时生效并提示也可能隐藏普通聊天。有效红灯 16 PASS / 2 FAIL，最终相邻回归 53/53 与全库 analyze 通过；71415 审查时离线，实时网页数量对照继续，详见[Issue #871 / #845 专项审计](docs/ISSUE_871_DOUYU_CHAT_COMPLETENESS_AUDIT_2026_09_19.md)。
- **弹幕重连状态修复（定向候选，未发布）**：Bilibili、抖音、斗鱼、虎牙、快手、SOOP、Twitch 与 YY 现用类型化事件区分暂态重连和最终关闭，直播间与多画面会话不再解析中文提示决定所有权。精确提交 `80c87c0e` 的 72/72 定向回归、全库 analyze 与 Android arm64 Debug 完整性检查通过；另在精确 `d77c6153` 以生产适配器对 Bilibili、Huya、Douyin 完成 Windows DIRECT 10 轮共 30/30 连接，全部 ready 且无重连/最终关闭。真实断网、长时恢复、Android 与 Issue #860 报告网络继续原生验收，详见[收藏刷新与弹幕连接审计](docs/ISSUE_860_REFRESH_DANMAKU_AUDIT_2026_09_11.md#后续增量公共直播弹幕重复连接探针)。
- **Android 物理音量键媒体流路由修复（定向候选，未发布）**：前台 Activity 现于每次 `onResume` 将硬件音量控件绑定到 `STREAM_MUSIC`，覆盖播放前、弹窗、浏览器、画中画及前后台返回后的窗口归属；不拦截按键或直接写系统音量。精确提交 `d8de9855` 的 71/71 定向回归、全库 analyze 与 arm64 Debug 构建/完整性检查通过，物理按钮和报告设备复验继续，详见[Android 音量键路由审计](docs/ANDROID_HARDWARE_VOLUME_ROUTING_AUDIT_2026_09_12.md)。
- **IPTV 频道请求头修复（源码未发布）**：M3U 的 `#EXTVLCOPT`、`#EXTHTTP`、adaptive `#KODIPROP`、频道属性与 URL `|...` 后缀现可按优先级解析并经 schema 9 持久化；主播放器、多画面、纯音频和录制共享规范化后的 User-Agent、Referer、Cookie、Authorization 与自定义字段。最终 focused CI 426/426 与全库 analyze 通过，详见[IPTV 请求头审计](docs/IPTV_HTTP_HEADER_PLAYBACK_AND_RECORDING_AUDIT_2026_09_12.md)。
- **IPTV 提供方回看策略修复（源码未发布）**：M3U 头部/频道级 `catchup`、source、days、correction 与 XMLTV/JSON `catchup-id` 现经 schema 8 完整持久化；节目单按提供方禁用、归档窗口和必需字段控制回看。统一支持 default/append/shift、Flussonic、Xtream Codes、VOD 与旧 `playseek`，直接九文件 226/226、最终 focused CI 295/295 与全库 analyze 通过，详见[IPTV 提供方回看审计](docs/IPTV_PROVIDER_CATCHUP_METADATA_AND_WINDOW_AUDIT_2026_09_12.md)。
- **DLNA 发现与投屏事务修复（源码未发布）**：每次搜索独立持有订阅、超时、释放与代次，刷新隔离旧快照并移除已消失设备；投屏严格串行暂停旧接收器、设置媒体地址和播放，重复点击合并，失败可重试，退出后不再续发播放。对话框补齐双语状态、当前接收器、固定关闭及窄屏大字号滚动布局。新增 12/12、四文件联合 41/41 与全库 analyze 通过，详见[DLNA 审计](docs/DLNA_DISCOVERY_CAST_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_12.md)。
- **当前直播间定时器修复（源码未发布）**：开关和时长先保存在弹窗草稿中，取消保持原计时会话；确认以一次事务启停并更新时长，停用不受未完成输入阻塞。数字边界改为内联校验，输入控制器由弹窗完整生命周期持有；320×480 / 3.0 倍英文下内容可滚动、操作固定可达。新增 5/5、五文件联合 30/30 与全库 analyze 通过，详见[直播间定时器审计](docs/ROOM_PLAYBACK_TIMER_TRANSACTION_AND_LAYOUT_AUDIT_2026_09_12.md)。
- **当前直播间音量修复（源码未发布）**：静音与手机/电脑默认值改为可取消草稿；确认等待本设备当前房间音量写入后再提交设置，提交期间合并重复动作并保持路由，失败可原位重试。旧持久化、备份和房间音量统一有限值与 `0..1` 边界；320×480 / 3.0 倍英文下主体滚动、操作固定可达。新增 9 项回归，详见[直播间音量审计](docs/ROOM_VOLUME_DIALOG_TRANSACTION_AND_LAYOUT_AUDIT_2026_09_12.md)。
- **已知直播间直链/投屏选择器修复（源码未发布）**：清晰度与线路使用受视口约束的滚动主体和固定取消动作，阶段切换重置滚动位置；按钮、系统返回或路由销毁都会完成当前选择并释放单次动作门禁。新增 4 项场景后定向 24/24、六文件联合 87/87，详见[已知直播间选择器审计](docs/KNOWN_ROOM_LINK_SELECTOR_LAYOUT_AND_LIFECYCLE_AUDIT_2026_09_12.md)。
- **直播间录制动作修复（源码未发布）**：动作提交前重新核对当前房间任务，启动/监控/停止/移除改为单一等待事务，进入录制中心避开弹窗反向动画；320×480 / 3.0 倍中英文下动作滚动、取消固定可达，标题按钮随大字自然增高。新增 6/6、六文件联合 102/102，详见[录制动作审计](docs/ROOM_RECORD_ACTION_DIALOG_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_12.md)。
- **未发布的播放恢复加固**：已复现并修复等待新地址时仍替换已恢复连接、候选失败覆盖用户暂停、取消后转圈残留及提前错误回调逃逸。17 项新增案例纳入回归，详见[恢复事务审计](docs/PLAYBACK_RECOVERY_TRANSACTION_AUDIT_2026_09_05.md)；保持原生虎牙 FLV 健康连接，不增加定时重开。
- **虎牙连续播放复核（源码未发布）**：原生 FLV 优先、健康连接不定时重开；后台续签不占播放器队列，恢复按活动 CDN/格式/凭据家族匹配，修复线路重排或过滤后按旧序号错选。1070 项回归与 42 项接口探测通过；上游与本地根因、修复边界见[线路身份审计](docs/HUYA_LINE_IDENTITY_AUDIT_2026_09_05.md)，既有原生采样见[后台续签审计](docs/HUYA_PREFETCH_OWNERSHIP_AUDIT_2026_09_05.md)。安装包、实际音画呈现与测试结果分开验收。
- **加载动画资源修复（源码未发布）**：切换样式时销毁旧动画，恢复默认/未知样式时正确启动，颜色修改保留旋转相位。7 项定向回归通过，详见[加载生命周期审计](docs/LOADING_ANIMATION_LIFECYCLE_AUDIT_2026_09_05.md)；Windows 热门页空闲 CPU 的完整归因仍在核对，不将本次修复当作全局性能结论。
- **加载样式设置布局修复（源码未发布）**：颜色卡片和 85 个样式单元统一使用惰性滚动页，320×480 / 3.0 倍英文下不再由固定标题区挤压网格；大字号采用响应式列数、两行名称和完整 Tooltip。详见[加载样式布局审计](docs/LOADING_STYLE_SETTINGS_LAYOUT_AUDIT_2026_09_11.md)。
- **字体管理器修复（源码未发布）**：字体长页改用惰性 Sliver 列表，顶栏、许可证、状态和操作在 320×480 / 3.0 倍英文下响应式排布；多字重弹窗整体可滚动，默认字体统一持久化为 `Default`，Windows 由主题层映射到 Microsoft YaHei。详见[字体管理审计](docs/FONT_FAMILY_MANAGER_LAYOUT_AUDIT_2026_09_11.md)。
- **精细字号设置修复（源码未发布）**：全局缩放及五项字号的默认值和支持范围集中到控制器，启动与备份导入统一归一化；五项用途说明在窄屏大字号下逐项可达，宽桌面限制正文行宽，重置增加确认。详见[精细字号设置审计](docs/FONT_SIZE_SETTINGS_LAYOUT_AND_BOUNDS_AUDIT_2026_09_11.md)。
- **网络代理设置修复（源码未发布）**：应用层和播放器代理地址/端口在窄屏或大字号下纵排、宽桌面保持紧凑横排；清空、编辑中间态或越界端口不再覆盖最后有效配置，并显示 `1..65535` 双语提示。详见[网络代理设置审计](docs/NETWORK_PROXY_SETTINGS_LAYOUT_AUDIT_2026_09_11.md)。
- **主题设置与间距弹窗修复（源码未发布）**：加载样式状态在窄屏堆叠；主题模式、语言和横纵网格间距统一使用有界滚动弹窗，最后选项与操作可达；间距仅接受有限的 `0..64` 值。详见[主题设置审计](docs/THEME_SETTINGS_DIALOG_LAYOUT_AUDIT_2026_09_11.md)。
- **缓存与数据范围修复（源码未发布）**：“清空本地缓存”现在只统计并删除临时缩略图与表情缓存，完整保留录制、下载、字体和 IPTV 数据；失败时复测剩余大小，重复操作共享同一任务，窄屏大字号下入口和确认操作保持可达。详见[缓存与数据审计](docs/CACHE_DATA_SETTINGS_SCOPE_AUDIT_2026_09_11.md)。
- **刷新设置选择器修复（源码未发布）**：刷新间隔、首页并发数和缩略图间隔统一为整体可滚动弹窗，320×480 / 3.0 倍英文下三组末项均可达；刷新时间在启动和备份恢复时统一限制为 5～360 分钟，避免开关已启用但计时器未启动。详见[刷新设置审计](docs/REFRESH_SETTINGS_DIALOG_LAYOUT_AUDIT_2026_09_11.md)。
- **播放器内核设置修复（源码未发布）**：内核/代理状态和 MPV 驱动摘要在窄屏大字号下纵向展开，驱动选择器整体滚动且整行可点；播放器代理快捷入口复用全角主机归一化与 `1..65535` 端口校验，并由弹窗生命周期持有输入控制器。iOS 进一步固定 media_kit 的 `libmpv` 纹理输出，只暴露 AudioUnit、VideoToolbox 与通用安全项，阻断 Android/Windows 专属设置经备份进入播放器。详见[播放器内核设置审计](docs/PLAYER_KERNEL_SETTINGS_LAYOUT_AUDIT_2026_09_11.md)及[Issue #859 审计](docs/ISSUE_AUDIT_2026_09_10.md#859ios-抖音全屏播放闪退)。
- **录制设置修复（源码未发布）**：缓存标题、画质/超时/队列选择和数字编辑弹窗在 320×480 / 3.0 倍英文下保持完整可达；录制画质使用本地化标签，并发任务限制为 `1..10`，缓存为正整数，旧配置、备份和运行时统一归一化。详见[录制设置审计](docs/RECORD_SETTINGS_LAYOUT_AND_BOUNDS_AUDIT_2026_09_11.md)。
- **平台显示与账号入口修复（源码未发布）**：平台偏好补齐说明和可滚动的完整站点选择器；显示列表在窄屏大字号下纵排控件，隐藏项/唯一项不显示拖动入口，阻止隐藏最后一个平台并同步修复失效首选项。抖音 Cookie 使用规范路由且保留旧深链兼容，停用的斗鱼入口不再伪装可点击。详见[平台设置与认证入口审计](docs/PLATFORM_SETTINGS_AND_AUTH_LAYOUT_AUDIT_2026_09_11.md)。
- **第三方 Cookie 编辑器修复（源码未发布）**：抖音、虎牙、快手、Twitch、SOOP 与 YY 六个平台统一使用可滚动编辑页，保存时清理首尾空白和 HTTP 头控制字符并显示本机保存结果；带修改返回会先确认舍弃，320×480 / 3.0 倍英文下输入与保存操作连续可达。详见[Cookie 编辑器审计](docs/ACCOUNT_COOKIE_EDITOR_STATE_AND_LAYOUT_AUDIT_2026_09_11.md)。
- **账号身份刷新生命周期修复（源码未发布）**：Bilibili 登录状态由已存 Cookie 立即建立，身份返回前显示核验状态；Cookie 切换、退出及迟到响应按最新代次隔离并合并重复任务。抖音昵称随最新 Cookie 刷新，二维码/Web 登录只在身份核验成功后返回。详见[账号身份生命周期审计](docs/ACCOUNT_IDENTITY_LIFECYCLE_AUDIT_2026_09_11.md)。
- **Bilibili 登录生命周期与布局修复（源码未发布）**：二维码生成、轮询、扫码核验及 Web 重定向按最新代次隔离并合并重复任务，连续轮询错误有界退避；WebView 同时处理 `m`/`www` 完成地址。二维码页与 Web 顶栏在 320×480 / 3.0 倍英文下保持状态和操作可达。详见[Bilibili 登录审计](docs/BILIBILI_LOGIN_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_11.md)。
- **备份设置与本地配置预览修复（源码未发布）**：本地预览统一为可滚动长页，摘要按 1/2/4 列响应式排布，原始配置区在 320×480 / 3.0 倍英文下仍可达；模块数量只统计已识别配置分区，本地/云端标题分离。备份页的日志开关和连接进度在窄屏大字号下纵向展开，说明文案不再截断。详见[备份设置与本地预览审计](docs/BACKUP_SETTINGS_AND_LOCAL_PREVIEW_LAYOUT_AUDIT_2026_09_11.md)。
- **本地互动平台与样式布局修复（源码未发布）**：平台体验资源包由 8 个补齐到项目支持的 22 个，平台名称按当前语言解析，等价 ID 统一归一化，未知平台使用独立通用身份；样式标题和值在窄屏大字号下响应式换行，设置长页、竖屏面板和横屏分栏均保持可达。详见[本地互动平台与布局审计](docs/LOCAL_INTERACTION_PLATFORM_AND_LAYOUT_AUDIT_2026_09_11.md)。
- **WebDAV 状态布局与目录导航修复（源码未发布）**：无配置、待选择、加载、空目录和错误状态统一为可扩展滚动面，320×480 / 3.0 倍文字下“创建新配置”和长错误后的“重试”仍可达；目录导航优先使用服务路径并隔离缺失名称/路径及重复分隔符。详见[WebDAV 状态布局与目录路径审计](docs/WEBDAV_STATE_LAYOUT_AND_DIRECTORY_PATH_AUDIT_2026_09_11.md)。
- **WebDAV 帮助页修复（源码未发布）**：教程由整页硬编码中文改为完整中英文，免费版额度与 WebDAV 请求/目录限制按官方当前页面修正并提供可核对入口；参数行、标题和图片在 320×480 / 3.0 倍英文下保持可达，复制与图片预览补齐可访问操作。详见[WebDAV 帮助页审计](docs/WEBDAV_HELP_LOCALIZATION_AND_LAYOUT_AUDIT_2026_09_11.md)。
- **版本历史数据源与布局修复（源码未发布）**：历史记录改为与版本检查共用维护仓库更新源，外部 JSON 畸形字段局部隔离；刷新期间保留已有列表和选择，失败提供可见反馈。移动详情整体可滚动，320×480 / 3.0 倍英文下发布、复制、下载和关闭均可达，宽屏保留双栏。详见[版本历史审计](docs/VERSION_HISTORY_SOURCE_AND_LAYOUT_AUDIT_2026_09_11.md)。
- **版本更新状态与布局修复（源码未发布）**：检查失败或包元数据异常会结束加载、清理旧日志/地址并显示可重试状态；缺少版本/构建号不再猜测 Release 文件名，下载只接受绝对 HTTP(S) 地址。320×480 / 3.0 倍英文下下载源、完整动作弹窗、复制、注入下载和失败重试均可滚动到达。详见[版本更新审计](docs/VERSION_UPDATE_STATE_AND_LAYOUT_AUDIT_2026_09_11.md)。
- **更新下载生命周期修复（源码未发布）**：下载先写 `.part` 并以 `.previous` 保护旧文件，取消/失败清理暂存；文件名隔离路径片段和非法字符。Android 完成后打开实际文件，桌面打开失败保留文件并可重试，ZIP/附件不再触发应用退出；安装权限只在 Android APK 场景请求。弹窗在 320×480 / 3.0 倍英文下整体可滚动。详见[下载生命周期审计](docs/DOWNLOAD_LIFECYCLE_AND_DIALOG_AUDIT_2026_09_11.md)。
- **关于页与启动更新提示修复（源码未发布）**：关于页长警告和版本徽标复用共享响应式 Tile；新版本提示整体可滚动、动作可换行，并作为根 Navigator 对话框呈现。320×480 / 3.0 倍英文下末项与双动作可达，系统返回先关闭提示，页面退出后的迟到检查结果被隔离。详见[关于与启动更新提示审计](docs/ABOUT_UPDATE_PROMPT_LAYOUT_AND_LIFECYCLE_AUDIT_2026_09_12.md)。
- **标签管理布局与完整性修复（源码未发布）**：说明、标签卡片和详情/新增/编辑/删除弹窗在 320×480 / 3.0 倍英文下保持可滚动到达；IME 完成与确认共用提交事务，删除同步清理房间映射，关注页当前标签失效后回到“全部”。详见[标签管理审计](docs/TAG_MANAGEMENT_LAYOUT_AND_INTEGRITY_AUDIT_2026_09_12.md)。
- **工具箱路由与选择器修复（源码未发布）**：首次剪贴板读取绑定发起页面，工具箱被新路由覆盖或退出后不再回填和提示；清晰度/线路选择器使用有界滚动内容及固定取消动作，320×480 / 3.0 倍中英文下保持可选择、可取消。详见[工具箱审计](docs/TOOLBOX_ROUTE_AND_SELECTOR_LAYOUT_AUDIT_2026_09_12.md)。
- **IPTV 订阅源管理修复（源码未发布）**：初始读取改为页面内加载、错误重试和空状态，退出后迟到结果按请求代次隔离；删除只关闭原确认路由，自动同步不再索引或恢复已删除项。统计、资源卡与操作在 320×480 / 3.0 倍中英文下保持滚动可达。详见[IPTV 管理审计](docs/IPTV_MANAGE_LAYOUT_AND_LIFECYCLE_AUDIT_2026_09_12.md)。
- **IPTV 节目单与回看切换修复（源码未发布）**：节目读取按 EPG 来源、请求代次和播放器生命周期提交；当前/未来/回看使用统一半开时间边界。回看 URL 保留 fragment 与重复参数，播放器切换等待完整区间并阻止重复动作；加载、错误、重试、当前节目和长标题在 320×480 / 3.0 倍英文下保持可滚动到达。详见[IPTV 节目单与回看审计](docs/IPTV_SCHEDULE_CATCHUP_TRANSACTION_AND_LAYOUT_AUDIT_2026_09_12.md)。
- **IPTV 直连播放启动修复（源码未发布）**：初始直播和回看切换现在等待真实播放器初始化，并受房间/播放代次共同约束；换房、退出或更新回看后，迟到的旧成功/异常不再改写当前页面或发布假提示。直接定向 37/37、九个测试文件联合 205/205，详见[IPTV 直连播放事务审计](docs/IPTV_DIRECT_PLAYER_TRANSACTION_AUDIT_2026_09_12.md)。
- **IPTV 返回直播修复（源码未发布）**：回看状态下点击当前直播节目或明确的“返回直播”按钮都会恢复原始直播源，并清除回看 URL 与完整时间区间；当前失败、旧请求被取代和成功使用独立结果，重复动作合并，空原始地址保留节目单。按钮在 EPG 加载/错误/空列表及 320×480 / 3.0 倍文字下保持可达。九个测试文件联合 214/214、全库 analyze 通过，详见[IPTV 返回直播审计](docs/IPTV_RETURN_TO_LIVE_TRANSACTION_AND_LAYOUT_AUDIT_2026_09_12.md)。
- **醒目留言呈现修复（源码未发布）**：空页增加可滚动双语状态；畸形平台颜色回落到主题色，空头像不再发起无效请求；长身份、金额和正文在 320×480 / 3.0 倍英文下响应式排布。页面去重与消息模型共用平台事件身份，合法的同内容不同事件继续保留。详见[醒目留言审计](docs/SUPER_CHAT_PRESENTATION_AUDIT_2026_09_12.md)。
- **关注分区状态与布局修复（源码未发布）**：显示平台增加、移除或重排时，标签与子页由同一快照重建并按平台 ID 保留选择；瀑布流和卡片使用稳定身份。关注按钮可随可访问字号自然增高，空名称/类型以双语文案稳定回落。详见[关注分区审计](docs/FAVORITE_AREAS_STATE_AND_LAYOUT_AUDIT_2026_09_12.md)。
- **电视二维码设置同步修复（源码未发布）**：扫码只接收规范 HTTP(S) 服务器 origin，忽略空值、说明文字、用户信息、路径和查询；连续帧共用一次提交，异常及退出后的迟到结果按页面代次隔离。相机控制器在重试/退出时逐个释放，手电筒默认关闭且操作不再嵌套；提示、相机错误和同步结果补齐双语及窄屏大字号滚动。详见[二维码设置同步审计](docs/QR_SETTINGS_SYNC_LIFECYCLE_AND_INPUT_AUDIT_2026_09_12.md)。
- **Firebase 个人中心修复（源码未发布）**：配置预览、下载、上传和退出统一进入可滚动动作卡片，补齐同步方向说明、空账号保护、单一活动事务、进度与失败恢复；下载覆盖本机设置和退出登录增加确认，认证退出会等待底层完成后再清理状态并安全返回。320×480 / 3.0 倍英文下全部入口连续可达。详见[Firebase 个人中心审计](docs/FIREBASE_PROFILE_ACTION_AND_LAYOUT_AUDIT_2026_09_12.md)。
- **Firebase 云端配置详情与元数据修复（源码未发布）**：字符串/Map 配置和畸形分区统一容错，收藏/历史计数与原始预览共用同一快照；文档切换、迟到完成、空身份和失败重试具有请求代次边界。注册字段统一为 `created_at`，配置上传通过事务保留既有注册时间并迁移旧字段。320×480 / 3.0 倍英文下元数据和原始 JSON 连续可达。详见[Firebase 云端配置详情审计](docs/FIREBASE_CONFIG_PREVIEW_AND_METADATA_AUDIT_2026_09_12.md)。
- **Firebase 邮箱认证修复（源码未发布）**：邮箱登录、注册、密码重置和 GitHub 登录统一使用单一活动事务与请求代次，进行中锁定会改变提交语义的控件，退出后隔离迟到结果；密码原样提交，自定义资料不再覆盖规范身份字段。完成回调覆盖配置同步和安全返回，失败提示、密码 tooltip 与最小按钮高度补齐双语及大字号体验。详见[Firebase 邮箱认证审计](docs/FIREBASE_EMAIL_AUTH_LAYOUT_AND_LIFECYCLE_AUDIT_2026_09_12.md)。
- **Firebase 会话与自动同步修复（源码未发布）**：SDK 初始化不再依赖营销网站前置探测；初始快照、认证流和登录页完成回调共用身份代次与合并任务，重试替换旧订阅，退出隔离迟到结果。权限/角色以当前用户快照提交，自动恢复静默处理空配置，上传/下载跨异步边界核对身份；连接文案与隐私日志同步修订。详见[Firebase 会话审计](docs/FIREBASE_AUTH_CONTROLLER_SESSION_AUDIT_2026_09_12.md)。
- **网页搜索生命周期与状态修复（源码未发布）**：启动参数改为严格 HTTP(S) 请求，WebView 加载/替换/重试/历史返回/关闭统一由单一所有权事务处理；房间识别排队并隔离退出后的迟到确认，主文档失败有双语可滚动终态。发布版关闭网页检查入口，日志不再记录完整 URL、响应头、房间 ID 或控制台正文。详见[网页搜索审计](docs/WEB_SEARCH_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_12.md)。
- **新增平台接入进度（源码未发布）**：AcFun 已接入热门、官网分类、作者搜索、分享链接、播放/录制输入和在线人数开关；真实官网搜索验证了稀疏分页，98 个结果按 20/20/20/20/18 连续返回。Windows 原生短录 MP4 已通过独立全文件解码；远端弹幕尚未接入，应用内明确提示，Android/实际观看/长时录制验收继续进行。当前 v3.1.8 安装包不含此功能。详见 [AcFun 接入审查](docs/ACFUN_NAVIGATION_AUDIT_2026_09_05.md)与[录制原生验证](docs/RECORDER_LIFECYCLE_AUDIT_2026_09_05.md)。
- **录制实时统计与退出加固（源码未发布）**：已复现旧会话采样锁串扰、旧终止回调覆盖新会话、最后文件大小遗漏、关闭后任务与目录保护遗留；以会话所有权与生命周期栅栏修复，不增加轮询频率。详见[录制输出所有权审计](docs/RECORDER_OUTPUT_OWNERSHIP_AUDIT_2026_09_05.md)。
- **录制启动与检测加固（源码未发布）**：停止、移除或退出后丢弃迟到的房间检测结果；启动只恢复未完成待录任务，保留已停止/完成/失败历史。启动恢复开关独立可见，自动检测关闭时只检查一次，详见[录制轮询与启动审计](docs/RECORDER_POLL_OWNERSHIP_AUDIT_2026_09_05.md)。
- **录制操作顺序加固（源码未发布）**：存储权限返回不再恢复已取消的开始动作；新录制等待旧停止及文件恢复真正完成，快速开始/停止/删除不会互相覆盖状态。详见[录制用户意图审计](docs/RECORDER_USER_INTENT_AUDIT_2026_09_05.md)。
- **当前源码版本号**：`3.1.8+4121`。候选包按各自源码 SHA 与验证记录识别，同一版本号不代表包含相同修订；3.2.0 只在完整目标验收后发布。
- **音频事件加固（源码未发布）**：旧房间的耳机/中断事件、通知动作和停止收尾按播放器与源代次隔离；当前房间事件不等待旧房间暂停收尾，duck 恢复保留用户音量和静音。131 项定向回归通过，详见[音频绑定审计](docs/AUDIO_SESSION_OWNERSHIP_AUDIT_2026_09_05.md)。不将此证据当作历史 PiP 黑屏已复验通过。
- **Android 系统要求**：Android 8.0 / API 26 及以上（与当前 FFmpegKit 原生录制依赖一致）
- **v3.0.0 上游源码基线**：`liuchuancong/pure_live@e808dcae`；完整记录见 `docs/STAGE_UPDATE_3_0_0.md`
- **本轮构建平台**：Android arm64-v8a、Windows x64 安装程序与便携 ZIP；其他平台继续使用 v3.0.0 安装包
- **质量门禁**：播放器来源/Surface/几何回归见 `docs/PLAYER_RECOVERY_AUDIT_3_0_15.md`，十个平台录制链路见 `docs/RECORDER_REPAIR_AUDIT_2026-08-27.md`

本版本还会在启动、备份恢复和手动清理时剔除空平台、空房间号、`0/null/undefined/nan/none` 等无效关注记录，并按“平台 + 房间号”去重，避免损坏的历史收藏继续参与首页刷新。

录制页的自动重连、轮询、缓存限制、最高画质和目录命名等开关现在直接绑定持久化配置；缓存限制改为实时读取，重新进入页面或升级后保持用户选择。
Android 录制在创建任务和申请存储权限前检查目录：应用私有目录会提示选择可导出的目录且不会留下“未启动”幽灵任务；工作资料等任意数字用户空间均能正确识别，外部同名文件夹不会误判。

![Pure Live 界面预览](assets/images/banner.png)

---

## 📺 支持平台

Pure Live 聚合多个第三方直播平台，并支持自定义直播源：

- **Bilibili**
- **虎牙直播（Huya）**
- **斗鱼直播（Douyu）**
- **快手（Kuaishou）**
- **抖音（Douyin）**
- **网易 CC 直播**
- **Twitch**
- **SOOP Live**
- **YY Live**
- **自定义 M3U / M3U8 直播源**

支持按照平台、分区等条件进行筛选，也可以隐藏不关注的平台。

**未发布开发源码另有** AcFun、Picarto、TwitCasting、猫耳 FM、映客、克拉克拉、花椒、OPENREC / mellow-fan、TTingLive / FLEX TV。上面的既有平台列表与本段源码范围分别看待；各入口、原生证据和未完成能力以[平台能力表](docs/PLATFORM_COMPATIBILITY.md)为准，不把测试数量或可返回媒体地址当成完整观看/录制通过。

### 自定义直播源

支持导入：

- M3U
- M3U8
- 本地直播源
- 网络直播源

可以按照分区、平台和频道进行管理。

---


## 文档

| 文档 | 内容 |
| --- | --- |
| [文档索引](docs/README.md) | 开发、发布、依赖和功能文档入口 |
| [维护范围与问题处置策略](MAINTENANCE_POLICY.md) | 平台支持边界、Issue 分流、Bug 来源判定、上游 Issue 优先级与完成标准 |
| [上游同步审查策略](UPSTREAM_REVIEW_POLICY.md) | 三方差异、语义变更台账、冲突处置与合并门禁 |
| [构建与发布](docs/BUILD_AND_RELEASE.md) | 本机质量门禁、签名、打包和 Release 流程 |
| [Windows 数据与升级](docs/WINDOWS_DATA_AND_UPGRADE.md) | 安装目录存储、关注恢复、换盘迁移和回滚 |
| [Windows MSIX 证书说明](docs/MSIX_INSTALL.md) | 自行构建 MSIX 时的证书指纹核对与安装步骤 |
| [依赖与接口审计](docs/DEPENDENCY_AUDIT.md) | 固定工具链、升级约束和接口探测范围 |
| [平台接口与兼容性](docs/PLATFORM_COMPATIBILITY.md) | 分区、搜索、弹幕和人数指标的当前能力 |
| [高刷新率与性能验证](docs/PERFORMANCE.md) | Android 120 Hz 适配、渲染优化和真机帧统计 |
| [v3.1.8 录制会话时间修复](docs/STAGE_UPDATE_3_1_8.md) | 自动续接与用户录制会话时间解耦、持久化兼容、Android/Windows 双平台交付 |
| [v3.1.8 Windows 运行审计](docs/WINDOWS_RUNTIME_AUDIT_3_1_8.md) | Bilibili 播放、远端/本地弹幕、短录媒体实读、退出回落与最终大小口径修正 |
| [v3.1.7 虎牙醒目留言事件身份修复](docs/STAGE_UPDATE_3_1_7.md) | 平台事件 ID、合法重复留言、有界去重缓存与双平台交付 |
| [v3.1.6 虎牙醒目留言实时刷新修复](docs/STAGE_UPDATE_3_1_6.md) | 通知/WUP 时序根因、非阻塞有界补偿、双平台安装包与验证边界 |
| [v3.1.5 Android / Windows 双平台发布](docs/STAGE_UPDATE_3_1_5.md) | 同源版本冻结、分平台串行构建、安装包、签名状态与校验说明 |
| [v3.1.4 Android 平板关注刷新修复](docs/STAGE_UPDATE_3_1_4.md) | 横屏平板下拉刷新根因、移动平台判定、触控链路与交付证据 |
| [v3.1.3 Android / Windows 阶段更新](docs/STAGE_UPDATE_3_1_3.md) | 多画面真全屏退出根因、安全区控件、手势隔离和双平台交付证据 |
| [v3.1.2 Android / Windows 阶段更新](docs/STAGE_UPDATE_3_1_2.md) | Windows 真全屏根因、窗口往返、定向回归与发布证据 |
| [v3.1.1 Android / Windows 阶段更新](docs/STAGE_UPDATE_3_1_1.md) | 多画面声音、音量、弹幕目标、持久化、根因与发布证据 |
| [v3.1.0 Android / Windows 验收矩阵](docs/ACCEPTANCE_MATRIX_3_1_0.md) | 快速回归顺序、全功能实机账本、平台/录制/性能矩阵与发布门禁 |
| [2026-08-31 近期 Issue 审计](docs/ISSUE_AUDIT_2026_08_31.md) | #818 后台播放实机根因、最新 Issue 归因与 v3.1.0 处理范围 |
| [v3.1.0 直播录制参考项目审计](docs/RECORDER_REFERENCE_AUDIT_3_1_0.md) | biliup / bililive-go 固定基线、协议韧性、录制状态机和平台引入门槛 |
| [v3.1.0 网络代理链路审计](docs/NETWORK_PROXY_AUDIT_3_1_0.md) | API、封面头像、弹幕 WebSocket、全角地址输入与代理故障边界 |
| [v3.1.0 阶段更新](docs/STAGE_UPDATE_3_1_0.md) | Android / Windows 更新范围、根因、验证证据、安装包与回滚说明 |
| [WebDAV 配置](docs/WEBDAV.md) | 通用配置字段、坚果云示例和故障排查 |
| [v3.0.0 全平台稳定版](docs/STAGE_UPDATE_3_0_0.md) | 最新上游状态绑定、Android 录制恢复、依赖锁与全平台发布门禁 |
| [v3.0.1 Android 竖屏直播适配](docs/STAGE_UPDATE_3_0_1.md) | 稳定源方向识别、普通页自适应、全屏策略、画中画比例和房间覆盖 |
| [v3.0.2 Android 播放比例修复](docs/STAGE_UPDATE_3_0_2.md) | 普通横屏 16:9 边界、竖屏适配隔离、原生单层缩放与弹幕主题布局 |
| [v3.0.3 Android 竖屏 Surface 修复](docs/STAGE_UPDATE_3_0_3.md) | 原生/应用层几何统一、切换时序和横屏直播记录自适应双列 |
| [v3.0.4 Android 可信画面比例修复](docs/STAGE_UPDATE_3_0_4.md) | 移动端单一比例控制、异常元数据回退与历史记录数量/日期增强 |
| [v3.0.5 Android 有效画面识别](docs/STAGE_UPDATE_3_0_5.md) | 黑边内嵌竖屏识别、三档互动面板、横屏沉浸背景与动态 PiP |
| [v3.0.6 Android 竖屏几何仲裁修复](docs/STAGE_UPDATE_3_0_6.md) | 抖音流元数据识别、裁边代际隔离、延迟有效采样与渲染一致性门禁 |
| [v3.0.7 Android 竖屏真实画布修复](docs/STAGE_UPDATE_3_0_7.md) | 截图/解码坐标隔离、原生纹理防拉伸与显式横屏全屏入口 |
| [v3.0.8 Android 竖屏与小窗比例修复](docs/STAGE_UPDATE_3_0_8.md) | 抖音选中流几何、可逆居中裁边、动态应用小窗与 PiP 可视区域 |
| [v3.0.11 Android 跨模式比例隔离修复](docs/STAGE_UPDATE_3_0_11.md) | 清理 3.0.10 错误草稿、共享 fit 状态隔离与全屏局部竖屏视口 |
| [v3.0.12 录制与全平台画质审计](docs/RECORDING_AND_QUALITY_AUDIT_3_0_12.md) | 十个平台画质名称/排序/真实请求、录制重连、分片隔离、原子合并与资源边界 |
| [v3.0.13 十个平台录制修复](docs/RECORDING_AUDIT_3_0_13.md) | 严格房间状态、播放完整元数据、Android 首次初始化、原始 FFmpeg 参数向量与可见失败诊断 |
| [v3.0.13 Android 阶段更新](docs/STAGE_UPDATE_3_0_13.md) | 版本范围、关键修复、质量门禁与正式交付要求 |
| [v3.0.15 播放器回归修复审计](docs/PLAYER_RECOVERY_AUDIT_3_0_15.md) | 3.0.14 回归来源、路径/首帧门控撤除、竖屏几何恢复、推测式超时下线与回滚策略 |
| [v3.0.18 Android 真机播放与录制加固](docs/STAGE_UPDATE_3_0_18.md) | Android 硬解截图探测隔离、虎牙单连接签名刷新、跨重试录制统计与录制中心真机边界验证 |
| [v3.0.19 Windows x64 稳定版](docs/STAGE_UPDATE_3_0_19_WINDOWS.md) | Windows 启动按需初始化、播放器资源释放、录制统计、Escape、弹幕交互与正式安装/便携包验证 |
| [v3.0.17 播放与录制连续性更新](docs/STAGE_UPDATE_3_0_17.md) | 用户播放意图/音频焦点统一、直播暂停/EOF 恢复、分片真实大小与录制中心有界滚动 |
| [v3.0.16 播放器与录制阶段更新](docs/STAGE_UPDATE_3_0_16.md) | 生命周期单一所有权、Android Surface/几何、录制按需清晰度/线路、斗鱼输入与录制中心稳定性 |
| [2026-08-27 录制链路审计](docs/RECORDER_REPAIR_AUDIT_2026-08-27.md) | 十个平台录制契约、斗鱼/虎牙线路游标、FFmpeg 错误分类、持久化和回滚 |
| [v3.0.14 播放器与录制恢复审计](docs/PLAYER_RECOVERY_AUDIT_3_0_14.md) | 已由 v3.0.15 纠正的恢复设计及 FFmpeg 故障分层历史记录 |
| [v3.0.14 Android 阶段更新](docs/STAGE_UPDATE_3_0_14.md) | 播放器稳定性修复、目标产物与正式交付门禁 |
| [v3.0.9 Android 竖屏原生缩放修复](docs/STAGE_UPDATE_3_0_9.md) | 抖音官方几何模型、移动端单层缩放、实测裁边与四种呈现统一 |
| [2026-08-25 上游 Issue 审计](docs/ISSUE_AUDIT_2026_08_25.md) | #793～#798、#791 录制根因及既有问题处理状态 |
| [v2.9.7 Android update](docs/STAGE_UPDATE_2_9_7.md) | 全平台观看指标语义、热门排行、SOOP PC/移动端总在线与 40 项接口门禁 |
| [v2.9.6 Android update](docs/STAGE_UPDATE_2_9_6.md) | 上游同步、抖音 Feed、Bilibili 热度排行与 40 项接口门禁 |
| [v2.9.5 Android update](docs/STAGE_UPDATE_2_9_5.md) | 全平台画质切换契约、横屏自适应面板、观看指标与接口回归 |
| [v2.9.4 全平台稳定版](docs/STAGE_UPDATE_2_9_4.md) | 上游多画面、录制目录保护、平台签名/快手兼容与全平台交付 |
| [v2.9.5 上游 Issue 审计](docs/ISSUE_AUDIT_2026_08_24.md) | #778、#779、#780、#782、#783、#784, #785 的复现、根因与处理结果 |
| [v2.9.3 Android 专项更新](docs/STAGE_UPDATE_2_9_3.md) | 横屏画质/线路内容驱动布局与小视口边界保护 |
| [v2.9.2 Android 专项更新](docs/STAGE_UPDATE_2_9_2.md) | 横屏画质/线路、四宫格直播记录与左右分栏实时弹幕预览 |
| [v2.9.1 Android 专项更新](docs/STAGE_UPDATE_2_9_1.md) | 横屏半屏内容面板、本地弹幕个性化与渲染缓存 |
| [v2.1.5 阶段更新](docs/STAGE_UPDATE_2_1_5.md) | 本地弹幕同步、列表阅读、模板状态和 Windows 平滑滚动 |
| [v2.1.6 Android 播放修复](docs/STAGE_UPDATE_2_1_6.md) | 音频/视频切换灰白画面与后台音频生命周期 |
| [v2.2.0 阶段更新](docs/STAGE_UPDATE_2_2_0.md) | 播放恢复、音频模式、弹幕设置、Windows 多开与最终验证 |
| [v2.3.0 稳定性更新](docs/STAGE_UPDATE_2_3_0.md) | PiP 返回弹幕恢复、启动刷新、横屏输入、长时间资源边界与验收状态 |
| [v2.7.0 阶段稳定版](docs/STAGE_UPDATE_2_7_0.md) | 最新上游整合、热门页生命周期与全平台阶段发布 |
| [v2.6.0 阶段稳定版](docs/STAGE_UPDATE_2_6_0.md) | 上游同步、近期 Issue、字体/SC/播放器与全平台阶段发布 |
| [v2.5.0 阶段稳定版](docs/STAGE_UPDATE_2_5_0.md) | 首页有界并发、三档刷新率、Windows 视频纹理与依赖/上游审计 |
| [近期 Issue 审计](docs/ISSUE_AUDIT_2026_08_23.md) | #769、#770、#771、#773 与 Windows 高 DPI 问题映射 |
| [参与贡献](CONTRIBUTING.md) | 分支、提交、测试和 Pull Request 要求 |
| [安全策略](SECURITY.md) | 私密漏洞报告和签名材料管理 |
| [版本说明](RELEASE_NOTES.md) | 当前版本变更与历史记录 |

## ✨ 核心功能

### 🎬 多平台直播

- 聚合多个主流直播平台。
- 支持平台分区浏览。
- 支持跨平台搜索。
- 支持直播 / 未开播筛选。
- 支持综合、平台顺序、观众和粉丝等排序方式。
- 各个平台保持独立分页状态。
- 快手保留网页搜索入口。
- 离线频道按照平台接口实际返回结果展示。

### ▶️ 多播放器

Android / Android TV 支持多个播放器：

- IJKPlayer
- EXOPlayer
- MPV Player

当某个播放器出现黑屏、卡顿、硬解兼容性问题或者特定直播流无法播放时，可以在设置中切换播放器。

Windows、Linux、macOS 等桌面平台使用对应平台的播放器实现。

### 🖥️ 多画面同看

- 支持双画面、四画面和一大多小聚焦布局。
- 每格独立播放、暂停、音量、清晰度和线路，只有聚焦画面出声。
- 聚焦画面可接入平台弹幕；快速切换使用最新音频焦点，避免多个画面同时出声。
- 移动端最多同时保留 4 路解码，桌面端最多 9 路，并可让小画面自动使用低清晰度以控制占用。
- Windows 每格按实际可见物理尺寸和源分辨率防抖协商渲染输出；切换布局、晋升大画面和缩放窗口时保留播放会话，同时避免沿用旧格纹理。详见[多画面渲染目标审计](docs/MULTIVIEW_RENDER_TARGET_AUDIT_2026_09_11.md)。

### 💬 弹幕系统

提供完整的弹幕控制能力：

- 弹幕过滤
- 用户屏蔽
- 关键词屏蔽
- 弹幕描边
- 弹幕透明度
- 字号调整
- 速度调整
- 显示区域调整
- 最大弹幕数量
- 发送间隔控制
- 刷新 FPS
- 平台原始颜色
- 统一弹幕颜色
- 应用界面动态最高刷新率，弹幕渲染智能省电适配
- 弹幕点击与长按操作
- 字体粗细与观看模板联动
- 精确重复和相似文本两级过滤

弹幕系统采用房间会话隔离、平台消息 ID 去重以及过期队列淘汰机制，减少切换直播间后出现：

- 串房弹幕
- 重复弹幕
- 旧弹幕重新出现
- 几分钟前积压弹幕突然播放

### 🪟 小窗弹幕

进入：

**设置 → 视频设置 → 小窗弹幕**

或者在直播间进入：

**弹幕设置**

即可配置小窗弹幕。

支持：

- Android 系统画中画
- Windows 小窗
- 应用内悬浮窗
- 独立弹幕控制器
- 独立弹幕队列
- 独立弹幕样式
- 自动根据窗口尺寸缩放
- 最大弹幕数量
- FPS 调整
- 速度调整
- 显示区域调整
- 弹幕字号和透明度
- 弹幕点击和长按

小窗弹幕不会污染主播放器弹幕队列。

配置会保存到本地，下次进入直播间后继续生效。

“最佳观看”模板默认将弹幕限制在画面顶部约 20% 区域，以减少弹幕对画面的遮挡。

主播放器、小窗以及 Windows 桌面端统一使用 px/s 速度和逻辑帧时钟。

切换横竖屏或者应用从后台恢复时，不会根据后台停留时间产生大量弹幕补跳。

### 📺 高刷新率

Android 支持根据设备显示模式动态适配刷新率：

- 自动监听当前显示模式
- 请求当前分辨率支持的最高刷新率
- 适配 60 Hz / 90 Hz / 120 Hz 等高刷新率设备
- 优化封面图片解码
- 优化图片缓存
- 优化弹幕重绘
- 应用界面跟随设备最高刷新率；自动弹幕主画面 60 FPS、小窗 30 FPS，手动模式最高 240 FPS

---

## 🔍 搜索与直播互动

支持跨平台直播搜索，并提供独立的平台分页状态。平台选择栏可访问屏幕外项目，但首尾严格有界；“全部”搜索按平台完成顺序渐进显示，单个平台超时或失败不会挡住其他结果。相邻页完整重叠时保留一次继续机会，连续第二个停滞页有界结束，避免漏掉后页或对固定响应无限追加；同一平台与关键词的未完成首屏重复提交共享一次请求，聚合结果已部分呈现时也不会重新请求，完成后仍可主动刷新。详见[搜索分页审计](docs/SEARCH_PAGINATION_STAGNATION_AUDIT_2026_09_11.md)与[搜索提交事务审计](docs/SEARCH_SUBMIT_TRANSACTION_AUDIT_2026_09_11.md)。

搜索结果支持：

- 综合排序
- 平台顺序
- 观众人数
- 粉丝数量
- 直播状态筛选
- YY 等九个平台原生/本机搜索，快手保留网页搜索
- Bilibili、斗鱼、虎牙、抖音、快手、网易 CC、Twitch、SOOP、YY 网页直播间识别

同时提供本地互动系统。

本地用户与互动数据可以保存：

- 昵称
- 头衔
- 弹幕输入
- 体验币
- 平台身份徽章
- 礼物目录
- 等级风格
- 画面礼物效果

这些数据默认保存在本机。

可以通过：

**设置 → 本地用户与互动**

统一启用或关闭相关功能。

---

## 🧭 底部导航

**设置 → 导航栏显示控制** 可以显示、隐藏和排序收藏、热门、分区及录制中心页签。至少保留一个可用页签；
只有当前显示的多个页签提供拖动排序入口，异常或旧版配置中的重复、未知与空白 ID 会在加载时自动整理。

---

## 👀 观看数据

Pure Live 会区分不同平台的观看数据口径：

- 热度
- 真实在线人数
- 累计观看人数

其中抖音、快手、网易 CC、Twitch、SOOP、AcFun、Picarto、TwitCasting、
mellow-fan（OPENREC）和 FLEX TV（TTingLive）可以显示平台明确返回的并发人数。

设置页会列出全部 21 个普通直播平台。虎牙、Bilibili、斗鱼等平台按照公开数据实际提供的热度、
累计观看或未知状态展示，不把这些字段混作并发人数；不支持并发人数的平台保留关闭态并显示口径说明。

可以通过：

**设置 → 通用 → 观看数据与排行口径**

选择排行方式，并管理支持人数统计的平台。

---

## 🎧 ASMR / 助眠模式

Android 支持 ASMR 助眠模式。

可以设置：

- 新房间自动进入纯音频
- 媒体保活
- 自定义自动停止时间
- 后台持续播放

房间内的耳机图标只控制当前房间的纯音频状态。

电视图标用于投屏。

前台手动进入音频模式时保留同一播放器的视频解码热状态，切回画面通常可直接复用当前纹理；应用进入后台后立即停用视频轨以降低解码和电量开销，回到前台再静默预热。深度恢复期间显示低开销音频卡片和明确进度，不再以黑屏或整页转圈阻塞操作。

当前各平台通常返回音视频复用直播流；关闭视频轨主要节省解码、GPU 与电量，并不等同于只下载音频。只有平台明确提供独立音频地址时，才可能同时实现网络流量显著下降和无等待画面恢复。

---

## ⏺️ 直播录制

支持直播流实时录制。

可以将直播保存到本地，在直播结束后进行回放。

选择自定义位置时，程序只写入该位置下带所有权标记的 `PureLiveRecords` 专用子目录；“清空录制文件目录”和自动容量限制均只处理该目录，不会遍历删除所选父目录中的其他文件。

支持配合：

- 直播录制
- 定时关闭
- 后台音频
- 系统媒体通知

进行长时间观看或助眠使用。

---

## ⏰ 定时关闭

支持设置倒计时自动停止播放或退出应用。

适用于：

- 睡眠
- ASMR
- 长时间观看
- 后台音频播放

---

## 💾 数据管理

支持：

- 本地配置导出
- 本地配置导入
- WebDAV 同步
- WebDAV 备份
- M3U / M3U8 导入
- 配置恢复

备份格式目前为 **v3**。

默认情况下：

- Cookie 不进入普通同步备份
- WebDAV 凭据不进入普通同步备份

旧版本备份文件仍然建议按照敏感文件进行保管。

---

## 🔐 Firebase 用户同步

项目支持可选的 Firebase 用户同步功能。

Firebase 不是 Pure Live 使用的必要条件。

如果需要使用 Firebase 功能，可以 Fork 项目，并在自己的 Firebase 项目中配置对应服务。

应用不会要求所有用户必须注册账号。

---

## 📥 下载

前往 [维护分支 GitHub Releases](https://github.com/wzgrx/pure_live/releases/latest) 获取最新安装包，并使用同一 Release 的 `SHA256SUMS.txt` 校验完整性。

### Android

当前 Android 正式包以 `arm64-v8a` 为主，适用于当前主流 64 位 ARM 手机和平板。更新页读取版本清单中的实际 ABI 列表，只展示对应 Release 实际发布的下载链接。

Android 始终使用正式包名：

`com.mystyle.purelive`

不再生成并存 QA 包。

正式 Release 使用仓库专用持久签名，因此可以直接覆盖旧的正式版本。

缺少正式发布密钥的本机测试包使用调试签名。

发布脚本会阻止调试签名进入正式 Release。

### Windows

提供：

- Windows x64
- 便携 ZIP
- EXE 安装器

EXE 安装向导支持选择其他磁盘，并把设置、关注、历史、IPTV、录制和缓存集中保存到安装目录 `AppData`。便携 ZIP 不包含运行时数据。

自行构建 MSIX 时的证书配置见 [Windows MSIX 证书说明](docs/MSIX_INSTALL.md)。

### macOS

源码保留 Intel x64、Apple Silicon arm64 与 Universal 构建能力。本维护分支缺少持续使用的 macOS 设备，相关产物只在 Release 明确列出时成立，并标为社区验证。

### Linux

源码保留 Linux x64 构建能力。Linux 网页搜索会交给系统浏览器，原生搜索与播放继续在应用内完成；本维护分支缺少常规运行验证。

### iOS

源码保留 iOS arm64 设备构建能力。相关 `.app`、签名和 IPA 状态以具体 Release 说明为准，本维护分支缺少持续使用的 iOS 设备。

---

## 🧪 本地构建与验证

项目固定使用 Flutter `3.47.0` / Dart `3.13.0`、AGP `9.3.1`、Gradle `9.5.0` 与 Java 25 构建运行时，Android 应用和插件字节码目标保持 Java/Kotlin 17。资源档位、串行平台阶段和增量缓存规则见 [构建资源策略](BUILD_POLICY.md)。正式交付的完整质量门禁：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1 -Scope Full
```

安装包每次只构建本轮明确指定的一个平台与变体，例如 Android arm64 正式包：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 `
  -Target AndroidArm64 -Configuration Release -FullRegression -RequireReleaseSigning
```

当前稳定版的源码基线、修复范围、验证证据、实际构建平台和产物校验见顶部版本条目及对应阶段文档；通用门禁和单平台串行发布流程见[构建与发布](docs/BUILD_AND_RELEASE.md)。

## 🤝 参与开发

- **主开发者**：[@liuchuancong](https://github.com/liuchuancong)
- **协助开发者**：[@wzgrx](https://github.com/wzgrx/pure_live)
- **协助开发者**：[@RebornQ](https://github.com/RebornQ)

> 📌 **欢迎贡献维护型修复、测试和文档**！
> - 如发现 License 使用不当，请提交 Issue 或 Pull Request
> - 本仓库 Issue 聚焦可复现 Bug；新增功能和产品建议统一提交到[原项目](https://github.com/liuchuancong/pure_live/issues/new/choose)

### 代码参考
- [dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live)
- [pure_live (Jackiu1997)](https://github.com/Jackiu1997/pure_live)

---

## 🌟 Star 趋势

如果 Pure Live 对你有帮助，欢迎给项目一个 ⭐ Star：

## Star History

<a href="https://www.star-history.com/?repos=liuchuancong%2Fpure_live&type=date&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=liuchuancong/pure_live&type=date&theme=dark&legend=bottom-right&sealed_token=7TCHJ1imubZUrHskxy4Fj--g2rclGNfNcTikzBHUf3sq9UyOFMIc2Seh8xnBxICxbcuc33QXSM34ooqO-iEpmwbF9JdlGslt_OSSHpPQqMSWBnOYCZoyWOK7vMh0OxfC9TyY_7cFplT_pTHUNrs3RYVg3GZfjqE1ezf5E9fH7_DTDNxxvD5jUlyqDNpT" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=liuchuancong/pure_live&type=date&legend=bottom-right&sealed_token=7TCHJ1imubZUrHskxy4Fj--g2rclGNfNcTikzBHUf3sq9UyOFMIc2Seh8xnBxICxbcuc33QXSM34ooqO-iEpmwbF9JdlGslt_OSSHpPQqMSWBnOYCZoyWOK7vMh0OxfC9TyY_7cFplT_pTHUNrs3RYVg3GZfjqE1ezf5E9fH7_DTDNxxvD5jUlyqDNpT" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=liuchuancong/pure_live&type=date&legend=bottom-right&sealed_token=7TCHJ1imubZUrHskxy4Fj--g2rclGNfNcTikzBHUf3sq9UyOFMIc2Seh8xnBxICxbcuc33QXSM34ooqO-iEpmwbF9JdlGslt_OSSHpPQqMSWBnOYCZoyWOK7vMh0OxfC9TyY_7cFplT_pTHUNrs3RYVg3GZfjqE1ezf5E9fH7_DTDNxxvD5jUlyqDNpT" />
 </picture>
</a>

---

## ☕ 捐助支持

如果您觉得本项目对您有帮助，欢迎扫码支持开发者一杯咖啡 ☕

<p align="center">
  <img src="https://github.com/liuchuancong/pure_live/blob/master/assets/images/wechat.png" width="350" alt="WeChat Donate">
</p>

> 您的支持是我持续维护的动力！感谢 ❤️
