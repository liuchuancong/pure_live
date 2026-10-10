# PureLive v2 Flutter 技术栈与公共能力选型

> 状态：候选基线，落地前需完成版本解析、平台编译与集成验证。  
> 原则：成熟库优先、边界清晰、减少重复封装、允许替换。  
> 适用范围：Android、Android TV、iOS、Windows、macOS、Linux。

## 1. 选型原则

1. **优先使用维护活跃且职责单一的库**，不因功能丰富而引入过重依赖。
2. **公共模块统一入口，底层库保持可替换**。业务功能不得直接散布调用底层网络、文件、通知或弹窗库。
3. **不把所有平台强行做成相同 UI**。统一设计令牌、语义与组件 API，平台外观由适配层决定。
4. **不要重复实现成熟库已有能力**。只封装项目策略、边界和统一 API。
5. **跨平台支持必须实测**。Pub 上能解析不代表目标平台都能运行。
6. **外部扩展按不可信输入处理**，特别是 TVBox、LX Music、直播站点脚本与远程配置。
7. **版本以仓库锁文件为准**。本文不把未经当前 CI 验证的版本号当作最终锁定版本。

## 2. 推荐总览

| 领域 | 推荐方案 | 优先级 | 说明 |
|---|---|---:|---|
| Flutter/Dart 工作区 | Dart Pub Workspace；Melos 可选 | 必选 | Pub Workspace 是依赖解析和工作区基础，Melos 只做脚本编排 |
| 路由 | `go_router` | 必选 | 声明式路由、深链接、导航守卫由项目层规范化 |
| 状态管理/依赖注入 | `flutter_riverpod` | 必选 | UI 状态、依赖组合、异步状态 |
| 业务结果/错误组合 | `fpdart` | 推荐 | `Either`、`Option`、`TaskEither`；避免全项目强制函数式化 |
| 数据类/联合类型 | `freezed` + `json_serializable` | 推荐 | DTO、不可变状态、联合类型；生成文件策略写入 CI 规范 |
| HTTP | `dio` | 必选 | 核心 HTTP 引擎 |
| 声明式 REST API | `retrofit` + `retrofit_generator` | 推荐 | 仅对稳定、结构化 API 使用 |
| 网络日志 | `talker` + `talker_dio_logger` | 推荐 | 统一诊断；生产环境脱敏 |
| 网络缓存 | `dio_cache_interceptor` | 按需 | 仅对适合缓存的请求启用，避免错误缓存媒体和动态接口 |
| Cookie | `cookie_jar` + `dio_cookie_manager` | 按需 | 网站/扩展需要 Cookie 时使用，按扩展隔离 |
| 网络状态 | `connectivity_plus` | 按需 | 只能反映连接类型/状态，不能保证服务器可达 |
| 路径拼接 | `path` | 必选 | 跨平台路径操作，不手写分隔符 |
| 应用目录 | `path_provider` | 必选 | 文档、缓存、支持目录等系统路径 |
| 文件/目录选择 | `file_selector` | 推荐 | 跨平台文件选择；平台能力需逐项验证 |
| 安全存储 | `flutter_secure_storage` | 推荐 | 令牌、密钥等小型秘密；需验证各平台实现与备份行为 |
| 简单偏好设置 | `shared_preferences` | 推荐 | 非敏感小型设置；不存复杂业务数据 |
| 结构化本地数据库 | `drift` | 推荐 | SQLite、查询、迁移、事务 |
| 图片缓存 | `cached_network_image` | 按需 | 结合统一缓存策略；不同平台实现需验证 |
| 日志 | `talker` 或 `logging` 二选一为主 | 推荐 | 避免多套日志体系并存 |
| 崩溃/错误上报 | `sentry_flutter` 或项目已有方案 | 按需 | 明确隐私、脱敏和用户授权 |
| 多语言 | `easy_localization` | 必选 | JSON 资源；CI 检查缺失键与格式 |
| 自适应布局 | Flutter 原生 `LayoutBuilder`、`MediaQuery`、`SafeArea` | 必选 | 先用原生能力建立断点和布局规则 |
| 尺寸适配 | `flutter_screenutil_plus` | 现有项目优先 | 统一尺寸入口；不要让 `.sp` 与自定义缩放递归叠加 |
| UI 设计系统 | `flutter_sdk_wind` | 必选（项目层） | 项目统一组件入口和主题令牌 |
| 通知 Toast | `toastification` | 推荐 | 由 `AppNotice` 门面统一调用 |
| 对话框/底部弹层 | Flutter 原生 `showDialog`、`showModalBottomSheet` + Wind 封装 | 必选 | 统一 API、尺寸、语义和可访问性 |
| 加载/空/错误状态 | Wind 自有组件 | 必选 | 统一样式，不再额外引入多套状态 UI 库 |
| 图标 | `flutter_svg` + 一套统一图标策略 | 按需 | 不混用大量互不一致的图标包 |
| 动画 | Flutter 原生动画；复杂场景按需选 `flutter_animate` | 按需 | 避免动画依赖成为基础设施强制项 |
| 测试 | `flutter_test`、`test`、`mocktail` 或 `mockito` | 必选/按需 | 统一选择一种主要 Mock 方案 |
| 黄金图测试 | `golden_toolkit` 等 | 按需 | 多主题、多平台 UI 回归 |
| JSON Schema 校验 | 选定一个稳定实现或项目校验层 | 按需 | 扩展清单、导入配置与外部输入必须校验 |
| JS 扩展运行时 | `fjs` + 项目 `Extension Runtime API` | 必选（扩展功能） | 不让业务层直接依赖 fjs 内部 API |
| 媒体播放 | 独立 `media_core` + 平台适配器 | 必选 | 不将播放器绑定到 UI 框架 |
| 系统托盘 | `tray_manager` 等 | 桌面按需 | 仅桌面应用引入 |
| 窗口控制 | `window_manager` 等 | 桌面按需 | 与路由、业务状态解耦 |
| 系统文件打开/分享 | `url_launcher`、`share_plus` 等 | 按需 | 按平台能力和项目需求引入 |

