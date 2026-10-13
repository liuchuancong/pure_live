# Live Sites Architecture（v2 重构版）

> **Package**: `live_sites` — 直播平台统一接入层
> **本文地位**: 架构基准。目录结构、分层、契约、流程以本文为准；**字段与命名以 [MODELS.md](MODELS.md) 为准**（字段字典先行，两文档冲突时先改文档再改代码）；**目录实例与代码骨架以 [EXAMPLES.md](EXAMPLES.md) 为准**（新建文件照抄模板）。
> **源码语言规则**: 源码注释与 API 文档一律英文；本文档与 MODELS.md 为维护者参考，使用中文。

---

## 0. 相对 v1 的关键变更（为什么重构）

| # | v1 的问题 | v2 的决定 |
|---|---|---|
| 1 | `models/` 一类型一目录时条目散落、枚举混在属主文件里难定位；另一极端（全扁平成少数大文件）又让单类型不可独立生成/测试 | **一类型一目录**（`live_room/live_room.{dart,freezed.dart,g.dart}`）；**枚举独立 `models/enums/` 单文件**；**converter 独立 `models/converters/` 单文件**；每领域一个 barrel 文件做聚合出口（§3、§9.1a） |
| 2 | `LiveRoom` 双重结构：8 个子对象 + 30 参数扁平构造器 + 40 个委托 getter，加一个字段改 7 处 | **子对象是唯一形态**；扁平访问器仅迁移期保留并 `@Deprecated`（§6） |
| 3 | 观众数是 `String`，`'0'`/`''`/`'null'` 三种语义 | 数量一律 `int?`，null=未知；解析/格式化在边界（MODELS.md §1.3） |
| 4 | 平台特例写在共享模型里（Huya 热度特判、B 站瞬时掉 1、平台能力表） | **共享模型禁止出现平台名的 switch**，quirk 全部下沉平台适配器（§7.4） |
| 5 | 16 个孤儿生成文件、手写/Freezed 混用无策略 | 明确代码生成判定规则 + 禁止孤儿生成物（§9） |
| 6 | 字段无字典，新增字段无出处 | MODELS.md 为唯一字段字典，新字段必须标注平台出处（API+键名） |
| 7 | 零平台实现、零测试即定稿模型 | 先迁移代表平台验证契约，再全量铺开（§13 迁移计划） |
| 8 | 文末粘贴的 fpdart 讨论稿（重复、过时） | 收敛为 §5 错误处理规范 |

保留 v1 的正确决定：能力发现式 `LiveSite`、`Either` 错误模型、manifest/lifecycle/registry、平台实现同包隔离。

---

## 1. 定位与边界

### 1.1 职责

- 平台身份（manifest）、生命周期、能力发现与注册。
- 房间/主播/分区/搜索/热门/推荐等数据获取。
- 播放线路与清晰度解析（不含播放引擎）。
- 弹幕协议适配（协议级重连归本包，播放恢复策略不归本包）。
- 平台私有 HTTP、签名、解析、协议实现。
- 共享领域模型与错误、分页契约。

### 1.2 非职责

- UI、路由、主题、状态管理、播放器引擎与选核、收藏/历史的业务逻辑、动态插件加载。（`apps/` 与 `live_playback` 等包的领地）

### 1.3 依赖方向

```
apps/pure_live ──► live_sites ──► live_net（HTTP）
                      │
                      ▲
              live_iptv（仅实现 IPTV 站点的 channel source，经公共入口引用，禁止深入 src/）
```

- 本包**不得**依赖 `apps/*`、`live_playback`、`live_ui_kit`。
- 跨包复用模型时，模型放在最低 appropriate 包；不得为借一个类引入反向依赖。

---

## 2. 分层总览

```
┌─────────────────────────────────────────────────────────┐
│ core/        LiveSite · Manifest · Context · RuntimeInfo │  契约层：接口与身份
│              LiveSiteRegistry · LiveSiteError            │
├─────────────────────────────────────────────────────────┤
│ capabilities/ 11 个可选能力接口（Either 边界）            │  能力层：功能契约
├─────────────────────────────────────────────────────────┤
│ models/       一类型一目录 + enums/ + converters/        │  模型层：纯数据
│               每领域一个 barrel 聚合出口                  │
├─────────────────────────────────────────────────────────┤
│ platforms/<id>/  api · parsers · capabilities · fixtures │  平台层：全部平台特例
├─────────────────────────────────────────────────────────┤
│ common/       归一化工具（text/headers/counts/ids/urls） │  共享工具：≥2 平台证实
│               编解码（brotli/tars/protobuf）             │  门槛：先留平台内，复用
│               观众数解析、礼物连击、清晰度标签            │  证实后才上提
└─────────────────────────────────────────────────────────┘
```

