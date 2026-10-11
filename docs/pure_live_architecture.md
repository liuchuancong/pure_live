
# PureLive 技术架构与 UI 系统建设方案

- **项目名称：** PureLive
- **架构方向：** Flutter 跨平台直播聚合应用
- **应用包：** `apps/pure_live`
- **播放器基础设施：** `media_core`
- **核心业务模块：** `live_sites`、`live_playback`、`live_interaction`、`live_library`、`live_iptv`、`live_preferences`
- **统一 UI 系统：** `live_uikit`
- **UI 技术基础：** Flutter、Material、Cupertino、Fluent、macOS、Yaru、Neumorphic、Wind UI
- **TV 项目：** `F:\pure_live_TV\pure_live_TV`
- **开发要求：** 不新增测试和 Demo 交付模块；实现完成后按约定直接提交并推送 Git
- **代码注释：** 英文
- **设计目标：** 单一业务体系、多种设计语言、跨平台适配、电视遥控器优先

---

# 1. 项目定位

PureLive 是一个专注于直播的跨平台应用。

项目不建设通用的全媒体扩展平台，不将音乐、通用点播和其他不相关的业务引入核心架构。

主要能力：

- 多直播平台聚合。
- 直播间搜索、分类、推荐和详情。
- 播放线路管理与自动恢复。
- 多播放器内核支持。
- 弹幕、礼物及直播互动。
- 关注、分组、收藏和观看历史。
- IPTV 直播频道与 M3U 播放列表。
- 统一主题、样式、背景和组件系统。参考`F:\pure_live_TV\pure_live_TV`
- Material、Cupertino、Fluent、macOS、Yaru、Neumorphic 六种设计语言。
- Android、Android TV、Windows、macOS、Linux、Android、iOS 跨平台 UI。
- 电视遥控器、D-pad 焦点、焦点导航和大屏布局。
- 统一应用体验与平台原生风格的兼容。

项目遵循以下原则：

1. 业务逻辑与 UI 分离。
2. UI 设计语言与业务模型分离。
3. 播放器内核与直播播放编排分离。
4. 直播平台实现与平台专属协议分离。
5. 桌面端、移动端与 TV 共用业务模块。
6. 同一设计语言使用同一套组件契约。
7. 不为了跨平台而牺牲 TV 的遥控器体验。
8. 不为了模块数量而过度拆分 Package。
9. 不重复实现现有 `media_core` 已有的能力。
10. 所有模块遵循统一的编码、依赖、提交和发布规范。

---

# 2. Monorepo 总体结构

```text
pure_live/
├── apps/
│   └── pure_live/
│       ├── lib/
│       │   ├── app/
│       │   ├── bootstrap/
│       │   ├── router/
│       │   ├── shell/
│       │   └── main.dart
│       ├── assets/
│       └── pubspec.yaml
│
├── packages/
│   ├── live_sites/
│   ├── live_playback/
│   ├── live_interaction/
│   ├── live_library/
│   ├── live_iptv/
│   ├── live_preferences/
│   ├── live_uikit/
│   ├── media_core/
│   └── shared_*/
│
├── tool/
├── docs/
├── pubspec.yaml
├── analysis_options.yaml
├── melos.yaml
└── README.md
```

以上是目标结构，不代表必须创建所有目录或重新实现已经存在的 Package。

迁移前先检查仓库当前状态。对于已存在的 `media_core`、配置模块、播放器适配器和公共基础设施，优先保留和复用。

## 2.1 应用组合根

`apps/pure_live` 是整个应用的组合根，负责：

- Flutter 应用启动。
- 平台环境检测。
- 路由和页面组装。
- 全局主题与设计语言选择。
- 依赖注入和服务注册。
- 应用级生命周期。
- 窗口与系统 UI 初始化。
- 移动端、桌面端与 TV 的启动配置。

应用组合根可以依赖业务 Package 和 `live_uikit`，但底层业务 Package 不应反向依赖应用页面。

## 2.2 `shared_*` 的创建原则

不要提前创建大量空的共享包。

只有满足以下条件之一时才拆分：

- 两个或更多 Package 确实共享一项稳定能力。
- 该能力具有独立的职责和生命周期。
- 独立维护能减少依赖耦合。
- 需要在多个应用之间复用。

例如，可以根据实际需求评估：

- `shared_utils`
- `shared_network`
- `shared_storage`
- `shared_logging`

这些名称是候选项，不是必须全部创建的 Package。优先使用仓库现有的网络、存储和日志实现。

---

# 3. 核心模块职责

## 3.1 `live_sites`

**职责：直播平台领域层。**

负责：

