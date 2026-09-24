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
| 需要 WebView，真机验证 | Dailymotion、NimoTV、Rumble、Shopee Live |
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

