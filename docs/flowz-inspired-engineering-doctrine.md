# PureLive 工程纲领 —— 借鉴 FlowZ 的跨平台系统设计原则

> 本文不是模块职责说明书（那部分见 [`pure_live_architecture.md`](./pure_live_architecture.md)），
> 而是从成熟同类产品 **FlowZ**（Electron + sing-box 跨平台代理客户端，见
> `C:\Users\XA-158\Downloads\FlowZ-main`）中提炼出的**系统工程理念**，映射到 PureLive
> 这个 Flutter 跨平台直播聚合应用上，形成一组可执行、可验收的设计原则。
>
> 状态标注：**[已达成]** / **[部分]** / **[待补]** —— 对照 `packages/` 当前真实代码。
>
> 与其他文档的分工：模块边界见 `pure_live_architecture.md`；状态管理见
> `riverpod-state-architecture.md`；存储见 `storage-architecture.md`；分页见
> `pagination-architecture.md`；codegen 见 `codegen.md`。本文只谈**贯穿式工程原则**，
> 不重复上述内容。

---

## 0. 为什么要参考 FlowZ

FlowZ 与 PureLive 表面不同（一个是代理客户端、一个是直播聚合应用），但在**系统工程层面**面对几乎相同的难题：

| 共同难题 | FlowZ 的解法 | PureLive 的对应面 |
| --- | --- | --- |
| 编排一个"外部权威引擎"（sing-box 内核 / 播放器内核 + 平台协议） | 服务化 + gRPC 原生管理面 | `live_playback` + `media_core` + 34 个 `live_sites` 平台 |
| 多平台形态差异（Win/mac/Linux/TV） | extraResources + 平台分支 | 移动/桌面/Android TV，六种设计语言 |
| 配置改动与"正在运行的会话"之间的冲突 | "改规则不断流"热重载 | 切清晰度/线路/主题不能打断播放 |
| 进程生命周期残留（虚拟网卡/系统代理/子进程） | "退出零残留" + 崩溃兜底 | 播放器/弹幕 socket/HTTP 连接的确定性回收 |
| 大版本/资源下载的失败与回滚 | 下载完整性校验 + 失败回滚 + 跳过坏版本 | 订阅更新 / 规则资源 / 应用自更新 |
| 能力不确定（fork 内核、缺库） | "核心即权威"运行时探测 | 引擎能力协商、线路可用性探测 |

FlowZ 的可贵之处在于：这些原则不是零散技巧，而是**一以贯之地写进了代码与 CI**。本纲领就是要把它
的"设计哲学"固化为 PureLive 的团队约定。

> **重要约束**：PureLive 遵循 [`pure_live_architecture.md` §15] 的"**不新增测试与 Demo 交付模块**"。
> 因此本文中的"质量门禁"一律表述为**非测试类的机械校验**（analyzer / codegen 不变量 / 死代码基线 /
> CI 构建矩阵），而非照搬 FlowZ 的单元测试门禁。

---

## 1. 六大工程纲领

每条纲领给出：**FlowZ 原语 → PureLive 落地规则 → 现状 → 反模式**。

### 纲领一：单一权威与能力协商（FlowZ「核心即权威」）

**FlowZ 原语**：GUI 不自带对协议的臆测——贴上的 outbound 交给当前 sing-box 内核去探测是否被支持；
官方内核不支持的协程可换第三方 fork，FlowZ 识别 fork 后自动关闭在线更新以保护它。

**PureLive 落地规则**
- **播放引擎是媒体能力的唯一权威**：`live_playback` 不得假设某线路/codec 一定可播，应通过
  `media_core` 的 `PlayerAdapterCapabilities` 在会话建立时**协商**，失败即归类并降级。
- **平台（site）是数据能力的唯一权威**：`live_sites` 的每个平台实现声明自身能力（是否有点播、
  是否有弹幕、可用画质档、是否需签名/Cookie），上层**只读能力声明**，不得用 `if (siteId == 'x')`
  之类的散点特判。