- 各直播平台的实现。
- 公共直播间模型。
- 平台专属数据模型。
- 平台 Logo、名称和元数据。
- 直播分类、搜索、推荐和详情。
- 播放地址解析。
- 线路与画质发现。
- 平台专属弹幕协议解析。
- 礼物、表情、徽章和观众数据转换。
- 平台限制与错误语义。
- 平台能力声明。

建议继续将 `live_core` 和 `live_danmaku` 的相关职责合并到该 Package。

公共模型与平台实现分离，但每个平台自己的模型、解析器、播放地址处理及弹幕工具尽量集中在同一平台目录。

```text
live_sites/
├── lib/
│   ├── live_sites.dart
│   └── src/
│       ├── common/
│       │   ├── models/
│       │   ├── contracts/
│       │   └── utils/
│       ├── site/
│       ├── playback/
│       ├── danmaku/
│       └── platforms/
│           ├── bilibili/
│           ├── douyu/
│           ├── huya/
│           └── ...
└── pubspec.yaml
```

模型生成采用 Freezed 与 JSON Serializable，具体版本及迁移规则以 `live_sites` 的独立架构文档为准。

不要将 UI 组件、播放器控制器和应用路由放入 `live_sites`。

## 3.2 `live_playback`

**职责：直播播放编排层。**

负责：

- 播放会话。
- 当前直播间与线路选择。
- 画质选择策略。
- 播放地址刷新和续期调度。
- 播放失败分类。
- 同线路、跨线路、跨引擎恢复策略。
- 音频模式协调。
- 多窗口播放会话协调。
- 播放状态与诊断事件。
- 播放会话的生命周期。

不负责：

- 实现底层播放器引擎。
- 实现播放器适配器。
- 重新定义媒体内核。
- 实现视频渲染。
- 直接解析平台私有协议。

`live_playback` 调用 `live_sites` 获取播放能力，并通过现有 `media_core` 驱动播放器。

## 3.3 `media_core`

**职责：播放器内核与媒体引擎适配层。**

保留现有实现，不因创建 `live_playback` 而重复建设。

负责：

- 播放器内核抽象。
- `PlayerAdapterBase` 等引擎适配器。
- `PlayerKernel`。
- `PlayerAdapterCapabilities`。
- 播放、暂停、停止和资源释放。
- 原生播放器事件转换。
- 视频、音频输出与底层播放能力。
- 引擎特有配置。
- 平台播放器适配。

原则：

> `media_core` 负责播放媒体，`live_playback` 负责决定如何稳定地播放直播。

## 3.4 `live_interaction`

**职责：通用直播互动会话层。**

负责：

- 弹幕会话生命周期。
- 公共消息事件流。
- 消息去重与合并。
- 重连后的消息处理。
- 观众人数更新的统一分发。
- 礼物和醒目留言的通用事件消费。
- 多个互动来源的协调。
- 互动状态和错误传播。

平台协议解析继续归 `live_sites`。

公共消息模型优先复用 `live_sites` 中的 `LiveMessage`、`LiveGift` 等模型，不再复制定义。

如果现有弹幕实现尚未复杂到需要独立 Package，可以先在业务边界内设计，待职责稳定后再独立发布。

## 3.5 `live_library`

**职责：用户的直播间内容管理。**

负责：

- 关注的直播间。
- 直播间分组。
- 收藏。
- 最近观看。
- 观看历史。
- 用户自定义排序。
- 直播间记录与元数据持久化。
- 关注状态与平台直播间身份的关联。

不负责：

- 平台 API 请求。
- 播放器控制。
- 弹幕解析。
- UI 页面。

持久化模型应与 `LiveRoom` 的网络响应模型明确区分，避免刷新直播间时覆盖用户自己的备注、分组和历史数据。

## 3.6 `live_iptv`

**职责：IPTV 直播源与频道管理。**

该模块只服务于直播范围内的 IPTV 能力，不扩展为通用媒体库。

负责：

- M3U 播放列表解析。
- IPTV 频道模型。
- 直播频道分组。
- 频道收藏与排序。
- 直播源导入。
- 频道 URL、请求头和必要的直播元数据。
- 频道可用性与刷新策略。
- IPTV 频道到 `live_playback` 的播放协调。

如果 IPTV 需要独立的频道模型，不要强行将所有频道包装成直播平台的 `LiveRoom`。可以由 IPTV 适配层将频道转换成播放会话需要的输入。

IPTV 频道和传统直播平台的领域模型可以不同，但应共享播放编排和 `media_core` 的媒体播放能力。

## 3.7 `live_preferences`

**职责：直播偏好与配置。**

负责：

