# PureLive 实现设计指南：逻辑编排 · UI 体系 · 平台兼容

> 本文档基于 `packages/` 与 `apps/pure_live` 的**现有真实代码**撰写，回答三个问题：
> **① 业务与播放/互动逻辑怎么编排；② 一套多设计语言的 UI 怎么设计；③ 各平台形态怎么兼容。**
> 设计理念的动机参照 FlowZ（`C:\Users\XA-158\Downloads\FlowZ-main`：服务化、能力即权威、
> 改配置不断流、显式声明优于推断），但本文只讲**落地实现**，不讲口号。
>
> 与其他文档分工：宏观模块职责见 [`pure_live_architecture.md`](./pure_live_architecture.md)；
> 状态管理见 [`riverpod-state-architecture.md`](./riverpod-state-architecture.md)；存储见
> [`storage-architecture.md`](./storage-architecture.md)；分页见
> [`pagination-architecture.md`](./pagination-architecture.md)。本文聚焦三者**接缝的具体实现**。

---

# 第一部分：逻辑编排（Logic Orchestration）

## 1.1 纵向分层与数据流

```
        apps/pure_live  ── 组合根(PureLiveServices) + Riverpod Provider + 页面/Shell
                │  向下只依赖：业务包 + live_uikit
   ┌────────────┼────────────────────────────┐
   │            │                            │
live_playback  live_interaction          live_library / live_iptv  (编排/内容层)
   │  依赖 LiveSite 契约 + PlaybackEngine seam
   ▼
live_sites ──────────────────────────────────────────── (领域/协议权威层)
   │  依赖 live_net(Dio) / live_platform(事实)
   ▼
live_playback.engine →(app 实现)→ media_core PlayerKernel  (渲染/内核)

横切基础设施：live_net(HTTP) · live_log(日志) · live_storage(Hive) · live_platform(平台) · live_pagination(分页)
```

**编排铁律**（现状已达成）：
- 领域层 `live_sites` **不依赖** 任何上层；`live_playback`/`live_interaction` 只**消费** `live_sites` 的契约与公共模型，不反向依赖。
- 每个包只放一个 `lib/<pkg>.dart` 公共入口，内部实现留 `src/`；跨包**禁止 import 内部路径**、**禁止循环依赖**。
- 所有业务包**纯 Dart、不含 Widget**（`live_sites`/`live_playback`/`live_interaction`/`live_library` 均无 flutter/widgets 依赖），UI 只在 `live_uikit` + `apps`。

## 1.2 领域契约层：能力 = 接口，不是布尔 flag

