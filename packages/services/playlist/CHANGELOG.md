# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `m3u.dart`: an import path for the format external lists actually arrive in. Splitting `#EXTINF` on the
  first comma (titles carry commas), unknown directives counted and kept so an export can say the round trip is
  lossy, relative locations resolved against the file's own base, bare-path files parsed with `hasHeader=false`
  reported rather than refused, and three line endings handled.
- `watch_later.dart`: `WatchLaterService` for the system list playlist.md names - fixed id, created on first
  use, not deletable, and **a repeat save moves the row to the front** instead of appending a second copy.
  `importM3uAsPlaylist` always creates a list rather than merging into one, and reports a title collision
  instead of inventing a merge rule.
- Bulk writes (`replaceItems`, `addAllItems`, `removeWhere`, `reverse`): the repository stores the whole ordered
  list, so a bulk caller issuing N single-row upserts rewrites an N-row document N times and a crash halfway
  leaves a list nobody asked for.
- Titles and ids are validated (blank refused, length bounded, newline ids refused) with a named
  `PlaylistFailure.invalidInput` rather than borrowing `notFound`.

- `Playlist` / `PlaylistItem` / `PlaylistsService`:跨源混排的用户队列,行的身份是下标而不是 ref,
  同一条内容可以排两次;`moveItem(from, to)` 的两个下标按移动前的列表读(拖拽手柄报的坐标)。
- 条目带快照(`ContentSummary`),列表渲染从不问源;`playMode`(顺序/随机/单曲循环)只存不执行,
  选下一行属于 `PlaybackQueue` —— 文档把用户资产与会话状态分成两件事,这里就一行都不做。
- `PlaylistRepository` 按整份列表给操作(有序列表就是记录的形状),今天由 `KeyValuePlaylistRepository` 绑定;
  读不懂的文档抛 `FormatException`,不当成空。空队列合法,`clear` 只清行不删列表。
