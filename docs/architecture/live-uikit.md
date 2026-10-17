# LiveUIKit 核心包实现边界

`live_uikit` 的核心包必须明确定位为：统一 UI 契约、设计令牌、主题解析与控件分派的基础设施层。它不负责实现八套 UI 风格，也不负责管理 PureLive 的业务状态。

本文是核心包的边界设计稿，现行实现与本文的出入见下一节。

## 修订状态（2026-10-17）

> 本文是**实现之前的边界设计稿**。文中的模块名与类型名（`shared/`、`root/`、`LiveUiAdapter`、
> `LiveControl`、`LiveImplementationKind`、`LiveUiFallbackPolicy`、`Styled*`）大多没有按此落地，
> 现行实现请以 [`packages/live_uikit/live-uikit.md`](../packages/live_uikit/live-uikit.md) 和八份
> `packages/live_uikit_*/live-uikit-*.md` 为准。留下本文是为了记录当初的边界理由。
>
> 尤其要注意：**本文要求核心提供“共享控件实现”，并在能力缺失时回退到它 —— 这套地板已经在
> 2026-10-17 被整体删除**。`SharedLanguageAdapter` 及其 `Token*` 渲染器、`LiveUiFallbackPolicy`、
> `LiveImplementationKind`、`LiveTheme.implementationKind`、`LiveDesignLanguage.token`，以及
> `adapterMissing` / `controlUnsupported` / `surfaceUnsupported` / `defaultAdapterMissing` 四个降级码，
> 都不存在了。
>
> 现行契约：`LiveUiControl` **十七**个成员 + `LiveUiSurface` 两个成员（`appHost` / `appShell`）；
> 每家适配器 `implements LanguageAdapter`，自己实现全部控件与两面 —— 库有对应件就映射，没有就用
> 该库自己的零件按该库视觉拼。`LanguageRegistry` 没有 `fallback` 槽；未注册语言抛
> `LiveUiResolutionException`，声明了却没有覆写抛 `LiveUiCapabilityException`；诊断只剩
> `unsupportedEffect`（设备做不到的效果）。
>
> 读 §15.1–§15.6 时，把里面的三 kind 与 shared 回退按上面这段替换理解。


## 1. 核心定位

`live_uikit` 是 PureLive UI 系统的核心基础设施包。

核心包定义统一公共 API、设计令牌模型、主题解析规则、适配器契约、能力解析机制及必要的共享控件实现。

核心包不实现具体设计语言，不依赖任何独立 UI 适配器包，不承担业务模块的状态管理、路由、数据访问或平台服务职责。

### 1.1 核心包必须负责

1. 定义稳定的统一控件 API。
2. 定义与第三方 UI 库无关的设计令牌。
3. 定义用户 UI 配置与有效主题模型。
4. 解析亮暗模式、密度、字体和视觉效果。
5. 定义 UI 适配器及 Theme Mapper 契约。
6. 管理适配器注册与查找。
7. 根据平台和能力选择控件实现。
8. 提供必要的共享控件实现。
9. 提供统一的主题上下文与 UI 根节点。
10. 提供 Overlay、焦点、无障碍和布局的公共契约。
11. 提供配置校验、降级策略和诊断接口。
12. 提供独立于具体适配器的自动化测试。

### 1.2 核心包禁止负责

1. 实现 Material、Cupertino、Fluent、macOS、Neumorphic、Glass 或 Wind 的专属视觉组件。
2. 直接依赖上述 UI 库的第三方 Package。
3. 在公共 API 中暴露第三方 UI 库的专属类型。
4. 管理业务页面、播放器或直播间状态。
5. 管理 PureLive 的路由和导航栈。
6. 直接依赖 Riverpod、GetX 或其他具体状态管理框架。
7. 直接依赖 Talker 等具体日志实现。
8. 直接实现配置持久化或数据库访问。
9. 管理 UI 插件的安装、下载、执行和权限。
10. 负责平台原生窗口、画中画或媒体播放服务。
11. 为七套 UI 强行统一其内部属性和实现细节。
12. 在缺少适配器时静默忽略配置错误。

## 2. 依赖边界

```
apps/pure_live
    │
    ├── live_uikit
    │
    ├── live_uikit_material
    ├── live_uikit_cupertino
    ├── live_uikit_fluent
    ├── live_uikit_macos
    ├── live_uikit_neumorphic
    ├── live_uikit_glass
    └── live_uikit_wind

Business Packages
    │
    └── live_uikit

live_uikit
    │
    ├── Flutter SDK
    └── Minimal framework-independent dependencies
```

依赖规则：

- `live_uikit` 不得依赖任何 `live_uikit_*` 适配器包。
- 适配器包可以依赖 `live_uikit`，但不得反向依赖核心包的私有实现。
- 业务包只能依赖核心包的公开 API，不得通过传递依赖调用第三方 UI 库。
- 应用组合根负责创建适配器实例并注册到核心运行时。
- 核心包可以使用 Flutter SDK 的基础 Widget、主题上下文、焦点、语义和布局能力。
- 核心包不应引入与自身职责无关的生成工具、状态管理或持久化依赖。

