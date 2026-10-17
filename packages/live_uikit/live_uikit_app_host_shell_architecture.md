# `live_uikit` App Host 与 App Shell 架构设计

- **Package:** `live_uikit`
- **Application:** PureLive 4.x (`apps/pure_live`)
- **Document type:** Architecture / Integration Decision
- **Status:** Accepted — implemented; 文中 Shared 兜底层已于 2026-10-17 删除（见修订说明）
- **Scope:** App Host dispatch、App Shell renderer、Theme scope、Router、Overlay、Material compatibility boundary、adapter diagnostics
- **Platforms:** Android、iOS、Android TV、Windows、macOS、Linux

## 修订说明（2026-10-17）

> 本文件是**已实现的设计提案**，其主体分层（App Host / App Shell / Component 三种能力各自宣告、
> 各自解析，Host 由语言自己管，Shell 吃中立规格，Router 实例保持稳定）**照原样落地了**。
> 但提案里那层「没有原生能力就用 Shared Token Host / Shared Token Shell 兜底」的设计，
> 在 2026-10-17 被整体删除。以下段落是历史，不是现行规则：§1.3 目标里的「没有原生 Shell 的
> Adapter 则使用 Token-driven Shared Shell」、§4 架构图里的 `Shared Token Host/Shell`、
> §5 的 Shared 预设实作、§6.2 的 Host 选择表、§7.3/§7.4、**整个 §8**、§11 的降级矩阵、
> Phase 3「先实作 Shared Token Shell」与 §14.1/§14.2 的 fallback 验收项。
>
> 现行规则：
>
> - `LiveUiControl` 十七个成员（`dialog`、`tabView` 已入契约），`LiveUiSurface` 两个成员
>   （`appHost`、`appShell`），`LiveUiSurfaceCapabilities` 独立宣告 —— 拥有 Host 不蕴涵拥有 Shell。
> - 八家适配器各 `implements LanguageAdapter`，**十七控件 + 两面全部自己答**：库有对应件就映射，
>   没有就用该库自己的零件按该库视觉拼（forui/glass/neumorphic/wind 的 Host 是 `WidgetsApp` + 本库主题
>   scope，仍是该语言的答案，不是别人的窗口；macOS 的 Shell 自绘固定宽侧栏 + `SidebarItems`）。
> - `LanguageRegistry` 没有 `fallback` 槽，`SharedLanguageAdapter` / `Token*` / `LiveUiFallbackPolicy` /
>   `LiveImplementationKind` / `LiveTheme.implementationKind` / `LiveDesignLanguage.token` 均已删除，
>   §7.4 提出的「`shellSharedFallback`」这类降级诊断码也不存在：未注册语言抛
>   `LiveUiResolutionException`，声明与覆写漂移抛 `LiveUiCapabilityException`。
> - 诊断只剩 `unsupportedEffect`（设备做不到的效果），去重单位仍是「语言变更」而非 rebuild —— 这条
>   提案判断正确，保留。
> - 验收：八语言真机批跑全部 `host=appHost shell=appShell`，0 诊断 0 异常。


---

## 1. 背景与问题定义

PureLive 已经有 `live_uikit`，负责 Design Token、`LiveTheme`、`LanguageAdapter`、各类 `Live*` controls、共享 Token Renderer，以及依目前 `LiveDesignLanguage` 选择 adapter 的 Runtime Dispatch。

目前 App 根元件采用下列模式：

```dart
return LiveApp(
  routerConfig: ref.watch(routerProvider),
  onGenerateTitle: (context) => t.app.title,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: appSupportedLocales,
  locale: appFlutterLocale,
  builder: (context, child) => TranslationProvider(child: child!),
);
```

`LiveApp` 接着呼叫：

```dart
LiveTheme.of(context).adapter.host(
  context,
  LanguageHostSpec(...),
)
```

目前的问题不是单一元件有没有换皮，而是「切换设计语言」的责任尚未完整分层：

