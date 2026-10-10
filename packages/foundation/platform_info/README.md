# pure_live_platform_info

> 职责:平台能力探测与 Android、iOS、桌面、Web 适配

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_platform_info.dart`;内部实现放 `lib/src/` |

## 内容

- `platform_info.dart` —— `PlatformKind`、`detectPlatform(os, isTelevisionDevice, isWeb)`、`capabilitiesFor(kind)` 能力矩阵、
  `PlatformCapability` 枚举 + `capabilities.enabled` / `supports(cap)`(把八个布尔变成可传递的"哪一项")、
  `copyWith` / `restrict`(两个目标同时成立时取交集)/ `without`(关掉单项)、值相等(否则每次派生行都被当作新行,子树无限重建)
- `device_profile.dart` —— `DeviceForm` + `resolveDeviceForm(shortestLogicalWidth, isTelevision, isAutomotive)`
  (**布局边界是启发式**:600 / 840 / 1080 逻辑像素;电视必须由宿主显式声明,因为 960+ 宽的电视与桌面窗口在像素上分不开)、
  `DeviceFormLayout`(`isCompact` / `isTouchFirst` / `isPointerFirst` / `requiresFocusNavigation`)、
  `CapabilityOverride` + `DeviceProfile.resolve`(**只允许关,不允许开** —— 给一台没验证过的设备发一个能力是断言,
  而矩阵是审过的;`disabledByOverrides` 让"规则不再命中"看得见)、`DeviceDescription.summary()/toJson()`
  (一行设备描述:模型串有上限并去换行,因为它来自平台且没有边界)

读 `TargetPlatform` 与插件是 Flutter 侧的事,所以这里只吃纯值:未识别的系统名落 `unknown`(全 false),
新平台不会悄悄继承桌面的文件系统权限。UI 不自己判平台,拿一次矩阵往下传。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze packages/foundation/platform_info`(2026-10-11:0 issue)
- 测试:`dart test` —— **21 例**全绿(矩阵自洽、unknown 不借 web、逐目标旗标)。
  `device_profile.dart` 的表单推断、覆盖规则与 `DeviceDescription` **没有新增测试**;行为用仓库外一次性脚本观测
  (320→phone / 700→foldable / 900→tablet / 1400→desktop / NaN→unknown / `isTelevision` 强制 tv;
  `modelPattern: 'shield'` 关掉 Shield 的 PiP 而 `'nomatch'` 那条没有生效;模型串被裁到 64 字符),脚本已删除。

## 行为契约(2026-10-10 起)

- **认不出来的系统答 `unknown`,不借 web 的答案**。旧回退注释写的是"最受限的目标",而 web 恰恰不是:
  它 `supportsPictureInPicture: true`、`isTouchPrimary: true`。于是一个 harmonyos / 改壳 Android 分支
  同时拿到两个乐观假设 **和** web 的存储分支(`kind == web` 这种问法在别处决定文件写到哪)。
  `PlatformCapabilities.unknown` 全 false —— 没人验证过的能力一律不给。
- `capabilitiesFor` 仍是对 `PlatformKind` 的穷尽 switch:加新目标不写矩阵就编不过,这是这个包存在的理由。
- web 的**输入方式不可从 OS 名推断**,所以有 `webIsTouchPrimary`(只改这一个旗标)。手机端与桌面端浏览器
  是同一个 kind、相反的布局规则,只有宿主能从 MediaQuery 分辨。
- 已知事实写进注释:tvOS 是唯一既没有后台音频也没有局域网遥控的目标(否则那两个开关在恰好一个平台上是死按钮)。

## 依赖

无(pub.dev 也不依赖)。禁止:任何 Flutter import —— 读 `TargetPlatform`/插件是 App 的事,这里只把
启动时收集到的原始信号回答成问题。

## 未验证

- **零消费者**,21 个测试钉的是矩阵自洽,不是"这台设备真的如此"。
- 每个旗标的**真实性**没有一台设备上验过(Android TV 的 secure storage、tvOS 的 PiP 限制都来自文档与常识)。
- `unknown` 的"全 false"是**保守**而不是**正确**:真出现新目标时,该做的是给它一行真的矩阵,而不是长期吃 unknown。
- `resolveDeviceForm` 的 600 / 840 / 1080 是分界**猜的**(Material 3 window size classes 的同族数字),
  没跟任何一份 UI 断点核对过;`foldable` 这一档在真机上与平板的重叠率未测。
- `CapabilityOverride` 靠**模型名子串**匹配:厂商改模型串(Android 的 `Build.MODEL` 常被运营商改写)就让规则失效,
  失效是静默的(只能从 `disabledByOverrides` 为空反推)。真机上的匹配率未测。
- 与 `foundation/files` 的关系仍是**平行枚举**:`platform_paths.dart` 自己写了一份 `LocalPathSourceKind`,
  理由是同层不建依赖边(见 [files 包](../files/lib/src/platform_paths.dart) 的头注释)。加新目标时两处都要改。