## 3. 核心包内部模块

### 3.1 Public API

**职责：** 为业务模块提供稳定的控件与主题入口。

包含：

- `LiveButton`
- `LiveCard`
- `LiveTextField`
- `LiveSwitch`
- `LiveCheckbox`
- `LiveSlider`
- `LiveText`
- `LiveIcon`
- `LiveDialog`
- `LiveMenu`
- `LiveProgress`

规则：

- 只暴露稳定的业务语义。
- 不暴露具体第三方 Widget。
- 不包含直播、媒体或业务领域模型。
- 不将七套 UI 的专有参数合并成巨型公共接口。

### 3.2 Design Tokens

**职责：** 定义跨 UI 风格的基础视觉参数。

包含：

- Color Tokens
- Typography Tokens
- Spacing Tokens
- Geometry Tokens
- Surface Tokens
- Shadow Tokens
- Motion Tokens
- Focus Tokens

规则：

- 令牌必须独立于第三方主题类型。
- 令牌不可直接依赖某个适配器。
- 所有令牌必须有明确的默认值和验证规则。
- 风格专属的复杂效果通过扩展令牌或可选能力表达，不得污染所有控件的基础模型。

### 3.3 Configuration

**职责：** 表达用户的视觉偏好。

核心模型：

- `LiveUiConfig`
- `LiveBrightnessMode`
- `LiveUiDensity`
- `LiveUiStyle`

规则：

- 只负责配置数据和校验。
- 不直接读写文件、数据库或 SharedPreferences。
- 不直接监听 Riverpod 状态。
- 不直接决定某个第三方 Widget 的构建方式。

配置存储由应用层实现，并通过明确的接口与核心模型交互。

### 3.4 Theme Resolution

**职责：** 将用户配置、系统环境和设计令牌解析为最终有效主题。

核心模型：

- `ResolvedLiveUiTheme`
- `LiveThemeResolver`
- `LiveThemeEnvironment`

规则：

- 不依赖具体 UI 适配器。
- 不直接构造 `ThemeData`、`CupertinoThemeData` 或第三方主题对象。
- 负责系统亮暗模式、强调色、字号、密度和效果参数的解析。
- 必须支持默认值、无效配置处理与确定性的解析结果。

### 3.5 Adapter Contracts

**职责：** 定义适配器必须遵守的协议。

包含：

- `LiveUiAdapter`
- `LiveThemeMapper<T>`
- 控件规格模型。
- 能力声明模型。
- 实现类型枚举。
- 适配器诊断信息。

规则：

- 契约不得引用适配器包中的具体类型。
- 控件规格必须保持稳定。
- 可选能力必须能够被明确声明。
- 新增控件时应评估接口拆分，避免强制所有适配器实现不支持的功能。

### 3.6 Runtime and Registry

**职责：** 管理已注册适配器，并解析当前控件实现。

包含：

- `LiveUiRegistry`
- `LiveUiResolver`
- `LiveWidgetFactory`
- `LiveUiRuntime`

规则：

- 不负责安装或下载适配器。
- 不负责动态加载任意 Dart 代码。
- 不依赖具体 UI 库。
- 不将未注册适配器视为已支持风格。
- 对缺失能力提供明确、可诊断的处理策略。
- 只有在确有必要时才允许运行时替换适配器实例。

### 3.7 Shared Widgets

**职责：** 提供适配器缺失时可复用的基础控件实现。

包含必要的共享按钮、卡片、输入框、开关、复选框和滑块实现。

规则：

- 使用核心设计令牌。
- 不依赖 Material 适配器包。
- 不强制使用 Material 默认视觉效果。
- 必须支持统一的交互、焦点、禁用和无障碍语义。
- 共享实现不应成为所有适配器的唯一实现。
- 只有经过能力解析选择后，才使用共享实现。

### 3.8 UI Root and Context

**职责：** 将解析后的主题和运行时提供给控件树。

包含：

- `LiveUiRoot`
- `LiveUiContext`
- `LiveUiScope`
- 当前适配器访问入口。

规则：

- 负责 UI 配置变化的传播。
- 不管理业务路由。
- 不创建播放器或业务 Controller。
- 不重置页面业务状态。
- 不直接绑定 Riverpod。
- Overlay 必须通过明确的上下文传播机制获取相同的主题与运行时。

### 3.9 Accessibility and Interaction Contracts

**职责：** 定义跨风格的基础交互要求。

包含：

- Focus Contracts
- Keyboard Interaction Contracts
- Semantic Labels
- Disabled and Loading States
- Minimum Interaction Target
- TV Remote Interaction Contracts

规则：

- 核心包定义语义和行为要求。
- 适配器负责将这些要求映射为具体控件行为。
- 平台特有的原生交互由适配器或专门的平台集成包实现。

