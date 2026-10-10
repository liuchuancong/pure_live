# PureLive v2 产品需求文档

> PureLive 是一个**壳**:直播、IPTV、音乐、视频站、TVBox 全部以**插件形式**接入。
> 壳提供插件运行时、媒体管线与统一界面;一切内容来自用户导入的插件与配置。
> 本文档是产品需求基线;技术方案见 [architecture/technical-architecture.md](architecture/technical-architecture.md)。

## 1. 产品形态

- 一套 Flutter 代码,发布 **Android 手机 / Android TV / Windows / macOS / Linux / iOS** 全平台。
- 壳内**零站点代码**:站点与源以插件形式由用户导入(JS 脚本 / Python 脚本 / M3U / TVBox 配置 / lx 音源脚本)。
- 四大内容域:直播 / IPTV / 音乐 / 视频站(含 TVBox)。

## 2. 域需求与参考映射

### 2.1 直播域(live)

| 需求 | 说明 | 参考实现 |
|---|---|---|
| 站点插件 | 每站一个插件:分类/房间列表/房间详情/取流/清晰度线路 | dart_simple_live-dev(bilibili/douyin/douyu/huya/twitch 五站协议)、本仓 master 维护线 35+ 站 |
| 房间会话 | 播放器接管、清晰度/线路切换(切换以真实打开新流为提交点)、画质记忆 | pure_live_TV live/playback |
| 弹幕 | 每站弹幕(bilibili protobuf-ws、douyu TCP 封包、huya WS、douyin wss) | dart_simple_live-dev 各站 danmaku |
| 登录 | 部分站需要 Cookie(二维码/粘贴) | 本仓 master 各站 account |
| 直播历史/收藏 | 跨站房间收藏与观看历史 | services 层已具备,消费于本域 |
| 多画面 | 同源多房间并播(看门狗/会话隔离已就绪) | pure_live_TV multiview |

### 2.2 IPTV 域(iptv)

| 需求 | 说明 | 参考实现 |
|---|---|---|
| 频道源导入 | M3U/M3U8 文件或 URL;频道分组(group-title) | external_tvbox M3uParser(已实装) |
| EPG 节目单 | XMLTV 文档:在播/下个/剩余分钟 | providers/iptv XmltvParser(已实装) |
| 换台 | 频道上下键环绕、数字选台、分组过滤 | features/iptv ChannelZapper(已实装) |
| 每频道请求头 | EXTVLCOPT UA/Referer 进票据 | 已贯通 |
| 频道收藏/最近观看 | 持久化分组 | pure_live_TV live/iptv storage 层(待实装) |
| 台标 | tvg-logo 展示 | 已解析 |

### 2.3 音乐域(music)

| 需求 | 说明 | 参考实现 |
|---|---|---|
| lx 音源脚本 | 用户导入 lx-music user-api 脚本(request/send/on/crypto/buffer/zlib) | MusicSourceScriptHost(已实装);lx-music-desktop/mobile 参考 |
| 播放链接解析 | musicUrl(source, musicId, quality) → url;质量 128k/320k/flac/flac24bit | 已实装 |
| 歌词/封面 | lyric/pic action | 宿主已支持 |
| 播放队列 | 顺序/repeatOne/repeatAll/stop,peek-then-commit | features/music MusicQueue(已实装) |
| 歌单导入 | 网易云/QQ/酷狗歌单 ID → 曲目表(经代理 API) | **bmsc-main** lib/api/music_provider.dart(参考) |
| B站作为音源 | B站视频音频流当音乐放;按 UP/收藏夹组织 | **bmsc-main**(参考:api/bilibili.dart + just_audio background) |
| 歌词显示 | LRC/YRC 同步滚动、翻译行 | ui/lyric(flutter_lyric 市场包,已接) |
| 音乐后台 | 后台音频 + 系统媒体面 | MediaSessionBootstrap(已接) |

### 2.4 视频站域(vod)

