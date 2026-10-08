# Playlist Service

> 用户资产层的播放列表(歌单/连播/稍后再看);与媒体执行队列分离(见 [../media/playback-queue.md](../media/playback-queue.md))。

## 结构

见 [../content/playlist.md](../content/playlist.md)。

## 服务职责

- 歌单 CRUD / 排序 / 导入导出(音乐域可导入外部歌单格式)。
- "稍后再看"(WatchLater)是系统内置歌单。
- 播放歌单 → 实例化 PlaybackQueue(policy 从歌单读取)。
- 同步纳入 sync;音乐域与 lx-music 歌单格式互通为远期评估。
