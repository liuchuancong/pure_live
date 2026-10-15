# PureLive v2 App 端架构设计(多平台 · UI 风格 · 直播/录制/存储/文件)

> 写给接手的人:这一篇是 `apps/pure_live/lib` 的建设思路。所有结论都以两样东西为依据:
> ① `apps/pure_live/pubspec.yaml` 已声明的依赖(全部清单见 §10,未列的不许新引入);
> ② `packages/` 已建成的包家族的公开 API(逐包核实过 barrel,不是想象)。
> 包负责"能力",app 负责"策略与装配"——包里不留 app 的预设值,app 不重造包里已有的机制。
>
> 现状快照:2026-10-15,分支 `v2`。app 的 lib 目前只有 7 个文件(组合根 + 组件画廊 demo),
> 这份设计就是从这 7 个文件长成完整应用的路线。

---

## 1. 总体 UI 风格架构(先行)

### 1.1 风格基线:向主流直播软件看齐的东西

参考 B 站直播 / 斗鱼 / 虎牙桌面端与 Twitch,它们共同的骨架是:

1. **播放器优先(room page 是产品中心)**:进入房间第一眼是视频,信息条、弹幕、互动都悬浮或围绕它。
2. **弹幕是一等公民**:独立右栏(桌面)或悬浮层(移动),可开关、可过滤、可平滑滚动,绝不出现在视频画面内的 DOM 式列表里。
3. **桌面三栏骨架**:顶栏(搜索/用户)+ 左 rail(关注/分类,可收起)+ 内容区;房间页把 rail 让位给"播放器 + 右侧互动栏"。
4. **移动端底部四 tab**:首页 / 分类 / 关注 / 我的;房间页全屏沉浸,控件悬浮、自动隐藏。
5. **TV 十英尺**:焦点驱动网格、大字号、遥控器 OK/返回语义,没有 rail,没有指针悬停。
6. **深色优先、强调色克制**:内容底色深,强调色只给"直播中 / 关注 / 主要按钮"。

PureLive 的对应策略:**这些是 `LiveTheme` 之上的布局策略,不是视觉实现**。颜色、圆角、密度、
动效一律来自 token;布局来自 `LiveEnvironment`(`LiveLayoutBuilder` 发布 mobile/desktop/TV
三档 `Geometry`,TV 数值——页边距 48、图标 28、96 高导航——core 已内置并测试)。app 只写
"哪个形态摆哪些格子",不写任何像素色值。

### 1.2 三个形态,一套页面

```text
                    ┌─ LiveEnvironmentScope(formFactor: 声明 + 实时宽度)
                    │
     desktop(宽>720,非TV)      touch(宽≤720)           tv(声明即 TV,宽度无关)
  ┌────────────────────────┐  ┌──────────────┐  ┌────────────────────────────┐
  │ TopBar 搜索/头像/设置   │  │  页面内容     │  │  焦点网格 / 96高导航        │
  ├──┬─────────────────────┤  │              │  │  无 rail、无悬停语义         │
  │Rail│ 内容区            │  │              │  │  控件高度来自 seed          │
  │可收│ (推荐流/分类/房间) │  │              │  │  (composition root 抬高)   │
  └──┴─────────────────────┘  └──────────────┘  └────────────────────────────┘
```

- 形态判定:TV 由启动参数/配置**声明**(`LiveLayoutBuilder` 里 TV 压倒一切宽度);desktop/touch
  由实时宽度按 core 断点(719/720)切换。**断点权威在 live_uikit**;`flutter_adaptive_layout`
  只允许做 widget 级辅助(如对话框宽度),若发现两套断点语义打架,评估后移除它。
- 房间页在 desktop 是 `播放器 + 右侧互动栏`;在 touch 是全屏播放器 + 悬浮互动;在 TV 是播放器 +
  焦点可控的底部操作条。**同三个 `RoomPage` 分支,共用全部状态**,切换形态不丢播放。

### 1.3 导航与信息架构(go_router 18,typed routes)

