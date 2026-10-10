# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased
- **偏好机制自 `features/settings` 搬进本包**(`lib/src/preferences/`,公开面经 barrel 导出)。
  搬的理由记在台账 §5:实测四处各自手写了版本化文档(`features/home` 的 `{v,order,hidden}`、
  `features/search` 的 `{v,items}`、`features/vod` 的进度行、app 的 appearance),而机制原住在
  `features/settings` —— §3 禁 feature 同层互依,所以谁都用不上;新建 `foundation/preferences` 又必须依赖
  同为 L0 的本包(§3 同样禁),要么加例外要么重抄 `KeyValueStore`。storage 本来就是"版本化文档 + 迁移"的
  持有者(`SchemaMigrator` / `MigrationRunner`),旧信封行的升级本来就要靠这里的 schema step。
  `pure_live_settings` 包随之删除(零消费者:`grep pure_live_settings` 除自身外只命中自己)。
- `PreferenceCodec<T>`:闭集类型(boolean / integer / real / string / stringList)+ `of()` 自定义。
  类型不匹配不被字符串化成"看起来对"的值;`stringList` 存成真 JSON 数组,不用分隔符拼接
  (含分隔符的 id 会破坏往返)。
- 落盘是带版本信封 `{'v':1,'c':<codec>,'value':…}`:同名换类型判为 `codecMismatch` 并回默认值。
- `PreferencesStore`:`read` / `readIfStored` / `write` / `putIfAbsent` / `reset` / `isStored` /
  `exportAll` / `importAll` / `changes` / `rejections` / `upgradedKeys` / `dispose`;`namespace` 参数
  让两个 App 共用一个 store 文件而互不可见。
- 具名失败:`PreferenceException` + `PreferenceFailure`(unreadableEnvelope / codecMismatch / invalidValue)。
  读永不抛、写会抛;每次回退记 `PreferenceRejection`(只记原值的运行时类型,不记原值)。
- `importAll` 按调用方键表逐项校验并返回 `PreferenceImportReport`(accepted / skipped / rejected /
  unknownKeys),坏一条不连坐其余。
- `PreferenceKey.upgrade` + `upgradedKeys`:信封之前的旧行不再被当成故障 —— 拒绝会让读回落默认值,
  而下一次写入把默认值存成"用户的选择",即采纳这套机制会静默删掉用户设置。读不回写,schema step 才回写。
- `test/preferences_store_test.dart`:32 例(自 `features/settings` 一起搬来,那是该机制的第一批测试)。

- `KeyValueStore` / `SecureStore` 接口、类型化读取与内存实现;`SettingsMigrator` 与 `SchemaMigrator`
  (W1 首切片:设置迁移边界)。
- `FileKeyValueStore`:单文件 JSON 实现 —— 首次访问载入、每次改动写穿、临时文件 + rename、操作串行化。
  读不懂的文件抛 `StoreCorruptedException` 并拒绝后续写入;不能序列化的值不改内存,也不改磁盘。
- `MigrationRunner` / `MigrationDomainSpec` / `KeyValueMigrationJournal`:迁移流程(确认才动手、v1 只读是
  结构性约束、逐域失败隔离、按已迁键断点续迁、单条失败进待处理桶、计数校验与差异报告)。键名表仍是各域自己的事。