- 默认画质。
- 默认播放引擎选择偏好。
- 线路偏好。
- 弹幕开关。
- 弹幕透明度、大小和显示位置。
- TV 导航偏好。
- 多窗口行为偏好。
- 自动重试与恢复偏好。
- 直播列表布局。
- 默认设计语言和主题偏好。

先检查现有设置模块。如果已经具备稳定的配置持久化和状态管理能力，应优先扩展现有实现，而不是重复创建存储系统。

## 3.8 `live_uikit`

**职责：统一的跨平台 UI 设计系统。**

负责：

- 主题。
- 颜色、文字、间距和圆角等设计令牌。
- 页面背景。
- 通用布局。
- 按钮、输入框、对话框和菜单。
- 加载、错误、空状态等通用状态组件。
- 六种设计语言的组件实现。
- 组件主题映射。
- 响应式布局。
- TV 焦点与遥控器交互基础设施。
- 跨平台 UI 能力适配。
- Wind UI 的集成与兼容策略。

不负责：

- 直播平台数据请求。
- 播放地址解析。
- 播放器内核。
- 业务持久化。
- 应用级业务路由。
- 具体直播平台的数据模型。

---

# 4. 模块依赖方向

```text
                       apps/pure_live
                              │
              ┌───────────────┼────────────────┐
              │               │                │
         Business Packages  live_uikit    Application Shell
              │               │
       ┌──────┼───────┐       │
       │      │       │       │
  live_sites  │  live_library │
       │      │               │
       ▼      ▼               ▼
 live_playback ─────────── UI Components
       │
       ▼
  media_core

 live_interaction ─────── live_sites
 live_iptv ────────────── live_playback
 live_preferences ─────── Application / UI Configuration
```

这是职责关系示意，不是最终的 Package 导入清单。

实际依赖应遵循：

1. `live_sites` 不依赖 `live_playback`。
2. `live_playback` 可以依赖 `live_sites` 和 `media_core`。
3. `live_interaction` 复用 `live_sites` 的公共消息模型。
4. `live_iptv` 可以依赖播放编排契约，但不能反向依赖应用页面。
5. `live_library` 不依赖具体 UI 组件。
6. `live_uikit` 不依赖直播业务 Package。
7. `media_core` 不依赖 `live_sites`。
8. `apps/pure_live` 负责组合模块。
9. 不允许通过循环依赖实现模块之间的调用。
10. 对于确实需要共享的类型，应将其放入现有公共契约中，而不是互相导入内部实现。

---

# 5. `live_uikit` 总体设计

## 5.1 核心目标

`live_uikit` 不是简单的组件集合，也不是将六套 UI 库同时包进一个统一的 Flutter Widget。

它应当是：

**统一设计令牌 + 统一组件契约 + 多种设计语言实现 + 平台能力适配 + TV 交互基础设施。**

同一个业务页面可以使用统一的业务模型和状态，但根据用户选择的设计语言，呈现 Material、Cupertino、Fluent、macOS、Yaru 或 Neumorphic 风格。

例如：

```dart
final designLanguage = LiveDesignLanguage.material;
```

在同一业务页面中，按钮、输入框、菜单、对话框和导航组件通过 `live_uikit` 的统一接口生成对应设计语言的实现。

不应要求业务页面分别维护六份业务逻辑。

## 5.2 推荐目录结构

```text
live_uikit/
├── pubspec.yaml
├── lib/
│   ├── live_uikit.dart
│   │
│   └── src/
│       ├── core/
│       │   ├── design_language.dart
│       │   ├── ui_platform.dart
│       │   ├── ui_configuration.dart
│       │   ├── ui_component_registry.dart
│       │   └── ui_environment.dart
│       │
│       ├── tokens/
│       │   ├── colors.dart
│       │   ├── typography.dart
│       │   ├── spacing.dart
│       │   ├── radii.dart
│       │   ├── elevation.dart
│       │   ├── motion.dart
│       │   ├── breakpoints.dart
│       │   └── focus_tokens.dart
│       │
│       ├── theme/
│       │   ├── live_theme.dart
│       │   ├── live_color_scheme.dart
│       │   ├── live_text_theme.dart
│       │   ├── live_background_theme.dart
│       │   ├── live_component_theme.dart
│       │   └── theme_resolver.dart
│       │
│       ├── backgrounds/
│       │   ├── live_background.dart
│       │   ├── background_style.dart
│       │   └── background_presets.dart
│       │
│       ├── components/
│       │   ├── buttons/
│       │   ├── inputs/
│       │   ├── cards/
│       │   ├── dialogs/
│       │   ├── menus/
│       │   ├── navigation/
│       │   ├── lists/
│       │   ├── tabs/
│       │   ├── indicators/
│       │   ├── loading/
│       │   ├── errors/
│       │   └── empty_states/
│       │
│       ├── layouts/
│       │   ├── adaptive_scaffold.dart
│       │   ├── responsive_layout.dart
│       │   ├── desktop_layout.dart
│       │   ├── mobile_layout.dart
│       │   └── tv_layout.dart
│       │
│       ├── navigation/
│       │   ├── app_navigation.dart
│       │   ├── navigation_rail.dart
│       │   ├── navigation_bar.dart
│       │   └── tv_navigation.dart
│       │
│       ├── focus/
│       │   ├── focus_scope.dart
│       │   ├── focus_boundary.dart
│       │   ├── focus_navigation.dart
│       │   ├── focus_restore.dart
│       │   └── focus_feedback.dart
│       │
│       ├── input/
│       │   ├── keyboard_actions.dart
│       │   ├── remote_actions.dart
│       │   └── input_capabilities.dart
│       │
│       └── design_languages/
│           ├── material/
│           ├── cupertino/
│           ├── fluent/
│           ├── macos/
│           ├── yaru/
│           └── neumorphic/
│
└── README.md
```

