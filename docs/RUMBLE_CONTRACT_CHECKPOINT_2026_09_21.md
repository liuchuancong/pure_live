# Rumble 适配合同检查点（2026-09-21）

## 已固化合同

- 目录：`https://rumble.com/browse/live`，沿用官网 `page` 参数和 `<link rel="next">` 结束证据。
- 稳定身份：收藏与回流保存公开直播页 key，例如 `v7fngda-rt-de-live-tv`；它与播放器嵌入 ID `v7dh3fs` 分开处理。
- 搜索：精确直播页直接解析；频道链接与普通关键词在对应直播目录页内匹配频道、标题和分类，不宣称全站历史视频检索。
- 人数：目录 `.videostream__number` 和直播页动态 `.live-video-view-count-status` 是当前观看；JSON-LD `VideoObject.userInteractionCount` / 卡片 `data-views` 是累计观看。
- 媒体：官方页面浏览器会话观察 `/live-hls[-dvr]/TOKEN/playlist.m3u8`，只接受 `*.rumble.cloud` / `*.rmbl.ws` HLS 变体。
- 恢复与录制：每次恢复重新加载同一公开页面 key，重新取得 master，并按稳定分辨率 ID 找回用户所选档位。

## 本次生产证据

- `/browse/live` 返回 HTTP 200，公开卡片同时包含直播状态、当前观看、频道、封面、累计观看与下一页链接。
- 样本 `RT DE LIVE-TV` 的 JSON-LD 页面 key 为 `v7fngda-rt-de-live-tv`，播放器 bootstrap ID 为 `v7dh3fs`，验证两套身份不可互换。
- 页面动态当前观看字段返回明确整数；详情显示的累计观看继续保留在独立字段。
- 页面播放器取得的 HLS master 返回 HTTP 200 和 `#EXTM3U`，当前样本列出 1080p、720p、360p 三档 CDN 变体。
- 普通 HTTP 请求在部分 Rumble 页面可能进入动态校验，因此媒体解析使用官方页面浏览器上下文；目录仍保留轻量原生 HTML 请求。

## 验收边界

- 已写目录、HTML 合同、身份、HLS 白名单、恢复和目录迁移夹具。
- 按当前开发顺序，Android / Windows 真实播放、短录、断流恢复与长期稳定性在平台源码收敛后集中执行。
- Rumble Live Chat 仍列为后续能力，不将评论或累计互动数当作实时聊天/在线人数。

## 参考

- Rumble 公开直播目录：<https://rumble.com/browse/live>
- yt-dlp 当前 Rumble 提取器：<https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/rumble.py>