| 路由 | 内容 | 形态差异 |
|---|---|---|
| `/` | 首页:推荐流(discovery/hot)+ 顶栏搜索入口 | desktop 左 rail 常驻;touch 底部 tab;TV 焦点网格 |
| `/categories/:site/:area` | 分类/分区列表 | 同上 |
| `/search` | 全站搜索(sites search 能力) | 桌面可作顶栏下拉 |
| `/room/:site/:roomId` | **房间页**(播放器 + 弹幕 + 互动 + 清晰度/线路) | §1.2 三分支 |
| `/follow` | 关注(live_library FollowRepository + 分组) | desktop 在 rail 也可达 |
| `/history` | 历史(HistoryRepository,容量上限由包管理) | 同上 |
| `/iptv` | IPTV 频道(live_iptv,经 LibraryIptvChannelSource 走普通播放栈) | — |
| `/recordings` | 录像库(§4 录制产物列表 + 播放) | — |
| `/settings` | 设置(现 settings_page.dart 迁入;含外观/存储/关于/更新) | — |
| `/settings/appearance` | 外观(设计语言/明暗/强调色/密度/透明度/字体) | 已有雏形 |

规则:路由表集中在 `app/router.dart`,用 `go_router_builder` 生成 typed route;**业务页之间不
`Navigator.push` 裸字符串**。返回键语义沿用已定案:返回=返回上级,PiP 只能按钮开,floatPlay
时返回后走应用内小窗。

### 1.4 组件规约(从 master 单体版的反面清单学来的)

- **只用 `Live*` 组件与 token**,业务页 import `live_uikit` 一个 UI 包;任何页面 import
  `fluent_ui/macos_ui/...` 都是架构违规(守卫已拦)。
- **加载态统一**:列表骨架用 `skeletonizer`(网格骨架)或 `shimmer`(行骨架)二选一按场景,
  不再出现 master 版三家 loading 并存;空/错态用 core 的 `LiveEmpty`/`LiveError`/`LiveLoading`。
- **弹窗/Toast 统一**:只有 `showLiveDialog` / `styledToast`(函数式,继承 ambient 主题),
  禁止三轨弹窗回潮。
- **图片统一**:`any_image_view` 包裹 `cached_network_image_ce`(国内源场景)与 `flutter_svg`,
  页面不直接摸 ImageProvider。
- **图标 seam**:core 契约没有 icon 控件;app 建一个 `UiIcon` 语义映射(语义名 → 当前设计语言
  的图标集),页面只给语义名。v1 的 remixicon 74 文件不迁,按需换各语言的图标资产。
- **背景**:场景背景走 `live_uikit_background`(solid/gradient/image/video 管线),表面内装饰
  走 core `LiveBackground`;两者命名分工按 ADR 0005 的现状执行。
- **刷新**:`custom_refresh_indicator` 包一层统一手势刷新;桌面列表不出现拉动刷新。

### 1.5 主题链路(已建成,只差页面消费)

`AppearancePreferences(live_preferences) ↔ appearance_mapping.dart ↔ UiConfig →
LiveConfigProvider → LiveTheme`,主题变更走 preferences 的 change stream 全树重建——这条链
main.dart 已跑通。`flex_color_scheme` 是 master 迁移残留,**禁用并在首次清理波次移除**(token
是唯一视觉真源,Material scheme 帮助类会制造第二真源)。桌面窗口背景/acrylic 属
`live_shell_desktop` 与系统,不进 token。

---

## 2. `lib/` 目标结构

```text
apps/pure_live/lib/
├── main.dart                  # 组合根:boot services → LiveConfigProvider → MaterialApp(已存在,只增不改向)
├── app/
│   ├── router.dart            # go_router typed 路由表 + 形态 shell 选择
│   ├── providers.dart         # Riverpod 全局 provider(AppServices/站点注册表/播放服务…)
│   └── delegates.dart         # l10n + 各设计语言 localizations 装配(从 main.dart 抽出)
├── core/
│   ├── errors.dart            # TransportFailure/Failure → 用户可读文案(slang key)
│   ├── formatters.dart        # 人气/时长/文件大小格式化
│   └── icons.dart             # UiIcon 语义图标 seam(§1.4)
├── features/                  # 每个功能:page + widgets + controller(Riverpod),不建 category 垃圾桶
│   ├── home/                  # 推荐/关注流/discovery
│   ├── categories/            # 分区
│   ├── search/
│   ├── room/                  # 房间页(§3.3):player区/互动区/控制条三分支
│   ├── follow/                # 关注+分组(live_library)
│   ├── history/
│   ├── iptv/                  # 频道列表/播放/源管理(live_iptv)
│   ├── recordings/            # 录像库(§4)
│   ├── settings/              # 现 settings_page 迁入拆分
│   └── multiview/             # 多画面(mosaic_grid)
├── player/                    # PlaybackService 消费层:窗口/画中画/浮窗意图,悬浮控件(§3.2)
├── interaction/               # InteractionSession 消费层:弹幕渲染列表/过滤/观众数(§3.4)
├── recording/                 # RecordOrchestrator 的 services 实现 + 录制管理页(§4)
├── storage/                   # StorageBootstrap 扩展装配、box 家族→功能映射(§5)
├── files/                     # 目录矩阵、导入导出、打开/分享(§6)
├── platform/                  # desktop_boot/tray/shell 装配(desktop_boot.dart 迁入)(§7)
└── l10n/                      # slang 生成产物 + 翻译源
```

