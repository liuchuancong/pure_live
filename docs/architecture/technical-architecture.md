# PureLive v2 技术方案架构

> 产品需求见 [../requirements.md](../requirements.md)。本文是技术方案:分层、插件运行时、
> 媒体管线、TV 支持,以及参考项目已验证机制的吸收映射。
> 当前 57 包分层护栏 0 错;实现进度标注见 [roadmap/w1-rebuild-progress.md](roadmap/w1-rebuild-progress.md)。

## 1. 分层架构(57 包)

```
apps/pure_live          组合根:零站点;装配/外观/路由/插件管理/设置/房间
L5 providers ×8         music(lx 宿主)/iptv/tvbox 兼容层;站点不编译进壳
L4 features ×10         home/live/vod/music/iptv/recorder/search/settings/account/backup
                        (domain+data 已实装;presentation=UI 最后)
L3 ui ×5                design(令牌)/ui_kit(组件)/adaptive(六风格+背景)/lyric(flutter_lyric)/player_ui(面板)
L2 services ×6          favorites/history/playlist/search/feed 聚合
L1 ecosystem ×11        capability/plugin_api/extension/permission/task/resolver/identity/
                        js_runtime/plugin_host/external_tvbox/spider 契约
L0.5 integrations ×3    media(内核+ingest+mediasession)/python_runtime/firebase
L0 foundation ×14       auth/backup/cache/diagnostics/events/files/l10n/logging/network/
                        platform_info/release/storage/sync/utils
```

方向严格单向;护栏 `tool/check_architecture.dart --strict` 强制(60→57 包,0 错)。

## 2. 插件运行时(四形态)

| 形态 | 运行时 | 包 | 状态 |
|---|---|---|---|
| JS | fjs(Rust+QuickJS):plain-contract + drpy 模块双形态;资源上限强制(128MB/GC/栈/并发) | ecosystem/js_runtime | ✓ |
| Python | serious_python 嵌入 CPython:worker 轮询本地网关(/poll /result /log /cache) | integrations/python_runtime | ✓ |
| Data | 解析器即运行时(M3U/TVBox 单仓多仓/XMLTV) | ecosystem/external_tvbox + providers/iptv | ✓ |
| Native | Dart 编译进壳(域适配层,不含站点) | providers/music 等 | ✓ |

管线:导入(文件/URL,自动识别形态)→ Manifest 校验(先于装载)→ staging 原子落盘 →
启用 → 能力注册表 → 首页/搜索/详情/房间/音乐自动消费。

**已知架构约束**:drpy 同步 req vs fjs Promise 桥(spider-runtime-requirements.md §4)——
异步型直接跑;同步型存量源四路径待定(W8 第一阻塞)。

## 3. 媒体管线

```
插件 resolve → MediaTicket → MediaKernelHost.open → PlayerHandle
                                    ↓ (DASH 双轨时)
        media_core_ingest FfmpegIngestRelay:ffmpeg 合流 → loopback HLS → 单本地 URL
                                    ↓
        MediaCorePlayerView(media_core_ui 六风格控制面:自动隐藏/进度/快捷键)
                                    ↓
        看门狗(超时/卡顿/到期预取)+ TicketSwapper(取新票重开保进度)
                                    ↓
        MediaSessionBootstrap(锁屏/通知栏/SMTC/MPRIS)+ 历史/收藏
```

参考项目机制吸收(pure_live_TV 生产验证):

| 机制 | 说明 | v2 落点 |
|---|---|---|
| VodPlaybackCore | 一个核心一个 handle;DASH 合流;备用 CDN 滚动;generation 守卫防慢解析覆盖新流 | integrations/media(待落) |
| GlobalPlayerService | 进程唯一内核单例 | app runtime ✓ |
| live/playback 分层 | states/services/models 分离 | features/live(进行中) |
| IPTV 分层 | data/parsers/storage 分离 | providers/iptv + features/iptv(部分) |
| 音乐会话双内核 | 'music'/'video' config 分会话调优 | features/music(待落) |

## 4. TV 端支持

| 需求 | 方案 | 落点 |
|---|---|---|
| 焦点导航 | dpad 包遍历;FocusScope 移焦 | app 壳(TV 波) |
| overscan 安全区 | 32px 边距变体 | ui/adaptive |
| TV 风格 | adaptive 追加 tv 条目(大字号/大间距/焦点边框) | ui/adaptive |
| 平台判定 | platform_info + leanback 特性 → 启动选风格 | app |
| 数字选台 | iptv zapper 数字键监听 | features/iptv |
| 播放控制条 | media_core_ui TV 焦点化变体 | ui/player_ui |

## 5. 安全与稳健

- 凭据:SecretVault(flutter_secure_storage 注入)存储;备份凭据键两端拒收。
- 风控:buvid3/WBI/try_look 匿名要点;-352/v_voucher 显式呈现。
- 沙箱:内存/GC/栈/并发上限强制;超预算快速失败。
- 原子写:全部持久化 write-then-rename;损坏数据降级为缺失。
- 备份:四数据域 + WebDAV 远端;凭据两端拒收;恢复后提示重启。

## 6. 构建与验证状态

- Windows Debug 构建 exit 0(首次全原生链产出:fjs/cargokit、serious_python、media_kit、ffmpeg)。
- 解析器经 iptv-org 真实 23198 行表验证(11209 频道/137ms/0 坏行)。
- W1 既有回归 52 测全绿(release 15/cache 26/backup 11)。
- 待首跑:fjs 沙箱探针(tool/probes/verify_lx_host.dart)、serious_python worker、插件导入全链、
  媒体会话/连播真机。