**依赖规则**：`core ← capabilities ← models`；`platforms` 可引用以上全部；`models` 不引用任何层；`common` 不引用 `platforms`。

---

## 3. 目录结构（目标态）

> 实例化展开（douyu 全展开 + 各文件代码骨架）见 [EXAMPLES.md](EXAMPLES.md)。

```
packages/live_sites/
├── ARCHITECTURE.md / MODELS.md / EXAMPLES.md / README.md / CHANGELOG.md
├── pubspec.yaml / analysis_options.yaml
├── lib/
│   ├── live_sites.dart              # 唯一公共出口（§10）
│   └── src/
│       ├── core/                     # 契约层（现状保留）
│       │   ├── live_site.dart
│       │   ├── live_site_manifest.dart
│       │   ├── live_site_context.dart
│       │   ├── live_site_runtime_info.dart
│       │   ├── live_site_registry.dart
│       │   └── live_site_error.dart  # sealed 错误族（site_error/ 子目录并入）
│       ├── capabilities/             # 11 个能力接口（现状保留）
│       ├── models/                   # ★ 一类型一目录 + enums + converters + 领域 barrel
│       │   ├── room/
│       │   │   ├── live_room/{live_room.dart, live_room.freezed.dart, live_room.g.dart}
│       │   │   ├── live_room_ref/{live_room_ref.dart, live_room_ref.freezed.dart}
│       │   │   ├── room_broadcast/{room_broadcast.dart, room_broadcast.freezed.dart}
│       │   │   ├── room_content/{room_content.dart, room_content.freezed.dart}
│       │   │   ├── room_links/{room_links.dart, room_links.freezed.dart}
│       │   │   ├── room_audience/{room_audience.dart, room_audience.freezed.dart}
│       │   │   ├── room_local/{room_local.dart, room_local.freezed.dart}
│       │   │   ├── room_runtime/{room_runtime.dart, room_runtime.freezed.dart}
│       │   │   └── room.dart                      # barrel：export 本领域全部
│       │   ├── anchor/
│       │   │   ├── live_anchor/{live_anchor.dart, live_anchor.freezed.dart}
│       │   │   └── anchor.dart
│       │   ├── area/
│       │   │   ├── live_area/{live_area.dart, live_area.freezed.dart}
│       │   │   └── area.dart
│       │   ├── audience/
│       │   │   ├── live_audience_update/{live_audience_update.dart, live_audience_update.freezed.dart}
│       │   │   └── audience.dart
│       │   ├── guide/
│       │   │   ├── room_guide/{room_guide.dart, room_guide.freezed.dart}
│       │   │   ├── guide_catch_up/{guide_catch_up.dart, guide_catch_up.freezed.dart}
│       │   │   └── guide.dart
│       │   ├── message/
│       │   │   ├── live_message/{live_message.dart, live_message.freezed.dart}
│       │   │   ├── message_sender/{message_sender.dart, message_sender.freezed.dart}
│       │   │   ├── live_badge/{live_badge.dart, live_badge.freezed.dart}
│       │   │   ├── live_emote/{live_emote.dart, live_emote.freezed.dart}
│       │   │   ├── live_message_color/{live_message_color.dart, live_message_color.freezed.dart}
│       │   │   ├── live_message_style/{live_message_style.dart, live_message_style.freezed.dart}
│       │   │   ├── live_retraction/{live_retraction.dart, live_retraction.freezed.dart}
│       │   │   └── message.dart
│       │   ├── gift/
│       │   │   ├── live_gift/{live_gift.dart, live_gift.freezed.dart}
│       │   │   ├── live_gift_value/{live_gift_value.dart, live_gift_value.freezed.dart}
│       │   │   ├── live_gift_combo/{live_gift_combo.dart, live_gift_combo.freezed.dart}
│       │   │   └── gift.dart
│       │   ├── super_chat/
│       │   │   ├── live_super_chat_message/{live_super_chat_message.dart, live_super_chat_message.freezed.dart}
│       │   │   ├── live_super_chat_price/{live_super_chat_price.dart, live_super_chat_price.freezed.dart}
│       │   │   ├── live_super_chat_display/{live_super_chat_display.dart, live_super_chat_display.freezed.dart}
│       │   │   └── super_chat.dart
│       │   ├── play/
│       │   │   ├── live_play_quality/{live_play_quality.dart, live_play_quality.freezed.dart}
│       │   │   ├── live_play_line/{live_play_line.dart, live_play_line.freezed.dart}
│       │   │   ├── live_play_lease/{live_play_lease.dart, live_play_lease.freezed.dart}
│       │   │   ├── play_geometry/{play_geometry.dart, play_geometry.freezed.dart}
│       │   │   ├── infer_stream_format.dart       # 纯函数，无生成物
│       │   │   └── play.dart
│       │   ├── search/
│       │   │   ├── live_search_request/{live_search_request.dart, live_search_request.freezed.dart}
│       │   │   ├── live_search_result/{live_search_result.dart, live_search_result.freezed.dart}  # sealed union
│       │   │   └── search.dart
│       │   ├── page/
│       │   │   ├── live_page_request/{live_page_request.dart, live_page_request.freezed.dart}
│       │   │   ├── live_page/{live_page.dart, live_page.freezed.dart}   # 泛型
│       │   │   └── page.dart
│       │   ├── asset/
│       │   │   ├── live_asset_ref/{live_asset_ref.dart, live_asset_ref.freezed.dart}
│       │   │   └── asset.dart
│       │   ├── enums/                             # ★ 枚举：一文件一枚举，纯 .dart
│       │   │   ├── live_status.dart
│       │   │   ├── live_restriction.dart
│       │   │   ├── live_follow_group.dart
│       │   │   ├── live_stream_format.dart
│       │   │   ├── live_stream_codec.dart
│       │   │   ├── live_play_format_source.dart
│       │   │   ├── live_message_type.dart
│       │   │   ├── live_audience_metric_type.dart
│       │   │   ├── live_audience_signal_kind.dart
│       │   │   ├── live_audience_online_availability.dart
│       │   │   ├── live_gift_kind.dart
│       │   │   ├── live_gift_unit.dart
│       │   │   ├── live_message_placement.dart
│       │   │   ├── live_notice_kind.dart
│       │   │   ├── live_search_target.dart
│       │   │   ├── live_asset_type.dart
│       │   │   ├── live_anchor_role.dart
│       │   │   ├── live_room_activity.dart
│       │   │   └── enums.dart                     # barrel：export 全部枚举
│       │   └── converters/                        # ★ 独立：converter 一文件一 converter
│       │       ├── live_status_by_name_converter.dart
│       │       ├── epoch_millis_converter.dart
│       │       ├── iso_time_converter.dart
│       │       ├── audience_number_converter.dart
│       │       ├── uri_string_converter.dart
│       │       ├── stringify_converter.dart
│       │       └── converters.dart                # barrel：export 全部 converter
│       ├── platforms/<id>/           # ★ 平台实现（每站一目录）
│       │   ├── <id>_site.dart        #   manifest + capability 提供 + lifecycle
│       │   ├── api/                  #   端点、签名（纯函数优先）
│       │   ├── parsers/              #   响应→共享模型（纯函数，fixture 可测）
│       │   ├── capabilities/         #   各能力实现
│       │   └── fixtures/             #   录制的真实响应样本（测试数据）
│       ├── common/                   # ≥2 平台证实的共享工具（含 brotli/tars/protobuf）
│       └── internal/built_in_sites.dart
└── test/
    ├── contracts/                    # 公共契约测试（所有平台跑同一套 harness）
    ├── models/                       # 模型单测 + schema v1→v2 回归
    ├── common/
    └── platforms/<id>/               # parser 金样本测试
```

