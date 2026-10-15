# PureLive App 目录架构(apps/pure_live/lib)

> 本文是 app 目录的**权威设计**,与项目既有文档对齐后修订(2026-10-15):
> 状态架构遵循 `riverpod-state-architecture.md`(feature 内 presentation/application/data,
> 不建 controllers/managers 目录);装配遵循 `pure_live_design_guide.md` §1.5(PureLiveServices
> 有序装配 + 逆序关闭,无全局单例);宏观职责见 `pure_live_architecture.md` §2(app 层 =
> app/bootstrap/router/shell)。动任何 app 代码前先读这里;设计变更先改这里。
>
> 依据:功能基线 `docs/pure-live-architecture.md`(原应用全量审查);包能力见主文档 §2。

---

## 1. 总原则

1. **目录按"变更原因"划分。** 一个功能域的页面、状态、数据访问在一个目录;跨域复用才上提。
2. **三条适配轴,三个固定归宿,不新增目录轴:**
   - **设计语言(多语言皮肤)**:归宿是 `live_uikit` 运行时注册表。app 内只有 `app/adapters.dart`
     (注册)与 `app/theme/`(UiConfigurationMapper 单向映射:平台事实+用户偏好→UI 类型)。
     页面只写 `Live*` 组件,**永不 switch(designLanguage)**,**永不 import 具体风格库**(守卫拦截)。
   - **形态(mobile/desktop/tv)**:归宿是 `LiveEnvironment`。AppShell **只换 chrome,页面三形态
     是同一个实例**(设计指南 §2.5);页内按 mode 分支,分支超长才拆 `widgets/` 私有组件。
     禁止 `ui/desktop/`、`ui/mobile/` 目录树。TV 的焦点/遥控基建(`focus/`+`input/`)属于
     live_uikit(待补,见设计指南第五部分),不在 app 里自造。
   - **语言(中英双语,3.x 基线)**:归宿是 `lib/l10n/`(slang;明确不引 easy_localization)。
     页面零硬编码文案。
3. **能力 = 契约 + `is` 探测,不是布尔 flag**(设计指南 §1.2):页面入口一次性
   `site is LiveSearchCapability` 决定功能面;禁止运行中 catch `UnimplementedError` 当业务分支;
   禁止页面做平台或站点的散点特判(`Platform.isX` 只许出现在 app 装配层)。
4. **层次单向**(主架构文档 §4 + 设计指南 §1.1):`features → 包(live_*)`;`core` 被所有层
   依赖;`app` 认识一切;`features` 互不 import。
5. **不为凑树建空文件**;小功能允许平铺,层目录在第一份真实内容落地时创建。

## 2. 顶层目录

```text
apps/pure_live/lib/
├── main.dart                 # 进程入口:LaunchArgs 解析 → boot → runApp;多窗口同入口分角色
│
├── l10n/                     # slang 翻译源(zh 源 + en)+ 生成产物;页面零硬编码文案
│
├── core/                     # 与直播业务无关的跨域基础;仅收"真实重复"的能力(状态架构文档 §11)
│   ├── errors.dart           # 领域异常 → 用户文案(取消 → null);slang 就绪后改返键
│   ├── formatters.dart       # 人数(万/亿)/时长/字节
│   ├── icons/                # 语义图标 seam(原应用 remixicon 基线的 v2 对应物)
│   ├── extensions/           # context/theme 扩展
│   └── widgets/              # 跨域通用小部件(仅确有第三处复用时才进)
│
├── app/                      # 应用装配(UI 侧组合根;不被业务 import)
│   ├── app.dart              # PureLiveApp 根
│   ├── bootstrap/            # 启动装配(PureLiveServices,顺序即语义,见 §4):
│   │   ├── app_services.dart #   聚合服务图(现 storage/services.dart 的 AppServices 扩展)
│   │   ├── platform.dart     #   live_platform 接线(claim 目录/TV 同源/FFI 身份)
│   │   ├── paths.dart        #   live_platform_path_provider 接线 + 下载目录规划(私有目录提示)
│   │   └── downloads.dart    #   FileDownloader(.part 断点续传,自原应用移植)
│   ├── engine/               # media_core 接缝(迁移方案 §3.5"接缝全部在 app 壳装配"):
│   │   ├── playback_engine.dart   #   PlaybackEngine 实现:LivePlayLine→PlayerSource→kernel
│   │   └── danmaku.dart          #   弹幕连接工厂(site capability→InteractionSource)
│   ├── router/
│   │   ├── router.dart       # GoRouter 装配 + $appRoutes;每域路由文件进 routes/
│   │   └── routes/           # home_routes.dart、room_routes.dart…
│   ├── app_providers.dart    # 唯一的全局 provider 文件(状态架构文档 §4:只放应用级依赖)
│   ├── shell/                # AppShell:只换 chrome(mobile 底栏/desktop rail/tv 顶部焦点行);
│   │                         # 统一包裹 TV 必需的 LiveRemoteInput + LiveFocusRestorer
│   ├── theme/                # UiConfigurationMapper(唯一映射点)+ UiConfig↔偏好持久化桥
│   ├── adapters.dart         # 设计语言 LanguageRegistry 常量
│   ├── delegates.dart        # l10n + 各设计语言 localizations
│   ├── windows/              # 桌面多窗口角色(主窗/房间窗)与第二进程装配
│   └── diagnostics.dart      # 启动诊断:发行类型冲突、resolver 降级、boot 时序
│
└── features/                 # 页面域;域内三层按需出现,小域可平铺(状态架构文档 §4)
    └── <域>/
        ├── presentation/     # 页面与组件(<域>_page.dart、widgets/、按形态的 pane 拆分)
        ├── application/      # Provider/Notifier(状态编排;文案不入;纯逻辑可单测)
        └── data/             # Repository 装配(包服务→页面状态;复杂才建,小域并入 application)
```

