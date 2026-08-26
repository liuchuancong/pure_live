# Pure Live 上游同步审查策略

<!-- policy-markers: normal-live-layout-visible; manual-workflow-defaults-off; whole-diff-classification; merge-base-incoming-range; repository-audit-required; predictive-back-pop-scope; semantic-change-ledger; fork-feature-impact; disposition-required; bug-provenance-required -->

上游同步属于代码变更，不属于机械更新。任何上游提交在进入维护分支前都必须先冻结提交，以 merge base 为中心对上游、维护分支和候选合并结果做三方比较，审查**全部入站提交与全部变更文件**、记录逐文件语义和处置，再通过与风险路径对应的确定性回归。版本号、构建工作流、更新源和发布资产不得被上游值直接覆盖。Bug 来源判定同时遵循 [MAINTENANCE_POLICY.md](MAINTENANCE_POLICY.md)。

仓库提供两个入口：手动运行的 GitHub Actions `Audit Upstream Update` 以只读方式冻结 `upstream/master`，用 `-ReportOnly` 盘点每个入站提交和文件、扫描当前分支全部已跟踪文件并上传 JSON 证据；它不执行合并或发布。真正合并前仍须在本地运行不带 `-ReportOnly` 的强制门禁，并按下述规则提交审查文档和显式批准。

## 1. 冻结与审查