> 现存 `models/` 根目录 13 个孤儿 `.freezed.dart/.g.dart`、`contracts/`、`registry/` 的孤儿生成物：**Phase 0 删除**（已确认无任何引用）。

**依赖规则补充**：`enums/` 不引用任何 models 目录；领域类型引用 `enums/` 与 `converters/`；barrel 只 export 不定义。

---

## 4. 核心契约（core/）

### 4.1 LiveSite

```dart
abstract interface class LiveSite {
  LiveSiteManifest get manifest;          // 稳定身份：id 小写 ASCII、多语言名、版本
  LiveSiteRuntimeInfo get runtimeInfo;    // 运行态：uninitialized/initializing/ready/degraded/unavailable/disposed
  T? capability<T extends LiveSiteCapability>();  // 能力发现；null = 不支持
  Future<void> initialize(LiveSiteContext context); // 幂等；构造无 I/O
  Future<void> dispose();
}
```

规则：不为单站便利在 `LiveSite` 上加方法；`capability<T>()` 返回 null 表示不支持，**空结果永远不冒充不支持**；运行态不进 manifest（登录态、临时故障是 runtime 的事）。

### 4.2 Registry

进程内集合，不是插件系统：不动态加载、不网络下载代码、不管理权限、不吞初始化错误。组合根（app 层）构造 `createBuiltInLiveSites()` 交给它。只注册已实现的平台。

