# MediaPlan

> 一次播放的编排声明:MediaRuntime 按 Ticket + 用户设置 + 设备能力生成,PlaybackSession 执行。

## 1. 内容

```text
MediaPlan
├── ticket              首选 MediaTicket
├── fallbacks           备选线路/画质阶梯
├── prefetchPolicy      到期预取提前量/是否启用
├── enginePreference    引擎选择(用户设置 × format 事实)
├── startAt             起播位置(历史断点/选集续播)
├── audioPolicy         音频焦点/静音策略
├── diagnosticsTag      诊断标签(source/contentRef)
└── recoveryLadder      恢复阶梯定制
```

## 2. 规则

- Plan 是纯数据(可序列化,便于诊断复现);执行状态在 PlaybackSession。
- 用户设置(默认清晰度/线路偏好/硬解开关)在 Plan 生成时注入,Session 中途改动 = 生成新 Plan 补丁。
- 录制任务的 Plan 独立生成(无起播位置,有分段策略)。
