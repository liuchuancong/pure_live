# PureLive v2 总体架构

> 状态:**定稿 / Architecture Decision v1.0**
> 定位:**跨平台、插件驱动、统一媒体运行时与内容生态平台**
> 上层文档:[README](../README.md) · 详细:各 contracts/、media/、plugin/ 子文档

## 1. 项目定位

PureLive v2 不再是"支持多个直播网站的播放器",而是:

> **一个跨平台、插件驱动的统一媒体生态平台。**

App 本身不绑定任何内容平台,不把业务能力写死在 Core。系统提供:插件运行时、能力契约、统一内容模型、统一媒体模型、播放内核(外部 media_core)、网络/存储/缓存/认证/同步、UI/Theme/Design System、权限与安全、数据迁移、诊断与可观测性、插件生态。

外部内容与服务一律通过 **Plugin / Provider / Capability** 接入。

## 2. 核心架构原则:万物插件化

> 任何可替换、可扩展、可独立演进的外部能力,优先设计为 Plugin / Provider / Capability,而不是直接写进 App Core。

插件化对象:直播源、VOD 源、音乐源、IPTV 源、TVBox 单仓/多仓、搜索源、Feed、歌词、字幕、弹幕、评论、主题、字体、Emote、元数据、EPG、推荐、认证、第三方扩展、数据解析器。

**但:Package 是工程组织方式,Plugin 是运行时扩展方式,Capability 是能力契约——三者必须分离。** 插件化不意味着一切都要单独成包。

## 3. 四个核心概念

```text
Plugin → Capability → Content → Media
```

- **Plugin**:声明"我是谁、能做什么、需要什么权限"——Manifest + Capabilities + Permissions + Providers + Runtime。三种形态:Native(Dart 编译,官方/高性能)、JS(第三方生态,跑沙箱)、Data(TVBox JSON/M3U/EPG 等无代码数据源)。
- **Capability**:系统提供什么能力——Live / VOD / Music / Iptv / Search / Feed / Danmaku / Subtitle / Lyric / Comment / Chapter / Quality / Line / History / Favorite / Playlist / Metadata / Recommendation / Auth / Account / Epg / Repository。
- **Content**:用户看到的内容——`ContentRef` / `ContentItem` / `Collection` / `Playlist` / `MediaItem`。
- **Media**:内容如何被播放——`MediaTicket` / `MediaPlan` / `PlaybackQueue` / `PlayerSession` / `PlayerKernel` / `PlayerAdapter`。

## 4. 总体分层

```text
┌─────────────────────────────────────────────────────────────┐
│                     PureLive App(组合根)                    │
├─────────────────────────────────────────────────────────────┤
│ Experience Layer:Home / Live / VOD / Music / IPTV /         │
│                  Search / Player / My                        │
├─────────────────────────────────────────────────────────────┤
│ Domain Services:History / Favorite / Playlist / Feed /      │
│                  Search / Link / Account / Sync / Cast /     │
│                  Remote / Recorder / Download                │
├─────────────────────────────────────────────────────────────┤
│ Content & Capability:ContentRef / ContentItem /             │
│                       Capability / Provider                  │
├─────────────────────────────────────────────────────────────┤
│ Plugin Runtime:Native / JS / Data Plugin,Registry,          │
│                 Manifest / Permission / Sandbox / Lifecycle  │
├─────────────────────────────────────────────────────────────┤
│ Media Runtime:MediaTicket / MediaPlan / Queue / Session /   │
│                Recovery / Watchdog / SegmentScheduler /      │
│                Recorder                                      │
├─────────────────────────────────────────────────────────────┤
│ Media Core(外部 workspace):PlayerKernel / PlayerAdapter /  │
│                MPV / Media3 / Fijk / …                        │
└─────────────────────────────────────────────────────────────┘
Foundation 横向支撑:Network / Auth / Storage / Cache / Files /
Platform / Logging / Diagnostics / Backup / Sync / Localization
```

## 5. 两条关键架构链(必须保持稳定)

**内容链**:
```text
Plugin → Capability → Provider → ContentRef → Content
      → Feed / Search / History / Favorite / Playlist / Link → Feature
```

**媒体链**:
```text
ContentRef → Provider → MediaTicket → MediaPlan
          → PlayerKernel → PlayerAdapter → Engine
```

## 6. 本仓落地约束

- **平台扩展基础设施**:Extension Gateway 是扩展体系最上层入口;Source → Repository → Provider → Resolver → MediaTicket 是核心数据链;Identity / Permission / Task / Diagnostics 是横向基础设施——详见 [platform-infrastructure.md](platform-infrastructure.md)。
- 播放内核 = 外部 [media_core](https://github.com/liuchuancong/media_core) workspace(git 依赖),**不依赖 PureLive、不被 PureLive 反向进入**;PureLive v2 只做其上的业务编排。
- UI 样式层 = fluttersdk_wind,只有 `pure_live_ui_kit` 允许直接 import(见 [../ui/ui-kit.md](../ui/ui-kit.md))。
- JS 插件沙箱 = flutter_js(仓库 `plugins/built_in_kotlin/flutter_js` 已含 AGP9 补丁)。
- 工程组织 = melos 单仓多包,分层清单见 [package-architecture.md](package-architecture.md);第一参考插件 = **Bilibili**(同时覆盖 Live/VOD/Search/Feed/Danmaku/Auth,最大程度验证生态链,见 [../roadmap/v2-roadmap.md](../roadmap/v2-roadmap.md))。
- 协议词典:33 站适配协议以 v1 `lib/shared/platforms` 与 pure_live_TV `lib/modules/vod` 为准,重写不复製。

## 7. 不变量

十条架构不变量(I1-I10)与依赖规则见 [dependency-rules.md](dependency-rules.md);媒体链细则见 [../media/media-architecture.md](../media/media-architecture.md);重大演进走 [../adr/](../adr/)。