---

## 5. 错误处理（Either 边界规范）

**原则**：可预期失败是值不是异常；`Either` 只出现在能力接口这一层边界，内部辅助函数一律普通返回值。

```dart
Future<Either<LiveSiteError, T>> xxx(...);   // 能力接口签名
```

| 场景 | 处理 |
|---|---|
| 房间不存在 | `LiveSiteNotFound`（Left） |
| 平台无此能力 | `capability<T>()` 返回 null（不走 Left） |
| 网络/超时/限流/登录失效 | 网络层映射为 `NetworkError/RateLimitError/AuthenticationError` |
| 响应形状损坏 | `ParseError` |
| 意外异常 | 边界处 `captureLiveSite` 兜底转 `UnexpectedError`（不得当统一归类器） |
| 成功但空列表 | **Right**（空页不是错误） |
| 缓存未命中 | `T?` / `Option`，不用 Either |

错误信息不得泄露 token/cookie/签名 URL。UI 文案本地化在应用层。`LiveSiteError` 家族清单见 MODELS.md §4。

---

## 6. 数据模型规范（models/）

字段、类型、命名以 **[MODELS.md](MODELS.md)** 为准。此处只列结构铁律：

1. **子对象是唯一形态**。`LiveRoom` = `LiveRoomRef` + 9 个子对象（anchor/area/audience/broadcast/content/guide/links/local/runtime），构造器收子对象；扁平委托 getter 仅为迁移期兼容，逐站迁移完成后删除。
2. **相等语义**：模型 `==` 为全字段值相等（freezed 生成）；**身份比较/去重/合并显式走 `room.ref` / `ref.identityKey`**（大小写归一见 `SiteIds.ignoresRoomIdCase`），禁止依赖 `Set<LiveRoom>`。
3. **null = 未知**；数量 `int?`；禁止哨兵值。
4. **平台特例禁入**（§7.4）。
5. **持久化 schema v2**：顶层 `schemaVersion: 2`，键名=字段名，嵌套 anchor/guide/local；v1 扁平键在读入层兼容（对照表见 MODELS.md §7）。
6. **不可变**：所有模型 freezed 生成，变更走 `copyWith`/`mergedWith`。

---

## 7. 平台实现规范（platforms/）

### 7.1 目录与命名
平台 id = 小写规范名（`bilibili`、`douyin`、`huya`、`iptv`…），目录、类名、文件名一致（`BilibiliSite`）。不造大小写别名。

### 7.2 站点类
只做三件事：声明 manifest、暴露 capability、管理生命周期。请求/解析代码在 `api/`、`parsers/`。

### 7.3 parser 是纯函数
`响应(Map) → 共享模型`，无 I/O、无全局状态；每个 parser 配 `fixtures/` 真实响应样本做金样本测试。这是 37 个平台能被独立验证的关键。

### 7.4 quirk 隔离（对 v1 教训的硬规则）
平台特殊处理（Huya 热度字段历史、B 站详情瞬时掉 1、douyin 的 metricType、某站 id 大小写）**只能出现在该平台的 parsers/capabilities**。共享模型与 common 若需要平台差异，通过 manifest/能力声明的**数据**表达，不写 `switch (platform)`。
> 判定标准：在 models/ 或 common/ 里 grep 到平台名字 = 评审不通过（`SiteIds` 的大小写白名单除外，那是身份数据）。

