# pure_live_adaptive

> 职责:六风格注册表 —— 把**同一套 `DesignTokens`** 映射成六种 `ThemeData`,并安装 ui_kit 的 extension。
> 风格之间的差别只在外观(圆角、表面、控件形状),尺寸/密度/焦点/动效一律来自令牌。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `src/ui_style.dart` | `AdaptiveUiStyle`、`StyleEntry`、`AdaptiveStyleRegistry`(`themeFor(style, brightness, seed, {tokens})`) | 切风格是运行时行为,注册表是它唯一的选择点 |
| `src/app_background.dart` | 背景合层(color / image / video),读 `BackgroundConfig` | 主机的背景开关要有一个不认站点的落点 |

## 映射规则(共享部分,任何风格都不许覆盖)

`_applyTokens` 在风格工厂之后跑,所以风格改不掉这几件事 —— 这是本轮的重点:
以前切到 Fluent 就顺带切成了鼠标密度,TV 上跑 Fluent 变体就拿到 36 像素的按钮。

| 令牌 | 落到 ThemeData 的哪里 |
|---|---|
| `density` | `visualDensity`(standard / comfortable / compact;SDK 只保证这三个常量,不用 "large") |
| `input != pointer` | `materialTapTargetSize.padded`,否则 `shrinkWrap` |
| `height(button/input/iconButton)` | 四种按钮主题与 `iconButtonTheme` 的 `minimumSize`、`inputDecorationTheme.contentPadding` |
| `height(toolbar)` | `appBarTheme.toolbarHeight` |
| `typeSize(role)` | `textTheme` 的六个角色(可读下限从这里进全局) |
| `gapBetween(listItem)` | `listTileTheme.minVerticalPadding` |
| `focus` | `focusColor` + 由 ui_kit 的 `focusRing` 画的边框(extension 里带,组件自己读) |
| `motion.scaleOnFocusAllowed == false` | `splashFactory: NoSplash` |

**没映射的**:路由转场。`PageTransitionsTheme` 对没列出的平台会回退到默认 builder,
给空 map 等于"继续动",与"不要动"相反 —— 所以要抑制转场的宿主得自己给 `Navigator` 传零时长。

## 依赖

允许:`ui/design`(层内叶子)+ `ui/ui_kit`(次序 design → ui_kit → adaptive)+ L0 + theme。
禁止:feature/app 反向依赖、providers。

## 平台矩阵

Android / Android TV / Windows / iOS / Linux / macOS。TV 由宿主声明的 `PlatformProfile.androidTv` 表达,
**不由屏宽猜**(`platformProfileOf` 的注释写了为什么)。

## 未验证

- **只过了静态分析**(`dart analyze packages/ui` 与 `dart analyze apps/pure_live` 均 0 issue)。
  按使用者的决定本轮不跑 `flutter analyze` / `flutter test`,没有真机、没有截图对比。
- 六个风格当前仍是"同一 Material 3 + 不同装饰"的变体;fluent / macos / yaru 等的真实控件包还没接
  (技术栈 §5.3 要求先验证各包的活跃度/焦点/无障碍/深色模式,不许因名字对就认定可用)。
- 注册表现有的 `themeFor(...)` 调用点(`apps/pure_live/lib/app/app.dart`)还**没传 tokens**,
  所以它现在拿到的是"按运行平台默认输入"解析出的令牌。传令牌是拆壳波的动作。