1. **App Host**：决定使用哪一种根应用元件，以及 Router、Navigator、Overlay、本地化、视窗层级预设行为由谁提供。
2. **App Shell**：决定页面外壳如何呈现，例如顶部标题列、侧边栏、底部导览、Navigation Rail、分栏、TV 焦点导览与视窗内容框架。
3. **Component Renderer**：决定 `LiveButton`、`LiveCard`、`LiveTextField` 等单一控制项如何绘制。

现有架构对 App Host 已有 `LanguageAdapter.host()` 与 `LanguageHostSpec` 的概念，也有十种控制项的分派契约；但从目前提供的介面来看，App Shell 没有独立、完整的中立契约。因此，即使根 Host 确实改成 Fluent 或 macOS 的 App 元件，使用 Material `Scaffold`、`AppBar`、`NavigationRail` 等组成的 Shell 仍会保持 Material 外观。

此外，`LiveApp._inkHost()` 无条件把整个路由子树包在 `Material(type: MaterialType.transparency)` 中，使 Material 相容层成为全域预设，而不是有边界的相容措施。

## 2. 设计目标

本设计需要达成以下目标：

- 切换设计语言时，App Host 依目前注册的 Adapter 正确分派。
- App Shell 亦有中立 API；原生 Adapter 可以用自己的元件库绘制，没有原生 Shell 的 Adapter 则使用 Token-driven Shared Shell。
- Feature page 不直接依赖 Fluent、macOS、Material、Cupertino 或其他具体 UI 套件。
- `live_uikit` Core 不依赖任何 `live_uikit_<style>` Adapter，也不依赖第三方 UI library。
- Material 相容处理采明确、局部、可逐步移除的边界，不在整个路由子树上强制加 `Material`。
- App Host、App Shell 或个别控制项降级时，都能透过 App 提供的诊断接线得知原因。
- 不因新增 Shell 能力而把 Shell 混入现有的 `LiveUiControl` 十个控制项成员。
- 调整设计语言时保留可行的 Router 状态与目前路由；允许关闭不再适用的暂态 Overlay，并明确测试 Host 切换行为。

## 3. 非目标

本设计不负责：

- 决定使用者预设的设计语言、主题偏好或偏好设定的储存格式。
- 在 `live_uikit` Core 中实作应用程式的业务导航、直播、媒体库或播放页面。
- 让任意第三方 Widget 自动变成与目前 Adapter 一致的外观。
- 保证所有设计语言都具备完全相同的原生能力。无法一对一映射的行为必须记录为不支援或使用共享实作。
- 将 `MaterialApp` 的存在本身视为视觉错误。真正的验收目标是可见 Shell 和控制项不再被 Material 外观绑定；没有原生 App Host 的风格可以使用 Flutter SDK 的基础 Host，而非必须假装成某个原生设计语言。

## 4. 核心决策

### 4.1 将 UI Runtime 分成三个不同的扩充面

```text
PureLive App Composition Root
│
├── UI configuration / preference state
├── LanguageRegistry + LiveUiResolver
├── platform capability inputs
└── LiveUiDiagnosticSink
        │
        ▼
LiveConfigProvider / LiveTheme
        │
        ├── 1. App Host dispatch
        │      └── Native host OR token/framework host
        │
        ├── 2. App Shell dispatch
        │      └── Native shell OR Shared Token Shell
        │
        └── 3. Component dispatch
               └── Native control OR Token renderer
```

三个扩充面相互合作，但不可混为一个概念：

- **Host** 是 App 级根元件。
- **Shell** 是应用程式页面的结构与导览外壳。
- **Component** 是按钮、表单、卡片等单一控制项。

Adapter 可以同时提供其中一项或多项原生实作，不能因为有原生 Button，就推论它也有原生 Shell 或原生 App Host。

### 4.2 没有原生 App Host 的风格，不应预设使用 Material 外壳

目前 `TokenApp` 使用 `MaterialApp.router`。这让 ForUI、Glass、Neumorphic、Wind 等没有自己 App widget 的风格，在根 Host 层仍依赖 Material App 的主题与预设行为。

建议把没有原生 App Host 的预设实作改成**框架级 Token Host**：优先评估以 Flutter SDK 的 `WidgetsApp.router` 提供 Router、本地化和基本 App 环境，由 `LiveTheme`、Shared Shell 与 Token Renderer 负责可见 UI。

