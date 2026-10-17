# PureLive v2 架构文档

- **定位:** 当前 workspace(`D:\flutter\pure_live`,分支 `v2`)的权威架构文档。站内逐站进度见
  `docs/site-porting-progress.md`,app 实施波次见 `docs/pure-live-app-design.md`,uikit 续作见
  `docs/uikit-adapter-roadmap.md`。本文回答三个问题:系统是什么、每个功能域由哪个包承接、
  现在处于什么状态。
- **功能基线:** 功能清单以原应用 `E:\study\pure_live`(v4 workspace,2026-10-15 全量审查,
  app 层 316 个 dart 文件、13 个 packages)为准——那是功能完整形态;v2 是对它的重建,不是 demo。
- **现状快照:** 2026-10-15。

---

## 1. 系统总览

PureLive 是一个跨平台直播聚合应用:观看(多平台直播间、弹幕、多画面)、录制(手动/自动、
断点恢复)、IPTV、用户数据(关注/历史/标签/屏蔽)与完整的多平台壳(桌面多窗口/托盘/小窗、
移动、TV)。支持平台矩阵:Windows、macOS、Linux、Android、iOS、Android TV。

v2 的五条架构决策(不可回退,均有 ADR 或用户定案背书):

1. **UI 单一真源:** 业务页只依赖 `live_uikit` 的 token 与 `Live*` 组件;九种设计语言
   (material/cupertino/fluent/macos/neumorphic/glass/wind/forui + 共享兜底)经
   `LanguageRegistry` 运行时切换,业务代码零改动。任何业务文件 import 具体风格库会被
   `tool/check_architecture.ps1` 拦截。
2. **包按能力切分,app 只做装配:** 直播取数、播放编排、互动管线、用户数据、路径决策各是
   独立纯 Dart 包;`apps/pure_live` 是组合根,只写策略与接线,不复写包内机制。
3. **存储 = Hive CE**(ADR,推翻过 drift/SQLite 方案,勿再翻案):`live_storage` 提供
   bootstrap/BoxManager,领域数据各归各的包级 store seam(live_library/live_iptv/preferences)。
4. **错误过边界走类型:** 站点层 `Either<LiveSiteError, T>`;网络层 `TransportFailure`;
   平台层 sealed `PlatformException`(path_provider)。页面永不裸 catch。
5. **平台区分与路径决策分离:** `live_platform` 只产出平台事实(OS/形态/发行类型,含
   distribution.json 声明链);`live_platform_path_provider` 消费事实决定目录,便携版
   永不写 AppData。

## 2. 包图谱(当前 workspace 实况)

```text
                          apps/pure_live(组合根:路由/形态壳/设置/装配)
                                      │ 只依赖 ↓,业务页不依赖任何风格库
  ┌──────────────┬───────────────┬────┴────────┬──────────────┬─────────────┐
  │ 取数与互动     │ 播放与录制      │ 用户数据      │ 平台与基础设施 │ UI           │
  ├──────────────┼───────────────┼─────────────┼──────────────┼─────────────┤
  │ live_sites    │ live_playback  │ live_library │ live_platform │ live_uikit   │
  │ live_websocket│ live_record_core│ live_preferences│ live_platform_ │ └ 9 个风格适配器│
  │ live_interaction│ (→ media_core)│ live_storage │   path_provider│ live_uikit_  │
  │ live_pagination│               │ live_log     │ live_net      │   background │
  └──────────────┴───────────────┴─────────────┴──────────────┴─────────────┘
```

