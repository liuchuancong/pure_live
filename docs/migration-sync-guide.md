# pure_live 迁移同步文档

> 写给手动同步的人。目标：把旧仓 `C:\Users\m1779\Downloads\pure_live-master\pure_live-master`
> 的整体逻辑照搬进本仓（`F:\projects\pure_live`，分支 v2），先求全、后统一修。

## 一、当前策略（2026-10 确立）

1. **整体照搬，不求逐站实测**：旧仓有什么方法就移植什么，先归档全部逻辑。
2. **不写测试、不跑实测探针**；唯一硬门槛是 `dart format . && dart analyze` 零问题。
3. **统一修改在后**：全部归档后，按主题做统一修复（数字字符串、信封形状、限制映射等，见 §7）。
4. 每个独立单元一次提交并 `git push origin v2`；生成物（`*.freezed.dart`、`*.g.dart`）不入 git。
5. 不碰用户的 3.x 安装和数据；真实 Cookie/账号/签名密钥不进仓库。

## 二、两边目录对照

| 内容 | 旧仓路径 | 新仓路径 |
|---|---|---|
| 站点 API/解析 | `packages/live_core/lib/src/sites/<site>/` | `packages/live_sites/lib/src/platforms/<site>/` |
| 弹幕 | `packages/live_danmaku/lib/src/sites/<site>.dart` | `.../platforms/<site>/danmaku/<site>_danmaku.dart` + `<site>_session.dart` |
| 公共工具 | `live_core` 内散落 | `live_sites/lib/src/common/`（SiteText/SiteCounts/SiteJson/SiteHeaders/SiteUrls） |
| 合同 | `LiveSite` 及各种接口 | `live_sites/lib/src/contracts/`（site_capability.dart、directory_capabilities.dart、live_site.dart） |
| 模型 | `live_core/lib/src/live_room.dart` 等 | `live_sites/lib/src/models/`（Freezed+json_serializable+equatable） |
| IPTV | `packages/live_iptv/` | 同名包，结构已重构（catchup/guide/import/library/playlist） |

**旧框架弹幕类不复用**：`DanmakuSocketConnection / DanmakuRun / DanmakuSocketSession /
DanmakuSocketPolicy / connectExactWebSocketViaRoute` 都是旧 live_danmaku 的 I/O 框架。
新树已确立更简单的模式（见 §4），照搬时把「协议解码」搬进 `<site>_danmaku.dart`，
把「连接生命周期」按新模式重写进 `<site>_session.dart`。

## 三、能力矩阵（截至本文件提交时）

已具备目录（LiveAreaCatalog）的站点 25 个：acfun、cc、chzzk、douyu、huya、missevan、
pandalive、showroom、twitcasting、yy、kugoulive、jdlive、inke、liveme、looklive、
niconico、fc2live、kilakila、bigo、soop、steambroadcast、sixroom、iptv、kuaishou(*)、
baidulive(*)。（* 号 = 仅有目录或部分能力，以 `git log --oneline` 各站提交为准。）

目录缺失（旧仓也没有目录接口，属正常）：tiktok 等。

**搜索（LiveSearchCapability）缺失**：acfun（BigPipe HTML 片段）、sixroom、missevan、
showroom（快照本地过滤）、kugoulive（jsonp）、twitcasting（搜索页）、jdlive（本地过滤）、
looklive（本地）、inke（昵称过滤）、kilakila（HTML 页）、liveme、pandalive（live/index + bj_list）。
douyin / weibo / xiaohongshu 的目录+搜索都在（需签名/cookie，见 §6）。

**弹幕（LiveDanmakuCapability）已完成**：bilibili、kuaishou、showroom、twitcasting、chzzk。
**待搬 24 个**（旧文件行数 ≈ 工作量）：

| 站点 | 旧行数 | 协议要点 |
|---|---|---|
| soop | 364 | 自定义二进制帧（ESC TAB + 服务号），§5 已有完整笔记，**建议第一个做** |
| douyin | 416 | 依赖 douyin_sign（a_bogus/msToken），protobuf over WS |
| kick | 475 | WS JSON |
| huya | 452 | WS + Tars 二进制（重） |
| douyu | 478 | TCP + STT 二进制（重，dart:io Socket） |
| jdlive | 518 | WS JSON |
| steambroadcast | 557 | getbroadcastmpd 轮询 |
| picarto | 652 | WS JSON |
| pandalive | 670 | WS |
| fc2live | 667 | control_token WS（token ~1 分钟过期） |
| baidulive | 628 | WS |
| twitch | 734 | IRC over WS（文本） |
| kilakila | 717 | WS |
| sixroom | 771 | WS |
| bigo | 876 | WS |
| acfun | 956 | protobuf over WS + acSecurity 密钥派生 + tickets（来自房间详情） |
| looklive | 996 | 云信（yunxin） |
| missevan | 916 | brotli 压缩帧 |
| niconico | 1055 | relive 座位 WebSocket（seat） |
| youtube | 1075 | 依赖签名 |
| kugoulive | 1296 | 签名 |
| seventeenlive | 1363 | 旧仓有 `sites/seventeenlive/`，**新树连站点适配器都没有**，需一并照搬 |
| yy | 743 + `yy/` 目录 | WS + 二进制（重） |
| bilibili/huya 超级留言 | — | 模型已备好 `LiveSuperChat`（chzzk 已用），照搬即可 |

