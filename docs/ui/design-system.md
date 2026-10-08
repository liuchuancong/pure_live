# Design System

> 设计令牌的唯一权威:纯数据包,零 widget 依赖。

## 令牌域

`colors(明暗两套)/ typography(字体族/字号/字重)/ shapes(圆角)/ spacing(间距节奏)/ elevation(阴影)/ motion(动效曲线与时长)/ breakpoints`

## 规则

- 主题引擎(theme 包)把用户令牌文件覆盖到默认令牌上,产出运行时令牌;ui_kit 与页面只读运行时令牌。
- 令牌命名语义化(surface/containerLow/containerHigh/onSurfaceVariant…),与 Material ColorScheme 角色对齐,便于双向构建。
- 令牌变更 = design 包 minor 版本;页面禁止硬编码颜色/间距(护栏规则 + code review)。
