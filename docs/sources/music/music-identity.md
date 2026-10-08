# Music Identity

> 同一首歌在不同平台 ID 不同;区分 **MusicIdentity(逻辑身份)** 与 **SourceSongId(源内 ID)**。

## 1. 匹配策略

优先 `ISRC`;否则组合 `title + artist + album + duration` 模糊匹配(阈值可配,置信度不足时让用户确认一次并记忆)。

## 2. 用途

- **换源播放**:音源失效/会员限制 → 用 identity 向另一源 resolve 新 MediaTicket。
- **去重**:搜索/歌单导入时合并同一曲目。
- **收藏/歌单**:以 identity 为逻辑主键,ContentRef 记录首选源。

## 3. 实现

匹配结果缓存(identity → sourceId 映射,storage 包);匹配逻辑在 services 层(纯 Dart,可单测),Provider 不感知彼此。
