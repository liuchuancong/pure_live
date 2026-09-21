# VK Video Live 合同检查点（2026-09-21）

## 当前公开合同

- 官网：`https://live.vkvideo.ru/`
- 分类：`GET /v1/catalog/public_video_streams/category/`
- 在线目录：`GET /v1/catalog/public_video_streams/`
- 分类直播：`GET /v1/catalog/public_video_streams/category/{categoryId}/stream/`
- 原生频道搜索：`GET /v8/search/channel`
- 房间：`GET /v1/blog/{channel}/public_video_stream`
- 频道：`GET /v8/channel/{channel}`

目录使用服务端 `extra.offset`，搜索使用 `extra.after`；源码按服务端游标继续分页，不用本地页码臆造下一偏移。稳定房间身份是官网频道 slug，当前 `live.vkvideo.ru/{channel}`、旧 `live.vkplay.ru/{channel}` 与 `vkplay.live/{channel}` 统一回流到当前官网 URL。

## 字段口径

- `count.viewers`：当前观看人数；
- `count.views`：本场累计观看；
- `channel.counters.subscribers`：频道关注数；
- `channelStatus=offline`：原生搜索保留未开播频道；
- `isOnline`、`isEnded`、`accessRestrictions.view.allowed` 与 `isPlaybackDisabled` 共同决定直播和访问状态。

这些字段分列展示，累计观看和关注数不参与当前在线人数冒充。

## 生产媒体证据

当前公开房间返回主线路与共享线路各一条 `live_hls`，域名为 VK 返回的 `*.okcdn.ru`。使用官网 Origin、房间 Referer 和浏览器 User-Agent 请求主清单得到：

- HTTP 200；
- `Content-Type: application/vnd.apple.mpegurl`；
- 标准 `#EXTM3U`；
- 1080p、720p、480p、360p、240p 五档视频变体；
- 解析后的实际变体清单继续返回 HTTP 200 与媒体分片列表。

源码只接收 HTTPS `*.okcdn.ru` HLS 地址，按分辨率合并两条线路，并从 URL 路径的 `expires/{timestamp}` 推导失效与提前刷新时间。播放恢复和录制恢复重新取得房间与签名 master，再按稳定分辨率 ID 匹配，不跨档静默降级。

## 当前边界

- 远端聊天尚待接入，当前使用明确说明的空弹幕适配器；
- DASH/CMAF 地址虽由官网返回，首阶段使用已完成字节验证的 HLS；
- Android/Windows 原生播放与短录按用户要求留到平台源码集中收敛后的统一验收阶段。

## 参考来源

- 官网：<https://live.vkvideo.ru/>
- 开发者入口：<https://dev.live.vkvideo.ru/docs/index>
- Streamlink 当前实现：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/vkvideolive.py>
