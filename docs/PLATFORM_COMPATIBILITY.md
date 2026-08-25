# 平台接口与兼容性

本文记录 Pure Live 当前使用的直播接口、数据含义和本地验证方法。平台网页可能随时调整，合并接口改动前应执行一次探测脚本。

## 当前平台能力

| 平台 | 分区来源 | 直播间搜索 | 弹幕 | 卡片指标含义 |
| --- | --- | --- | --- | --- |
| 哔哩哔哩 | 动态读取直播分区接口 | 原生直播间搜索，可返回未开播结果 | 访客模式动态获取 token；先连官方通用网关，再轮换 `host_list` 区域节点；认证失败后刷新凭据 | `online`/心跳为热度，`WATCHED_CHANGE` 为累计看过 |
| 斗鱼 | 动态读取移动端分类接口 | 原生直播间搜索，可返回未开播结果 | WebSocket | 热度 |
| 虎牙 | 网站业务分类与动态游戏列表 | 原生搜索当前直播间 | `wsapi.huya.com` WebSocket，按 `live:<uid>`/`chat:<uid>` 注册房间组并解析批量推送 | 列表/详情/URI 8006 均为热度 |
| 抖音 | 从直播首页动态提取分类 | 带网页签名参数的当前直播搜索 | WebSocket | 顶层/嵌套 `user_count` 为当前在线；`display_value/total_user` 为累计观看，缺少累计值时不再用在线值冒充 |
| 快手 | 网站当前直播频道、动态子分类与推荐回放 | 网页搜索入口 | 当前未接入 | 在线；房间页下播但卡片仍带播放地址时按录播处理 |
| 网易 CC | 动态游戏列表，保留网站顶层入口 | 原生主播/直播间搜索，可返回未开播结果 | 当前未接入 | `webcc_visitor/hot_score/visitor` 为同一热度口径；只有 `vision_visitor/online_num` 为并发人数 |
| Twitch | 网站 GraphQL 标签与目录接口 | 原生频道搜索，可返回未开播频道 | Twitch IRC WebSocket；登录 Cookie 中的 `auth-token`/`login` 用于认证聊天 | `viewersCount` 为并发观看人数 |
| SOOP Live | 官方分类与推荐接口 | 原生搜索当前直播间 | SOOP WebSocket；账号 Cookie 可选 | 推荐/搜索以 `total_view_cnt`（PC + 移动端）为并发人数；分类使用 `view_cnt`；`current_view_cnt` 仅是 PC 端分量 |
| YY Live | 动态读取头部与分类元数据 | 原生直播间/主播搜索，可返回未开播结果 | YY WebSocket | `users` 为平台热度值 |

> “热度”是平台排序/活跃度指标，不等同于唯一在线用户数。界面会按平台字段分别显示“热度”“在线”或“累计观看”，避免把不同含义的数据统一标成在线人数。

搜索页会直接显示当前平台的覆盖范围，并提供“包含未开播”筛选。平台选择栏使用独立水平列表：项目超过屏幕宽度时可横向访问，首尾为硬边界，不使用无对应内容页的 `TabBar` 自动定位。综合排序固定把直播中房间放在前面，再比较当前观看口径、粉丝数和主页平台顺序；“平台优先”直接使用“平台显示设置”的拖动顺序，“观众优先”和“粉丝优先”则调整对应字段的比较次序。粉丝字段只在平台搜索响应明确提供时参与，缺少该字段的结果保留为稳定次序；快手使用网页搜索入口，IPTV 只查找本机导入频道。每个平台单独维护翻页结束状态，空页或重复页会停止继续请求。

“全部”搜索并发请求各原生平台，但按单个平台完成顺序渐进显示，某个平台超过 12 秒会被标记为本轮部分失败，不再阻塞其他结果。搜索页生命周期内复用同一组适配器，Twitch 等游标分页状态不会因每次读取平台列表而丢失。网页继续搜索可从 Bilibili、斗鱼、虎牙、抖音、快手、网易 CC、Twitch、SOOP 和 YY 的直播间链接识别“平台 + 房间号”；搜索/分类页和相似伪装域名会被忽略。

“设置 → 通用 → 观看数据与排行口径”提供两个全局模式和分平台开关：

- **平台热度优先**：按平台列表提供的热度或累计观看显示、降序排序；快手等只公开当前观看人数的平台继续保留“在线”标签。热门页、收藏、搜索与房间选择器共用同一个数值解析和稳定排序器。
- **真实在线人数优先**：抖音、快手、网易 CC、Twitch、SOOP Live 仅在拿到明确并发人数时按在线显示、排序；支持平台尚未取得列表值或房间消息时明确显示“待刷新”，不再回退为一个被误标或参与在线排行的热度值。
- 哔哩哔哩的列表 `online` 与弹幕心跳、斗鱼公开 `ol/hot`、虎牙 `totalCount/userCount/iAttendeeCount` 都是热度，均不换写成真实人数。由此避免把几百万热度显示为几百万人同时在线。
- 切换全局口径或分平台开关后，收藏与搜索现有结果会立即重新排序，热门页会刷新当前平台的候选池后重排；在线模式把已启用且支持并发人数的平台排在仅提供热度/累计值的平台之前。网易 CC 在线模式一次取 100 个热度候选后按并发人数排序，避免只在每 20 张卡片内部重排。

