# PureLive App 目录架构(apps/pure_live/lib)

> 本文是 app 目录的**权威设计**:每一层放什么、不放什么,26 个功能域的长相,三条适配轴
> (9 种设计语言 / 桌面·触摸·TV 三形态 / 多语言)各自的归宿,以及现状文件到目标归宿的
> 迁移映射。动任何 app 代码前先读这里;设计变更先改这里。
>
> 依据:功能基线 `docs/pure-live-architecture.md`(原应用全量审查);包能力见 §2 包图谱。

---

## 1. 总原则

1. **目录按"变更原因"划分,不按文件类型。** 一起变的放一起:一个功能域的页面、控制器、
   组件在一个目录;跨域复用才上提。
2. **三条适配轴,三个固定归宿,不新增目录轴:**
   - **设计语言(9 种)**:归宿是 `live_uikit` 的运行时注册表(`app/adapters.dart` 注册,
     `app/theme/` 持久化桥)。页面只写 `Live*` 组件,**app 内不存在按设计语言划分的目录**,
     也不存在"fluent 版页面"。
   - **形态(desktop / touch / TV)**:归宿是 `LiveEnvironment` 的运行时分支——同一个
     widget 的 build 里按 `LiveEnvironmentScope.of(context).mode` 走三分支;分支超长才拆成
     `widgets/room_wide_pane.dart` 这类私有组件。**禁止** `ui/desktop/`、`ui/mobile/` 这类
     按形态复制的目录树(那是双倍维护)。
   - **语言(多语言)**:归宿是 `lib/l10n/`(slang)。页面零硬编码文案,只引用生成的
     `t.*` 键。翻译集中一处,按键命名空间对应功能域(如 `room.record.start`)。
3. **层次单向:** `features → services → data → packages(live_*)`;`core` 被所有层依赖且
   不依赖任何业务;`app` 是装配层,认识所有层;`features` 之间**互不 import**(跨页跳转走
   路由,跨页数据走 provider)。
4. **不为凑树建空文件。** 目录在第一份真实内容落地时创建;本文的树是"终局地图",不是
   "一次建完的清单"。

## 2. 顶层目录

```text
apps/pure_live/lib/
├── main.dart                 # 进程入口:解析 LaunchArgs → boot → runApp;多窗口同入口分角色
│
├── l10n/                     # 多语言。slang 翻译源(JSON/YAML)+ 生成产物 t.g.dart
│   ├── translations_zh.i18n.json
│   ├── translations_en.i18n.json
│   └── (生成) i18n.g.dart            # 键访问 t.room.record.start;严格校验缺键
│
├── core/                     # 与直播业务无关的跨域基础;纯 Dart 优先,可被所有层依赖
│   ├── errors.dart           # 领域异常 → 用户文案(取消返回 null)
│   ├── formatters.dart       # 人数(万/亿)/时长/字节
│   ├── icons/                # 语义图标 seam:语义名 → Material 基线图标,可按设计语言覆盖
│   │   └── app_icons.dart
│   ├── extensions/           # BuildContext/LiveTheme/枚举扩展(如 theme.colors 简写)
│   └── widgets/              # 跨域通用小胶水(空态包装、最大宽度居中、自适应栅格项)
│
├── app/                      # 应用装配(UI 侧组合根;认识所有层,不被别人 import)
│   ├── app.dart              # PureLiveApp 根(从 main.dart 拆出;StreamBuilder→LiveConfigProvider→MaterialApp.router)
│   ├── router/
│   │   ├── router.dart       # GoRouter 装配 + $appRoutes 聚合;初始路由、重定向
│   │   └── routes/           # 每域一个路由文件(如 room_routes.dart),声明 TypedGoRoute 分组
│   ├── providers/            # 全局 Riverpod provider,按域拆文件:
│   │   ├── services_provider.dart   #   appServices / 平台 / 路径
│   │   ├── playback_provider.dart   #   PlaybackService 单例
│   │   ├── sites_provider.dart      #   站点注册表
│   │   └── recording_provider.dart  #   RecordOrchestrator
│   ├── shell/                # 自适应壳:AdaptiveShell + rail/底栏/TV 变体(现 adaptive_shell.dart 迁入)
│   ├── theme/                # UiConfig ↔ 偏好持久化桥(现 appearance_mapping.dart 迁入)、字体应用、动态图标
│   ├── adapters.dart         # 9 设计语言的 LanguageRegistry 常量(已存在)
│   ├── delegates.dart        # l10n + 各设计语言 localizations 装配(已存在)
│   ├── windows/              # 桌面多窗口:LaunchArgs 解析、窗口角色(主窗/房间窗)、第二进程入口逻辑
│   └── diagnostics.dart      # 启动诊断输出:发行类型冲突、resolver 降级、boot 时序
│
├── data/                     # 数据与系统资源组合根(无 UI;对应原应用 app/services+data_root+downloads)
│   ├── app_services.dart     # AppServices 聚合:boot 全链(存储→偏好→平台→路径),对外只读字段
│   ├── platform/             # live_platform 接线:bootPlatform(claim 目录/TV 同源/FFI 身份)(现 platform/ 迁入)
│   ├── paths/                # live_platform_path_provider 接线:PathProviderRuntime + 目录规划(下载私有目录提示)
│   ├── preferences/          # live_preferences 桥:外观/桌面偏好读写封装
│   └── downloads/            # FileDownloader:.part 断点续传、多源尝试、进度/取消(自原应用移植)
│
├── services/                 # 直播领域服务消费层(跨页面共享、无页面;薄封装包内核,不复制包逻辑)
│   ├── sites/                # 站点注册表装配:buildSiteRegistry 的 v2 对应物(平台开关读设置)
│   ├── playback/             # PlaybackService 意图封装:进房/换线/换清晰度/小窗;把窗口角色喂给 Coordinator
│   ├── interaction/          # InteractionSession 装配:站点弹幕 provider→传输→过滤链;屏蔽词→MessageFilter
│   ├── recording/            # RecordOrchestrator 五 seam 的 app 实现(capture/probe/files/guard/notices)
│   ├── intake/               # 链接接管:剪贴板分享码、系统分享、"打开方式"→路由/房间/IPTV 导入
│   └── updater/              # 更新:version.json 检查、镜像竞速、安装
│
└── features/                 # 页面域。26 个域一个长相,见 §3 域内结构与 §4 清单
    ├── home/
    ├── room/
    │   ├── room_page.dart
    │   ├── controllers/      #   RoomController(房间详情/清晰度线路状态)
    │   ├── widgets/          #   播放器控制条、信息条、弹幕面板、手势层…(widgets/ 内按形态拆 pane)
    │   ├── panels/           #   房间子弹窗体系:录制/弹幕设置/换房/睡眠/音量/直链/消息…
    │   └── services/         #   仅本域的适配(如 RoomRuntime 组装)
    └── …
```

