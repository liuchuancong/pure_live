# 上游同步审查：9e80f3be（2026-08-26）

<!-- file_review; semantic_change_ledger; issue_and_bug_mapping; fork_feature_impact; quality_assessment; disposition; conflict_resolution; regression_plan; verification_plan -->

## 冻结范围

- 维护分支：`396de06701df94ba17340a00a3a6bf7f6f6712dc`
- 上游完整提交：`9e80f3be0e21917fd52e5df2b42cc3382a2a38d4`
- merge base：`ff17c2331be212519e9d0dea02872a00c0afa7dc`
- 入站范围：`ff17c2331be212519e9d0dea02872a00c0afa7dc..9e80f3be0e21917fd52e5df2b42cc3382a2a38d4`
- 机器证据：`local-artifacts/upstream-reviews/upstream-9e80f3be0e21.json`（本地，不提交）

## issue_and_bug_mapping

| Issue | 维护分支映射 | 根因/结论 |
| --- | --- | --- |
| [#802 新版 UI 竖屏直播比例有问题](https://github.com/liuchuancong/pure_live/issues/802) | `present` | 上游最新提交仍未建立可信显示比例；布局、播放器纹理和 Android Surface 各自读取尺寸。异常 `dw/dh`、旧 Surface 或手动方向覆盖会在普通页、全屏与小窗继续产生不同结果。 |
| [#797 竖屏切换横屏后比例失调](https://github.com/liuchuancong/pure_live/issues/797) | `present` 的同根因历史报告 | “强制销毁播放器后正常”表明可复用播放器保留的尺寸状态参与了错误；仅重建播放器属于高开销规避，不作为主修复。 |
| [#790 竖版直播比例失调](https://github.com/liuchuancong/pure_live/issues/790) | `present` 的同根因历史报告 | 上游关闭 Issue 时未附确定性回归；后续 #802 证明相邻路径仍存在。 |
| [#803 切换直播间页面显示数量少](https://github.com/liuchuancong/pure_live/issues/803) | `already-fixed` 后继续增强 | 维护分支已恢复半屏自适应多列；本轮增加完整观看日期以及有限自定义/不限数量设置。 |

## semantic_change_ledger

| commit | upstream intent / implementation | quality_assessment | fork_feature_impact | disposition | regression_plan |
| --- | --- | --- | --- | --- | --- |
| `390ae86bca8c576919c5afba510262827ddafacb` | 录播房间允许解析流；启动后预热 FFmpeg；Android 改回 Zoom 路由动画。 | 录播判定正确；预热应异步且显式吸收失败；Zoom 会削弱本仓库已验证的预测返回。 | 影响录制、启动负载和 Android 返回手势。 | `adapt`：接受录播判断，采用有界异步预热，保留 Predictive Back。 | 录播流解析单测、初始化静态检查、返回策略回归。 |
| `1850abc4c34a806f3fc4d9038f951c12602fab2c` | 根据播放器宽高增加外层 `FittedBox`，移除 Windows 可见视口纹理约束。 | 原始宽高可能异常或暂态，且适配器已有缩放；直接叠加会再次双重缩放。Windows 改动会恢复大纹理资源风险。 | 会覆盖 v3.0.2/v3.0.3 的单一缩放与 Windows 内存策略。 | `rewrite`：移动端由管理层以稳定、可信比例做唯一缩放，适配器设为 fill；桌面保留现有适配器与视口策略。 | 横/竖/异常比例、手动覆盖、普通/全屏/PiP/应用小窗与不同内核策略测试。 |
| `5707aad5a754f6fd3aa8cb836e53f78f41121a08` | 新增翻转/抽屉式 `LivePlayShell`，重写普通直播页并隐藏方向按钮。 | 移动端翻转把视频与常用操作分到两个面，删除既有普通页回归且增加动画状态；不满足维护分支“视频、画质、弹幕同时可见”不变量。 | 会改变普通页信息架构、弹幕生命周期、返回路径和方向诊断入口。 | `drop`：不引入 Shell，不删除回归，不隐藏方向按钮。 | 普通页可见性、侧滑返回、弹幕列表保活测试。 |
| `3d946b2c2473ed85731314a5c17041e799fbf86a` | 上游合并维护分支历史。 | 合并提交本身无额外文件语义；以其两侧实际提交逐项审查。 | 建立共同历史但不替代冲突处理。 | `accept` 祖先关系，最终使用真实 merge。 | 祖先关系与最终树差异核对。 |
| `a42907b7b440f179c4d8d44f03ec870f9027dd3f` | 为竖屏布局增加 compatibility mode，回到 16:9 兼容显示。 | 可作为用户恢复入口，但只改变外层布局，未修复纹理比例；部分路径仍直接使用未经校验的 `sourceAspectRatio`。 | 与本仓库既有兼容枚举重叠。 | `adapt`：保留现有兼容模式，统一使用可信比例，不复制重复布局树。 | 兼容、均衡、沉浸模式布局测试。 |
| `9e80f3be0e21917fd52e5df2b42cc3382a2a38d4` | 小宽度直播记录改为头像单行，大宽度双列，降低图片缓存宽度。 | 解决上游 #803 的单页信息密度，但 520 px 阈值会让手机半屏退化单列，且覆盖维护分支已验收的 2×2 卡片。 | 会回归用户明确要求的半屏多列与封面主视觉。 | `adapt`：保留维护分支自适应多列；吸收紧凑信息思想，并增加完整日期、用户自定义数量与不限模式。 | 半屏 2×2、窄屏回退、完整日期、有限/不限持久化与备份回归。 |

## file_review

| file | disposition / conflict_resolution |
| --- | --- |
| `lib/common/global/initialized.dart` | `adapt`：增加失败可恢复的异步 FFmpeg 预热，不阻塞首屏。 |
| `lib/main.dart` | `drop` 上游 Zoom 变更，保留 `PredictiveBackPageTransitionsBuilder`。 |
| `lib/modules/live_play/dialogs/play_other.dart` | `adapt`：保留维护分支宽度驱动多列；增加完整日期并读取新的数量语义。 |
| `lib/modules/live_play/widgets/layout/live_play_content.dart` | `adapt`：保留稳定普通页；所有模式只消费统一可信比例。 |
| `lib/modules/live_play/widgets/layout/live_play_shell.dart` | `drop`：不接入翻转 Shell；最终合并树不保留未使用文件。 |
| `lib/modules/live_play/widgets/video_player/video_controller_panel.dart` | `drop` 隐藏方向按钮的改动，保留手动覆盖与诊断入口。 |
| `lib/player/adapters/media_kit_adapter.dart` | `adapt`：保留 Windows 视口纹理；移动端由管理层建立唯一比例边界。 |
| `lib/player/core/player_manager.dart` | `rewrite`：保留尺寸防抖/房间重置；将移动端各内核统一为“可信比例 + 单层 BoxFit”。 |
| `lib/recorder/services/ffmpeg_service.dart` | `accept` 现有服务边界初始化保证；仅保留语义等价实现。 |
| `lib/recorder/services/stream_resolver_service.dart` | `accept` 录播房间判断。 |

## fork_feature_impact

- 保留 Android 普通页、横屏全屏、系统画中画、应用小窗共用播放器/弹幕会话的设计。
- 保留 Windows 可见视口纹理约束、预测返回、方向覆盖按钮、2×2 直播记录和发布元数据。
- 新增的历史“不限”采用 `0` 作为持久化值；旧安装缺失键仍为 50，现有正数设置原样保留。
- 移除升级迁移中写死的 50 条截断，避免用户选择更大数量后被升级流程静默丢弃。

## conflict_resolution

最终创建真实 merge，冲突文件以维护分支产品不变量为基底，逐项吸收上述 `accept/adapt/rewrite` 语义；版本、Release、工作流和更新源保持维护分支值。合并后的新修复单独提交，便于回滚上游同步与本轮行为增强。

## verification_plan

1. 上游审批门禁与真实 merge 后全仓审计。
2. 定向单元/Widget 测试：视频几何、竖屏策略、普通页布局、半屏记录布局、历史元数据/迁移、返回策略、录播流判断。
3. `git diff --check`；代码完成后执行一次 `flutter analyze`。
4. 本轮不连接设备、不构建安装包；Android 交付轮再补普通竖屏、普通横屏、全屏、系统 PiP、应用小窗和房间/画质切换设备证据。

## rollback

- 上游同步回滚点：最终 merge 提交。
- 竖屏比例回滚点：移动端统一比例包装与几何归一化提交。
- 历史增强回滚点：`historyLimit == 0` 语义、迁移去截断和历史 UI 提交。