只有在某个确实需要 Material 内部机制的旧页面或旧控制项中，才使用局部 Material compatibility boundary。不要因为一个页面需要 `Material`，就把整个 App 路由子树包起来。

注意：切换为 `WidgetsApp.router` 前，必须确认共享 Renderer 的实际实作、Popup/Tooltip、焦点与文字选取行为、本地化 Delegate，以及各平台的 Back/Router 行为。这是迁移任务，不应只把 `MaterialApp.router` 搜寻取代成 `WidgetsApp.router`。

### 4.3 App Shell 是独立契约，不是 Host 的副作用

新增中立的 Shell 规格与元件入口。功能页或 Routing 层组合 Shell 时，只传递语意资料；由目前 Adapter 决定用哪套元件绘制。

建议的公开概念名称：

- `LiveAppShell`：App-facing 的中立 Shell 元件。
- `LanguageShellSpec`：跨 Adapter 的 Shell 规格。
- `LiveShellDestination`：中立导览目的地模型。
- `LanguageAdapter.shell(...)` 或等价的 Shell renderer 入口。
- Shared Token Shell：所有 Adapter 都有可工作的预设实作。

以上为建议的 API 名称；实际命名可依目前 `styling.dart` 公开 API 惯例调整，但不得让 Feature page 直接依赖具体 UI library。

## 5. 职责与依赖边界

### 5.1 `live_uikit` Core

Core 拥有：

- Host 与 Shell 的中立规格。
- `LiveApp` 等 App-facing dispatch widget。
- Shared Token Host / Shared Token Shell 的预设实作。
- `LanguageAdapter` 所需的 Host、Shell 与 Component contract。
- 对降级行为的诊断型别与决策结果。
- Theme、Token、Environment 和通用元件。

Core 不拥有：

- 具体 Adapter 的 package dependency。
- 使用者偏好设定的读写。
- 业务路由表、应用程式导航项目清单或特定 Feature。
- 应用层的 Logger 实作。

### 5.2 各 `live_uikit_<style>` Adapter

Adapter 拥有：

- 它真正支援的 App Host 实作。
- 它真正支援的 Shell renderer。
- 各种原生 Component renderer。
- 把 `LanguageHostSpec`、`LanguageShellSpec` 与 Component Spec 映射到该 UI library 的逻辑。
- Adapter 自身能力宣告与 contract tests。

Adapter 不得：

- 依赖另一个 Adapter。
- 反向让 Core 引用自己。
- 对未支援的语意静默产生看似等价、实际不同的行为。

### 5.3 `apps/pure_live`

App Composition Root 是唯一允许组合所有实际 Adapter 的地方，负责：

- 将已安装的 Adapter 注册到 `LanguageRegistry`。
- 建立 `LiveUiResolver` 与 Shared fallback。
- 还原及保存 `UiConfig`。
- 将 `LiveUiDiagnosticSink` 接到 `live_log`。
- 将平台形态、TV 模式与硬体能力提供给 UI Runtime。
- 提供 App 的导览目的地、显示文字、图示与导航回呼。

App 其他 feature 不能因为 App Composition Root 可以依赖 Adapter，就自行 import Adapter 或其底层 UI library。

## 6. Host contract 设计

### 6.1 Host 的责任

Host 应建立与目前设计语言相符的 App 根元件，并接收一致的应用级资料：

- `routerConfig`
- `title` / `onGenerateTitle`
- `localizationsDelegates`
- `supportedLocales`
- `locale`
- `builder`
- `debugShowCheckedModeBanner`
- 必要的 App 级行为与主题映射

Host 不应负责建立业务导览项目，也不应试图将 Material Shell 自动转成 Fluent 或 macOS Shell。

### 6.2 Host 选择规则

| 目前 Adapter 能力 | Host 决策 |
|---|---|
| 有真正的原生 App Host | 使用该 Adapter 的 Host |
| 没有原生 App Host，但 Core Shared Host 可用 | 使用 Token/framework Host |
| Adapter 未注册 | 依 `LiveUiFallbackPolicy` 使用 Shared fallback，并回报 `adapterMissing` |
| Shared Host 也不可用 | 依 fail-fast 策略抛出 `LiveUiResolutionException` |

