# pure_live v2 架构文档(决策稿 v0.5)

> 状态:**推荐定稿(能力分解法,media_core 同粒度)**。v0.4 → v0.5:用 media_core 的分解法(每引擎一包 / 每能力一包 / 跨域能力独立成包 / repository 与 UI 分包)逐项重排,**81 包 + app 壳**;并给出"v1/TV 能力 → v2 包"覆盖表,证明无遗漏。未写业务代码。
> 分支:`v2`。已定:firebase 保留;背景系统(视频/纯色/图片)独立;33 站一站一包(B 站拆 live/vod 两包)。

## 1. 分解方法(为什么是这个数)

media_core 的 26 包不是按大小拆的,是按**能力种类**拆的:每个引擎一包(better_player/fvp/ijk_player/media_kit)、每个播放能力一包(pip/floating/multiview/fullscreen/feed/list_playback/ingest/danmaku/mediasession/cast/download/audio)、平台特定一包(native/win32)、横切一包(logging/memory/presentation/ui)。v2 对整个 App 应用同一方法:

1. **盘点全部用户可见能力**(v1 + TV + lx-music 的每个功能点);
2. 每个能力 → 一个包(跨域共用能力升为 services 层);
3. 每个域的数据层与 UI 层分包(repository / feature);
4. 第三方大件(厂商 SDK)各自隔离包。

结果:**7 层 81 包**。粒度对齐 media_core 的 DNA(它 1 个内核 26 包;我们是整个 App 81 包)。

## 2. 包清单(81 + app,全枚举)

### 2.1 foundation(L0,11 包)——基础设施

utils(公用方法/Result)、logging(talker)、network(dio 客户端工厂/拦截器/cookie/UA 池/gbk)、auth(凭据保险箱+登录流程契约)、storage(kv=hive / db=drift / secure 三面装配)、files(文件处理器:m3u/json 读写、pick/拖拽、哈希校验)、platform(窗口/托盘/深链接/TV dpad/分享接入/亮度音量电池)、backup(备份引擎:版本化格式/WebDAV)、**sync**(多设备持续同步:firebase 面与 LAN bonsoir——与 backup 分开:backup=快照导出导入,sync=持续同步)、release(版本检查/更新提示)、l10n(多语言装配)。

### 2.2 integrations(L0.5,2 包)——第三方大件

firebase(firebase_core/auth/firestore/crashlytics 装配,**已拍板保留**)、media(media_core 接线:引擎装配与选择、mpv 调优、wakelock/audio_session/mediasession)。

### 2.3 ecosystem(L1,5 包)——插件与外观生态

plugin_api(源插件契约 + 契约测试套件,独立 semver)、plugin_host(flutter_js 沙箱 + 注册表/权限/生命周期)、theme(主题引擎:令牌文件 → WindThemeData/ColorScheme,导入导出)、background(背景系统:视频/纯色/图片/渐变 + 暗化模糊 + 画布层级 + 页面规则 + 随机壁纸 API + 用户资源;参考 TV features/wallpaper)、danmaku(弹幕层:flame_barrage 接线/设置/屏蔽词/撤回)。

### 2.4 services(L2,8 包)——跨域能力(新增层)

| 包 | 能力来源 |
|---|---|
| `pure_live_search` | 聚合搜索:live/vod/music 跨源搜索编排(v1 各域散搜 → 统一) |
| `pure_live_history` | 观看历史:跨域统一时间线(live 房间 + vod 选集 + 音乐) |
| `pure_live_favorites` | 收藏:跨域收藏夹/分组 |
| `pure_live_playlist` | 播放队列:音乐队列与 vod 连播共用 |
| `pure_live_remote` | LAN 远控:alfred HTTP 服务 + web_remote 网页(v1 assets/web_remote) |
| `pure_live_cast` | 投屏:dlna_dart 接入 |
| `pure_live_fonts` | 字体仓库:字体下载/缓存/应用(正文+弹幕字体,v1 FontDownloadManager) |
| `pure_live_emote` | 直播表情包:各站表情获取/缓存/渲染索引(v1 emoji_manager) |

