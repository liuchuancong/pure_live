# 内容模型总览

> 统一内容模型是跨域业务(搜索/历史/收藏/队列/链接)的地基;平台差异止步于 Provider。

## 1. 模型族

```text
ContentRef      内容的身份(跨域引用的最小单元)
ContentItem     列表里的可展示条目(Feed/搜索/目录)
ContentDetail   详情页聚合(元数据/子项/能力句柄)
Collection      内容集合(剧集/专辑/合集)
Playlist        用户侧播放队列(歌单/连播)
MediaItem       可播放实体(进媒体管线的入口)
```

## 2. 设计规则

- 一切跨业务数据(历史/收藏/搜索结果/队列)以 **ContentRef** 为键(I7);禁止平台专属 ID 外泄到业务层。
- ContentKind 枚举:live/video/movie/series/episode/music/album/artist/playlist/channel/radio/podcast/recording/localFile/collection(只追加)。
- 模型用 freezed;序列化随备份/同步走版本化格式。

各模型细则:[content-ref.md](content-ref.md) / [media-item.md](media-item.md) / [collection.md](collection.md) / [playlist.md](playlist.md) / [content-identity.md](content-identity.md)。