这是一种目标组织方式。实现过程中应按真实组件数量逐步建立目录，不必提前创建大量空文件。

---

# 6. 六种设计语言

## 6.1 设计语言清单

| 设计语言   | 主要目标            | 关键实现                             |
| ---------- | ------------------- | ------------------------------------ |
| Material   | Android、通用跨平台 | Material Theme、按钮、输入框、对话框 |
| Cupertino  | iOS 风格            | Cupertino Theme、原生风格导航和控件  |
| Fluent     | Windows 风格        | Fluent 主题、导航、菜单和控件        |
| macOS      | macOS 原生风格      | macOS 风格控件、窗口和菜单适配       |
| Yaru       | Ubuntu/Linux 风格   | Yaru 视觉语言与桌面控件              |
| Neumorphic | 柔和浮雕风格        | 浮雕表面、阴影和定制控件             |

每种设计语言都应具备自己的组件实现，而不是仅切换颜色和圆角。

例如，同一个统一按钮组件在不同设计语言下可以分别使用 Material、Cupertino 或 Fluent 的原生控件，也可以在某些组件上使用经过统一接口封装的自定义实现。

但不要求所有设计语言都在每个控件上完全复制原生实现。如果某种设计语言没有合适的原生控件，应采用最符合其视觉规则的实现。

## 6.2 设计语言与运行平台分离

必须区分：

- **运行平台：** Android、iOS、Windows、macOS、Linux、Android TV。
- **设计语言：** Material、Cupertino、Fluent、macOS、Yaru、Neumorphic。
- **交互模式：** Touch、Mouse、Keyboard、Remote。
- **布局模式：** Mobile、Desktop、TV。

它们是不同维度，不应混为一个枚举。

例如：

- Windows 可以使用 Fluent，也可以使用 Material。
- Android 可以使用 Material，也可以使用 Neumorphic。
- macOS 可以使用 macOS 风格，也可以使用 Material。
- Android TV 默认可以使用 Material 设计语言，但必须启用 TV 焦点与遥控器交互模式。
- 桌面 Linux 可以使用 Yaru，也可以使用其他设计语言。

建议定义：

```dart
enum LiveDesignLanguage {
  material,
  cupertino,
  fluent,
  macos,
  yaru,
  neumorphic,
}

enum LiveUiPlatform {
  android,
  ios,
  androidTv,
  windows,
  macos,
  linux,
  web,
}

enum LiveInputMode {
  touch,
  mouse,
  keyboard,
  remote,
}

enum LiveLayoutMode {
  mobile,
  desktop,
  tv,
}
```

实际项目可以根据现有的 `TargetPlatform`、TV 检测逻辑和设备能力进一步精简。

## 6.3 统一主题配置

建议通过一个统一配置对象控制 UI：

```dart
@immutable
class LiveUiConfiguration {
  const LiveUiConfiguration({
    required this.designLanguage,
    required this.layoutMode,
    this.enableAnimations = true,
    this.enableFocusEffects = true,
  });

  final LiveDesignLanguage designLanguage;
  final LiveLayoutMode layoutMode;
  final bool enableAnimations;
  final bool enableFocusEffects;
}
```

主题配置还应支持：

- Light / Dark。
- 主色、强调色和语义颜色。
- 页面背景。
- 卡片背景。
- 弹窗背景。
- 分隔线。
- 字体与文字层级。
- 圆角。
- 阴影。
- 动画时长。
- 焦点颜色和焦点边框。
- TV 焦点缩放。
- 触控和遥控器的控件尺寸。

