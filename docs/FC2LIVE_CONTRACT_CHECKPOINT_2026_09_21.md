# FC2 Live 合同检查点（2026-09-21）

## 当前生产证据

- 官网普通内容首页通过 `POST /contents/allchannellist.php` 动态加载当前目录；本次匿名探测返回 64 个条目。源码只将 `type=1` 作为媒体直播间，公开聊天和二人房间不混入直播目录。
- 目录的 `count` 是当前观看，`total` 是本场累计观看；房间 `memberApi.php` 同样独立返回两项，并提供频道号、主播、标题、分类、封面、开播状态与访问条件。
- 当前公开样本 `10608314` 的房间元数据返回 `is_publish=1`，控制接口签发短时 `wss://*.live.fc2.com/control/channels/<ID>` 会话。
- 控制会话完成后发送 `get_hls_information`，服务器返回同频道的 `master_playlist`。保持 WebSocket 时读取主清单得到 HTTP 200、标准 `#EXTM3U`，当前样本含 270 kbps、720 kbps、2.16 Mbps、3.6 Mbps 四个 H.264/AAC 变体。

## 源码合同

- 平台稳定身份是数字频道号；支持官网根路径和语言前缀房间链接。
- 官网普通目录为有限快照，分类和关键词搜索在同一快照内完成；精确频道号或链接通过房间接口查询，也能保留未开播状态。
- 登录、积分、门票或付费房间保持“访问受限”，不伪装为下播。
- 当前画质标识为 `auto`。原生输入读取平台 HLS master 自适应选档，不虚构未确认的分辨率标签。
- 播放和录制使用 owned input：每次原生打开或恢复都重新取得房间版本、短时控制令牌、WebSocket 和 HLS grant；控制 WebSocket 保持到私有 HLS relay 完整关闭。
- 媒体 URL 只接受同频道的 `https://*.live.fc2.com/a/stream/<ID>/0/master_playlist`，并校验签名查询字段。远端聊天另列后续批次。

## 参考

- FC2 Live 官网：<https://live.fc2.com/>
- yt-dlp 当前 FC2 Live 实现：<https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/fc2.py>

## 后续验收

1. Android 与 Windows 分别完成目录、精确搜索、首帧、停止和恢复。
2. 两端各执行一次短录、严格解码、时长与资源释放检查。
3. 校验本地 Clash 与直连策略下 HTTP、WSS 和 relay 使用同一网络路径。