依赖方向(守卫精神):`features/* → player/interaction/recording → 包(live_*)`;
`features/*` 之间**互不 import**,跨页跳转走路由,跨页数据走 provider/repo。
现有 7 个文件的去向:`settings_page.dart`→`features/settings/`(HomePage 画廊 demo 删除,
其语言切换职责并入设置);`appearance_mapping.dart`→`app/`;`desktop_boot.dart`、
`desktop_tray_icons.dart`→`platform/`;`background_demo_page.dart` 完成视觉验收后删除;
`services.dart`→`storage/` + `app/providers.dart`。

**Wave 1 已落地(commit `ee365fd99`,2026-10-15)**:目录重组完成;`app/` 下新增
`router.dart`(typed routes,`router.g.dart` 按仓库惯例提交)、`adaptive_shell.dart`
(桌面/TV 左 rail、触摸底部 NavigationBar)、`adapters.dart`(语言注册表常量)、
`providers.dart`、`delegates.dart`;`features/settings/` 拆成索引页 + `appearance_page.dart`;
首页/关注/历史为 `LiveEmpty` 占位页;`home` 画廊 demo 已删;`flex_color_scheme` 已移出
pubspec。`background_demo_page.dart` 暂留 `lib/` 根部,经 `/dev/background` 路由可达
(注释注明 ADR 0005 定案后删除);TV 形态经构建期 `--dart-define=PURE_LIVE_TV=true`
声明,`appIsTv` 常量传入 `LiveLayoutBuilder`。

---

## 3. 直播域(核心链路)

### 3.1 取数:live_sites 是唯一站点出口

- 页面永远面对 core 契约:`LiveDiscoveryProvider`(推荐/分类/搜索/热门)、`LiveAnchorProvider`、
  `LiveAreaProvider`、`LiveDanmakuProvider`、link resolver;平台实现(kick/douyin/huya/…)私有。
- 站点注册表在组合根装配(`app/providers.dart`),`AppServices.boot` 注释里"platform adapters
  尚未接入"的欠账在这一步清掉。
- HTTP 一律经 `live_net`(`LiveHttp`/`ClientProfile`);页面不 import dio。
- 分页用 `live_pagination`(尚未在 app 依赖里,随首页推荐流波次加入)。

### 3.2 播放:live_playback 的意图 API

- 房间页只调 `PlaybackService` 的意图(进房/换线/换清晰度/刷新/退出),恢复阶梯(同线→下线→
  下清晰度→刷新→放弃)包里已实现,app 不复写。
- 播放器画面是 `PlayerHandle`(media_core 内核)的表面;全屏/系统 PiP/应用内浮窗属 media_core
  能力包,app 的 `player/` 只发意图并摆 UI。多窗口 audible 仲裁由 `PlaybackSessionCoordinator`
  管:desktop 多窗(`desktop_multi_window`)时"哪个窗口出声"由此决定,app 把窗口角色喂给它。
- 多画面:`mosaic_grid` + 每格一个 PlaybackSession。**沿用已定位的根因修法**:格子复用带票据的
  room detail(MultiviewStreamSource.detail),不允许每格再发第二次详情请求。

### 3.3 房间页装配(产品中心)

```text
desktop:                         touch:
┌───────────────┬─────────┐      ┌────────────────────┐
│  播放器        │ 互动栏   │      │   全屏播放器         │
│  (PlayerHandle)│ 弹幕列表 │      │  悬浮:信息/弹幕开关  │
│  控制条:       │ 关注/礼  │      │  底部:输入/清晰度    │
│  清晰度/线路/  │ 物/人气  │      └────────────────────┘
│  音量/弹幕开关/ │ (可收起) │
│  截图/录制/PiP │         │
└───────────────┴─────────┘
```

- 清晰度/线路选择器用 `LiveSelect`(fluent 已原生,其余语言共享兜底)。
- 弹幕开关/过滤入口、截图(§6)、"开始录制"(§4)都是房间页控制条的一等按钮。
- 登录类能力(QR 扫码 `mobile_scanner`/`pretty_qr_code`、web 登录 `webview_flutter`)属于
  站点账号域,先做"游客可看",登录波次单独排。

