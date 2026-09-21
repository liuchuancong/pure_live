# Steam Broadcasts 合同检查点（2026-09-21）

## 当前生产证据

- 官网匿名社区页通过 `/apps/allcontenthome` 加载热门直播；`appHubSubSection=13`、页号和 `broadcastsoffset` 形成原生分页。本次连续读取前两页，均为 10 条不同直播。
- 每张卡片明确提供 SteamID64、游戏、主播、当前观看、头像和直播缩略图；频道观看链接为 `/broadcast/watch/<SteamID64>`。
- 当前公开样本 `76561198373527746` 的 `getbroadcastmpd` 返回 `success=ready`、当前观看数、viewer token、DASH URL 与 HLS master URL。
- 当前 HLS master 实际读取为 HTTP 200 与标准 `#EXTM3U`，包含 1080p60、720p30、480p30、360p30 四个 H.264 视频变体及独立 AAC 音频组。

## 源码合同

- 稳定房间身份是 17 位 SteamID64；只接受官方 `steamcommunity.com/broadcast/watch/<ID>` 链接，不把应用社区页或 `steam.tv` 别名猜成账号身份。
- 目录保留官方每页 10 条与下一偏移；关键词在当前请求页内按游戏、主播、标题和 SteamID64 匹配，精确 ID/链接通过观看接口查询。
- `ready`、离线、等待与账号受限分开建模；受限账号保持未知状态，不伪装为下播。
- HLS 仅接受 `https://*.steamcontent.com/broadcast/<ID>/.../hls_manifest/.../master.m3u8`，并校验路径里的账号、媒体主机、`broadcast_origin` 及主清单子 URL。
- 当前画质为 `auto`，保留 master 自适应和独立音频组；播放、录制与恢复重新取得当前 master，不复用旧广播会话 URL。
- 远端聊天另列后续批次。

## 参考

- Steam Community Broadcasts：<https://steamcommunity.com/?subsection=broadcasts>
- Streamlink 当前 Steam 插件：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/steam.py>
- yt-dlp 2026 年 Steam HLS/DASH 现行问题证据：<https://github.com/yt-dlp/yt-dlp/issues/15955>

## 后续验收

1. Windows 使用 Clash 完成目录、精确查询、首帧、停止和恢复。
2. Android 使用同一代理策略完成播放、停止和恢复。
3. 两端各执行一次短录、严格解码、时长与资源释放检查。
