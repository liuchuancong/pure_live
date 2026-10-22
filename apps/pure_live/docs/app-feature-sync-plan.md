# 功能同步计划（参考仓 → v2）

参考实现：`C:\Users\XA-158\projects\study\PureLive`（用户的原应用 v4 workspace）。
用户 2026-10-21 指定：按参考项目**分批同步**，每批一个提交，批内页面/功能/设置一起对齐。

## 硬约束（每一波都适用）

1. **播放走 media_core**：页面只经 `system/playback/playback_engine.dart` 的接缝，不直接碰播放库。
2. **数据模型用本仓 `packages/live_sites`**：参考仓的模型只作行为参照，字段按 live_sites 实读（可空性/变体数不得凭记忆）。
3. **配置按域补**：新配置项写进 `system/configuration/preferences/<域>_preferences.dart`，facade 加 getter/copyWith 参数；不再往单一文件里堆。
4. **UI 走 pure_uikit 分派**：不直接 import 设计语言库，不手绘别家控件。

## 差距盘点（2026-10-21 快照）

> 2026-10-22：下表缺口已全部由 B1–B10 补齐或审计等价，保留作历史对照；实时状态看台账。

| 域 | 参考 | v2 | 缺口 |
|---|---|---|---|
| 房间/播放 `live_play` | 79 文件 | 26 文件 | 手势层（本次已补）、本地互动 6.8k 行、mini 播放器/悬浮窗、切房间面板、后台播放/音频焦点/播放列表/预测返回/重连看护 |
| TV | 54 文件（home/music/pages/room/settings/video/wallpaper/widgets） | shell + room layout | 整棵 TV UI 树、音乐模式 |
| VOD | `live_vod` 整包 | 无 | 录播/点播能力 |
| 多画面 | 10 文件 | 2 文件 | 分屏布局/交互 |
| 历史 | 4 文件 | 1 文件 | 分组/清理/搜索 |
| 搜索 | 9 文件 | 5 文件 | 联想/结果过滤增强 |
| web_dav | 独立域 5 文件 | backup 内 | 已等价，不单列 |

## 分批台账

