# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Fixed(安全)**:`_directoryFor` 净化 id 时只挡了 `/`、`\` 与空白,**没挡连续的点** ——
  于是 id `..` 原样通过,解析成 `plugins/../`,即**插件目录的父目录(应用自己的数据目录)**;
  `uninstall()` 是 `delete(recursive: true)`。现在折叠点串并加一道「仍在根目录内」的复检
  (复检是保险而不是主防线:路径规范化得过仍能出根的写法才是真正被堵住的)。
- **Fixed(DoD 体积上限)**:`readSource` / `readContent` 加了 `maxBytes`(默认 4 MiB),超出抛新的
  `PluginTooLargeException`(带 id、文件名、上限与实际字节数)。以前是无限 `readAsString()`:
  一个 200 MB 的 plugin.js 会在装载时把进程打死,而且那时插件已经装进列表、删都嫌卡。
- 缺文件现在抛 `PluginInstallException` 而不是裸 `FileNotFoundError` —— 调用方按类型分支,不该比字符串。

- Skeleton created for layer ecosystem as `pure_live_plugin_host`: no dependencies and no implementation yet.
