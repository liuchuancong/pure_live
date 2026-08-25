# Pure Live 上游同步审查策略

<!-- policy-markers: normal-live-layout-visible; manual-workflow-defaults-off -->

上游同步属于代码变更，不属于机械更新。任何上游提交在进入维护分支前都必须先冻结提交、审查差异、记录处置，再通过与风险路径对应的确定性回归。版本号、构建工作流、更新源和发布资产不得被上游值直接覆盖。

## 1. 冻结与审查

1. `git fetch --prune upstream` 后记录 `upstream/master` 的完整 40 位提交。
2. 在合并前运行：

   ```powershell
   PowerShell -ExecutionPolicy Bypass -File .\tool\review_upstream_update.ps1 `
     -BaseRef HEAD -UpstreamRef upstream/master
   ```

3. 脚本检测到高风险路径时会退出失败。逐项人工审查并写入 `docs/UPSTREAM_AUDIT_<SHA>.md` 后，才使用 `-ApproveHighRisk` 生成审查证据。
4. 使用真实 merge 保留上游祖先关系。解决冲突时优先保留维护仓库的版本、更新源、按需串行构建策略和签名/发布校验。
5. 合并后的源码必须再次检查 `git diff --check`，并执行受影响测试；正式发布再执行一次完整门禁。

## 2. 高风险路径

- `lib/modules/live_play/`、`lib/player/`：播放器状态、普通/横屏/全屏、画中画、画质/线路、弹幕和生命周期。
- `lib/common/services/settings/`：Hive 键、默认值、备份恢复、升级兼容和响应式更新。
- `lib/core/`：平台接口、签名、解析、热度/在线语义和弹幕协议。
- `.github/workflows/`、`pubspec.yaml`、`assets/version.json`、平台打包目录：构建范围、版本、签名、更新源与发布资产。
- `assets/translations/`：键名必须与调用方一致，各语言不得出现误放的其他语言文本。
- Android、Windows、Linux、macOS、iOS 原生目录：平台生命周期、权限、ABI 和打包行为。

## 3. 必须保持的产品不变量

- 手机普通直播页首次进入时同时可见顶部栏、视频、画质/线路入口和弹幕列表；不得用默认关闭的全屏翻转层或抽屉隐藏普通操作区。
- 桌面普通直播页保留可见且有界的侧栏；纯视频站点不预留空白面板。
- 普通、横屏、全屏、系统画中画和应用小窗只改变表达层，不得销毁仍需复用的播放/弹幕会话。
- 画质与线路切换以实际播放器打开成功为提交点；失败保留旧源和旧选择。
- 新增设置键必须定义旧安装默认值、备份/恢复值和缺失键迁移；把既有功能改成开关时，缺失键默认保持原功能可用。
- 历史、关注和其他 Hive 集合使用新列表发布变化，避免原地修改后遗漏持久化或响应式通知；批量刷新必须使用有界并发和超时。
- 手动全平台工作流的所有平台和发布输入默认关闭；每次只构建本轮明确选择的平台并串行执行。

## 4. 审查证据

每次审查文档至少记录：冻结提交、提交列表、文件列表、高风险分类、冲突处置、拒绝/修正的上游改动、必跑测试和最终合并提交。`local-artifacts/upstream-reviews/` 中的 JSON 是机器证据，不提交；`docs/UPSTREAM_AUDIT_<SHA>.md` 是仓库内的审查结论。
