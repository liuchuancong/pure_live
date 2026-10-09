# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `KeyValueStore` / `SecureStore` 接口、类型化读取与内存实现;`SettingsMigrator` 与 `SchemaMigrator`
  (W1 首切片:设置迁移边界)。
- `FileKeyValueStore`:单文件 JSON 实现 —— 首次访问载入、每次改动写穿、临时文件 + rename、操作串行化。
  读不懂的文件抛 `StoreCorruptedException` 并拒绝后续写入;不能序列化的值不改内存,也不改磁盘。
- `MigrationRunner` / `MigrationDomainSpec` / `KeyValueMigrationJournal`:迁移流程(确认才动手、v1 只读是
  结构性约束、逐域失败隔离、按已迁键断点续迁、单条失败进待处理桶、计数校验与差异报告)。键名表仍是各域自己的事。

