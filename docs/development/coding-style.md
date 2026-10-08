# 编码规范(Coding Style)

## 语言与格式

- Dart 3.13 / flutter_lints;格式化 `dart format`(page_width 120)。包目录的宽度取自
  [../../analysis_options.package.yaml](../../analysis_options.package.yaml) 的 `formatter.page_width`:
  格式化器**不会**从仓库根的 `analysis_options.yaml` 继承这个值,所以两处都要写,
  `.github/workflows/architecture.yml` 的 `dart format --set-exit-if-changed` 负责守住。
- **代码注释一律英文**(见 [../DEVELOPMENT_STANDARDS.md](../DEVELOPMENT_STANDARDS.md) §4,含文件头 Module/Purpose/Author/Created);
  本 `docs/` 体系与包 README 用中文。注释只写代码说不出的约束,不写流水账。

## 架构级红线(护栏 + Review 双查)

1. 依赖方向按 [../architecture/dependency-rules.md](../architecture/dependency-rules.md);违反 = CI 失败。
2. 每包单一 barrel;外部不得 `import 'package:.../src/...'`。
3. 业务代码禁止:`import fluttersdk_wind`(仅 ui_kit)、平台判断(仅 platform/adaptive)、直接厂商 SDK(仅 integrations)、硬编码颜色间距(用 design 令牌)。
4. 状态管理 Riverpod:包内暴露 provider;跨包装配只在 app 组合根(overrides);禁止手动单例/服务定位器。
5. 模型 freezed;JSON 序列化 json_serializable;错误用 Result 语义(utils),不裸 throw 跨包。

## 提交

- Conventional Commits(feat/fix/docs/refactor/chore + scope)。
- 一个逻辑改动一个提交;跑过受影响包的 analyze/test 再提。
