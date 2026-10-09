# 能力契约(Capability Contract)

> Capability 描述"系统提供什么能力";插件按需实现,一个插件不必实现全部。

## 1. 能力分类

**基础能力**:`LiveCapability` `VodCapability` `MusicCapability` `IptvCapability` `SearchCapability` `FeedCapability`

**媒体附加能力**:`DanmakuCapability` `SubtitleCapability` `LyricCapability` `CommentCapability` `ChapterCapability` `QualityCapability` `LineCapability`

**数据能力**:`HistoryCapability` `FavoriteCapability` `PlaylistCapability` `MetadataCapability` `RecommendationCapability`

**平台能力**:`AuthCapability` `AccountCapability` `EpgCapability` `RepositoryCapability`

## 2. 示例:能力组合

```text
Bilibili:LIVE + VOD + Search + Feed + Danmaku + Comment + Subtitle + Auth
Douyu:   LIVE + Search + Feed + Danmaku + Auth
NetEase: MusicSearch + MusicResolve + Lyric + Album + Playlist
```

## 3. 通用方法约定

每个内容类 Capability 至少提供:

```dart
/// 目录/分类浏览
Future<Page<ContentItem>> browse(CategoryRef? category, Cursor? cursor);
/// 详情
Future<ContentDetail> detail(ContentRef ref);
/// 搜索(实现 SearchCapability 时)
Future<Page<SearchItem>> search(SearchRequest request);
/// 解析播放 → 统一 MediaTicket(见 media-contract.md)
Future<MediaTicket> resolve(ContentRef ref, {QualityRef? quality, LineRef? line});
/// 换链(到期/失败重取)
Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason);
```

业务规则落在契约里:取流必须返回 **MediaTicket**(含 `expiresAt`),宿主据此做到期预取换链——源实现方免费获得断流防护(见 [../media/media-ticket.md](../media/media-ticket.md))。

### 3.1 分类表(categories)与分页语义(2026-10-09 细分)

```dart
/// 源自带的分类表;空 = 源无分类,消费方不得自造分类 UI
Future<List<ContentCategory>> categories();
```

- `ContentCategory{id, name, parentId?, icon?}`;`parentId` 表达两级树,平铺源留空;`id` 即
  `ContentQuery.category` 回传值。
- 分类表可选:没有分类是**形态**,不是失败;JS 面未实现 `live.categories` 视为空表。

**分页三态**(platform-models §9 `PageMode`),由源在**每个应答**里声明,消费方按模式读字段、不得假设:

| 模式 | 语义 | 消费规则 |
|---|---|---|
| `fixedPage` | 一页码 + 页大小经典表 | 下一页 = `page+1`;`hasMore=false` 即止 |
| `cursor` | 服务器自定义游标 | 应答带 `nextCursor`,下一页必须经 `PageRequest.cursor` 回传,**page 数字无意义** |
| `singleShot` | 一次全量 | `items` 即全部,`hasMore` 恒 false,请求第 2 页返回空 |

源说谎的代价归源:声明 `cursor` 却不带 `nextCursor`,或 `singleShot` 却称 `hasMore`,契约测试按违规处理
(与 `contract.browse.page_mismatch` 同表)。

## 4. 契约测试

每个 Capability 都有 Contract Test(`LiveProviderContractTest` 等),**内置源与 JS 源跑同一套断言**;第三方插件交付前必须通过对应契约测试(见 [../development/testing.md](../development/testing.md))。

断言实现:`package:pure_live_capability/testing.dart`。它不依赖 `package:test`,而是返回
`List<ContractViolation>`(每条带稳定 `code`),因此单测、插件校验 CLI 与设备端自检跑同一条路径;
错误码清单与 `expiresAt` 的读法见
[包 README](../../packages/ecosystem/capability/README.md)。

## 5. 实现落点与名称对应

§1/§3 用的是文档名,代码里的实际形状以
[platform-models.md](platform-models.md) §7/§9/§11 为准(实现包:`packages/ecosystem/capability`):

| 文档名 | 实现名 |
|---|---|
| `Page<T>` | `PageResult<T>` |
| `ContentItem` / `SearchItem` | `ContentSummary` |
| `CategoryRef? category, Cursor? cursor` | `ContentQuery`(category / keyword / `PageRequest`) |
| `SearchRequest` | `SearchQuery` |
| `QualityRef` / `LineRef` | `SelectionRef` |
| `LiveDetail` | `ContentDetail` |
| `LiveCapability`…(§1 命名) | `CapabilityKind` 枚举项 + `BrowseCapability` / `SearchCapability` / `ResolveCapability` / `FeedCapability` 方法集 |

方法集尚未定义的 kind(danmaku、subtitle、lyric、comment、chapter、quality、line、history、favorite、playlist、
metadata、recommendation、auth、account、epg、repository)随定义其调用的那一批补接口与断言;在此之前
`checkCapabilityDeclarations` 对它们既不报违规也不算通过,以免一个空检查被误读成"已覆盖"。
`qualities(ContentRef)`(见 [../sources/live/source-contract.md](../sources/live/source-contract.md))属于其中的
quality/line 一组。

插件仍可以在 Manifest 里声明这些名字(§1 名单就是插件面的合法词表),但粗路由集 `ExtensionCapability`
([platform-contracts.md](platform-contracts.md) §5)没有对应条目时不产生路由,`pure_live_plugin_api` 的清单
校验也不因此拒绝安装。拼写差异一处:`lyric`(本节)/ `lyrics`(枚举),由 `capabilityAliases` 对齐。
名单一致性由两侧各自对着本文钉住:`pure_live_capability` 断言 `CapabilityKind` 覆盖 §1 全部名字,
`pure_live_plugin_api` 断言 `pluginCapabilityNames` 等于 §1 名单 —— 改本文必须同时改两处。

