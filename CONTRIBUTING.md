# 参与贡献

<!-- contribution-policy-markers: maintenance-bug-only; bug-triage; upstream-review; feature-routing -->

感谢为 Pure Live 提交维护型修复、测试或文档。仓库以 `master` 为集成分支，重点维护 Android / Android TV 与 Windows，GitHub Actions 仅作为手动兜底，主要验证在本机完成。完整边界见 [MAINTENANCE_POLICY.md](MAINTENANCE_POLICY.md)。

本仓库 Issue 聚焦可复现 Bug。新增功能、产品方向和全新平台适配请先提交到[原项目 Issue](https://github.com/liuchuancong/pure_live/issues/new/choose)；维护分支只在上游已采纳或维护者明确安排整合时跟进。

## 开始之前

1. Fork 仓库并从最新 `master` 创建短期分支。
2. 使用 `.fvmrc` 指定的 Flutter `3.47.0`，保留 `pubspec.lock`。
3. 不提交账号、Cookie、签名文件、应用密码、私有直播源和包含个人数据的备份。
4. 依赖或工具链升级需说明兼容性理由，并同步更新审计文档。
5. Bug 修复先确定来源、根因与影响面；上游同步先完成全入站差异审计，不先合并再补审查。

分支名称示例：

```text
fix/android-pip-danmaku
fix/windows-package
docs/build-guide
```

## Issue 与 Bug 分诊

提交 Bug 时请提供当前版本或完整 SHA、平台/系统/播放器、直播平台、最短复现步骤、最后正常版本、实际与预期结果，以及已清理敏感信息的日志或录屏。Linux、macOS 和 iOS 属于社区验证范围，相应报告最好附可重复测试或贡献者设备证据。

开始修复前，先以 merge base、冻结上游和当前维护分支做三方比较，并把来源标为：

- `upstream-existing`：上游已存在；
- `fork-regression`：维护分支单独引入；
- `integration-conflict`：上游与维护分支组合后发生冲突；
- `external-drift`：平台接口、协议、系统或依赖变化；
- `environment-or-data`：旧配置、缓存、迁移或设备环境触发；
- `not-reproduced`：当前证据尚未形成稳定复现。

修复说明应定位第一个错误状态、调用链或事件时序，解释方案为何覆盖复现与相邻状态，并记录回归、迁移、回滚和剩余证据。详细模板见 [维护范围与问题处置策略](MAINTENANCE_POLICY.md)。

## 上游同步

同步 [liuchuancong/pure_live](https://github.com/liuchuancong/pure_live) 前必须执行 [UPSTREAM_REVIEW_POLICY.md](UPSTREAM_REVIEW_POLICY.md) 和 `tool/review_upstream_update.ps1`。审计文档需包含完整入站提交与文件，并为每项变更记录目的、前后行为、关联 Issue/Bug、修复方法、质量、维护分支功能影响、`accept/adapt/rewrite/drop/defer` 处置、验证和回滚。

禁止把“无文本冲突”当成兼容结论。播放器、弹幕、导航、设置默认值、数据迁移、平台接口、工作流、版本、签名和更新源都要核对语义冲突。

## 开发与验证

日常修改先运行受影响测试，并在修改完成后执行一次 Analyze：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1 `
  -Scope Focused -TestPath test/example_test.dart -Analyze
```

正式交付改用 `-Scope Full`，门禁包括锁定依赖解析、改动文件格式检查、一次静态分析、完整测试和公开接口探测。只修改文档时检查链接、路径和 Markdown 显示。完整资源与串行构建规则见 [BUILD_POLICY.md](BUILD_POLICY.md)。

涉及安装包时显式选择一个平台和一个变体；不同平台另起串行阶段。例如：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 `
  -Target WindowsX64 -Configuration Debug -SkipQuality
```

Android UI、播放器、画中画或弹幕改动默认采用无设备流程：先定位状态机与事件顺序，补充可重复的单元/Widget 回归测试，再执行静态分析、本地测试和目标产物构建。连接手机、启动 ADB、安装 APK 或自动操作设备仅在当前任务明确提出设备验收时执行；以前连接过设备不代表后续任务持续开放设备操作。

执行任何设备命令前必须重新核对用户最新指令。当前任务要求不操作手机时，连 `adb devices`、`dumpsys`、日志、截图和包信息等只读查询也不执行，直接使用源码状态机分析与确定性测试完成修复。

验证结论按层次分别记录：代码审查、自动化测试、本地构建、可选设备采样。设备采样用于补充发布证据，不作为开始分析或提交代码修复的前置条件；尚未采样的设备场景单独标记，不影响已经通过自动化门禁的代码结论。Windows 小窗、安装器或运行时资源改动继续通过本机便携包和安装包启动验证。具体流程见 [构建与发布](docs/BUILD_AND_RELEASE.md)。

## 提交规范

使用简短、可检索的提交标题：

```text
feat(pip): add compact danmaku controls
fix(windows): exclude runtime data from packages
docs: reorganize build and release guides
```

一次提交聚焦一个目的。生成文件、依赖锁文件和文档应与触发它们的源码改动放在同一组提交中。

## Pull Request

Pull Request 需包含：

- 改动原因和实现摘要；
- 对应 Issue 或背景链接；
- Bug 来源分类、根因和首次错误状态；
- 与冻结上游、merge base 和当前维护分支的差异；
- 选择直接复用、适配、兼容层或重写的理由；
- 已执行的命令及结果；
- 实测平台、设备和播放器；
- UI 变化的截图或录屏；
- 普通/横屏/全屏/小窗/音频/弹幕及 Windows 窗口等相邻状态影响；
- 依赖、接口、数据迁移、资源释放和回滚影响；
- 未覆盖平台、剩余风险和证据层级。

合并前请把分支更新到最新 `master`，解决冲突并重新执行受影响的验证项。维护分支在合并后应与 `master` 对齐，避免长期漂移。