不要将这些设置散落在业务页面中。

---

# 7. 统一组件契约

## 7.1 设计原则

业务层只调用 `live_uikit` 的统一组件。

例如：

```dart
LiveButton(
  label: 'Play',
  onPressed: onPlay,
);
```

业务代码不应根据当前设计语言写出六套分支。

推荐为常用组件提供稳定的参数契约：

- `LiveButton`
- `LiveIconButton`
- `LiveTextField`
- `LiveSearchField`
- `LiveCard`
- `LiveDialog`
- `LiveMenu`
- `LiveNavigation`
- `LiveTabBar`
- `LiveListTile`
- `LiveSwitch`
- `LiveCheckbox`
- `LiveRadio`
- `LiveSlider`
- `LiveProgressIndicator`
- `LiveLoadingView`
- `LiveErrorView`
- `LiveEmptyView`

各组件必须明确支持的参数和语义。

例如，统一按钮契约应明确：

- 文本或图标。
- 启用状态。
- 加载状态。
- 点击回调。
- 主按钮、次按钮和危险操作等语义。
- 键盘激活方式。
- TV 焦点反馈。
- 最小可交互尺寸。

不同设计语言可以使用不同视觉表现，但不应随意改变这些语义。

## 7.2 不要创建一个巨型万能组件

不建议：

```dart
LiveWidget(
  type: 'button',
  design: 'material',
  mode: 'tv',
  style: ...,
);
```

也不建议所有控件共享一个包含几十个可空参数的类。

推荐采用：

1. 稳定的公共组件 API。
2. 设计语言专属的内部实现。
3. 统一主题和设计令牌。
4. 独立的 TV 焦点和输入适配。
5. 仅在真正存在差异时暴露可选能力。

---

# 8. `fluttersdk_wind` 集成方案

目标依赖：

```yaml
dependencies:
  fluttersdk_wind: ^1.8.1
```

Wind UI 应作为 `live_uikit` 的 UI 实现与设计系统资源之一，而不是直接成为所有业务页面的唯一 UI 入口。

## 8.1 集成目标

- 复用 Wind UI 已有的主题、组件和布局能力。
- 统一与 Material、Cupertino、Fluent、macOS、Yaru、Neumorphic 的组件契约。
- 避免重复实现已经成熟的控件。
- 避免业务层直接依赖 Wind UI 的内部类型。
- 统一主题、尺寸、字体和响应式行为。
- 明确 Wind UI 与 TV 焦点导航的兼容边界。

## 8.2 集成前必须确认

在正式接入前，应审查实际安装版本的：

- 导出的公共 API。
- 主题和样式配置。
- 组件覆盖范围。
- 与 Material 的关系。
- 响应式布局机制。
- 字体与尺寸缩放规则。
- 桌面端支持。
- 键盘与焦点支持。
- Android TV 支持情况。
- 与现有 Flutter SDK 版本的兼容性。

不要仅因为 Wind UI 已经提供某个组件，就认定它适合所有设计语言。

## 8.3 推荐策略

将 Wind UI 作为内部实现或基础组件来源。

```text
Application Page
       │
       ▼
   live_uikit
       │
       ▼
Component Contract
       │
       ├── Material Implementation
       ├── Cupertino Implementation
       ├── Fluent Implementation
       ├── macOS Implementation
       ├── Yaru Implementation
       ├── Neumorphic Implementation
       └── Wind-backed Implementation
```

这里的 Wind-backed Implementation 不一定对应一种独立的设计语言。

如果 Wind UI 的某个控件本质上属于 Material 风格，可以将其作为 Material 实现的内部基础，而不是重复建立一套第七种设计语言。

如果 Wind UI 与统一 API 的语义不匹配，则应封装适配层，不要为了使用它而改变整个组件体系。

---

# 9. 主题、样式与背景系统

## 9.1 设计令牌

建议集中管理：

```text
Design Tokens
├── Colors
├── Typography
├── Spacing
├── Sizing
├── Radius
├── Elevation
├── Shadows
├── Motion
├── Breakpoints
├── Focus
└── Opacity
```

设计令牌负责表达语义，而不是让业务页面直接使用大量硬编码数值。

例如：

- `surface`
- `surfaceElevated`
- `surfaceVariant`
- `primary`
- `secondary`
- `outline`
- `error`
- `success`
- `focus`
- `textPrimary`
- `textSecondary`

不同设计语言可以映射到不同的具体颜色、字体和阴影。

## 9.2 背景系统

