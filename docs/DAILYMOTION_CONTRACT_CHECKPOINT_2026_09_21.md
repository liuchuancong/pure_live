# Dailymotion 适配合同检查点（2026-09-21）

## 当前生产合同

- 目录：`api.dailymotion.com/videos`，`mode=live`、`sort=live-audience`，沿用原生 `page/limit/has_more`。
- 搜索：直播节目关键词分页；精确视频 ID / `video`、`live`、`embed`、`dai.ly` 官方链接；精确频道名先读取 `live_onair`。
- 状态：`mode=live` 且 `onair=true` 才标记正在直播；同类未开播节目保留离线状态，普通 VOD 不进入直播适配器。
- 观看指标：公开响应未提供已核验的当前并发人数，不使用累计播放量代替。
- 媒体：官方 `geo.dailymotion.com/player.html?video=VIDEO_ID` 动态取得签名 HLS 主清单；仅接受 `*.dmcdn.net` 且路径包含同一视频 ID 的 rendition URL。
- 录制与恢复：播放器、录制器共用同一组原生 HLS rendition；恢复与录制开始时重新取得动态主清单。
- 弹幕：当前为空实现，界面持续说明范围。

## 2026-09-21 在线证据

- 官方目录返回原生分页、`mode=live`、`onair` 与所有者字段；`x3b68jn` 等当前样本为正在直播。
- 官方详情区分直播节目和普通 VOD。
- 官方嵌入播放器请求签名 `cdndirector.dailymotion.com` 主清单；播放器上下文读取成功。
- 主清单返回多档 `*.dmcdn.net` HLS rendition，独立原生请求得到媒体清单字节。

## 参考

- <https://developers.dailymotion.com/v0/reference/video-fields>
- <https://developers.dailymotion.com/me/v0/reference/video-filters>
- <https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/dailymotion.py>
