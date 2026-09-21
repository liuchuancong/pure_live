# GoodGame 适配合同检查点（2026-09-21）

## 已固化合同

- 目录：`/api/4/streams/2/`，保留 `page`、`queryInfo.onPage` 与 `queryInfo.qty`，只选择 GoodGame 自有直播源。
- 稳定身份：频道链接保存规范化频道名；`/player?STREAM_ID` 保存 `id:STREAM_ID`，详情读取后回到规范频道身份。
- 搜索：精确频道名、频道 URL 和播放器 URL 走详情；其他关键词在对应直播目录页内匹配标题、主播和游戏，不虚构全站离线主播搜索。
- 人数：API `viewers` 是当前观看，`followers` 单独保存；`rating`、`premiums` 等平台计数不写入当前观看。
- 媒体：只接受 `hls.goodgame.ru/hls/STREAM_ID[_QUALITY].m3u8`，保留 `source` 与数字分辨率档位，要求短时 `expires` 和 `token`。
- 恢复与录制：重新查询稳定频道身份取得新 token，再按 `source` / `NNNp` 稳定质量 ID 恢复，不沿用到期地址。

## 本次生产证据

- 官网 API 返回 HTTP 200；当前目录报告 84 条、每页 50 条，并提供明确的页号和总量。
- 当前公开样本同时返回频道、主播、游戏、当前观看、粉丝、成人标记以及 `source`、720p、480p、240p 四档 HLS。
- 频道详情 `/api/4/users/CHANNEL/stream` 与播放器详情 `/api/player?src=STREAM_ID` 映射到相同 stream/channel 身份。
- 720p 地址返回 HTTP 200、`application/vnd.apple.mpegurl` 和标准 HLS master；清单声明 H.264/AAC、1280×720、24fps，并引用独立音频和视频子清单。

## 验收边界

- 已写目录、两种详情形态、身份、媒体域名/路径、观看口径、恢复和目录迁移夹具。
- 按当前开发顺序，Android / Windows 真实播放、短录、断流恢复与长期稳定性在平台源码收敛后集中执行。
- GoodGame 远端聊天仍列为后续能力，成人标记通过房间提示保留。

## 参考

- GoodGame 官网：<https://goodgame.ru/>
- Streamlink 当前 GoodGame 提取器：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/goodgame.py>