| 批 | 范围 | 参考文件 | 状态 |
|---|---|---|---|
| B1 | 发现流收尾：搜索/历史接入发现过滤 | search/9、history/4 | ✅ 182ab726c |
| B1b | 搜索排序：4 模式 + 离线过滤 + 排序 UI | search/search_ranking.dart | ✅ 77b2b03a6（+5 测试） |
| B2 | 房间·本地互动 | live_play/local_interaction/16（6.8k 行） | ✅ B2a 3c9d55d98（礼物+等级）、B2b f2e58692b（预设样式+等级读数） |
| B2c | 礼物横幅（一屏一张、大额大卡、预设着色、可关） | local_gift_effect | ✅ e1897b16a |
| B3 | 房间·附件 | live_play/{mini,switch_room,logic,audio_focus,predictive_back} | ✅ 重连阶梯 6106be436、后台播放 acd14002b、切房间（RoomPlaylist：列表上下文 + 头部前后切换，六入口）、mini 播放器/PiP（media_core 呈现驱动 + 置顶/小窗几何偏好）、音频焦点（通话/闹钟暂停与恢复、duck、耳机拔出、永久失去）、预测性返回（Android 通道 + MainActivity 覆盖层优先级）；移动端系统 PiP 与应用内悬浮窗属引擎缺口 |
| B4 | 播放器视图 | live_play/player/8 | ✅ 手势 W1、诊断徽章 967502f97、录制徽章 24717c3be、弹幕设置入口 c63a7fb90；控制条逐项核对完毕；**节目单审计**：参考的 view_schedule 是 IPTV 频道节目单（iptv_guide），v2 的 IPTV 播放页已有 EPG 条与节目列表，房间页不适用 |
| B5 | 多画面 | multiview/10 | ✅ 审计：v2 有 1/2/4/6/9 布局、选房、逐格静音与全静音、布局持久化；参考多出的是 TV 焦点栏/几何细化 |
| B6 | 录制/IPTV | recorder/、iptv/ | ✅ 审计：v2 体量相当（录制 718+649 行、IPTV 544+1104 行），既有等价 |
| B7 | 账号/备份 | account/14、backup/5、web_dav/5 | ✅ 审计等价（账号名单/编辑器/QR 登录、备份+WebDAV、日志页）；开播提醒按标签 f8a6a2760 |
| B8 | 设置全量 | settings/16 | ✅ 并发刷新 522969fc0、屏幕常亮 e1893639e、首选平台 937cb4d8a、动态取色 c9fee55c4；仅剩内核/兼容模式（依赖引擎能力，随 media_core） |
| B9 | TV UI 树 | tv/54 | ✅ 关注/热门/分区/历史/频道/设置/视频/音乐 全部落地（08695da19…ed2e2ed54）；播放器抽为 musicPlayerProvider 供双端共用 |
| B10 | VOD | live_vod 包、tv/video | ✅ B10a ✅；**B10b ✅ 音乐**：队列/音频地址 d631d7fc6、音乐页走 media_core_audio 5564347a7、歌词条 6710ed886；B10c TV 视频 ✅ e266eda90 / 音乐 ✅ ed2e2ed54；**B10b-3 ✅ 6e54a6e15**：标题解析（7 测试）+ 可插拔 LyricProvider（出厂无服务；覆盖 lyricProvider 即接外部歌词源，歌词条自动生效） |
| B11 | 设置页对齐（2026-10-22 用户：“对比设置页面，同步”） | settings/16 | 🟡 **B11a ✅** 外观页「列表显示」组：加载样式/房间卡片/页面设置三个原本无入口的子页 + 列/行间距滑块（`FeedPreferences` 新增 `crossAxisSpacing`/`mainAxisSpacing`，七处网格生效，顺带修复 `FeedPreferences.copyWith` 漏转发 `liveAlertTagIds`/`preferredSiteId`/`showUnplayableInDiscover`）；**B11b ✅** 视频页「重置小窗位置与大小」；**B11c ✅** 后台播放引导：ROM 族识别（HyperOS/MIUI/ColorOS/OxygenOS/OriginOS/HarmonyOS/MagicOS/One UI/Flyme）、系统状态读取（通知/电池优化/后台限制/流量节省/省电模式）与按厂商的系统页跳转，Kotlin 通道 `pure_live/background_guide`，视频页入口显示待处理数；**B11d ✅** 宽屏也用底栏（`homeBottomBarOnWide`，仅 Android/iOS：平板与展开的折叠屏在首页保留手机底栏，桌面仍用侧栏；导航页新增宽屏组）；**B11e ✅** Twitch 语言筛选（`twitchLanguages` 偏好 + 平台页多选对话框 + `createBuiltInLiveSites(twitchLanguages:)` 接缝，适配器按请求读取）；斗鱼续期审计：v2 的 `DouyuLoginStore` 在凭据可用时已自动续期，参考的开关无需存在。剩：精确字号微调、弹幕列表礼物口径（值钱礼物/换算元/上舰卡片/YouTube 全聊天）、移动小窗与 PiP 弹幕（引擎缺口） |

## 顺序调整（2026-10-21 用户指令）

**先做基础页面（设置/账号/备份/历史/关于/IPTV/录制/多画面/工具箱等），房间页与播放器相关的工作（B3、B4）暂停**，
等基础页面完成后回头再做。因此实际执行顺序：**B7（账号/备份）→ B8（设置全量）→ B6（录制/IPTV 页面）→ B5（多画面）→ B9（TV 树）→ B10（VOD）**，
其中 B1/B2 已完成。

## 状态（2026-10-22 收尾检查）

