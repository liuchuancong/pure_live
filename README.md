
<p align="center">
  <img src="assets/icons/icon.png" width="150" alt="Pure Live 图标"/>
</p>

<h1 align="center">纯粹直播（Pure Live）</h1>

<h4 align="center">基于 Flutter 的开源多平台直播聚合播放器</h4>

<p align="center">
  A third-party live stream aggregator built with Flutter.
</p>

<p align="center">
  <a href="https://github.com/wzgrx/pure_live/releases/latest">
    <img alt="Latest Release" src="https://img.shields.io/github/v/release/wzgrx/pure_live">
  </a>
  <a href="https://github.com/wzgrx/pure_live/actions/workflows/feature-build.yml">
    <img alt="Manual Build" src="https://github.com/wzgrx/pure_live/actions/workflows/feature-build.yml/badge.svg">
  </a>
  <a href="https://github.com/liuchuancong/pure_live">
    <img alt="Stars" src="https://img.shields.io/github/stars/liuchuancong/pure_live?color=yellow">
  </a>
  <a href="https://github.com/wzgrx/pure_live/releases">
    <img alt="Downloads" src="https://img.shields.io/github/downloads/wzgrx/pure_live/total?style=flat-square">
  </a>
  <a href="LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/liuchuancong/pure_live?color=blue">
  </a>
</p>

> 纯粹直播（Pure Live）是一款开源的第三方多平台直播聚合播放器，使用 Flutter 构建，支持 Android、Android TV、Windows、Linux、macOS 和 iOS 等平台。