`live_uikit` 应提供统一背景能力：

- 纯色背景。
- 渐变背景。
- 图片背景。
- 半透明背景。
- 毛玻璃效果。
- Neumorphic 背景。
- 页面级背景。
- 卡片级背景。
- TV 大屏背景。
- 背景模糊与遮罩。

背景系统应处理性能与平台差异。

例如，模糊效果在低性能设备或 Android TV 上可能带来额外开销，因此应允许按设备能力禁用或降低效果。

不要让每个业务页面自己实现背景渐变、遮罩和模糊。

## 9.3 动态主题

建议支持：

- Light。
- Dark。
- System。
- 用户自定义主色。
- 设计语言切换。
- 组件密度。
- TV 专用焦点配色。
- 不同窗口的独立布局状态。

主题变化不应导致播放会话、直播间状态或弹幕连接重新初始化。

---

# 10. TV UI 专项架构

## 10.1 现有项目

现有 TV 项目路径：

```text
F:\pure_live_TV\pure_live_TV
```

它是重要的现有实现来源，不能在没有审查的情况下直接重写。

先检查：

- 现有页面结构。
- 遥控器事件处理。
- 焦点管理。
- 直播列表。
- 直播间播放页。
- 弹幕覆盖层。
- 播放器控制栏。
- 主题。
- 字体和尺寸适配。
- 路由。
- 现有 TV 特有业务逻辑。

目标是复用已有实现中成熟的 TV 交互和布局经验，并将通用能力迁移到新的应用架构中。

不建议一开始就将整个 TV 应用改成另一套 UI。

## 10.2 TV 不是放大的桌面 UI

TV 应采用独立的布局与交互模式，但仍复用统一业务组件契约。

必须支持：

- 遥控器方向键。
- 确认键。
- 返回键。
- 焦点移动。
- 焦点记忆与恢复。
- 焦点边界。
- 焦点可见性。
- 焦点缩放或高亮。
- 列表滚动跟随焦点。
- 对话框焦点管理。
- 页面切换后的焦点恢复。
- 播放器控制栏的焦点导航。
- 弹幕开启状态下的遥控器操作。
- 搜索输入与软键盘。
- 避免焦点陷阱。
- 失焦和禁用状态。
- 大屏文字与点击区域。

## 10.3 TV 焦点基础设施

建议将通用焦点基础设施放在：

```text
live_uikit/src/
├── focus/
└── input/
```

包括：

- 焦点范围。
- 焦点边界。
- 焦点导航策略。
- 焦点历史与恢复。
- 遥控器按键到动作的映射。
- 焦点动画。
- 焦点高亮。
- 可聚焦组件基类或组合器。

不要让每个业务页面各自实现一套 D-pad 逻辑。

## 10.4 焦点与设计语言分离

焦点行为属于交互能力，而不是 Material 或 Fluent 的专属功能。

例如：

```text
LiveButton
   │
   ├── Material Visual
   ├── Cupertino Visual
   ├── Fluent Visual
   └── Neumorphic Visual
          │
          ▼
     Focus Adapter
          │
          ▼
     Keyboard / Remote
```

每个组件都应遵循统一的可聚焦语义，但具体的焦点描边、阴影、动画和缩放由主题决定。

## 10.5 TV 布局规范

建议提供：

- `LiveTvScaffold`
- `LiveTvNavigation`
- `LiveTvContentGrid`
- `LiveTvFocusableCard`
- `LiveTvPlayerControls`
- `LiveTvDialog`
- `LiveTvSearchField`

这些组件属于 `live_uikit` 的 TV 专用布局能力，不应将整套 TV 页面逻辑复制进每种设计语言。

如果现有 Flutter 项目已经具备等价能力，应优先复用而不是重复创建。

---

# 11. 响应式与尺寸体系

## 11.1 多平台布局

同一个业务页面应根据布局模式调整结构：

- Mobile：单列、底部导航、触控优先。
- Desktop：侧边导航、窗口布局、鼠标与键盘。
- TV：大卡片、远距离可读文字、遥控器焦点导航。

不要仅根据屏幕宽度判断所有设备行为。

布局选择还应考虑：

- 输入设备。
- 当前窗口尺寸。
- TV 设备能力。
- 可用安全区域。
- 是否存在鼠标或键盘。
- 窗口是否处于窄屏状态。

## 11.2 尺寸缩放

应避免将所有字体和控件尺寸统一绑定到单一屏幕宽度比例。

推荐区分：

- 字体尺寸。
- 图标尺寸。
- 控件高度。
- 页面间距。
- 卡片尺寸。
- TV 专用尺寸。
- 桌面紧凑模式。
- 用户系统字体缩放。

