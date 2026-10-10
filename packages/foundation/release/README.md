# pure_live_release

> 职责:更新检查、版本与发布通道

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_release.dart`;内部实现放 `lib/src/` |

## 内容

- `version.dart` —— `AppVersion`(解析 `4.0.0+5000`、语义段优先、build 做同版本 tie-break)、`manifestBuildForArm64`(BUILD_POLICY 里 `--split-per-abi` 给 arm64 `versionCode` +2000 那条坑,写成函数而不是注释)、`decideUpdate`(none / available / forced)

低于 `minimumSupported` 一律 forced,即使 feed 里没有更新的 build —— 继续用下去是对着已经不满足的协议取流。

- `update_feed.dart` —— `UpdateFeedTransport`(读 feed 的端口)、`UpdateFeedResponse`、`kDefaultUpdateFeedTimeout`(15s)、
  `ReleaseEntry`/`ReleaseAsset`(含 `assetFor` 按包名挑本平台工件)、`UpdateChecker.check`(永不抛)与 `UpdateCheckResult.decide`

## 行为契约

| 项 | 规则 |
|---|---|
| 取 feed | 只经 `UpdateFeedTransport`;本包不依赖 `pure_live_network`,绑定在 App 组合根(`apps/pure_live/lib/app/update_transport.dart`)。L0 之间互不依赖,见 [依赖规则](../../../docs/architecture/dependency-rules.md) §3。 |
| 超时 | `check` 自带 15s 预算,可注入。设置页在 `await` 之后才弹结果,没有截止线时一个不回话的主机会让「正在检查更新…」一直挂着。 |
| 失败 | 传输异常、超时、非 2xx、JSON 畸形全部落到 `UpdateCheckResult.error`,`check` 本身不抛 —— 检查更新失败不该把发起它的界面带走。 |
| 版本 | feed 头部版本解析失败的行被跳过,取下一条能解析的。 |
| 生命周期 | `UpdateChecker` 不创建也不关闭 HTTP 客户端:客户端由 runtime 持有,同一个客户端还在服务扩展网关。 |

## 未验证

- 真实 `assets/releases.json` 的形状:测试用夹具,线上 feed 的字段名与本平台工件命名没有对账过。
- `assetFor` 的 windows/linux/macOS 正则在真实工件名上的命中率(仓库目前只发 APK 与 windows zip)。
- 设备上的更新弹窗:见 App 侧 acceptance,不属于本包。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