「原生 Host」指由该 Adapter 真正管理 App 根元件，而不只是把某个 `Theme` 放入 `MaterialApp`。

### 6.3 现有 `LiveApp` 的修改要求

`LiveApp` 应继续作为 Host dispatch façade，但不得全域强制添加 Material compatibility wrapper。

目前程式：

```dart
builder: _inkHost,
```

以及：

```dart
return Material(
  type: MaterialType.transparency,
  child: wrapped,
);
```

应改为只负责串接呼叫端 builder，且正确处理 null child。概念如下：

```dart
Widget composeHostBuilder(BuildContext context, Widget? child) {
  final built = builder?.call(context, child) ?? child;
  return built ?? const SizedBox.shrink();
}
```

再把 `composeHostBuilder` 放入 `LanguageHostSpec.builder`。真正需要 Material lookup 的旧页面，应使用明确的局部相容元件，而不是所有 Host 都共用 `_inkHost`。

这个修改只移除全域 Material 包装，**不会**自动把使用 `Scaffold`、`AppBar`、Material `NavigationRail` 的旧 Shell 变成其他设计语言；那些组成元件仍需要迁移到 `LiveAppShell` 或各自的 neutral contract。

### 6.4 Host 切换与 Router 状态

不同 Host 可能是不同 Flutter Widget 类型。切换 Host 时，Navigator/Overlay 子树有可能被重建，原本的瞬时 Dialog、Popup、Tooltip 或路由动画可能结束。

要求：

- App 应在 Host 之间共用同一个已建立的 Router 实例，避免在 `build()` 中反覆建立 Router。
- 设计语言切换后，期望 URL/route location 与可恢复的导航状态维持一致。
- 不要求保留旧 Host 的暂态 Overlay；切换时应可安全关闭它们。
- 必须以整合测试验证实际 Router 套件下的状态行为，不可只依赖理论假设。
- 若实作使用 Host key，key 应按 Host/Adapter 身分设计，并测试它不会意外重设应用路由状态。

## 7. App Shell contract 设计

### 7.1 Shell 的责任

Shell 是 Feature page 之上的应用版面结构，可能包含：

- App title / page title
- 导览目的地与目前选取项目
- 顶部工具列与全域操作
- 侧边导览、Navigation Rail、底部导览或 TV 导览列
- 主内容槽位
- 可选的次要栏或 Inspector 槽位
- 响应式版面、视窗缩放与 TV 10-foot 几何
- 键盘与遥控器焦点顺序

Shell 不负责：

- 实际建立/解析应用路由。
- 决定目的地对应哪个业务功能。
- 将 `routerConfig` 藏在某一个 Adapter 中。
- 另行建立一份主题系统。

### 7.2 中立规格要求

`LanguageShellSpec` 最低应能表达：

- `title` 或语意明确的页面标题资料。
- `child` 主内容。
- `destinations` 导览目的地列表。
- `selectedDestinationId`。
- `onDestinationSelected`。
- 可选的全域操作、leading slot、secondary content。
- Shell 的呈现意图，例如 `adaptive`、`navigationOnly` 或 `contentOnly`，实际 enum 名称可再决定。
- 由 `LiveEnvironment` 解析的版面模式或足以让 renderer 读取环境的上下文。

导览目的地应保存 ID、标签、可用性和图示语意，而不是把 Material `NavigationDestination`、Fluent `NavigationPaneItem` 或其他 UI library 的具体 Widget 传过 contract 边界。

若需要传入自订操作，优先设计中立的 `LiveShellActionSpec`，包含 ID、标签、图示语意、enabled 状态与 callback。不要要求 Adapter 猜测任意 Widget 要如何重新换皮。

### 7.3 `LiveAppShell` 的分派流程

概念流程：

