# 竖屏画面比例与直播记录布局回归审计（2026-08-26）

## 冻结范围

- 维护分支基线：`ff17c2331be212519e9d0dea02872a00c0afa7dc`
- 审查时上游：`1850abc4c34a806f3fc4d9038f951c12602fab2c`
- merge base：`9427e5eadc3ede681ab2359b7507d35ff3a51d07`
- 证据：用户提供的普通竖屏、全屏和应用小窗截图；本轮未执行设备命令。

## Bug 1：竖屏源在普通页、全屏和小窗中被横向压缩

- **来源分类**：`upstream-existing`，并被维护分支的竖屏展示策略放大。
- **第一个错误状态**：vendored `AndroidVideoController` 把 `VideoParams.rotate == null`
  放入“旋转 90/270 度”分支，将已经是竖屏的 `dw/dh` 再交换一次；当 `dw/dh`
  不完整时还会直接得到零尺寸。
- **契约冲突**：应用层 `MediaKitAdapter` 使用 `(rotate ?? 0)`，因此同一条解码元数据在
  竖屏识别层被解释为 `1080 x 1920`，在 Android Surface 层却被解释为
  `1920 x 1080`。播放器布局按竖屏建立，原生纹理按横屏渲染，最终把画面横向压窄。
- **影响面**：普通竖屏、横屏全屏、系统画中画和应用小窗共用同一个
  `VideoController.rect`，所以不是四套 UI 各自出错，而是共同的 Surface 几何源错误。
- **修复方式**：在 `media_kit_video` 内建立唯一的 `resolveVideoParamsDisplaySize`：
  只接受完整 `dw/dh` 对，否则回退完整 `w/h` 对；缺失旋转按 0 度处理；旋转归一化后
  只对 90/270 度交换一次。应用层检测与 Android Surface 同时使用该结果。
- **时序加固**：Surface resize 通过串行队列按解码事件顺序提交，防止旧的异步
  MethodChannel 返回覆盖质量切换、房间切换或小窗切换后的新尺寸。
- **上游处置**：上游 `1850abc4` 也修改了视频尺寸，但整体恢复外层 `FittedBox`，同时
  移除维护分支的稳定检测和 Windows 纹理边界。该实现不整体合入，本轮采用 `adapt`，
  在真正产生错误的 Surface 元数据边界统一契约，避免再次叠加缩放层。

## Bug 2：横屏“直播记录”从多列退化为单列

- **来源分类**：`integration-conflict`。
- **根因提交**：上游 `b4781c90897aab4f2b7895ab06a7d86132dcfa50` 将维护分支原有
  的约 380 px 双列条件替换为“扣除边距后至少 520 px”，并增大标题、Tab、卡片底栏和
  网格间距。右半屏面板通常只有约 360–430 logical px，因此该条件恒为单列；原有
  `resolveRoomHistoryCardHeight` 两行适配函数也变成未使用代码。
- **修复方式**：按实际内容宽度和最小可读卡片宽度 168 px 计算 1/2 列，不再使用桌面
  固定断点；恢复紧凑标题、Tab、间距和 36 px 信息栏，并重新使用两行高度约束。常见
  横屏手机右半屏显示 2 x 2，真正狭窄的面板仍安全回退单列。

## 自动化证据

- `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`：通过，0 问题。
- 受影响测试共 26 项：通过。
  - `test/media_kit_video_geometry_test.dart`
  - `test/content_first_panel_layout_test.dart`
  - `test/portrait_stream_support_test.dart`
  - `test/live_play_normal_layout_test.dart`
  - `test/video_output_size_policy_test.dart`
- 新增回归覆盖：缺失旋转的原生竖屏、负数/超范围旋转归一化、不完整校正尺寸回退、
  横屏半屏双列、窄面板单列以及两行卡片完整高度。

## 相邻模式与剩余证据

- 普通横屏和明确 0/180 度的尺寸不变；明确 90/270 度仍只交换一次。
- Windows 继续保留现有纹理尺寸策略；共享解析器只消除尺寸契约分叉。
- 本轮未构建 APK、未连接手机、未执行设备采样。后续 Android 构建交付时应按普通页、
  横屏全屏、系统画中画、应用小窗和质量切换顺序补一次设备证据。
- 回滚点是本审计对应的几何解析器、Android Surface 队列和直播记录自适应布局修改；
  不涉及设置或用户数据迁移。