1. `git fetch --prune upstream` 后记录 `upstream/master` 的完整 40 位提交。
2. 在合并前运行。脚本必须以 `merge-base..upstream SHA` 计算真正的入站范围，禁止用两个分支树直接比较来混入维护仓库自己的提交：

   ```powershell
   PowerShell -ExecutionPolicy Bypass -File .\tool\review_upstream_update.ps1 `
     -BaseRef HEAD -UpstreamRef upstream/master
   ```

3. 只要存在入站提交，脚本就先退出。审查人必须建立 `docs/UPSTREAM_AUDIT_<SHA>.md`，包含完整上游 SHA、merge base，以及 `file_review`、`semantic_change_ledger`、`issue_and_bug_mapping`、`fork_feature_impact`、`quality_assessment`、`disposition`、`conflict_resolution`、`regression_plan`、`verification_plan` 标记，再用 `-AuditDocument ... -ApproveHighRisk` 复核。
4. 所有文件必须归入明确类别并进入 JSON 证据；删除源码、二进制变化、重命名、文件模式变化、依赖源、工作流、版本/更新源和平台原生改动单独列出。未分类文件不得继续合并。
5. 新增行出现凭据形态、可变 Git/Action 引用、`pull_request_target`、`permissions: write-all` 或手动构建默认开启时直接阻断，人工批准也不覆盖。
6. 使用真实 merge 保留上游祖先关系。解决冲突时优先保留维护仓库的版本、更新源、按需串行构建策略和签名/发布校验。
7. 合并后运行 `python tool/audit_repository.py` 对整个已跟踪仓库重新扫描，再执行 `git diff --check`、受影响测试；正式发布执行完整门禁。

## 2. 三方语义变更台账

在创建 merge 前分别检查：

1. `merge-base..upstream SHA`：上游本次真正带入的行为；
2. `merge-base..fork SHA`：维护分支在同一基线之后形成的定制；
3. 候选结果：两边组合后产生的默认值、调用顺序、状态机和发布行为。

原始 `git merge upstream/master` 不作为调查起点；先合并再只处理文本冲突会隐藏语义冲突。无文本冲突、编译通过或测试数量增加都不自动代表质量合格。

审查文档中的 `semantic_change_ledger` 至少为每个入站提交和文件记录以下字段：

| 字段 | 必填内容 |
| --- | --- |
| commit / file / module | 完整提交、文件、符号或功能模块。 |
| upstream intent | 上游为什么修改，行为前后有何差异。 |
| issue_and_bug_mapping | 关联 Issue/Bug、复现、来源分类和根因；无关联也要写明。 |
| implementation | 具体怎样修复，涉及的状态、接口、资源和数据契约。 |
| quality_assessment | 正确性、边界、异步竞态、释放、迁移、性能与更优方法。 |
| fork_feature_impact | 对维护分支 UI、播放器、弹幕、接口、默认值、版本与发布流程的影响。 |
| disposition | `accept`、`adapt`、`rewrite`、`drop` 或 `defer`，以及理由。 |
| regression_plan | 受影响测试、平台/模式矩阵、失败回滚点与未覆盖证据。 |

处置含义：

- `accept`：实现和语义均适合直接进入；
- `adapt`：保留上游意图，修改实现以兼容维护分支；
- `rewrite`：根因或目标成立，但现有实现质量或架构不合适；
- `drop`：与维护分支产品不变量、发布安全或目标范围冲突；
- `defer`：证据、设备、迁移或依赖条件尚未满足，记录恢复条件。

## 3. 全量审查顺序

每次按以下顺序串行完成，不以“高风险文件之外默认可信”跳过其余代码：

1. **身份与历史**：核对远端 URL、完整 SHA、merge base、祖先关系和全部入站提交。
2. **全差异盘点**：逐文件核对增删改、重命名、模式、二进制和行数；每个文件写明接受、修正或舍弃。
3. **跨模块语义**：核对路由/返回、播放器/弹幕生命周期、异步竞态、Timer/Stream 释放、缓存上限、网络超时、平台接口解析及失败回退。
4. **持久化与升级**：新增键、默认值、备份恢复、旧配置迁移、路径安全和清理边界必须成组检查。
5. **供应链与发布**：Git 依赖和 Actions 固定 40 位提交；工作流权限最小化、平台默认关闭，版本、签名、更新源和 Release 资产一致。
6. **平台原生**：Android/Windows/Linux/macOS/iOS 分别检查生命周期、返回模型、窗口、权限、ABI 与打包内容。
7. **合并后全仓复核**：运行全仓审计、确定性回归、静态分析；正式交付才追加完整测试、接口探测和目标平台构建。

## 4. 高风险路径

- `lib/modules/live_play/`、`lib/player/`：播放器状态、普通/横屏/全屏、画中画、画质/线路、弹幕和生命周期。
- `lib/common/services/settings/`：Hive 键、默认值、备份恢复、升级兼容和响应式更新。
- `lib/core/`：平台接口、签名、解析、热度/在线语义和弹幕协议。
- `.github/workflows/`、`pubspec.yaml`、`assets/version.json`、平台打包目录：构建范围、版本、签名、更新源与发布资产。
- `assets/translations/`：键名必须与调用方一致，各语言不得出现误放的其他语言文本。
- Android、Windows、Linux、macOS、iOS 原生目录：平台生命周期、权限、ABI 和打包行为。
- 其他 `lib/`、测试、文档和资源仍必须逐文件审查；风险较低不等于跳过。

## 5. 必须保持的产品不变量

- 手机普通直播页首次进入时同时可见顶部栏、视频、画质/线路入口和弹幕列表；不得用默认关闭的全屏翻转层或抽屉隐藏普通操作区。
- 桌面普通直播页保留可见且有界的侧栏；纯视频站点不预留空白面板。
- 普通、横屏、全屏、系统画中画和应用小窗只改变表达层，不得销毁仍需复用的播放/弹幕会话。
- Android 直播页使用路由局部 `PopScope`：普通页侧滑直接退出，横屏/全屏第一次返回普通页；弹窗优先关闭。禁止全局替换 `SystemChannels.navigation`，也禁止在路由确认退出前清理播放器监听。
- 画质与线路切换以实际播放器打开成功为提交点；失败保留旧源和旧选择。
- 新增设置键必须定义旧安装默认值、备份/恢复值和缺失键迁移；把既有功能改成开关时，缺失键默认保持原功能可用。
- 历史、关注和其他 Hive 集合使用新列表发布变化，避免原地修改后遗漏持久化或响应式通知；批量刷新必须使用有界并发和超时。
- 手动全平台工作流的所有平台和发布输入默认关闭；每次只构建本轮明确选择的平台并串行执行。

## 6. 上游 Issue 映射

优先审查最新受支持版本和最新日期的上游 Bug，再根据严重程度、可复现性和用户影响排序。每条审查过的 Issue 都要映射到维护分支，标为 `present`、`already-fixed`、`upstream-only`、`external-drift`、`not-reproduced`、`community-platform` 或 `deferred`，并链接到语义台账中的具体实现和回归计划。

同一根因产生多个现象时合并为一个设计与回归集合。对上游已修复的问题仍要核对修复质量、维护分支是否已有不同实现、合并后是否改变设置默认值或生命周期；对维护分支未出现的问题记录代码路径和证据，不为了追求提交数量引入无关修改。

## 7. 审查证据

每次审查文档至少记录：冻结提交、merge base、完整提交列表、逐文件清单、语义变更台账、Issue/Bug 映射、维护分支功能影响、质量评估、明确处置、冲突解决、回归与验证计划、最终合并提交和回滚点。`local-artifacts/upstream-reviews/` 中的 JSON 是机器证据，不提交；`docs/UPSTREAM_AUDIT_<SHA>.md` 是仓库内的审查结论。没有新提交时仍生成“0 入站提交”机器证据，证明检查的是正确范围。
