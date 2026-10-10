# pure_live_release

> 职责:更新检查、版本与发布通道

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_release.dart`;内部实现放 `lib/src/` |

## 内容

- `version.dart` —— `AppVersion`(解析 `4.0.0+5000` / `4.1.0-beta.1+5100`、语义段优先、build 做同版本 tie-break)、**pre-release 序**(semver 2.0.0 规则 11:预发布排在同三元组的正式版**之前**,点分标识符数字比数字、字母比字母,短字段集在前)、`manifestBuildForArm64`(BUILD_POLICY 里 `--split-per-abi` 给 arm64 `versionCode` +2000 那条坑,写成函数而不是注释)、`decideUpdate`(none / available / forced)

低于 `minimumSupported` 一律 forced,即使 feed 里没有更新的 build —— 继续用下去是对着已经不满足的协议取流。

- `update_feed.dart` —— `UpdateFeedTransport`(读 feed 的端口)、`UpdateFeedResponse`、`kDefaultUpdateFeedTimeout`(15s)、
  `ReleaseEntry`/`ReleaseAsset`(含 `assetFor` 按包名挑本平台工件)、`UpdateChecker.check`(永不抛)与 `UpdateCheckResult.decide`
- `channels.dart` —— `ReleaseTrack`(stable 不给 beta;beta 收 beta/rc;nightly 全收)+ `selectRelease`
  (轨道外候选**计数而不是悄悄丢** —— "有更新但你不在通道里"与"没有更新"在用户那边长得一模一样)、
  `ApkAbi` + `selectApk`(**精确 ABI → universal → 没有**;把 armeabi-v7a 交给 arm64 设备不是"装得慢",是对着已在的签名报冲突)、
  `WindowsFlavor`(msix / installer / portable —— 这一选择同时**决定数据落在哪**:MSIX 在 `Packages\<PFN>`,portable 跟着 exe 走)+ `selectWindowsAsset`
- `integrity.dart` —— `sha256Hex` / `requireDigest` / `digestMatches` / `parseDigestManifest` / `ArtifactSize`。
  摘要两侧都归一化(大写、空白、`sha256:` 前缀),因为**格式造成的不匹配**会让用户去找一个不存在的 bug;
  `ArtifactSize` 在取字节**之前**用声明大小撞上限
- `snooze.dart` —— `DismissedUpdate`(编解码严格:`4.1.0-beta.1+5099|<iso>|<minutes>`,解不出来当"没有记录"→ 再问一次而不是永不问)、
  `UpdateNoticeStore` 端口 + `InMemoryUpdateNoticeStore`、`SnoozeChoice`、`UpdateNagPolicy.shouldOffer`
  (**更新的版本必然打破沉默** —— snooze 是关于那个 build 的,不是关于"别烦我";被 snooze 的 4.1.0 不该吞掉可能带安全修复的 4.2.0)

## 行为契约

| 项 | 规则 |
|---|---|
| 取 feed | 只经 `UpdateFeedTransport`;本包不依赖 `pure_live_network`,绑定在 App 组合根(`apps/pure_live/lib/app/update_transport.dart`)。L0 之间互不依赖,见 [依赖规则](../../../docs/architecture/dependency-rules.md) §3。 |
| 超时 | `check` 自带 15s 预算,可注入。设置页在 `await` 之后才弹结果,没有截止线时一个不回话的主机会让「正在检查更新…」一直挂着。 |
| 失败 | 传输异常、超时、非 2xx、JSON 畸形全部落到 `UpdateCheckResult.error`,`check` 本身不抛 —— 检查更新失败不该把发起它的界面带走。 |
| 版本 | feed 头部版本解析失败的行被跳过,取下一条能解析的。 |
| 生命周期 | `UpdateChecker` 不创建也不关闭 HTTP 客户端:客户端由 runtime 持有,同一个客户端还在服务扩展网关。 |
| 通道 | `ReleaseTrack.stable` 永不返回预发布;`selectRelease` 把被通道挡掉的条数报出来。 |
| 工件 | 挑不到就返回 null,由调用方显示"有此版本但本平台没有包";**不做"下一个能下的就下"** —— 下错 ABI 的代价是签名冲突。 |
| 完整性 | 校验失败抛 `IntegrityFailure`(带 expected/found);没有摘要可查时同样抛,而不是当成通过。 |

## 验证

- 分析:`dart analyze packages/foundation/release`(2026-10-11:0 issue)
- 测试:`dart test` —— **28 例**全绿(`AppVersion` 解析/比较/ABI build、feed 解码与超时、`assetFor` 平台挑选)。
  本轮新增的 pre-release 序、`channels` / `integrity` / `snooze` **没有新增测试**;行为用仓库外一次性脚本观测:
  `[beta.1, beta.2, rc.1, 4.1.0]` 排序正确、stable 轨道 skipped=1、arm64 命中自己的 APK 而 x86_64 落 universal、
  `sha256: <大写HEX>` 归一化后可验、dismiss 后再问同版本 false 而问更新版本 true、脏记录解出 null。脚本已删除。

## 未验证

- 真实 `assets/releases.json` 的形状:测试用夹具,线上 feed 的字段名与本平台工件命名没有对账过。
- `assetFor` / `selectApk` / `selectWindowsAsset` 的名字匹配是**子串启发式**,在真实工件命名(仓库目前只发 APK 与 windows zip)上的命中率未验证;加新命名风格时先看这里。
- `integrity.dart` 假定发布脚本真的写了 sha256 摘要。**仓库现有的 release 工件是否带 `sha256:` 摘要文件没有核对过**,`parseDigestManifest` 的形状也是推演的。
- `UpdateNagPolicy` 的时长档位(20min / 8h / 3d / 7d)是拍的;`snooze` 记录与 App 偏好存储的绑定还没接(端口在本包,实现在组合根)。

- 设备上的更新弹窗与"下载完校验再安装"的整条链:见 App 侧 acceptance,不属于本包。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 依赖

- `crypto ^3.0.0`(SHA-256 摘要)、`pure_live_utils`(叶子:`Clock` 给 nag policy 与轨道选择)。