### 3.10 Diagnostics

**职责：** 提供可测试、可观察的 UI 运行时诊断能力。

包含：

- 当前风格。
- 适配器注册状态。
- 控件实现类型。
- 降级原因。
- 主题解析错误。
- 适配器初始化错误。

规则：

- 核心包只定义诊断事件和接口。
- 不直接依赖特定日志库。
- 不输出不必要的用户隐私或业务数据。

## 4. 共享实现与适配器的边界

共享实现和适配器必须有明确的职责划分。

| Concern    | Core Package | Adapter Package |
| ---------- | ------------ | --------------- |
| 公共控件 API   | 定义           | 实现映射            |
| 控件规格       | 定义           | 消费              |
| 设计令牌       | 定义与解析        | 映射为自身视觉参数       |
| 第三方 Widget | 禁止依赖         | 可以使用            |
| 专属视觉效果     | 定义可选契约       | 具体实现            |
| 控件能力声明     | 定义模型与解析      | 声明实际能力          |
| 缺失能力回退     | 决策规则         | 提供可用实现          |
| 无障碍语义      | 定义基础要求       | 适配具体组件          |
| 平台特有行为     | 定义抽象契约       | 负责实现            |
| 业务状态       | 不管理          | 不管理             |

## 5. 配置持久化边界

核心包只定义配置模型和必要的存储契约。

例如：

```dart
abstract interface class LiveUiConfigStore {
  Future<LiveUiConfig?> load();

  Future<void> save(LiveUiConfig config);

  Future<void> clear();
}
```

实际存储可以由应用层使用 Hive CE、SharedPreferences 或其他存储方案实现。

核心包不得直接初始化数据库或选择存储位置。

## 6. 状态管理边界

核心包不依赖 Riverpod，但可以暴露与具体框架无关的配置访问接口。

PureLive 应用层负责：

1. 创建配置状态管理器。
2. 加载持久化配置。
3. 监听用户配置变更。
4. 调用核心主题解析机制。
5. 将更新后的配置传递给 `LiveUiRoot`。

适配器只负责渲染，不得创建或管理业务状态。

## 7. 错误与降级边界

核心包负责定义降级策略及诊断结果。

以下情况必须有明确处理：

- 默认适配器缺失。
- 目标适配器未注册。
- 控件能力不支持。
- 主题配置无效。
- 字体无法加载。
- 平台不支持某种视觉效果。
- 适配器初始化失败。

核心包不得通过无条件空断言、静默忽略或未经记录的自动回退隐藏问题。

对于默认适配器缺失等启动级错误，应在初始化阶段尽早报告；对于单项视觉能力缺失，则可以使用经过验证的共享实现。

## 8. 明确禁止的架构行为

以下行为视为架构违规：

1. 在业务页面中直接导入 `fluent_ui`、`macos_ui` 或其他适配器依赖。
2. 在核心包的公共 API 中暴露第三方 UI 类型。
3. 在核心包中实现七套风格的专属控件。
4. 在共享控件内部硬编码 Material 主题。
5. 将主题切换与业务状态重建绑定。
6. 在核心包中使用 Riverpod 管理业务状态。
7. 在核心包中实现配置文件读写。
8. 让一个适配器依赖另一个适配器。
9. 将所有风格的专有参数塞入单个公共控件。
10. 对未声明的能力进行未经验证的自动降级。
11. 将 UI 风格注册机制扩展为任意代码加载机制。
12. 让平台原生服务进入 UI 设计系统核心。

## 9. 核心包验收标准

- 核心包可在不引入七套 UI 适配器的情况下独立分析和测试。
- 核心包没有任何具体 UI 库依赖。
- 公共 API 不暴露第三方类型。
- 主题解析结果具有确定性。
- 适配器注册与能力解析可独立测试。
- 共享控件不依赖特定适配器。
- 配置存储和状态管理可由应用层替换。
- 缺失能力和初始化错误可以诊断。
- UI 切换不会重建业务状态。
- 所有公共控件具有一致的交互语义。

**最终边界：核心包定义规则、模型、契约、解析机制和共享基础实现；适配器包实现具体 UI 风格；应用组合根负责依赖组装、配置状态和生命周期管理；业务模块只使用统一公共 API。**

## 10. 核心包目录与模块映射

### 10.1 设计原则

`packages/live_uikit` 采用按职责分层、按功能组织的目录结构。

目录划分必须满足以下原则：

1. 公共 API 与内部实现分离。
2. 配置模型、设计令牌、主题解析和运行时调度各自独立。
3. 核心包不依赖任何具体 UI 适配器包。
4. 共享控件不得依赖具体适配器。
5. 第三方 UI 类型只能出现在对应适配器包内部。
6. 公共 API 只导出稳定、明确支持的类型。
7. 每个模块拥有清晰的输入、输出和依赖边界。
8. 不为尚无实际需求的功能预先创建空目录或抽象层。
9. 不使用一个巨大的 `utils/`、`common/` 或 `manager/` 目录容纳职责不明的代码。
10. 优先通过静态依赖关系保证架构边界，而不是依靠开发者记忆。

