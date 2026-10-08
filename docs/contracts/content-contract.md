# 内容契约(Content Contract)

> 所有业务尽量使用统一 Content Model;跨业务数据一律 ContentRef(I7)。

## 1. ContentRef

```dart
class ContentRef {
  final String sourceId;   // 插件 id,如 com.purelive.source.bilibili
  final ContentKind kind;
  final String id;
  final String? parentId;  // 选集→剧集,单曲→专辑
}
```

URI 形态:

```text
bilibili://vod/BV1xxx
bilibili://episode/123
douyu://live/123456
youtube://video/abc
netease://song/123456
tvbox://vod/xxxx
local://video/xxxx
```

## 2. ContentKind

`live` `video` `movie` `series` `episode` `music` `album` `artist` `playlist` `channel` `radio` `podcast` `recording` `localFile` `collection` —— 只追加,不复用旧名,不重排(见 [../architecture/evolution.md](../architecture/evolution.md))。

## 3. ContentItem / MediaItem

- `ContentItem`:列表/Feed/搜索结果里的可展示条目(标题/封面/副标题/ContentRef/角标)。
- `MediaItem`:详情与可播放实体(媒体描述 + 可解析为 MediaTicket 的句柄)。

## 4. Collection / Playlist

- `Collection`:内容集合(剧集/专辑/合集),持有子 ContentRef 列表与顺序。
- `Playlist`:用户侧队列(歌单/连播列表),建在 ContentRef 之上,可跨源混排。

## 5. 禁止

- 平台前缀业务类型(`BilibiliHistory` / `DouyuFavorite`)——历史/收藏/播放列表/稍后再看一律基于 ContentRef(见 [../services/history.md](../services/history.md))。
- 搜索结果返回平台专属 ID——必须返回 ContentRef(见 [../services/search.md](../services/search.md))。
