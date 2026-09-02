# Pure Live v3.1.2 Android / Windows 阶段更新

## 1. 范围与来源判定

- 版本：`3.1.2+4115`
- 维护基线：本仓库 `master`，本轮没有同步上游代码。
- 交付目标：Android `arm64-v8a`、Windows x64 安装程序与便携 ZIP。
- 问题来源：Windows 全屏为 `window_manager 0.5.2` 原生状态与本项目隐藏标题栏初始化组合后触发的依赖交互缺陷；CC 分类为平台把旧 JSON 地址迁移到官方 Glive HTML 后暴露出的本仓库容错缺口。两者都不是 v3.1.1 多画面音量、声音焦点或弹幕改动引入。

## 2. 根因链

1. 桌面初始化使用 `WindowOptions(titleBarStyle: TitleBarStyle.hidden)`。
2. `window_manager 0.5.2` 的 Windows 原生初始化会把该窗口标记为 `is_frameless_=true`。
3. 插件 `SetFullScreen` 先把全局 `g_is_window_fullscreen` 改为 `true`，但实际窗口样式、显示器边界和尺寸变化全部受 `if (!is_frameless_)` 保护。
4. 因而旧版 Dart 状态、全屏图标和返回逻辑已经切到全屏，Windows HWND 却仍为普通重叠窗口；用户看到标题栏、任务栏、直播间侧栏和原窗口尺寸。
5. 插件自己的 `SetTitleBarStyle` 会把 `is_frameless_` 重置为 `false`。进入 Windows 全屏前幂等重放同一隐藏标题栏样式，即可让随后 `SetFullScreen(true)` 执行真实的样式与边界变换。

这一链路同时解释了旧版“按钮状态已经变化但画面没有全屏”的现象，也排除了直播源比例、播放器纹理、弹幕布局和多画面代码作为根因。

## 3. 修复设计

- 把桌面全屏进入步骤抽成可测试的 `enterDesktopFullscreen`：
  - Windows：先调用 `setTitleBarStyle(TitleBarStyle.hidden)`，再调用 `setFullScreen(true)`；
  - macOS / Linux：保持直接进入全屏，不引入 Windows 专用副作用。
- 不修改退出路径。插件在退出时继续恢复进入前保存的窗口样式、矩形、标题栏类型和最大化状态。
- 每次进入都重复执行幂等准备，覆盖首次启动、普通窗口、最大化、PiP 往返及其他曾经把窗口设为 frameless 的路径。
- 新增确定性测试锁定调用顺序，避免后续依赖升级或重构再次删掉必要准备步骤。

### 3.1 CC 分类迁移兼容

- 现网核对确认 `https://cc.163.com/category/?format=json` 会跳转到网易官方 `https://ds.163.com/glive/`，响应由 JSON 变为 HTML；旧代码在 `jsonDecode` 位于保护块之外，分类页因此直接失败。
- 解析器现在始终先建立稳定的四个顶级分类。旧 `game_list` JSON 可用时继续填充游戏子分类；HTML、空响应、未知或部分 schema 时返回顶级分类，不影响推荐、搜索、房间详情与播放。
- 接口门禁只接受两种合同：包含 `game_list` 的旧 JSON，或主机、路径均匹配网易官方 Glive 的迁移跳转；未知重定向和任意 HTML 继续报错。
- 新增确定性测试覆盖 HTML 回退、旧 JSON 全部分类与三种标签分组，避免后续把解码异常重新提升为页面级故障。

## 4. 旧版与修复版实测

测试设备当前显示模式为 3840×2400、250% Windows 缩放、200 Hz；应用截图使用逻辑像素。

