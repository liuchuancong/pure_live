
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

## 维护分支说明（请先阅读）

<!-- maintenance-readme-markers: maintenance-scope; android-first; windows-maintained; upstream-feature-routing; bugfix-release-default -->

- 本仓库重点维护 **Android / Android TV 与 Windows**。当前日常使用 Android 更多，因此多数修复、功能整合和安装包会优先更新 Android；Windows 继续作为主要桌面维护目标。
- Linux、macOS 和 iOS 保留源码及上游兼容性，但缺少持续使用的对应设备，列为社区验证范围，不承诺每轮构建、更新时效或运行结果。
- 本分支更新频繁、历史定制较多，仍可能出现较多回归、接口时效和设备兼容问题。若更看重低频变更或原项目行为，可切换到[原项目](https://github.com/liuchuancong/pure_live)。
- 本仓库 Issue 仅受理**可复现的维护型 Bug**。新增功能、产品方向和全新平台适配请提交到[原项目 Issue](https://github.com/liuchuancong/pure_live/issues/new/choose)。
- 每个完成的 Bug 修复批次默认递增版本，优先构建 Android `arm64-v8a` 正式更新包，并同步源码、版本标签、安装包与校验文件到本仓库 GitHub Release；其他平台仍按本轮明确范围串行构建。
- 每次同步上游、分析 Bug 和审查原项目 Issue 的来源判定、根因、兼容、验证与回滚流程见[维护范围与问题处置策略](MAINTENANCE_POLICY.md)及[上游同步审查策略](UPSTREAM_REVIEW_POLICY.md)。

- **最新稳定版**：[v3.1.6](https://github.com/wzgrx/pure_live/releases/tag/v3.1.6)
- **当前构建版本**：Android / Windows `3.1.6+4119`（同一冻结源码、分平台串行构建）
- **Android 系统要求**：Android 8.0 / API 26 及以上（与当前 FFmpegKit 原生录制依赖一致）
- **v3.0.0 上游源码基线**：`liuchuancong/pure_live@e808dcae`；完整记录见 `docs/STAGE_UPDATE_3_0_0.md`
- **本轮构建平台**：Android arm64-v8a、Windows x64 安装程序与便携 ZIP；其他平台继续使用 v3.0.0 安装包
- **质量门禁**：播放器来源/Surface/几何回归见 `docs/PLAYER_RECOVERY_AUDIT_3_0_15.md`，十个平台录制链路见 `docs/RECORDER_REPAIR_AUDIT_2026-08-27.md`

本版本还会在启动、备份恢复和手动清理时剔除空平台、空房间号、`0/null/undefined/nan/none` 等无效关注记录，并按“平台 + 房间号”去重，避免损坏的历史收藏继续参与首页刷新。

录制页的自动重连、轮询、缓存限制、最高画质和目录命名等开关现在直接绑定持久化配置；缓存限制改为实时读取，重新进入页面或升级后保持用户选择。
Android 录制在创建任务和申请存储权限前检查目录：应用私有目录会提示选择可导出的目录且不会留下“未启动”幽灵任务；工作资料等任意数字用户空间均能正确识别，外部同名文件夹不会误判。

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
| [维护范围与问题处置策略](MAINTENANCE_POLICY.md) | 平台支持边界、Issue 分流、Bug 来源判定、上游 Issue 优先级与完成标准 |
| [上游同步审查策略](UPSTREAM_REVIEW_POLICY.md) | 三方差异、语义变更台账、冲突处置与合并门禁 |
| [构建与发布](docs/BUILD_AND_RELEASE.md) | 本机质量门禁、签名、打包和 Release 流程 |
| [Windows 数据与升级](docs/WINDOWS_DATA_AND_UPGRADE.md) | 安装目录存储、关注恢复、换盘迁移和回滚 |
| [Windows MSIX 证书说明](docs/MSIX_INSTALL.md) | 自行构建 MSIX 时的证书指纹核对与安装步骤 |
| [依赖与接口审计](docs/DEPENDENCY_AUDIT.md) | 固定工具链、升级约束和接口探测范围 |
| [平台接口与兼容性](docs/PLATFORM_COMPATIBILITY.md) | 分区、搜索、弹幕和人数指标的当前能力 |
| [高刷新率与性能验证](docs/PERFORMANCE.md) | Android 120 Hz 适配、渲染优化和真机帧统计 |
| [v3.1.6 虎牙醒目留言实时刷新修复](docs/STAGE_UPDATE_3_1_6.md) | 通知/WUP 时序根因、非阻塞有界补偿、双平台安装包与验证边界 |
| [v3.1.5 Android / Windows 双平台发布](docs/STAGE_UPDATE_3_1_5.md) | 同源版本冻结、分平台串行构建、安装包、签名状态与校验说明 |
| [v3.1.4 Android 平板关注刷新修复](docs/STAGE_UPDATE_3_1_4.md) | 横屏平板下拉刷新根因、移动平台判定、触控链路与交付证据 |
| [v3.1.3 Android / Windows 阶段更新](docs/STAGE_UPDATE_3_1_3.md) | 多画面真全屏退出根因、安全区控件、手势隔离和双平台交付证据 |
| [v3.1.2 Android / Windows 阶段更新](docs/STAGE_UPDATE_3_1_2.md) | Windows 真全屏根因、窗口往返、定向回归与发布证据 |
| [v3.1.1 Android / Windows 阶段更新](docs/STAGE_UPDATE_3_1_1.md) | 多画面声音、音量、弹幕目标、持久化、根因与发布证据 |
| [v3.1.0 Android / Windows 验收矩阵](docs/ACCEPTANCE_MATRIX_3_1_0.md) | 快速回归顺序、全功能实机账本、平台/录制/性能矩阵与发布门禁 |
| [2026-08-31 近期 Issue 审计](docs/ISSUE_AUDIT_2026_08_31.md) | #818 后台播放实机根因、最新 Issue 归因与 v3.1.0 处理范围 |
| [v3.1.0 直播录制参考项目审计](docs/RECORDER_REFERENCE_AUDIT_3_1_0.md) | biliup / bililive-go 固定基线、协议韧性、录制状态机和平台引入门槛 |
| [v3.1.0 网络代理链路审计](docs/NETWORK_PROXY_AUDIT_3_1_0.md) | API、封面头像、弹幕 WebSocket、全角地址输入与代理故障边界 |
| [v3.1.0 阶段更新](docs/STAGE_UPDATE_3_1_0.md) | Android / Windows 更新范围、根因、验证证据、安装包与回滚说明 |
| [WebDAV 配置](docs/WEBDAV.md) | 通用配置字段、坚果云示例和故障排查 |
| [v3.0.0 全平台稳定版](docs/STAGE_UPDATE_3_0_0.md) | 最新上游状态绑定、Android 录制恢复、依赖锁与全平台发布门禁 |
| [v3.0.1 Android 竖屏直播适配](docs/STAGE_UPDATE_3_0_1.md) | 稳定源方向识别、普通页自适应、全屏策略、画中画比例和房间覆盖 |
| [v3.0.2 Android 播放比例修复](docs/STAGE_UPDATE_3_0_2.md) | 普通横屏 16:9 边界、竖屏适配隔离、原生单层缩放与弹幕主题布局 |
| [v3.0.3 Android 竖屏 Surface 修复](docs/STAGE_UPDATE_3_0_3.md) | 原生/应用层几何统一、切换时序和横屏直播记录自适应双列 |
| [v3.0.4 Android 可信画面比例修复](docs/STAGE_UPDATE_3_0_4.md) | 移动端单一比例控制、异常元数据回退与历史记录数量/日期增强 |
| [v3.0.5 Android 有效画面识别](docs/STAGE_UPDATE_3_0_5.md) | 黑边内嵌竖屏识别、三档互动面板、横屏沉浸背景与动态 PiP |
| [v3.0.6 Android 竖屏几何仲裁修复](docs/STAGE_UPDATE_3_0_6.md) | 抖音流元数据识别、裁边代际隔离、延迟有效采样与渲染一致性门禁 |
| [v3.0.7 Android 竖屏真实画布修复](docs/STAGE_UPDATE_3_0_7.md) | 截图/解码坐标隔离、原生纹理防拉伸与显式横屏全屏入口 |
| [v3.0.8 Android 竖屏与小窗比例修复](docs/STAGE_UPDATE_3_0_8.md) | 抖音选中流几何、可逆居中裁边、动态应用小窗与 PiP 可视区域 |
| [v3.0.11 Android 跨模式比例隔离修复](docs/STAGE_UPDATE_3_0_11.md) | 清理 3.0.10 错误草稿、共享 fit 状态隔离与全屏局部竖屏视口 |
| [v3.0.12 录制与全平台画质审计](docs/RECORDING_AND_QUALITY_AUDIT_3_0_12.md) | 十个平台画质名称/排序/真实请求、录制重连、分片隔离、原子合并与资源边界 |
| [v3.0.13 十个平台录制修复](docs/RECORDING_AUDIT_3_0_13.md) | 严格房间状态、播放完整元数据、Android 首次初始化、原始 FFmpeg 参数向量与可见失败诊断 |
| [v3.0.13 Android 阶段更新](docs/STAGE_UPDATE_3_0_13.md) | 版本范围、关键修复、质量门禁与正式交付要求 |
| [v3.0.15 播放器回归修复审计](docs/PLAYER_RECOVERY_AUDIT_3_0_15.md) | 3.0.14 回归来源、路径/首帧门控撤除、竖屏几何恢复、推测式超时下线与回滚策略 |
| [v3.0.18 Android 真机播放与录制加固](docs/STAGE_UPDATE_3_0_18.md) | Android 硬解截图探测隔离、虎牙单连接签名刷新、跨重试录制统计与录制中心真机边界验证 |
| [v3.0.19 Windows x64 稳定版](docs/STAGE_UPDATE_3_0_19_WINDOWS.md) | Windows 启动按需初始化、播放器资源释放、录制统计、Escape、弹幕交互与正式安装/便携包验证 |
| [v3.0.17 播放与录制连续性更新](docs/STAGE_UPDATE_3_0_17.md) | 用户播放意图/音频焦点统一、直播暂停/EOF 恢复、分片真实大小与录制中心有界滚动 |
| [v3.0.16 播放器与录制阶段更新](docs/STAGE_UPDATE_3_0_16.md) | 生命周期单一所有权、Android Surface/几何、录制按需清晰度/线路、斗鱼输入与录制中心稳定性 |
| [2026-08-27 录制链路审计](docs/RECORDER_REPAIR_AUDIT_2026-08-27.md) | 十个平台录制契约、斗鱼/虎牙线路游标、FFmpeg 错误分类、持久化和回滚 |
| [v3.0.14 播放器与录制恢复审计](docs/PLAYER_RECOVERY_AUDIT_3_0_14.md) | 已由 v3.0.15 纠正的恢复设计及 FFmpeg 故障分层历史记录 |
| [v3.0.14 Android 阶段更新](docs/STAGE_UPDATE_3_0_14.md) | 播放器稳定性修复、目标产物与正式交付门禁 |
| [v3.0.9 Android 竖屏原生缩放修复](docs/STAGE_UPDATE_3_0_9.md) | 抖音官方几何模型、移动端单层缩放、实测裁边与四种呈现统一 |
| [2026-08-25 上游 Issue 审计](docs/ISSUE_AUDIT_2026_08_25.md) | #793～#798、#791 录制根因及既有问题处理状态 |
| [v2.9.7 Android update](docs/STAGE_UPDATE_2_9_7.md) | 全平台观看指标语义、热门排行、SOOP PC/移动端总在线与 40 项接口门禁 |
| [v2.9.6 Android update](docs/STAGE_UPDATE_2_9_6.md) | 上游同步、抖音 Feed、Bilibili 热度排行与 40 项接口门禁 |
| [v2.9.5 Android update](docs/STAGE_UPDATE_2_9_5.md) | 全平台画质切换契约、横屏自适应面板、观看指标与接口回归 |
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

当前 Android 正式包以 `arm64-v8a` 为主，适用于当前主流 64 位 ARM 手机和平板。更新页读取版本清单中的实际 ABI 列表，只展示对应 Release 实际发布的下载链接。

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

源码保留 Intel x64、Apple Silicon arm64 与 Universal 构建能力。本维护分支缺少持续使用的 macOS 设备，相关产物只在 Release 明确列出时成立，并标为社区验证。

### Linux

源码保留 Linux x64 构建能力。Linux 网页搜索会交给系统浏览器，原生搜索与播放继续在应用内完成；本维护分支缺少常规运行验证。

### iOS

源码保留 iOS arm64 设备构建能力。相关 `.app`、签名和 IPA 状态以具体 Release 说明为准，本维护分支缺少持续使用的 iOS 设备。

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
