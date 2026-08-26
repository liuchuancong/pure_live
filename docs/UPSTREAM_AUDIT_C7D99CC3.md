# 上游同步审查：c7d99cc3（2026-08-26）

<!-- file_review; semantic_change_ledger; issue_and_bug_mapping; fork_feature_impact; quality_assessment; disposition; conflict_resolution; regression_plan; verification_plan -->

## 冻结范围

- 维护分支审查起点：`1b6fc8e81eb716278f932d5a88881151c0974358`
- 上游完整提交：`c7d99cc38ac27effb8c2af8cd0a0586256a4c67f`
- 上游吸收维护分支的拓扑合并：`af0fed608f1efcdefafbbcbd7248f55b9cdedb80`
- 新增行为审查基线 / merge base：`af0fed608f1efcdefafbbcbd7248f55b9cdedb80`
- 前序上游范围 `9e80f3be0e21917fd52e5df2b42cc3382a2a38d4` 已由
  [`UPSTREAM_AUDIT_9E80F3BE.md`](UPSTREAM_AUDIT_9E80F3BE.md) 完整审查。
- 说明：上游通过 `af0fed60` 合入本仓库 `0df66ce6d90a66e7d9358e47f54642062a043a79`，
  因而 Git 存在两个 merge base。`af0fed60` 只接受祖先关系；其版本、工作流、播放器布局、
  返回策略和发布元数据冲突解析不反向覆盖维护分支。真正新增行为是下列两个提交。

## issue_and_bug_mapping

| Issue / Bug | 映射 | 结论 |
| --- | --- | --- |
| [#802 竖屏比例问题](https://github.com/liuchuancong/pure_live/issues/802) | `present` | `0cc949ab` 与 `c7d99cc3` 都未修改播放器纹理、视频比例或竖屏识别；上游最新代码仍没有完整修复。维护分支继续采用统一可信显示比例的独立修复。 |
| Android 直播页返回失效历史回归 | `already-fixed` | 上游把路由局部 `PopScope` 换成 `BackButtonListener`，会退出预测返回协商；维护分支保留已回归验证的 `PopScope`。 |
| Android 自动录制存储检查 | `present` | 恢复任务可绕过 `addTask` 的权限检查；在 `startTask` 与自动恢复入口补检查是合理加固。 |

## semantic_change_ledger

| commit | upstream intent / implementation | quality_assessment | fork_feature_impact | disposition | regression_plan |
| --- | --- | --- | --- | --- | --- |
| `af0fed608f1efcdefafbbcbd7248f55b9cdedb80` | 上游合入本仓库 `0df66ce6`，并人工解析大量版本、工作流、播放器和 UI 文件。 | 祖先同步有价值，但其冲突结果包含上游版本源与旧播放器布局，不适合作为维护分支最终树。 | 直接接受树内容会覆盖 v3.0.3 发布信息、2×2 直播记录、预测返回及播放器修复。 | `adapt`：接受拓扑祖先；所有冲突以维护分支产品不变量为准。 | 核对上游祖先关系、发布元数据、普通直播页、返回与记录布局。 |
| `0cc949ab065f6e9520a1976c42dda56c6cf7c6ed` | 重排 `live_play_page.dart` 导入；以 `BackButtonListener` 替换 `PopScope`。 | 导入重排无行为；返回替换绕开 `PopScope.canPop` 与 Android predictive-back 路由协议，低于现有实现。 | 可能恢复“直播间侧边返回失效/首次返回行为不一致”。 | `drop` 行为、`accept` 无语义导入整理：保留局部 `PopScope`。 | `live_play_back_scope_test.dart` 与 Android 页面转换静态核对。 |
| `c7d99cc38ac27effb8c2af8cd0a0586256a4c67f` | 在开始录制和开机自动恢复前检查 Android 存储权限与可用路径；删除启动期同步 FFmpeg 初始化；为 Android FFmpeg 命令加入 `tls_verify=0`。 | 权限检查弥补恢复任务未经过 `addTask` 的路径；移除阻塞式初始化方向正确，但维护分支已有首帧后延迟预热；全局关闭 TLS 校验扩大网络风险且未针对具体失败证书。 | 录制权限增强可进入；启动预热保留维护分支有界实现；TLS 全局关闭不进入。 | `adapt`：接受权限检查，保留异步预热，舍弃 `tls_verify=0`。 | 录制控制器、FFmpeg 命令参数、初始化静态分析，权限拒绝和路径不可写分支代码核对。 |

## file_review

| file | disposition / conflict_resolution |
| --- | --- |
| `lib/modules/live_play/pages/live_play_page.dart` | `accept` 仅导入排序；不改变页面组合。 |
| `lib/modules/live_play/widgets/layout/live_play_back_scope.dart` | `drop` 上游 `BackButtonListener`；保留维护分支 `PopScope` 与首次退出演示层的既有契约。 |
| `lib/common/global/initialized.dart` | `adapt`：不恢复同步启动初始化；保留维护分支首帧后延迟、失败可重试的 FFmpeg 预热。 |
| `lib/recorder/ffmpeg/ffmpeg_command_builder.dart` | `drop` 全局 `tls_verify=0`；继续使用系统证书校验，避免所有 Android 录制连接静默降级。 |
| `lib/recorder/pages/recorder/recorder_controller.dart` | `accept` 新的 `startTask`/自动恢复权限与路径检查；保持非 Android 快速通过。 |

## fork_feature_impact

- 上游本次没有竖屏比例修复；普通竖屏、横屏全屏、系统画中画和应用小窗仍由维护分支统一修复。
- 保留维护分支版本、Release、构建工作流、更新源、普通直播页、2×2 记录卡片和预测返回。
- 录制权限增强不修改用户历史、收藏、播放器或弹幕数据。

## conflict_resolution

使用真实 merge 保留 `c7d99cc3` 祖先关系。`af0fed60` 带回的版本/发布/工作流及播放器冲突采用维护分支版本；
`0cc949ab` 的返回实现采用维护分支版本；`c7d99cc3` 的录制权限检查进入最终树。
最终 merge：`4db6df312930ec81a79c8c269e91283dac832c1e`。

## verification_plan

1. 合并后运行全仓完整性审计与 `git diff --check`。
2. 定向覆盖竖屏策略、移动端单一视频比例层、普通页布局、返回、直播记录布局/日期/数量和设置迁移。
3. 修改完成后只运行一次 `flutter analyze`。
4. 本轮不连接设备、不构建安装包；交付构建另行执行。

## rollback

- 上游同步：真实 merge 提交。
- 竖屏：统一移动端显示比例提交。
- 历史增强：完整日期与 `historyLimit == 0` 提交。
