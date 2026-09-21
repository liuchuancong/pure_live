# 浪 Live 合同与内部适配检查点（2026-09-21）

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