- **线路降级是一等公民**：同线路刷新 → 跨线路 → 跨引擎，恢复策略显式建模，而非"播放失败就报错"。

**现状**：**[部分]** `live_sites` 已有 `registry` + `contracts` + 34 平台，`live_playback` 有
`engine/`/`coordinator/`/`session/` 分层；能力声明的**统一契约**仍需在各平台收敛到
`SiteCapabilityDescriptor` 级别，避免页面侧出现站点特判。

**反模式**：在 UI/Riverpod 层直接判断具体站点 id 或播放器类型来决定行为；把"能不能播"交给猜。

---

### 纲领二：变更分级——"不断流优先"（FlowZ「改规则不断流」）

**FlowZ 原语**：编辑已启用规则的匹配值 → 经 local rule-set **热重载、零中断**；只有结构变更
（增删/排序/改动作/改端口/TUN）才重启内核，且**去抖合并、连改多次只重启一次**。

**PureLive 落地规则**——把所有"用户可改的东西"分成两级：
- **软变更（不重建会话/连接）**：切换设计语言、明暗、弹幕开关/透明度/字号、列表布局、清晰度档内
  的画质选择、已关注房间的备注/分组。这些只重建**派生状态**，绝不新建播放会话、不断弹幕连接、
  不重新拉取直播间。
- **硬变更（需去抖重建）**：切换播放引擎、换线路、改 TUN 级别的系统接管、结构性增删规则集。必须
  **去抖合并**为一次重建，且明确"约 1 秒自动恢复"是设计如此，不是 bug。

