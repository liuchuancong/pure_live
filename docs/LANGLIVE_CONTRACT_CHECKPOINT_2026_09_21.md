# 浪 Live 合同与内部适配检查点（2026-09-21）

## 2026-09-23 CDN 边缘复核

同一公开房间 `5461380` 的官网 `GET https://api.lang.live/langweb/v1/room/liveinfo?room_id=5461380` 出现明确的边缘差异：本机直连到当时的 CloudFront `13.33.183.19` / `.128` 返回 HTTP 200、`ret_code=0`，房间身份一致、`live_status=0`；直连到当时 DNS 返回的 `3.160.150.11` / `.38` 均为 HTTP 403 HTML，经本机 Clash 也为 403。`--resolve` 仅用于诊断同一官方主机的两个边缘，**不写入生产解析或固定 IP**。一个已下播房间的元数据成功不能证明当前直播媒体可播。

新增显式只读探针 `PURELIVE_LANGLIVE_ROOM_PROBE=1`：走当前系统解析时，注册前的 `LangLiveApi` 如实报告 `edge_access_blocked`，不把 403 当作房间下播；与确定性适配器测试合计 **8/8**，记录 `20260923T090143778Z-quality-focused.json`。探针此前两次以严格成功断言运行时分别遇到 `access` 与诊断边缘连接 `transport`，失败记录保留在本机 `local-artifacts/build-records/`。当前仍缺公开在播房间与 FLV/HLS 前缀字节证据，故注册门槛不变。

## 已完成

- 从当前 Android 包 `com.lang.lang` 6.6.7.6（versionCode 2353）确认生产域名仍为
  `api.lang.live`、`core-api.lang.live`、`pub.lang.live`，直播 CDN 资产使用
  `*.lv-play.com`。
- 当前包确认客户端仍包含直播首页、精确用户、直播进入、搜索、FLV 播放和 HLS 播放所需
  的模型及端点族；旧版公开 Web 合同仍是
  `GET /langweb/v1/room/liveinfo?room_id=ROOM_ID`。
- 新增内部 `LangLiveApi`、`LangLiveLink`、`LangLiveSite`：
  - 识别精确账号 ID、`/main/{id}` 与 `/room/{id}`；
  - 严格校验 `pretty_id`，区分直播、离线和未知状态；
  - FLV/HLS 仅接受 `*.lv-play.com` 且扩展名与字段一致的 URL；
  - 播放、录制和恢复都重新使用受控房间快照；
  - 有界响应、超时、取消、HTTP/业务错误和空媒体均独立分类。

## 注册门槛

当前出口访问 `api.lang.live` 命中 CloudFront 403，而 `webview.lang.live` 与
`core-api.lang.live` 可达。这是访问区域证据，不据此推断服务停止。

内部适配器暂不加入 `Sites`。注册前还需从当前可访问区域取得一次生产响应，并对返回的
FLV/HLS 执行前缀字节检查；页面或测试数据里的示例 URL 不计作生产媒体证明。

## 当前 APK 证据

- 文件：APKPure 分发的当前签名 XAPK，包名 `com.lang.lang`；本地只作分析，不纳入 Git。
- XAPK SHA-256：`e0ec513317b37e31f0a8ee5c7a0a200fef36a75c44fc7b9a74fb4b83d6fc7563`
- 官方签名指纹（商店页面）：`5adf89b79c8290de39fceaaf9eec7fbfebb76319`
- 当前包默认生产域：`https://api.lang.live/`、`https://core-api.lang.live/`、
  `https://pub.lang.live/`。
- 当前包端点证据：`v3/home/hot`、`/v2/search/user`、`/v2/user/user_live_info`、
  `v2/live/enter`；进入直播模型继续携带 `liveurl` 兼容字段。

## 下一步

1. 从可访问区域请求当前在播账号，保存脱敏后的响应结构与媒体协议证据。
2. 校验 FLV `FLV` 文件头或 HLS `#EXTM3U`，验证请求头和重定向边界。
3. 通过后注册站点、补设置迁移和全局 URL/外部打开器，并把计数增加 1。

## 来源

- 官方 Google Play：<https://play.google.com/store/apps/details?id=com.lang.lang>
- 官方 WebView：<https://webview.lang.live/>
- 官方房间页：<https://www.lang.live/main/5461380>
- 历史参考实现：<https://github.com/bililive-go/bililive-go/blob/ef71711a7c573b013d82fec01ee8d0609ee36aca/src/live/lang/lang.go>
- APKPure 当前包页面：<https://apkpure.net/cn/lang-live-live-music-shows/com.lang.lang/download>
