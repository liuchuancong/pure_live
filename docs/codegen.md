# Codegen 约定（build_runner + Freezed + json_serializable）

> 状态：已启用（live_sites 首个接入包）。工具链锁定在 workspace 的 `pubspec.lock`。

## 工具链

| 包 | 位置 | 用途 |
|---|---|---|
| `build_runner` | dev | 生成驱动 |
| `freezed` / `freezed_annotation` | dev / runtime | 不可变模型、联合类型、copyWith |
| `json_serializable` / `json_annotation` | dev / runtime | JSON 序列化 |

版本按当前 Dart SDK（3.13）解析锁定：freezed ^4.0.2、freezed_annotation ^3.1.0、
json_serializable ^6.14.0、json_annotation ^4.12.0。

## 生成与提交

- 生成物（`*.g.dart`、`*.freezed.dart`）**不进 git**（`.gitignore` 已忽略），
  CI 与本地在构建前生成。
- 生成命令（在包目录下）：

```sh
dart run build_runner build --delete-conflicting-outputs
```

- 改了模型/JSON 注解后必须重跑生成；提交前 `dart analyze` 必须 `No issues found!`。
- 生成物缺失会导致分析报错（找不到 `_$X`），属预期行为，跑一次生成即可。

## 模型迁移规则（live_sites）

1. 先简单 DTO（SiteMetadata、LiveArea、LivePage、LiveEmote…），后 LiveRoom。
2. 3.x JSON 兼容是硬约束：
   - `LiveStatus` 按**索引**存（枚举顺序是持久化契约，不得改序）；
   - `LiveRestriction` 按**名字**存（未知名字丢弃、不抛错）；
   - `data` / `danmakuData`（运行时缓存）**永不进 JSON**；
   - 旧 JSON 的缺省字段要有默认值（`@JsonKey(defaultValue: …)` 或可空 + fromJson 兜底）。
3. 身份相等性：`LiveRoom` 的相等是 `platform:roomId`，不是字段全等。
   若 Freezed 默认 equality 与身份语义冲突，用 `@Freezed(equal: false)` 并保留手写
   `==`/`hashCode`，或把身份对象与快照模型分离——**不为统一代码生成牺牲身份约定**。
4. `copyWith` 的 nullable 清除语义：由 Freezed 生成，业务侧 `mergeFrom` 等稀疏合并
   逻辑保持现有行为，迁移前后行为必须一致（以现有语义为准，不改变对外行为）。
5. 迁移一个模型 = 一个提交；先迁移、跑生成、跑分析、跑既有测试（若有），再提交。
