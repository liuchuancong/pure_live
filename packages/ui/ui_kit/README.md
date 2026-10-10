# pure_live_ui_kit

> 职责:组件底座 + 统一门面(通知/对话框/加载),以及把设计令牌送进 widget 树的那条接缝。
> 令牌本身在 `ui/design`(纯 Dart);这里只负责"读得到"。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `src/tokens_theme.dart` | `DesignTokensTheme`(`ThemeExtension`)+ `context.designTokens` / `context.themeTokens`、`rolesOfScheme`、`platformProfileOf` / `targetPlatformFor`、`MotionSize` | 密度、输入模式、焦点粗细、动效预算在 `ThemeData` 里没有对应槽位;没有这条接缝,每个组件只能各自猜一个数 |
| `src/app_facade.dart` | `AppNotice` / `AppDialog` / `AppLoading` 接口 + `SilentNotice` | 技术栈 §7 的"统一门面";feature 只认接口,呈现由宿主绑 |
| `src/poster_card.dart` | `PosterCard` / `CoverImage` | 全仓重复最多的元素,尺寸必须只有一处定义 |
| `src/status_views.dart` | `EmptyStateView` / `ErrorRetryView` / `SectionHeader` | 状态页每个 feature 都要画一遍 |

## 令牌的读法

- `context.designTokens` 拿 `DesignTokens`;**没有安装 extension 时回退到平台默认值而不是抛**。
  抛会让一个组件只能在全应用主题里被预览,而回退最多是间距差几个像素。
- 文字一律走 `tokens.typeSize(role)`:十英尺可读下限在这里生效,不依赖某个风格把 `bodySmall` 建成 12 像素。
- 时长一律走 `styleTokens.duration(MotionSize.x)`;reduce-motion 时它是 0,意思是"不要动",不是"动快点"。
- 焦点环:`themeTokens.focusRing(color)` 返回 `BorderSide?`;`null` 是合法答案
  (该风格用自身 outline 表达焦点,再叠一层环等于在已经看得出的状态上加倍)。
- 角色→颜色由 `rolesOfScheme(scheme)` 给默认映射,风格可覆盖单个条目而不是替换整张表。
- `PosterCard.width` **现在真的被使用**(它此前被声明又被忽略:传与不传得到不同布局,而两者都没有报错)。
- `ErrorRetryView` 的 `title` / `retryLabel` 是可覆盖的参数(默认仍是中文)。底座组件把词写死,
  等于逼每个要翻译的 feature 复制这个组件。

## 依赖

允许:`ui/design` + L0 + theme;只有 ui_kit 可 import `fluttersdk_wind`。禁止:反向依赖、应用壳、`ui/adaptive`。

## 平台矩阵

Android / Android TV / Windows / iOS / Linux / macOS 同一套代码;TV 与手机的区别由 tokens 的 `InputMode` 表达,
不是由包里的宽度猜测(见 `platformProfileOf` 的注释:Flutter 把 Android TV 报成 android,宿主必须自己说)。

## 未验证

- **只过了静态分析**(`dart analyze`,0 issue)。按使用者的决定本轮**不跑 `flutter analyze`、不跑 `flutter test`、
  没上真机**,所以:extension 是否真的被 `MaterialApp` 的 theme 带下去、焦点环在各种控件上的实际观感、
  `typeSize` 下限在真实字号设置下的排版,**都未验证**。
- 图标尺寸(88/64/56)与 placeholder 尺寸是新写的经验值,没有对着截图核过。
- `AppNotice` / `AppDialog` / `AppLoading` 仍没有具体实现(宿主绑定属于拆壳波)。
