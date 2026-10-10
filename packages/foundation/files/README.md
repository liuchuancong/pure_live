# pure_live_files

> 职责:跨平台文件与路径访问,含导入导出与下载目录

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_files.dart`;内部实现放 `lib/src/` |

## 内容

- `file_names.dart` —— `sanitizeFileName`(非法字符 / 控制字符 / 前后缀空白 / Windows 保留名 / 只截词干保住扩展名)、`disambiguateName`(`a (1).mp4` 式让位)、`resolveWithin`(**目录逃逸守卫**:拒绝绝对 key 与 `..` 逃出的结果)
- `paths.dart` —— `DirectoryPolicy`(应用绑 path_provider)、`writeTextAtomically`(临时文件 + rename,崩溃不会留下半截设置)、`mimeTypeFor`

名字来自站点或导入的播放列表,就是攻击者可控文本;`resolveWithin` 集中做一次归一化,好过每个调用者各自记得防 `../`。

## 路径与存储(2026-10-11 补齐)

| 文件 | 提供 |
|---|---|
| `src/storage_locations.dart` | `HostPlatform`、`StorageKind`(userData/database/logs/cache/temp/downloads/documents/media/backups/plugins)与三条判定:`isEvictable`(系统可随时回收)、`isUserVisible`(绝不自动清理)、`isExcludedFromBackup`;每 kind 的目录名按平台给(`Cache` vs `cache`) |
| `src/platform_paths.dart` | `PathSignals`(宿主事实)+ `AppPaths`(把 kind 解析成目录)+ `ResolvedPath` |
| `src/storage_guard.dart` | `StorageGuard`(建目录、写探针证明可写、量体积、按预算淘汰、空间够不够)、`StorageCapacity` / `DiskCapacityProbe` / `EvictionReport` / `StorageGuardFailure` |

解析规则(全部由注入的事实算出,包内不碰插件):

- **Windows 便携版**:`portableDataDirectory` 优先,否则 `<exe 目录>/data`;`temp` 仍走系统临时目录 —— U 盘可能只读,
  半个临时文件不该让便携版起不来。
- **Windows MSIX**:`packageFamilyName` 非空即打包版,一律走 `%LOCALAPPDATA%\Packages\<PFN>\{LocalState,LocalCache,TempState}`。
  打包版写 `%LOCALAPPDATA%\<Publisher>\<App>` 会被系统重定向到一份**下次启动看不到**的虚拟化副本。
- **Windows 安装版**:设置/数据库/备份走漫游 `%APPDATA%\<Publisher>\<App>`(跟账户走),缓存/日志/插件走
  `%LOCALAPPDATA%`(缓存换机器重建比带过去好,日志跟到读不了它的设备没意义)。
- **Android**:userData/database/logs/plugins 一律**内部私有**(不需要权限);cache 优先外部 app 目录;
  downloads/documents/media 优先公共目录(`Download`/`Documents`/`Music`),没有共享存储权限时回落到 app 外部目录再回落到内部。
- **iOS/macOS**:`Library/Application Support/<app>`、`Library/Caches/<app>`(系统备份自动排除)、`Library/Logs/<app>`、
  `Documents/<app>`、`tmp`。
- **Linux**:XDG —— 设置在 `configHome`(所以 `rm -rf ~/.config/<app>` 是"重置"而不是"删历史"),数据/数据库/备份在
  `dataHome`,日志在 `stateHome`,缓存在 `cacheHome`,用户目录读 `XDG_*_DIR` 否则 `~/Downloads` 等。
- **Web**:每个 kind 都解析成 `null`(没有文件系统),调用方按"不可用"降级到内存,而不是抛。

`StorageGuard` 的两条规矩:**解析出来的路径不等于能写的路径**(Android 外置卡可被卸载、漫游配置可能只读、
便携目录可能在写保护介质上),所以每个位置用一次真实写探针证明,并按路径记住结果 —— 授权变化或重新挂载后调
`invalidate()`;**淘汰按修改时间从旧到新**,`keep` 里的文件绝对不动(用户标记的离线内容不能被缓存策略回收),
删不掉的计入 `skipped` 而不是当成失败(Windows 上播放器正开着文件是常态)。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