## 3. 网络基础设施

### 3.1 推荐架构

```text
Feature / Provider / Service
          |
          v
   Network Facade
          |
          +-- API Client (Dio + optional Retrofit)
          +-- Extension Client (Dio, isolated policy)
          +-- Media/Download Client (Dio, Range/progress)
          +-- Update Client (Dio, manifest/checksum policy)
          |
          v
 Interceptors / Error Mapping / Redaction / Tracing
```

不要让全项目共用一个无差别配置的 Dio 实例。可以共享工厂与公共拦截器，但按用途创建不同客户端配置。

### 3.2 统一封装职责

项目网络模块只负责项目规则：

- 统一请求配置与超时默认值。
- 统一请求取消和生命周期。
- 统一错误映射，不把原始异常直接暴露给 UI。
- 统一日志、请求追踪与敏感信息脱敏。
- 统一代理、Cookie、请求头与证书策略的注册入口。
- 统一缓存与重试策略，但由每个客户端显式启用。
- 统一文件下载、进度、临时文件和校验流程。
- 支持测试注入 Adapter/Client。
- 对扩展请求按扩展 ID 隔离 Cookie、凭据、代理与权限。

### 3.3 错误模型

建议在基础层定义稳定的错误类型，例如：

- `NetworkFailure`
- `TimeoutFailure`
- `CancelledFailure`
- `UnauthorizedFailure`
- `NotFoundFailure`
- `RateLimitedFailure`
- `ServerFailure`
- `ParseFailure`
- `SecurityFailure`
- `UnknownFailure`

Repository/Domain 边界可以返回 `Future<Either<AppFailure, T>>`；仅当组合异步任务确实有价值时使用 `TaskEither`。统一规范，避免 `AsyncValue<Either<...>>`、`Result<Either<...>>` 等无意义的多层包装。Riverpod 的 `AsyncValue` 主要负责 UI 异步状态，`Either` 主要负责业务操作结果。

### 3.4 安全规则

