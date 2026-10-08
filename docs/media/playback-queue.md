# PlaybackQueue

> 队列执行器:把用户资产(Playlist/连播列表)实例化为顺序播放的会话链。

## 1. 结构

```text
PlaybackQueue
├── items: ContentRef[]
├── index: 当前项
├── policy: 顺序/随机/单曲循环/播完即停
└── session: 当前 PlaybackSession
```

## 2. 规则

- 项与项之间自动衔接:上一 Session disposed → 下一 ContentRef resolve → 新 Session;衔接失败跳过并标记。
- 队列状态(当前位置)可持久化("继续听这个歌单/看到第 N 集")——持久化的是 ContentRef 序列 + index,不是 Session。
- "下一集/上一集/自动连播"全部经队列,UI 不自行编排会话。
