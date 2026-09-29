# YY 匿名弹幕协议审计（2026-09-02）

## 结论

此前 YY 播放和录制可用但实时弹幕始终没有进入“连接正常”状态，根因不在播放器，也不是房间安静：旧实现把一个手工拼接的 `3104100` 数据包直接发给当前 WebSocket，并假定服务端会把 `3104600` 聊天包直接放在最外层。当前 YY H5 客户端实际要求先完成匿名账号、AP、频道路由和广播组订阅；聊天消息还嵌套在 appid `31` 的服务消息中。因此，旧代码从未真正加入目标房间。

本仓库现按当前官方网页实现重建为一个有界、可测试的状态机。播放地址和录制逻辑没有随本修复改变。当前官方 SDK 使用 `wss://h5-sinchl.yy.com/websocket?appid=yymwebh5&version=3.2.10&uuid=UUID`；UUID 同时进入 AP 登录数据。URL、版本和二进制字段必须作为一个协议版本整体维护。

K90 Pro 的后续网络证据排除了 YY CDN 和证书故障：设备无系统 HTTP 代理，DNS/ICMP/TCP 443 正常，证书链与主机名验证通过，三个当次解析到的 CDN IPv4 地址都返回 `101 Switching Protocols`。应用侧却在 `IOWebSocketChannel` 的 10 秒 connect timeout 到期，尚未进入二进制 UDB 阶段。把 `DIRECT` 恢复为 dart:io 默认 client 后现象不变，因而代理 client 只是应当消除的多余差异，不是根因。

最终用同一 Dart 3.13 运行时对请求头做逐项矩阵，定位到 YY 边缘服务的非标准行为：`Sec-WebSocket-Version` 或 `Sec-WebSocket-Key` 只要使用小写字段名，服务端就保持连接但不返回 HTTP 响应；使用浏览器式大小写时约 0.2 秒返回 `101`。HTTP 字段名按标准应不区分大小写，而 dart:io `HttpClient` 会规范化为小写，因此常规 `WebSocket.connect` 在 Windows 和 Android 上都必然等到超时。当前实现只为 YY 增加一个有界的 RFC 6455 传输：保留这两个字段名的浏览器式写法，校验 `Sec-WebSocket-Accept`，限制握手/消息长度，处理二进制、分片、ping/pong 和 close；其他平台继续使用 SDK WebSocket。

传输打通后，官方网页 CDP 实帧与本仓库发包逐字节对比又定位了第二层协议漂移：`3.2.10` 的频道加入负载必须携带属性 `2="0"`、`3="1"`，路由头结尾必须是 `0xff787878`，且频道路由包先于 appid 订阅包发送。旧实现缺少 14 字节属性、尾标记写成 `0xff7e7e78`、顺序相反，所以 UDB/AP 均成功但服务器静默丢弃 `513035`。修正后同一桌面探针已收到 `512011/2048514`、进入 joined，并持续收到 `533080` 广播组消息；最新 Android 实机仍按下方门禁验证真实聊天可见性。

## 当前依据

- YY 房间页面：<https://www.yy.com/22490906/22490906>
- YY Player manifest：<https://web3.yystatic.com/project/yyplayer_deploy/manifest.json>
- 2026-09-02 manifest 指向的 H5 service bundle：<https://web.yystatic.com/project/yycom_live/pc/js/async_component/H5ServiceYYSDK-b6085282.js>
- 2026-09-02 页面实际建立的 WebSocket：`appid=yymwebh5&version=3.2.10&uuid=...`
- bundle 运行时声明的 H5 service 协议版本：`3.2.10`

审计时同时在本地冻结了该 bundle，并核对 `778244`、`775684`、`513035`、`2048258`、`2048514`、`537944`、`533080`、`3104600` 和版本号均来自同一份当前资源。网页资源以后发生变化时，应重新审计 manifest 与 bundle，而不是继续猜测二进制字段。

## 官方序列与本仓库实现

| 阶段 | 请求 URI | 响应/消息 URI | 本仓库动作 |
|---|---:|---:|---|
| 匿名 UDB | `778244`，内部 `19822` | `778500`，内部 `20078` | 取得匿名 uid、用户名、口令和 cookie |
| AP 登录 | `775684` | `775940` | appid `259` 登录；只接受成功码 `200` |
| 频道路由 | `513035`，内部 `2048258` | `512011`，内部 `2048514` | 以当前 topSid/subSid 和匿名加入属性 `2="0"/3="1"` 加入频道 |
| appid 订阅 | `538456` | — | 在路由包之后订阅 `31/101/102/103/17` |
| 广播组 | `537944` | `533080` 或 `28760` | 加入频道和 service 广播组 |
| 聊天 | — | appid `31` 内部 `3104600` | 解出昵称和正文，并按当前房间严格过滤 |
| 心跳 | `794116` | `794372` | AP 登录开始后发送；45 秒无入站数据触发有界重连 |

