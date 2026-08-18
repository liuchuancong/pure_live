# Pure Live 文档

本文档目录保存开发、验证和用户功能说明。仓库根目录只保留 GitHub 会自动识别的入口文档与项目配置。

## 开发与发布

- [本地构建、测试与发布](BUILD_AND_RELEASE.md)：固定工具链、一键质量门禁、Android 签名、Windows 打包与本地发布。
- [Windows 数据目录与升级](WINDOWS_DATA_AND_UPGRADE.md)：安装目录数据、旧版关注合并、换盘迁移与回滚。
- [依赖与接口审计](DEPENDENCY_AUDIT.md)：依赖锁定策略、暂缓升级原因和直播平台接口探测边界。
- [平台接口与兼容性](PLATFORM_COMPATIBILITY.md)：各平台分区、搜索、弹幕和人数指标的当前能力。
- [Android/Windows 性能验证](PERFORMANCE.md)：120 Hz 请求、渲染/滑动优化和实机采样方法。
- [上游问题审计（2026-08-16）](ISSUE_AUDIT_2026_08_16.md)：本轮问题对应根因、代码落点和验证状态。
- [v2.1.0 阶段更新](STAGE_UPDATE_2_1_0.md)：上游同步、Twitch、SOOP Live、依赖迁移、全平台构建矩阵与验收范围。
- [v2.1.4 阶段更新](STAGE_UPDATE_2_1_4.md)：Bilibili/SOOP 接口、Windows 200 Hz 优化、数据升级和全平台产物。
- [参与贡献](../CONTRIBUTING.md)：分支、提交、测试和 Pull Request 约定。
- [版本说明](../RELEASE_NOTES.md)：当前开发版本变更。
- [安全策略](../SECURITY.md)：漏洞报告、凭据和签名材料管理。

## 功能说明

- [WebDAV 配置](WEBDAV.md)：服务地址、账号、应用密码、目录和故障排查。
- [README](../README.md)：功能概览、小窗弹幕、下载和常见问题。

## 维护原则

1. 命令以仓库根目录为工作目录，优先调用 `tool/` 中的包装脚本。
2. 工具链版本以 `.fvmrc`、Gradle 配置和 `pubspec.lock` 为准。
3. 外部接口和依赖状态具有时效性，发布前重新运行质量门禁。
4. 构建产物进入 `local-artifacts/`，不提交到 Git。
5. 文档中的密钥、账号、Cookie 和本地绝对路径只使用占位符。
