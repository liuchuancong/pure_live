# Content Identity(内容身份)

> 同一内容在不同源 ID 不同;跨源去重/换源播放需要身份层。音乐域最典型(见 [../sources/music/music-identity.md](../sources/music/music-identity.md)),视频域同理(B 站 BV ↔ TVBox 资源)。

## 1. 双层身份

```text
MusicIdentity(逻辑身份)  ≠  SourceSongId(源内 ID)
```

- 匹配优先级:ISRC(音乐)/ 权威编号 → title + artist/creator + album/series + duration 模糊匹配(阈值可配)。
- 匹配结果缓存(identity → sourceId 映射),换源播放 = 用同一 identity 向另一 Provider resolve 新 MediaTicket。

## 2. 规则

- 身份匹配是 services 层能力,Provider 不感知彼此。
- 匹配置信度不足时不强并:显示候选让用户确认一次,结果记忆。
- 历史/收藏以用户首次使用的 ContentRef 为主键,identity 作为换源索引。