字体缩放不应导致 TV 上的文字过小，也不应让移动端的按钮在高分辨率设备上失去合理比例。

尺寸系统应兼顾：

- 可读性。
- 最小可交互区域。
- 屏幕密度。
- 系统字体缩放。
- 布局约束。

---

# 12. 应用主题选择与组件注册

建议通过应用级配置决定设计语言：

```text
User Preferences
       │
       ▼
LiveUiConfiguration
       │
       ▼
Theme Resolver
       │
       ▼
Design Language Registry
       │
       ├── Material
       ├── Cupertino
       ├── Fluent
       ├── macOS
       ├── Yaru
       └── Neumorphic
```

应用启动时：

1. 读取设计语言设置。
2. 确认当前平台能力。
3. 选择布局模式。
4. 构建主题。
5. 注册组件实现。
6. 构建应用 UI。

运行时切换设计语言时，不应重建与 UI 无关的业务服务。

建议优先使用显式依赖注入和配置对象，避免在组件内部到处访问全局可变单例。

如果某个设计语言不支持特定组件，可以回退到统一基础实现，但必须保证语义一致，并明确记录回退策略。

---

# 13. 公共 Package 规范

每个 Package 应有清晰的公共入口。

例如：

```text
lib/
├── live_sites.dart
├── live_playback.dart
├── live_interaction.dart
├── live_library.dart
├── live_iptv.dart
├── live_preferences.dart
└── live_uikit.dart
```

内部实现放在 `src/`，避免外部 Package 依赖内部路径。

不要将所有内部类型导出到公共入口。

公开 API 应满足：

- 命名稳定。
- 依赖明确。
- 不泄漏平台私有实现。
- 不依赖 UI 上下文。
- 不暴露不必要的第三方库类型。
- 不重复定义相同的公共模型。
- 不通过循环依赖解决模块调用。
- 为可能变更的实现保留适配层。

---

# 14. 依赖管理原则

## 14.1 UI 依赖

`live_uikit` 可以依赖实际使用的 UI 框架和设计语言库。

在确定依赖前，需要审查：

- 与当前 Flutter SDK 的兼容性。
- Android TV 和桌面端支持。
- 组件覆盖率。
- 主题能力。
- 焦点管理能力。
- 包的维护状态。
- 依赖树和平台插件。
- 与 Wind UI 的 API 兼容性。

六种设计语言不意味着必须让每个业务 Package 都依赖六套 UI 库。

**只有 `live_uikit` 应负责这些设计语言依赖，业务 Package 不应直接导入它们。**

## 14.2 业务依赖

- `live_sites` 负责平台领域。
- `live_playback` 依赖 `live_sites` 和 `media_core`。
- `live_interaction` 复用公共消息模型。
- `live_library` 负责直播间记录。
- `live_iptv` 负责 IPTV 直播源。
- `live_preferences` 负责配置。
- `live_uikit` 负责 UI。
- 应用组合根负责组装所有模块。

不要让 `live_uikit` 依赖 `live_sites`，也不要让 `media_core` 依赖应用业务。

---

# 15. 开发、提交与推送流程

## 15.1 开发约束

按照项目要求：

- 不新增测试模块。
- 不新增 Demo 应用。
- 不为了验证组件而创建独立 Demo Package。
- 不为了迁移而复制整个应用。
- 不重新实现已经存在的播放器基础设施。
- 不创建只有空接口的占位模块。
- 不在没有明确需求时增加新的共享 Package。
- 代码注释全部使用英文。
- 所有模块应有明确的公共 API 和职责说明。

## 15.2 实现与推送

用户要求模块实现完成后直接提交并推送 Git。

推荐流程：

1. 检查当前分支与工作区。
2. 确认本次变更范围。
3. 按模块完成实现。
4. 删除临时文件和不需要的 Demo 代码。
5. 整理格式与生成文件。
6. 按仓库已有流程进行必要的静态分析、构建或 CI 检查。
7. 检查 Git diff，避免误提交用户其他改动。
8. 生成清晰的提交信息。
9. 提交并推送到明确的目标分支。
10. 汇报提交号、推送分支和变更摘要。

不新增测试代码与不做任何质量检查是两件不同的事。这里遵循“不新增测试和 Demo”的要求，但不应因为该要求而跳过仓库现有的必要发布检查。

推送前不得擅自重置工作区、覆盖用户修改或删除未纳入本次任务的文件。

---

# 16. 实施阶段与顺序

## Phase 1：整理业务模块