### 10.2 推荐目录结构

```text
packages/live_uikit/
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
├── analysis_options.yaml
│
├── lib/
│   ├── live_uikit.dart
│   │
│   └── src/
│       ├── config/
│       │   ├── live_ui_config.dart
│       │   ├── live_ui_style.dart
│       │   ├── live_brightness_mode.dart
│       │   ├── live_ui_density.dart
│       │   └── live_ui_config_validator.dart
│       │
│       ├── tokens/
│       │   ├── live_color_tokens.dart
│       │   ├── live_typography_tokens.dart
│       │   ├── live_spacing_tokens.dart
│       │   ├── live_geometry_tokens.dart
│       │   ├── live_surface_tokens.dart
│       │   ├── live_motion_tokens.dart
│       │   ├── live_focus_tokens.dart
│       │   └── live_design_tokens.dart
│       │
│       ├── theme/
│       │   ├── resolved_live_ui_theme.dart
│       │   ├── live_theme_environment.dart
│       │   ├── live_theme_resolver.dart
│       │   └── live_theme_mapper.dart
│       │
│       ├── contracts/
│       │   ├── live_ui_adapter.dart
│       │   ├── live_ui_capabilities.dart
│       │   ├── live_control.dart
│       │   ├── live_implementation_kind.dart
│       │   └── widgets/
│       │       ├── live_button_spec.dart
│       │       ├── live_card_spec.dart
│       │       ├── live_text_field_spec.dart
│       │       ├── live_switch_spec.dart
│       │       ├── live_checkbox_spec.dart
│       │       └── live_slider_spec.dart
│       │
│       ├── runtime/
│       │   ├── live_ui_runtime.dart
│       │   ├── live_ui_registry.dart
│       │   ├── live_ui_resolver.dart
│       │   ├── live_widget_factory.dart
│       │   └── live_ui_fallback_policy.dart
│       │
│       ├── widgets/
│       │   ├── button/
│       │   │   ├── live_button.dart
│       │   │   ├── live_button_variant.dart
│       │   │   └── live_button_size.dart
│       │   ├── card/
│       │   │   └── live_card.dart
│       │   ├── text_field/
│       │   │   └── live_text_field.dart
│       │   ├── switch/
│       │   │   └── live_switch.dart
│       │   ├── checkbox/
│       │   │   └── live_checkbox.dart
│       │   ├── slider/
│       │   │   └── live_slider.dart
│       │   ├── text/
│       │   │   ├── live_text.dart
│       │   │   └── live_text_style.dart
│       │   └── icon/
│       │       └── live_icon.dart
│       │
│       ├── shared/
│       │   ├── button/
│       │   │   └── shared_button_adapter.dart
│       │   ├── card/
│       │   │   └── shared_card_adapter.dart
│       │   ├── text_field/
│       │   │   └── shared_text_field_adapter.dart
│       │   ├── switch/
│       │   │   └── shared_switch_adapter.dart
│       │   ├── checkbox/
│       │   │   └── shared_checkbox_adapter.dart
│       │   └── slider/
│       │       └── shared_slider_adapter.dart
│       │
│       ├── root/
│       │   ├── live_ui_root.dart
│       │   ├── live_ui_scope.dart
│       │   └── live_ui_context.dart
│       │
│       ├── layout/
│       │   ├── live_spacing.dart
│       │   ├── live_container.dart
│       │   └── live_responsive.dart
│       │
│       ├── overlays/
│       │   ├── live_dialog.dart
│       │   ├── live_menu.dart
│       │   └── live_overlay_context.dart
│       │
│       ├── interaction/
│       │   ├── live_focus_policy.dart
│       │   ├── live_keyboard_policy.dart
│       │   └── live_interaction_state.dart
│       │
│       └── diagnostics/
│           ├── live_ui_diagnostic_event.dart
│           ├── live_ui_diagnostic_sink.dart
│           └── live_ui_diagnostic_codes.dart
│
├── test/
│   ├── config/
│   ├── tokens/
│   ├── theme/
│   ├── contracts/
│   ├── runtime/
│   ├── widgets/
│   ├── root/
│   └── interaction/
│
└── example/
    └── lib/
        └── main.dart
```

上述目录是目标结构，不要求在第一阶段一次性创建全部文件。仅在对应功能进入实施范围时创建模块。

### 10.3 模块映射总表

