<div align="center">

<img src="assets/icons/icon.png" width="150" alt="Pure Live 图标"/>

# 纯粹直播（Pure Live）

**基于 Flutter 的开源多平台直播聚合播放器**

A third-party live stream aggregator built with Flutter.

[![Latest Release](https://img.shields.io/github/v/release/liuchuancong/pure_live?color=success&label=%E6%9C%80%E6%96%B0%E7%89%88%E6%9C%AC)](https://github.com/liuchuancong/pure_live/releases/latest)
[![Stars](https://img.shields.io/github/stars/liuchuancong/pure_live?color=yellow)](https://github.com/liuchuancong/pure_live/stargazers)
[![Downloads](https://img.shields.io/github/downloads/liuchuancong/pure_live/total?style=flat-square&color=orange&label=%E4%B8%8B%E8%BD%BD)](https://github.com/liuchuancong/pure_live/releases)
[![License](https://img.shields.io/github/license/liuchuancong/pure_live?color=blue)](LICENSE)
[![Platform](https://img.shields.io/badge/Android%20%7C%20TV%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20iOS-8A2BE2)](https://github.com/liuchuancong/pure_live)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)](https://flutter.dev)

<img src="assets/images/banner.png" width="720" alt="Pure Live 界面预览"/>

</div>

> **纯粹直播** 是一款开源的第三方多平台直播聚合播放器，使用 Flutter 构建，支持 Android、Android TV、Windows、Linux、macOS 和 iOS。一个应用看遍全网直播，支持多画面同看、弹幕、录制、定时关闭与数据同步。

---

## 📺 支持站点

**45 个直播站点 + IPTV 自定义直播源，共 46 个适配器。** 各站分区、搜索、弹幕、人数口径与能力边界见[平台兼容性](docs/PLATFORM_COMPATIBILITY.md)。

### 🇨🇳 国内平台（20 站）

| | | |
| --- | --- | --- |
| <img src="assets/images/bilibili.png" width="26"/> **哔哩哔哩** | <img src="assets/images/douyu.png" width="26"/> **斗鱼** | <img src="assets/images/huya.png" width="26"/> **虎牙** |
| <img src="assets/images/douyin.png" width="26"/> **抖音** | <img src="assets/images/kuaishou.png" width="26"/> **快手** | <img src="assets/images/yy.png" width="26"/> **YY 直播** |
| <img src="assets/images/cc.png" width="26"/> **网易 CC** | <img src="assets/images/acfun.png" width="26"/> **AcFun** | <img src="assets/images/missevan.png" width="26"/> **猫耳 FM** |
| <img src="assets/images/inke.png" width="26"/> **映客** | <img src="assets/images/kilakila.png" width="26"/> **克拉克拉** | <img src="assets/images/huajiao.png" width="26"/> **花椒直播** |
| <img src="assets/images/xiaohongshu.png" width="26"/> **小红书** | <img src="assets/images/weibo.png" width="26"/> **微博直播** | <img src="assets/images/jd.png" width="26"/> **京东直播** |
| <img src="assets/images/taobao.png" width="26"/> **淘宝直播** | <img src="assets/images/kugou.png" width="26"/> **酷狗直播** | <img src="assets/images/baidu.png" width="26"/> **百度直播** |
| <img src="assets/images/sixroom.png" width="26"/> **六间房** | <img src="assets/images/look.png" width="26"/> **LOOK 直播** | |

### 🌍 海外平台（25 站）

| | | |
| --- | --- | --- |
| <img src="assets/images/twitch.png" width="26"/> **Twitch** | <img src="assets/images/soop.png" width="26"/> **SOOP Live** | <img src="assets/images/youtube.png" width="26"/> **YouTube Live** |
| <img src="assets/images/tiktok.png" width="26"/> **TikTok LIVE** | <img src="assets/images/kick.png" width="26"/> **Kick** | <img src="assets/images/chzzk.png" width="26"/> **CHZZK** |
| <img src="assets/images/bigo.png" width="26"/> **Bigo Live** | <img src="assets/images/17live.png" width="26"/> **17LIVE** | <img src="assets/images/liveme.png" width="26"/> **LiveMe** |
| <img src="assets/images/showroom.png" width="26"/> **SHOWROOM** | <img src="assets/images/niconico.png" width="26"/> **niconico** | <img src="assets/images/openrec.png" width="26"/> **OPENREC / mellow-fan** |
| <img src="assets/images/ttinglive.png" width="26"/> **TTingLive / FLEX TV** | <img src="assets/images/picarto.png" width="26"/> **Picarto** | <img src="assets/images/twitcasting.png" width="26"/> **TwitCasting** |
| <img src="assets/images/dailymotion.png" width="26"/> **Dailymotion** | <img src="assets/images/rumble.png" width="26"/> **Rumble** | <img src="assets/images/vk.png" width="26"/> **VK Video Live** |
| <img src="assets/images/goodgame.png" width="26"/> **GoodGame** | <img src="assets/images/fc2.png" width="26"/> **FC2 Live** | <img src="assets/images/steam.png" width="26"/> **Steam 直播** |
| <img src="assets/images/panda.png" width="26"/> **PandaTV** | <img src="assets/images/popkon.png" width="26"/> **PopkonTV** | <img src="assets/images/shopee.png" width="26"/> **Shopee Live** |
| <img src="assets/images/nimo.png" width="26"/> **NimoTV** | | |

### 📡 IPTV / 自定义直播源

- 支持 **M3U / M3U8**、本地直播源、网络直播源导入
- 按分区、平台和频道管理，支持 EPG 节目单与订阅源同步

> 🚧 战旗直播、浪 LIVE 正在内部适配中。注册适配器不等于每个站点都已完整验收，实际能力以[平台兼容性](docs/PLATFORM_COMPATIBILITY.md)为准。

---

## 📥 下载安装

前往 [**GitHub Releases**](https://github.com/liuchuancong/pure_live/releases/latest) 获取最新安装包，并使用同一 Release 的 `SHA256SUMS.txt` 校验完整性。

| 平台 | 安装包 | 系统要求 |
| --- | --- | --- |
| 📱 Android / Android TV | APK（arm64-v8a / armeabi-v7a / x86_64，以 Release 实际发布为准） | Android 8.0（API 26）及以上 |
| 🖥️ Windows | EXE 安装器 / 便携 ZIP（MSIX 可自行构建，见 [MSIX 证书说明](docs/MSIX_INSTALL.md)） | Windows 10 / 11 x64 |
| 🍎 macOS | Universal DMG / ZIP | Apple Silicon + Intel |
| 🐧 Linux | Portable tar.gz | x64 |
| 📲 iOS | TrollStore IPA / 未签名 ZIP | arm64 |

- Android 使用正式包名 `com.mystyle.purelive`，正式 Release 使用仓库专用持久签名，可直接覆盖升级。
- Windows 安装向导支持选择其他磁盘，设置、关注、历史、IPTV、录制和缓存集中保存在安装目录 `AppData`。
- macOS / Linux / iOS 源码保留构建能力，相关产物以具体 Release 说明为准，属社区验证范围。

---

## ✨ 核心功能

### 🎬 多平台聚合

- 聚合 45 个直播平台，按平台与分区浏览、筛选和隐藏入口
- 跨平台搜索，支持综合 / 平台顺序 / 观众 / 粉丝等排序，直播 / 未开播筛选
- 各平台保持独立分页状态；"全部"搜索按平台完成顺序渐进显示，单平台超时不挡其他结果

### ▶️ 多播放器

Android / Android TV 支持在设置中切换播放器，出现黑屏、卡顿或硬解兼容问题时可随时更换：

- IJKPlayer
- EXOPlayer
- MPV Player

Windows、Linux、macOS 等桌面平台使用对应平台的播放器实现。

### 🖥️ 多画面同看

- 支持双画面、四画面和一大多小聚焦布局
- 每格独立播放、暂停、音量、清晰度和线路，只有聚焦画面出声
- 聚焦画面可接入平台弹幕；移动端最多 4 路解码，桌面端最多 9 路
- 小画面可自动使用低清晰度以控制占用，Windows 按实际可见尺寸协商渲染输出

### 💬 弹幕系统

弹幕过滤、用户屏蔽、关键词屏蔽、描边、透明度、字号、速度、显示区域、最大数量、发送间隔、刷新 FPS、平台原始颜色 / 统一颜色、点击与长按操作、精确重复与相似文本两级过滤。

弹幕系统采用房间会话隔离、平台消息 ID 去重与过期队列淘汰，避免切房后串房弹幕、重复弹幕或积压弹幕突然播放。

### 🪟 小窗弹幕

**设置 → 视频设置 → 小窗弹幕**，或在直播间进入**弹幕设置**配置：

- Android 系统画中画、Windows 小窗、应用内悬浮窗
- 独立弹幕控制器、队列与样式，不污染主播放器弹幕队列
- 自动根据窗口尺寸缩放，配置本地保存、下次进入继续生效

### 📺 高刷新率

Android 根据设备显示模式动态适配刷新率：请求当前分辨率支持的最高刷新率，适配 60 / 90 / 120 Hz 等高刷屏；界面跟随设备最高刷新率，弹幕主画面 60 FPS、小窗 30 FPS，手动模式最高 240 FPS，并优化封面解码、图片缓存与弹幕重绘。

### 🎧 ASMR / 助眠模式

- 新房间自动进入纯音频、媒体保活、自定义自动停止时间、后台持续播放
- 前台切音频保留视频解码热状态，回前台可复用当前纹理；后台自动停用视频轨降低电量开销

### ⏺️ 直播录制

- 直播流实时录制，保存到本地随时回放
- 自定义位置只写入带所有权标记的 `PureLiveRecords` 专用子目录，清理与容量限制不会误删其他文件
- 可配合定时关闭、后台音频、系统媒体通知进行长时间观看

### ⏰ 定时关闭

设置倒计时自动停止播放或退出应用，适用于睡眠、ASMR、长时间观看与后台音频播放。

### 💾 数据管理

- 本地配置导出 / 导入、配置恢复
- WebDAV 同步与备份，支持 [坚果云](docs/WEBDAV.md) 等服务商
- **仅导出 / 导入关注列表**：专用文件只含关注房间与分区，适合 Windows 与移动端之间交换
- 备份格式 v3，Cookie 与 WebDAV 凭据默认不进入同步备份

### 🔥 Firebase 用户同步（可选）

Firebase 不是必要条件，应用不要求注册账号。如需使用可 Fork 项目并在自己的 Firebase 项目中配置。

---

## 🔍 搜索与本地互动

搜索结果支持综合排序、平台顺序、观众人数、粉丝数量与直播状态筛选；百度直播支持精确房间号与官方链接查询，快手保留网页搜索，各平台原生搜索能力详见[平台兼容性](docs/PLATFORM_COMPATIBILITY.md)。

内置本地互动系统，昵称、头衔、弹幕输入、体验币、平台身份徽章、礼物目录、等级风格与画面礼物效果默认保存在本机，可在**设置 → 本地用户与互动**统一启用或关闭。

---

## 🧭 观看数据与导航

- 区分各平台观看数据口径：热度、真实在线人数、累计观看人数，不支持的平台保留关闭态并显示口径说明；在**设置 → 通用 → 观看数据与排行口径**选择排行方式
- **设置 → 导航栏显示控制** 可显示、隐藏和排序收藏、热门、分区及录制中心页签，支持拖动排序

---

## 🛠️ 本地构建

项目固定使用 Flutter `3.47.0` / Dart `3.13.0`、AGP `9.3.1`、Gradle `9.5.0` 与 Java 25 构建运行时，Android 字节码目标 Java/Kotlin 17。资源档位与缓存规则见 [构建资源策略](BUILD_POLICY.md)。

完整质量门禁：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1 -Scope Full
```

安装包每次只构建一个平台与变体，例如 Android arm64 正式包：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 `
  -Target AndroidArm64 -Configuration Release -FullRegression -RequireReleaseSigning
```

---

## 📚 文档

<!-- stable-doc-index:start -->
| 文档 | 内容 |
| --- | --- |
| [文档索引](docs/README.md) | 当前入口、开发验证、产品参考与历史证据查找方式 |
| [3.2.0 验收入口](docs/ACCEPTANCE_3_2_0.md) | 最短执行顺序、Android/Windows 批次及发布门禁 |
| [当前状态快照](docs/ACCEPTANCE_STATUS_3_2_0.md) | 当前候选、编号统计、主要阻塞与下一批顺序 |
| [Android / Windows 验收矩阵](docs/ACCEPTANCE_MATRIX_3_1_0.md) | 62 个编号行的唯一状态和证据所有者 |
| [维护范围与问题处置策略](MAINTENANCE_POLICY.md) | 平台支持边界、Issue 分流、来源判定与完成标准 |
| [上游同步审查策略](UPSTREAM_REVIEW_POLICY.md) | 三方差异、语义审查、冲突处置与合并门禁 |
| [构建与发布](docs/BUILD_AND_RELEASE.md) | 本机质量门禁、签名、打包和 Release 流程 |
| [平台接口与兼容性](docs/PLATFORM_COMPATIBILITY.md) | 分区、搜索、弹幕、观看指标和能力边界 |
| [平台扩展任务清单](docs/PLATFORM_EXPANSION_PLAN_2026_09_21.md) | 已接入范围、内部候选、下一生产合同批次与统一收敛顺序 |
| [Windows 数据与升级](docs/WINDOWS_DATA_AND_UPGRADE.md) | 安装目录存储、关注恢复、迁移和回滚 |
| [Windows MSIX 证书说明](docs/MSIX_INSTALL.md) | 自行构建 MSIX 时的证书核对与安装步骤 |
| [高刷新率与性能验证](docs/PERFORMANCE.md) | Android / Windows 帧、CPU、GPU 与资源采样 |
| [WebDAV 配置](docs/WEBDAV.md) | 通用字段、坚果云示例和故障排查 |
| [依赖与接口审计](docs/DEPENDENCY_AUDIT.md) | 固定工具链、升级约束和接口探测范围 |
| [参与贡献](CONTRIBUTING.md) | 分支、提交、测试和 Pull Request 要求 |
| [安全策略](SECURITY.md) | 私密漏洞报告和签名材料管理 |
| [版本说明](RELEASE_NOTES.md) | 当前稳定版变更与历史记录 |
<!-- stable-doc-index:end -->

---

## 📌 维护说明

<!-- maintenance-readme-markers: maintenance-scope; android-first; windows-maintained; upstream-feature-routing; bugfix-release-default -->

- 本仓库重点维护 **Android / Android TV 与 Windows**：多数修复与安装包优先更新 Android，Windows 继续作为主要桌面维护目标；Linux、macOS 与 iOS 为社区验证范围，不承诺每轮构建。
- 当前 **3.2.0** 处于完整验收阶段，尚未发布；进度与发布门禁见 [3.2.0 验收入口](docs/ACCEPTANCE_3_2_0.md)，当前状态见 [状态快照](docs/ACCEPTANCE_STATUS_3_2_0.md)。
- Issue 受理**可复现的维护型 Bug**（[提交 Bug](https://github.com/liuchuancong/pure_live/issues/new/choose)）；Bug 修复批次默认递增版本并优先构建 Android 正式包。
- 上游变更的来源判定、根因、兼容、验证与回滚流程见[维护范围与问题处置策略](MAINTENANCE_POLICY.md)及[上游同步审查策略](UPSTREAM_REVIEW_POLICY.md)。

---

## 🤝 贡献与致谢

**主开发者**：[@liuchuancong](https://github.com/liuchuancong)

**协助开发者**：[@RebornQ](https://github.com/RebornQ) · [@wzgrx](https://github.com/wzgrx)

> 📌 欢迎贡献维护型修复、测试和文档！分支、提交、测试与 Pull Request 要求见 [CONTRIBUTING.md](CONTRIBUTING.md)。

**代码参考**

- [dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live)
- [pure_live (Jackiu1997)](https://github.com/Jackiu1997/pure_live)

---

## 🌟 Star 趋势

如果 Pure Live 对你有帮助，欢迎给项目一个 ⭐ Star：

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
