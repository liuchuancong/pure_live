# 上游同步审计模板

> 复制为 `docs/UPSTREAM_AUDIT_<UPSTREAM_SHA>.md`，把占位值替换为 `tool/review_upstream_update.ps1 -ReportOnly` 输出的真实值。每个入站提交和文件都必须在文档中出现。

- fork_sha: `FORK_SHA`
- upstream_sha: `UPSTREAM_SHA`
- merge_base: `MERGE_BASE_SHA`
- incoming_range: `MERGE_BASE_SHA..UPSTREAM_SHA`
- report: `local-artifacts/upstream-reviews/REPORT.json`

## file_review

| 状态 | 文件 | 风险 | 上游目的 | 维护分支相关实现 | 处置 |
| --- | --- | --- | --- | --- | --- |
| M | `PATH` | high / medium / low |  |  | `accept/adapt/rewrite/drop/defer` |

## semantic_change_ledger

| commit | file / module | upstream intent / before → after | implementation | issue_and_bug_mapping | quality_assessment | fork_feature_impact | disposition | regression_plan |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `FULL_COMMIT_SHA` | `PATH` |  |  |  |  |  |  |  |

## issue_and_bug_mapping

| Issue / Bug | 版本与日期 | 维护分支状态 | 来源分类 | 根因 | 代码落点 | 结论 |
| --- | --- | --- | --- | --- | --- | --- |
|  |  | `present/already-fixed/upstream-only/external-drift/not-reproduced/community-platform/deferred` |  |  |  |  |

## fork_feature_impact

- 普通竖屏、横屏、全屏、画中画、小窗、音频模式：
- 播放器、清晰度、线路和弹幕会话：
- 设置默认值、迁移、备份恢复：
- 首页、关注、搜索、排行和平台接口：
- Windows 窗口、安装、数据目录和资源趋势：
- 版本、签名、更新源、工作流和 Release 资产：

## quality_assessment

- 正确性与边界：
- 异步竞态和生命周期：
- Timer / Stream / Worker / Controller / 纹理 / 缓存释放：
- 性能与网络请求：
- 数据迁移：
- 更优方案与决定：

## disposition

| 改动 | `accept/adapt/rewrite/drop/defer` | 理由 | 恢复条件（如 defer） |
| --- | --- | --- | --- |
|  |  |  |  |

## conflict_resolution

- 文本冲突：
- 无文本冲突但存在的语义冲突：
- 最终候选结果与上游/维护分支差异：
- 版本、更新源、签名和发布资产保留策略：

## regression_plan

- 受影响单元 / Widget 测试：
- Android 模式矩阵：
- Windows 模式矩阵：
- 接口与网络故障：
- 旧配置、迁移和回滚：
- 未覆盖平台与证据：

## verification_plan

- 静态审计：
- `git diff --check`：
- Focused / Full 测试：
- Analyze：
- 目标平台构建：
- 设备或桌面采样：
- 外部接口探测与时间：

## 合并结论

- 最终 merge 提交：
- 接受、适配、重写、舍弃和延期摘要：
- 已知限制：
- 回滚点：