**不存在的顶层目录(刻意):** `services/`、`data/`(领域服务的消费在 feature 的
`application/`+`data/` 与 `app/bootstrap|engine/`,不设平行的服务目录轴——避免与包层职责
重复)、`ui/`、`models/`、`utils/`、`pages/`。

## 3. 功能域的固定内聚结构

```text
features/<域>/
├── presentation/          # <域>_page.dart(组装,≤200 行)+ widgets/;形态分支拆 pane 也在这里
├── application/           # @riverpod 生成式 Provider/Notifier;查询用函数式,可变状态用 Notifier
└── data/                  # Repository(组合包服务与本地存储;小域可并入 application)
```

规则(全部来自 `riverpod-state-architecture.md`):

- Provider 按"业务对象"命名(`rooms_provider.dart`),不按层命名;禁止手写
  ChangeNotifier/状态基类;`AsyncValue` 表达加载/错误/数据,重试走 `ref.invalidate`。
- **生命周期三条线**:页面级状态默认自动销毁;共享状态明确失效条件;播放会话/弹幕连接/
  录制任务长于页面——所有权在组合根与 Coordinator,**`keepAlive` 不是资源所有权方案**。
- **主题/偏好变化只重建派生 Provider,绝不重建播放会话或弹幕连接**(主架构文档硬约束)。
- Widget 内的临时 UI 状态(弹窗开合等)留在 Widget,不上提。
- settings 集群例外:一个域多个 `*_page.dart` 平铺。

## 4. 启动装配顺序(bootstrap,顺序即语义)

```
LaunchArgs(含 --instance/--open-room、TV 声明)
  → 平台事实(PlatformBootstrap:init,发行类型在此解析)
  → 日志(live_log,先于网络——故障才有地方落)
  → 存储(StorageBootstrap)→ 偏好(PreferencesService)
  → 路径(PathProviderBootstrap)→ 内容库(library/iptv)→ 网络(LiveHttp)
  → 站点注册表(SiteRegistry:33+ 站 + IPTV 平等接入;engine/弹幕工厂绑定)
→ ProviderScope(app_providers 覆盖)→ AppShell → 路由
退出:逆序 shutdown,落盘在进程退出前完成(退出零残留)。
```

无全局单例:服务图由组合根持有、显式下传;第二实例(测试脚手架/第二扇窗)不共享。

## 5. 功能域清单(终局,来自原应用全量审查)

路由:壳内 branch(`/`、`/follow`、`/history`)之外全部为壳外全页。状态:✅ 已有 · ⬜ 待建。