### 2.5 ui(L3,5 包)

design(设计令牌唯一权威,纯数据)、ui_kit(组件库,**唯一 import wind 处**)、adaptive(TV/手机/桌面自适应)、**lyric**(歌词渲染组件,flutter_lyric 接线)、**player_ui**(播放器控制层:控制栏/手势层/清晰度线路菜单——v1 core/player/presentation 的重写位)。

### 2.6 sources(L5,35 包)——一站一包,B 站拆双包

`source_acfun`、`source_baidulive`、`source_bigo`、**`source_bilibili_live`**、**`source_bilibili_vod`**、`source_cc`、`source_chzzk`、`source_douyin`、`source_douyu`、`source_fc2live`、`source_huya`、`source_inke`、`source_jdlive`、`source_kilakila`、`source_kuaishou`、`source_kugoulive`、`source_liveme`、`source_looklive`、`source_missevan`、`source_niconico`、`source_pandalive`、`source_picarto`、`source_seventeenlive`、`source_showroom`、`source_sixroom`、`source_soop`、`source_steambroadcast`、`source_tiktok`、`source_twitcasting`、`source_twitch`、`source_weibo`、`source_xiaohongshu`、`source_youtube`、`source_yy`、`source_music_builtin`。

(33 站中 bilibili 拆为 live/vod 两包——媒体_core"每能力一包"的同类处理;TV 端 vod 模块的 api 分文件就是先例。)

### 2.7 features(L4,15 包)——repository 与 UI 分包(VGV 模式,一步到位)

**repository 包(数据+领域,纯 Dart 可单测)**:`pure_live_live_repository`、`pure_live_vod_repository`、`pure_live_music_repository`、`pure_live_iptv_repository`、`pure_live_recorder_repository`、`pure_live_settings_repository`。
**UI 包(页面+controllers)**:`pure_live_live`、`pure_live_vod`、`pure_live_music`、`pure_live_iptv`、`pure_live_recorder`、`pure_live_settings`、`pure_live_account`、`pure_live_backup_ui`、`pure_live_home`(首页模块编排)。

repository 分包的收益立即可见:TV 壳/桌面壳未来直接复用 repository,不用动 UI。

### 2.8 app 壳

ProviderScope 组合根 + go_router 装配 + 平台初始化序列;平台目录留仓库根。

**合计:11+2+5+8+5+35+15 = 81 包 + app。**

## 3. 能力覆盖表(v1/TV/lx 每个能力 → v2 包,证明无遗漏)

| v1/TV/lx 能力 | v2 包 |
|---|---|
| 33 站直播适配 | sources/ 34+1 包 |
| B 站视频(ugc/pgg/评论/历史/热词) | source_bilibili_vod + vod_repository |
| 音乐(搜索/歌单/歌词/队列/音源) | source_music_builtin + music_repository + playlist + lyric |
| 聚合搜索 | search |
| 收藏 / 历史 | favorites / history |
| 多画面 / 小窗 / 全屏 | media_core_multiview / pip / fullscreen(经 pure_live_media 接线) |
| 播放器控制层 / 手势 | player_ui |
| 弹幕(设置/屏蔽/撤回/表情) | danmaku + emote |
| 背景壁纸(视频/纯色/图片/随机 API) | background |
| 主题 / 动态取色 / 壁纸 | theme + design |
| 字体下载管理 | fonts |
| IPTV(m3u/EPG/频道管理) | files(解析)+ iptv_repository + pure_live_iptv |
| 录制(FFmpeg 接线/分段) | media(ingest)+ recorder_repository + pure_live_recorder |
| 投屏 DLNA / LAN 远控 | cast / remote |
| 备份 / 多设备同步 / WebDAV | backup / sync / backup_ui |
| 账号(多平台登录态/扫码) | auth + sources 的 auth/ + account |
| 版本更新 / 发布元数据 | release |
| 多语言 / 字体缩放 | l10n + adaptive |
| TV 遥控 / 桌面窗口托盘 | platform + adaptive |
| 深链接 / 分享接入 | platform(app_links / share_handler) |
| 用户插件源 / 用户主题 | plugin_host / theme |
| 崩溃收集 / 云同步 | firebase |