- 不向第三方扩展请求自动注入应用认证令牌。
- 日志不得输出密码、完整 Cookie、令牌、签名 URL 或敏感查询参数。
- 对外部 URL 防范 SSRF、私网地址、重定向绕过和 DNS 解析变化。
- 不对非幂等请求盲目重试。
- 取消请求必须能传递到实际网络任务。
- 不默认缓存认证响应、动态签名链接和播放地址。
- 文件下载先写临时文件，验证大小/校验和后再原子替换。
- 扩展运行时和网络层分别实施超时、并发、响应体大小限制。

## 4. 文件路径与存储

### 4.1 路径库组合

- `path`：拼接、规范化、解析路径。
- `path_provider`：获取系统分配的应用目录。
- `file_selector`：系统文件选择器。
- `dart:io`：文件读写与目录操作，放在可使用 IO 的平台实现层。
- Web 若未来支持，必须通过条件实现或独立抽象处理，不应直接假设 `dart:io` 可用。

不要在业务代码里写 `'$root\\cache\\$name'` 或依赖 Windows 分隔符。使用 `package:path/path.dart` 的 `join`、`basename`、`extension` 等 API。

### 4.2 推荐目录职责

```text
AppPaths
  ├── documentsDirectory
  ├── supportDirectory
  ├── cacheDirectory
  ├── downloadsDirectory (若平台允许/用户选择)
  └── temporaryDirectory

Storage
  ├── PreferencesStore      # 简单设置
  ├── SecureStore           # 小型秘密
  ├── Database              # 结构化业务数据
  ├── FileRepository        # 文件导入/导出
  └── CacheRepository       # 可重建缓存
```

路径服务应暴露语义化目录，而不是把任意原始路径开放给所有 Feature。缓存可以清理，用户数据不能被当作缓存清除。数据库迁移、备份与恢复必须有版本号和失败回滚策略。

## 5. 六种 UI 风格的架构

目标外观：

- Material
- Cupertino
- Fluent
- macOS
- Neumorphic
- Yaru

### 5.1 不要把六套 UI 库直接暴露给 Feature

推荐结构：

```text
Feature Widgets
      |
      v
Wind Design System
  ├── Design Tokens
  ├── Semantic Components
  ├── Theme Resolver
  ├── Adaptive Layout
  └── Platform UI Adapters
       ├── Material
       ├── Cupertino
       ├── Fluent
       ├── macOS
       ├── Neumorphic
       └── Yaru
```

Feature 只依赖 Wind 提供的 `WindButton`、`WindDialog`、`WindTextField`、`WindScaffold` 等语义组件，不应直接 import 六种风格的具体包。

### 5.2 主题解析规则

主题系统至少区分：

1. **ThemeFamily**：Material、Cupertino、Fluent、macOS、Neumorphic、Yaru。
2. **ColorScheme**：浅色、深色、跟随系统或动态色。
3. **Density**：紧凑、标准、宽松。
4. **PlatformProfile**：Android 手机、Android TV、iOS、Windows、macOS、Linux。
5. **Accessibility**：文本缩放、高对比度、减少动态效果。
6. **InputMode**：触摸、鼠标键盘、遥控器/D-pad。

ThemeFamily 不应只根据操作系统硬编码推断。用户可以手动选择；系统默认值只是建议。

### 5.3 风格库选型建议

| 风格 | 方案 | 说明 |
|---|---|---|
| Material | Flutter `Material` 原生组件 | 基础覆盖面最大，作为公共语义组件的主要参考 |
| Cupertino | Flutter `Cupertino` 原生组件 | 适合 iOS 风格适配 |
| Fluent | 评估 `fluent_ui` | 核对桌面支持、主题一致性、组件完整度与更新活跃度 |
| macOS | 评估 `macos_ui` | 适合 macOS 特有控件；不应成为所有桌面平台的基础依赖 |
| Neumorphic | 仅作为可选外观层 | 控件语义、焦点、可访问性和深色模式要自行验证；不要让它支配整体架构 |
| Yaru | 评估 `yaru` | 适合 Linux/Yaru 风格；验证 Flutter 版本兼容与维护状态 |

