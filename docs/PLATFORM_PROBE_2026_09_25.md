# 全平台端到端探针（2026-09-25）

`tool/probes/all_sites_playback_probe_test.dart` 用 App 自己的适配器把每个已注册平台走一遍：目录 → 直播间详情 → 画质 → 播放地址（与播放器同一入口 `resolvePlayUrls`）→ 实际请求媒体并识别 FLV / TS / fMP4，HLS 会顺着主播放列表、子播放列表一直请求到分片，并回放播放列表下发的 Cookie。探针只输出每个平台的结论，不保存地址、Cookie 或媒体。

```bash
PURELIVE_ALL_SITES_PROBE=1 flutter test tool/probes/all_sites_playback_probe_test.dart
PURELIVE_PROBE_SITES=huya,douyu PURELIVE_PROBE_REPORT=/tmp/report.json ...   # 限定平台 / 输出 JSON
```

运行环境：WSL2 主机，Clash TUN 透明代理。结论只代表这台主机的网络；需要 WebView 的平台和最终播放效果仍以真机为准。

## 结果

首轮 24/45 取到媒体；本批修复后 **27/45** 取到媒体，另有 2 个平台成功建立私有播放输入。

| 结论 | 平台 |
| --- | --- |
| 取到媒体（27） | 17LIVE、AcFun、百度、哔哩哔哩、CC、CHZZK、抖音、斗鱼、虎牙、映客、京东、克拉克拉、快手、酷狗、LiveMe、LOOK、猫耳、PandaTV、Picarto、SHOWROOM、六间房、SOOP、Steam、TwitCasting、Twitch、微博、YY |
| 私有播放输入已建立 | FC2、niconico |
| 需要 WebView（Windows 集成测试 `integration_test/webview_sites_test.dart`） | Shopee Live、NimoTV 通过；Rumble 受 Cloudflare 质询影响时通过时不通过；Dailymotion 见下 |
| 按设计无公开目录 | 淘宝、TikTok、小红书、YouTube（仅搜索与链接回流） |
| 需要登录 / 成人认证 | Bigo（`needLogin`）、PopkonTV 目录前列均为成人直播 |
| 网络 / 地区限制 | GoodGame（`hls.goodgame.ru` 超时）、OPENREC（mellow-fan 接口 curl 同样 403）、VK 部分签名子播放列表 403（疑与 `srcIp` 和代理分流有关） |
| 平台侧变化 | 花椒：匿名 `getLives4H5` 报告总数但不再返回任何 feed，官网 PC 端已无直播列表；手机网络结果相同 |
| 快照有限 | TTingLive：首页快照仅 1 个房间且已下播 |
| 修复已验证 | Kick（Android 真机、Windows 集成测试） |

## 本批修复

| 平台 | 根因 | 提交 |
| --- | --- | --- |
| SHOWROOM | 无人开播的分类改为返回 `cell_type: 7` 提示卡，被当作直播行解析，整个目录报格式错误 | `b1e5db41` |
| PopkonTV | 游客搜索不再返回成人直播，详情退回主播资料判为下播；改为在 60 秒缓存的公开目录中确认 | `3331c42c` |
| LiveMe | 精选列表出现无 `ushortid` 的联合房间卡，整页因身份校验失败 | `3d0aaceb` |
| VK Video Live | 新 CDN `*.vkuser.net` 不在白名单；共享镜像 403 导致整个房间失败 | `bb421c45` |
| Kick | Cloudflare 对 `dart:io` 的 TLS 指纹一律 403（curl 与手机 curl 均 200）。Android 走平台 TLS（`HttpURLConnection`），Windows 走 WinHTTP/Schannel，均只放行 kick.com；IVS 播放列表仍走 dio。Linux 仍受阻 | `f1511974`（Android）、`76a59f31`（路由）、`8435e9e2`（Windows WinHTTP）；Android 真机 1080p60 播放与聊天通过，Windows `integration_test/native_http_kick_test.dart` 通过 |
| TwitCasting | 分片需要播放列表下发的 `lvhls_ssid_*` Cookie；FFmpeg（mpv/IJK）会回放，App 实测可播，仅探针需要补 Cookie 回放 | `59b29295`（探针） |
| NimoTV | 流信息包 `mStreamPkg` 改版：`id=` 前的 `|` 变为长度字节，全部房间格式错误；CDN 现在对整个查询串签名（`wsSecret`/`wsTime`/`fm`/`ctype`），改用 https 或追加 `ratio` 均 403/404，只能播放包内给出的原画 http 地址 | `ad82bcfa` |
| Shopee Live | ① 首次打开走 WebView 会话解析，冷启动可超过 45 秒，被统一超时判为网络错误（第一个房间失败、之后正常）；② 任一播放地址或封面不在白名单就整间报格式错误；③ 新增自有 CDN `play-spe.livestream.shopee.co.id`（`cdnID=SHOPEE`），同样是 codec 12 HEVC | `66a6bc78`、`e0185e6b`、`264a9351` |
| NimoTV（Android） | Android WebView 的移动端 UA 被首页脚本重定向到 `m.nimo.tv`，没有目录卡片，手机上 NimoTV 标签页始终失败；改用桌面 UA。房间标题含 HTML 实体（`Hi&#39;`）未解码。真机（经 App 代理）：目录与房间可打开、出画面，但 CDN 间歇 403 会中断播放 | `4828bc47` |
| Nimo / Dailymotion / Rumble / Shopee | Android 无头 WebView 没有使用 App 代理（只有 Twitch 用了），国内配置代理后这几个站仍直连失败；改为共享的 `WebViewProxyScope`，并串行化进程级 `ProxyController` | `9f541aae` |


