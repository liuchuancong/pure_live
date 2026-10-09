# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `HistoryEntry` / `HistoryService` / `HistoryRepository` 端口:跨域观看历史,行身份是
  `(sourceId, contentId, kind)` —— 不用 `ContentRef ==`(它含 `parentId`,调用方少写一次父级就会把同一集拆两行)。
- 三个记录点:`record`(进度,`duration` 缺省保留上次长度)、`finish`(看完)、`flush`(落回被节流挡下的行);
  节流是机制、`minWriteInterval` 由宿主给(默认 0),文档没给数就不假装知道。
- 长度未知 ≠ 已看完;`timeline` 按 `updatedAt` 倒序并可按域/源/标题子串筛;`series(parentId)` 给"看到第 N 集"。
- 快照随条目存(文档未要求,与收藏/歌单一致,理由写在 README);删除与清空同时清掉挂起行,历史不会复活。
- `KeyValueHistoryRepository`:今天的键值绑定;文档点名的 Drift 由细粒度端口隔开。
