# PureLive v2 文档中心

> PureLive v2 = 跨平台、插件驱动的统一媒体生态平台。
> 架构语言:**Plugin → Capability → Content → Media**(详见 [architecture/architecture.md](architecture/architecture.md))。

## 文档地图

| 目录 | 内容 |
|---|---|
| [architecture/](architecture/) | 总体架构、系统总览、运行时、**平台扩展基础设施(Extension Gateway)**、**外部生态直接导入(TVBox/LX Music 不转换插件)**、依赖规则、包架构、演进策略 |
| [contracts/](contracts/) | **平台契约与模型(platform-contracts / platform-models)** + 七大契约:插件/能力/内容/媒体/Provider/主题/Repository |
| [plugin/](plugin/) | 插件体系:三种形态、Manifest、生命周期、权限、安全、开发指南 |
| [content/](content/) | 统一内容模型:ContentRef / ContentItem / MediaItem / Collection / Playlist |
| [media/](media/) | 统一媒体管线:MediaTicket / MediaPlan / 会话 / 队列 / 恢复 / 看门狗 / 换线 / 录制 / 引擎适配 |
| [sources/](sources/) | 内容源架构:live(直播)/ vod(点播与 B 站、TVBox)/ music(音乐与多源)/ iptv |
| [services/](services/) | 跨域服务:auth/history/favorites/playlist/search/feed/links/download/sync/cache/backup |
| [ui/](ui/) | UI 体系:设计系统/主题/组件库/自适应(手机/TV/桌面) |
| [security/](security/) | 安全模型 / 插件沙箱 / 权限模型 / 凭据存储 / 网络安全 |
| [diagnostics/](diagnostics/) | 日志 / 追踪 / 播放诊断 / 崩溃报告 |
| [development/](development/) | 环境搭建 / 编码规范 / 包开发 / 插件开发 / 测试 / 发布 |
| [migration/](migration/) | v1→v2 迁移:数据库 / 设置 / 插件 |
| [adr/](adr/) | 架构决策记录 0001-0014 |
| [roadmap/](roadmap/) | v2 路线图 / 里程碑 / 发布计划 / **W1 实施进度与决策记录** |

## 阅读顺序(新人)

1. [architecture/architecture.md](architecture/architecture.md) → 2. [architecture/system-overview.md](architecture/system-overview.md) → 3. [contracts/capability-contract.md](contracts/capability-contract.md) → 4. [media/media-ticket.md](media/media-ticket.md) → 5. [development/setup.md](development/setup.md)

## 最高原则

> **Core 提供规则,Plugin 提供能力,Provider 提供内容,Media Core 提供播放,Feature 提供体验。**

十条架构不变量(I1-I10)见 [architecture/dependency-rules.md](architecture/dependency-rules.md)。