| 包 | 职责(公开 API 证据) | 对应原应用 |
|---|---|---|
| `live_sites` | 站点契约 + capability 接口 + 逐站实现;`Either<LiveSiteError,T>`;13/28+ 站完成(台账驱动) | live_core/src/sites + live_danmaku/src/sites |
| `live_websocket` | 纯 Dart WS 传输:条件导入工厂、心跳/抖动/超时关连接 | live_danmaku 内传输部分 |
| `live_interaction` | `InteractionSession` 合并多 `InteractionSource`、`MessageGate` 去重重连、`MessageFilter` 链、`AudienceTracker` | live_danmaku 的管线/过滤部分 |
| `live_playback` | `PlaybackService` 意图 API、`PlaybackSession`(租约续期、失败阶梯 同线→下线→下清晰度→刷新)、`PlaybackSessionCoordinator` 多窗音频仲裁;PlayerHandle 来自 workspace 外的 media_core(路径 `C:\Users\XA-158\projects\flutter\media_core`) | live_player + live_media |
| `live_record_core` | `RecordOrchestrator`(任务四轴状态)、capture/probe/files/guard/notices 五 seam、`restore()` 崩溃恢复、`RecordNaming` | live_record |
| `live_library` | `FollowRepository`/`HistoryRepository`/`LibraryRoom`(快照与用户元数据分离),LibraryStore seam | live_store rooms/tags 部分 |
| `live_preferences` | `PreferencesService`(appearance/desktop 域,change stream 响应式) | live_store settings 部分 |
| `live_storage` | Hive CE `StorageBootstrap`/`StorageBoxManager`、secrets 密封(DPAPI/Keystore) | live_store 存储引擎 |
| `live_iptv` | `parsePlaylist`(M3U/TXT 容错)、`IptvLibrary`(URL 对账)、`LibraryIptvChannelSource`(走普通播放栈) | live_iptv |
| `live_platform` | 平台区分:OS/形态(用户可声明)/发行类型(distribution.json 声明链 + FFI 包身份 + 标记/形状) | app/platforms.dart + data_root 的探测半边 |
| `live_platform_path_provider` | StorageArea 目录解析(写探针)、`PathPrivacy`、`PathInsights`、`StorageConflicts`、`AtomicFileWriter`、`FileAccessService` 契约 | app/data_root + downloads 的路径半边 |
| `live_net` | `LiveHttp`/`ClientProfile`/`TransportFailure`、`MediaProbe` 验流 | live_net(同名前身) |
| `live_shell` / `live_shell_desktop` | 窗口角色/关窗语义/托盘/单实例(`ChromeStage`/`QuitLedger`/`WindowRole`)与其插件实现 | app/desktop 部分 |
| `live_log` | 日志内核 | app_log |
| `live_pagination` | 分页内核 | live_core 分页部分 |
| `live_uikit`(+9 适配器+background) | token 管线、10 控件契约、共享渲染器、LiveEnvironment(TV/桌面/触摸几何) | live_ui |

原应用两个包在 v2 **尚无对应**:live_cast(DLNA 投屏)、live_vod(TV 点播+音乐)——见 §7 差距表。

## 3. 应用架构(apps/pure_live)

目录架构的**权威设计**在 `docs/app-directory-architecture.md`(已与 riverpod-state、
design_guide、pure_live_architecture 三份项目文档对齐):feature 内
presentation/application/data 三层、`app/` 装配层(bootstrap/router/shell/theme/engine/
windows)、`app_providers.dart` 唯一全局 provider 文件、AppShell 只换 chrome、能力=标记
接口+`is` 探测。本节只留骨架与不变量:

```text
lib/
├── main.dart               # 进程入口:LaunchArgs → boot → runApp ✅
├── l10n/                   # slang 翻译源(中英双语,3.x 基线)⬜
├── core/                   # errors ✅ formatters ✅ icons/ extensions/ widgets/ ⬜
├── app/                    # app.dart ✅ bootstrap/ engine/ router/ shell/ theme/ windows/ ⬜ 接线中
│                           # app_providers.dart adapters.dart delegates.dart diagnostics.dart
└── features/               # 域内 presentation/application/data(小域可平铺)
                            # home/follow/history/settings(索引+外观)✅;其余随波次
```

- **导航:** go_router 18 typed routes(`@TypedStatefulShellRoute`,branch=首页/关注/历史;
  其余页面壳外全页)。返回键语义已定案:返回=返回上级,PiP 仅按钮开。
- **形态:** AppShell 只换 chrome(mobile 底栏/desktop rail/tv 顶部焦点行),页面三形态同一
  实例;TV 由构建期 `--dart-define=PURE_LIVE_TV=true` 声明(永不从 isAndroid 猜),与
  `live_platform` FormFactor 同源;**TV 恒 Material**(其他语言焦点模型不符合遥控器预期),
  TV 的 `focus/`+`input/` 基建属于 live_uikit(设计指南标注待补)。
- **状态:** Riverpod 3 生成式 Provider;服务图长生命周期由组合根持有,Provider 只编排不
  持有协议逻辑;主题/偏好变化只重建派生 Provider,绝不重建播放会话或弹幕连接。

## 4. 功能域对照(原应用 → v2 承接与状态)

状态:✅ 已落地 · 🟡 包/内核就绪、待装配 · ⬜ 未开工 · ➖ 未规划(需决策)。

### 4.1 直播观看(核心)

