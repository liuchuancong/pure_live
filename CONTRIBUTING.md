# 参与贡献

感谢为 Pure Live 提交修复、功能、测试或文档。仓库以 `master` 为集成分支，GitHub Actions 仅作为手动兜底，主要验证在本机完成。

## 开始之前

1. Fork 仓库并从最新 `master` 创建短期分支。
2. 使用 `.fvmrc` 指定的 Flutter `3.44.9`，保留 `pubspec.lock`。
3. 不提交账号、Cookie、签名文件、应用密码、私有直播源和包含个人数据的备份。
4. 依赖或工具链升级需说明兼容性理由，并同步更新审计文档。

分支名称示例：

```text
feature/pip-danmaku
fix/windows-package
docs/build-guide
```

## 开发与验证

Windows 11 推荐运行完整门禁：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1
```

门禁包括锁定依赖解析、改动文件格式检查、静态分析、完整测试和公开接口探测。只修改文档时仍应检查链接、路径和 Markdown 显示；修改 Flutter 代码时应至少通过 `analyze` 和 `test`。

涉及安装包时继续运行：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1
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
- 已执行的命令及结果；
- 实测平台、设备和播放器；
- UI 变化的截图或录屏；
- 依赖、接口、数据迁移和回滚影响。

合并前请把分支更新到最新 `master`，解决冲突并重新执行受影响的验证项。维护分支在合并后应与 `master` 对齐，避免长期漂移。