```text
App routing / ShellRoute
        │
        ▼
LiveAppShell(neutral spec)
        │
        ▼
LiveTheme.of(context).adapter.shell(context, spec)
        │
        ├── Adapter supports native shell -> native shell renderer
        │
        └── otherwise -> Shared Token Shell + diagnostic
```

`LiveAppShell` 应放在 App 的 ShellRoute、路由层 Shell 或对应的 app composition widget 中。它不是必须包住整个 Router 的全域 `Material` wrapper，也不应在不适合的登入页、播放器全荧幕页或设定子流程中强制显示导览列。

### 7.4 Shell 能力不可混进十个 Component Control

目前 `LiveUiControl` 的十个成员是明确的元件控制项契约，不应为了 Shell 而把 `appShell` 假装成第十一个 control。

建议采独立的 surface/host 能力描述，例如 `LiveUiSurfaceCapabilities` 或等价的独立契约，用来声明：

- App Host 是原生、共享或不可用。
- App Shell 是原生、共享或不可用。

Shell 降级应有独立诊断语意，例如 `shellSharedFallback`。实际 enum 命名可以沿用现有 `LiveUiDiagnosticCode` 的规约。Provider 或 Runtime 应在能力解析时报告，不可每次 Widget rebuild 都重复报告。

## 8. Shared Token Shell 与 Token Host

### 8.1 Shared Token Shell

Shared Token Shell 是每个 Adapter 在尚未实作原生 Shell 时的工作预设。它应：

- 只使用 Core 公开 API、Flutter SDK primitives 与 resolved `DesignToken`。
- 依 `LiveEnvironment` 在手机、桌面、TV 间选择适合的版面。
- 尊重可用性、焦点、键盘操作、TV 遥控器与最小触控/遥控目标尺寸。
- 不假设 `MaterialApp`、Material `Scaffold` 或 Material `AppBar` 一定存在。
- 保留呼叫端提供的 navigation callback 与选取状态，不在 Shell 内另存一份互相竞争的状态。
- 对不适合目前版面的导航方式做明确、可预期的降级。

### 8.2 Token Host

没有原生 App Host 的 Adapter 应使用共享的 Token/framework Host。优先使用能满足 `RouterConfig`、Locale、Delegate、title 与 builder 需求的 Flutter SDK 基础 Host，例如 `WidgetsApp.router`；若实际 Flutter SDK 版本或应用所需能力无法满足，需在技术决策中列出缺口与替代方式。

Token Host 不应只是把 `MaterialApp.router` 换名为 `TokenApp`，也不应将 App Theme 写死成 `ThemeData` 后宣称完成跨语言 Host。若某些 token widget 仍依赖 Material 机制，应逐个列出依赖与相容方案，逐步移除广域依赖。

### 8.3 旧 Material Widget 的相容策略

迁移期间允许旧页面使用局部相容层，例如概念上的 `LiveMaterialCompatibility`。它只能包住尚未迁移的局部 Widget subtree，且必须清楚标记待移除范围。

禁止：

- 在 `LiveApp` 里无条件包整个 Router subtree。
- 把 Material Widget 藏在各个 Adapter 的 Shared Shell 中，让所有风格都悄悄变成 Material。
- 把使用 Material Widget 的旧页面误认为已完成跨语言支援。

## 9. Theme 与 Provider 的正确位置

`LiveApp.build()` 会执行 `LiveTheme.of(context)`，因此呼叫 `LiveApp` 时，对应的 `LiveConfigProvider` / `LiveTheme` scope 必须已经在它的祖先树中。

建议的整体结构：

```text
ProviderScope
└── App Bootstrap / UiConfig state
    └── AppTheme / LiveConfigProvider
        └── TranslationProvider (依目前 l10n 架构放置)
            └── PureLiveApp
                └── LiveApp
                    └── adapter-selected App Host
                        └── Router / Navigator
                            └── App routing Shell
                                └── LiveAppShell
                                    └── Feature page
```

如果 `TranslationProvider` 需要依靠 Host 提供的 Flutter Locale/Localizations，则可以继续放在 Host 的 `builder` 里；如果它必须在 `LiveApp` 呼叫 `LiveTheme.of` 之前就提供翻译上下文，则应放到更上层。应以 `t` 的实际初始化与 `TranslationProvider` 套件规则决定位置，不要重复建立 Provider。

