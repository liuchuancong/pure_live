# Playlist

> 用户侧播放队列:歌单、连播列表、稍后再看——建立在 ContentRef 上,可跨源混排。

```dart
class Playlist {
  final String id;
  final String title;
  final List<PlaylistEntry> entries;   // ContentRef + 快照元数据(源失效仍可显示)
  final PlaylistPolicy policy;         // 顺序/随机/单曲循环
}
```

## 规则

- **跨源混排**:B 站视频与音乐可以进同一队列;播放时按各自 capability resolve。
- 快照元数据(title/cover)随条目存储——源失效时队列仍完整可见(降级显示)。
- 队列与 `PlaybackQueue`(媒体管线中的执行队列)分离:Playlist 是用户资产,PlaybackQueue 是会话状态(见 [../media/playback-queue.md](../media/playback-queue.md));"播放歌单"= Playlist → 实例化 PlaybackQueue。
- 存储走 settings_repository/backup;同步纳入 sync 范围。