- 完成 `live_sites`。
- 确定 `live_playback` 与 `media_core` 的接口。
- 明确 `live_interaction` 的独立边界。
- 整理 `live_library` 的持久化职责。
- 明确 `live_iptv` 的范围。
- 整理现有 `live_preferences`。
- 每个模块实现完成后按约定提交和推送。

## Phase 2：建设 `live_uikit` 基础

先实现：

1. 设计语言枚举。
2. 运行平台与布局模式区分。
3. 统一主题配置。
4. 颜色、字体、间距、圆角和阴影令牌。
5. 页面背景系统。
6. 统一按钮、输入框、卡片、菜单和对话框。
7. 统一加载、错误和空状态。
8. 组件实现注册与主题解析。

这一阶段优先确保公共组件 API 稳定，而不是一次性实现所有复杂控件。

## Phase 3：接入六种设计语言

按以下顺序逐步接入：

1. Material。
2. Cupertino。
3. Fluent。
4. macOS。
5. Yaru。
6. Neumorphic。

同时审查并接入 `fluttersdk_wind: ^1.8.1`。

如果 Wind UI 与某种设计语言重叠，应优先作为该设计语言的内部组件实现，而不是重复建立一套独立设计系统。

## Phase 4：TV 适配

- 审查 `F:\pure_live_TV\pure_live_TV`。
- 提取可复用的 TV 焦点基础设施。
- 建立 TV 布局模式。
- 统一遥控器事件。
- 统一焦点高亮和焦点恢复。
- 迁移直播列表与播放控制栏的通用交互。
- 保留必要的 TV 专属页面结构。
- 避免把 TV 页面直接放大成桌面布局。

## Phase 5：应用接入

- 应用启动时加载 UI 配置。
- 使用 `live_uikit` 组装页面。
- 接入业务 Package。
- 支持主题切换。
- 支持设计语言切换。
- 支持移动端、桌面端和 TV 布局。
- 保持播放会话与主题状态解耦。
- 完成实现后按约定直接提交并推送。

---

# 17. 最终验收标准

## 业务模块

- [ ] `live_sites` 职责清晰。
- [ ] `live_playback` 不重复实现播放器内核。
- [ ] `media_core` 保持独立。
- [ ] `live_interaction` 不重复定义公共消息模型。
- [ ] `live_library` 不负责平台 API 和 UI。
- [ ] `live_iptv` 只覆盖 IPTV 直播。
- [ ] `live_preferences` 不重复建设现有设置系统。

## `live_uikit`

- [ ] 统一设计令牌。
- [ ] 统一主题配置。
- [ ] 统一背景系统。
- [ ] 统一公共组件契约。
- [ ] Material 实现。
- [ ] Cupertino 实现。
- [ ] Fluent 实现。
- [ ] macOS 实现。
- [ ] Yaru 实现。
- [ ] Neumorphic 实现。
- [ ] `fluttersdk_wind` 集成策略明确。
- [ ] 业务页面不直接依赖具体设计语言的内部实现。

## TV

- [ ] 复用现有 TV 项目的有效实现。
- [ ] 遥控器方向键。
- [ ] 确认键和返回键。
- [ ] 焦点导航。
- [ ] 焦点恢复。
- [ ] 焦点可见性。
- [ ] TV 大屏布局。
- [ ] 播放器控制栏交互。
- [ ] 不依赖触摸才能完成核心操作。
- [ ] 主题切换不影响播放会话。

## 工程规范

- [ ] 无不必要的重复 Package。
- [ ] 无循环依赖。
- [ ] 无未经审查的第三方库 API 假设。
- [ ] 无对其他模块内部路径的随意依赖。
- [ ] 无意外删除或覆盖用户现有代码。
- [ ] 不新增测试与 Demo 交付模块。
- [ ] 按既定流程提交并推送。
- [ ] 所有代码注释使用英文。

---

# 18. 最终架构原则

PureLive 的最终目标不是建立尽可能多的 Package，而是建立稳定、可持续维护的直播应用架构。

- 直播业务保持专注。
- `media_core` 专注媒体内核。
- `live_playback` 专注播放编排。
- `live_sites` 专注直播平台。
- `live_interaction` 专注通用互动。
- `live_library` 专注用户的直播间管理。
- `live_iptv` 专注 IPTV 直播源。
- `live_preferences` 专注直播设置。
- `live_uikit` 专注多设计语言、主题、组件与跨平台交互。
- `apps/pure_live` 负责组装应用。
- TV 使用统一业务能力和组件契约，同时拥有独立的遥控器交互与布局规则。

**核心目标：同一套直播业务，多种设计语言，多种设备形态，一个可持续演进的 Flutter 工程体系。**
