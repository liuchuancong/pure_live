# Pure Live 文档

本文档目录保存开发、验证和用户功能说明。仓库根目录只保留 GitHub 会自动识别的入口文档与项目配置。

## 开发与发布

- [维护范围与问题处置策略](../MAINTENANCE_POLICY.md)：Android/Windows 维护边界、Issue 分流、Bug 来源判定、上游 Issue 优先级、验证和回滚标准。
- [上游同步审查策略](../UPSTREAM_REVIEW_POLICY.md)：三方差异、全入站文件审查、语义变更台账、冲突处置与合并门禁。
- [Bug 根因分析模板](BUG_TRIAGE_TEMPLATE.md)：复现基线、来源分类、首次错误状态、影响矩阵与分层证据模板。
- [上游同步审计模板](UPSTREAM_AUDIT_TEMPLATE.md)：审查脚本要求的逐文件台账、Issue 映射、质量评估、处置和回归字段。
- [上游同步审计（9e80f3be）](UPSTREAM_AUDIT_9E80F3BE.md)：竖屏比例、直播记录、录播与播放器布局入站提交的逐项处置。
- [上游同步审计（c7d99cc3）](UPSTREAM_AUDIT_C7D99CC3.md)：上游吸收维护分支后的返回、录制权限、初始化与 FFmpeg 参数冲突处置。
- [竖屏比例与直播记录根因审计](BUG_AUDIT_2026_08_26_PORTRAIT_HISTORY.md)：移动端单一可信比例、完整观看日期与不限数量回归证据。
- [本地构建、测试与发布](BUILD_AND_RELEASE.md)：固定工具链、一键质量门禁、Android 签名、Windows 打包与本地发布。
- [Windows 数据目录与升级](WINDOWS_DATA_AND_UPGRADE.md)：安装目录数据、旧版关注合并、换盘迁移与回滚。
- [依赖与接口审计](DEPENDENCY_AUDIT.md)：依赖锁定策略、暂缓升级原因和直播平台接口探测边界。
- [平台接口与兼容性](PLATFORM_COMPATIBILITY.md)：各平台分区、搜索、弹幕和人数指标的当前能力。
- [Android/Windows 性能验证](PERFORMANCE.md)：120 Hz 请求、渲染/滑动优化和实机采样方法。
- [关注页刷新与状态一致性](FAVORITE_REFRESH_DESIGN.md)：下拉手势、启动核验、并发事务和失败语义。
- [上游问题审计（2026-08-24）](ISSUE_AUDIT_2026_08_24.md)：#778、#779、#780、#782、#783、#784, #785 的根因、代码落点和验证状态。
- [上游问题审计（2026-08-25）](ISSUE_AUDIT_2026_08_25.md)：#791 录制根因，以及 #789、#786、#783、#767 的当前处理状态。
- [v3.0.0 全平台稳定版](STAGE_UPDATE_3_0_0.md)：最新上游状态绑定、录制恢复、依赖锁与全平台发布门禁。
- [v3.0.0 build 4088 全仓审查](REPOSITORY_AUDIT_3_0_0_BUILD_4088.md)：Android 返回根因、全上游/全仓流程、供应链、Windows 刷新率与 MSIX 修正。
- [v3.0.1 Android 竖屏直播适配](STAGE_UPDATE_3_0_1.md)：源方向稳定识别、普通页自适应、全屏策略、画中画比例与房间覆盖。
- [v3.0.2 Android 播放比例修复](STAGE_UPDATE_3_0_2.md)：普通横屏 16:9 边界、竖屏适配隔离、原生单层缩放与弹幕主题布局。
- [v3.0.3 Android 竖屏 Surface 修复](STAGE_UPDATE_3_0_3.md)：原生/应用层几何统一、切换时序和横屏直播记录自适应双列。
- [v3.0.4 Android 可信画面比例修复](STAGE_UPDATE_3_0_4.md)：普通页、全屏、系统画中画和应用内小窗共享单一可信比例，并增强历史记录日期与容量。
- [v3.0.5 Android 有效画面识别](STAGE_UPDATE_3_0_5.md)：双证据几何引擎、黑边内嵌竖屏裁边、普通页/横屏/小窗三种呈现。
- [v3.0.6 Android 竖屏几何仲裁修复](STAGE_UPDATE_3_0_6.md)：抖音平台分辨率证据、裁边代际隔离、延迟有界采样与渲染比例一致性门禁。
- [v3.0.7 Android 竖屏真实画布修复](STAGE_UPDATE_3_0_7.md)：截图/解码坐标隔离、原生纹理防拉伸与显式横屏全屏入口。
- [v3.0.8 Android 竖屏与小窗比例修复](STAGE_UPDATE_3_0_8.md)：抖音选中流几何、可逆居中裁边、应用小窗动态尺寸与 PiP 可视区域。
- [v3.0.9 Android 竖屏原生缩放修复](STAGE_UPDATE_3_0_9.md)：抖音官方几何模型、移动端原生单层缩放、实测裁边与四种呈现统一。
- [v3.0.10 Android 横屏全屏竖屏展示修复](STAGE_UPDATE_3_0_10.md)：全屏 contain、透明播放器表面、模糊背景回退与跨平台识别边界。
- [Video Geometry Engine](VIDEO_GEOMETRY_ENGINE_2026_08_26.md)：编码画布、有效节目区域与呈现窗口的统一识别和普通直播保护设计。
- [v2.9.7 Android update](STAGE_UPDATE_2_9_7.md): cross-platform audience semantics, stable popular ranking and SOOP PC/mobile totals.
- [v2.9.6 Android update](STAGE_UPDATE_2_9_6.md): upstream synchronization, Douyin/Bilibili repairs and 40 interface probes.
- [v2.9.5 Android update](STAGE_UPDATE_2_9_5.md): Douyu playback, YY integration and 36 interface probes.
- [v2.9.4 全平台稳定版](STAGE_UPDATE_2_9_4.md)：多画面、录制数据保护、纯 Dart 平台签名/快手兼容与全平台交付。
- [v2.1.0 阶段更新](STAGE_UPDATE_2_1_0.md)：上游同步、Twitch、SOOP Live、依赖迁移、全平台构建矩阵与验收范围。
- [v2.1.5 阶段更新](STAGE_UPDATE_2_1_5.md)：本地弹幕同步、列表阅读、模板状态和 Windows 平滑滚动。
- [v2.1.6 Android 播放修复](STAGE_UPDATE_2_1_6.md)：音频/视频切换灰白画面与后台音频生命周期。
- [v2.2.0 阶段更新](STAGE_UPDATE_2_2_0.md)：播放器快速恢复、弹幕合并、Windows 多开与最终验证。
- [v2.3.0 稳定性更新](STAGE_UPDATE_2_3_0.md)：PiP 返回弹幕恢复、启动逐批刷新、横屏输入与长时间资源边界。
- [v2.7.0 阶段稳定版](STAGE_UPDATE_2_7_0.md)：最新上游整合、热门页生命周期和全平台阶段发布。
- [v2.6.0 阶段稳定版](STAGE_UPDATE_2_6_0.md)：近期 Issue、字体/SC/播放器稳定性和全平台阶段发布。
- [v2.5.0 阶段稳定版](STAGE_UPDATE_2_5_0.md)：首页有界并发、三档刷新率、Windows 视频纹理与依赖/上游审计。
- [参与贡献](../CONTRIBUTING.md)：分支、提交、测试和 Pull Request 约定。
- [版本说明](../RELEASE_NOTES.md)：当前开发版本变更。
- [安全策略](../SECURITY.md)：漏洞报告、凭据和签名材料管理。

## 功能说明

- [WebDAV 配置](WEBDAV.md)：服务地址、账号、应用密码、目录和故障排查。
- [README](../README.md)：功能概览、小窗弹幕、下载和常见问题。

## 维护原则

1. Android/Android TV 与 Windows 是主要维护目标；其他平台按社区证据记录。
2. Bug 先判定上游、维护分支、整合冲突、外部漂移或本地数据来源，再设计修复。
3. 上游同步先完成三方语义审查和处置台账，再创建 merge。
4. 命令以仓库根目录为工作目录，优先调用 `tool/` 中的包装脚本。
5. 工具链版本以 `.fvmrc`、Gradle 配置和 `pubspec.lock` 为准。
6. 外部接口和依赖状态具有时效性，发布前重新运行质量门禁。
7. 构建产物进入 `local-artifacts/`，不提交到 Git。
8. 文档中的密钥、账号、Cookie 和本地绝对路径只使用占位符。