**重要：** 不要仅因包名和风格匹配就认定它是最佳方案。每个适配包都必须经过同一套验证：最近发布/提交、未解决问题、Flutter/Dart SDK 约束、目标平台编译、焦点/键盘、无障碍、深色模式和主题扩展能力。

### 5.4 Design Tokens

建议统一定义：

- 颜色：`surface`、`surfaceVariant`、`primary`、`error`、`outline` 等语义颜色。
- 间距：`space2`、`space4`、`space8`、`space12`、`space16`、`space24`、`space32`。
- 圆角：`radiusSmall`、`radiusMedium`、`radiusLarge`。
- 高度与尺寸：按钮、输入框、图标按钮、列表项、工具栏。
- 动效：持续时间、曲线、减少动态效果规则。
- 字体：标题、正文、辅助文字、等宽文本、最小可读字号。
- 焦点：默认、聚焦、选中、禁用、按下状态。
- 密度：TV/遥控器、桌面鼠标、移动触摸分别定义交互尺寸。

所有风格适配器映射这些语义令牌，不让 Feature 自己写一套 Material 常量、另一套 Fluent 常量。

## 6. 尺寸与响应式布局

### 6.1 推荐规则

优先级如下：

1. 用 `LayoutBuilder` 根据实际可用宽度选择布局。
2. 用 `MediaQuery` 获取屏幕、文本缩放、系统边距等环境信息。
3. 用 `SafeArea` 或明确的 `viewPadding` 规则处理系统安全区域。
4. 用 Wind Design Tokens 统一间距、圆角、控件尺寸。
5. 仅在需要设计稿比例适配的场景使用 `flutter_screenutil_plus`。

### 6.2 不要把 ScreenUtil 当作响应式布局引擎

- 手机、平板、桌面、TV 应使用不同断点和布局策略。
- 桌面布局不应只按屏幕宽度同比放大所有控件。
- 文本缩放与盒子尺寸缩放分离。
- 不要同时对同一个文本尺寸应用 `.sp`、自定义 scale 和 MediaQuery 文本缩放。
- 不允许尺寸 getter 互相调用造成递归。
- 为 TV 设计 D-pad 焦点环、焦点可见性、遥控器导航顺序和足够大的点击区域。

可从以下断点起步，再按实际 UI 测试调整：

| 布局类别 | 初始宽度参考 | 典型布局 |
|---|---:|---|
| Compact | `< 600` | 单栏、底部导航或窄侧栏 |
| Medium | `600–839` | 双栏/导航栏 |
| Expanded | `840–1199` | 侧栏 + 主内容 |
| Large | `>= 1200` | 多栏、可调节面板 |

断点不是平台判定规则。Android TV 即使宽度很大，也应使用 TV 的焦点和遥控器交互配置。

## 7. 弹窗、通知、加载和空状态

### 7.1 统一门面

建议在 Wind 中提供：

```dart
abstract interface class AppNotice {
  void success(String message);
  void info(String message);
  void warning(String message);
  void error(String message);
}

abstract interface class AppDialog {
  Future<T?> show<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  });
}

abstract interface class AppLoading {
  Future<T> during<T>(
    Future<T> Function() task, {
    String? message,
  });
}
```

以上仅是接口方向示例；实际签名应根据 Wind 的导航上下文、可访问性、TV 焦点管理和测试策略确定。

### 7.2 选型

- Toast/通知：优先评估 `toastification`，统一通过 `AppNotice` 调用。
- 对话框：Flutter 原生 Dialog + Wind 样式适配，不额外引入另一套完整 Dialog 框架。
- 底部弹层：Flutter 原生 `showModalBottomSheet` + Wind 包装。
- 加载状态：Wind 的 `WindLoadingOverlay`、`WindProgress`。
- 空状态/错误状态：Wind 的 `WindEmptyState`、`WindErrorState`。
- 桌面窗口内通知、TV 反馈和移动端提示可以采用不同展示形式，但对外调用 API 保持一致。

避免同时引入多个 Toast、Snackbar、Dialog 和 Loading 库，否则会出现主题、堆叠顺序、导航生命周期与测试行为不一致。

