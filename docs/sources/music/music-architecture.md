# Music 架构

> 音乐不是单一音乐源,而是多源 Resolver 体系(ADR 0010);逻辑参考 lx-music(只学结构,不移植 JS)。

## 1. 模型

```text
MusicCapability
      │
      ▼
MusicResolver(跨源解析)
      │
 ┌────┼────┐
 ▼    ▼    ▼
内置源 lx兼容源 插件源
      │
      ▼
 MediaTicket
```

## 2. 能力面

MusicSearch / MusicResolve / Lyric / Album / Playlist / Songlist / 排行榜 / 热搜。

## 3. 文档

- 身份与换源:[music-identity.md](music-identity.md)
- 解析器:[music-resolver.md](music-resolver.md)
- 歌词:[lyric.md](lyric.md)

## 4. 内置源

`source_music_builtin` 提供首批音源;自定义源(user-api)经 JS 插件接入——lx-music 音源脚本兼容为远期评估项(接口预留,不承诺)。
