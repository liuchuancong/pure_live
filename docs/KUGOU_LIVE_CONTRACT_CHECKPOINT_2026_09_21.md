# 酷狗直播合同检查点（2026-09-21）

## 结论

酷狗直播已完成首个源码闭环并注册到应用：官网动态分类、推荐/分类原生分页、主播关键词搜索（包含未开播结果）、精确房间与官方链接识别、房间状态、观看人数/热度/粉丝分列、签名 HTTPS FLV、播放恢复和录制解析均已接入。

本检查点记录生产接口和媒体字节证据，不代表 Android/Windows 原生播放器、长录制和所有网络条件已经集中验收。远端聊天协议仍保持显式待接入状态。

## 生产合同

| 能力 | 当前合同 | 解析规则 |
| --- | --- | --- |
| 官网分类 | `https://fanxing.kugou.com/` | 从 `/pcindex/category/{cid}` 导航读取 ID 与名称；解析为空时使用同日核验的内置快照 |
| 推荐目录 | `/mfanxing-home/h5/cdn/room/index/list` | `data.list`，`hasNextPage` 为原生翻页证据 |
| 分类目录 | `/mfanxing-home/h5/cdn/room/index/list_v4` | `data.list[].data`，分类 ID 直接传 `cid` |
| 主播搜索 | `/pt_search/pcsearch/v1/type_all.jsonp` | 严格校验 JSONP 回调，读取 `data.anchor.list`；开播与未开播结果均保留 |
| 房间详情 | `service2.fanxing.kugou.com/.../getEnterRoomInfo` | `liveSessionId`、`liveType` 与 `limitType` 共同判定直播、未开播、受限或未知 |
| 媒体 | `/video/pc/live/pull/mutiline/streamaddr` | 以 `protocol:rate:codec:layout` 为稳定档位，合并同档多 CDN 线路 |

## 数据语义

- `viewerNum` / `getViewerNum`：目录明确提供的当前观看人数。
- `hot`：平台热度，只进入热度字段。
- `fansCount`：主播粉丝数，独立展示。
- `watchCount`：当前公开合同未证实为并发人数，因此适配器不拿它补在线字段。
- 房间详情缺少目录实时人数时保留未知；已缓存目录卡片可补充同一房间的列表指标。

## 媒体约束与续期

当前生产样本房间返回两个 CDN line、一个 rate 档位以及 HTTPS FLV。适配器仅接受：

1. `https` 且主机根为 `liveplay.live.kugou.com`；
2. `/live/` 下与协议匹配的 `.flv` 或 `.m3u8`；
3. 同时含 `txSecret`、十六进制 `txTime` 与 `token`；
4. `token` 明确绑定当前房间号；
5. 媒体响应中的 `roomId` 与请求房间一致，`status=1`。

生产 HTTPS FLV 请求返回 HTTP 200、`Content-Type: video/x-flv`，开头三个字节为 `46 4c 56`。`txTime` 按十六进制 Unix 秒解析，播放器在失效前五分钟进入主动刷新窗口；播放和录制恢复均重新查询同一房间和同一稳定画质标识。

## 当前分类快照

`推荐、一起玩、音乐、高清、舞蹈、颜值、新秀、酷次元、搞笑、国风、游戏女神、王者荣耀、和平精英、网游竞技`。运行时优先读取官网导航，快照仅用于导航结构暂时解析为空的降级显示。

## 集中验收待办

- Android 与 Windows：目录、分类切换、关键词与未开播结果、精确链接回流。
- Android 与 Windows：当前直播首帧、多 CDN 切换、签名到期恢复。
- 录制：短录文件探测、停止收尾、网络中断后同档恢复。
- 聊天：继续核验官方实时协议与会话生命周期，取得可复现合同后再接入。

## 参考

- 酷狗直播官网：<https://fanxing.kugou.com/>
- DouyinLiveRecorder 当前平台清单与酷狗解析参考：<https://github.com/ihmily/DouyinLiveRecorder>
- bililive-go 平台实现结构参考：<https://github.com/bililive-go/bililive-go>
- biliup 录制与恢复结构参考：<https://github.com/biliup/biliup>
