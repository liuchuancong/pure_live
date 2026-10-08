# History(历史)

> 跨域统一观看历史,键 = ContentRef;禁止平台前缀类型(BilibiliHistory 等)。

## 记录点

- 播放开始/退出/进度节流(position 变更)。
- `parentId` 聚合:看到某剧第 N 集 = episode 记录 + series 聚合视图。

## 查询

- 统一时间线(live/vod/music/iptv 混排)+ 按域过滤。
- `ContinueWatching`(继续观看):有进度未看完的 series/recording。
- 搜索/筛选/清空(带确认)。

## 存储

drift(recorder 域同款模式);同步纳入 sync;迁移:接收 v1 各域历史(见 [../migration/database-migration.md](../migration/database-migration.md))。