`LiveConfigProvider` 应沿用既有的配置生命周期：

1. App 还原 `UiConfig`。
2. Runtime 解析目前 Adapter 与 Token。
3. `LiveApp` 取得决策后建立对应 Host。
4. Router 的 Shell 层使用 `LiveAppShell`。
5. Feature page 仅依赖 `Live*` 公开元件及中立环境 API。

## 10. 对目前程式码的具体修改

### 10.1 `PureLiveApp`

目前 `PureLiveApp` 的主要责任可以保留：提供 router、标题、本地化 delegate、locale 与 translation builder。

需要确认：

- `routerProvider` 返回稳定的 Router 实例，而不是每次 `build()` 重新建构 Router。
- `AppTheme` / `LiveConfigProvider` 位于 `PureLiveApp` 祖先层，让 `LiveApp` 能读到 `LiveTheme`。
- 所有 `localizationsDelegates`、`supportedLocales`、`locale` 在各 Host Adapter 都得到正确传递。
- Builder 不再被隐式套入整棵树的 Material 包装。

### 10.2 `LiveApp`

`LiveApp` 保持精简的 Host dispatcher。它应：

1. 透过 `LiveTheme.of(context)` 取得目前解析结果。
2. 呼叫 Adapter 的 Host contract。
3. 传入通用 `LanguageHostSpec`。
4. 只组合呼叫端 builder，不引入 Material widget。
5. 对 Host fallback 的记录交由 Runtime/诊断契约处理，而不是在 `LiveApp` 中自行判断并吞掉错误。

建议 builder 的概念实作：

```dart
Widget composeHostBuilder(BuildContext context, Widget? child) {
  final built = builder?.call(context, child) ?? child;
  return built ?? const SizedBox.shrink();
}
```

`LanguageHostSpec.builder` 使用这个无 Material 版本的 compose function。

### 10.3 `TokenApp`

目前的 `TokenApp` 使用 `MaterialApp.router`，并从 `LiveTheme` 建立 `ThemeData` 与 `ColorScheme`。这是 Material host，而不是中立 Token Host。

修改方向：

- 将它重新定义成明确的 Token/framework Host，优先评估 `WidgetsApp.router`。
- 不以 `ThemeData` 作为 token 到 App Host 的唯一输出路径。
- 让 Shared Token Shell 负责可见 App Shell，而不是依赖 Material `Scaffold`。
- 若部分共享元件需要 MaterialLocalizations 或 Material 内部依赖，记录并逐项消除或局部隔离。
- 若短期不能移除 `MaterialApp.router`，应把它记为「暂时的 Material-backed Host」，不得宣称此风格的根 Host 已与 Material 解耦；同时应确保使用中立 Token Shell，并建立移除它的迁移项目。

### 10.4 `_inkHost`

移除其作为全域 builder 的用途。透明 `Material` 仍然是 Material subtree，透明只表示不绘制不透明背景，不代表它是中立 Host。

如旧功能页真的需要 Material ancestor，应明确在该局部页面包相容元件并留下迁移注记。新的 Feature page 必须只使用 `live_uikit` 中立 API。

### 10.5 ShellRoute / App Shell

在 App routing 或 app composition 模组内实作 App-specific Shell composition：

- App 决定有哪些目的地与各目的地对应的导航 callback。
- Router 决定目前 location 与实际路由。
- `LiveAppShell` 只接收中立 Shell 规格并绘制外壳。
- Adapter 决定每个风格的导航列、侧边栏、工具列、选取态、间距与互动效果。

若路由套件支援 `ShellRoute` 或等价机制，优先在该层放置 `LiveAppShell`，避免将同一套导航硬塞进所有页面。

## 11. Adapter 能力、Fallback 与 Diagnostics

Host、Shell 与 Component 是三种不同层级的能力；Runtime 不得用某一层的能力替另一层背书。

