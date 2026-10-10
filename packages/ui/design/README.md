# pure_live_design

> 职责:UI 的**语义令牌** —— 颜色角色、间距/圆角/字阶/动效/密度、交互尺寸与焦点视觉,以及外观设置的持久形状。
> 这里是**数字与名字**,不是颜色值:具体 scheme 由风格适配器造。
> 规格出处:[技术栈 §5.2/§5.4](../../../docs/architecture/pure_live_v2_flutter_technology_stack.md)。

## 模块

| 文件 | 提供 | 为什么要单独一份 |
|---|---|---|
| `src/semantic_roles.dart` | `ColorRole`(13 个角色)、`ControlState`、`FocusShape`、`InputMode`、`PlatformProfile` | 六种风格不共享 Material 的命名;角色按语义命名,适配器才不用各写一套常量 |
| `src/scale_tokens.dart` | `SpaceToken` / `RadiusToken` / `Density` / `TypeRole` / `MotionProfile` | 字阶要能表达"十英尺可读下限",动效要能表达"减少动态 = 时长归零而不是变短" |
| `src/control_metrics.dart` | `ControlKind`(高度与最小可瞄准尺寸)、`FocusVisual` | TV / 鼠标 / 触摸的交互尺寸本来就不该是同一个数 |
| `src/design_tokens.dart` | `DesignTokens` + `resolveDesignTokens` + `AppearanceSettings`(+ `resolveTokens` / `copyWith` / `withDensity` / `withInput`)+ `BackgroundConfig` + 兼容用的 `PureLiveSpacing` / `PureLiveRadius` | 解析规则(不可协商的那几条)只能有一处实现 |

## 规则(这些是包里的硬约束,不是建议)

- **字不能越改越小**:`resolveDesignTokens` 把 `textScale < 1` 抬回 1.0;`TypeRole.sizeFor` 只允许变大。
- **remote 有可读下限**:`InputMode.remote` 下 `bodySmall` 等小字角色最低 16 逻辑像素。
- **减少动态效果 = 时长归零**,不是缩短;且 `MotionProfile.reduced` 优先于模式默认值。
- **遥控器输入不做聚焦缩放**(`scaleOnFocusAllowed == false`):控件尺寸一变,它下面整排行就跟着动,
  在 d-pad 上看起来像界面在抖。
- **瞄准尺寸**:主交互件下限 remote/touch 48/44、pointer 24;`chip` 属行内件(行的 padding 也参与命中),
  下限 32/20 —— 两套数字是刻意的,统一成一个会把 chip 撑成按钮。
  `ControlKind.isAimable` 把这条变成可断言的检查,而不是等用户在小屏上按不中。
- **焦点必须看得见**:`FocusVisual.isFindable` 要求宽度 ≥2 且对比 ≥3:1;remote 给 3px / 3.5:1。
- `PlatformProfile.preferredInput` 只是默认值:接遥控器的主机、外接键控的盒子都能覆盖,
  覆盖后**下限跟着输入模式走而不是平台走**。

## 兼容

`PureLiveSpacing` / `PureLiveRadius` 的数值保持 ui_kit 现在渲染的那套(枚举字段访问进不了 const 表达式,
所以是两份字面量 + 一条相等断言把它钉住)。改这些数字是一次设计变更,得对着截图定,不是顺手重构。

## 依赖

无。这个包**刻意不 import Flutter**:令牌要能在没有 BuildContext 的情况下被断言,
否则"数字对不对"只能靠截图 review。

## 平台矩阵

纯 Dart,所有平台一致。真正分叉的是适配器(ui/adaptive),它把这里解析出的 `DesignTokens` 映射成 `ThemeData`。

## 未验证

- **数字没有对着真机或截图核过**:26 个测试钉住的是自洽性(下限、排序、归零、可瞄准、设置→令牌的映射),
  不是"TV 上看着舒服"。`apps/pure_live` 已经把用户设置接进 `themeFor`,但那条链路只过了静态分析:
  设置页改一次密度/字号后实际渲染成什么样,本轮没有 widget 测试、也没有设备截图。
- `ColorRole` 的 13 个角色是照 §5.4 列的集合,没有做对比度实测;对比度目前是**要求值**而不是计算值。
