
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

> 本维护分支基于 [liuchuancong/pure_live](https://github.com/liuchuancong/pure_live)，维护本机优先构建、正式签名、接口探测、Windows 数据迁移及高刷新率优化。上游变更按独立审查流程处理；3.2.0 周期不合并上游。

## 维护分支说明（请先阅读）

<!-- maintenance-readme-markers: maintenance-scope; android-first; windows-maintained; upstream-feature-routing; bugfix-release-default -->

- 本仓库重点维护 **Android / Android TV 与 Windows**。当前日常使用 Android 更多，因此多数修复、功能整合和安装包会优先更新 Android；Windows 继续作为主要桌面维护目标。
- Linux、macOS 和 iOS 保留源码及上游兼容性，但缺少持续使用的对应设备，列为社区验证范围，不承诺每轮构建、更新时效或运行结果。
- 本分支更新频繁、历史定制较多，仍可能出现较多回归、接口时效和设备兼容问题。若更看重低频变更或原项目行为，可切换到[原项目](https://github.com/liuchuancong/pure_live)。
- 本仓库 Issue 仅受理**可复现的维护型 Bug**。新增功能、产品方向和全新平台适配请提交到[原项目 Issue](https://github.com/liuchuancong/pure_live/issues/new/choose)。
- 每个完成的 Bug 修复批次默认递增版本，优先构建 Android `arm64-v8a` 正式更新包，并同步源码、版本标签、安装包与校验文件到本仓库 GitHub Release；其他平台仍按本轮明确范围串行构建。
- 每次同步上游、分析 Bug 和审查原项目 Issue 的来源判定、根因、兼容、验证与回滚流程见[维护范围与问题处置策略](MAINTENANCE_POLICY.md)及[上游同步审查策略](UPSTREAM_REVIEW_POLICY.md)。

- **最新稳定版**：[v3.2.3](https://github.com/wzgrx/pure_live/releases/tag/v3.2.3)，从维护分支 `claude` 发布，更新内容见[版本说明](RELEASE_NOTES.md)。
- **3.2.0 真机验收**：发布后继续进行。部分编号大项仍在补充双端证据，进度与剩余缺口见 [3.2.0 验收入口](docs/ACCEPTANCE_3_2_0.md)。
<!-- current-status-owner: docs/ACCEPTANCE_STATUS_3_2_0.md -->
- **当前验收快照**：源码提交、候选包、设备状态、编号统计与剩余阻塞只在[当前状态快照](docs/ACCEPTANCE_STATUS_3_2_0.md)维护；分项状态与证据见[验收矩阵](docs/ACCEPTANCE_MATRIX_3_1_0.md)。README 不再复制逐批测试数量、候选哈希和待办时间线。
- **平台范围**：v3.2.0 支持 45 个直播站点 + IPTV，共 46 个适配器；注册不等于目录、搜索、播放、弹幕和录制均已完整验收，能力边界见[平台兼容性](docs/PLATFORM_COMPATIBILITY.md)。
- **当前源码版本号**：`3.2.3+4126`。候选包按源码 SHA 与验证记录识别，同一版本号不代表包含相同修订。
- **Android / Android TV 安装要求**：当前源码与下一候选为 Android 8.0 / API 26 及以上、arm64-v8a；系统版本和 CPU ABI 两项都要匹配。已发布 v3.0.2 的实际 APK 最低为 Android 7.0 / API 24、仅含 arm64-v8a；Android 6.0.1 / API 23 电视不在该包的安装范围内。当前 API 26 下限与 FFmpegKit 原生录制依赖一致，旧系统兼容需另行处理原生依赖并完成电视端验收。
- **v3.0.0 上游源码基线**：`liuchuancong/pure_live@e808dcae`；完整记录见 `docs/STAGE_UPDATE_3_0_0.md`
- **本轮构建平台**：Android arm64-v8a、Windows x64 安装程序与便携 ZIP、Linux x64 便携 tar.gz；macOS 与 iOS 继续使用 v3.0.0 安装包
- **质量门禁**：播放器来源/Surface/几何回归见 `docs/PLAYER_RECOVERY_AUDIT_3_0_15.md`，十个平台录制链路见 `docs/RECORDER_REPAIR_AUDIT_2026-08-27.md`

本版本还会在启动、备份恢复和手动清理时剔除空平台、空房间号、`0/null/undefined/nan/none` 等无效关注记录，并按“平台 + 房间号”去重，避免损坏的历史收藏继续参与首页刷新。

录制页的自动重连、轮询、缓存限制、最高画质和目录命名等开关现在直接绑定持久化配置；缓存限制改为实时读取，重新进入页面或升级后保持用户选择。
Android 录制在创建任务和申请存储权限前检查目录：应用私有目录会提示选择可导出的目录且不会留下“未启动”幽灵任务；工作资料等任意数字用户空间均能正确识别，外部同名文件夹不会误判。

![Pure Live 界面预览](assets/images/banner.png)

---

## 📺 平台范围

**版本边界**：[v3.1.8](https://github.com/wzgrx/pure_live/releases/tag/v3.1.8) 支持 **9 个直播站点 + IPTV**；[v3.2.0](https://github.com/wzgrx/pure_live/releases/tag/v3.2.0) 支持 **45 个直播站点 + IPTV**。平台已注册不代表 45 站的目录、搜索、弹幕、播放与录制都已通过双端真机验收。各站实际能力和人数口径见[平台兼容性](docs/PLATFORM_COMPATIBILITY.md)，剩余验证见[当前状态](docs/ACCEPTANCE_STATUS_3_2_0.md)。

| 阶段 | 平台 |
| --- | --- |
| v3.1.8 起（9 站） | 哔哩哔哩、斗鱼、虎牙、抖音、快手、网易 CC、Twitch、SOOP Live、YY Live |
| v3.2.0 新增：国内（13 站） | AcFun、猫耳 FM、映客、克拉克拉、花椒、小红书、微博直播、京东直播、淘宝直播、酷狗直播、百度直播、六间房直播、LOOK 直播 |
| v3.2.0 新增：其他地区（23 站） | Picarto、TwitCasting、OPENREC / mellow-fan、TTingLive / FLEX TV、niconico、SHOWROOM、CHZZK、Kick、17LIVE、LiveMe、TikTok LIVE、YouTube Live、Bigo Live、PandaTV、PopkonTV、Shopee Live、VK Video Live、NimoTV、Dailymotion、Rumble、GoodGame、FC2 Live、Steam Broadcasts |
| 两阶段均有 | IPTV / 自定义直播源；本地或网络导入，不计作直播平台站点 |

可按平台与分区浏览、筛选和隐藏入口；搜索、直播状态、官方链接回流、人数语义、远端弹幕及录制能力随平台而异，不用统一标签代替各站合同。战旗直播、浪 Live 仍在内部适配准备阶段，暂未计入 45 站。

当前源码的“第三方账号”页可选填斗鱼 Cookie，取流与播放/录制请求使用同一会话；画质以平台实际确认档位显示。匿名接口可能将部分房间原画请求回落到 4M，登录态提升与长时稳定性仍需在候选包中对照验证，见 [Issue #873 审计](docs/ISSUE_873_DOUYU_QUALITY_AND_SESSION_AUDIT_2026_09_23.md)。

### 自定义直播源

支持导入：

- M3U
- M3U8
- 本地直播源
- 网络直播源

可以按照分区、平台和频道进行管理。

---


## 文档

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

## ✨ 核心功能

### 🎬 多平台直播

- 聚合多个主流直播平台。
- 支持平台分区浏览。
- 支持跨平台搜索。
- 支持直播 / 未开播筛选。
- 支持综合、平台顺序、观众和粉丝等排序方式。
- 各个平台保持独立分页状态。
- 猫耳 FM 自 v3.2.0 起支持官网直播间关键词分页搜索，可显示未开播房间；精确房间号和官网直播链接仍可直接查询。
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
- Windows 每格按实际可见物理尺寸和源分辨率防抖协商渲染输出；切换布局、晋升大画面和缩放窗口时保留播放会话，同时避免沿用旧格纹理。详见[多画面渲染目标审计](docs/MULTIVIEW_RENDER_TARGET_AUDIT_2026_09_11.md)。

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

3.2.0 开发源码新增 Kick 与 GoodGame 公开聊天只读接入；确认房间订阅后显示远端评论。当前安装包尚未包含这两项能力，双端真实消息验收仍待完成，详见[平台兼容性](docs/PLATFORM_COMPATIBILITY.md)。

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

支持跨平台直播搜索，并提供独立的平台分页状态。平台选择栏可访问屏幕外项目，但首尾严格有界；“全部”搜索按平台完成顺序渐进显示，单个平台超时或失败不会挡住其他结果。相邻页完整重叠时保留一次继续机会，连续第二个停滞页有界结束，避免漏掉后页或对固定响应无限追加；同一平台与关键词的未完成首屏重复提交共享一次请求，聚合结果已部分呈现时也不会重新请求，完成后仍可主动刷新。详见[搜索分页审计](docs/SEARCH_PAGINATION_STAGNATION_AUDIT_2026_09_11.md)与[搜索提交事务审计](docs/SEARCH_SUBMIT_TRANSACTION_AUDIT_2026_09_11.md)。

搜索结果支持：

- 综合排序
- 平台顺序
- 观众人数
- 粉丝数量
- 直播状态筛选
- YY、LiveMe、TikTok LIVE、YouTube Live、Bigo Live、PandaTV、PopkonTV、Shopee Live、VK Video Live、NimoTV、Dailymotion、Rumble、GoodGame、FC2 Live、Steam Broadcasts、京东直播、淘宝直播、酷狗直播、六间房直播等平台原生/本机搜索；百度直播支持精确房间号与官方链接查询，LOOK 直播支持精确房间号并在当前官网推荐页内筛选关键词，快手保留网页搜索
- Bilibili、斗鱼、虎牙、抖音、快手、网易 CC、Twitch、SOOP、YY、AcFun、Picarto、TwitCasting、SHOWROOM、CHZZK、Kick、17LIVE、LiveMe、TikTok LIVE、YouTube Live、Bigo Live、PandaTV、PopkonTV、Shopee Live、VK Video Live、NimoTV、Dailymotion、Rumble、GoodGame、FC2 Live、Steam Broadcasts、京东直播、淘宝直播、酷狗直播、百度直播、六间房直播、LOOK 直播网页直播间识别

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

## 🧭 底部导航

**设置 → 导航栏显示控制** 可以显示、隐藏和排序收藏、热门、分区及录制中心页签。至少保留一个可用页签；
只有当前显示的多个页签提供拖动排序入口，异常或旧版配置中的重复、未知与空白 ID 会在加载时自动整理。

---

## 👀 观看数据

Pure Live 会区分不同平台的观看数据口径：

- 热度
- 真实在线人数
- 累计观看人数

其中抖音、快手、网易 CC、Twitch、SOOP、AcFun、Picarto、TwitCasting、
mellow-fan（OPENREC）、FLEX TV（TTingLive）、CHZZK、Kick、17LIVE、LiveMe、TikTok LIVE、YouTube Live、Bigo Live、PandaTV、PopkonTV、Shopee Live、VK Video Live、NimoTV、Rumble、GoodGame、FC2 Live、Steam Broadcasts、酷狗直播、百度直播和 LOOK 直播可以显示平台明确返回的并发人数。

设置页会列出全部 45 个普通直播平台。虎牙、Bilibili、斗鱼、Dailymotion、京东直播、淘宝直播、六间房直播等平台按照公开数据实际提供的热度、
累计观看或未知状态展示，不把这些字段混作并发人数；不支持并发人数的平台保留关闭态并显示口径说明。

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

开启「同时录制弹幕」后，每段录像旁会生成同名 `.xml` 弹幕文件（B 站弹幕格式，时间轴与该段录像对齐），可用 DanmakuFactory 转成 ASS 字幕，或在 PotPlayer 等播放器中加载。需要该平台已接入远端弹幕。

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

“备份与还原”还提供**仅导出/导入关注列表**；WebDAV 更多操作提供“仅上传关注列表”，接收端选择“仅恢复关注列表”。专用文件只含关注房间和分区，适合在 Windows 与移动端之间交换，其他设备设置保持各自原值。完整备份和关注列表专用文件分开命名；专用文件需使用关注列表导入入口。

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

当前 Android 正式包以 `arm64-v8a` 为主，适用于当前主流 64 位 ARM 手机和平板。更新页读取版本清单中的实际 ABI 列表，只展示对应 Release 实际发布的下载链接。

Android 始终使用正式包名：

`com.mystyle.purelive`

不再生成并存 QA 包。

v3.1.8 与 v3.2.0 的 APK 均为 Release 编译、使用同一个固定的本地调试证书签名（SHA-256 `1e832295…8f237ff7b9`，文件名或元数据标注 `debug-signed`），两者之间及同证书的测试包之间可以直接覆盖安装、保留数据。证书不同的旧安装包需要先在应用内备份，卸载后再安装。

### Windows

提供：

- Windows x64
- 便携 ZIP
- EXE 安装器

EXE 安装向导支持选择其他磁盘，并把设置、关注、历史、IPTV、录制和缓存集中保存到安装目录 `AppData`。便携 ZIP 不包含运行时数据。

自行构建 MSIX 时的证书配置见 [Windows MSIX 证书说明](docs/MSIX_INSTALL.md)。

### macOS

源码保留 Intel x64、Apple Silicon arm64 与 Universal 构建能力。本维护分支缺少持续使用的 macOS 设备，相关产物只在 Release 明确列出时成立，并标为社区验证。

### Linux

源码保留 Linux x64 构建能力。Linux 网页搜索会交给系统浏览器，原生搜索与播放继续在应用内完成；本维护分支缺少常规运行验证。

### iOS

源码保留 iOS arm64 设备构建能力。相关 `.app`、签名和 IPA 状态以具体 Release 说明为准，本维护分支缺少持续使用的 iOS 设备。

---

## 🧪 本地构建与验证

项目固定使用 Flutter `3.47.5` / Dart `3.13.4`、AGP `9.4.1`、Gradle `9.8.0` 与 Java 26（Temurin 26.0.2.1）构建运行时，Android 应用和插件字节码目标保持 Java/Kotlin 17。资源档位、串行平台阶段和增量缓存规则见 [构建资源策略](BUILD_POLICY.md)。正式交付的完整质量门禁：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1 -Scope Full
```

安装包每次只构建本轮明确指定的一个平台与变体，例如 Android arm64 正式包：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 `
  -Target AndroidArm64 -Configuration Release -FullRegression -RequireReleaseSigning
```

当前稳定版的源码基线、修复范围、验证证据、实际构建平台和产物校验见顶部版本条目及对应阶段文档；通用门禁和单平台串行发布流程见[构建与发布](docs/BUILD_AND_RELEASE.md)。

## 🤝 参与开发

- **主开发者**：[@liuchuancong](https://github.com/liuchuancong)
- **协助开发者**：[@wzgrx](https://github.com/wzgrx/pure_live)
- **协助开发者**：[@RebornQ](https://github.com/RebornQ)

> 📌 **欢迎贡献维护型修复、测试和文档**！
> - 如发现 License 使用不当，请提交 Issue 或 Pull Request
> - 本仓库 Issue 聚焦可复现 Bug；新增功能和产品建议统一提交到[原项目](https://github.com/liuchuancong/pure_live/issues/new/choose)

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
