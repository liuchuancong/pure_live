# Theme(主题系统)

> 主题 = 令牌数据文件;用户可导入/导出/分享,永不执行代码。契约见 [../contracts/theme-contract.md](../contracts/theme-contract.md)。

## 组成

`colors / typography / shapes / spacing / elevation / motion / assets(背景资源引用)`

## 类型

Builtin / Dynamic(动态取色)/ User(导入文件)/ Plugin(插件提供)

## 处理

```text
主题文件(zip:manifest + tokens + assets 引用)
 → theme 引擎校验 → 令牌合并(design 默认 ← 用户覆盖)
 → WindThemeData + Material ColorScheme(明暗各一套,按 themeMode 切换)
 → 背景资源 id 交 background 包解析为画布
```

## 规则

- 主题只影响外观,不得改变业务逻辑;运行时切换无重启。
- 弹幕/字幕/播放器控制层的可定制项(颜色/大小)也是令牌的一部分。
- 格式细节待最终拍板(建议 zip),变更走 ADR。
