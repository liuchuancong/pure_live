# ADR 0005:统一内容模型(Content Model)

- 状态:已接受(2026-10-08)

## 背景

v1 各域(直播/点播/音乐)各自为政,搜索/历史/收藏无法统一,平台数据渗透业务层。

## 决策

ContentRef(sourceId+kind+id+parentId)为跨业务唯一键;ContentItem/MediaItem/Collection/Playlist 为标准展示与资产模型;ContentKind 枚举只追加。禁止平台前缀业务类型(BilibiliHistory 等)。见 [../contracts/content-contract.md](../contracts/content-contract.md)。

## 后果

- 正:搜索/历史/收藏/队列天然跨域;源失效数据可降级显示。
- 负:个别站点特有字段(直播间人气榜)需 extras 承载,强类型损失由文档与契约测试弥补。