- 2026-10-22 复核：工作区（根目录 `dart analyze`，含全部包）零问题；B11 后全量 `flutter test` 为 **327 通过 / 12 金图失败**，失败仍全部是待重录的视觉金图。
- 全量 `flutter analyze`：零问题。
- 全量 `flutter test`：**347 通过 / 12 失败**；失败全部是 `test/tool/` 的金图（uikit_closeup ×4、uikit_showcase ×8）——这套金图是用户的视觉验收工具，导航/房间/音乐/TV 的改动改变了渲染，**金图需用户重录**，本轮刻意未动 `test/tool/failures/` 与金图。
- 台账：B1–B10 全部 ✅；2026-10-22 用户要求对比设置页后重开 **B11（🟡，见下行）**，B11a/B11b 已完成。B3 补齐音频焦点（+9 测试）与预测性返回（+3 测试），切房间 +11 测试；B11a/B11b +5 测试、B11c +14 测试、B11d +4 测试、B11e +2 测试。
- 待用户侧：重录 `test/tool` 金图；真机验证音频焦点（来电/耳机拔出）、Android 预测性返回与桌面小窗/PiP。

## 逐页推进（用户 2026-10-21 指定顺序）

- [x] 关注页（462829607）：观众重排 + 标签权重 + 平台 tab 按用户平台序（+8 测试）
- [x] 热门页（5ed4d75b2）：不可播放过滤（轮播/限制/登录）+ `showUnplayableInDiscover` 开关与设置行（+5 测试）
- [x] 分区页（d138cab27）：区域图按名称互借 + 双态图标取色半 + 房间列表同过滤（+6 测试）
- [x] 搜索页（B1/B1b + 2026-10-22 审计）：发现页过滤、4 种排序、分平台分区、主播/分区结果、网页搜索入口齐备；`live_sites` 虽有 `LiveSuggestCapability`，参考仓的搜索页并未使用联想 UI，故无行为可移植。
- [x] 历史页（B1 + 2026-10-22 审计）：今日/昨日/本周/更早分组、关键字过滤、条数上限、逐条刷新、清空与删除均与参考等价；参考的逐房间菜单只是把删除与观看时间放进菜单，v2 用长按删除 + 卡片进度，功能不缺。
- [x] 后续页（B3–B10）：房间页细节、设置、关于/更新、TV、VOD 均已在批次内完成。

## 波次（按价值/独立度排序，先前规划，仍有效）

- [x] **W1 播放手势层**（2026-10-21）：音量/亮度半区拖动 + 档位浮层 + 滚轮调音量 + 松手写回设备类默认音量。新增 `features/room/widgets/room_gesture_layer.dart`，`room_video_surface` 原手势并入。
- [x] **W2 本地互动** → B2/B2c（礼物、等级、预设、横幅、本地消息总线）。
- [x] **W3 mini 播放器/悬浮窗** → B3（media_core 呈现驱动 + 置顶/小窗几何偏好；移动端 PiP/应用内悬浮窗属引擎缺口）。
- [x] **W4 切房间** → B3（RoomPlaylist + 头部前后切换，六入口）。
- [x] **W5 后台播放/音频焦点/重连看护** → B3（重连阶梯、后台暂停、音频焦点）。
- [x] **W6 多画面增强** → B5 审计（布局/静音/持久化已等价）。
- [x] **W7 TV UI 树** → B9。
- [x] **W8 VOD** → B10（视频 + 音乐，media_core_audio）。
- [x] **W9 历史/搜索增强** → B1/B1b + 2026-10-22 审计（无剩余行为缺口）。

## 与并行工作的边界

- 分支表/路由改动须重跑 build_runner（曾因漏跑导致 goBranch 错位）。
- `git add` 前查 `test/tool/failures/`（金图临时产物）。
- 参考仓的 `live_store`（drift/per-key setting）**不照搬**：v2 的存储是 Hive CE + 分域 JSON 文档（用户已定案）。
