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
- `file_key_value_store.dart` —— `FileKeyValueStore`:单文件 JSON 的 `KeyValueStore`,首次访问时载入、每次改动写穿
- `migration.dart` —— `SettingsMigrator`(旧键 → 新键 + 转换函数表,未知键记录不丢)+ `SchemaMigrator`(版本步进链,断点续迁)

迁移语义按 [docs/migration/settings-migration.md](../../../docs/migration/settings-migration.md) 与 [v1-to-v2.md](../../../docs/migration/v1-to-v2.md):一个键转换失败只记在它自己头上,其余继续;schema 版本每步落盘,重试从断点接上,链上有缺口或重复步在动手前就报错。

`FileKeyValueStore` 的三条规矩,都是围绕"别把用户的数据变成没有":

- **读不懂就不覆盖**:文件存在但不是 `{"key": value}` 形状时抛 `StoreCorruptedException`,之后的 `write` 也一并拒绝。
  把"读不出来"当成"本来就是空"会让下一次写入把不可读永久变成丢失(空文件例外:那是首次写入中途被杀留下的,里面从来没有数据)。
- **编码失败 = 什么都不发生**:先把候选 map 编码,再动内存与磁盘,所以一个不能序列化的值(例如 `DateTime`)抛
  `ArgumentError`,而文件与原值分毫未动。
- **写 = 临时文件 + rename**:读者只会看到完整的旧文件或完整的新文件;所有操作走一条队列,否则两个扩展同时
  读-改-写会在同一个文件上互相覆盖。

应用目录由组合根与 `pure_live_files` 决定,本包只收一个路径 —— L0 之间不建依赖边。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
