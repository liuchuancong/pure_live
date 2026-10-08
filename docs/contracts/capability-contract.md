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

## 4. 契约测试

每个 Capability 都有 Contract Test(`LiveProviderContractTest` 等),**内置源与 JS 源跑同一套断言**;第三方插件交付前必须通过对应契约测试(见 [../development/testing.md](../development/testing.md))。