### 3.4 弹幕:live_interaction(live_websocket 传输)

- app 依赖里**还没有** `live_interaction` 与 `live_websocket`——房间页波次加入。
- 装配:`site 的 LiveDanmakuProvider(协议)` → `InteractionSource` → `InteractionSession`
  (去重/重连门/过滤链/观众数,包已实现)。app 的 `interaction/` 只做两件事:
  ①把用户过滤设置翻译成 `MessageFilter`;②把 `LiveMessage` 渲染成弹幕列表/悬浮弹幕。
- 渲染规约:哪个窗口有声音哪个窗口显示弹幕(已定案语义);弹幕列表用普通 ListView + 自动吸底 +
  手动上滚即暂停吸底;悬浮弹幕开关进设置。

---

## 4. 录制域(live_record_core,app 尚未依赖)

- 加入依赖后,`recording/` 负责**实现 `RecordServices` 五个 seam**(capture/probe/files/guard/
  notices):capture 用 live_sites 的播放地址解析 + live_net MediaProbe 验流;files 用 §6 目录
  矩阵;notices 接桌面托盘(live_shell TrayHost)与移动通知。
- 任务模型用包的四轴状态 + `restore()` 崩溃恢复:`RecordNaming` 统一文件名
  (`{平台}/{主播}/{日期 时间}/{标题}.ts` 之类,**具体模板是 app 策略,写在 app**)。
- 手动录制:房间页控制条"录制"按钮 → `orchestrator.watch(RecordTarget)`;自动录制(关注主播
  开播即录)属第二波,依赖 follow 仓库 + 轮询。
- 电池策略:Android 录制时 `battery_plus` 读状态,仅提示不阻断;iOS 沙盒下录到 app 文档目录并
  提示导出。TV 不提供录制入口。

---

## 5. 存储域(live_storage 五家族映射)

定案已锁:Hive CE + hive_box_manager,别再荐 sqlite/drift。app 侧映射:

| 功能 | 落点 |
|---|---|
| 偏好/外观/账号票据 | `live_preferences`(preferences box,已接线) |
| 关注/历史 | `live_library` 的 LibraryStore seam(包内已是 Hivez box,第二窗口可见) |
| IPTV 频道/播放列表 | `live_iptv` 的 IptvStore seam |
| 录制台账 | `live_record_core` 的 RecordJsonStore |
| 弹幕过滤词/界面杂项 | storage 五家族中的 keyed/json 家族,`storage/` 里按功能开 box |

规则:`AppServices.boot` 已是唯一 bootstrap;新 box 一律经 `StorageBoxManager`,Repository
按 key 队列保留;**业务页不碰 box,只碰 Repository**。

---

## 6. 文件处理域

`live_platform` 是文件能力的契约层(`StorageManager`/`StorageArea`/`FileAccessService`/
`ShutdownCoordinator`),`files/` 是装配:

- **目录矩阵**(`PlatformBootstrap.init` 一次,处处读事实,不自己拼路径):

| 用途 | 桌面 | Android | iOS |
|---|---|---|---|
| 录像输出 | 用户可选(默认 视频/ PureLive) | 公共视频目录(需权限) | 文档目录+提示导出 |
| 截图 | 图片目录 | 相册(media store) | 相册 |
| IPTV 导入暂存 | 下载/临时 | 缓存 | 缓存 |
| 日志 | 应用支持目录(live_log 滚动) | 同 | 同 |

- **选择文件**:`FileAccessService` 统一封 `file_picker`(移动/选目录)与 `file_selector`
  (桌面),页面只见 seam。
- **导入/导出**:IPTV 的 m3u/txt 解析在 live_iptv(已容错);配置备份/恢复用 `archive` 打
  zip(偏好+关注+IPTV+过滤词),入口在设置页。
- **打开/外送**:`open_file`(打开录像/日志)、`share_plus`(分享房间/文件)、
  `url_launcher`(外链)、`android_intent_plus`(Android 特有跳转)——全部经 `files/` 的
  三个函数式入口,页面不直接 import 插件。
- 截图:播放器帧回调落盘(路径走目录矩阵),成功后 styledToast + 可选分享。

---

## 7. 平台差异矩阵(装配差异,不是页面差异)