| 功能(原应用证据) | v2 承接 | 状态 |
|---|---|---|
| 33+ 平台站点适配(BilibiliSite/DouyuSite/…/KickSite;capability 接口协商;Either 错误) | live_sites,台账 `site-porting-progress.md` 逐站对齐 | 🟡 13 站完成,余量按台账 |
| 弹幕协议连接(心跳/重连护栏/礼物定价) | live_sites `LiveDanmakuProvider` + live_websocket 传输 | 🟡 随站点移植 |
| 弹幕管线(多源合并/去重门/过滤链/观众数) | live_interaction `InteractionSession` | 🟡 待房间页装配 |
| 播放解析(清晰度/线路/租约/恢复阶梯) | live_playback `PlaybackService`/`PlaybackSession` | 🟡 待房间页装配 |
| 播放器引擎(mpv fork/回环中继/HLS cookies/FLV 拼接) | media_core(workspace 外)+ live_playback PlayerHandle | 🟡 引擎在外部仓,facade 就绪 |
| 房间页(四态布局/清晰度线路选择器/竖屏模式/手势/锁屏/时钟电量/换台滑动/睡眠定时) | features/room/ | ⬜ |
| 弹幕显示(悬浮+列表四 Tab/SC 倒计时/礼物合并/彩色昵称 WCAG/帧率与同屏上限/竖屏 1/4 模式) | live_interaction + features/room 弹幕区 | ⬜ |
| 弹幕屏蔽(关键词/用户//正则/相似度/重复折叠/表情-only,房间内 manager + 整页) | live_interaction `MessageFilter` + 屏蔽词存储 | ⬜(存储域待落 live_storage 家族) |
| 多画面(桌面 9 格/手机 4 格/1+3 focus;单声源仲裁;离屏格转 audioOnly;小格低清晰度;选房器) | features/multiview + mosaic_grid + Coordinator | ⬜(票据复用修法已定案) |
| 小窗/画中画(Android 系统 PiP、应用内 FloatingRoom、桌面 MiniKind 三种、置顶拖动记忆位) | media_core 呈现机制 + live_shell WindowRole | ⬜ |
| 本地互动(本地弹幕/本地礼物金币/成长签到/特效,34 设置键) | ➖ 决策点:是否随 v2 保留(纯客户端玩法) | ➖ |
| DLNA 投屏(SSDP/AVTransport,仅 Android) | ➖ live_cast 无对应包 | ➖ |

### 4.2 录制

| 功能 | v2 承接 | 状态 |
|---|---|---|
| 录制内核(FFmpeg clock-v1 分片→MP4 合并、租约/重试/开播轮询、崩溃恢复 fail-closed、B 站 XML 弹幕) | live_record_core(`RecordOrchestrator`/`restore()`) | 🟡 |
| 五 seam 的 app 实现(capture=playback 解析、probe=MediaProbe、files=StorageArea、guard=电量/容量、notices=托盘/通知) | app/recording/ | ⬜ |
| 录制中心页(五过滤器+任务卡)与录制设置页(清晰度偏好/分片时长/并发/容量上限/拼音目录/录弹幕) | features/recordings/ | ⬜ |
| 自动录制(开播自动录,依赖轮询) | 同上第二波 | ⬜ |

### 4.3 IPTV

| 功能 | v2 承接 | 状态 |
|---|---|---|
| 源管理(M3U/TXT/粘贴/http 导入、URL 对账保收藏、自动同步 2-72h、自定义 UA) | live_iptv `IptvLibrary`/`parsePlaylist` | 🟡 |
| EPG(XMLTV/gz/JSON、频道映射、catchup 字段) | live_iptv(对齐原库时补) | 🟡/⬜ |
| 频道页(分组/计数/播放走普通栈/节目单) | features/iptv/ | ⬜ |

### 4.4 用户数据与同步

| 功能 | v2 承接 | 状态 |
|---|---|---|
| 关注+分组、观看历史(快照/元数据分离、LRU 多账号) | live_library | 🟡(页面占位) |
| 用户自建标签 | 待落(live_library 扩展或独立 store) | ⬜ |
| 账号:9 平台 cookie(手填/斗鱼续期)、B 站扫码+网页短信登录、多账号 LRU、SecretStore 密封 | secrets 密封已落地(live_storage);登录 UI/AccountRoster 未建 | ⬜ |
| 备份(v4 分节、全量/仅关注、恢复前预览) | preferences 分节 schema 已交付;BackupService 未建 | ⬜ |
| WebDAV 多服务器(Basic/Digest、浏览/恢复)、TV 单向推送(HTTP :port)、局域网双向同步(:39888/UDP :39889/mDNS 配对) | ➖ 无对应包,整域未开工 | ⬜ |
| 3.x 遗留迁移(Hive→新库、IPTV 旧库、重登提示) | ➖ v2 是否承接 3.x 迁移待决策(原方案绑 drift) | ➖ |

### 4.5 发现与入口

| 功能 | v2 承接 | 状态 |
|---|---|---|
| 首页菜单(关注/热门/分区/录制中心可自选)、每平台推荐流 tab、全部分区+关注分区、分区房间列表 | features/home/categories + live_sites Discovery/Area/Hot capabilities | ⬜(包能力随站点就绪) |
| 搜索(房间/主播双模式、平台范围+海外排除、smart/platform/audience/fans 排序、覆盖度分级含 webOnly 内嵌浏览器) | live_sites Search capabilities + features/search | ⬜ |
| 链接接管(剪贴板分享码、系统分享/打开方式、IPTV 文件导入、`LinkParser` 进房间) | live_sites `LiveLinkResolver` 已有契约;intake 装配未建 | ⬜ |
| 工具箱(粘贴链接→跳房间/取流地址复制) | 同上 | ⬜ |
| 标签页/平台展示设置(hot_areas 实为平台显隐排序) | 随发现域 | ⬜ |

### 4.6 桌面壳与系统集成

| 功能 | v2 承接 | 状态 |
|---|---|---|
| 多窗口(额外窗口独立进程、`--instance`/`--open-room`、共享存储) | live_shell `WindowRole` + live_shell_desktop + desktop_multi_window | 🟡(装配未做) |
| 托盘(录制数 tooltip/隐藏/退出)、自绘标题栏、开机自启(注册表 Run)、关闭对话框(托盘/退出+不再问+录制中必问) | live_shell `TrayHost`/`QuitLedger`/`CommandStartupRegistration`(app 里已有雏形) | 🟡 |
| 小窗(mini window) | media_core + shell | ⬜ |
| TV 判定(MethodChannel `isTelevision`/leanback) | live_platform FormFactor 声明 + `PURE_LIVE_TV` 构建期声明 | 🟡(需接线同源) |
| 发行类型(exe/MSIX/便携:distribution.json 声明链+FFI+标记;便携绝不写 AppData) | live_platform `DistributionResolver` + path_provider policy | ✅(2026-10-15,`0a92c3ad9`) |
| 网络类型探测/移动数据提醒、代理(播放器+全局双域) | live_net ClientProfile;connectivity_plus 在 app 依赖 | ⬜ |

### 4.7 内容与运维

| 功能 | v2 承接 | 状态 |
|---|---|---|
| 检查更新(GitHub version.json、镜像竞速、断点续传、Android 装包/Windows 安装器、跳过版本) | path_provider downloads 区 + `FileDownloader` 模式待移植 | ⬜ |
| 字体管理(系统+云端字体下载/应用/删除,弹幕字体独立) | ⬜ | ⬜ |
| 图片缓存(自定义 cache_manager:30 分钟/320 文件上限,统一走代理) | cached_network_image_ce 依赖已备;策略装配 ⬜ | ⬜ |
| 日志页(级别过滤/导出/脱敏) | live_log + features/settings/log | ⬜ |
| 下载管理(.part 断点续传、多源顺序尝试、默认目录 Android Download/pure_live) | path_provider downloads + downloads.dart 移植 | ⬜ |
| TV 点播与音乐(B 站 UGC/PGC、歌单/歌词/队列,即 live_vod + pure_music 方向) | ➖ 另案(pure_music 到时抄代码) | ➖ |

## 5. 关键流程(目标形态)

1. **启动装配(顺序即语义,设计指南 §1.5):** `main` → LaunchArgs → **平台事实**
   (`PlatformBootstrap.init`,发行类型在此解析)→ **日志**(先于网络,故障才有地方落)→
   **存储**(StorageBootstrap)→ **偏好** → **路径**(PathProviderBootstrap)→ **内容库**
   (library/iptv)→ **网络**(LiveHttp)→ **站点注册表**(33+ 站 + IPTV 平等接入;
   `app/engine/` 绑定 media_core 的 PlaybackEngine 与弹幕工厂)→ ProviderScope → AppShell →
   路由。无全局单例,服务图由组合根显式下传;退出逆序 shutdown,落盘在进程退出前完成。
2. **进房播放:** 路由进 RoomPage → `PlaybackSession.start()` 相位机(resolving→opening→
   playing;失败 `_classify` 后走恢复阶梯:同线重开→同画质下一条线→下一条画质→强制重解析→
   放弃;`isRetryable==false` 直接跳阶梯;租约到期=一次恢复)∥
   `site is LiveDanmakuCapability → InteractionSession`(多源合并/去重门/过滤链)。软变更
   (切主题/画质热切)只重建派生状态,会话与弹幕连接不重建。
3. **录制:** 房间页录制面板 → `RecordOrchestrator.watch(target)`;capture seam 复用播放解析,
   files seam 用 StorageArea.exports/downloads,notices 接托盘;`restore()` 在启动时收尾上次任务。
4. **下载/更新:** 一律先问目录——`PathPrivacy.isPrivate` 为真的默认目录必须提示用户改选;
   下载器移植原 `.part` 断点续传实现,落到 `StorageArea.downloads`。
5. **数据落地:** 领域数据走各自 store seam(live_library/live_iptv/preferences),业务页只见
   Repository;跨窗口可见性由 box 层保证。

## 6. 交叉关注点

- **错误:** TransportFailure/SiteError/PlatformException 在 `core/errors.dart` 统一翻译成
  slang 文案;页面不显示原始异常。
- **l10n:** slang(依赖已备,未铺);delegate 装配已在 `app/delegates.dart`。
- **诊断:** live_log 输出;distribution 冲突、resolver 解析失败(`LiveUiResolutionException`)、录制失败
  阶段必须可见。敏感值(cookie/ticket)脱敏后才能进日志。
- **测试纪律:** 纯逻辑离线测试进各包 `test/`(站点编解码/解析/定价为逐站 DoD);
  `tool/check_architecture.ps1` 是提交门禁;**提交前 `git status`,绝不混入并行 WIP**。

## 7. 差距与实施顺序

包就绪待装配(🟡)是当前主要资产;⬜ 按依赖排序:

1. **房间页波(最大单项):** features/room 全套 + live_playback/interaction 接线 —— 解锁观看主链路。
2. **发现波:** 首页/分区/搜索(依赖站点台账继续推进)。
3. **用户数据波:** 关注/历史/标签/屏蔽存储域 + 账号登录 UI。
4. **录制波:** 五 seam 实现 + 录制中心/设置页。
5. **IPTV 波、多画面波。**
6. **壳完善波:** 多窗口/托盘/小窗/链接接管/工具箱/更新下载。
7. **TV 波:** live_uikit `focus/`+`input/` 基建贯通列表/控制栏/软键盘(设计指南第五部分
   明确待补);审查 `F:\pure_live_TV\pure_live_TV` 提取成熟交互,不整包改写。

## 8. 文档勘误与取舍(防止旧文档误导)

阅读 docs 全量后确认的"文档说 X、现实已演进为 Y"清单,以现实为准并在此记录:

| 旧文档说法 | 现行裁决 | 依据 |
|---|---|---|
| storage-architecture(Proposed)推荐 Drift+SQLite | **存储引擎已定案 Hive CE**(`live_storage`),不再翻案;该文档的数据分类/所有权/错误模型/清理策略等**原则**仍然有效 | ADR + 用户多轮推翻 |
| packages-migration 的 25 包细分(regional 站点包、live_danmaku_*、live_media_*、live_store_* 五拆、live_state) | **未按此拆分**:单 live_sites + live_interaction/live_websocket/live_playback/live_storage;live_state 被推翻(状态直接用 Riverpod,用户数据进 app) | 后续用户决策 |
| packages-migration 将 live_vod_bilibili/music 列入 P7 | **音乐/点播不进 v2 核心架构**(pure_live_architecture §1 定位),pure_music 另案 | 定位文档胜出 |
| 六种设计语言含 Yaru;Wind 只作内部实现不设第七语言 | 现实 8 个适配器:material/cupertino/fluent/macos/neumorphic/glass/wind/forui(无 yaru;wind/glass/forui 已是独立语言) | 演进现状,uikit 家族文档为准 |
| 生成物不入 git(ADR 0001、packages-migration §4.1) | 现行惯例**提交**生成文件(`.gitignore` 注释与 104 个在库 .g.dart);两处旧说法待用户定夺是否回改 | 仓库现状 |
| `LiveUiControl`/Spec 契约与 design_guide §2.4 的 `LiveDesignLanguageComponents` 接口形态 | 以 live_uikit 现行契约为准(9 节目录见 `docs/architecture/live-uikit.md` 与各包 spec) | 现状 |

> 维护约定:各域动工前先回本文勾状态;站点进度只更新台账不重复记 here;旧文档与本表冲突时,以本表与现实代码为准。
