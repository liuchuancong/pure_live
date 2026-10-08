# Engine Adapter(引擎适配)

> PlayerAdapter 由外部 media_core workspace 提供;PureLive 只经 `pure_live_media` 接线。

## 1. 关系

```text
pure_live_media(本仓,接线层)
   → media_core(PlayerKernel/PlaybackOperation/MediaPlan 语义)
      → media_core_media_kit / media_core_better_player / media_core_ijk / media_core_fvp(适配包)
         → MPV / Media3 / IJK / FVP 引擎
```

media_core **不依赖 PureLive**;PureLive 不反向进入 media_core(改动走其独立仓库与发布节奏)。

## 2. 适配器约定

- 内核只消费 MediaPlan/MediaTicket 语义,永远不知道 Bilibili/Douyu/TVBox(I2)。
- 引擎选择:用户默认设置 × Ticket.format 事实(如 flv 直播偏好、HEVC 需硬解)× 设备能力;失败走 engineFallback。
- mpv 调优参数属于 App(应用声明自己的调优,承接 v1 "the app declares its own mpv tuning" 原则);media_core 不内置预设。

## 3. 诊断

engine.switch / engine.fallback 事件 + 引擎版本进播放诊断;`play_success_rate`、`engine_fallback_rate` 为生态核心指标(见 [../diagnostics/tracing.md](../diagnostics/tracing.md))。
