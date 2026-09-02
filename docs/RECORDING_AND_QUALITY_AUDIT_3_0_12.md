# Pure Live v3.0.12 录制与画质审计

审计日期：2026-08-27

基线：`wzgrx/pure_live@fd763c750fa55917e00c7f5b350df00a3bb5f805`

问题来源：`upstream-existing` 与 `fork-regression` 的组合。旧录制模块把平台画质显示名、请求 ID、URL 列表和 FFmpeg 生命周期混在一起；部分维护分支修复只覆盖播放器，没有同步录制器。

## 1. 第一处错误状态与统一修复

1. **画质身份错误**：平台显示名曾被当成请求参数。最明显的是 SOOP；中文化后若仍把“原画”发给只接受 `original` 的接口，按钮必然失效。现在所有适配器使用 `LivePlayQuality.selectionId` 作为稳定请求 ID，显示名只负责 UI。
2. **抖音旧/新 SDK 混用**：旧键 `ORIGION/FULL_HD1/HD1/SD2/SD1` 与新键 `origin/uhd/hd/sd/ld/md` 并存。旧实现漏掉 `MD`，并把 `SD1/SD2` 的中文含义与顺序写反。现在按平台语义排序，而不是按会波动的瞬时 `v_bit_rate` 排序；相同 URL 的别名只显示一次。
3. **画质已选但未真正生效**：Bilibili 匿名请求可能返回低于请求值的 `current_qn`。播放器与录制器现在读取服务端实际值；其他直接 URL 平台以被选中的 URL 集合作为实际结果。切换后 URL 完全相同时，不再伪装成成功切换。
4. **录制 URL 过期与线路固化**：录制器不再长期复用一次解析出的签名 URL。失败后重新读取房间与质量信息，并从上次失败线路的下一条 CDN 开始。
5. **FFmpeg 退出与任务状态串线**：旧回调缺少 session 代次，旧任务的迟到回调可能覆盖新任务。现在每个事件携带 session ID，完成、错误、停止、合并和重连均经过同一生命周期栅栏。
6. **文件完整性错误**：旧实现可能覆盖同秒文件、把上次失败分片混进新尝试、合并失败仍删除 TS、缓存清理误删正在写入的目录。现在使用毫秒级尝试前缀、唯一输出名、`.partial` 原子提交、成功后删除源片段，并用引用计数保护活跃目录。
7. **敏感和迟到状态**：旧任务会把带 token 的当前 CDN URL 落盘，任务删除后的迟到回调也可能保留 session 状态。现在签名 URL 只存于内存，新 started 事件权威替换旧代次，终态和删除路径均清理 session。

## 2. 平台画质与录制矩阵

