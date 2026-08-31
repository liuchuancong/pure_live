# v3.1.0 网络代理链路审计

## 结论

本轮故障不是虎牙接口或弹幕协议整体失效，而是应用内部存在三套彼此独立的网络客户端：

1. 平台目录、房间详情和播放地址使用 Dio，已经读取“应用代理”；
2. 封面与头像由 `flutter_cache_manager` 自建 `HttpClient`，始终直连；
3. 实时弹幕由 `IOWebSocketChannel` 自建 `HttpClient`，也始终直连。

当 Android 当前 VPN/DNS 不能解析平台域名、但本机 Clash 可通过 ADB 反向端口提供代理时，第一条链路会恢复，后两条仍分别报封面失败和弹幕重连。设置页使用中文输入法输入 `127.0.0.1` 时还可能得到 `127。0。0。1`，旧代码把它原样交给 DNS，进一步造成看似随机的全站网络失败。

归因：`fork-regression` 与 `environment-or-data` 叠加。外部 DNS 状态触发问题，维护分支只代理 Dio、没有统一缓存和 WebSocket 路由，是应用侧第一处无效状态。

## 修复

- 新增单一 `buildProxyDirective`，统一校验开关、主机和端口，支持 IPv4、域名及带括号/不带括号 IPv6。
- 代理主机在输入、初始化、备份导入和序列化时统一归一化；中文全角句号、冒号和方括号会即时转换为 ASCII。
- 拒绝分号与换行组成的代理指令注入；半输入状态、空主机和越界端口保持 `DIRECT`。
- Dio、封面/头像缓存和所有平台的弹幕 WebSocket 共用同一个“应用代理”实时提供器；更改设置后新连接即时读取新值。
- WebSocket 的自定义 `HttpClient` 只用于 Upgrade 握手，握手结束后平滑关闭空闲 HTTP 连接，实际 WebSocket 继续由已升级传输承载，避免每次重连泄漏客户端。
- “播放器代理”继续单独控制媒体流，避免用户只想代理接口/弹幕时意外改变解码链路。

## 验证证据

- `test/proxy_routing_test.dart`：全角输入、空值/端口边界、IPv6 和指令注入。
- `test/web_socket_util_test.dart`：代理提供器进入 WebSocket 握手客户端；静默半开重连和心跳单连接行为保持通过。
- `tool/huya_danmaku_probe.py`：当前虎牙匿名房间完成 WebSocket 101、注册 `live/chat` 分组并收到 command 22 推送，证明协议本身有效。
- Android Debug 实测：Dio 通过 `localhost:7897` 加载虎牙目录；修复缓存客户端后同页封面和头像全部加载；中文输入法输入的地址保存为 ASCII `127.0.0.1`。截图：
  - `local-artifacts/runtime/android-proxy-images-fixed-retry2.png`
  - `local-artifacts/runtime/android-proxy-page-current.png`
  - `local-artifacts/runtime/android-proxy-ascii-hot.png`

正式 v3.1.0 产物仍按发布门禁重新执行代理开/关、错误地址恢复、虎牙房间弹幕和关闭房间后的连接释放；本文件区分源码/协议证据与最终安装包实测，不用其中一层替代另一层。
