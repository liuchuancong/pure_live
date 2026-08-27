# Pure Live v3.0.13 十个平台录制审计

审计日期：2026-08-27

审计范围：哔哩哔哩、斗鱼、虎牙、抖音、快手、网易 CC、Twitch、SOOP、YY、IPTV/自定义源的“房间状态 → 画质 → 线路/URL → 请求头 → FFmpeg → 分片/合并”完整路径。

问题来源：`fork-regression` 与 `upstream-existing` 的组合。本轮没有合并上游，也没有操作手机；修复建立在当前维护分支源码、确定性回归和公开接口探测之上。

## 1. 根本原因

### 1.1 Android 首次录制初始化被错误延后

上游曾明确把 FFmpegKit 初始化放在应用启动阶段，否则移动端首次录制可能直接出现 I/O 错误。维护分支为降低启动开销，把初始化移动到首帧之后再延迟两秒，结果用户在这段窗口内点击录制时，原生库、文件系统和 FFmpeg session 尚未就绪。

v3.0.13 在 Android/iOS 完成设置与服务注册后立即启动**非阻塞、幂等**预热；录制服务本身仍等待同一个 Future。Windows 等桌面平台保留首帧后的延迟预热，避免加重桌面启动关键路径。

### 1.2 UI 房间查询不等于录制房间查询

多个平台的普通 `getRoomDetail` 为了让已挂载播放器保留旧标题/封面，会把网络、解码或字段结构错误转换为一个“看起来已下播”的占位房间。旧录制器直接复用这条 UI 路径，于是第一次无效状态在**获取房间详情**阶段产生：临时接口失败被当成权威下播，后续画质、线路、URL 与 FFmpeg 根本没有执行。

v3.0.13 新增 `LiveSiteRecordRoomResolver`：

- 网络与响应结构错误必须向上抛出，进入录制器的有界重试；
- 只有平台明确返回下播/封禁时才形成不可重试状态；
- 返回对象必须保留解析画质和签名 URL 所需的完整播放字段；
- 首页卡片的缓存状态不再阻止用户明确发出的“立即录制”操作。

### 1.3 FFmpeg 命令被二次解析

旧代码先把参数拼成类似 shell 的字符串，再交给 Android FFmpegKit 解析。签名 URL 中的 `&`、请求头中的 CRLF、Cookie，以及带空格的存储路径都可能被重新切分或转义，表现为某个平台或某个目录随机“录制失败”。

新实现通过 FFmpegKit 的参数列表接口传递原始 `List<String>`。URL、请求头块和输出路径各占一个原子参数；字符串形式仅用于脱敏日志与测试展示。

### 1.4 失败没有可见分层

旧任务页只显示“失败”，无法区分房间状态、画质、CDN、网络、FFmpeg 启动和分片合并。本轮为持久化任务增加脱敏后的 `lastErrorStage/lastError`，并在任务卡中显示最近失败阶段；完整 URL、Cookie、Authorization、token、sign、auth、key、wsSecret、txSecret 不写入持久化数据。

## 2. 十个平台逐项审查

