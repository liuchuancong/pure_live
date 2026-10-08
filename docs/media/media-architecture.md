# 媒体架构总览

> 所有需要播放的内容进入统一 Media Pipeline;Provider 与 Player 彻底解耦(I1/I2)。

## 1. 管线

```text
ContentRef → Provider → MediaResolver → MediaTicket → MediaPlan
→ PlaybackSession → PlayerKernel → PlayerAdapter → Engine(mpv/media3/…)
```

## 2. 组件地图

| 组件 | 职责 | 文档 |
|---|---|---|
| MediaTicket | 一次取流的完整凭据(URL/TTL/线路/画质) | [media-ticket.md](media-ticket.md) |
| MediaPlan | 播放编排:起播参数/预取/兜底/引擎偏好 | [media-plan.md](media-plan.md) |
| PlaybackSession | 一次播放的会话状态与控制面 | [playback-session.md](playback-session.md) |
| PlaybackQueue | 队列执行(连播/歌单) | [playback-queue.md](playback-queue.md) |
| Recovery | 刷新原因分级与恢复阶梯 | [recovery.md](recovery.md) |
| Watchdog | 卡顿/中断/过期看门狗 | [watchdog.md](watchdog.md) |
| LineSwitch | 多线路与无缝切换 | [line-switch.md](line-switch.md) |
| Recorder | 录制(同一管线的旁路消费) | [recorder.md](recorder.md) |
| EngineAdapter | media_core 的内核适配 | [engine-adapter.md](engine-adapter.md) |

## 3. 铁律

- Provider 不知道播放器实现;Player 不知道内容来源(I1/I2)。
- 一切可播放资源以 MediaTicket 表达(I6);Ticket 会过期,过期→refresh,不是重建播放。
- 内核 = 外部 media_core workspace,本仓只经 `pure_live_media` 接线,不反向依赖。