| 情况 | 预期决策 | 诊断要求 |
|---|---|---|
| 有原生 Host、有原生 Shell | 使用原生 Host 与原生 Shell | 无 fallback 诊断 |
| 有原生 Host、没有原生 Shell | 原生 Host + Shared Token Shell | 记录 Shell fallback |
| 没有原生 Host、有原生 Shell | Token/framework Host + 原生 Shell | 记录 Host fallback |
| 有 Host/Shell，但个别 control 不支援 | 个别 control 使用 Shared renderer | 延续 `controlUnsupported` 规则 |
| Adapter 未注册 | 整体使用 Shared fallback | 延续 `adapterMissing` 规则 |
| Shared fallback 不存在 | fail-fast | 抛出 `LiveUiResolutionException` |

诊断的去重单位应依「语言或 Adapter 变更」及「解析到的 surface」定义，而不是 Widget rebuild。Host/Shell fallback 诊断与既有的十个 `LiveUiControl` 诊断分开，避免破坏 `LiveUiControl` 固定十成员的规格。

## 12. Platform 与 `LiveEnvironment`

App 由 `live_platform` 等宿主服务提供装置形态与硬体能力，再交给 `LiveConfigProvider` 和 `LiveLayoutBuilder`。Core 不应自行调用平台插件或读取 App 偏好。

需要分开处理的维度：

- **Form factor**：手机、平板、Android TV、桌面等宿主宣告的设备形态。
- **Window geometry**：实际视窗宽度、视窗尺寸变化与目前的 layout mode。
- **Input capability**：触控、键盘、滑鼠、遥控器/方向键等输入方式。
- **Visual capability**：硬体模糊、透明效果等实际能力。

TV 不应只由 Android 平台判断，也不能只由视窗宽度推断。TV 10-foot Geometry、遥控器焦点导览与较大的触控目标需要一起被测试。`controlHeightTv` 仍是 Token seed 的宿主覆写；TV 的页面 padding、导航尺寸和版面则交由 `LiveEnvironment` / `Geometry`。

## 13. 分阶段迁移计划

### Phase 1 — 确认 Host 分派

- 在 Debug 记录 Adapter ID、runtime type、`implementationKind` 与实际 Host 类型。
- 验证每个语言选项确实进入预期的 Adapter，而非静默使用 Shared fallback。
- 确认 `LiveTheme` scope 已位于 `LiveApp` 祖先层。
- 确认 Router 实例是稳定的。

### Phase 2 — 移除全域 Material wrapper

- 移除 `LiveApp._inkHost` 对整个 Router subtree 的无条件 Material 包装。
- 保留呼叫端 builder 与 `TranslationProvider` 行为。
- 为仍需要 Material 的旧页面加入局部相容层及迁移记录。
- 以测试确认 Material、Fluent、macOS、Cupertino Host 的本地化、Overlay 与焦点行为。

### Phase 3 — 建立 Shell contract 与 Shared Token Shell

- 加入中立 Shell spec、destination model 与 `LiveAppShell` dispatch。
- 把 App 的导航目的地资料留在 `apps/pure_live`。
- 先实作 Shared Token Shell，让所有语言都有可工作的 Shell fallback。
- 新增 Shell fallback capability 与 diagnostics，保持 `LiveUiControl` 十个成员不变。

### Phase 4 — 让原生 Adapter 提供 Shell

- 先挑一个目标风格实作原生 Shell，验证 API 与 layout contract。
- 逐一处理顶部工具列、侧边导航、底部导航、选取状态、焦点导航、TV 几何与响应式行为。
- 以 adapter contract tests 确认所有 Shell 栏位有明确映射或明确记录为 unmappable。

### Phase 5 — Token/framework Host

- 审查 `TokenApp` 中所有 `MaterialApp` / `ThemeData` / MaterialLocalizations 依赖。
- 验证 `WidgetsApp.router` 是否能满足目前 SDK 与 Router、本地化和 builder 需求。
- 把必要的旧 Material 依赖局部隔离并逐步移除。
- 若暂时保留 Material-backed Host，维持明确技术债记录，不把它视为最终的中立 Host。

### Phase 6 — 迁移功能页与架构守卫

