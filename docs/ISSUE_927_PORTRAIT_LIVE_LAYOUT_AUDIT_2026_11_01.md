# Issue #927 竖屏直播适配回归审计（2026-11-01）

Issue: <https://github.com/liuchuancong/pure_live/issues/927>
报告基线：Pure Live 3.1.19 / Samsung Galaxy Z Fold6 / Android 16
本机源码基线：`63ce0126888f3d24abed74de683cdc74a41e62b6`（`v3.1.19-16`，工作区干净）

## 1. 结论摘要

| 需求 | 结论 | 证据 |
| --- | --- | --- |
| A「兼容 16:9」恢复 3.1.2 显示效果 | 已修复 | `resolveCompatibilityVideoHeight` + T1/T10/T11/T16 |
| B「均衡模式」视频区随弹幕区联动 | 已修复 | 视频区改为占据弹幕面板之外的剩余空间 + T2/T3/T9 |
| C 展开态按直播源方向选分屏拓扑 | 已修复（Android 宽窗口） | `resolveLivePlayNormalLayout` + T4/T5/T6/T7/T8 |

问题在当前 `HEAD` 复现（`63ce0126`），根因分类：**`integration-conflict`**。

## 2. 根因

### 2.1 首个错误状态

`lib/domains/live/presentation/playback/widgets/layout/live_play_content.dart` 的
`LivePlayNormalLayout.build`：当「兼容 16:9」被选中时，`useAdaptivePortraitFrame` 因
`portraitLayoutMode != PortraitLayoutMode.compatibility` 恒为 `false`，布局落到通用 `Column`，
视频交给 `LivePlayVideoFrame(expandToParent: false)`，即 **固定 `AspectRatio(16 / 9)`**。

于是竖屏直播在「兼容 16:9」下拿到的不是按源比例计算的画面高度，而是一个横屏 16:9 框：
9:16 画面 contain 进 16:9 框后只剩一条窄条（Issue 图 2 的「未适配画面」）。

### 2.2 3.1.2 的正确语义

`v3.1.2:lib/modules/live_play/widgets/layout/live_play_content.dart` 的
`LivePlayLayout._buildCompatibilityVideo`：

```dart
final maxHeight = constraints.maxHeight * 0.6;
final calculatedHeight = width / aspectRatio;
final height = calculatedHeight > maxHeight ? maxHeight : calculatedHeight;
```

即 `min(宽度 / 源宽高比, 0.6 × 可用高度)`。Issue 里「约 6:4」指的是这个 **0.6 上限**
（弹幕至少保留 40%），不是固定容器比例，也不是固定区域切分。横屏源代入该式仍然等于
自身 16:9 高度，所以对普通横屏直播无行为变化。

### 2.3 回归来源（提交级证据）

`git log -S` 与逐提交 blob 比对（`_buildCompatibilityVideo` 是否存在）：

| 提交 | 日期 | 结果 |
| --- | --- | --- |
| `f5dd66b0f fix(视频播放比例)` | 2026-08-26 19:52 | 恢复兼容模式实现（存在） |
| `f0c0fbf02 feat(live_play): 添加 showPanel 属性…` | 2026-08-27 11:46 | 仍存在 |
| **`7ef505213 merge: integrate reviewed upstream e696bb79`** | 2026-08-27 20:21 | **消失** |

`7ef505213` 的两个父提交状态不同：parent1 `53b8dbf88` 不含该实现，parent2 `05db8871c` 含该实现；
合并结果与 parent1 完全一致，说明冲突解决时把维护分支的兼容模式实现整体丢弃了。
此后 `v3.1.3`（`909a1a9`）、`v3.1.19`（`31d4d96`）与当前 `HEAD` 都未恢复。

补充事实（用于解释「为什么 3.1.2 正常」）：`git merge-base v3.1.2 v3.1.3` = `527fea1b`，
且 `v3.1.2` 不是 `v3.1.3` 的祖先——3.1.2 的发布线保留了该实现，但从未合回 master。
因此不是「3.1.3 引入了新 bug」，而是 **3.1.2 的修复没有随主线带走**。

### 2.4 需求 B / C 的断点

- B：`PortraitLiveRoomLayout` 把视频放在 `Positioned.fill`、弹幕面板 `Positioned(bottom: 0)`
  叠在画面上。弹幕面板高度变化只改变覆盖面积，视频区尺寸不变——「视频区域不跟随」是结构性的，
  不是某次计算写错。
