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
- `migration_runner.dart` —— `MigrationRunner` / `MigrationDomainSpec` / `KeyValueMigrationJournal`:逐域迁移流程
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

## 迁移流程(`MigrationRunner`,不是键名表)

三份 `docs/migration/*.md` 给的是**流程 + 键名表**。键名表里的 v1 具体键名不在本仓里(v1 源码已删),
所以这里只实现流程,键名留给各域自己的 spec 带 —— 编一组键名出来测试会全绿,而真迁移时会全错。

钉住的规则(逐条来自 v1-to-v2.md 与 database-migration.md):

| 规则 | 落法 |
|---|---|
| 摘要 → 用户确认 → 才动手 | `confirmed` 默认 **false**:没拿到"是"就一个字节都不读不写 |
| v1 只读不改 | `MigrationDomainSpec` 只暴露 `read`(流)与"写 v2"的回调 —— 结构上拿不到写 v1 的手 |
| 逐域独立、失败隔离可重试 | 每域单独跑;reader 断了只影响这一域,其它域照跑;该域不标记完成 |
| 断点续迁不重复 | `MigrationJournal` 记住每域已迁的键 + 已完成的域;重跑时已完成的域**根本不读**,半路断的域跳过已写键 |
| 单条失败进"待处理",不阻塞整体 | `MigrationReject`(或映射随便抛什么)只让这一行进 `RejectedRecord` 桶;域仍可完成 |
| 计数校验 + 差异报告 | `scanned == migrated + rejected` 才算对得平;`expectedCount` 不符则该域不完成并计入 `discrepancies` |
| 绝不清空 | 全程没有删除 v1 的 API;回滚按文档就是"清 v2 重来" |

`KeyValueMigrationJournal` 把"哪些键已迁"记成一份键列表。这是**键值后端的代价**,不是模型的必然:
一个几万条的历史域会带一份同样长的键表,而 Drift 绑定该把它换成按行的已迁标记 —— 换的是这个类,不是接口。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)