### 7.5 能力诚实
平台没有的 API 不实现该 capability，不返回假空列表；临时不可用返回错误而非 null capability。分页按平台真实语义（page/cursor），不伪造。

---

## 8. 能力接口清单（capabilities/，现状保留）

| 接口 | 语义 | 核心签名 |
|---|---|---|
| `LiveRoomProvider` | 房间详情/目录页 | `getRoom(roomId)` / `getRooms(request)` |
| `LiveAnchorProvider` | 主播详情 | `getAnchor(anchorId)` |
| `LiveAreaProvider` | 分区树/分区房间 | `getAreas()` / `getAreaRooms(areaRef, request)` |
| `LiveHotProvider` | 热门榜 | `getHotRooms(request)` |
| `LiveDiscoveryProvider` | 推荐流 | `getRecommendedRooms(request)` |
| `LiveSearchProvider` | API 搜索 | `supportedTargets` + `search(request)` |
| `LiveWebSearchProvider` | WebView 搜索（scheme 校验、默认无 JS 桥） | `createSearch(query)` |
| `LivePlaybackProvider` | 清晰度/线路（`LivePlayLine` 自描述，播放器零平台代码） | `getQualities` / `getLines` |
| `LiveDanmakuProvider` | 弹幕会话（协议重连归会话；事件流 `Stream<LiveMessage>`） | `createSession(roomId)` |
| `LiveLinkResolver` | 分享链接→房间身份 | `resolve(uri)` |
| `LiveSiteCapability` | marker | — |

---

## 9. 模型代码生成策略（freezed / json_serializable / equatable 全量使用）

**总原则：模型的 `==`、`hashCode`、`copyWith`、`toJson/fromJson` 一律由生成器产出，手写这四样属于违规。** 手写只允许三处：归一化工厂体、业务方法（`mergedWith`/查询 getter）、JsonConverter。

### 9.1 三类模型，三种打法

| 类别 | 工具链 | 归属模型 | 理由 |
|---|---|---|---|
| **A · 值对象/聚合子对象** | `@freezed` + `@JsonSerializable`（需持久化的） | RoomContent/Links/Local/Runtime、RoomBroadcast、RoomAudience、RoomGuide、GuideCatchUp、PlayQuality/PlayLine/Lease/Geometry、MessageSender、Badge、Emote、Gift 族、SuperChat 族、Page/PageRequest、Search 族、AssetRef | 全字段值相等正合语义；生成 copyWith 加字段零成本 |
| **B · 身份实体** | `@freezed` + **身份下沉到 `LiveRoomRef`** | LiveRoom、LiveArea、LiveAnchor | freezed 不允许覆写 `==`；身份相等语义放进小的 `LiveRoomRef`（platform+roomId，freezed 全字段相等=身份相等）。**约定：LiveRoom 自身 `==` 为全字段相等（值语义）；身份比较/集合去重一律走 `room.ref == other.ref` 或 `ref.identityKey`** |
| **C · 密封联合** | `@freezed` union | LiveLinkResolution（room/redirect）、LiveSearchResult（room/anchor/area）、LiveSiteError | `.map/.when/.maybeMap` 穷尽匹配，exhaustive 检查由编译器保证 |

`equatable` 保留给**非模型的不可变类**（错误详情、上下文选项等手写类）免手写 `==`；模型本体不用它。

### 9.1a 为何一类型一目录（目录形态决策）

- **生成物定位**：`.freezed.dart`/`.g.dart` 必须与源同目录同名（§9.5）。一类型一目录让单个类型的源与生成物共处一个目录，`LiveRoom` 的生成代码就在 `live_room/` 里，不需要在一堆同名字段文件间翻找。
- **独立演进**：单类型的 `freezed`/`json_serializable` 输入输出边界清晰，加字段的 diff 只落在该类型目录。
- **枚举与 converter 解耦**：枚举独立 `models/enums/` 单文件（纯 `.dart`，无生成物）；converter 独立 `models/converters/` 单文件；脏解析规则集中但不与枚举耦合。
- **导航成本可控**：每领域一个 barrel（`room.dart`）保留聚合出口，公共出口仍只 export barrel，外部无感（§10 成立）。
- **不重蹈 v1**：v1 的问题是"大量目录只装一个枚举"且无 barrel、无生成物边界；v2 把枚举抽到 `enums/`、converter 抽到 `converters/`、每领域给 barrel，每目录职责单一。