> 本维护分支持续同步 [liuchuancong/pure_live](https://github.com/liuchuancong/pure_live)，并维护本机优先构建、正式签名、接口探测、Windows 数据迁移及高刷新率优化。

- **最新稳定版**：[v2.9.5](https://github.com/wzgrx/pure_live/releases/tag/v2.9.5)
- **当前版本**：`2.9.5+4084`
- **v2.9.5 上游源码基线**：`liuchuancong/pure_live@cc1f4dca`，包含多画面同看、纯 Dart 平台签名、语言切换、Windows MSIX 数据路径与房间增量合并
- **本轮构建平台**：Android arm64-v8a (Windows/Linux/macOS/iOS remain at v2.9.4)
- **质量门禁**：Flutter Analyze、自动化测试、接口探测与各平台构建记录见 `docs/STAGE_UPDATE_2_9_5.md`

![Pure Live 界面预览](assets/images/banner.png)

---

## 📺 支持平台

Pure Live 聚合多个第三方直播平台，并支持自定义直播源：

- **Bilibili**
- **虎牙直播（Huya）**
- **斗鱼直播（Douyu）**
- **快手（Kuaishou）**
- **抖音（Douyin）**
- **网易 CC 直播**
- **Twitch**
- **SOOP Live**
- **YY Live**
- **自定义 M3U / M3U8 直播源**

支持按照平台、分区等条件进行筛选，也可以隐藏不关注的平台。

### 自定义直播源

支持导入：

- M3U
- M3U8
- 本地直播源
- 网络直播源

可以按照分区、平台和频道进行管理。

---


## 文档

| 文档 | 内容 |
| --- | --- |
| [文档索引](docs/README.md) | 开发、发布、依赖和功能文档入口 |
| [构建与发布](docs/BUILD_AND_RELEASE.md) | 本机质量门禁、签名、打包和 Release 流程 |
| [Windows 数据与升级](docs/WINDOWS_DATA_AND_UPGRADE.md) | 安装目录存储、关注恢复、换盘迁移和回滚 |
| [Windows MSIX 证书说明](docs/MSIX_INSTALL.md) | 自行构建 MSIX 时的证书指纹核对与安装步骤 |
| [依赖与接口审计](docs/DEPENDENCY_AUDIT.md) | 固定工具链、升级约束和接口探测范围 |
| [平台接口与兼容性](docs/PLATFORM_COMPATIBILITY.md) | 分区、搜索、弹幕和人数指标的当前能力 |
| [高刷新率与性能验证](docs/PERFORMANCE.md) | Android 120 Hz 适配、渲染优化和真机帧统计 |
| [WebDAV 配置](docs/WEBDAV.md) | 通用配置字段、坚果云示例和故障排查 |
| [v2.9.5 Android update](docs/STAGE_UPDATE_2_9_5.md) | Douyu playback, YY integration and 36 interface probes |
| [v2.9.4 全平台稳定版](docs/STAGE_UPDATE_2_9_4.md) | 上游多画面、录制目录保护、平台签名/快手兼容与全平台交付 |
| [v2.9.5 上游 Issue 审计](docs/ISSUE_AUDIT_2026_08_24.md) | #778、#779、#780、#782、#783、#784, #785 的复现、根因与处理结果 |
| [v2.9.3 Android 专项更新](docs/STAGE_UPDATE_2_9_3.md) | 横屏画质/线路内容驱动布局与小视口边界保护 |
| [v2.9.2 Android 专项更新](docs/STAGE_UPDATE_2_9_2.md) | 横屏画质/线路、四宫格直播记录与左右分栏实时弹幕预览 |
| [v2.9.1 Android 专项更新](docs/STAGE_UPDATE_2_9_1.md) | 横屏半屏内容面板、本地弹幕个性化与渲染缓存 |
| [v2.1.5 阶段更新](docs/STAGE_UPDATE_2_1_5.md) | 本地弹幕同步、列表阅读、模板状态和 Windows 平滑滚动 |
| [v2.1.6 Android 播放修复](docs/STAGE_UPDATE_2_1_6.md) | 音频/视频切换灰白画面与后台音频生命周期 |
| [v2.2.0 阶段更新](docs/STAGE_UPDATE_2_2_0.md) | 播放恢复、音频模式、弹幕设置、Windows 多开与最终验证 |
| [v2.3.0 稳定性更新](docs/STAGE_UPDATE_2_3_0.md) | PiP 返回弹幕恢复、启动刷新、横屏输入、长时间资源边界与验收状态 |
| [v2.7.0 阶段稳定版](docs/STAGE_UPDATE_2_7_0.md) | 最新上游整合、热门页生命周期与全平台阶段发布 |
| [v2.6.0 阶段稳定版](docs/STAGE_UPDATE_2_6_0.md) | 上游同步、近期 Issue、字体/SC/播放器与全平台阶段发布 |
| [v2.5.0 阶段稳定版](docs/STAGE_UPDATE_2_5_0.md) | 首页有界并发、三档刷新率、Windows 视频纹理与依赖/上游审计 |
| [近期 Issue 审计](docs/ISSUE_AUDIT_2026_08_23.md) | #769、#770、#771、#773 与 Windows 高 DPI 问题映射 |
| [参与贡献](CONTRIBUTING.md) | 分支、提交、测试和 Pull Request 要求 |
| [安全策略](SECURITY.md) | 私密漏洞报告和签名材料管理 |
| [版本说明](RELEASE_NOTES.md) | 当前版本变更与历史记录 |

## ✨ 核心功能

### 🎬 多平台直播

- 聚合多个主流直播平台。
- 支持平台分区浏览。
- 支持跨平台搜索。
- 支持直播 / 未开播筛选。
- 支持综合、平台顺序、观众和粉丝等排序方式。
- 各个平台保持独立分页状态。
- 快手保留网页搜索入口。
- 离线频道按照平台接口实际返回结果展示。

### ▶️ 多播放器

Android / Android TV 支持多个播放器：

- IJKPlayer
- EXOPlayer
- MPV Player

当某个播放器出现黑屏、卡顿、硬解兼容性问题或者特定直播流无法播放时，可以在设置中切换播放器。

Windows、Linux、macOS 等桌面平台使用对应平台的播放器实现。

### 🖥️ 多画面同看

- 支持双画面、四画面和一大多小聚焦布局。
- 每格独立播放、暂停、音量、清晰度和线路，只有聚焦画面出声。
- 聚焦画面可接入平台弹幕；快速切换使用最新音频焦点，避免多个画面同时出声。
- 移动端最多同时保留 4 路解码，桌面端最多 9 路，并可让小画面自动使用低清晰度以控制占用。

### 💬 弹幕系统

提供完整的弹幕控制能力：

- 弹幕过滤
- 用户屏蔽
- 关键词屏蔽
- 弹幕描边
- 弹幕透明度
- 字号调整
- 速度调整
- 显示区域调整
- 最大弹幕数量
- 发送间隔控制
- 刷新 FPS
- 平台原始颜色
- 统一弹幕颜色
- 应用界面动态最高刷新率，弹幕渲染智能省电适配
- 弹幕点击与长按操作
- 字体粗细与观看模板联动
- 精确重复和相似文本两级过滤

弹幕系统采用房间会话隔离、平台消息 ID 去重以及过期队列淘汰机制，减少切换直播间后出现：

- 串房弹幕
- 重复弹幕
- 旧弹幕重新出现
- 几分钟前积压弹幕突然播放

### 🪟 小窗弹幕

进入：

**设置 → 视频设置 → 小窗弹幕**

或者在直播间进入：

**弹幕设置**

即可配置小窗弹幕。

支持：

- Android 系统画中画
- Windows 小窗
- 应用内悬浮窗
- 独立弹幕控制器
- 独立弹幕队列
- 独立弹幕样式
- 自动根据窗口尺寸缩放
- 最大弹幕数量
- FPS 调整
- 速度调整
- 显示区域调整
- 弹幕字号和透明度
- 弹幕点击和长按

小窗弹幕不会污染主播放器弹幕队列。

配置会保存到本地，下次进入直播间后继续生效。

“最佳观看”模板默认将弹幕限制在画面顶部约 20% 区域，以减少弹幕对画面的遮挡。

主播放器、小窗以及 Windows 桌面端统一使用 px/s 速度和逻辑帧时钟。

切换横竖屏或者应用从后台恢复时，不会根据后台停留时间产生大量弹幕补跳。

### 📺 高刷新率

Android 支持根据设备显示模式动态适配刷新率：

- 自动监听当前显示模式
- 请求当前分辨率支持的最高刷新率
- 适配 60 Hz / 90 Hz / 120 Hz 等高刷新率设备
- 优化封面图片解码
- 优化图片缓存
- 优化弹幕重绘
- 应用界面跟随设备最高刷新率；自动弹幕主画面 60 FPS、小窗 30 FPS，手动模式最高 240 FPS

---

## 🔍 搜索与直播互动

支持跨平台直播搜索，并提供独立的平台分页状态。平台选择栏可访问屏幕外项目，但首尾严格有界；“全部”搜索按平台完成顺序渐进显示，单个平台超时或失败不会挡住其他结果。

搜索结果支持：

- 综合排序
- 平台顺序
- 观众人数
- 粉丝数量
- 直播状态筛选
- YY 等九个平台原生/本机搜索，快手保留网页搜索
- Bilibili、斗鱼、虎牙、抖音、快手、网易 CC、Twitch、SOOP、YY 网页直播间识别

同时提供本地互动系统。

本地用户与互动数据可以保存：

- 昵称
- 头衔
- 弹幕输入
- 体验币
- 平台身份徽章
- 礼物目录
- 等级风格
- 画面礼物效果

这些数据默认保存在本机。

可以通过：

**设置 → 本地用户与互动**

统一启用或关闭相关功能。

---

## 👀 观看数据

Pure Live 会区分不同平台的观看数据口径：

- 热度
- 真实在线人数
- 累计观看人数

其中：

- 抖音
- 快手
- 网易 CC
- Twitch
- SOOP Live

可以显示平台明确返回的并发人数。

虎牙、Bilibili、斗鱼等平台则按照平台实际提供的热度数据进行展示。

可以通过：

**设置 → 通用 → 观看数据与排行口径**

选择排行方式，并管理支持人数统计的平台。

---

## 🎧 ASMR / 助眠模式

Android 支持 ASMR 助眠模式。

可以设置：

- 新房间自动进入纯音频
- 媒体保活
- 自定义自动停止时间
- 后台持续播放

房间内的耳机图标只控制当前房间的纯音频状态。

电视图标用于投屏。

前台手动进入音频模式时保留同一播放器的视频解码热状态，切回画面通常可直接复用当前纹理；应用进入后台后立即停用视频轨以降低解码和电量开销，回到前台再静默预热。深度恢复期间显示低开销音频卡片和明确进度，不再以黑屏或整页转圈阻塞操作。

当前各平台通常返回音视频复用直播流；关闭视频轨主要节省解码、GPU 与电量，并不等同于只下载音频。只有平台明确提供独立音频地址时，才可能同时实现网络流量显著下降和无等待画面恢复。

---

## ⏺️ 直播录制

支持直播流实时录制。

可以将直播保存到本地，在直播结束后进行回放。

选择自定义位置时，程序只写入该位置下带所有权标记的 `PureLiveRecords` 专用子目录；“清空录制文件目录”和自动容量限制均只处理该目录，不会遍历删除所选父目录中的其他文件。

支持配合：

- 直播录制
- 定时关闭
- 后台音频
- 系统媒体通知

进行长时间观看或助眠使用。

---

## ⏰ 定时关闭

支持设置倒计时自动停止播放或退出应用。

适用于：

- 睡眠
- ASMR
- 长时间观看
- 后台音频播放

---

## 💾 数据管理

支持：

- 本地配置导出
- 本地配置导入
- WebDAV 同步
- WebDAV 备份
- M3U / M3U8 导入
- 配置恢复

备份格式目前为 **v3**。

默认情况下：

- Cookie 不进入普通同步备份
- WebDAV 凭据不进入普通同步备份

旧版本备份文件仍然建议按照敏感文件进行保管。

---

## 🔐 Firebase 用户同步

项目支持可选的 Firebase 用户同步功能。

Firebase 不是 Pure Live 使用的必要条件。

如果需要使用 Firebase 功能，可以 Fork 项目，并在自己的 Firebase 项目中配置对应服务。

应用不会要求所有用户必须注册账号。

---

## 📥 下载

前往 [维护分支 GitHub Releases](https://github.com/wzgrx/pure_live/releases/latest) 获取最新安装包，并使用同一 Release 的 `SHA256SUMS.txt` 校验完整性。

### Android

v2.7.0 的 Android 包仅提供 `arm64-v8a`，适用于当前主流 64 位 ARM 手机和平板。更新页读取版本清单中的实际 ABI 列表，只展示本轮实际发布的下载链接。

Android 始终使用正式包名：

`com.mystyle.purelive`

不再生成并存 QA 包。

正式 Release 使用仓库专用持久签名，因此可以直接覆盖旧的正式版本。

缺少正式发布密钥的本机测试包使用调试签名。

发布脚本会阻止调试签名进入正式 Release。

### Windows

提供：

- Windows x64
- 便携 ZIP
- EXE 安装器

EXE 安装向导支持选择其他磁盘，并把设置、关注、历史、IPTV、录制和缓存集中保存到安装目录 `AppData`。便携 ZIP 不包含运行时数据。

自行构建 MSIX 时的证书配置见 [Windows MSIX 证书说明](docs/MSIX_INSTALL.md)。

### macOS

支持：

- Intel x64
- Apple Silicon arm64
- Universal

macOS Universal 包可以同时运行在 Intel 和 Apple Silicon Mac 上。

### Linux

提供 Linux x64 阶段构建。

Linux 网页搜索会交给系统浏览器，原生搜索与播放继续在应用内完成。

### iOS

提供 iOS arm64 设备构建包。

iOS 附件为设备 `.app` 编译归档。

签名和 IPA 封装需要在持有 Apple 开发者证书的环境中完成。

---

## 🧪 本地构建与验证

项目固定使用 Flutter `3.47.0` / Dart `3.13.0`、AGP `9.3.1`、Gradle `9.5.0` 与 Java 25 构建运行时，Android 应用和插件字节码目标保持 Java/Kotlin 17。资源档位、串行平台阶段和增量缓存规则见 [构建资源策略](BUILD_POLICY.md)。正式交付的完整质量门禁：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1 -Scope Full
```

安装包每次只构建本轮明确指定的一个平台与变体，例如 Android arm64 正式包：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 `
  -Target AndroidArm64 -Configuration Release -FullRegression -RequireReleaseSigning
```

当前 v2.7.0 build 4077 在原有首页有界并发、PiP 弹幕恢复和三档刷新率基础上，同步上游至 `81ec372a`，并为热门页平台切换增加关闭状态、加载代次与延迟任务隔离；关注页每个平台列表重新直接承载下拉刷新，空列表也可手势核验；取消关注弹窗绑定自身路由，避免误退直播页。Windows 视频纹理按实际可见视口适配且切换比例不重新拉流，iOS 新配置默认使用 IJK 并识别设备最高刷新率。完整门禁和全平台产物记录见 [v2.7.0 阶段稳定版](docs/STAGE_UPDATE_2_7_0.md) 与 [构建与发布](docs/BUILD_AND_RELEASE.md)。

## 🤝 参与开发

- **主开发者**：[@liuchuancong](https://github.com/liuchuancong)
- **协助开发者**：[@wzgrx](https://github.com/wzgrx/pure_live)
- **协助开发者**：[@RebornQ](https://github.com/RebornQ)

> 📌 **欢迎贡献**！
> - 如发现 License 使用不当，请提交 Issue 或 Pull Request
> - 如有新的想法或建议，欢迎贡献合作！

### 代码参考
- [dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live)
- [pure_live (Jackiu1997)](https://github.com/Jackiu1997/pure_live)

---

## 🌟 Star 趋势

如果 Pure Live 对你有帮助，欢迎给项目一个 ⭐ Star：

## Star History

<a href="https://www.star-history.com/?repos=liuchuancong%2Fpure_live&type=date&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=liuchuancong/pure_live&type=date&theme=dark&legend=bottom-right&sealed_token=7TCHJ1imubZUrHskxy4Fj--g2rclGNfNcTikzBHUf3sq9UyOFMIc2Seh8xnBxICxbcuc33QXSM34ooqO-iEpmwbF9JdlGslt_OSSHpPQqMSWBnOYCZoyWOK7vMh0OxfC9TyY_7cFplT_pTHUNrs3RYVg3GZfjqE1ezf5E9fH7_DTDNxxvD5jUlyqDNpT" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=liuchuancong/pure_live&type=date&legend=bottom-right&sealed_token=7TCHJ1imubZUrHskxy4Fj--g2rclGNfNcTikzBHUf3sq9UyOFMIc2Seh8xnBxICxbcuc33QXSM34ooqO-iEpmwbF9JdlGslt_OSSHpPQqMSWBnOYCZoyWOK7vMh0OxfC9TyY_7cFplT_pTHUNrs3RYVg3GZfjqE1ezf5E9fH7_DTDNxxvD5jUlyqDNpT" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=liuchuancong/pure_live&type=date&legend=bottom-right&sealed_token=7TCHJ1imubZUrHskxy4Fj--g2rclGNfNcTikzBHUf3sq9UyOFMIc2Seh8xnBxICxbcuc33QXSM34ooqO-iEpmwbF9JdlGslt_OSSHpPQqMSWBnOYCZoyWOK7vMh0OxfC9TyY_7cFplT_pTHUNrs3RYVg3GZfjqE1ezf5E9fH7_DTDNxxvD5jUlyqDNpT" />
 </picture>
</a>

---

## ☕ 捐助支持

如果您觉得本项目对您有帮助，欢迎扫码支持开发者一杯咖啡 ☕

<p align="center">
  <img src="https://github.com/liuchuancong/pure_live/blob/master/assets/images/wechat.png" width="350" alt="WeChat Donate">
</p>

> 您的支持是我持续维护的动力！感谢 ❤️