**IPTV 待办**：节目单映射串联 —— `rebuildMappings`（guide/guide_matcher.dart）已就绪，
但需要先定「频道 ↔ 播放列表归属」再接入 `importResult` / `applyMappings`。

## 四、弹幕移植配方（新模式）

新树的既有范例：`bilibili/danmaku/*`、`kuaishou/danmaku/*`、`showroom/danmaku/*`、
`twitcasting/danmaku/*`、`chzzk/danmaku/*`（chzzk 是从旧框架完整照搬的最新范例）。

1. **`<site>_danmaku.dart`（纯协议，无 I/O）**：常量（端点、心跳周期、服务号/命令号）
   + `decode(...)` 把一帧解析成 `List<LiveMessage>`。旧文件的 Protocol 部分 near-1:1 搬。
2. **`<site>_session.dart`（生命周期）**：`implements LiveDanmakuSession`
   （`Stream<LiveMessage> get messages` + `Future<void> close()`，close 幂等）。
   模式：`StreamController.broadcast` + `dart:io` WebSocket + 心跳 Timer；
   onDone/onError → 加错误并关流（简单版，如 showroom），或像 chzzk 那样内部重连。
   **重连策略归会话、重试策略归调用方**——两条重试策略会打架。
3. **站点接线**：site 类 `implements` 加 `LiveDanmakuCapability`，实现：
   ```dart
   @override
   Future<LiveDanmakuSession> connect(LiveRoom room) {
     guardRoom(room);
     return <Site>DanmakuSession.connect(...); // 参数来自 room.data 运行时缓存
   }
   ```
4. **房间详情必须带齐弹幕初始化参数**（进 `room.data`，不进 JSON）。若新站解析器
   还没存（如 soop 的 CHDOMAIN/CHPT/CHATNO），先在 site 解析器的 room()/detail 里补。

### 模型字段对照（旧 → 新，搬解码逻辑时逐项替换）

| 旧（live_core/live_danmaku） | 新（live_sites models） |
|---|---|
| `LiveMessage(messageId: …)` | `LiveMessage(id: …)` |
| `color: LiveMessageColor.white` | `color: 0xFFFFFF`（int；bilibili mapper 有现成例子） |
| `LiveGift(kind:, iconUrl:, free:)` | `LiveGift(name, count, unit, unitPrice, totalValue, combo)`——kind/iconUrl/free 已删 |
| `gift.plainText`（message 字段） | 自己拼，如 `'$name ×$count'` |
| `data: LiveNoticeKind.subscription` | `data: 'subscription'`（字符串即可） |
| `data: LiveNoticeKind.system` | `data: 'system'` |
| `LiveGiftUnit.starBalloon / .other / .cheese` | 新枚举只有 `silver / gold / rmb`；starBalloon→gold、cheese→gold，无价单位把 unitPrice 留 0，注释说明 |
| `data: LiveSuperChatMessage(...)` | `data: LiveSuperChat(message, price, priceText, unit, startTime, endTime)`（live_gift.dart，本次新增） |
| 旧框架 `session.message()/ready()/reconnect()` | 新模式直接 `_messages.add(...)` / 内部状态机 |

## 五、第一个作业：soop 弹幕（已完成勘查，照此写即可）

旧文件：`live_danmaku/lib/src/sites/soop.dart`（364 行）+ 旧
`sites/soop/soop_api.dart` 的 `danmakuArgs()`（613–640 行）。

1. **参数来源**：房间详情 CHANNEL 对象 → `data` 缓存需补 `chatNo`（CHATNO）、
   `chatHost`（CHDOMAIN，缺失时 `chat-<CHIP 十六进制大写>.sooplive.com`）、
   `chatPort`（CHPT）。端点：`wss://<host>:<port+1>/Websocket/<roomId>` 优先，
   回落 `ws://<host>:<port>/Websocket/<roomId>`（TLS 端口可能拒 ClientHello）。