| Module | Directory | Primary responsibility |
|---|---|---|
| Configuration | `config/` | 用户 UI 配置与校验 |
| Design Tokens | `tokens/` | 与设计语言无关的视觉参数 |
| Theme Resolution | `theme/` | 解析最终有效主题 |
| Adapter Contracts | `contracts/` | 适配器与控件规格契约 |
| Runtime | `runtime/` | 注册、解析、分派与回退 |
| Public Widgets | `widgets/` | 稳定的业务控件 API |
| Shared Implementations | `shared/` | 不依赖具体适配器的共享控件 |
| UI Root and Scope | `root/` | 提供运行时与主题上下文 |
| Layout | `layout/` | 通用布局与响应式辅助 |
| Overlays | `overlays/` | 统一弹窗与浮层入口 |
| Interaction | `interaction/` | 公共焦点、键盘与交互策略 |
| Diagnostics | `diagnostics/` | 运行时诊断事件与接口 |

### 10.4 Configuration：配置模块

路径：`lib/src/config/`

负责：

- 定义 `LiveUiConfig`。
- 定义 UI 风格、亮暗模式和密度枚举。
- 验证字号缩放、透明度等参数范围。
- 提供默认配置。
- 为持久化提供稳定的数据模型。

不得负责：

- 读写文件或数据库。
- 监听 Riverpod 状态。
- 构造 Flutter Theme。
- 决定具体控件的实现方式。

配置持久化由应用层实现。配置模型需要序列化时，应根据实际需要添加独立的序列化实现，而不是让配置类承担存储职责。

### 10.5 Tokens：设计令牌模块

路径：`lib/src/tokens/`

负责：

- 定义颜色、字体、间距、几何、表面、动效和焦点令牌。
- 提供明确的默认值。
- 约束令牌之间的取值范围。
- 提供与具体 UI 库无关的基础视觉参数。

不得负责：

- 创建第三方 UI 主题对象。
- 依赖适配器注册表。
- 处理业务状态。
- 根据具体业务页面修改视觉令牌。

建议使用不可变模型。高频访问的令牌对象应避免不必要的重复创建。

### 10.6 Theme：主题解析模块

路径：`lib/src/theme/`

负责：

- 根据 `LiveUiConfig` 与 `LiveThemeEnvironment` 生成 `ResolvedLiveUiTheme`。
- 处理系统亮暗模式。
- 计算最终强调色、字号、密度和效果参数。
- 为主题变化提供可测试的解析逻辑。
- 为适配器提供统一的主题输入。

不得负责：

- 直接构建 `ThemeData`。
- 直接构建 `CupertinoThemeData`。
- 直接引用 Fluent、macOS、Wind 等第三方主题类型。
- 决定用户是否已安装某个适配器。

具体 UI 库的主题转换由适配器包实现。

### 10.7 Contracts：适配器契约模块

路径：`lib/src/contracts/`

负责定义：

- `LiveUiAdapter`。
- `LiveUiCapabilities`。
- `LiveControl`。
- `LiveImplementationKind`。
- 各控件的规格模型。
- 必要的主题映射接口。

契约只描述调用方需要什么，以及适配器必须提供什么。

不得在契约模型中出现 `FluentButton`、`MacosSwitch` 或其他第三方 Widget 类型。

建议在实施时评估是否将单一的大型 `LiveUiAdapter` 拆分为控件级能力接口。适配器不应被迫实现其不支持且无法合理降级的功能。

### 10.8 Runtime：运行时模块

路径：`lib/src/runtime/`

负责：

- 注册和查找适配器。
- 验证默认适配器。
- 解析当前风格对应的实现。
- 检查控件与平台能力。
- 选择原生适配器实现、共享实现或自定义实现。
- 执行明确的回退策略。
- 提供可测试的控件分派入口。

不得负责：

- 下载或安装适配器。
- 动态执行任意插件代码。
- 创建业务 Controller。
- 持久化用户配置。
- 管理应用路由。

Runtime 只处理已由应用组合根注册的适配器。

### 10.9 Widgets：公共控件模块

路径：`lib/src/widgets/`

负责：

- 暴露稳定的 `Live*` 控件。
- 校验公共参数。
- 将控件规格传递给 Runtime。
- 统一交互语义与回调。
- 在风格切换时重新解析实现。

不得负责：

- 直接导入七套 UI 库。
- 在每个控件内部重复编写七路风格分支。
- 将业务状态管理嵌入控件。
- 通过特定 UI 库的专有参数改变公共 API 语义。

公共控件只依赖核心契约、运行时和必要的 Flutter SDK API。

### 10.10 Shared：共享控件模块

路径：`lib/src/shared/`

负责：

- 提供适配器缺少对应控件时的共享实现。
- 根据当前主题令牌渲染控件。
- 提供统一的焦点、禁用、加载和无障碍行为。
- 在能力解析确认需要回退后参与渲染。

不得负责：

- 依赖 `live_uikit_material`。
- 固定使用 Material 默认颜色、圆角和阴影。
- 代替所有适配器实现专属视觉效果。
- 绕过 Runtime 自行判断当前 UI 风格。

共享实现应是独立的基础实现，而不是某个适配器的内部包装。

### 10.11 Root：UI 上下文模块

路径：`lib/src/root/`