## 8. 状态管理、错误处理与模型

### Riverpod

负责：

- Provider/依赖注入。
- Feature 状态和异步 UI 状态。
- 生命周期与资源释放。
- 测试时覆盖依赖。

### fpdart

负责：

- `Either<Failure, T>` 业务结果。
- `Option<T>` 有明确语义的可选结果。
- 需要组合异步流程时使用 `TaskEither`。

### Freezed / JSON

- `freezed`：不可变模型和联合类型。
- `json_serializable`：JSON 编解码。
- 外部数据必须进行运行时校验，不能把 `json_serializable` 当作完整输入校验器。
- 对远程扩展清单、TVBox 配置和音乐源响应定义大小限制、字段限制与版本兼容规则。

## 9. 本地化

采用 `easy_localization` + JSON，不采用 Flutter `gen-l10n`。

```text
apps/pure_live/assets/translations/
  ├── zh.json
  ├── en.json
  └── ja.json
```

规则：

- 应用 UI 字符串必须走本地化键。
- CI 检查 JSON 语法、重复键和语言之间的缺失键。
- 用户导入的 TVBox、直播源、音乐源内容属于外部内容，不自动翻译、不擅自改写。
- 本地化状态由 Settings/LocaleService 管理。
- 资源分拆应以已验证的加载方案为基础，不假设每个 Feature 的 JSON 都会自动合并。

## 10. 插件与扩展运行时

```text
Provider / Extension
        |
        v
Extension Gateway
        |
        v
Extension Runtime API
        |
        v
FJS Runtime Adapter
        |
        v
       fjs
```

要求：

- 业务层依赖 `ExtensionRuntime` 抽象，而非直接调用 fjs 内部 API。
- 兼容层负责请求、Cookie、加解密、二进制、压缩、回调、Promise 和错误转换。
- 对 drpy 的同步 `req` 语义与异步桥接分别设计，不假设二者天然等价。
- 每次执行都有超时、取消、并发数、输入/输出大小限制和诊断上下文。
- 对插件访问文件、网络、凭据、剪贴板和其他插件的能力实施显式授权。
- 验证 fjs 的实际目标平台支持、异步桥接、二进制数据、内存限制与崩溃恢复。
- “Verified” 不等于安全；导入脚本默认按不可信代码处理。

## 11. 包引入分级

### A 级：核心必需

- `dio`
- `path`
- `path_provider`
- `flutter_riverpod`
- `go_router`
- `easy_localization`
- `fpdart`
- `flutter_screenutil_plus`（项目已使用时）
- `drift`（需要结构化本地数据库时）
- `flutter_secure_storage`（确有秘密存储需求时）

### B 级：优先评估

- `retrofit` + `retrofit_generator`
- `talker` + `talker_dio_logger`
- `freezed` + `json_serializable`
- `file_selector`
- `toastification`
- `shared_preferences`
- `cached_network_image`
- `flutter_svg`

### C 级：按功能引入

- `dio_cache_interceptor`
- `cookie_jar` + `dio_cookie_manager`
- `connectivity_plus`
- `flutter_animate`
- `golden_toolkit`
- `tray_manager`
- `window_manager`
- `url_launcher`
- `share_plus`
- `sentry_flutter`

### 不建议

- 同时引入多个状态管理框架。
- 同时引入多个功能重叠的 HTTP 客户端。
- 业务 Feature 直接依赖所有 UI 风格库。
- 把所有网络请求塞进单个全局 Dio 且共享 Cookie。
- 把所有存储都放进 SharedPreferences。
- 把缓存目录与用户数据目录混用。
- 用一套屏幕比例公式解决所有平台的布局。
- 引入多个重复的 Toast、Dialog、Loading 库。
- 在未验证平台支持前，宣称某个 UI 库完整支持所有桌面和移动平台。

## 12. 推荐包边界