### 9.2 归一化构造模式（raw 工厂）

平台输入脏（大小写、空格、占位符、本地时区），归一化不能丢。模式：**redirecting `raw` 工厂承载字段，公开工厂带函数体做归一化**：

```dart
@freezed
abstract class LiveRoom with _$LiveRoom {
  const LiveRoom._();

  /// 字段已归一的直接构造；copyWith / fromJson 生成代码走这里。
  @visibleForTesting
  const factory LiveRoom.raw({
    required LiveRoomRef ref,
    RoomContent content = const RoomContent(),
    RoomAudience audience = const RoomAudience(),
    // ...
  }) = _LiveRoom;

  /// 业务构造：先归一再委托 raw。必须幂等（fromJson 与业务构造共用）。
  factory LiveRoom({
    required String platform,
    required String roomId,
    RoomContent content = const RoomContent(),
    // ...
  }) => LiveRoom.raw(
    ref: LiveRoomRef(platform: platform.trim().toLowerCase(), roomId: roomId.trim()),
    content: content,
    // ...
  );

  factory LiveRoom.fromJson(Map<String, Object?> json) => _$LiveRoomFromJson(json);
}
```

规则：`raw` 是唯一 redirecting 工厂（json_serializable 依据它生成）；归一化逻辑集中在公开工厂，**禁止**散落到 getter；平台特例归一化（如 Huya 热度字段）不放这里，放平台 parser。

### 9.3 JsonConverter（脏解析全部收敛于 `models/converters/`）

`models/converters/` 目录独立存放，**每个 converter 一文件**，**每个脏解析规则全局只写一次**：

| Converter | 文件 | 职责 |
|---|---|---|
| `LiveStatusByNameConverter` | `live_status_by_name_converter.dart` | 枚举按 **name 字符串**读写；读入兼容 v1 的 index int |
| `EpochMillisConverter` | `epoch_millis_converter.dart` | 毫秒数 ↔ `DateTime?`（UTC） |
| `IsoTimeConverter` | `iso_time_converter.dart` | ISO-8601 ↔ `DateTime?`（UTC） |
| `AudienceNumberConverter` | `audience_number_converter.dart` | `"1.2万"/"3,400"/1.2e4` → `int?`（null=未知；`parseAudienceNumber` 逻辑的唯一居所） |
| `UriStringConverter` | `uri_string_converter.dart` | URL 字符串 ↔ `Uri?`（非法输入给 null，不抛） |
| `StringifyConverter` | `stringify_converter.dart` | 平台把数字 id 发成 int/Double 的 → String |

枚举专属 converter（如 `LiveStatusByNameConverter`）**放在 `converters/`，不放枚举同文件**——枚举文件保持纯声明，converter 集中便于统一审查脏解析规则。`converters/converters.dart` 为 barrel，统一 export。

### 9.4 SDK 与依赖约束（五件套同升同降）

`freezed_annotation` / `freezed` / `json_annotation` / `json_serializable` / `build_runner`（**`analyzer` 不直接声明**，由 `very_good_analysis` 与生成器牵引）**必须作为一个整体升级**。

当前基准（`packages/live_sites/pubspec.yaml`，`resolution: workspace`、`sdk: ^3.13.0`）：

```yaml
dependencies:
  equatable: ^2.0.7
  freezed_annotation: ^3.1.0
  json_annotation: ^4.12.0

dev_dependencies:
  build_runner: ^2.16.0
  freezed: ^4.0.2
  json_serializable: ^6.14.0
  very_good_analysis: ^11.0.0
```

升级步骤：先升 workspace SDK 约束 → 升五件套 → `dart run build_runner build --delete-conflicting-outputs` → `dart analyze` 全绿 → 提交（源与生成物同一 PR，禁止"生成物后补"）。

### 9.5 生成物卫生（对孤儿文件问题的硬规则）

- 生成文件与源文件**同目录同名**；源文件删除/移动时生成文件必须同删同移。
- PR 检查：`git status` 出现无源 `.g.dart/.freezed.dart` 即不合并；改名后旧生成物残留即不合并。
- 手改生成文件 = 直接打回。
- 现存 16 个孤儿生成物：Phase 0 一次性清除。