只有收到目标 topSid/subSid 的 `2048514` 且登录状态为 `4` 后，适配器才上报弹幕服务 ready。WebSocket TCP/HTTP upgrade 成功本身不再被误报为“弹幕连接正常”。

## 稳定性约束

1. 每个 WebSocket 消息可包含多个 YY 包，按包头长度逐个解析。
2. WebSocket 地址必须与当前 SDK 完全一致，包含 `appid/version/uuid` 查询参数；版本和 UUID 不得与 AP 登录身份分离。
3. 所有长度字段均做边界检查；截断或异常聊天包只记录告警，不让 socket 回调抛出。
4. 旧房间/旧连接由 generation 隔离；stop 后的回调不会写入新页面。
5. 聊天同时校验 topSid 和 subSid，避免跨房间、延迟包或重连残包进入当前列表。
6. 握手 15 秒未完成则重连；连接建立但协议未完成时不启动 ready 状态。
7. 每次连接失败记录握手异常或远端 close code/reason，避免只留下“正在重连”而丢失根因。
8. 通用 WebSocket 的 `DIRECT` 路由不创建多余的自定义 `HttpClient`；其他平台的真实应用代理仍沿用统一动态设置。YY 因必须绕开会改写字段名的 `HttpClient`，当前固定使用国内直连传输。
9. 旧的无边界 `BufferParser` 已退出 YY 调用路径；YY 二进制编码和解码统一由 `yy_protocol.dart` 管理。为兼容仓库完整性审计，旧文件暂时保留但没有任何生产代码引用。
10. YY 专用传输严格校验 101、`Connection/Upgrade`、`Sec-WebSocket-Accept` 与协商子协议；单帧或分片消息上限为 16 MiB，异常帧以协议错误关闭。
11. 频道加入负载固定回归 `2="0"/3="1"`、路由尾标记 `0xff787878` 和“路由先于 appid 订阅”的 `3.2.10` 顺序，避免再次出现服务器静默丢包。

## 确定性测试

`test/yy_protocol_test.dart` 覆盖：

- 当前 single-channel WebSocket 地址及 `appid/version/uuid` 查询身份；
- 官方 10 字节小端包头；
- 匿名 UDB → AP → 频道路由 → 广播组的完整顺序；
- 路由 payload 的匿名加入属性、header service 名称、section length 与结尾标记；
- 正确房间聊天与跨房间过滤；
- 单个 WebSocket 消息中的多个协议包；
- 截断帧不从 socket 回调抛出；
- 加入错误房间时失败且不进入 ready。

`test/yy_web_socket_channel_test.dart` 另覆盖：

- 握手输出必须保留 `Sec-WebSocket-Key` 与 `Sec-WebSocket-Version` 的字段名写法；
- 本地原始 socket 完成 101 upgrade 后，二进制帧能进入上层通道；
- 错误的 `Sec-WebSocket-Accept` 被拒绝。

单元测试只证明本地协议状态机和边界行为。Android 网络实机必须在共享设备 `purelive` lane 内，以当前在线 YY 房间验证：播放器有画面、录制文件增长且含 H264/AAC、弹幕 ready、退出后进程和临时录制状态清理。真实聊天另作为观测证据：已知活跃房间使用 `-RequireLiveDanmaku` 强制至少一条；普通随机房间若官方网页同期也没有 appid `31` 聊天，则记录为“本轮未观测”，不把安静房间误判为协议失败。

2026-09-24 升级版 `31a3c964` 已保留数据安装在 K90 Pro，未切换其他应用前台时重跑只读网络探测（`local-artifacts/diagnostics/android-yy-network-20260924T094636544/summary.json`）：六个 YY 主机的 TCP 443 均可达，系统 HTTP 代理与 Private DNS 均未设置；`h5-sinchl.yy.com` 证书校验通过，标准 WebSocket Upgrade 与三个边缘 IPv4 地址均返回 HTTP 101。探针在升级后持续等待消息到 12 秒而退出 28，不是握手失败。该结果只排除本轮设备到 YY 边缘的基础网络阻断，仍需应用内播放、弹幕 ready、聊天和录制链路验收。