负责：

- 提供 `LiveUiRoot`。
- 向控件树暴露当前主题和 Runtime。
- 在配置变化时更新上下文。
- 通过 Flutter 的继承式上下文机制减少不必要的重建。
- 保证 Overlay 能够获得一致的主题上下文。

不得负责：

- 管理 GoRouter。
- 初始化播放器。
- 管理业务页面生命周期。
- 直接依赖 Riverpod。

应用层可以通过 Riverpod 管理配置，再把更新后的配置传入 Root。

### 10.12 Layout：布局模块

路径：`lib/src/layout/`

负责：

- 提供统一间距、容器和布局辅助。
- 通过设计令牌实现一致的布局规则。
- 提供跨屏幕尺寸的响应式辅助。

不得负责：

- 替代 Flutter 的完整布局系统。
- 将电视、桌面和手机的尺寸规则强行合并成单一缩放比例。
- 依赖具体 UI 适配器。

平台特有的窗口行为应交给专门的平台集成或应用层处理。

### 10.13 Overlays：浮层模块

路径：`lib/src/overlays/`

负责：

- 定义统一的 Dialog、Menu 和 Overlay API。
- 传播主题上下文。
- 统一基本关闭、确认、取消和焦点语义。
- 提供与公共控件一致的视觉令牌。

不得负责：

- 管理业务导航。
- 实现具体 UI 库专属的弹窗。
- 自行持久化弹窗状态。

具体视觉实现由适配器负责。

### 10.14 Interaction：交互模块

路径：`lib/src/interaction/`

负责：

- 定义统一焦点策略。
- 定义键盘和遥控器交互要求。
- 规范禁用、加载、悬停和聚焦状态。
- 为无障碍语义提供公共辅助机制。

不得负责：

- 直接控制媒体播放。
- 接管整个应用的快捷键系统。
- 将某个平台的交互行为无条件应用到所有平台。

适配器必须根据平台能力实现对应的交互契约。

### 10.15 Diagnostics：诊断模块

路径：`lib/src/diagnostics/`

负责：

- 定义诊断事件和错误代码。
- 记录适配器注册和能力解析结果。
- 记录主题解析错误与回退原因。
- 为自动化测试提供可观测接口。

不得负责：

- 直接绑定 Talker 或其他日志库。
- 输出用户敏感信息。
- 承担一般业务日志职责。

日志事件由应用层接入实际日志系统。

## 11. 模块依赖矩阵

符号说明：

- `✓`：允许直接依赖。
- `—`：不应直接依赖。
- `→`：仅通过定义好的契约或公开接口交互。

| Module | Config | Tokens | Theme | Contracts | Runtime | Widgets | Shared | Root |
|---|---|---|---|---|---|---|---|---|
| Config | — | — | — | — | — | — | — | — |
| Tokens | — | — | — | — | — | — | — | — |
| Theme | ✓ | ✓ | — | — | — | — | — | — |
| Contracts | — | ✓ | ✓ | — | — | — | — | — |
| Runtime | ✓ | — | ✓ | ✓ | — | — | ✓ | — |
| Widgets | — | — | — | ✓ | ✓ | — | — | → |
| Shared | — | ✓ | ✓ | ✓ | — | — | — | — |
| Root | ✓ | — | ✓ | — | ✓ | — | — | — |

矩阵表达的是推荐的模块边界，不代表每个模块都必须直接导入表格中所有允许依赖的模块。

特别约束：

- `Theme` 不得依赖 `Runtime`。
- `Runtime` 可以依赖主题解析接口，但不得依赖具体适配器实现。
- `Shared` 不得依赖 `Widgets`，避免公共 API 与内部实现产生循环依赖。
- `Widgets` 通过 Runtime 选择实现。
- `Root` 负责组装配置与 Runtime，但不承担业务状态管理。
- 所有模块不得直接依赖适配器包。

## 12. 公共导出策略

文件：`lib/live_uikit.dart`

该文件是核心包唯一的稳定公共入口。

建议按需导出：

- 用户配置模型。
- 设计令牌公开类型。
- 解析后的主题模型。
- 适配器契约。
- 注册表和运行时公共接口。
- 公共控件。
- Root 与 Scope。
- 必要的交互契约。
- 诊断接口。

禁止导出：

- `lib/src/` 中的内部实现文件。
- 共享控件的内部实现类。
- 内部缓存和分派辅助类。
- 未承诺兼容性的实验性类型。

适配器包应提供独立入口，例如 `live_uikit_fluent.dart`，仅暴露适配器注册所需的公开 API。

## 13. 第一阶段最小实现范围

第一阶段不应一次实现完整目录。

必须完成：

1. `config/`：配置模型与校验。
2. `tokens/`：最小完整令牌集合。
3. `theme/`：有效主题解析。
4. `contracts/`：基础控件契约。
5. `runtime/`：注册、解析和回退。
6. `widgets/`：Button、Card、TextField、Switch、Checkbox、Slider。
7. `shared/`：至少为首批验证场景提供可用的共享实现。
8. `root/`：主题上下文与运行时传播。
9. `test/`：核心契约与运行时测试。