| 场景 | v3.1.1 | v3.1.2 修复版 Debug |
| --- | --- | --- |
| 普通窗口进入全屏 | 仅图标/状态变化，截图仍为 `1155×703` | 截图变为完整显示器 `1536×960` |
| 最大化进入全屏 | 仍为 `1536×912`，保留标题栏和工作区边界 | 变为 `1536×960`，标题栏和任务栏不占位 |
| 原生 HWND | 仍为 `(188,104)-(1347,809)`、普通窗口样式 | 全屏为 `(0,0)-(1536,960)`，进程响应正常 |
| 普通窗口退出 | 无真实全屏可恢复 | 精确恢复 `(188,104)-(1347,809)` |
| 最大化退出 | 无真实全屏可恢复 | 回到 `1536×912` 工作区，`IsZoomed=true` |

实测使用真实虎牙直播画面和弹幕；进入、退出过程中播放器持续出帧，弹幕继续更新。

## 5. 自动化证据

- `test/windows_fullscreen_transition_test.dart`
  - Windows 先准备隐藏标题栏，再进入全屏；
  - 其他桌面平台只调用全屏。
- `test/windows_pip_presentation_test.dart`
  - PiP 前的宽屏/全屏呈现快照保持原有优先级。
- `test/cc_category_fallback_test.dart`
  - 官方迁移 HTML 返回稳定顶级分类；
  - 旧 JSON 继续正确填充端游、手游和其他子分类。
- 聚焦门禁：Analyze 0 issue，4/4 测试通过。
- 质量记录：`local-artifacts/build-records/20260831T091722185Z-quality-focused.json`。
- Windows Debug 构建记录：`local-artifacts/build-records/20260831T101208353Z-build-windowsx64-debug.json`。

`local-artifacts` 为本机忽略目录；正式 Release 同时上传可公开核对的构建元数据、SHA-256 和本说明。

## 6. 发布门禁

正式发布只在下列条件全部满足后执行：

1. 冻结提交完成一次完整 Analyze、Flutter 回归、公开平台接口合同与全仓审计；
2. Android arm64-v8a APK 核对包名、版本、唯一 ABI、Flutter 资源、关键原生库、签名状态、大小与 SHA-256；
3. Windows 安装程序和便携 ZIP 核对版本、架构、运行时白名单、安装目录能力与 SHA-256；
4. Windows 正式包重复普通窗口/最大化全屏往返，不只依赖 Debug 结果；
5. GitHub tag、Release、源码提交、更新源和资产元数据相互一致。

## 7. 回滚

- 代码回滚点只涉及 `lib/player/utils/fullscreen.dart` 的 Windows 全屏准备步骤及对应测试。
- 若未来 `window_manager` 原生实现移除 `is_frameless_` 阻断，可在升级审计和同一运行矩阵通过后删除兼容步骤；在此之前保留幂等调用。
- Android 不执行 Windows 专用分支，移动端旋转、沉浸式系统栏和竖屏直播比例逻辑不受本补丁影响。

## 8. 正式包发布后运行复验

- Android v3.1.2 APK 已在 PJZ110 / Android 16 覆盖升级，原关注数据保留；10 次冷启动全部成功，293～332 ms、平均 306.2 ms，0 FATAL/ANR。
- Android 分类和搜索平台标签左右端点稳定；网易 CC 旧分类地址返回官方 Glive HTML 时仍保留四个稳定入口。
- Android 正确识别 120 Hz；省电、均衡、最高三档即时切换，最高档在冷启动后保持。
- Android 直连 Twitch 搜索会显示局部失败；临时使用手机可达的本机 Clash 应用代理后，Twitch 原生搜索和在线人数正常，测试结束已恢复原代理地址与关闭状态。
- Windows v3.1.2 便携 Release 正确识别 3840×2400 / 200 Hz；三档刷新率即时生效并可持久化。普通窗口和最大化进入全屏均覆盖完整逻辑显示器，Escape 后分别精确恢复。
- Android 与 Windows 完整运行记录分别见 `docs/ANDROID_RUNTIME_AUDIT_3_1_2.md`、`docs/WINDOWS_RUNTIME_AUDIT_3_1_2.md`；未执行项目继续保留在验收矩阵中，不以已通过子集替代全平台长时结论。
