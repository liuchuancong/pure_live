# 百度直播合同检查点（2026-09-21）

## 结论

百度直播已完成首个源码闭环并注册到应用：官网推荐与七个分类、原生会话分页、精确房间号、官方房间/分享链接、直播状态、当前观看人数、主播粉丝、FLV/HLS 画质、播放恢复和录制解析均已接入。

本检查点记录当前生产接口和媒体字节证据，不代表 Android/Windows 原生播放器、长录制及所有网络条件已经集中验收。官网 PC 端当前未公开稳定的昵称关键词搜索入口，因此首阶段搜索只接收精确房间号与已核验官方链接；远端聊天协议继续保留明确待办。

## 生产合同

| 能力 | 当前合同 | 解析规则 |
| --- | --- | --- |
| 推荐与分类 | `POST https://tiebac.baidu.com/livefeed/feed` | `resource=banner,tab,feed` 取得首屏、分类和 `session_id`；后页使用 `resource=feed`、`refresh_type=1` 与递增 `refresh_index` |
| 分类 | 同一首屏响应的 `tab.items` | 当前返回推荐、购物、财经、健康、教育、新闻、休闲七类，并保留各自 `type/channel_id` |
| 房间详情 | `GET https://mbd.baidu.com/searchbox?cmd=371` | 请求体绑定 `room_id/device_id`；`status=0` 为直播，`20` 为结束，付费、封禁与未知状态不降级成未开播 |
| 官方链接 | `live.baidu.com/m/room/{room_id}` 及两类 PC/H5 分享路径 | 仅接收 HTTPS、官方主机、严格路径和 6～20 位房间号；拒绝用户信息、非标准端口、片段与相似域名 |
| 媒体 | 房间 `video.url_clarity_list`、`live_hls_url`、`live_flv_url` | 以 `protocol:resolution:codec` 为稳定档位，仅接收路径绑定当前房间号的官方 HTTPS FLV/HLS |

目录请求签名沿用官网当前 PC 包的公开规则：参数名排序后以 `key=value&...` 拼接，再追加客户端公开常量并计算 MD5。签名覆盖设备 ID、时间、分类、频道、会话和刷新索引；适配器不复用其他房间或其他分页会话。

## 数据语义

- `feed.items[].audience_count`：官网直播卡片展示的当前观看人数。
- `searchbox 371.online_users`：房间当前观看人数；详情刷新优先使用该字段。
- `host.fans` / `real_fans_num`：主播粉丝数，独立展示。
- `total_users_count`、互动数和内部推荐分数不补作并发人数。
- 缺少明确当前人数时保持未知，不以零值或其他统计字段补齐。

## 媒体约束与生产证据

适配器只接收：

1. `https`，无用户信息、片段和非 443 端口；
2. `hls-live.bdstatic.com`、`flv-live.bdstatic.com` 或 `*.liveshow.bdstatic.com`；
3. `/live/` 下与协议匹配的 `.flv` / `.m3u8`；
4. 媒体路径中包含并边界绑定当前房间号；
5. 明细中的 FLV/HLS 原值；不把仅有 HTTP 且证书主机不匹配的旧 `*.lss-user.baidubce.com` 线路升级后交给播放器。

本轮当前推荐页返回 10 个直播房间。样本 `11572411040` 返回 1080P、720P、540P FLV 和默认 HLS；样本 `11571271139`、`11567732702` 返回默认 HLS/FLV。实际有界读取结果：

- 两条 HLS：HTTP 206，`Content-Type: application/x-mpegURL`，前缀 `#EXTM3U`；
- 两条 FLV：HTTP 200，`Content-Type: video/x-flv`，前三字节 `46 4c 56`；
- 房间详情 `status=0`，媒体路径均绑定请求房间号。

播放与录制恢复都会重新请求同一房间，并按稳定档位 ID 找回同协议、分辨率和编码，不跨档静默回落。

实现完成后，两个确定性测试文件共 **5/5 PASS**，受影响 Dart 范围 Analyze 无诊断。随后使用注册适配器相同的签名、解析与媒体白名单执行当前生产探针 **1/1 PASS**：首屏、七分类、直播详情和实际媒体前缀在同一流程内通过。

## 当前源码范围

- `lib/core/site/baidulive/baidu_live_link.dart`：严格房间身份与官方链接。
- `lib/core/site/baidulive/baidu_live_api.dart`：签名目录、分类、详情、状态、媒体白名单与数据语义。
- `lib/core/site/baidulive/baidu_live_site.dart`：目录游标、精确搜索、详情、画质、恢复与录制入口。
- `siteCatalogMigration=36`：现有安装只自动增加一次，用户后续隐藏选择保持不变。
- `LiveUrlTool` 与网页搜索解析器：官方链接回流为 `baidulive + room_id`。

## 集中验收待办

- Android 与 Windows：目录首屏、七分类、连续翻页、刷新与精确链接回流。
- Android 与 Windows：FLV/HLS 首帧、画质切换、断网后同档恢复。
- 录制：FLV 与 HLS 各自短录、停止收尾、网络中断恢复和完整解码。
- 搜索与聊天：继续核验官方昵称查询和实时消息合同，取得稳定生产证据后接入。

## 参考

- 百度直播官网：<https://live.baidu.com/>
- 百度直播当前公开房间路径：<https://live.baidu.com/m/room/11572411040>
- DouyinLiveRecorder 当前百度解析参考：<https://github.com/ihmily/DouyinLiveRecorder/blob/main/src/spider.py>
- bililive-go 平台实现结构参考：<https://github.com/bililive-go/bililive-go>
- biliup 录制与恢复结构参考：<https://github.com/biliup/biliup>