- Shell 与常用基础元件先迁移。
- Feature page 仅 import `package:live_uikit/live_uikit.dart` 或规定的中立 entrypoint。
- 架构守卫允许 `apps/pure_live` 的指定 Composition Root 依赖 Adapter；其他 App feature、packages 与 Core 不得依赖 Adapter。
- CI 执行 format、analyze、unit tests、adapter contract tests 与跨 Host integration tests。

## 14. 测试与验收标准

### 14.1 Host dispatch

- 每一个已注册语言都进入预期的 Host。
- 未注册语言使用 Shared fallback 并只在适当的语言/解析变更时回报 `adapterMissing`。
- Shared Host 不可用时会 fail-fast，不会静默回退到 Material。
- 切换语言后，Router location 及可恢复的导航状态依规格保持一致。

### 14.2 Shell dispatch

- 每个 Adapter 都宣告 Shell 能力或明确使用 Shared Token Shell。
- Shared Token Shell 不依赖 `MaterialApp`、`Scaffold` 或 `AppBar` 作为必需祖先。
- 原生 Shell 能绘制目的地、选取状态、标题、操作和主内容。
- 导航状态由呼叫端持有；Shell 不会建立第二份互相竞争的选取状态。
- fallback 诊断不因 Widget rebuild 重复发送。

### 14.3 Material dependency boundary

- `LiveApp` 不再无条件对整个 Router subtree 包装 `Material`。
- 非 Material Host 中，未迁移的 Material Widget 只能出现在明确标记的局部相容区域。
- Shared Token Shell 不以 Material `Scaffold` 作为预设外壳。
- Token/framework Host 的 Material 依赖有测试及文件记录；目标状态不把 Material 外壳当作所有语言的隐藏 fallback。

### 14.4 Localization、Overlay 与 input

- `onGenerateTitle` 可在各 Host 正常取得语系上下文。
- `localizationsDelegates`、`supportedLocales`、`locale` 与 `TranslationProvider` 在所有 Host 都正常运作。
- 对话框、Tooltip、Popup 和文字选取工具列使用正确的 Host/Adapter 行为；无法原生映射的行为有明确 fallback。
- Android TV 遥控器、桌面键盘/滑鼠与行动触控操作都可正常使用。

### 14.5 架构守卫

- `packages/live_uikit` 不依赖任何 Adapter 或第三方 UI library。
- Adapter 不互相依赖。
- 只有指定 App Composition Root 可以 import/依赖已注册的 Adapter。
- Feature packages 不 import 具体 UI library。
- `LiveUiControl` 仍维持既定十个成员；Host/Shell 能力采独立 contract。

## 15. 建议文件与程式码落点

档名是建议落点，应与目前 repository 的实际目录及既有命名对齐；不要仅为符合这份树状图而重复建立相同职责的档案。

## 16. 最终决策摘要

1. `LiveApp` 只处理 App Host dispatch，不负责强制所有语言使用 Material 祖先。
2. App Host、App Shell、Component Renderer 是三种不同的能力，必须分开设计、分开宣告、分开测试。
3. `TokenApp` 的最终目标是中立的 Token/framework Host；优先评估 `WidgetsApp.router`，并把剩余 Material 依赖局部隔离。
4. 新增 `LiveAppShell` 与中立 Shell contract，让原生 Adapter 可以完整实作各自的外壳，其他 Adapter 使用 Shared Token Shell。
5. 不把 Shell 混入既有十个 `LiveUiControl`，而是新增独立的 Host/Shell surface capability 与 diagnostics。
6. App Composition Root 统一注册 Adapter、提供平台能力及日志 sink；Feature page 只依赖中立 `live_uikit` API。
7. 透过 Host/Shell dispatch、Router state、Localization、Overlay、TV focus 及架构守卫的整合测试，确认真正的跨语言切换，而不只验证单一控制项的外观。

**完成定义：** 当使用者切换设计语言时，App Host、App Shell 与各个 `Live*` 控制项都依各自契约使用对应的原生 renderer 或明确的共享 fallback；不再因全域 `Material` wrapper 或 Material-based Token Host，让所有设计语言被动呈现相同的 Material 外壳。