---

## 10. 公共出口（lib/live_sites.dart）

只导出：core 契约、11 能力接口、各领域 barrel（+ enums/converter barrel）、公共错误族、`createBuiltInLiveSites`。**禁止**导出 `src/platforms/`、`src/common/` 内部实现。外部包（含 live_iptv）只允许 `import 'package:live_sites/live_sites.dart'`——所以**移动模型文件不破坏外部**，前提是符号名不变（改名须走 §12 版本流程）。

```dart
/// Live Sites — unified integration contract for live platforms.
///
/// One package, one public surface: core contracts, optional capabilities,
/// model domains (one barrel per domain). Platform implementations under
/// src/platforms/ are private.
library;

// core
export 'src/core/live_site.dart';
export 'src/core/live_site_context.dart';
export 'src/core/live_site_error.dart';
export 'src/core/live_site_manifest.dart';
export 'src/core/live_site_registry.dart';
export 'src/core/live_site_runtime_info.dart';
// capabilities
export 'src/capabilities/live_anchor_provider.dart';
export 'src/capabilities/live_area_provider.dart';
export 'src/capabilities/live_danmaku_provider.dart';
export 'src/capabilities/live_discovery_provider.dart';
export 'src/capabilities/live_hot_provider.dart';
export 'src/capabilities/live_link_resolver.dart';
export 'src/capabilities/live_playback_provider.dart';
export 'src/capabilities/live_room_provider.dart';
export 'src/capabilities/live_search_provider.dart';
export 'src/capabilities/live_site_capability.dart';
export 'src/capabilities/live_web_search_provider.dart';
// models — 领域 barrel（一领域一 barrel，聚合该领域全部类型）
export 'src/models/anchor/anchor.dart';
export 'src/models/area/area.dart';
export 'src/models/asset/asset.dart';
export 'src/models/audience/audience.dart';
export 'src/models/gift/gift.dart';
export 'src/models/guide/guide.dart';
export 'src/models/message/message.dart';
export 'src/models/page/page.dart';
export 'src/models/play/play.dart';
export 'src/models/room/room.dart';
export 'src/models/search/search.dart';
export 'src/models/super_chat/super_chat.dart';
// models — 枚举与 converter barrel
export 'src/models/enums/enums.dart';
export 'src/models/converters/converters.dart';
// internal entry point
export 'src/internal/built_in_sites.dart';
```

> 领域 barrel 只 `export` 不定义；枚举 barrel 与 converter barrel 同理。公共出口因此保持稳定：新增一个模型类型只改对应领域 barrel，`live_sites.dart` 不动。

---

## 11. 与 live_iptv 的关系

- `live_iptv` 拥有 IPTV 领域模型（频道库、EPG 源、节目单解析）与存储；`live_sites` 中的 `iptv` 平台是它的**接入适配器**：`IptvEntry/EpgProgramme → LiveRoom/LivePlayLine` 的字段映射固定在 MODELS.md §6。
- 依赖方向：`live_iptv ──► live_sites`（公共入口）。禁止 live_sites 深入 live_iptv 内部。
- `IptvStreamType` 在 live_sites 侧由 `LiveStreamFormat + inferStreamFormat(url)` 取代（消灭双枚举）；`IptvChannel` 的收藏/置顶/隐藏属 `RoomLocal` 本地域，不上移。

---

## 12. 兼容与版本化

- `LiveSiteManifest.contractVersion`：公共契约版本（semver）；加能力=minor，改签名=major。
- 持久化 JSON：`schemaVersion`（当前 2）；读入端永久兼容 v1（收藏/历史是用户数据）。
- `LiveStatus` 等枚举持久化用 **name 字符串**，不用 index（枚举插值即破坏）；`unknown/none` 永远最后。
- 公共 API 破坏性变更：先在 MODELS.md/本文档记录，再改代码，同步更新契约测试。

---

## 13. 迁移计划（状态：Phase 0 待执行）

