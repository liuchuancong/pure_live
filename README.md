<h1 align="center">
  <br>
  <img src="assets/icons/icon.png" width="150" alt="Pure Live 图标"/>
  <br>
  纯粹直播（Pure Live）
  <br>
</h1>

<h4 align="center">基于 Flutter 的开源多平台直播聚合播放器</h4>

<p align="center">
  <a href="https://github.com/wzgrx/pure_live/releases/latest"><img alt="Latest Release" src="https://img.shields.io/github/v/release/wzgrx/pure_live"></a>
  <a href="https://github.com/wzgrx/pure_live/actions/workflows/feature-build.yml"><img alt="Manual Build" src="https://github.com/wzgrx/pure_live/actions/workflows/feature-build.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/wzgrx/pure_live?color=blue"></a>
  <a href="https://github.com/wzgrx/pure_live/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/wzgrx/pure_live/total?style=flat-square"></a>
</p>

> 本仓库基于 [liuchuancong/pure_live](https://github.com/liuchuancong/pure_live) 持续维护，新增可配置的小窗弹幕，并完善本机构建、依赖锁定、接口探测和发布流程。

- **最新稳定版**：[v2.0.34](https://github.com/wzgrx/pure_live/releases/tag/v2.0.34)
- **当前版本**：`2.0.34+45`（`master`）
- **上游同步基线**：`liuchuancong/pure_live@2cd1877`（2026-08-16）
- **主要发布平台**：Android、Windows

![Pure Live 界面预览](assets/images/banner.png)

## 功能概览

- **直播平台**：Bilibili、虎牙、斗鱼、快手、抖音、网易 CC。
- **自定义直播源**：导入本地或网络 M3U/M3U8，按分区和平台筛选。
- **多播放器**：Android/TV 可切换 IJKPlayer、EXOPlayer 和 MPV Player。
- **弹幕增强**：顶部约 20% 的最佳观看模板、舒适/高密度模板、过滤、用户/关键词屏蔽、描边、透明度、字号、速度、显示区域，以及动态跟随屏幕最高刷新率；直播间内调整即时作用于画面。房间会话隔离、平台消息 ID 去重和过期队列淘汰共同避免串房、重放与几分钟前的积压弹幕。
- **小窗弹幕**：覆盖 Android 系统画中画、Windows 小窗和应用内悬浮窗。
- **数据管理**：本地导入导出、WebDAV 同步，以及可选的 Firebase 用户同步。
- **播放工具**：直播录制、定时关闭、后台音频和系统媒体通知。
- **搜索与互动**：跨平台原生直播搜索、滚动分页加载，以及保存在本机的昵称、头衔、弹幕输入、体验币、六平台身份徽章、礼物目录、等级风格和画面礼物效果；“设置 → 本地用户与互动”提供独立总开关。
- **观看口径**：热度、真实在线人数、累计观看分别存储和标注；“设置 → 通用 → 观看数据与排行口径”可切换排行方式并管理支持真实在线的平台。
- **ASMR 助眠**：Android 可让新房间自动进入纯音频、启用媒体保活并按任意自定义时长停止；房间内耳机只控制本次纯音频，电视图标专用于投屏。
- **高刷新率适配**：Android 动态监听显示模式并自动请求当前分辨率支持的最高刷新率，同时优化封面解码、缓存和弹幕重绘。

## 小窗弹幕

进入“设置 → 视频设置 → 小窗弹幕”，或在直播间切换到“弹幕设置”，即可配置：

- 保留平台原始颜色，或设置统一颜色、字号和透明度；
- 调整速度、显示区域、最大数量、发送间隔和刷新 FPS；
- 根据小窗尺寸自动缩放；
- 使用独立弹幕控制器，切换窗口模式时不污染主播放器队列；
- 配置保存在本地，再次进入直播间时继续生效；“最佳观看”默认只占画面顶部约 20%。
- 弹幕 FPS 可动态跟随设备最高刷新率；画面弹幕支持可选点击和长按操作。
- 主画面、小窗和 Windows 桌面端统一使用 px/s 速度与逻辑帧时钟，切换横竖屏或应用恢复后不补跳后台停留时间。

独立设置页提供实时样式预览和恢复默认值；即使主播放器的全局弹幕已关闭，小窗弹幕设置入口仍保持可见。

## 下载

前往 [GitHub Releases](https://github.com/wzgrx/pure_live/releases/latest) 获取安装包：

- Android：当前优先发布 `arm64-v8a` APK；
- Windows：按 Release 附件说明选择安装包或便携 ZIP；
- 下载后使用同一 Release 中的 `SHA256SUMS.txt` 校验完整性。

Android 始终使用正式包名 `com.mystyle.purelive`，不再生成并存 QA 包。正式 Release 使用仓库专用持久签名，可直接覆盖旧正式版；缺少发布密钥的本机测试包使用调试签名，发布脚本会阻止其进入正式 Release。

## 本地开发

项目固定使用 Flutter `3.47.0` / Dart `3.13.0`、AGP `9.3.1`、Gradle `9.5.0` 和 Java 25 构建运行时；Android 应用字节码目标保持 Java/Kotlin 17。Android 已迁移到 AGP 9 Built-in Kotlin，不再重复加载独立 Kotlin Gradle Plugin。Windows 11 上运行完整质量门禁：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1
```

生成 Android `arm64-v8a` APK、Windows x64 便携包、可选 EXE 安装器和 SHA-256 文件：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1
```

本地脚本优先完成依赖解析、格式检查、静态分析、测试和外部接口探测；GitHub Actions 仅保留手动兜底入口，以减少配额消耗。完整说明见 [本地构建与发布](docs/BUILD_AND_RELEASE.md)。

缩略图除支持手动刷新外，也可在“设置 → 刷新设置”启用定时自动刷新并选择 5 分钟到 6 小时的周期。

## 文档

| 文档 | 内容 |
| --- | --- |
| [文档索引](docs/README.md) | 开发、发布、依赖和功能文档入口 |
| [构建与发布](docs/BUILD_AND_RELEASE.md) | 本机质量门禁、签名、打包和 Release 流程 |
| [依赖与接口审计](docs/DEPENDENCY_AUDIT.md) | 固定工具链、升级约束和接口探测范围 |
| [平台接口与兼容性](docs/PLATFORM_COMPATIBILITY.md) | 分区、搜索、弹幕和人数指标的当前能力 |
| [高刷新率与性能验证](docs/PERFORMANCE.md) | Android 120 Hz 适配、渲染优化和真机帧统计 |
| [WebDAV 配置](docs/WEBDAV.md) | 通用配置字段、坚果云示例和故障排查 |
| [参与贡献](CONTRIBUTING.md) | 分支、提交、测试和 Pull Request 要求 |
| [安全策略](SECURITY.md) | 私密漏洞报告和签名材料管理 |
| [版本说明](RELEASE_NOTES.md) | 当前版本变更与历史记录 |

## 数据与隐私

- 项目未集成广告或行为追踪 SDK；直播请求主要发往对应平台。
- 登录、版本更新和用户主动启用的同步功能会访问 Firebase、GitHub 或用户配置的 WebDAV 服务。
- 平台 Cookie 仅用于对应平台身份认证。备份格式 v3 默认排除 Cookie 与 WebDAV 凭据；旧备份仍应按敏感文件保管。
- Android 已关闭系统级应用数据备份；后台音频播放时会显示媒体播放前台服务通知，停止播放后释放相关资源。

## 常见问题

| 现象 | 处理方式 |
| --- | --- |
| Windows 恢复手机备份后只有弹幕、没有画面 | 进入“设置 → 播放器”，重新选择或重置播放器 |
| 黑屏、卡顿或部分清晰度播放失败 | 切换 IJK / MPV / EXO，检查账号清晰度权限和硬件解码支持 |
| Bilibili 高清直播不可选 | 在应用内完成对应平台认证，Cookie 默认从同步备份中剔除 |
| 小窗中弹幕过密 | 降低显示区域、最大数量或字号，增大发送间隔 |
| Bilibili 视频正常但弹幕提示连接更新 | 房间播放会优先开始，弹幕凭据与节点在后台刷新；访客弹幕接收不依赖账号登录 |

不同厂商系统对后台播放、画中画和硬件解码的实现存在差异，提交问题时请附应用版本、系统版本、设备型号、播放器类型和可复现直播间。

## 参与开发

- 上游项目：[@liuchuancong/pure_live](https://github.com/liuchuancong/pure_live)
- 维护仓库：[@wzgrx/pure_live](https://github.com/wzgrx/pure_live)
- 提交改动前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)，UI 变更请附截图或录屏。

代码参考：

- [dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live)
- [pure_live (Jackiu1997)](https://github.com/Jackiu1997/pure_live)

## 许可与内容说明

项目代码采用 [GNU Affero General Public License v3.0](LICENSE)。应用聚合第三方直播平台与用户配置的直播源；使用者应遵守对应平台条款和所在地规则。视频、音频、图像及直播内容的权利归原权利人所有。权利相关问题可通过 [GitHub Issues](https://github.com/wzgrx/pure_live/issues) 联系维护者。

## Star 趋势

[![Stargazers over time](https://starchart.cc/wzgrx/pure_live.svg)](https://starchart.cc/wzgrx/pure_live)