2. **协议**（搬 `SoopDanmakuProtocol` 即可）：
   - 帧 = 若干包；包 = `ESC TAB`(\x1b\x09) + 4 位十进制服务号 + 6 位十进制体长
     + `00` + 体（14 字节头，字段用 \f 分隔，第一段丢弃）。
   - 客户端发文本帧、服务端回二进制帧；子协议 `chat`。
   - 包：登录（服务 1，开连接即发）＝
     `'\x1b\t000100000600\f\f\f16\f'`；心跳（服务 0，20s）＝
     `'\x1b\t000000000100\f'`；进房（服务 2，登录后 200ms）＝
     `'\x1b\t0002' + (utf8len+6).padLeft(6,'0') + '00\f<chatNo>\f\f\f\f\f'`。
   - 解码：服务 5=聊天（字段 1 文本、6 昵称、2 发送者 id，id 去掉 `(n)` 后缀）、
     18/33/105/87=星球气球/转播气球/영상풍선/애드벌룬（gift，字段下标旧文件写死）、
     91/93=订阅/订阅周年（notice，`订阅了频道，已订阅 N 个月`）。
3. **握手头大小写**：该站边缘节点对头大小写敏感（`User-Agent` 而非 `user-agent`），
   旧 `handshakeHeaders()`/`headerName()` 要搬；ws 回落端口不带 Cookie（`plainHeaders()`）。
4. 静默 90s 判死；新会话可先做「无重连、出错即关流」的简单版（showroom 模式）。

## 六、签名/cookie 类站点的处理

- douyin：先照搬 `live_core/lib/src/sites/douyin/douyin_sign.dart`（a_bogus/msToken/visitorId），
  再搬目录（`webcast/web/partition/detail/room/v2`、首页 categoryData）与弹幕。
- youtube / kugoulive / weibo / xiaohongshu：照搬各自的签名/令牌链，逻辑进
  `<site>_parser.dart` 或独立的 `<site>_sign.dart`。
- 这些站照搬后同样**不实测**，标注「归档未验证」即可。

## 七、归档后的统一修复清单（按主题，不按站点）

1. **数字字符串**：站点下发数字常带引号。全库 grep `as num?`，逐个换成
   `SiteCounts.integer(...)`（liveme/bigo/sixroom 已修出过 crash）。
2. **信封形状**：同一站点不同端点可能「扁平」或「包 data」（soop 主列表扁平、
   分类有 `result`；pandalive `live/index` 扁平、`member/bj` 包 data；kilakila
   成功码是 200 不是 0）。归档时如照搬了旧校验就不用改；统一过一遍即可。
3. **限制映射**：`LiveRestriction` 已恢复 3.x 全集（none/needsLogin/paid/
   subscribersOnly/private/appOnly/regionBlocked/password/adult/unplayable，按名字存取）。
   新搬的解析器直接用 3.x 的原语义。
4. **身份**：`LiveRoom` 相等 = platform+roomId（Equatable）；`mergeFrom` 会拒绝
   合并不同身份——解析器不得让应答字段覆盖请求 id（bigo 花名 id 教训）。
5. **`data`/`danmakuData` 运行时缓存**：不进 JSON、不进 `mergeFrom`；
   站点必须能从稳定字段重建。
6. 代码生成：模型改后 `dart run build_runner build`（在仓库根或包内），
   `*.freezed.dart`/`*.g.dart` 不提交。

## 八、例行流程（每个单元）

```bash
cd F:/projects/pure_live
# 写代码（照搬 → 适配 §4 字段对照 → 英文注释 + 全量 doc 注释）
dart run build_runner build   # 仅当改了模型
dart format . && dart analyze # 必须 No issues found!
git add <涉及路径>
git commit -m "feat(live_sites): port the <site> <thing> wholesale"  # 或 chore/fix
git push origin v2
```

不写测试、不写 demo、不新增空接口占位模块；分析器排除 `*.freezed.dart`/`*.g.dart`。

## 九、本文件写下的「半成品」笔记

- soop 弹幕：勘查完成（§5），代码未写。room 解析器 data 缓存需补 chatNo/chatHost/chatPort。
- live_iptv 映射串联：`rebuildMappings` 在 `lib/src/guide/guide_matcher.dart`；
  卡点是 `IptvChannel` 目前没有 playlistId 归属字段，需先加字段或引入关联表。
- acfun 搜索：BigPipe 应答 = JSON 的 `html` 字段是 HTML 片段（`search-up` 卡片、
  `total-num[data-total]` 计数、`empty-page` 标记、`data-up-exposure-log` 元数据、
  `is_on_live` 直播标记），`html` 包已进依赖；旧实现在 `sites/acfun/acfun_api.dart`
  643 行起，含服务页→客户端页翻页状态机（site 389 行起）。
