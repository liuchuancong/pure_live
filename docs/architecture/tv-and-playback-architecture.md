# TV 支持与播放会话技术架构(pure_live_TV 模式吸收)

> 目的:把 `C:\Users\XA-158\projects\flutter\pure_live_TV` 参考项目验证过的播放/直播/IPTV 架构,
> 映射到 v2 的 57 包分层上,并落地 TV 端支持。本文是实施基准;每个 ✓ 项落包时在行内引用本文小节。

## 1. 参考项目验证过的核心机制(必须吸收)

### 1.1 VodPlaybackCore —— 点播流机制单件

pure_live_TV `lib/modules/vod/controllers/vod_playback_core.dart`(232 行,生产验证):

- **一个核心拥有一个 PlayerHandle**,挂在共享内核(GlobalPlayerService.instance.kernel)上;
- **DASH 合流**:B 站回答是 video.m4s + audio.m4s 双轨时,经 media_core_ingest 的
  `FfmpegIngestRelay` 用 FFmpeg 合成**滚动 loopback HLS 树**——播放器只见一个本地 URL;
- **备用 CDN 滚动**:同步 open 失败(坏节点/边缘缓存失效)先滚到应答的下一个 backup host,
  再报废 handle;
- **generation 守卫**:每次切换自增,被取代的慢解析不可能覆盖新流;
- **referer/音频独开/mpv vid 重建**等传输细节都在核心内,会话策略(队列/播放模式/进度/
  恢复快照)归上层控制器——核心只管打开与传输,刻意不做 Riverpod notifier。

**v2 落点**:integrations/media 新增 `VodPlaybackCore` 同名件(依赖 media_core_ingest +
media_core,均在集成层许可内),features/vod 的控制器组合它。

### 1.2 直播播放会话目录形态

pure_live_TV `lib/modules/live/playback/`:`controllers / dialogs / models / pages /
player_panel_layout / services(live_play_repository、hint cache)/ states(live_play_state)`。

**v2 落点**:features/live 按此分层——states(live_play_state)先落;services 映射
LxMusicRepository 同级的 LivePlayRepository;dialogs/pages 属 UI 最后。

### 1.3 IPTV 模块完整分层

pure_live_TV `lib/modules/live/iptv/`:`data / iptv_repository / models / parsers /
platform / services / storage`。v2 已有 providers/iptv(源)+ external_tvbox(M3U/XMLTV 解析);
features/iptv 已有 zapper/EPG window。缺口 = storage 层(频道分组收藏/最近观看持久化)。

### 1.4 媒体会话双内核配置

VodPlaybackCore 以 `PlayerConfig(name: 'music'/'video')` 区分会话,内核按 config 名做
per-config 调优与日志;GlobalPlayerService 单例持有唯一 kernel。

## 2. TV 端支持方案

| 需求 | 方案 | 落包 |
|---|---|---|
| 焦点导航 | dpad 包(已在 app 依赖)遍历可聚焦组件;TV 上 FocusScope 自动移焦 | app 壳 + features presentation(TV 波) |
| 遥控器返回 | go_router 返回栈原生支持;TV 弹窗需 pop 优先 | app 壳 |
| overscan 安全区 | UI 层 SafeArea 变体(TV overscan 32px) | ui/adaptive TV 变体 |
| 播放控制 | media_core_ui 已有 macos/fluent/material 控制面;TV 需焦点化控制条 | ui/player_ui TV 控制条 |
| 长按/数字选台 | iptv zapper 已支持;TV 数字键监听 | features/iptv + presentation |
| UI 风格 | adaptive 注册表追加 `tv` 风格(大字号/大间距/焦点高亮边框) | ui/adaptive + ui_kit |
| 平台判定 | foundation/platform_info 已有;isTV = android + leanback 特性 | app 启动时选风格 |

## 3. 实施顺序(依赖序)

1. integrations/media:`VodPlaybackCore`(DASH relay + CDN 滚动 + generation)——点播地基 ✓✓
2. features/live:states/live_play_state + services/live_play_repository——直播会话
3. features/iptv:storage 层(分组收藏持久化)
4. features/recorder data:任务持久化仓库
5. ui/adaptive:`tv` 风格 + overscan 变体(UI 波)
6. app:dpad 焦点遍历与 TV 入口(构建验证后)

## 4. 已确认的内核能力(直接可用,无需新写)

- `FfmpegIngestRelay`(media_core_ingest):DASH→loopback HLS,首播放列表等待=可播判定 ✓
- `MediaCorePlayerView`(media_core_ui):六风格控制面 ✓ 已接
- `MediaSessionBootstrap`(media_core_mediasession):系统媒体面 ✓ 已接
- `PlayerKernel.audioDriverFactory`:进程级单驱动 ✓
