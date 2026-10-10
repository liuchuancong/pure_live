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
- **Fixed**:`PluginBundleParser` located the manifest header with a whole-file `indexOf`, so any file that
  merely *mentions* the marker - in a string, in a script comment - was read as declaring one there, and
  everything before that point became the installed script with the real header still inside it. The header now
  has to open the file (whitespace and a byte-order mark only, within 512 characters), and both of its
  boundaries are searched forward from the marker, so an unrelated `*/` earlier in the file can no longer close
  it. `PluginBundleParser` had no tests at all; it is the only thing between an imported file and the sandbox.
- Parse failures are one exception type now: malformed JSON, a manifest of the wrong shape (the model throws on
  a missing `id`), an unclosed header and a header with no script after it all surface as
  `PluginBundleException` instead of leaking `FormatException` / `StateError` at the caller. A file over
  `kMaxBundleCharacters` is refused before the parser builds its substring copies.
- **Fixed**:`installData` reset `enabled` to false on every update. The two install paths had each their own
  copy of validate-stage-swap, and the data one drifted from the rule the code path documents ("an update must
  not turn a source off"). Both now share `_write`.
- **Fixed**: an update dropped `originUrl` unless the caller passed it again. The stored state is the only copy
  of the base that relative spider paths inside a config resolve against, so a plain version bump broke a
  working plugin; the previous value carries over and an explicit one replaces it. The returned
  `InstalledPlugin` also carries it now, which it silently dropped before.
- **Fixed**:`setEnabled` overwrote `state.json` in place. A crash or a full disk mid-write leaves a file that
  does not parse, which `list()` reads as "not installed" - pressing the toggle could therefore delete a
  plugin from the management page while its directory and script stayed on disk with no entry left to remove it.
  It writes `state.json.tmp` and renames.
- A damaged directory reads as absent instead of taking the listing down with it: `_readManifestAt` and
  `_readState` caught only `FormatException`, but a manifest that parses with the wrong shape throws from the
  model, so one corrupt plugin broke `list()` for everybody. `uninstall` still works on those directories.
- Added `find(id)` (one plugin, same "not installed" reading as `list`, so the two cannot disagree about
  damaged data), `pruneStagingRemnants()` for a deliberate post-startup sweep, `PluginBundle.renderToFile()`,
  and `uninstall` now deletes the `.staging` sibling rather than leaving a copy of code the user removed.
- An `originUrl` with no scheme is treated as absent; `Uri.parse` accepts nearly anything and would hand back a
  base that points somewhere else entirely.
- Install timestamps read through an injected `Clock` (default `systemClock`); the constructor called
  `DateTime.now()` directly, which makes a local-vs-UTC mistake invisible at the call site and forces a test to
  wait on the wall clock.
- `list()` iterates asynchronously (`listSync` blocked the isolate inside an `async` method).
- Added `test/plugin_bundle_parser_test.dart` (12 cases) and `test/plugin_store_state_test.dart` (13 cases).
  `dart test`: 36 passing in the package.
- Declared `pure_live_utils` for the `Clock` typedef (dependency-rules §1: every layer may use L0).

- **Fixed(安全)**:`_directoryFor` 净化 id 时只挡了 `/`、`\` 与空白,**没挡连续的点** ——
  于是 id `..` 原样通过,解析成 `plugins/../`,即**插件目录的父目录(应用自己的数据目录)**;
  `uninstall()` 是 `delete(recursive: true)`。现在折叠点串并加一道「仍在根目录内」的复检
  (复检是保险而不是主防线:路径规范化得过仍能出根的写法才是真正被堵住的)。
- **Fixed(DoD 体积上限)**:`readSource` / `readContent` 加了 `maxBytes`(默认 4 MiB),超出抛新的
  `PluginTooLargeException`(带 id、文件名、上限与实际字节数)。以前是无限 `readAsString()`:
  一个 200 MB 的 plugin.js 会在装载时把进程打死,而且那时插件已经装进列表、删都嫌卡。
- 缺文件现在抛 `PluginInstallException` 而不是裸 `FileNotFoundError` —— 调用方按类型分支,不该比字符串。

- Skeleton created for layer ecosystem as `pure_live_plugin_host`: no dependencies and no implementation yet.