| 关注点 | Windows/Linux | macOS | Android | iOS | Android TV |
|---|---|---|---|---|---|
| 窗口/关窗语义/托盘/多实例 | `live_shell`+`live_shell_desktop`(已建:`ChromeStage`/`QuitLedger`/`WindowRole`,保留系统标题栏) | 同 | — | — | — |
| 多窗口 | desktop_multi_window,角色=主窗/弹出播放窗,audible 由 Coordinator 仲裁 | 同 | — | — | — |
| 形态 | desktop | desktop | touch | touch | tv(声明)+ D-pad 验收 |
| 单实例/重启 | DesktopBootstrap(已建)+ restart_app | 同 | restart_app | — | — |
| 动态图标/渠道 | dynamic_app_icon_flutter_plus(渠道包) | — | 同 | 同 | 同 |
| 网络感知 | connectivity_plus(断网横幅) | 同 | 同 | 同 | 同 |
| 电量 | — | — | battery_plus(录制提示) | 同 | — |

原则:**页面代码读 `LiveEnvironment` 与 provider,不 `Platform.isXXX`**;平台分支只允许出现在
`platform/`、`files/`、`recording/` 的装配层,且必须走 live_platform/live_shell 的 seam
(`PlatformEnvironment` 是唯一事实源)。

---

## 8. 横切规约

- **状态**:Riverpod 3 + `riverpod_annotation` codegen;每个 feature 一个 controller 文件;
  AsyncValue 直接映到 `LiveLoading/LiveError`。
- **错误**:`Either`/`TransportFailure` 在 `core/errors.dart` 统一翻译成 slang 文案;页面
  永不显示原始异常。
- **l10n**:slang;`app/delegates.dart` 统一挂 core + 各设计语言 + slang delegates(main.dart
  已有雏形)。中英双份,页面禁止硬编码英文。
- **日志**:`live_log` 皆经它;敏感字段(票据/cookie)不打明文。
- **更新**:package_info_plus + pub_semver 比对(版本源后续定),设置页"关于"。
- **通道**:pigeon 生成类型化 channel(`platform/` 内)。
- **密钥**:envied,不进仓库。
- **提交流程**:见 `docs/uikit-adapter-roadmap.md` 红线——提交前 `git status`,绝不混入并行 WIP。

---

## 9. 实施波次(每波可独立验收)

1. **骨架波**:lib 目录重组(§2)、go_router 路由表、底部 tab + 左 rail 的自适应壳、设置页迁入、
   删画廊 demo、移除 flex_color_scheme。
2. **直播 MVP 波**:sites 注册表接线 → 首页推荐/分类/搜索 → 房间页播放(PlaybackService)+
   清晰度/线路 + live_pagination。
3. **弹幕波**:live_interaction/live_websocket 依赖加入,房间页弹幕栏/悬浮弹幕/过滤设置。
4. **用户数据波**:关注/历史(live_library)、登录(QR/webview)、IPTV 页。
5. **录制波**:live_record_core 接线、录像库页、托盘/通知、崩溃恢复验收。
6. **多画面/打磨波**:mosaic_grid 多画面(复用票据)、背景管线、TV D-pad 全链验收、备份导出。

每波 DoD:format/analyze/test 全绿 + `check_architecture.ps1` + 真机/桌面手测;**提交前看
git status**。

## 10. 依据:app pubspec 依赖 → 用途对照(2026-10-15 实录)

UI:`live_uikit` + 8 适配器、`live_uikit_background`、`flex_color_scheme(残留,移除)`、
`animations`、`shimmer`/`skeletonizer`、`custom_refresh_indicator`、`any_image_view`/
`cached_network_image_ce`/`cached_network_image`/`flutter_svg`、`mosaic_grid`。
数据/域:`live_sites`、`live_playback`、`live_interaction`、`live_iptv`、`live_library`、
`live_net`、`live_storage`、`live_preferences`、`live_log`、`live_platform`、`live_shell`/
`live_shell_desktop`;**未接(按波次加入)**:`live_websocket`、`live_record_core`、
`live_pagination`。基础设施:`flutter_riverpod`/`riverpod_annotation`、`go_router`、`freezed`/
`json_annotation`(+dev codegen)、`slang`、`envied`、`pigeon`、`path`/`path_provider`、
`archive`、`file_picker`/`file_selector`、`open_file`/`share_plus`/`url_launcher`/
`android_intent_plus`、`connectivity_plus`/`network_info_plus`、`battery_plus`、
`device_info_plus`/`package_info_plus`/`pub_semver`、`window_manager`/`tray_manager`/
`screen_retriever`/`desktop_multi_window`/`restart_app`、`mobile_scanner`/`pretty_qr_code`/
`webview_flutter`、`markdown`、`flutter_keyboard_visibility`、`dynamic_app_icon_flutter_plus`、
`collection`、`flutter_adaptive_layout(评估,见 §1.2)`。