- C：`resolveLivePlayNormalLayout(width)` 只接受宽度，`width > 680` 一律返回 `desktopSplit`，
  与直播源方向无关；折叠/展开只能通过窗口宽度体现，源码里没有任何铰链/折叠 API。

## 3. 修复

### 3.1 需求 A

新增纯函数 `resolveCompatibilityVideoHeight`（`@visibleForTesting`），按 3.1.2 语义返回
`min(width / sourceAspectRatio, (1 - danmakuShare) × availableHeight)`，并对未知/非法比例回退
16:9、对退化高度保留画质栏与弹幕区的固定占位。

`_buildPortraitStack` 在兼容模式下用 `SizedBox(width, height: …)` 决定画面区域，
`_buildNormalView` 相应把视频 surface 以 `expandToParent: true` 传入（兼容模式自有尺寸，
不再叠加 16:9 外框）。

### 3.2 需求 B

`PortraitLiveRoomLayout` 的视频层从 `Positioned.fill` 改为
`Positioned(top: 0, bottom: current)`：视频区高度 = 可用高度 − 弹幕面板高度，
面板拖动/吸附时视频区立即用剩余空间重排；`AnimatedSlide` 下滑退出时露出的区域由一层黑色
背景承接，不显示页面底色。弹幕调节入口与三段吸附、下滑进入竖屏全屏的交互完全沿用。

### 3.3 需求 C

`resolveLivePlayNormalLayout` 改为按 `宽度 + 直播源方向` 选择拓扑：

- 窄窗口（≤ 680）→ `portraitStack`（折叠态行为不变）
- 宽窗口 + 竖屏源 → `desktopSplit`（视频左、弹幕右）
- 宽窗口 + 横屏源 → `landscapeStack`（视频上、弹幕下，行为等同折叠态）

方向来自 `LivePlayerFacade.isVerticalVideo`（由解码帧尺寸 `height > width` 驱动），
不使用设备物理旋转。`splitBySourceOrientation` 仅在 `PlatformUtils.isAndroid` 时为真，
Windows 桌面保持既有左右分屏，避免桌面回归。

### 3.4 需求 C 的后续优化（折叠屏实机反馈）

首轮交付后哥在 Fold6 上验收，指出两处仍需调整：

**（1）横屏源上下分屏：旋转 90° 后视频挤占弹幕区**

原实现让视频以固定 `AspectRatio(16/9)` 撑满宽度，`Expanded` 兜住弹幕区。展开态
旋转成宽扁窗口后，`宽度 × 9/16` 会暴涨，弹幕区被压到几乎为零。

修复：`landscapeStack` 改为「视频 `Expanded` + 弹幕固定高度」。
弹幕区高度取新设置项 `landscapeDanmakuHeight`（默认 220 px，可调 120–480 px），
并夹在 `[96, 可用高度 × 0.6]` 之间——下限保证列表可用，上限保证短页面时不会反过来
把视频挤没。视频在剩余高度里按源比例内缩，不再撑满整页。

设置项位于「竖屏直播设置 → 全屏、小窗与弹幕」分组，持久化键
`landscapeDanmakuHeight`，即时生效（`Obx` 监听）。

**（2）竖屏源左右分屏：画面被塞进 16:9 横框**

原实现左区是 `Expanded(child: video)`，而 `video` 自带 `AspectRatio(16/9)`。
竖屏源因此显示成「16:9 横框 + 中间一条竖屏内容 + 两侧黑边」。

修复：宽窗口的两种拓扑都由布局自己掌握视频框——`video` 以 `expandToParent: true`
传入，外层用 `AspectRatio(源宽高比)` 约束。竖屏源时左区宽度改为
`可用高度 × 源比例`（展开态 900×700 → 394 px），画面高度撑满、**无黑边**，
省下来的宽度全部给弹幕区（506 px）。宽度上限保留
`minimumDesktopSplitPanelWidth`（240 px）作为弹幕区最小宽度；横屏源仍按
`屏宽 − 面板宽` 走原有路径，行为不变。

## 4. 自动化证据

新增 `test/domains/live/live_play_normal_layout_test.dart`（23 项）：