**不存在的顶层目录(刻意):** `ui/`(设计语言和形态不建目录轴,见总原则 2)、
`models/`(数据模型在包里,页面私有的进 `features/<域>/models/`)、`utils/`(可命名的
归属进 core,拒绝垃圾桶)、`pages/`(页面属于功能域)。

## 3. 功能域的固定内聚结构

每个 `features/<域>/` 长这样(按需出现,不预建空目录):

```text
features/<域>/
├── <域>_page.dart            # 路由页面:只做组装(壳选择、provider 接线),≤200 行
├── controllers/              # Riverpod Notifier/AsyncNotifier(codegen);纯逻辑可单测
├── models/                   # 页面私有视图模型(freezed);领域模型一律用包里的,不复制
├── widgets/                  # 页面私有组件;形态分支的拆分组件也在这里(xxx_wide_pane.dart)
├── panels/                   # 页内子弹窗(房间域专用形态;经本域 PanelController 管理)
└── services/                 # 仅本域使用、又不值得上提 services/ 的适配
```

规则:

- **页面文件只组装。** 布局分支、数据装配下放 widgets/controllers;一个 page 文件超 200 行
  即拆分信号。
- **域内自由,域间隔离。** 域内文件互相 import 无需节制;跨域只允许:路由跳转、引用
  services/ 与 core/、引用包。
- **设置集群例外:** settings 是一个域多个页面,允许平铺多个 `*_page.dart`
  (appearance/danmaku/fonts/log),不强拆子目录。
- **纯逻辑可单测:** controllers 不 import UI 库(Material 除外做类型),文案不入 controller。

## 4. 功能域清单(终局,来自原应用全量审查)

路由前缀:壳内 branch(`/`、`/follow`、`/history`)之外全部为壳外全页。状态:✅ 已有 · ⬜ 待建。