## 画质与播放线路契约

画质按钮不再只代表一段显示文字。每项必须同时具备稳定平台标识、请求参数、可播放线路和（平台支持时）服务端实际生效值。公共播放器仅在新媒体源成功打开后提交选中状态；解析失败、播放器拒绝、旧请求迟到、服务端降级或两个按钮最终得到同一组线路时，保留旧画面和旧选中项。

| 平台 | 稳定画质标识 | 切流校验 |
| --- | --- | --- |
| 哔哩哔哩 | `qn` | 以响应 `current_qn` 回写实际画质；访客被降级时不再显示成已切到原画 |
| 斗鱼 | `rate` | `rate` 是请求代码而非码率，严格保留接口 `multirates` 顺序；每个 CDN 使用同一目标 `rate` 重新取流 |
| 虎牙 | `iBitRate` | 切换时总是替换旧 `ratio`；原画删除 `ratio`，转码写入目标码率；不再虚构平台未返回的高清选项 |
| 抖音 | `sdk_key` | `stream_data`、FLV 和 HLS 按键名关联，禁止依赖 JSON Map 插入顺序 |
| 快手 | 清晰度名称 + 等级 | 同清晰度多 CDN 合并为线路，AVC 优先、HEVC 仅作回退 |
| 网易 CC | resolution key | 清晰度 key 与自身 CDN Map 绑定，优先线路在前、其他有效线路继续保留 |
| Twitch | HLS variant attributes | `EXT-X-STREAM-INF` 与紧随其后的 URI 成对解析，支持相对 URL；并发多画面不共享可变 URL 列表 |
| SOOP Live | preset name | 过滤 `auto` 和重复 preset，按平台 `bps` 排序，请求沿用同一 preset 名称 |
| YY Live | gear | 同名但不同 gear 保持独立并编号，播放响应只接收有效 HTTP(S) CDN 地址 |
| IPTV | `default` | 单一导入源，空地址不生成伪画质 |

横屏“清晰度与播放线路”面板根据画质数、线路数和可用高度计算整体尺寸。一个画质/一条线路时收紧面板；常见四画质使用均衡 `2×2`；项目多时只让按钮网格滚动，不用固定比例制造空白。按钮区域是主要视觉，标题、留白和重复的当前值标签均已压缩。

## 本地接口探测

```powershell
python tool/interface_probe.py
```

The release probe runs 40 checks across categories, recommendations, searches, room metadata, danmaku discovery and playback contracts. Its existing recommendation checks now also validate the audience-field contract for Douyu `ol`, Huya `totalCount`, Douyin `user_count`, Kuaishou `watchingCount`, CC heat/concurrent pairs, Twitch `viewersCount`, SOOP PC/mobile totals and YY `users`. Douyu additionally executes signing, H5 metadata retrieval, CDN selection and a real FLV-header request with player-equivalent headers; Bilibili, Huya and CC verify current quality/line descriptors; YY verifies categories, both search types, room status and playback lines. Deterministic parser tests separately cover the display/ranking semantics and platform playback mappings.

2026-08-17 再次完成哔哩哔哩访客 WebSocket 实连：`uid=0` 会话连续取得当前房间弹幕，但平台把 legacy 与 rich user 两处昵称和 UID 一并脱敏。客户端会优先读取平台 rich user 的完整昵称；访客数据仍为脱敏值时在弹幕列表提示来源。公开直播的弹幕接收继续使用访客会话，登录账号用于完整昵称、发送平台弹幕、关注、会员清晰度和其他账号功能。

虎牙协议变更后可额外运行 `python .\tool\huya_danmaku_probe.py`，动态选择当前直播间并验证 WebSocket 注册、心跳和真实推送接收；当前客户端使用网页同款房间组注册和批量推送格式。脚本仅使用 Python 标准库，此网络回归不并入默认单元测试，避免平台限流导致本地门禁波动。

## 回归重点

1. 进入各平台首页和任意二级分区，下拉刷新后仍可显示封面。
2. 使用“全部”搜索验证跨平台去重、直播优先排序和单平台故障提示。
3. 哔哩哔哩直播间需在认证回应后显示“弹幕服务器已连接”，断线时自动轮换节点。
4. 平台接口返回的图片若为 `//host/path`，客户端会统一补全 HTTPS；设置页可清空图片缓存并强制刷新当前封面。
5. 接口响应字段变动时，先保留原始失败信息，再更新对应 `lib/core/site/*_site.dart` 与本文件。

## 本地构建策略

- Android：默认仅构建 `arm64-v8a`，适用于主流 64 位手机。
- Windows：仅构建 `windows-x64`。
- Linux：构建 `linux-x64` 便携归档。
- macOS：构建包含 x86_64 与 arm64 的 universal 应用归档。
- iOS：执行 `--no-codesign` 设备编译并归档 `.app`，随后在证书环境签名封装。
- GitHub Actions：保留五平台手动构建入口；Android/Windows 日常验证优先使用 `tool/build_local_release.ps1`，减少远程构建用量。
