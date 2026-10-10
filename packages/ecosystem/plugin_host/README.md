# pure_live_plugin_host

> 职责:Plugin install pipeline: bundle parsing, manifest validation, on-disk store and per-plugin state

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_plugin_host.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 行为契约

| 项 | 规则 |
|---|---|
| manifest 位置 | **文件必须以 header 开头**,前面只允许空白与 BOM(且在 512 字符内)。旧写法在整个文件里 `indexOf(marker)`:脚本正文里出现一次 marker(注释里、字符串里都算)就被当成声明,而 marker 之前的真实代码变成了"脚本",真 header 还留在里面。为什么不许 preamble:区分"前置注释"和"以注释开头的正文"需要解析注释,那正好是这条规则要买的确定性。 |
| header 边界 | 两个边界都**从 marker 往后找**(`{` 与 `*/`)。以前结尾从 index 0 找,于是文件里任何更早的 `*/` 都能"关掉"header。 |
| 解析失败只有一种 | JSON 不合法、manifest 形状不对(`id` 缺失时模型自己抛)、header 未闭合、header 之后没有代码 —— 全部是 `PluginBundleException`,不是 `FormatException`/`StateError` 外泄。`parse()` 的调用方只有一个 catch 目标,不用了解 `PluginManifest` 内部怎么报错。 |
| 读入规模 | `kMaxBundleCharacters` = 4 MiB(按 UTF-16 code unit,是**解析**的护栏:parse 会做多次 substring 拷贝)。真正的字节上限在 store 的 `readSource` / `readContent`,那才是打开文件的地方。 |
| 目录 | `plugins/<id>/manifest.json + plugin.js(或 content.txt) + state.json`。三文件分开:半个坏脚本不能把声明一起带走,启用位是用户数据。 |
| id → 路径 | 只有一处做 sanitise(`_directoryFor`):非 `[A-Za-z0-9._-]` 换 `_`,连续点折叠,首尾点换 `_`,再过一次"仍在 root 内"。id `..` 曾经直接指到 `plugins/` 的**上一层**,而 `uninstall` 是递归删除。 |
| 安装 | 校验(交 plugin_api 的 validator,不在这里重判)→ 写满 staging → 删旧目录 → rename。`install` 与 `installData` **共用一条 `_write`**:两条各自实现过一遍,数据那条就漂走了 —— 它每次更新都把 `enabled` 写回 false,正是上面"更新不该顺手关掉一个源"要避免的事。 |
| 更新保住的字段 | `enabled` 与 `originUrl` 都从旧 state 带过来(这次没给 origin 就沿用旧的;给了才替换)。相对路径的 spider 靠 originUrl 解析,更新时丢了它 = 一个原本能用的插件坏了。返回值里也带上 originUrl(以前丢了)。 |
| 时间戳 | `installedAt` 走注入的 `Clock`(默认 `systemClock`,经 package:clock 的 zone 可覆盖)。构造函数里直接 `DateTime.now()` 的坏处在本仓库已经修过好几轮:本地/UTC 混用在这个调用点上是看不见的。 |
| `setEnabled` | 先写 `state.json.tmp` 再 rename。原地覆盖 + 断电/写满 → 半个 JSON → `list()` 读作"没装",用户点了个开关就把插件变没了(目录还在,但界面上已经没有任何入口能删它)。 |
| 坏文件 | manifest 或 state **解析不出、或形状不对**都算"未安装"(`find` 返回 null、`list` 跳过),不再只 catch `FormatException`:形状错的 manifest 是模型抛的 `Error`,以前会把整个列表打崩。目录仍然可以 `uninstall`。 |
| `originUrl` 读取 | 没有 scheme 的值当没有:不在这里用 `Uri.parse` 兜一个相对"来源",那会变成一个指向别处的 base。 |
| `.staging` 残骸 | `list()` 跳过它。崩溃发生在最后一次写之后、rename 之前时,残骸是**内容完整**的目录,读它就等于把同一个插件列两遍,第二遍挂在一个没有任何 manifest 声称过的 id 上(那个幻影还能被启用、写状态、卸载)。同 id 再装会清掉它;`pruneStagingRemnants()` 是显式的启动后清扫(返回删掉几个),`uninstall` 也连带删掉同名残骸 —— 用户刚删的代码不该以另一个名字留在盘上。 |
| 撞名 | 两个不同 id 可能被 sanitise 成同一个目录(`com.a$b` 与 `com.a_b`、`com.a..b` 与 `com.a_b`)。装第二个时直接拒,理由是目录里已有别人的 manifest —— 静默覆盖会留下一个声称第三个 id 的插件。 |
| 读取上限 | `readSource` / `readContent` 带 `maxBytes`(默认 4 MiB),超了抛具名 `PluginTooLargeException`;文件不存在是 `PluginInstallException`,不是 `FileNotFoundError`。 |

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / iOS / macOS / Windows / Linux | ✅ | `dart:io` 文件与目录,无插件、无 Flutter。 |
| Web | ❌ | 本包 `lib/` 直接 import `dart:io`(staging 目录与 rename),浏览器沙箱里没有这个原语。真要支持 Web,得换一个 KV 而不是加条件导入。 |

## 验证

- 分析:`dart analyze packages/ecosystem/plugin_host`(0 issue)
- 测试:`dart test`(**36 例**,跑在临时目录):路径与字节上限 5 + 列表/撞名/升级 6 +
  bundle 解析 12 + state/更新保全/坏文件 13。
- 解析器此前**一个测试都没有**,而它正是"导入的文件"与沙箱之间唯一的一道闸;本轮 12 条里最有价值的是
  preamble 拒绝、marker 出现在正文里不算声明、未闭合 header、嵌套 metadata 不被截断、
  `renderToFile()` 回环。

## 未验证(2026-10-11 复核)

- **零消费者**:整条插件栈仍悬空(台账 §2bis 第 1 组),所以 `..` 那条删除路径是**推演出来的**,
  不是观测到的事故 —— 它值得修,但记清楚来源。`setEnabled` 的 tmp+rename、坏 state 的"读作未安装"同样是
  推演出来的失效路径:测试能证明**写了 tmp 并 rename 成功**,证明不了断电在第几行会截断。
- 测试跑在临时目录上;真机(Android 的外部存储 / Windows 的 AppData)路径权限差异**未验证**,
  `rename` 跨卷失败的情况也没验过 —— 而 `setEnabled` 与 install 都依赖 rename 原子性,Windows 上
  目标已存在时 rename 的行为差异没有覆盖到(测试里 install 先删旧目录再 rename,规避了这一条)。
- `.staging` 残骸现在**不会被列出来**,也给了显式清扫 `pruneStagingRemnants()`,但**没有人调用它**:
  接不接进启动流程是产品判断(它会在用户的插件根目录里删目录),不是本包的默认。
- 单个损坏插件读作"未安装"之后,`list()` 里就没有它的行为了 —— 界面上看不见、也就点不到"清理";
  要不要提供一条"列出损坏目录"的旁路,记台账 §5。