| 平台 | 画质来源与排序 | 实际切换/录制参数 | 显示规则 | 状态与限制 |
| --- | --- | --- | --- | --- |
| 哔哩哔哩 | `accept_qn/current_qn`，按 qn 降序 | 请求 qn；回读 `current_qn` | 服务器中文优先，缺失时用 qn 标准表 | 匿名账号可能被服务端降档，UI/录制会显示实际档位 |
| 斗鱼 | `multirates` 的服务端顺序；`rate` 是不透明代码 | 每个 rate、每条 CDN 都重新签名请求 | 平台中文名优先，英文通用名中文化 | 不再把 rate 数字误当码率排序 |
| 虎牙 | 服务器 bitrate 列表，`0` 表示源流 | 转码档写入/替换 `ratio`；源流移除 `ratio` | 平台名优先，源码英文名中文化 | 不再虚构服务器未提供的画质 |
| 抖音 | SDK key/level 语义顺序；码率仅作元数据 | 每档直接使用对应 FLV/HLS URL | 兼容旧键与新键，已补 `MD→流畅` | 同源别名去重；主播只提供一档时只显示一档 |
| 快手 | adaptation `level`，缺失时用 bitrate | 每档对应 AVC URL 集；无 AVC 时回退 HEVC | 平台名优先，通用英文中文化 | 同画质合并多 CDN，不重复显示 H.264/H.265 两套按钮 |
| 网易 CC | 档位 key 语义优先，vbr 只作档内参考 | 每档对应该档 CDN URL 集 | 平台反射表优先 | 源流缺 vbr 仍排第一；查询后缀与直连 URL 均正确拼接 |
| Twitch | `chunked` 源流优先，其余按 HLS `BANDWIDTH/RESOLUTION/FRAME-RATE` | 每档对应 master playlist 的 variant URI | `1080P60（原画）` 等 | 源流缺 RESOLUTION 仍显示“原画”；相对 URI 正确解析 |
| SOOP | `viewpreset.name` 语义优先，bps 作档内参考 | 请求始终使用原始 preset ID | `original/hd/sd/low` 中文化 | 原画缺 bps 不降档；中文显示名与接口 ID 完全分离 |
| YY | StreamManager gear + rate；失败走移动 HLS | gear 原值或移动 HLS rate | 平台名优先，重名附 gear | 匿名 StreamManager 被拒时只展示真实可用的移动 HLS 档位 |
| IPTV/自定义源 | 用户提供单一 URL | 原协议与自定义 UA | 固定“默认” | 没有平台多码率描述，不制造画质按钮 |

## 3. 录制协议与头部

- Bilibili、斗鱼、虎牙、抖音、快手、CC、Twitch、SOOP、YY 共用播放器已验证的 Origin、Referer、User-Agent 与可选 Cookie 解析器；请求头会移除换行和非法字段名。
- HTTP/HTTPS 只在网络错误和 5xx 时由 FFmpeg 内部有限重连；403/404 交还上层刷新签名 URL。RTSP 使用 TCP，UDP/RTP 使用有界 FIFO，IPTV 保留用户协议。
- 录制映射只选择音视频轨，允许临时缺少视频或音频的直播；不把字幕、附件和数据流写入 TS。
- FFmpeg 日志中的完整流地址、token、sign、auth、key、Cookie 与 Authorization 在进入应用日志前脱敏。

## 4. 确定性回归

- 每个平台的质量解析、排序、稳定 ID、URL 归属与重复档位处理。
- 抖音旧/新 SDK 名称、`SD1/SD2` 正确语义、`MD`、同 URL 别名、源流码率低于转码流时的排序。
- Bilibili 服务端降档回读；斗鱼不透明 rate；虎牙 ratio 替换/移除；SOOP 本地化后仍发送原 preset。
- 播放与录制请求头一致性；FFmpeg HTTP/RTSP/UDP 参数和头部注入。
- session 迟到回调、取消令牌、有限退避、旧任务迁移、活跃目录保护、ffconcat 路径转义与原子 MP4 提交。

## 5. 外部证据与剩余边界

- 抖音开放平台建议多清晰度按钮采用“极速、流畅、清晰、高清、超清、4K”，并以真实 URL 切换，而不是只改变标签：<https://developer.open-douyin.com/docs/resource/zh-CN/mini-app/develop/tutorial/basic-ability/video-component>
- Twitch 官方把 `chunked` 定义为源流，并要求 `setQuality` 使用 `getQualities` 返回的值：<https://dev.twitch.tv/docs/embed/video-and-clips/>
- FFmpeg 协议、concat 与转义行为以官方文档为准：<https://ffmpeg.org/ffmpeg-protocols.html>、<https://ffmpeg.org/ffmpeg-formats.html>、<https://ffmpeg.org/ffmpeg-utils.html>

公开接口探测只证明当前匿名元数据合同仍可访问，不等于每个账号、付费/地区限制房间、所有 CDN 或用户 IPTV 源均完成运行采样。正式交付会分别记录静态分析、自动化测试、公开接口探测、Android arm64 构建与签名证据；本轮不操作手机。