| 域目录 | 页面 | 路由 | 内容(原应用对应) | 状态 |
|---|---|---|---|---|
| `home` | HomePage | `/` | 菜单(关注/热门/分区/录制中心,可自选)+推荐流 | ⬜ 占位 |
| `popular` | PopularPage | `/popular` | 每平台推荐 tab | ⬜ |
| `areas` | AreasPage | `/areas` | 全部分区+关注分区 | ⬜ |
| `area_rooms` | AreaRoomsPage | `/areas/:site/:areaId` | 分区房间列表+关注分区 | ⬜ |
| `search` | SearchPage | `/search` | 房间/主播双模式、范围与排序、覆盖度分级 | ⬜ |
| `room` | RoomPage | `/room/:site/:roomId` | 房间页全套:四态布局、清晰度线路、弹幕面板(列表/SC/设置/屏蔽)、手势、录制面板、换台 | ⬜ |
| `multiview` | MultiviewPage | `/multiview` | 多画面(桌面 9 格/手机 4 格/1+3) | ⬜ |
| `follow` | FollowPage | `/follow` | 关注+分组+标签筛选 | ⬜ 占位 |
| `history` | HistoryPage | `/history` | 观看历史 | ⬜ 占位 |
| `tags` | TagsPage | `/tags` | 用户自建标签管理 | ⬜ |
| `iptv` | IptvPage | `/iptv` | 源管理/频道分组/EPG/播放 | ⬜ |
| `recorder` | RecorderPage | `/recorder` | 录制中心(五过滤器+任务卡) | ⬜ |
| `recorder` | RecordSettingsPage | `/settings/recording` | 录制设置(与中心同域) | ⬜ |
| `shield` | ShieldPage | `/settings/shield` | 弹幕屏蔽(关键词/用户/正则/相似度) | ⬜ |
| `settings` | SettingsPage | `/settings` | 设置索引(17 节目标态) | ✅ |
| `settings` | AppearancePage | `/settings/appearance` | 外观(设计语言/明暗/密度/桌面行为) | ✅ |
| `settings` | DanmakuSettingsPage | `/settings/danmaku` | 弹幕默认项+字体入口 | ⬜ |
| `settings` | FontManagerPage | `/settings/fonts` | 系统+云端字体管理 | ⬜ |
| `settings` | LogPage | `/settings/log` | 日志查看/导出/脱敏 | ⬜ |
| `account` | AccountPage | `/account` | 平台账号中枢(cookie/扫码/多账号) | ⬜ |
| `backup` | BackupPage | `/settings/backup` | 本地备份/恢复+恢复预览 | ⬜ |
| `backup` | WebDavPage | `/settings/webdav` | WebDAV 多服务器同步 | ⬜ |
| `backup` | RemoteSyncPage | `/settings/remote-sync` | 局域网设备同步(配对/mDNS) | ⬜ |
| `toolbox` | ToolboxPage | `/toolbox` | 链接解析→跳房间/取流地址 | ⬜ |
| `about` | AboutPage | `/about` | 关于/许可/主页/声明 | ⬜ |
| `about` | VersionPage | `/about/updates` | 更新检查/日志/下载源 | ⬜ |

非页面域:链接接管(`services/intake`)、开机开场(splash,做成 `app/shell` 的可选开场层,
不占路由)。对应关系:原 `record_settings` 并入 `recorder` 域;原 `web_dav`/`remote_receiver`
/`tv_sync` 并入 `backup` 域;原 `hot_areas`(平台展示设置)并入 `settings` 的平台节;
原 `auth`(云账号停用说明页)不迁——v2 无云账号。

## 5. 约定

**命名:** 文件 `snake_case.dart`;页面 `XxxPage`;控制器 `XxxController`;面板 `XxxPanel`;
provider 文件 `<域>_provider.dart`;路由文件 `<域>_routes.dart`。测试镜像 lib 路径
(`test/features/room/...`)。

**codegen:** freezed/riverpod/json/slang/go_router_builder 的 `*.g.dart` 按仓库惯例提交;
改动后 `dart run build_runner build --delete-conflicting-outputs`(app 目录内执行)。

**l10n:** 每域一个键命名空间(`home.*`、`room.*`、`settings.appearance.*`);占位与复数用
slang 语法;中文为源语言,英文跟随。新增页面的验收包含"零硬编码文案"。

**图标:** 页面只用 `core/icons/app_icons.dart` 的语义名(如 `AppIcons.record`);各设计语言
的覆盖映射也在这里,页面不直接写 `Icons.*`。迁移期允许 Icons.* 存在于 widgets/ 内,落 seam
时统一替换。

**平台分支:** 业务代码禁止 `Platform.isXxx`;平台差异只出现在 `data/platform/`、
`app/windows/` 的装配层,页面读 `PlatformEnvironment` 事实。

## 6. 现状 → 目标归宿(迁移映射)

| 现状文件 | 目标归宿 | 说明 |
|---|---|---|
| `main.dart`(308→瘦身版) | `main.dart` + `app/app.dart` | 入口只留 args/boot/runApp |
| `app/adaptive_shell.dart` | `app/shell/` | 已有内容原样迁 |
| `app/appearance_mapping.dart` | `app/theme/` | 已有内容原样迁 |
| `app/providers.dart` | `app/providers/services_provider.dart` | 后续 playback/sites/recording 分文件 |
| `app/router.dart(+g)` | `app/router/` | 域路由文件随后续页面出现 |
| `app/delegates.dart`、`app/adapters.dart` | 原地 | 已符合 |
| `core/formatters.dart`、`core/errors.dart` | 原地 | 已符合(本次新建) |
| `platform/platform_composition.dart` | `data/platform/` | 本次新建,待迁 |
| `storage/services.dart` | `data/app_services.dart` | 原 AppServices,扩展为全链聚合后迁 |
| `features/settings/appearance_page.dart` 等 | 原地 | 已符合;硬编码文案待 l10n 替换 |
| `features/home|follow|history` 占位页 | 原地 | 内容随对应波次替换 |
| `background_demo_page.dart` | 删除 | ADR 0005 定案后 |

**实施顺序:** 先做迁移映射里的六处搬移(纯移动+import 修正,一次提交),再继续接线。
未在映射中的层(`services/`、多数 `features/`)随对应功能波次创建,不预建。
