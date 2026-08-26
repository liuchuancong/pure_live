# 竖屏画面比例与直播记录布局回归审计（2026-08-26）

> 后续统一几何识别、有效画面检测与三种呈现方案见
> [`VIDEO_GEOMETRY_ENGINE_2026_08_26.md`](VIDEO_GEOMETRY_ENGINE_2026_08_26.md)。原有解码尺寸修复保留为
> 第一层证据，新方案在其上增加黑边内嵌画面识别、会话隔离与动态 PiP 参数。

## 冻结范围

- 维护分支基线：`ff17c2331be212519e9d0dea02872a00c0afa7dc`
- 审查时上游：`c7d99cc38ac27effb8c2af8cd0a0586256a4c67f`
- merge base：`9427e5eadc3ede681ab2359b7507d35ff3a51d07`
- 证据：用户提供的普通竖屏、全屏和应用小窗截图；本轮未执行设备命令。

## Bug 1：竖屏源在普通页、全屏和小窗中被横向压缩

- **来源分类**：`upstream-existing`，并被维护分支的竖屏展示策略放大。
- **v3.0.3 已修正但不完整的部分**：vendored `AndroidVideoController` 曾把
  `VideoParams.rotate == null` 当成 90/270 度并交换尺寸；共享解析器已消除这一分叉，
  但用户复测证明它不是全部根因。
- **剩余第一个错误状态**：应用外层布局、各播放器适配器和 Android 原生纹理仍各自拥有
  一套比例/`BoxFit` 权限。CDN 或解码器发布异常 `dw/dh`、方向覆盖与旧 Surface 尺寸不一致时，
  原生纹理的异常比例仍直接进入适配器；外层只调整竖屏容器高度，不足以纠正纹理本身。
- **根本契约冲突**：方向识别已经判定“竖屏/横屏”，但实际绘制仍信任另一套原始宽高。
  因此手动方向开关能改变布局，却不一定改变画面比例；同一个复用纹理进入普通页、全屏和
  小窗后会连续复现。
- **影响面**：普通竖屏、横屏全屏、系统画中画和应用小窗共用同一个
  `VideoController.rect`，所以不是四套 UI 各自出错，而是共同的 Surface 几何源错误。
- **最终修复方式**：保留共享 `resolveVideoParamsDisplaySize`，再在 `PlayerManager` 建立移动端
  唯一的显示几何边界：方向判定是权威来源；同方向且合理的比例原样保留，异常窄、异常宽或
  与方向冲突的元数据分别回退 9:16、16:9 或 1:1。所有移动播放器适配器在该边界内使用
  `BoxFit.fill`，用户选择的 `contain/cover/fitWidth/...` 只由外层执行一次，消除多重比例权限。
- **时序加固**：Surface resize 通过串行队列按解码事件顺序提交，防止旧的异步
  MethodChannel 返回覆盖质量切换、房间切换或小窗切换后的新尺寸。
- **上游处置**：上游 `1850abc4` 也修改了视频尺寸，但整体恢复基于原始宽高的外层 `FittedBox`，同时
  移除维护分支的稳定检测和 Windows 纹理边界。该实现不整体合入，本轮采用 `adapt`，
  把移动端改写为“可信比例 + 单层缩放”。截至 `c7d99cc3`，上游后续提交只涉及返回和录制，
  没有继续修复竖屏比例；[#802](https://github.com/liuchuancong/pure_live/issues/802) 仍是同类证据。

## Bug 2：横屏“直播记录”从多列退化为单列

- **来源分类**：`integration-conflict`。
- **根因提交**：上游 `b4781c90897aab4f2b7895ab06a7d86132dcfa50` 将维护分支原有
  的约 380 px 双列条件替换为“扣除边距后至少 520 px”，并增大标题、Tab、卡片底栏和
  网格间距。右半屏面板通常只有约 360–430 logical px，因此该条件恒为单列；原有
  `resolveRoomHistoryCardHeight` 两行适配函数也变成未使用代码。
- **修复方式**：按实际内容宽度和最小可读卡片宽度 168 px 计算 1/2 列，不再使用桌面
  固定断点；恢复紧凑标题、Tab、间距和 36 px 信息栏，并重新使用两行高度约束。常见
  横屏手机右半屏显示 2 x 2，真正狭窄的面板仍安全回退单列。
- **本轮增强**：观看时间统一显示为本地 `yyyy-MM-dd HH:mm`；保留数量支持任意非负整数，
  `0` 表示“不限”。备份恢复与升级迁移使用同一语义，不再被旧的 50/500 条硬上限截断。

## 自动化证据

- `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`：通过，0 问题。
- 受影响测试共 59 项：通过（12 个目标文件，`--concurrency=12`）。
  - `test/media_kit_video_geometry_test.dart`
  - `test/mobile_video_frame_test.dart`
  - `test/content_first_panel_layout_test.dart`
  - `test/portrait_stream_support_test.dart`
  - `test/live_play_normal_layout_test.dart`
  - `test/history_metadata_test.dart`
  - `test/settings_upgrade_migration_test.dart`
  - `test/play_other_history_test.dart`
  - `test/live_play_back_scope_test.dart`
  - `test/ffmpeg_record_command_test.dart`
  - `test/recorder_storage_policy_test.dart`
  - `test/player_settings_controller_test.dart`
- 新增回归覆盖：缺失旋转的原生竖屏、负数/超范围旋转归一化、不完整校正尺寸回退、
  横屏半屏双列、窄面板单列、两行卡片完整高度、异常比例归一化、单层移动端缩放、
  完整观看日期以及有限/不限历史迁移。
- 合并后全仓审计：0 error；1 条既有空 `catch` 数量清单（30 处），不是新增阻断项。
- 长路径回归工具已加固：依赖解析使用真实目录，Native Assets 测试使用稳定 SUBST 短路径，
  避免 Flutter 3.47 在 iOS 生成目录及 FFmpeg Hook 的 Windows 长路径失败。

## 相邻模式与剩余证据

- 普通横屏和明确 0/180 度的尺寸不变；明确 90/270 度仍只交换一次。
- Windows 继续保留现有纹理尺寸策略；新增单层可信比例边界只用于 Android/iOS。
- 本轮未构建 APK、未连接手机、未执行设备采样。后续 Android 构建交付时应按普通页、
  横屏全屏、系统画中画、应用小窗和质量切换顺序补一次设备证据。
- 比例修复、上游 merge 与历史数量迁移分别提交，可独立回滚；历史旧值保持兼容，只有用户
  明确选择 `0` 时才进入不限模式。
