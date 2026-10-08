# pure_live_storage

> 职责:统一 kv 与安全存储,承载设置迁移边界

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_storage.dart`;内部实现放 `lib/src/` |

## 内容

- `stores.dart` —— `KeyValueStore` / `SecureStore` 接口 + 类型化读取(`readInt` 兼容旧库存成文本的数字)+ 内存实现;真实后端由应用组合根绑定
- `migration.dart` —— `SettingsMigrator`(旧键 → 新键 + 转换函数表,未知键记录不丢)+ `SchemaMigrator`(版本步进链,断点续迁)

迁移语义按 [docs/migration/settings-migration.md](../../../docs/migration/settings-migration.md) 与 [v1-to-v2.md](../../../docs/migration/v1-to-v2.md):一个键转换失败只记在它自己头上,其余继续;schema 版本每步落盘,重试从断点接上,链上有缺口或重复步在动手前就报错。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