## 4. 依赖规则(护栏脚本 `tool/check_architecture.dart` 按此校验)

- **分层单向**:L0 foundation 无内部依赖(utils/logging 是人人可用的叶子);integrations→L0;L1 ecosystem→L0;L2 services→L0+plugin_api;L3 ui→design/ui_kit 内部单向(ui_kit→design)+L0+theme;L5 sources→L0+plugin_api,**同层禁互依**;L4 features:repository→L0+plugin_api+services,UI 包→**本域 repository**+services+ui+ecosystem,**同层禁互依**;app→全部。
- 每包单一 barrel;业务禁 import wind(仅 ui_kit);业务禁直接 import 厂商 SDK(仅 integrations)。
- **显式例外清单**:danmaku→media(时钟)、background→media(视频背景)、sync→firebase、backup→auth、player_ui→media。

## 5. 工程化保障(同 v0.3/0.4 并强化)

ADR(`docs/v2/adr/`)、`tool/scaffold_package.ps1` 脚手架(81 包零漂移)、每包 README+每包 CI、契约测试(plugin_api contract_test,内置源与 JS 源同断言)、fixtures 快照(每 source 包)、melos lockstep、生成物折中(drift/hive 入库,riverpod/freezed CI 生成)、DI 仅 app 可 override。

**"加功能"剧本**:
- 加直播平台:scaffold source 模板 → 实现 LiveCapability(协议词典:v1)→ 录 fixtures → 契约测试 → 注册。不碰任何其他包。
- 加跨域能力:services 加一包 → feature UI 消费。
- 加内容形态:plugin_api 加 capability(契约 minor)→ sources 实现 → repository → feature UI → app 挂路由。

## 6. 路线图(waves)

| 波 | 内容 | 完成标志 |
|---|---|---|
| W0 ✅ | pubspec 现代化 + 本文档 | — |
| W1 | melos 化 + **81 包骨架**(脚手架)+ 护栏脚本 + plugin_api 契约 v0 | melos analyze 绿;护栏进 CI |
| W2 | foundation 11 包实做 | 单测绿 |
| W3 | integrations(firebase/media)+ ecosystem(theme/background/danmaku)+ ui 5 包首批 + app 壳 | 全平台启动;三类背景可切;用户主题可导入 |
| W4 | plugin_host 沙箱 + JS demo 插件 | 插件全流程 |
| W5 | source_bilibili_live 契约测试 + 真机播放 | 第一源跑通 |
| W6 | 其余 34 源 + live_repository + pure_live_live | 直播域可用 |
| W7 | source_bilibili_vod + vod_repository + pure_live_vod | B 站视频可播 |
| W8 | music_builtin + music_repository + playlist/lyric + pure_live_music | 音乐可播 |
| W9 | iptv / recorder / search / history / favorites / remote / cast / fonts / emote / settings / account / backup_ui / home / release / 迁移器 | 功能齐 |
| W10 | 生态打磨(JS SDK 文档/示例插件/评估 lx 源兼容);v1 lib 清零 | v2 首版发布 |

## 7. 决策状态

已定:firebase 保留(pure_live_firebase);背景系统独立包(视频/纯色/图片/渐变);33 站一站一包、B 站拆 live/vod;repository/UI 一步到位分包;插件仅 JS;app 壳留仓库根;melos lockstep;生成物折中。

待确认(2):① theme 文件格式(zip:manifest+令牌+资源引用);② v1 数据迁移器(W9 一次性 hive→新存储)。

## 附录 A:v2 pubspec 差异(同 v0.1 §5)
## 附录 B:wind 快速上手(同 v0.1 附录 B)