| 覆盖 | 断言要点 |
| --- | --- |
| T1 竖屏源 + 兼容 16:9 | 视频区 360×420（= min(640, 0.6×700)），弹幕 231 > 200 |
| T10 横屏源 + 兼容 16:9 | 视频区高 202.5（= 360/(16/9)），与旧 16:9 行为一致 |
| T11 源尺寸未知 | NaN/0/负/∞ 比例回退 16:9，不溢出 |
| T16 极端窗口 | 320×240、240×180、900×260 无布局异常 |
| T2/T3 均衡模式 | 面板 308→476 时视频 392→224，且两者之和恒等于页面高度 |
| T2 不覆盖 | 视频区底边 ≤ 弹幕面板顶边 |
| T9 沉浸模式 | 面板初始高度取 `portraitPanelRange` 的 `minimum` |
| T4 | 展开 + 竖屏源：左区 393.75 宽（= 700×9/16）、高 700、比例 9:16，弹幕区拿剩余 506.25 |
| T14 | 展开 + 竖屏源 + 旋转成 1100×450：左区 253.1 宽、弹幕区 ≥ 240，无溢出 |
| T5 | 展开 + 横屏源：弹幕区 220（默认保底），视频拿 700−220−48−1 |
| T15 | 展开 + 横屏源 + 旋转成 1100×450：弹幕区 240（自定义值），视频按 16:9 内缩不撑满 |
| T6 | 窄窗口竖屏/横屏源都保持上下堆叠 |
| T7 | 折叠 360 → 展开 900 后拓扑切换 |
| T8 | 同一宽窗口下源方向变化后拓扑切换 |
| T13 | `splitBySourceOrientation=false`（非 Android）保持左右分屏 |

执行结果：

- 目标测试：`flutter test test/domains/live/live_play_normal_layout_test.dart` → **23/23 通过**
- 全量测试：`flutter test --concurrency=6` → **238/238 通过**（含原有 47 个测试文件）
- 静态分析：`flutter analyze` → **No issues found!**
- 格式：`dart format` 对改动文件已应用并复核 **0 changed**

## 5. 已知限制

`tool/local_ci.ps1 -Scope Full` 当前在 `HEAD` 上无法通过：`tool/validate_build_policy.ps1`
要求 `.github/workflows/audit-upstream.yml` 等文件存在，而它们在 `4a0cf09fe`
（"Remove outdated GitHub workflows…"）已被删除。这是既有不一致，与本修复无关，
本轮未改动该策略脚本或工作流。等价证据见第 4 节（Analyze + 全量测试 + 格式检查）。

## 6. 人工验收清单（Galaxy Z Fold6 / Android 16）

| 编号 | 操作 | 预期 |
| --- | --- | --- |
| M1 | 竖屏直播间 +「兼容 16:9」 | 画面完整、左右留黑边，下方弹幕正常可见 |
| M2 | 均衡模式，弹幕区调大 | 画面缩小但完整不变形，弹幕可读 |
| M3 | 均衡模式，弹幕区反复调大调小 | 画面连续跟随，无闪烁/回弹/塌缩 |
| M4 | 展开，竖屏直播 | 保持左右分屏 |
| M5 | 展开，横屏直播 | 改为上下分屏 |
| M5b | 展开 + 横屏直播，旋转 90° | 弹幕区仍保留设置的高度（默认 220 px），内容不被挤没 |
| M5c | 「竖屏直播设置 → 上下分屏时弹幕区高度」拖动滑块 | 分屏布局实时跟随，无需重进直播间 |
| M5d | 展开 + 竖屏直播 | 左区画面按 9:16 撑满高度、无黑边，右侧弹幕区变宽 |
| M6 | 折叠，竖屏/横屏直播 | 保持原折叠态布局 |
| M7 | 展开态切换竖屏源↔横屏源 | 按新源方向切换分屏，无旧方向残留 |
| M8 | 展开→折叠→展开 反复 | 每次窗口变化都重新布局 |
| M9 | 切换其他竖屏适配模式再切回 | 各模式各自生效 |
| M10 | 进入/退出全屏 | 布局与适配状态正确恢复 |
| M11 | 应用内返回 / 系统返回手势 | 返回路径正确，无布局残留 |
| M12 | 切换直播间/线路/清晰度 | 不继承上一个源的比例/方向 |
| M13 | 普通手机窗口 | 不受宽窗口分屏逻辑影响 |