**现状**：**[已达成（UI 侧）]**。[`apps/pure_live/lib/src/app.dart`](file:///d:/flutter/pure_live/apps/pure_live/lib/src/app.dart)
中主题由 preferences **单帧重解析**，注释明确写道"切 Neumorphic 是一帧变化、不是重启，会话/连接/
直播间拉取都不重建，因为主题是派生状态而服务不是"——这正是 FlowZ 热重载精神的 UI 版。
**[待补（播放侧）]**：画质/线路热切的"去抖合并 + 优雅断流开关"需在 `live_playback/coordinator`
中对齐该分级。

**反模式**：切主题导致 `Provider` 重建整棵业务树；改一个偏好项触发播放器重新初始化。

---

### 纲领三：显式声明优于推断（FlowZ「一次授权零提权」的抽象）

**FlowZ 原语**：装一次提权 helper 后全程免授权；能力/内核来源显式可辨，不靠猜。

**PureLive 落地规则**
- **形态显式声明**：TV 不是"屏幕大一点的桌面"。当前构建是否面向 TV 由**启动参数/`--dart-define`/原生桥**
  **声明**，绝不自动推断——把手机误判成 TV 会给出一个没人能用遥控器操作的界面。
- **目录/权限显式解析**：持久数据目录走"环境变量覆盖 → OS 应用支持目录 → 文档目录"的**有序链**，
  **cache 目录被刻意排除**在持久链外。
- **策略性失败要"响亮"**：读不到可持久化根目录时，**宁可启动报错并展示 boot error**，也不要带着
  "下次清理就丢失的设置"静悄悄启动。

**现状**：**[已达成]**。[`services.dart`](file:///d:/flutter/pure_live/apps/pure_live/lib/src/services.dart) 的
`boot({declaredTvBuild})` 与 `resolvePersistentDirectory` 完全体现本纲领（注释即设计说明）。

**反模式**：用宽度阈值反推设备形态；把用户设置写进可被系统回收的 cache 目录。

---

### 纲领四：退出零残留与兜底回收（FlowZ「跨平台清理 + 崩溃/登出/关机兜底」）

**FlowZ 原语**：退出时跨平台清理内核进程/虚拟网卡/系统代理注册表项，并崩溃、登出、关机都有兜底。

**PureLive 落地规则**
- **逆序确定性关闭**：服务图按构建逆序 `shutdown()`，偏好落盘与存储关闭必须**在进程退出前完成**，
  且从**应用生命周期钩子**调用，而非某个 widget 的 `dispose`。
- **连接类资源必须可回收**：弹幕 WebSocket/HTTP 长连、播放器 surface、平台签名会话，都要有
  `dispose`/`suspend`/`resume` 的确定性路径；异常退出后不留悬挂连接。
- **看门狗与限额**：对渲染内存、连接重连次数设上限，避免长时间后台后资源泄漏导致卡顿。

**现状**：**[部分]**。`PureLiveServices.shutdown()` 已实现逆序关闭（preferences→library→history→
iptv→storage）；`live_log` 有 sink fan-out。**[待补]**：播放会话与弹幕连接（`live_playback`/
`live_interaction`）在**应用级生命周期**（非 widget 级）与平台挂起事件上的兜底回收；FlowZ 的
renderer-memory-watchdog 式的资源看门狗尚无对应。

**反模式**：靠 widget `dispose` 保证数据落盘；弹幕 socket 只在新建房间时关，切页/后台不关。

---

### 纲领五：类型化装配与反上帝对象（FlowZ 服务化 + 类型化 IPC registry）

**FlowZ 原语**：主进程服务化（70+ service）+ `IpcHandlerRegistry` 用**类型化 `IpcChannel` 联合**
杜绝"孤儿 channel/重复注册静默覆盖"。代价是 `main/index.ts` 长到约 2385 行、组装耦合重。

**PureLive 落地规则**
- **组合根持有服务图并显式下传，不做全局单例**：这样第二个实例（测试脚手架、第二扇窗）无法
  偷偷共享同一个图。
- **装配有序**：平台层先答"东西在哪"→ 日志先于网络（传输失败要有地方落）→ 数据库先于偏好 →
  偏好先于首帧（主题从偏好解析）。
- **契约走类型**：跨包共享的类型放入各包的 `contracts`/公共导出，**不 import 内部路径**、不用
  循环依赖调用。Riverpod Provider 作为运行时装配的补充，而非替代显式服务图。

**现状**：**[已达成，且优于 FlowZ]**。`PureLiveServices.boot()` 是**显式、有序、无单例**的组合根，
注释直言"nothing here is a global singleton"，天然规避了 FlowZ 那个 2385 行上帝入口的问题。
`analysis_options.yaml` + melos `analyze` 保障跨包类型正确。

**反模式**：`ServiceLocator.instance` 式全局可变单例；包之间互相 import `src/` 内部实现。

---

### 纲领六：韧性与完整性（FlowZ 下载校验 / 失败回滚 / 跳过坏版本 / 退避 / 诊断脱敏）

**FlowZ 原语**：自动更新带**完整性校验 + 启动预检 + 失败自动回滚 + 问题版本跳过**；订阅更新用
**指数退避**、且"更新不打断当前连接"、"节点指纹对账保留本机 id 与选中项"；诊断报告**一键去敏导出**；
配置写盘用 `atomic-write`；SSRF/重定向有专门守卫。

**PureLive 落地规则**
- **刷新即韧性**：订阅/关注列表/规则资源/IPTV 源更新采用**指数退避 + 抖动**，失败不影响正在观看的会话。
- **更新不改变用户选择**：拉取到新的房间/线路集合时，按**稳定身份**对账，保留用户自己的分组、
  备注、选中项、历史（呼应 [`storage-architecture.md`] 中"持久模型 ≠ 网络响应模型"的边界）。
- **原子写与可回滚**：偏好/库的落盘走原子写，损坏时降级为"保留默认 + 记 warning"，不整体丢数据。
- **诊断去敏导出**：日志 ring buffer（`live_log` 的 `MemorySink`）+ 结构化字段，导出去除 Cookie/
  token/房间的敏感标识。

**现状**：**[部分]**。`live_preferences` 有 `load()` 返回 `report.isClean`、坏文档降级保默认；
`live_log` 有 `MemorySink(capacity:1000)` 供报告附带；`pagination_core` 定义了刷新/并发策略。
**[待补]**：订阅/资源刷新的**退避调度器**与**失败回滚/跳过坏版本**语义；诊断**去敏导出**的统一封装。

**反模式**：刷新失败即整表清空；更新覆盖用户分组；日志明文含 Cookie 直接导出。

---

## 2. 跨平台 UI：把 FlowZ「Conduit 设计系统」落到 live_uikit

FlowZ 用 **token 驱动的 Conduit 双主题设计系统 + 自托管字体**保证视觉统一。PureLive 的目标更大——
**六种设计语言（Material/Cupertino/Fluent/macOS/Yaru/Neumorphic）共用同一套组件契约**。映射原则：

- **令牌 → 契约 → 多语言实现 → 平台/输入适配 → TV 焦点基础**（`live_uikit` 已按此目录组织：
  `tokens/`、`components/`、`design_languages/{六种}`、`focus/`、`input/`、`layouts/`、`backgrounds/`、`theme/`）。
- **四个正交维度不得混为一枚举**：运行平台、设计语言、交互模式（Touch/Mouse/Keyboard/Remote）、
  布局模式（Mobile/Desktop/TV）。
- **业务页面只调统一契约**（`LiveButton` 等），不得为设计语言写六套分支，也不得直接依赖某设计语言的
  内部实现（呼应 `pure_live_architecture.md` §7、§14）。

现状：**[部分]** 六语言目录已建立、`UiConfigurationMapper` + `LiveThemeResolver` 已跑通
（含 `onFallback` 回退记日志）。待补：各设计语言的**组件覆盖度对齐**与 **TV 焦点/遥控器基础**
（`focus/` 与 `input/`）作为一等能力完善。

---

## 3. 质量门禁与 CI 建议（非测试类机械校验）

在遵守"不新增测试"的前提下，借鉴 FlowZ 的"发布前强制校验"与"双平台 CI"：

| FlowZ 机制 | PureLive 适配（非测试） | 现状 |
| --- | --- | --- |
| `test:core-gate` 打包前不变量阻断 | **codegen 不变量校验**：`melos gen` 后检查 Freezed/JSON 产物与源模型一致；分析器 `public_member_api_docs` 等契约规则 | **[部分]** 已有 `melos gen` |
| ESLint + Prettier + husky + lint-staged | `dart analyze` + `dart format`（melos 脚本）；pre-commit 走 format/analyze | **[已达成]** 脚本就绪，钩子待接 |
| `kareki` 死代码基线 | 已有：`dart run kareki --baseline .kareki-baseline.json`（新增即失败、基线内放行） | **[已达成]** |
| 双平台 CI（mac+win）required checks | GitHub Actions：Linux/Windows/macOS 矩阵跑 `melos bootstrap + analyze + format --set-exit-if-changed + build`，PR 需绿 | **[待补]** `.github/workflows` 存在，需确认覆盖 |
| 打包与验证分离 | 验证 workflow 快反馈；发布/打包 workflow 单独触发 | **[待补]** |

**建议的最小 CI**（每个 PR / main push）：
```
melos bootstrap
melos gen            # 校验生成产物无 drift（有 diff 即失败）
melos run analyze    # 跨包静态分析
melos run format     # --set-exit-if-changed
melos run kareki     # 死代码基线
flutter build <各目标平台>   # 至少 Linux/Windows 桌面 + 一个移动目标编译通过
```

---

## 4. PureLive 现状快照（真实完成度）

> 依据 `packages/*/lib` 实际扫描（Dart 文件数 / 代码行 / 是否含测试）。全仓无测试文件，
> 符合"不新增测试"的项目约定。

| 包 | 规模 | 职责 | 完成度 |
| --- | --- | --- | --- |
| `live_sites` | 193 文件 / ~35.8k 行 | 直播平台领域层（`common/contracts/models/platforms/registry`，**34 个平台**：bilibili、douyu、huya、soop、youtube、twitch、tiktok…） | **主力，较完整** |
| `live_uikit` | 58 文件 / ~10.6k 行 | 六设计语言 UI 系统（tokens/theme/components/focus/input/layouts/backgrounds） | **骨架完整，覆盖度对齐中** |
| `live_iptv` | 44 文件 / ~7.6k 行 | IPTV/M3U 频道与源管理 | **较完整** |
| `live_playback` | 12 文件 / ~2.4k 行 | 播放编排（`engine/coordinator/session/model`，含原 `media_core` 能力面） | **核心分层已立** |
| `live_preferences` | 22 文件 / ~3.0k 行 | 偏好与配置（Hive 存储、坏文档降级） | **可用** |
| `live_net` / `live_log` / `live_storage` / `live_platform` | 14/15/23/19 文件 | Dio 工厂 / 分级日志 sink / Hive 引导 / 平台事实与目录解析 | **基础设施就绪** |
| `pagination_core` | 12 文件 / ~0.9k 行 | 统一分页契约（详见 `pagination-architecture.md`） | **已抽象** |
| `live_library` / `live_interaction` | 7 / 8 文件 | 关注·分组·历史 / 弹幕会话·去重·观众数分发 | **早期，边界已定** |
| `integrations/{firebase,media,python_runtime}` | 占位 | 预留集成（不在 workspace 内） | **未启用** |
| `apps/pure_live` | 组合根 | `services.dart`(显式服务图) + `app.dart`(主题单帧重解析) + `pages` + `ui/app_shell` | **装配跑通** |

---

## 5. 落地优先级（待办清单）

**P0（守住已达成的一致性）**
- [ ] 全仓禁止 UI/Riverpod 层出现 `siteId`/`engine` 散点特判，一律走 `contracts` 能力声明。
- [ ] 把 `PureLiveServices.boot` 的"有序 + 逆序关闭 + 无单例"写入 PR 检查清单，防止退化。

**P1（补韧性/生命周期，对齐 FlowZ）**
- [ ] 播放会话 + 弹幕 socket 接入**应用级生命周期**（挂起/恢复/退出）的确定性回收与看门狗。
- [ ] 订阅/规则资源/IPTV 源的**退避刷新调度器**（失败不打断当前会话、按稳定身份对账保用户数据）。
- [ ] 偏好/库落盘的**原子写 + 失败回滚**；诊断信息**去敏导出**统一封装。

**P2（UI 覆盖度与门禁）**
- [ ] 六设计语言**组件覆盖度对齐表**，缺口有回退实现且语义一致。
- [ ] `live_uikit` **TV 焦点/遥控器基础**（focus/input）作为一等能力完善。
- [ ] CI：`melos gen` 产物 drift 校验 + 多平台 `build` 矩阵 + `format/analyze/kareki` 设为 required。

---

## 6. 明确不做的事（延续项目原则）

- 不做通用全媒体平台，不引入音乐/无关点播业务。
- 不为跨平台牺牲 TV 遥控器体验；不把 TV 页面放大成桌面布局。
- 不新增测试与 Demo 交付模块；质量以**非测试机械门禁**保障。
- 不重复实现已有基础设施（`live_*` 基础包、`pagination_core`、Riverpod/存储层已定型的部分）。
- 不为凑模块数量而拆分空壳 Package；`shared_*`/`integrations/*` 仅在确有稳定共享能力时才启用。
- 代码注释保持英文（与既有包源码一致）。

---

## 7. 一句话总纲

> **同一套直播业务，多种设计语言，多种设备形态；变更默认不断流、能力以权威引擎为准、
> 退出零残留、装配显式有序、刷新自带韧性——把 FlowZ 验证过的系统工程纪律，
> 落进 PureLive 的 Flutter 工程体系。**