| 域目录 | 页面(presentation/) | 路由 | 内容(原应用对应) | 状态 |
|---|---|---|---|---|
| `home` | HomePage | `/` | 菜单(关注/热门/分区/录制中心,可自选)+推荐流 | ⬜ 占位 |
| `popular` | PopularPage | `/popular` | 每平台推荐 tab(平台显隐排序读设置) | ⬜ |
| `areas` | AreasPage | `/areas` | 全部分区+关注分区 | ⬜ |
| `area_rooms` | AreaRoomsPage | `/areas/:site/:areaId` | 分区房间列表+关注分区 | ⬜ |
| `search` | SearchPage | `/search` | 房间/主播双模式、范围与排序、覆盖度分级(含 webOnly 内嵌浏览器) | ⬜ |
| `room` | RoomPage | `/room/:site/:roomId` | 房间页全套;panels 子体系(录制/弹幕设置/换房/睡眠/音量/直链) | ⬜ |
| `multiview` | MultiviewPage | `/multiview` | 多画面(media_core_multiview 承载,票据复用已定案) | ⬜ |
| `follow` | FollowPage | `/follow` | 关注+分组+标签 | ⬜ 占位 |
| `history` | HistoryPage | `/history` | 观看历史 | ⬜ 占位 |
| `tags` | TagsPage | `/tags` | 用户自建标签 | ⬜ |
| `iptv` | IptvPage | `/iptv` | 源管理/分组/EPG/catchup/播放 | ⬜ |
| `recorder` | RecorderPage、RecordSettingsPage | `/recorder`、`/settings/recording` | 录制中心+设置(同域两页平铺) | ⬜ |
| `shield` | ShieldPage | `/settings/shield` | 弹幕屏蔽(关键词/用户/正则/相似度) | ⬜ |
| `settings` | Settings、Appearance、Danmaku、FontManager、Log 各页 | `/settings/**` | 设置集群(17 节目标态);含平台展示设置(原 hot_areas) | ✅ 索引+外观;余 ⬜ |
| `account` | AccountPage | `/account` | 9 平台 cookie + B 站扫码/网页登录 + 多账号 | ⬜ |
| `backup` | Backup、WebDav、RemoteSync 各页 | `/settings/**` | 本地备份/WebDAV/局域网同步 | ⬜ |
| `toolbox` | ToolboxPage | `/toolbox` | 链接解析→跳房间/取流地址 | ⬜ |
| `about` | AboutPage、VersionPage | `/about`、`/about/updates` | 关于/许可;更新检查/镜像/下载 | ⬜ |

**不进 app 的(定位裁决,主架构文档 §1):** 音乐与点播(live_vod 方向,pure_music 另案)、
DLNA 投屏(media_core_cast_dlna 承载,需要时经 `app/engine/` 绑定)、本地互动(E:\study 的
客户端假礼物/成长体系,无 v2 文档规划,裁决为不做)。原 `auth`(云账号停用说明页)不迁。

## 6. 约定

- **命名:** 文件 `snake_case.dart`;页面 `XxxPage`;Notifier `XxxNotifier`;路由文件
  `<域>_routes.dart`;provider 文件按业务对象命名。测试镜像 lib 路径(app 层不建测试/Demo
  **交付模块**,业务纯逻辑单测按状态架构文档 §8 执行)。
- **codegen:** riverpod/freezed/json/go_router_builder/slang 的 `*.g.dart` 照仓库现行惯例
  入库;改动后 build_runner 一次生成。
- **文案:** 中英双语;新增页面验收含"零硬编码文案"。
- **图标:** 页面用 `core/icons` 语义名,不直写 `Icons.*`;迁移期暂许,落 seam 时统一替换。
- **平台分支:** 业务代码禁 `Platform.isX`;差异只出现在 `app/bootstrap|windows/`,页面读
  `PlatformEnvironment` 事实(四轴:平台/设计语言/输入/形态,严禁混为一个枚举)。

## 7. 现状 → 目标归宿(迁移映射)

| 现状文件 | 目标归宿 | 说明 |
|---|---|---|
| `main.dart` | `main.dart` + `app/app.dart` | 入口只留 args/boot/runApp |
| `app/adaptive_shell.dart` | `app/shell/` | 迁移时补 TV 顶部焦点行与 RemoteInput/FocusRestorer 包裹 |
| `app/appearance_mapping.dart` | `app/theme/` | 与 UiConfigurationMapper 合并为唯一映射点 |
| `app/providers.dart` | `app/app_providers.dart` | 改名对齐状态架构文档;不扩成目录 |
| `app/router.dart(+g)` | `app/router/` | 域路由文件随页面出现 |
| `app/delegates.dart`、`app/adapters.dart` | 原地 | 已符合 |
| `core/formatters.dart`、`core/errors.dart` | 原地 | 已符合(本次新建) |
| `platform/platform_composition.dart` | `app/bootstrap/platform.dart` | 本次新建,待迁 |
| `storage/services.dart` | `app/bootstrap/app_services.dart` | 按 §4 顺序扩展为全链聚合后迁 |
| `features/**`、`background_demo_page.dart` | 原地/删除 | 同前版结论 |

**实施顺序:** 先做映射中六处搬移(纯移动+import 修正,一次提交),再按 §4 补全 boot 链。
`engine/`、多数 `features/` 随对应功能波次创建,不预建。