| 平台 | 严格房间与状态 | 画质和 URL | 录制请求头/特殊约束 | 本轮处置 |
| --- | --- | --- | --- | --- |
| 哔哩哔哩 | 严格读取官方房间信息，兼容数字/字符串 `live_status` | 使用规范房间号请求 playinfo，按 qn 选择并回读实际 `current_qn` | 复用播放端 UA、Referer、Origin 与可选 Cookie | 增加严格录制入口；元数据错误不再伪装下播 |
| 斗鱼 | 严格读取 `betard`，兼容字符串/数字 `show_status` 与 `videoLoop` | 每个 rate、CDN 都重新执行签名与 `getH5PlayV1` | 保留 DID、Referer、UA；不缓存过期签名 URL | 修复用户报告的首阶段误判与参数二次解析 |
| 虎牙 | 严格读取 `profileRoom`；只把 `OFF/OFFLINE/CLOSED` 视为明确下播 | 保留 `HuyaUrlDataModel`、线路和真实 bitrate，源流正确移除 ratio | 复用虎牙 UA、Referer 与 Cookie | 未知/缺字段响应进入重试，不再回退当前播放器房间 |
| 抖音 | API 与 HTML 两条解析路径均保留完整 `stream_url` | SDK key 对应 FLV/HLS；新旧档位和真实 URL 去重逻辑沿用 v3.0.12 | 保留 Cookie、Referer、Origin、UA | 增加严格录制能力并兼容字符串状态值 |
| 快手 | 启动会话后严格解析房间页；`isLiving` 兼容 bool/数字/字符串 | 保留 adaptation 与多 CDN；仅在匹配回放卡确有播放 URL 时回退 | 复用网页会话 Cookie、Referer、UA | 防止无播放数据的旧卡片被误当作可录制回放 |
| 网易 CC | 严格读取主播/频道信息，兼容字符串/数字 status | 保留 `quickplay` 与各档 stream URL | 使用 CC 播放端请求头 | 增加严格入口；空列表与字段漂移作为错误处理 |
| Twitch | 严格执行 GQL 房间查询 | access token + master playlist variants，源流 `chunked` 优先 | 使用 Twitch Client-ID、Origin、Referer、UA | 录制入口复用完整 GQL 数据，不使用卡片简化结果 |
| SOOP | 严格读取 player API；兼容字符串/数字 RESULT；区分下播与封禁 | 保留 preset、CDN、bno/rmd，并按选项生成 AID | 使用 SOOP Origin、Referer、UA | URL 签名错误向上抛出，不再静默返回空列表 |
| YY | 严格读取房间详情，兼容字符串/数字 resultCode | 保留真实 gear；匿名 StreamManager 失败时使用真实移动 HLS 档位 | 使用 YY 移动端 UA/Referer | 增加严格入口，响应错误进入有界重试 |
| IPTV/自定义源 | 本地数据库记录是权威房间数据 | 使用用户提供的单一 URL，不制造不存在的多码率 | 保留自定义 UA 与 HTTP/RTSP/RTMP/SRT/UDP/RTP/file 协议 | 增加严格入口与 SRT 录制协议白名单 |

## 3. 通用录制修复

- 用户点击“立即录制”只产生一次调度意图；监控任务仍保持等待开播语义。
- 每次重试重新获取严格房间数据、画质和签名 URL，并轮换 CDN；403/404 返回上层刷新，5xx/网络错误由 FFmpeg 有限重连。
- HTTP/HTTPS、RTSP、UDP/RTP、RTMP/SRT 分别使用适用的超时与重连参数；音频或视频临时缺轨时采用可选映射。
- Android 最低 API 对齐当前 FFmpegKit 依赖的 API 26，避免在原生录制库本身不支持的系统版本上生成可安装但录制必失败的包。
- FFmpeg 启动、结束和错误仍使用 session 代次隔离；分片、原子合并、活跃目录保护沿用 v3.0.12 的生命周期修复。

## 4. 回归与证据边界

确定性回归覆盖：十个平台严格录制能力、UI 离线回退隔离、临时元数据失败可重试、明确下播不可重试、用户立即录制意图、FFmpeg 原始参数向量、请求头/URL/空格路径完整性、Android/桌面初始化策略、错误脱敏与任务 schema 迁移。

公开接口探测覆盖九个网络平台的匿名房间/画质/播放 URL 合同，并对 Bilibili、斗鱼、虎牙、抖音、快手、CC、Twitch、SOOP、YY 执行平台专用探针；IPTV 依赖用户自己的本地源。公开探测不等于付费、登录、地区限制、主播专属 CDN 或任意用户 IPTV 源均已运行采样。

正式发布分别保存完整静态分析、全量 Flutter 测试、接口探测、仓库审计、Android arm64 APK 内容、ABI、版本、关键原生库、正式证书和 SHA-256 证据。本轮未连接或操作用户手机，真机行为由用户安装后补充验证。
