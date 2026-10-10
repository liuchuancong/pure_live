# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Fixed**:`list()` no longer reads a `.staging` directory as an installed plugin. A crash between the last
  staging write and the rename leaves a *complete* remnant (manifest, script and state are all written before
  the swap), so it listed the same plugin twice — the second entry under an id no manifest ever claimed, which
  could then be enabled, given state and uninstalled as that phantom. The suffix is now a named constant shared
  by the writers and the reader instead of being spelled at each call site.
- **Fixed**:`install`/`installData` refuse when the target directory already holds a *different* plugin's
  manifest. Ids are sanitised before they become paths, so two valid reverse-domain ids can name one directory
  (`com.a$b` and `com.a_b`, `com.a..b` and `com.a_b`); without the check the second install replaced the first
  silently and the manifest left on disk named a third thing. Re-installing the same id is still the upgrade
  path and still carries the enable flag over.
- README gained 行为契约 and 平台矩阵 sections, and the stale line claiming nobody handles the staging remnant
  was corrected: it is now invisible to listing and cleared by the next install of that id, while the
  still-true remainder (no boot-time sweep of orphan remnants) stays listed as 未验证.
- Added `test/plugin_store_listing_test.dart` (6 cases). `dart test`: 11 passing in the package.

- **Fixed(安全)**:`_directoryFor` 净化 id 时只挡了 `/`、`\` 与空白,**没挡连续的点** ——
  于是 id `..` 原样通过,解析成 `plugins/../`,即**插件目录的父目录(应用自己的数据目录)**;
  `uninstall()` 是 `delete(recursive: true)`。现在折叠点串并加一道「仍在根目录内」的复检
  (复检是保险而不是主防线:路径规范化得过仍能出根的写法才是真正被堵住的)。
- **Fixed(DoD 体积上限)**:`readSource` / `readContent` 加了 `maxBytes`(默认 4 MiB),超出抛新的
  `PluginTooLargeException`(带 id、文件名、上限与实际字节数)。以前是无限 `readAsString()`:
  一个 200 MB 的 plugin.js 会在装载时把进程打死,而且那时插件已经装进列表、删都嫌卡。
- 缺文件现在抛 `PluginInstallException` 而不是裸 `FileNotFoundError` —— 调用方按类型分支,不该比字符串。

- Skeleton created for layer ecosystem as `pure_live_plugin_host`: no dependencies and no implementation yet.