`layout/`、`overlays/`、`interaction/` 和 `diagnostics/` 可以随实际需求逐步加入，但 TV 焦点契约、主题一致性和基本错误诊断必须在正式支持相应平台前完成。

## 14. 目录结构验收标准

- [ ] 每个目录都有明确的职责说明。
- [ ] 公共 API 与内部实现严格分离。
- [ ] 核心包不依赖任何具体 UI 适配器。
- [ ] 业务模块不需要导入第三方 UI 库。
- [ ] Runtime 不负责持久化和业务状态。
- [ ] Theme 不依赖 Runtime 或具体适配器。
- [ ] Shared 不依赖任何适配器包。
- [ ] Root 不负责路由或业务生命周期。
- [ ] 公共导出集中在 `live_uikit.dart`。
- [ ] 各模块具备相应的单元测试或 Widget 测试。
- [ ] 未实施的能力不会以空目录或空接口伪装成已完成。
- [ ] 新增模块前必须说明其职责、依赖方向和测试边界。

**架构约束总结：** `config` 定义用户意图，`tokens` 定义视觉基础，`theme` 计算有效主题，`contracts` 定义协议，`runtime` 决定实现，`widgets` 暴露公共 API，`shared` 提供共享实现，`root` 负责上下文传播，应用组合根负责注册与生命周期管理。

## 15. 控件分派与降级流程

> 本节(§15.1–§15.6)是提案原设计:三 kind 派发结果与 shared 回退。
> 现行模型没有这两样 —— 见文首「修订状态(2026-10-17)」。


本章把 §3.6 Runtime、§3.7 Shared、§7 错误与降级落到一条明确的、可测试的分派路径上。目标：任何 `Live*` 公共控件在任意“风格 × 平台 × 能力 × 注册状态”组合下，其实现选择都是确定的、可诊断的，且不静默隐藏问题。

### 15.1 分派入口与时序

一次公共控件渲染的分派链路（自上而下）：

```
业务代码
  → LiveButton(spec...)                     // §3.1 公共 API，只吃控件规格
      → LiveUiScope / LiveUiContext.of      // §3.8 Root：取当前 ResolvedLiveUiTheme + LiveUiRuntime
          → LiveUiResolver.resolve(          // §3.6 Runtime：本控件的分派决策
                control: LiveControl.button,
                style: 当前 LiveUiStyle,
                platform: 平台/能力,
              )
              → LiveUiRegistry.adapterFor(style)     // 已注册? 
              → adapter.capabilities.supports(button)? // 声明该能力?
          → 返回 LiveResolvedImplementation { kind, builder }
      → 按 kind 渲染（原生适配器 / 共享 / 自定义）
```

约束：

- 公共控件（`widgets/`）**不判断当前是哪种风格**，也不 `switch (七套)`；它只把规格交给 `LiveUiResolver`（见 §10.9 禁止事项）。
- `LiveUiResolver` 是**唯一**决定“用谁渲染”的地方；`shared/` 不自行判断风格（§10.10）。
- 分派结果必须携带 `LiveImplementationKind`，供渲染、测试与诊断读取。

### 15.2 实现类型枚举

`LiveImplementationKind`（`contracts/` 定义）至少：

| 值 | 含义 | 来源 |
|---|---|---|
| `adapterNative` | 目标风格适配器提供的原生控件 | `live_uikit_*` 适配器 |
| `shared` | 核心包共享实现（基于令牌） | `shared/` |
| `custom` | 应用注册的自定义覆盖实现 | 组合根注入 |

诊断与测试据此断言“某个控件在某种风格下到底由谁渲染”。

### 15.3 决策流程（含降级）

`LiveUiResolver.resolve` 的确定性决策顺序：

```
1. 取当前风格 style（来自 ResolvedLiveUiTheme / LiveUiRuntime）。
2. adapter = registry.adapterFor(style)
   2a. adapter == null:
         if style == defaultStyle 且 defaultAdapter 缺失:
             -> 启动级错误 (§7)：立即通过 diagnostics 报告 defaultAdapterMissing；
                解析失败或按显式策略回退到 shared（不可静默）。
         else:
             -> 记录 adapterMissing 诊断 -> 进入 3（用共享）。
   2b. adapter != null:
         if adapter.capabilities.supports(control):
             -> kind = adapterNative，使用 adapter 映射的控件。
         else:
             -> 记录 controlUnsupported 诊断 -> 进入 3。
3. 若存在该控件的 custom 覆盖（组合根注册）:
       -> kind = custom。
4. 否则使用 shared/<control>_adapter:
       -> kind = shared。（前提：shared 实现满足该控件的基础交互/无障碍契约，§3.7）
5. 若 shared 也不可用（极端：控件无任何实现）:
       -> 按 LiveUiFallbackPolicy：抛出可诊断错误或渲染显式占位并报告，
          绝不无条件空实现掩盖。
```

