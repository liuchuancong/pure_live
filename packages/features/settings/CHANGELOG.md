# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

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