核心契约 [`LiveSite`](file:///d:/flutter/pure_live/packages/live_sites/lib/src/contracts/live_site/live_site.dart)：

```dart
abstract interface class LiveSite {
  String get id;
  SiteMetadata get metadata;
  Future<LivePage<LiveRoom>> getRecommendRooms({int page});
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page});
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page});
  Future<LiveRoom> getRoomDetail(LiveRoom room);        // 身份保留、稀疏字段不清空
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room);
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality); // 自描述线路:URL+headers+lease
  Future<LiveRoom> refreshLiveStatus(LiveRoom room);    // 关注列表轻量刷新
}
```

**三条编排设计**（可直接照此扩新站点）：

1. **房间级操作传 `LiveRoom` 本身**：room 已带 `platform`/`roomId`/运行时上下文，调用方不再到处传 `(platform, roomId)` 二元组。目录/搜索这类"还没有房间"的操作保留专门的查询入参——**绝不为了统一形状而塞一个空壳 `LiveRoom`**。
2. **能力用标记接口 + `is` 探测**（[`site_capability.dart`](file:///d:/flutter/pure_live/packages/live_sites/lib/src/contracts/site_capability/site_capability.dart)）：
   ```dart
   site is LiveDanmakuCapability   // 能开弹幕会话
   site is LiveDirectoryCapability // 目录方法返回真实数据
   site is LiveSearchCapability    // searchRooms 可用
   ```
   协议连不上房间的站点**就是不实现该接口**——没有布尔 flag、没有"返回 null 的方法"。未迁移的目录/搜索方法抛 `UnimplementedError`，**只有实现好了才 `implements` 该标记接口**，页面在入口一次性探测，而不是运行中 catch 异常才发现。
3. **统一守卫 `SiteRoomGuard`**：每个适配器在房间级操作首行调用 `guardRoom`，跨平台房间直接抛 `SitePlatformMismatchError`，而不是给一个莫名其妙的网络错误。

> FlowZ 对照：这就是"核心即权威"的领域版——能力由权威声明，上层永不臆测。

**目录编排收口**：`LiveSiteDirectory.browse(DirectoryQuery)` 扩展把 recommend/category/search 的分支**集中在一个 sealed-query switch**（`RecommendQuery`/`CategoryQuery`/`SearchQuery`），而非散落在每个视图里。

## 1.3 播放编排：Session 状态机 + 恢复阶梯

`live_playback` **只编排、不实现播放器**。`PlaybackEngine`（[`playback_engine.dart`](file:///d:/flutter/pure_live/packages/live_playback/lib/src/engine/playback_engine.dart)）是 app 绑定 `media_core` 的 **seam**：会话面向接口驱动引擎，引擎把原生错误翻成 `PlaybackEngineEvent`（`EngineReady`/`EngineStopped`/`EngineProgress`），**`open` 永不抛异常，失败一律走 `EngineStopped`**。

[`PlaybackSession`](file:///d:/flutter/pure_live/packages/live_playback/lib/src/session/playback_session.dart) 的相位机与恢复阶梯：

```
start() → resolving →(取 qualities/lines)→ opening → playing ⇄ paused
                         ▲                    │(EngineStopped / lease 到期 / 抛错)
                         │                    ▼
                     recovering ← _advanceLadder(分类后的 PlaybackFailure)
                         │ 超出 maxRecoveryAttempts 或不可重试
                         ▼
                       ended (give up)
```

**恢复阶梯（recovery ladder）——编排的核心**（`_advanceLadder`）：
```
同线路重开 → 同画质下一条线路 → 下一条画质 → 强制刷新 getPlayUrls(重解析) → 放弃
```
- **失败先分类再决策**：`_classify` 把 `SiteError`/引擎错误映射成 `PlaybackFailure`。`isRetryable==false`（如 `needsLogin`、`notLive`）**直接跳过整条阶梯**，不做无谓重连。
- **租约续期即一次恢复**：`LeaseScheduler` 到点触发 `_onLeaseDue`，走同一阶梯（刷新会带回新 URL）——直播地址过期被统一纳入阶梯，而非特判。
- **去抖/防重入**：`_opening` 标志避免并发 open；`_state.isBusy` 时 `start()` 幂等返回。

[`PlaybackCoordinator`](file:///d:/flutter/pure_live/packages/live_playback/lib/src/coordinator/playback_coordinator.dart)：多窗口（一窗一会话）编排 + **单一音频所有权**。新会话默认 `claimAudio`，前一个音频主人降级为静音/停止（由调用策略决定）；会话 ended 自动释放所有权。画质/线路排序策略集中在 [`QualitySelector`](file:///d:/flutter/pure_live/packages/live_playback/lib/src/session/quality_selector.dart)，可注入替换。

## 1.4 互动（弹幕）编排：解析归站点、会话归互动

`live_interaction`（[`live_interaction.dart`](file:///d:/flutter/pure_live/packages/live_interaction/lib/live_interaction.dart)）**纯 Dart、永不解析平台协议**。协议解码由 `live_sites` 完成并映射成公共流模型（`LiveMessage`/`LiveGift`/`LiveAudienceUpdate`）。

```
LiveSite(danmaku capability)  →  LiveDanmakuSession(messages: Stream<LiveMessage>)
        │ 适配成 InteractionSource
        ▼
InteractionSession ──合并同一房间的多个 InteractionSource
   ├─ MessageGate        // 去重 + 重连门(重连后的历史消息不重复渲染)
   ├─ MessageFilter 链   // 内容过滤，可插拔
   └─ AudienceTracker    // 观众数读数统一化
        │ 带退避重连协调多源生命周期
        ▼
     UI 只消费规整后的消息流与互动状态
```

**编排要点**：传输/重连/心跳是"站点适配器的事"，渲染是"UI 的事"，`InteractionSession` 居中做**多源合并、去重、门控、退避重连**——这样将来"弹幕 + 醒目留言 + 礼物"多来源接入时，UI 侧代码不变。

## 1.5 组合根编排：有序装配 + 逆序关闭

[`PureLiveServices.boot`](file:///d:/flutter/pure_live/apps/pure_live/lib/src/services.dart) 是全应用唯一装配点，**顺序即语义**：

```
平台事实(runtime) → 日志(log，先于网络，故障才有地方落) → 存储(storage) → 偏好(preferences)
   → 内容库(library/history/iptv) → 网络(http) → 站点注册表(sites)
```
- **无全局单例**：图由组合根持有并显式下传，第二个实例（测试脚手架、第二扇窗）不会偷偷共享。
- **逆序 `shutdown()`**：preferences→library→history→iptv→storage，落盘与关闭在进程退出前完成（呼应"退出零残留"）。
- `SiteRegistry(factories: defaultSiteFactories(...))` 按 id 装配所有平台适配器；IPTV 作为"读频道库而非读平台"的一个 site 平等接入。

## 1.6 状态层（Riverpod）与编排的边界

服务图是**长生命周期、命令式**对象（会话、连接、注册表）；Riverpod Provider 负责把 `SiteRegistry`、`FollowRepository`、当前 `PlaybackSession` 等**以可组合、可失效的响应式方式**喂给页面。约束（详见 `riverpod-state-architecture.md`）：Provider 只**引用/编排服务**，不持有协议逻辑；主题/偏好变化只重建派生状态 Provider，**绝不重建播放会话或弹幕连接**。

---

# 第二部分：UI 体系设计（live_uikit）

## 2.1 五层骨架

`live_uikit`（[barrel](file:///d:/flutter/pure_live/packages/live_uikit/lib/live_uikit.dart)）不是"六套 UI 库的封装壳"，而是：

```
tokens(设计令牌) → theme(主题解析) → components/contracts(Spec 契约)
   → design_languages/{6 种实现} → layouts + focus + input + backgrounds
```
业务页面**只依赖本包的公共契约**，永不直接 import Material/Fluent/…库；"用哪种语言渲染"是这里解析的**用户偏好**，不是页面里的平台判断。

## 2.2 设计令牌（tokens/）

`colors/typography/spacing/sizing/radii/elevation/motion/breakpoints/focus_tokens` 表达**语义**（`surface`、`surfaceElevated`、`primary`、`focus`、`textSecondary`…），页面不写死数值。六种语言把同一语义映射到不同具体值。

## 2.3 主题解析：配置 + 注册表 + 回退上报

- 输入 [`LiveUiConfiguration`](file:///d:/flutter/pure_live/packages/live_uikit/lib/src/core/ui_configuration.dart)：`designLanguage` + `brightness(light/dark/system)` + `accentColor` + `pureBlack`。
- [`LiveComponentRegistry`](file:///d:/flutter/pure_live/packages/live_uikit/lib/src/core/ui_component_registry.dart)：**显式且完备**注册，Material 是**回退语言**（所有未实现组件的最终兜底）。每个语言是一个 `LiveDesignLanguageAdapter{ theme: LiveThemeBuilder, components: LiveDesignLanguageComponents }`。
- 用户存的 `designLanguageId` 若在当前构建未注册（新草稿文档 / 该平台没编进某语言）：**回退到 Material 并在 `LiveTheme.fallbacks` 里说明**——"静默渲染成另一种语言"是没人会报的 bug，必须可见。

## 2.4 组件契约 = 一份 Spec 接口 + 六种实现（核心）

[`LiveDesignLanguageComponents`](file:///d:/flutter/pure_live/packages/live_uikit/lib/src/components/contracts/live_design_language_components.dart)：

```dart
abstract interface class LiveDesignLanguageComponents {
  Widget button(BuildContext, LiveButtonSpec);
  Widget textField(BuildContext, LiveTextFieldSpec);
  Widget card(...); Widget menu(...); Future<T?> dialog<T>(...);
  Widget progressIndicator(...); Widget loadingView(...); Widget errorView(...); Widget emptyView(...);
  // 随契约增长：navigation / tabs / lists / TV 布局（与 components/ 目录同序扩展）
}
```

**渲染链**（以 [`LiveButton`](file:///d:/flutter/pure_live/packages/live_uikit/lib/src/components/buttons/live_button.dart) 为例）：
```
业务页: LiveButton(label, variant, size, onPressed, focusNode)
   → 归一化成 LiveButtonSpec (语义: 主/次/危险, 启用/加载, 最小可交互尺寸, TV 焦点)
   → LiveTheme.of(context).registry.adapterFor(activeLanguage).components.button(context, spec)
   → MaterialComponents / FluentComponents / ... 各自画
```
**两条硬约束**：① **页面永不 `switch(designLanguage)` 写六套分支**；② **语言实现只见 spec/string/callback，永不见业务类型**（`LiveRoom` 等）。这就是"一份业务、多种皮肤"能成立的机制。

## 2.5 一页面 · 多形态外壳（跨端复用关键）

[`AppShell`](file:///d:/flutter/pure_live/apps/pure_live/lib/src/ui/app_shell.dart) 按 `layoutMode` 只换 **chrome**，页面实例三形态完全相同：

| layoutMode | chrome | 导航 |
| --- | --- | --- |
| mobile | `Column`：内容在上、底部 `navBarHeight` 条 | 底部 Tab |
| desktop | `Row`：左侧 `railWidth` 侧栏 + 内容 | NavigationRail |
| tv | `Column`：焦点驱动的顶部 `LiveButton` 行 + 全幅内容 | Top nav |

> 注释原话："只移动 chrome、页面本身三形态一致——这正是让一个功能不出现两份实现的原因。"
> 外壳还统一包裹 TV 必需的两件基础设施：`LiveRemoteInput`（遥控器动作作用域，menu 键跳设置）与 `LiveFocusRestorer`（返回页面落在离开的项上）。

## 2.6 背景系统与性能降级

`backgrounds/`（`LiveBackground`/`background_style`/`background_presets`）统一纯色/渐变/图片/半透明/毛玻璃/Neumorphic/页面级/TV 大屏背景。是否允许 blur 由环境的 `supportsBlur` 决定（见 3.4）——低端机与 TV 关闭最贵 backdrop 滤镜。

## 2.7 扩展流程

- **新增一种设计语言**：实现 `LiveDesignLanguageComponents` + `LiveThemeBuilder`，组一个 `LiveDesignLanguageAdapter`，在组合根 `registry().withLanguage(...)` 注册；缺的组件自动回退 Material。
- **新增一类组件**：给 `LiveDesignLanguageComponents` 加一个 `xxx(LiveXxxSpec)`，先只在需要的语言实现、其余回退；公共 Widget 负责把参数归一化成 Spec。
- **Wind UI**：`integration/wind_integration.dart` 作为**某语言的内部实现来源**（不设为第七种语言），语义不合就加适配层，不为迁就它改动整个契约。

---

# 第三部分：平台兼容（各形态如何统一）

## 3.1 正交四轴——严禁 `Platform.isX` 进页面

设计把"设备"拆成互不混用的维度（[`ui_environment.dart`](file:///d:/flutter/pure_live/packages/live_uikit/lib/src/core/ui_environment.dart)）：

```
LiveUiPlatform   运行平台: android / ios / androidTv / windows / macos / linux / web
LiveDesignLanguage 视觉语言: material / cupertino / fluent / macos / yaru / neumorphic
LiveInputMode    输入设备集合: touch / mouse / keyboard / remote
LiveLayoutMode   布局形态: mobile / desktop / tv
PlatformCapabilities 能力: windowing / systemTray / pictureInPicture / mediaSession / filePicker
```
例：Windows 可跑 Fluent 也可跑 Material；Android TV = android 平台 + `FormFactor.tv` + remote 输入 + tv 布局。`LiveUiEnvironment` **是数据不是行为**：没有任何 widget 去看 `Platform.isX`，也没有页面自行断定"我是不是 TV"。

## 3.2 平台事实的来源链

```
live_platform                     apps/pure_live                      live_uikit
PlatformKind ──┐                                                 LiveUiPlatform
FormFactor ────┤   UiConfigurationMapper (组合根，单向)          LiveUiEnvironment
Capabilities ──┘   (live/src/ui/ui_configuration.dart)   ───►   LiveUiConfiguration
                 platformOf / environmentOf / configurationOf   LiveComponentRegistry
```
[`UiConfigurationMapper`](file:///d:/flutter/pure_live/apps/pure_live/lib/src/ui/ui_configuration.dart) 是**唯一**把"平台事实 + 用户偏好"翻成"UI 类型"的地方，单向、集中一个文件：`live_preferences` 只存裸值(语言 id/枚举/accent int)不知设计语言为何物；`live_uikit` 只渲染不知偏好文档为何物。

## 3.3 布局兼容：宽度 + 平台共同决定，窄窗即移动形态

```dart
LiveLayoutMode.resolve(platform, width):
  if platform.isTv → tv
  if desktop|web  → width < breakpoints.desktop ? mobile : desktop
  else            → width < breakpoints.tablet  ? mobile : desktop
```
即"桌面窗口拖窄真的会变 mobile 布局"，而不是按平台一刀切。`LiveLayoutBuilder` 在每帧按实时窗口宽 `withWidth()` 重算。

## 3.4 输入与能力兼容：保守默认 + 显式加宽

- **输入**：`platform.defaultInputModes`（android={touch,keyboard}、ios={touch}、androidTv={remote}、桌面/web={mouse,keyboard}）是起点；组合根拿到真实设备信息后可 `withInputModes()` 加宽（带触屏的桌面、配蓝牙键盘的手机）。`needsFocusNavigation = tv || 无 touch`——凡无触摸就必须可焦点导航。
- **能力**（[`PlatformCapabilities`](file:///d:/flutter/pure_live/packages/live_platform/lib/src/runtime/platform_capabilities.dart)）：`defaults` **保守**——unknown 平台 `none`(全 false)；TV 无 windowing/tray；PiP 仅非 TV 安卓。app shell 用 `copyWith` 覆盖它更知的项（如 window_manager 初始化成功后再置 `systemTray=true`）。UI 据能力开关功能面，而非崩溃或给坏按钮。

## 3.5 TV 专项：声明而非推断 + 差异化默认

- **形态来源**：`declaredTvBuild`（launcher flag / 原生桥 / `--dart-define`）→ `FormFactor.tv`。**永不**从 `Platform.isAndroid` 猜——手机误判成 TV 会给出没人能用遥控器操作的界面。
- **默认语言**：`defaultDesignLanguageFor` 给每平台贴合的初始语言（ios→cupertino、macos→macos、windows→fluent、linux→yaru、android/tv/web→material）；**TV 恒 Material**（其他语言的焦点模型不符合遥控器预期）。
- **性能**：TV 构建 `supportsBlur` 默认 false（backdrop 是 TV 上最贵的效果）。
- **交互基建**：`focus/`（`LiveFocusScope`/`LiveFocusHighlight`/`LiveFocusRestorer`/`LiveFocusNavigation`）+ `input/`（`LiveRemoteInput`/`LiveRemoteActions`）是 TV 一等能力，D-pad/确认/返回/焦点记忆统一在此，页面各不自造一套。

## 3.6 平台差异矩阵（速查）

| 维度 | Mobile | Desktop | TV | Web |
| --- | --- | --- | --- | --- |
| 布局 | mobile | desktop(窄窗→mobile) | tv | desktop(窄窗→mobile) |
| 导航 chrome | 底部栏 | 侧栏 Rail | 顶部焦点行 | 侧栏/自适应 |
| 输入 | touch(+键盘) | mouse+keyboard | remote | mouse+keyboard |
| blur/动画 | 视机型 | 开 | blur 关 | 视情形 |
| 焦点基建 | 弱需 | 键盘 | 强需(必须) | 键盘 |
| 默认语言 | material/cupertino | fluent/macos/yaru… | material | material |

## 3.7 新增一个平台的接入步骤

1. `live_platform`：`PlatformKind` 增项 + `PlatformCapabilities.defaults` 给保守默认。
2. `UiConfigurationMapper.platformOf` 增映射 + `defaultDesignLanguageFor` 给默认语言。
3. 组合根 boot 里解析该平台目录/形态；如该形态无触摸，确认 `needsFocusNavigation` 生效。
4. UI 侧通常**零改动**（页面与语言无关，chrome 按 layoutMode 选）。

---

# 第四部分：端到端一次调用（三层如何咬合）

**场景：用户在某平台点进房间并播放（桌面 Fluent 主题）**

```
DiscoverPage(Riverpod watch SiteRegistry + provider 出 LiveRoom)
  → 导航进 RoomPage
     ├─ 平台兼容: LiveUiEnvironment(platform=windows, layout=desktop, input={mouse,keyboard}, blur=on)
     │            registry.adapterFor(fluent) 渲染 chrome；页面只调 LiveButton/LiveCard 契约
     ├─ 播放编排: provider 用 services.sites.of(room.platform) 拿 LiveSite
     │            PlaybackCoordinator.open(room, site) → PlaybackSession.start()
     │              resolving→getPlayQualities→getPlayUrls(带 lease)→engine.open→playing
     │              失败→_classify→恢复阶梯; lease 到期→自动刷新; app 实现 engine seam → media_core
     └─ 互动编排: site is LiveDanmakuCapability ? connect(room) 包成 InteractionSource
                  → InteractionSession(MessageGate 去重/重连门 + MessageFilter) → 弹幕覆盖层消费
切主题/切画质(软变更): 只重解析 LiveTheme / selector 热切, 会话与弹幕连接不重建
退出/切后台: coordinator.disposeAll + session.dispose(引擎/订阅/租约) + services.shutdown 逆序落盘
```

三层咬合关系：**平台层给"在哪跑"的事实 → UI 层据此选形态与语言渲染统一契约 → 编排层用能力探测驱动的会话/恢复/合并**，三者通过组合根与契约单向连接，互不越界。

---

# 第五部分：现状与待补

**已达成（可直接依赖的骨架）**：LiveSite 契约+能力接口+注册表(34 站点)、PlaybackSession 恢复阶梯/Coordinator 音频所有权/Engine seam/Lease、Interaction 会话管线、live_uikit 令牌+Spec 契约+注册表回退+六语言目录、AppShell 三形态、平台四轴与能力矩阵、组合根有序装配与逆序关闭。

**待补（建议下阶段落实）**：
- 播放侧"软变更去抖合并"与画质/线路热切的优雅断流开关（对齐 `live_playback/coordinator`）。
- `live_interaction` 的多源合并/退避重连随真实第二来源（礼物/醒目留言）落地。
- 弹幕 socket 与播放会话接入**应用级生命周期**（挂起/恢复/退出）的确定性回收。
- `live_sites` 中尚缺目录/搜索能力的站点按标记接口逐个补齐（探测点已就位）。
- 各设计语言的**组件覆盖度对齐表**，缺口回退 Material 并记 `fallbacks`。
- TV `focus/`+`input/` 基建在直播列表、播放控制栏、搜索软键盘上贯通。

> 代码注释保持英文；不新增测试/Demo 模块；能力以契约与 `is` 探测表达，页面永不做平台或站点散点特判。