## 环境限制（非代码问题）

- **Dailymotion**：元数据接口能返回签名主播放列表，但 `cdndirector.dailymotion.com` 对本机 Clash 出口（美国机房 IP）一律 403，`x-error-code: E005`，换请求头、Cookie、`app=com.dailymotion.neon` 均无效，判断为屏蔽机房/代理 IP。需要住宅 IP 才能验证。另外公开接口 `flags=live_onair` 会列出实际已下播（`DM003`）的频道，App 的目录用 `mode=live&sort=live-audience` 并过滤 `onair`，不受影响。
- **Rumble**：接口与页面都在 Cloudflare「Just a moment…」质询之后；无头 WebView 有时能通过（5 次中 2 次取到 1080p HLS），频繁请求后质询升级即失败。
- **Windows 上的 dart:io 不跟随系统代理**：WebView2 走系统代理，App 自己的请求只认「网络代理」里的设置。只开了系统代理（未开 TUN、未在 App 里设置代理）时，NimoTV 这类站点会出现「目录能加载、进房间失败」。可以考虑增加「跟随系统代理」选项（待定）。

## 已修复：Shopee Live 有声无画面（claude@79f78e06）

真机（K90，3.2.1）现象：目录、详情、在线人数与 1080p FLV 地址正常，播放时只有声音，系统没有创建视频解码器。

根因（2026-09-25 用真机「获取直链」取得的 FLV 在主机复现）：

- Shopee CDN（`*.livetech.shopee.co.id`）的 FLV 用的是**传统 FLV + 国内 codec id 12 扩展**表示 HEVC，不是增强型 FLV（之前据录制端推断为增强型 FLV，是错的）。
- FFmpeg 8.0 才在 `flvdec.c` 加入 `FLV_CODECID_X_HEVC = 12`。media_kit 的 `libmpv.so` 内置 FFmpeg 7.1，读到 codec 12 报 `Video codec (c) is not implemented` 并丢弃视频轨，只剩 AAC 音频。用 FFmpeg 7.1.5 静态版复现一致。
- 录制端 ffmpeg-kit 是 FFmpeg 9.0.2，认识 codec 12，所以录像有画面。

修复：`lib/player/core/flv_legacy_hevc_relay.dart`。libmpv 打开 Shopee 的 FLV 地址时，改走本机回环中继，把 codec 12 的视频标签改写为增强型 FLV（`hvc1`，FFmpeg 6.1 起支持）：只改标签头，NAL 与 HEVCDecoderConfigurationRecord 原样复制，其他标签不动。IJK / Exo 内核与其他站点的地址不受影响。

验证：

- 用真实 14 MB 样本，Dart 改写结果与 Python 原型逐字节一致，FFmpeg 7.1 解出 713 帧 HEVC 1080×1920（`missing picture in access unit` 警告在原始流上用 FFmpeg 8 也会出现，与改写无关）。
- 真机：Shopee 直播间 1080p FLV 正常出画面，竖屏布局识别正确；线路 1 → 线路 2 切换正常；退出后应用内小窗继续播放。
- 同时修复：直播间加载失败后退出，不再弹出黑色空白小窗（claude@928ea47d）。
