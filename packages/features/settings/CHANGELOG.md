# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- Added `PreferenceKey.upgrade` and `PreferencesStore.upgradedKeys`. The store could reject an older shape but
  never read it: a row written before the envelope existed decoded as `unreadableEnvelope`, the key answered
  its default, and the next write persisted that default as though the user had chosen it. Adopting the
  mechanism therefore deleted a user's setting — which is the property that decides whether any existing
  consumer can move onto it at all. The hook returns the inner value (or null when the shape is genuinely
  unknown), reports through `upgradedKeys` rather than `rejections`, still runs the key's own `validate`, and
  does not rewrite the row on read: a screen that came to display a value must not be the thing that mutates
  storage, and converting the row is a `SchemaMigrator` step's job.
- Added the package's first tests — 32 cases in `test/preferences_store_test.dart`. The 491-line mechanism had
  none (the README said so, at that round's instruction), which let the gap above sit in the read path
  unnoticed. Coverage: envelope and codec-name gating, reads never throwing plus rejection accounting, writes
  refusing out-of-range values, `putIfAbsent` first-run semantics, namespace isolation and backups carrying
  only their own namespace, the change stream and idempotent `dispose`, `importAll` per-entry accept/reject,
  and the legacy upgrade path in both directions.

- **不兼容改动**:删除 `PreferenceKeys` 常量表与 `isFirstRun` / `markFirstRunDone` /
  `preferredQuality` / `danmakuEnabledByDefault` / `homeTabOrder` 五个具体偏好。它们是直播产品的
  词汇表,不该出现在四个 App 共享的包里(ADR 0022 / portfolio §5)。各 App 现在自己声明
  `PreferenceKey`,首启用判断改用 `putIfAbsent`。
- `PreferenceCodec<T>`:闭集类型(boolean / integer / real / string / stringList)+ `of()` 自定义。
  类型不匹配不再被字符串化成"看起来对"的值;`stringList` 存成真 JSON 数组,不用分隔符拼接
  (含分隔符的 id 会破坏往返)。
- 落盘改为带版本信封 `{'v':1,'c':<codec>,'value':…}`:同名换类型判为 `codecMismatch` 并回默认值。
- `PreferencesStore`:`read` / `readIfStored` / `write` / `putIfAbsent` / `reset` / `isStored` /
  `exportAll` / `importAll` / `changes` / `rejections` / `dispose`;`namespace` 参数让两个 App 共用
  一个 store 文件而互不可见。
- 具名失败:`PreferenceException` + `PreferenceFailure`(unreadableEnvelope / codecMismatch /
  invalidValue)。读永不抛、写会抛;每次回退记 `PreferenceRejection`(只记原值的运行时类型,不记原值)。
- `importAll` 按调用方键表逐项校验并返回 `PreferenceImportReport`(accepted / skipped / rejected /
  unknownKeys),坏一条不连坐其余。
