# Pure Live 上游同步审查策略

<!-- policy-markers: normal-live-layout-visible; manual-workflow-defaults-off; whole-diff-classification; merge-base-incoming-range; repository-audit-required; predictive-back-pop-scope -->

上游同步属于代码变更，不属于机械更新。任何上游提交在进入维护分支前都必须先冻结提交、审查**全部入站提交与全部变更文件**、记录逐文件处置，再通过与风险路径对应的确定性回归。版本号、构建工作流、更新源和发布资产不得被上游值直接覆盖。

仓库提供两个入口：手动运行的 GitHub Actions `Audit Upstream Update` 以只读方式冻结 `upstream/master`，用 `-ReportOnly` 盘点每个入站提交和文件、扫描当前分支全部已跟踪文件并上传 JSON 证据；它不执行合并或发布。真正合并前仍须在本地运行不带 `-ReportOnly` 的强制门禁，并按下述规则提交审查文档和显式批准。

## 1. 冻结与审查

1. `git fetch --prune upstream` 后记录 `upstream/master` 的完整 40 位提交。
2. 在合并前运行。脚本必须以 `merge-base..upstream SHA` 计算真正的入站范围，禁止用两个分支树直接比较来混入维护仓库自己的提交：

   ```powershell
   PowerShell -ExecutionPolicy Bypass -File .\tool\review_upstream_update.ps1 `
     -BaseRef HEAD -UpstreamRef upstream/master
   ```

3. 只要存在入站提交，脚本就先退出。审查人必须建立 `docs/UPSTREAM_AUDIT_<SHA>.md`，包含完整上游 SHA、merge base，以及 `file_review`（逐文件审查）、`conflict_resolution`（冲突处置）、`verification_plan`（验证计划）标记，再用 `-AuditDocument ... -ApproveHighRisk` 复核。
4. 所有文件必须归入明确类别并进入 JSON 证据；删除源码、二进制变化、重命名、文件模式变化、依赖源、工作流、版本/更新源和平台原生改动单独列出。未分类文件不得继续合并。
5. 新增行出现凭据形态、可变 Git/Action 引用、`pull_request_target`、`permissions: write-all` 或手动构建默认开启时直接阻断，人工批准也不覆盖。
6. 使用真实 merge 保留上游祖先关系。解决冲突时优先保留维护仓库的版本、更新源、按需串行构建策略和签名/发布校验。
7. 合并后运行 `python tool/audit_repository.py` 对整个已跟踪仓库重新扫描，再执行 `git diff --check`、受影响测试；正式发布执行完整门禁。

## 2. 全量审查顺序

每次按以下顺序串行完成，不以“高风险文件之外默认可信”跳过其余代码：

1. **身份与历史**：核对远端 URL、完整 SHA、merge base、祖先关系和全部入站提交。
2. **全差异盘点**：逐文件核对增删改、重命名、模式、二进制和行数；每个文件写明接受、修正或舍弃。
3. **跨模块语义**：核对路由/返回、播放器/弹幕生命周期、异步竞态、Timer/Stream 释放、缓存上限、网络超时、平台接口解析及失败回退。
4. **持久化与升级**：新增键、默认值、备份恢复、旧配置迁移、路径安全和清理边界必须成组检查。
5. **供应链与发布**：Git 依赖和 Actions 固定 40 位提交；工作流权限最小化、平台默认关闭，版本、签名、更新源和 Release 资产一致。
6. **平台原生**：Android/Windows/Linux/macOS/iOS 分别检查生命周期、返回模型、窗口、权限、ABI 与打包内容。
7. **合并后全仓复核**：运行全仓审计、确定性回归、静态分析；正式交付才追加完整测试、接口探测和目标平台构建。

## 3. 高风险路径

- `lib/modules/live_play/`、`lib/player/`：播放器状态、普通/横屏/全屏、画中画、画质/线路、弹幕和生命周期。
- `lib/common/services/settings/`：Hive 键、默认值、备份恢复、升级兼容和响应式更新。
- `lib/core/`：平台接口、签名、解析、热度/在线语义和弹幕协议。
- `.github/workflows/`、`pubspec.yaml`、`assets/version.json`、平台打包目录：构建范围、版本、签名、更新源与发布资产。
- `assets/translations/`：键名必须与调用方一致，各语言不得出现误放的其他语言文本。
- Android、Windows、Linux、macOS、iOS 原生目录：平台生命周期、权限、ABI 和打包行为。
- 其他 `lib/`、测试、文档和资源仍必须逐文件审查；风险较低不等于跳过。

## 4. 必须保持的产品不变量

- 手机普通直播页首次进入时同时可见顶部栏、视频、画质/线路入口和弹幕列表；不得用默认关闭的全屏翻转层或抽屉隐藏普通操作区。
- 桌面普通直播页保留可见且有界的侧栏；纯视频站点不预留空白面板。
- 普通、横屏、全屏、系统画中画和应用小窗只改变表达层，不得销毁仍需复用的播放/弹幕会话。
- Android 直播页使用路由局部 `PopScope`：普通页侧滑直接退出，横屏/全屏第一次返回普通页；弹窗优先关闭。禁止全局替换 `SystemChannels.navigation`，也禁止在路由确认退出前清理播放器监听。
- 画质与线路切换以实际播放器打开成功为提交点；失败保留旧源和旧选择。
- 新增设置键必须定义旧安装默认值、备份/恢复值和缺失键迁移；把既有功能改成开关时，缺失键默认保持原功能可用。
- 历史、关注和其他 Hive 集合使用新列表发布变化，避免原地修改后遗漏持久化或响应式通知；批量刷新必须使用有界并发和超时。
- 手动全平台工作流的所有平台和发布输入默认关闭；每次只构建本轮明确选择的平台并串行执行。

## 5. 审查证据

每次审查文档至少记录：冻结提交、merge base、完整提交列表、逐文件清单、风险分类、冲突处置、拒绝/修正的上游改动、验证计划和最终合并提交。`local-artifacts/upstream-reviews/` 中的 JSON 是机器证据，不提交；`docs/UPSTREAM_AUDIT_<SHA>.md` 是仓库内的审查结论。没有新提交时仍生成“0 入站提交”机器证据，证明检查的是正确范围。