| 阶段 | 内容 | 完成标准 |
|---|---|---|
| **0 清理 + 目录重构** | 删 16 个孤儿生成物与空目录 `contracts/`、`registry/`；按 §3 新树建 `models/<域>/<类型>/`、`models/enums/`、`models/converters/` 与各 barrel；统一 §9 生成策略 | `dart analyze` error 清零；`build_runner` 产物与新目录对齐、无孤儿 |
| **1 模型落地** | ①§2 枚举定稿（进 `enums/`）+ `inferStreamFormat`（含单测）②播放族（format 必填/codec 枚举/formatSource）③audience `int?` 化 + schema v2 读写 ④一类型一目录 codegen 化（raw 工厂 + `converters/` 拆分） | 模型测试绿；`build_runner` 产物齐且无孤儿；外部包仅经公共入口引用不破 |
| **2 代表平台** | 迁移 **douyu**（纯 REST，最简）+ **huya**（含 quirk 隔离示范）进 `platforms/`，parser 金样本测试 | 契约 harness 通过；证明模型够用 |
| **3 弹幕平台** | **bilibili + douyin**（协议复杂、签名重），验证 `LiveMessageType` 全类型与 Sender 字段 | 弹幕回放录制可用 |
| **4 全量 + IPTV** | 其余 33 站按 2/3 模式批量迁移；iptv 站点按 MODELS.md §6 接入 live_iptv | 旧 `lib/shared/platforms` 可删 |
| **5 收敛** | 删迁移期扁平 getter、v1 写入路径；live_iptv 弃用 `IptvStreamType` | 公共 API 冻结，进入常规迭代 |

每阶段独立可回滚；不跳阶段（v1 的教训：没有平台验证的模型设计不可信）。

---

## 14. 测试策略

1. **契约 harness**（`test/contracts/`）：一套测试跑所有平台——manifest id 稳定、capability 诚实（有即实现、无即 null）、分页语义、错误映射、空结果非错误、生命周期幂等。
2. **parser 金样本**：每个 parser 至少一个真实响应 fixture（正常 + 畸形 + 缺字段）。
3. **模型回归**：schema v1 旧收藏样本 → v2 读入 → 字段无丢失；`identityKey` 稳定性；`inferStreamFormat` 后缀表。
4. **网络测试**：默认 mock/fixture；真实网络集成测试单独 tag，不进常规 CI。

命令（workspace 根）：
```powershell
dart format --output=none --set-exit-if-changed packages/live_sites
dart analyze packages/live_sites
dart test packages/live_sites
```

---

## 15. PR 检查清单

- [ ] 字段变更先改 MODELS.md，新字段带平台出处（站/接口/键名）
- [ ] models/、common/ 无平台名 switch（§7.4 判定）
- [ ] 数量字段 `int?`，无哨兵值；枚举持久化用 name
- [ ] 无孤儿生成文件；生成策略符合 §9；模型按 §3 一类型一目录、枚举进 `enums/`、converter 进 `converters/`
- [ ] 新增模型类型已更新对应领域 barrel；公共出口未新增内部导出
- [ ] parser 为纯函数且带 fixture 测试
- [ ] 平台特例留在 platforms/<id>/ 内
- [ ] 分析/格式化/测试全绿；源码注释英文

---

## 16. 决策记录（ADR 摘要）

| 决策 | 备选 | 选择理由 |
|---|---|---|
| 能力发现 `capability<T>()` | god-interface 全量默认方法 | 37 站能力差异大；空结果≠不支持 |
| `Either` 仅能力边界 | 全函数式 / 全异常 | 可预期失败是值；内部保持普通 Dart |
| LiveRoom 子对象唯一形态 | 纯扁平 | 加字段改动点 7→2；语义分组可测 |
| 数量 `int?` | String 承载"1.2万" | 解析一次在边界；消费端不再 parse |
| 一类型一目录 + enums/converters 独立 | 全扁平 13 文件 / 一类型一目录但枚举寄居 | 生成物与源同目录可定位；枚举/converter 职责单一；领域 barrel 保持出口稳定（§9.1a） |
| 全 codegen（freezed+json_serializable+equatable） | 手写归一化实体 | `==`/copyWith/序列化全部生成（加字段=声明字段+重新生成）；归一化走 raw 工厂模式，身份语义下沉 `LiveRoomRef` |
| 平台 quirk 下沉 | 模型内 switch(platform) | 37 站后模型将不可读 |
| 先代表平台后全量 | 一次定稿 | v1 教训：无实现验证的模型必然返工 |
