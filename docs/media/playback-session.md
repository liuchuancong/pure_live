# PlaybackSession

> 一次播放的会话:持有 Plan、Ticket、内核会话句柄、恢复状态与诊断轨迹。

## 1. 状态机

```text
resolving → preparing → playing ⇄ buffering
                ↓ fail
            recovering(lineSwitch / engineFallback / reconnect)
                ↓ 不可恢复
             failed(向 UI 呈现原因与重试)
```

退出(用户/切后台策略)→ **disposed**:Session 销毁,ContentRef 与进度写 history。

## 2. 控制面

play / pause / seek / stop / switchQuality / switchLine / setVolume / next / previous——统一 `PlaybackCommand`(投屏与远控复用同一命令集,见 [../services/cast.md](../services/cast.md)、[../services/remote.md](../services/remote.md))。

## 3. 规则

- 同一时刻主画面只允许一个活动 Session;小窗/画中画/多画面由 media_core 的 pip/floating/multiview 承载多个内核会话。
- 会话是内存态;跨会话一切以 ContentRef + history 恢复。
- 全部状态迁移发诊断事件(见 [../diagnostics/playback-diagnostics.md](../diagnostics/playback-diagnostics.md))。
