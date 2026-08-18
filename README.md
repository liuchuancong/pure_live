
<p align="center">
  <img src="assets/icons/icon.png" width="150" alt="Pure Live 图标"/>
</p>

<h1 align="center">纯粹直播（Pure Live）</h1>

<h4 align="center">基于 Flutter 的开源多平台直播聚合播放器</h4>

<p align="center">
  A third-party live stream aggregator built with Flutter.
</p>

<p align="center">
  <a href="https://github.com/liuchuancong/pure_live/releases/latest">
    <img alt="Latest Release" src="https://img.shields.io/github/v/release/liuchuancong/pure_live">
  </a>
  <a href="https://github.com/liuchuancong/pure_live/actions/workflows/feature-build.yml">
    <img alt="Manual Build" src="https://github.com/liuchuancong/pure_live/actions/workflows/feature-build.yml/badge.svg">
  </a>
  <a href="https://github.com/liuchuancong/pure_live">
    <img alt="Stars" src="https://img.shields.io/github/stars/liuchuancong/pure_live?color=yellow">
  </a>
  <a href="https://github.com/liuchuancong/pure_live/releases">
    <img alt="Downloads" src="https://img.shields.io/github/downloads/liuchuancong/pure_live/total?style=flat-square">
  </a>
  <a href="LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/liuchuancong/pure_live?color=blue">
  </a>
</p>

> 纯粹直播（Pure Live）是一款开源的第三方多平台直播聚合播放器，使用 Flutter 构建，支持 Android、Android TV、Windows、Linux、macOS 和 iOS 等平台。

- **最新稳定版**：`v2.1.0`
- **当前开发版本**：`2.1.1+49`
- **构建平台**：Android arm64、Windows x64、Linux x64、macOS Universal、iOS arm64 设备包

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
| [依赖与接口审计](docs/DEPENDENCY_AUDIT.md) | 固定工具链、升级约束和接口探测范围 |
| [平台接口与兼容性](docs/PLATFORM_COMPATIBILITY.md) | 分区、搜索、弹幕和人数指标的当前能力 |
| [高刷新率与性能验证](docs/PERFORMANCE.md) | Android 120 Hz 适配、渲染优化和真机帧统计 |
| [WebDAV 配置](docs/WEBDAV.md) | 通用配置字段、坚果云示例和故障排查 |
| [MSIX 安装证书修复](docs/MXIS_OPEN.md) | Windows11 自定义 MSIX 证书不受信任安装解决方案 |
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
- 动态最高刷新率适配
- 弹幕点击与长按操作

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
- 弹幕 FPS 可以跟随设备最高刷新率

---

## 🔍 搜索与直播互动

支持跨平台直播搜索，并提供独立的平台分页状态。

搜索结果支持：

- 综合排序
- 平台顺序
- 观众人数
- 粉丝数量
- 直播状态筛选

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

---

## ⏺️ 直播录制

支持直播流实时录制。

可以将直播保存到本地，在直播结束后进行回放。

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

前往 [GitHub Releases](https://github.com/liuchuancong/pure_live/releases/latest) 获取最新安装包。

### Android

正式 Release 提供以下三种 ABI：

- `armeabi-v7a` — 32 位 ARM 设备
- `arm64-v8a` — 64 位 ARM 设备
- `x86_64` — 64 位 x86 设备

Android 始终使用正式包名：

`com.mystyle.purelive`

不再生成并存 QA 包。

正式 Release 使用仓库专用持久签名，因此可以直接覆盖旧的正式版本。

缺少正式发布密钥的本机测试包使用调试签名。

发布脚本会阻止调试签名进入正式 Release。

如果设备支持 64 位 ARM，推荐优先使用：

`arm64-v8a`

三种 ABI 的 APK 会根据 Release 构建流程分别生成，用户可以根据设备架构选择对应安装包。

### Windows

提供：

- Windows x64
- 便携 ZIP
- EXE 安装器
- MSIX 安装包

根据 Release 附件说明选择对应版本即可。

如果安装自定义 MSIX 后提示证书不受信任，可以参考：

[MSIX 安装证书修复](docs/MXIS_OPEN.md)

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