| 需求 | 说明 | 参考实现 |
|---|---|---|
| B站视频 | 热门/搜索/详情分P/播放(WBI+try_look 游客;登录后高清/收藏/历史/心跳) | **newBV-main** bili-api 92 端点(需求清单见 spider-runtime-requirements.md §6) |
| DASH 播放 | video.m4s+audio.m4s 经 FFmpeg 合流为 loopback HLS,播放器只见本地 URL | pure_live_TV VodPlaybackCore + media_core_ingest FfmpegIngestRelay |
| 番剧/PGC | playurl V1/V2、时间表、索引七分类 | newBV(端点已盘点) |
| 互动 | 点赞/投币/收藏/三联/弹幕发送(登录态) | newBV |
| 弹幕接收 | seg.so protobuf 分段弹幕 | newBV danmaku* + v1 danmaku |
| 字幕 | AI 字幕 api | newBV |
| 通用视频站 | 任意视频站以 spider 插件接入(categoryContent/detailContent/playerContent) | webtv-main spider 模型 |

### 2.5 TVBox 域(tvbox)

| 需求 | 说明 | 参考实现 |
|---|---|---|
| 配置导入 | 单仓/多仓(urls、storeHouse)文件或 URL;来源地址记录 | 已实装 |
| 站点插件 | type 3 js → fjs;type 3 py → serious_python;本地代理回调 | webtv-main spider 模型(部分实装,见缺口) |
| spider 运行环境 | req/joinUrl/md5X/aesX/rsaX/local kv/s2t/t2s/js2Proxy | **架构约束:drpy 同步 req vs fjs Promise 桥**(spider-runtime-requirements.md §4) |
| 库资产 | crypto-js/cheerio/gbk 随宿主分发(vendoring 决策) | webtv-main assets(约 1MB) |
| jar 解包 | spider.jar 内 js/py 发现装载 | webtv-main Loader(待实装) |
| 直播配置 | lives 组/频道进 IPTV 域 | 已实装 |
| playerContent 嗅探 | parse=1 时网页嗅探取流(webview) | webtv-main(待实装,需 webview 依赖) |
| 本地代理 | js2Proxy/localProxy 回调 URL 的本地 HTTP 服务 | **未建**(共同底座,优先级高) |

## 3. 插件模型(全域统一)

| 插件形态 | 运行时 | 覆盖 |
|---|---|---|
| JS 脚本 | fjs(Rust+QuickJS):plain-contract 与 drpy 模块两形态 | 站点/影视源/音乐源/搜索源 |
| Python 脚本 | serious_python 嵌入式 CPython(专用线程+本地网关) | TVBox py spider / 复杂站点 |
| Data 配置 | 解析器即运行时(M3U/TVBox JSON/XMLTV) | IPTV/TVBox 仓 |
| Native | Dart 编译进壳或独立包 | 高性能/需要原生能力的域适配 |

统一管线:导入(文件/URL)→ Manifest 校验 → 落盘 → 启用 → 能力注册表 → 首页/搜索/详情/播放自动消费。

## 4. 平台矩阵

| 能力 | Android | Android TV | Windows | macOS | Linux | iOS |
|---|---|---|---|---|---|---|
| 直播/点播/IPTV/TVBox | ✓ | ✓(dpad+焦点) | ✓ | ✓ | ✓ | ✓ |
| 音乐后台+媒体面 | ✓ | ✓ | ✓(SMTC) | ✓(MPRIS) | ✓(MPRIS) | ✓ |
| lx 音源脚本 | ✓ | ✓ | ✓(首跑待验) | ✓(待验) | ✓(待验) | ✓(待验) |
| py spider | ✓(chaquo 型) | ✓ | ✓ | ✓ | ✓ | —(按 serious_python 支持) |
| 录制 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## 5. 非功能需求

- 崩溃安全:所有持久化写原子化(write-then-rename);损坏数据降级为缺失。
- 风控防护:buvid3/WBI/try_look 等匿名态协议要点已按 v1 线实现;风控错误(-352/v_voucher)显式呈现。
- 资源上限:JS 沙箱 128MB 内存/GC 阈值/栈深/并发预算强制执行。
- 备份:收藏/历史/歌单/外观本地文件导出导入 + WebDAV 远端;凭据形态键两端拒收。
- 更新:releases.json 源检查,平台安装包直链。
