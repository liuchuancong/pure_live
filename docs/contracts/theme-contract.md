# 主题契约(Theme Contract)

> 主题 = 数据(令牌文件),不是代码;用户可导入/导出/分享(见 [../ui/theme.md](../ui/theme.md))。

## 1. 主题结构

```text
Theme
├── colors        色板(含明暗两套)
├── typography    字体/字号/字重
├── shapes        圆角体系
├── spacing       间距节奏
├── elevation     阴影层级
├── assets        背景图/视频引用(资源 id → background 包解析)
└── metadata      名称/作者/版本/适配说明
```

## 2. 类型

`Builtin Theme`(内置)/ `Dynamic Theme(动态取色)` / `User Theme(用户导入)` / `Plugin Theme(插件提供)`

## 3. 交付格式

zip 包:`manifest.json + tokens.json + assets/`(待 §8-1 拍板后定稿)。令牌校验由 theme 引擎执行;**主题文件永不执行代码**。

## 4. 渲染规则

ThemeRuntime 将令牌构建为 `WindThemeData + Material ColorScheme`(明暗各一套,按 themeMode 切换);主题只影响外观,**不允许修改业务逻辑**;背景/壁纸资源经 `pure_live_background` 解析呈现。
