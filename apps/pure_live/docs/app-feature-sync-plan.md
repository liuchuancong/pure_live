# 功能同步计划（参考仓 → v2）

参考实现：`C:\Users\XA-158\projects\study\PureLive`（用户的原应用 v4 workspace）。
用户 2026-10-21 指定：按参考项目**分批同步**，每批一个提交，批内页面/功能/设置一起对齐。

## 硬约束（每一波都适用）

1. **播放走 media_core**：页面只经 `system/playback/playback_engine.dart` 的接缝，不直接碰播放库。
2. **数据模型用本仓 `packages/live_sites`**：参考仓的模型只作行为参照，字段按 live_sites 实读（可空性/变体数不得凭记忆）。
3. **配置按域补**：新配置项写进 `system/configuration/preferences/<域>_preferences.dart`，facade 加 getter/copyWith 参数；不再往单一文件里堆。
4. **UI 走 pure_uikit 分派**：不直接 import 设计语言库，不手绘别家控件。

## 差距盘点（2026-10-21）

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
| B3 | 房间·附件（⏸ 用户指令：先基础页面） | live_play/{mini,switch_room,logic} | 🟡 重连阶梯 6106be436、后台播放 acd14002b；剩 mini 播放器/切房间/音频焦点/预测返回（需原生或列表上下文） |
| B4 | 播放器视图（⏸ 同 B3） | live_play/player/8 | ⬜（手势 W1 已完成） |
| B5 | 多画面 | multiview/10 | ✅ 审计：v2 有 1/2/4/6/9 布局、选房、逐格静音与全静音、布局持久化；参考多出的是 TV 焦点栏/几何细化 |
| B6 | 录制/IPTV | recorder/、iptv/ | ✅ 审计：v2 体量相当（录制 718+649 行、IPTV 544+1104 行），既有等价 |
| B7 | 账号/备份：账号三视图、WebDAV、日志页 | account/14、backup/5、web_dav/5 | 🟡 盘点：v2 已有等价（账号名单/编辑器/QR 登录、备份+WebDAV 1012 行、日志页）；开播提醒按标签 f8a6a2760 |
| B8 | 设置全量 | settings/16 | 🟡 并发刷新任务 522969fc0、屏幕常亮 e1893639e、首选直播平台 937cb4d8a；审计：外观页已覆盖纯黑/主题色/密度/字体/壁纸/动画等，剩余为动态取色与内核/兼容模式（依赖平台/引擎） |
| B9 | TV UI 树 | tv/54 | 🟡 关注焦点墙 08695da19（TvFocusCard/TvRoomWall/TvFollowView）；剩 热门/分区/历史/IPTV 的 TV 面板、TV 设置与视频/音乐模式 |
| B10 | VOD | live_vod 包、tv/video | ⬜ |

## 顺序调整（2026-10-21 用户指令）

**先做基础页面（设置/账号/备份/历史/关于/IPTV/录制/多画面/工具箱等），房间页与播放器相关的工作（B3、B4）暂停**，
等基础页面完成后回头再做。因此实际执行顺序：**B7（账号/备份）→ B8（设置全量）→ B6（录制/IPTV 页面）→ B5（多画面）→ B9（TV 树）→ B10（VOD）**，
其中 B1/B2 已完成。

## 逐页推进（用户 2026-10-21 指定顺序）

- [x] 关注页（462829607）：观众重排 + 标签权重 + 平台 tab 按用户平台序（+8 测试）
- [x] 热门页（5ed4d75b2）：不可播放过滤（轮播/限制/登录）+ `showUnplayableInDiscover` 开关与设置行（+5 测试）
- [x] 分区页（d138cab27）：区域图按名称互借 + 双态图标取色半 + 房间列表同过滤（+6 测试）
- [ ] 搜索页：借用发现页过滤；联想/结果增强
- [ ] 历史页：分组/清理增强
- [ ] 后续页依次推进（房间页细节、设置页、关于/更新等）

## 波次（按价值/独立度排序，先前规划，仍有效）

- [x] **W1 播放手势层**（2026-10-21）：音量/亮度半区拖动 + 档位浮层 + 滚轮调音量 + 松手写回设备类默认音量。新增 `features/room/widgets/room_gesture_layer.dart`，`room_video_surface` 原手势并入。
- [ ] **W2 本地互动**：房间内自己的弹幕/礼物（composer、面板、样式面板、礼物目录/等级/成长），v2 侧以 `RoomLocalMessageBus` 为投递口；配置进 local_interaction 域。
- [ ] **W3 mini 播放器/悬浮窗**：从房间收进小窗继续看（pip 域字段已存在，补 UI 与生命周期）。
- [ ] **W4 切房间面板**：播放器内左滑/面板切上一个下一个房间。
- [ ] **W5 后台播放与重连看护**：background_playback/audio_focus/reconnect_watch 三条逻辑。
- [ ] **W6 多画面增强**：布局与交互对齐参考。
- [ ] **W7 TV UI 树**：按参考 tv/* 移植，入口 `platforms/tv/`。
- [ ] **W8 VOD**：先定能力边界（依赖 live_vod 语义）再落页面。
- [ ] **W9 历史/搜索增强**。

## 与并行工作的边界

- 分支表/路由改动须重跑 build_runner（曾因漏跑导致 goBranch 错位）。
- `git add` 前查 `test/tool/failures/`（金图临时产物）。
- 参考仓的 `live_store`（drift/per-key setting）**不照搬**：v2 的存储是 Hive CE + 分域 JSON 文档（用户已定案）。