平台能力（如玻璃模糊、TV 焦点、backdrop filter）在步骤 2/4 中作为额外门控：环境不支持某效果时，适配器或共享实现必须走**已验证**的降级视觉（如不透明平面色），并通过 diagnostics 记录降级原因，而非直接崩溃或忽略。

### 15.4 LiveUiFallbackPolicy（该类型已删除，见文首修订说明）

`runtime/live_ui_fallback_policy.dart` 集中定义降级规则，使流程可测、可配置：

- `onMissingDefaultAdapter`：`failFast`（默认，启动级）/ `fallbackToShared`。
- `onMissingAdapter(style)`：`fallbackToShared`（默认）并记录。
- `onUnsupportedControl(style, control)`：`fallbackToShared`（默认）并记录。
- `onUnsupportedEffect(environment, effect)`：使用声明的降级视觉并记录。

策略本身属于核心（决策规则），但“实际可用的实现”由适配器/共享提供（§4 表格）。核心**不得**绕过策略做未声明、未记录的自动降级（§8.10）。

### 15.5 与 §7/§8 的对应

- 启动级错误（默认适配器缺失）在 Root/组合根初始化阶段尽早报告（§7 末段）。
- 单项能力缺失走共享实现 + 诊断（§7、§10.10、§15.3）。
- 任何降级都要产生一条 `LiveUiDiagnosticEvent`（含 style/control/kind/reason），保证“可诊断、非静默”。

### 15.6 分派验收标准

- [ ] `Live*` 控件源码内没有对第三方 UI 库的导入，也没有七路 `switch(style)`。
- [ ] 风格切换只改变 `LiveUiResolver` 返回的 `kind`/builder，不改业务状态、不重建页面树（§6、§8.5）。
- [ ] 未注册风格、缺默认适配器、缺控件能力、缺平台效果这四类情形各有确定的、可断言的处理路径与诊断码。
- [ ] `adapterNative`/`shared`/`custom` 三种 kind 均可在 Widget 测试中稳定复现。
- [ ] 任何降级都会发出诊断事件，不存在静默空实现。

## 16. 当前实现与目标边界的差距（迁移备注）

> 本节记录“现状 vs 本文规范”的客观差距，供迁移排期参考；不代表这些规则可被豁免。

本节按 2026-10-17 的现状重写：上面第 1、2、3 条差距**都已了结**，而且第 3 条的解法比本文当初的设计更严格。

1. ✅ 核心包 `pubspec.yaml` 里没有任何第三方 UI 库，`lib/src/styling/language_adapters.dart` 也不存在了：
   八套风格各在独立的 `live_uikit_<style>` 包里，`tool/check_architecture.ps1` 机器校验这条边界。
2. ✅ 公共控件统一叫 `Live*`（`LiveButton` / `LiveCard` / …），每个都是一层薄派发器：
   建 `Language*Spec` → `LiveTheme.of(context).adapter.<control>(...)`，源码内不 `switch` 风格。
3. ✅ 分派链路是 `Live* → LiveConfigProvider（每次语言变更解析一次）→ LiveUiResolver.resolve → LanguageAdapter`。
   本文设想的“共享实现兜底”先建后删：核心**不出任何控件渲染器**，因此没有 `adapterNative|shared|custom` 三 kind，
   也没有“缺失能力落到 shared”。未注册语言抛 `LiveUiResolutionException`，声明与覆写不一致抛
   `LiveUiCapabilityException` —— 派发结果本身不再是可上报的降级。

仍然成立的差距：

4. **§5/§10.4 配置持久化**：`UiConfig` 的持久化在 app 层（外观偏好），符合“核心不碰存储”，
   但核心没有本文要求的 `LiveUiConfigStore` 契约接口。
5. **§3.10/§15 诊断**：诊断已在（`LiveUiDiagnostic` + `LiveUiDiagnosticSink` typedef，核心不依赖日志实现），
   但只剩 `unsupportedEffect` 一个码；适配器库自己的特效（glass 毛玻璃、fluent acrylic）仍不读
   `LiveTheme.canBlur`，这条半边仍开放。

原文的迁移顺序已按 §1–§4 走完，保留在下面作为当时为什么这样排序的理由：

建议迁移顺序（低风险优先）：先抽 `contracts/`（把 `LanguageAdapter`/各 `Spec` 归位并去除对第三方类型的暴露）→ 逐个把 `language_adapters.dart` 中的各库实现**外迁**为 `live_uikit_*` 包并从核心 pubspec 删除对应依赖 → 建 `runtime/`（registry/resolver/fallback/policy）+ `diagnostics/` → 统一 `Live*` 命名。迁移期以“核心包 `pubspec` 不再出现任何第三方 UI 库”作为 §9/§14 的关键里程碑门禁。
