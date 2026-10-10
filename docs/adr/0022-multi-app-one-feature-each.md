# ADR 0022 — 多应用组合:一个 App 一个功能

- 状态:已接受(2026-10-10)
- 取代:`ADR 0015` 的"单应用"前提部分;`docs/roadmap/w1-rebuild-progress.md` §5bis 的"壳即插件宿主"总前提
- 相关:`ADR 0017`(TVBox 走嵌入式 CPython)、`ADR 0019`(网关服务边)、`docs/architecture/application-portfolio.md`

## 背景

v2 到目前为止只有一个应用壳 `apps/pure_live`,并被要求承担全部产品形态:直播、点播、B 站视频、
音乐、TVBox 导入、IPTV、录制。为此又推出"壳里不写任何站点,站点一律以导入插件接入"的方向
(w1-rebuild §5bis)。两条前提叠加后的结果是:

1. 一个 App 要同时满足四种完全不同的交互模型(遥控器 D-pad 的直播墙、手机竖屏的 B 站信息流、
   音乐播放器、TVBox 源管理),UI 与状态层的分支条件互相污染;
2. 站点接入方式被迫做成"一律插件",于是直播这种需要签名、Cookie 租约、低延迟换源的场景,
   反而要绕 JS/Python 沙箱边界(§5.2 的虎牙 antiCode 只能写在壳里,正是因为沙箱路线不适合它);
3. 依赖清单里为不存在的第二/第三/第四个 App 预留了大量位置,而每个 App 真正需要的只是其中一部分;
4. 任何一个功能的实验都会波及整个壳的启动路径与体积。

## 决策

**仓库改为"一个 App 一个功能"的多应用 monorepo,共享逻辑全部下沉到 `packages/`。**

| App | 产品 | 站点接入方式 | 明确不做 |
|---|---|---|---|
| `apps/pure_live` | 直播软件 | **native Dart 源**(huya / douyu / bilibili live / demo 种子) | 不做 JS/Python 插件宿主、不做 TVBox 导入、不做音乐 |
| `apps/pure_bili` | B 站视频客户端(参照 newBV) | native Dart(bilibili vod) | 不做直播、不做外部生态导入 |
| `apps/pure_music` | 音乐客户端 | lx 音源脚本 + bmsc 式 B 站音源/歌单导入 | 不做视频与直播 |
| `apps/pure_tvbox` | TVBox 客户端 | **导入即运行**:JS/Python spider、单仓/多仓/JSON/M3U/EPG | 不内置任何 native 站点 |

配套规则:

1. **App 之间禁止任何依赖**(包括 dev 依赖与测试依赖)。共享只有两条路:下沉到 `packages/`,
   或各自实现。
2. **每个 App 是自己进程的唯一组合根**(I9 由"全仓唯一"改为"每 App 唯一")。`packages/` 里任何包
   仍禁止 import 应用包。
3. **插件/外部生态不是全局前提,而是 `pure_tvbox` 的功能**。`ecosystem/plugin_host`、
   `ecosystem/js_runtime`、`integrations/python_runtime`、`ecosystem/external_tvbox` 保留在共享层
   (因为机制可复用),但只有 `pure_tvbox` 装配它们;`pure_live` 的组合根里不再出现插件宿主。
4. **native Dart 源是合法的一等接入方式**,适用于需要签名算法、Cookie 租约、低延迟换源的直播场景;
   它受同样的 capability 契约约束(`pure_live_capability`),因此换源、聚合、历史/收藏这些上层机制
   对"native 源"与"导入源"一视同仁。
5. **用户数据不跨 App 共享**:收藏/历史/歌单/设置各 App 一份(各自 `getApplicationSupportDirectory()`
   下的独立文件)。共享的是**机制**(`packages/services/*`),不是数据库。理由:四个产品有不同的账号、
   内容域与生命周期,把用户数据绑在一起会让任何一个的迁移/清理风险传染给其余三个。跨 App 合流留给
   `foundation/backup` + `foundation/sync` 在显式导入/导出时做。
6. **平台矩阵按 App 声明**:`pure_live`/`pure_tvbox` 以 Android + Android TV + Windows 为主;
   `pure_bili`/`pure_music` 以 Android + iOS 为主。CI 与验收按 App 分道,不再要求一个产物覆盖全部。

## 后果

- **正面**:每个 App 的启动路径、依赖树和体积只含自己需要的层;`pure_live` 可以去掉 JS/Python
  运行时与插件存储,直播换源不再受沙箱边界约束;`pure_tvbox` 可以按 TVBox 用户的真实心智设计导入面,
  而不必给直播用户解释 spider/data 插件。
- **代价(接受)**:四个 App 各自要维护壳层(路由、主题、更新入口、启动装配),重复面由
  `packages/ui/*` 与 `packages/features/*` 压到最小;发布/版本/CI 变成 4 条线;跨 App 的"一处修复
  四处生效"依赖包层纪律,壳里不许留业务逻辑。
- **需要改的既有产物**:`tool/check_architecture.dart` 目前只认 `apps/pure_live`,要扩成多 App
  并新增"App 之间互不依赖"的规则;根 `pubspec.yaml` 的 `workspace:` 增员;发布工作流按 App 拆分;
  `packages/README.md` 的消费矩阵按四个 App 重写。
- **不回收的旧决定**:§5bis 的插件导入实现(PluginStore / JsPluginRuntime / PythonSpiderHost /
  SpiderVodProvider)不删除,整体归 `pure_tvbox` 装配;`providers/huya`、`providers/douyu`、
  `providers/bilibili` 的 native 实现不删除,归 `pure_live`(vod 部分归 `pure_bili`)。
- **判据**:如果某个能力在两个 App 里长得不一样但底层事实相同,下沉到包;如果连事实都不一样,
  留在各自 App。这条判据用来阻止"为了不写两遍而把两个产品揉进一个 API"。
