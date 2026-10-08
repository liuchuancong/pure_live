# ADR 0014:主题系统(Theme System)

- 状态:已接受(2026-10-08)

## 背景

用户要求主题可导入、高度自定义;v1 主题硬编码在代码里。

## 决策

主题 = 令牌数据文件(zip:manifest + tokens + assets 引用,格式细节待拍板);四类来源(Builtin/Dynamic/User/Plugin);theme 引擎校验 → 合并 design 默认令牌 → 构建 WindThemeData + Material ColorScheme(明暗两套);背景资源 id 由 background 包解析;主题永不执行代码。ui_kit 唯一触达 wind。见 [../contracts/theme-contract.md](../contracts/theme-contract.md)、[../ui/theme.md](../ui/theme.md)。

## 后果

- 正:生态可分享主题;换 wind 不换主题;安全面为零。
- 负:令牌 schema 需要版本化演进(随 design 包 minor)。