```text
packages/
  foundation/
    network/             # Dio 工厂、错误映射、日志脱敏、追踪
    filesystem/          # path/path_provider/file_selector 门面
    storage/             # preferences、secure store、数据库边界
    logging/             # 日志规范与敏感信息过滤
    diagnostics/         # 错误诊断与上报接口
    localization/        # easy_localization 初始化与 LocaleService

  ui/
    design_tokens/       # 语义颜色、间距、尺寸、圆角、动效
    wind/                # flutter_sdk_wind 的项目级入口
    adaptive/            # 断点、平台配置、输入模式
    overlays/            # Dialog、Notice、Loading、Empty/Error state

  ecosystem/
    extension_api/       # 与运行时无关的扩展 API
    extension_gateway/   # 生命周期、权限、请求路由
    extension_fjs/       # fjs 适配器
    external_tvbox/      # TVBox/drpy 兼容层
    external_lx_music/   # LX Music 音源兼容层

  services/
    download/
    backup/
    update/
    cache/
```

注意：以上是职责划分建议。若某个包暂时只有一个消费者，可先放在现有包的独立目录中，避免为了目录完整而过早拆包。

## 13. 维护与准入检查

每个新依赖进入仓库前必须记录：

- 解决的问题与为何不使用 Flutter/Dart 原生能力。
- 当前稳定版本、最低 Dart/Flutter 版本。
- 最近发布/提交与维护状态。
- 已知问题、许可证和传递依赖。
- Android、iOS、Windows、macOS、Linux 的支持矩阵。
- 是否有原生插件、平台通道、FFI 或额外构建步骤。
- 是否影响启动体积、应用体积、编译时间和运行时内存。
- 是否涉及网络、文件、凭据、遥测或隐私。
- 是否存在替代方案和退出路径。

CI 至少执行：

1. `dart pub get` 与锁文件检查。
2. `dart format --set-exit-if-changed .`
3. `flutter analyze`
4. `flutter test`
5. 关键平台构建。
6. 本地化 JSON 与缺失键检查。
7. 扩展清单/外部配置 fixture 校验。
8. 依赖许可证与过期依赖检查。
9. 关键网络、存储和主题适配层的契约测试。

## 14. 实施顺序

### P0：依赖与设计系统验证

- 锁定 Flutter/Dart SDK 和工作区策略。
- 对 `flutter_sdk_wind` 进行 API、主题、焦点和平台覆盖审查。
- 验证六种风格库的 SDK 约束和真实目标平台编译。
- 验证 `fjs` 运行时桥接和外部扩展兼容性。
- 建立依赖清单、准入规则和 CI 检查。

### P1：基础设施

- Network Facade、错误模型、日志脱敏。
- AppPaths、文件导入/导出与原子写入。
- Preferences、SecureStore、Database。
- Design Tokens、Theme Resolver、响应式断点。
- Dialog、Notice、Loading、Empty/Error state。

### P2：业务接入

- 先迁移稳定 REST API 到 Network Facade。
- 再迁移 Provider/Extension 请求并隔离 Cookie。
- 为 TV、桌面、移动端建立主题和输入模式测试。
- 迁移本地化与设置持久化。

### P3：持续治理

- 每次升级核心依赖执行兼容性构建。
- 维护平台能力矩阵。
- 记录 ADR 解释重要选型变化。
- 定期检查上游发布、未解决问题和安全公告。

## 15. 最终结论

PureLive v2 应采用“成熟库做底层，项目层做统一策略”的路线：

- Dio 做网络引擎，项目 Network Facade 统一策略。
- `path`、`path_provider`、`file_selector` 分别处理路径、目录和文件选择。
- Riverpod 管状态，fpdart 管业务结果，避免职责重叠。
- `easy_localization` 管 JSON 本地化。
- `flutter_screenutil_plus` 只承担必要的设计稿尺寸适配，响应式布局以 Flutter 原生能力和断点为主。
- `flutter_sdk_wind` 作为统一设计系统入口，六种风格通过适配层实现。
- Toast、Dialog、Loading、空状态统一由 Wind 门面提供。
- fjs 通过独立 Runtime Adapter 接入扩展生态。
- 所有依赖以锁文件、平台构建和契约测试作为最终准入依据，而不是只看 pub.dev 热度。
