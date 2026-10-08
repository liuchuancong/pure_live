# 包开发指南

## 新建包

```powershell
tool/scaffold_package.ps1 <层>/<短名>   # 如 foundation/cache_qa → packages/foundation/...
```

脚手架产出:pubspec(name = pure_live_<短名>)+ barrel + README(职责/允许依赖/禁止依赖)+ test 占位 + CI 片段。结构不得私自偏离;偏离先改模板。

## 日常

1. 只在包内改;跨包需求先看依赖矩阵(允许吗?)。
2. 公开 API 全部经 barrel 导出;内部实现 `lib/src/`。
3. 每包 README 的"职责一句话"失效时,先改文档再改代码。
4. analyze/test 在包目录跑(melos filter),提交前全绿。

## 晋升

目录 → 独立包:超 ~800 行或出现第二个消费方;走 ADR。包 → 拆分:同规则。
