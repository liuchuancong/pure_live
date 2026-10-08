# Recovery(恢复)

> 播放故障的分级恢复:先票据、再线路、再引擎、最后退避重连;每级有时限与次数上限。

## 1. 恢复阶梯

```text
refresh(ticket)            # 按 RefreshReason 重取票据
 → lineSwitch(下一线路)     # 备选 urls
 → qualityFallback(降画质)  # 高画质源 403/超载
 → engineFallback(换内核)   # mpv 失败试备用 adapter
 → reconnect + backoff      # 指数退避,上限后交还 UI
```

## 2. 触发映射

| 信号 | 动作 |
|---|---|
| expiresAt 将至 | 预取 refresh(无感) |
| http403/404 | refresh → lineSwitch |
| 网络断开恢复 | reconnect(从断点) |
| decodeError | engineFallback |
| 长时间无数据 | watchdog 介入(见 watch Dog 文档) |

## 3. 规则

- 恢复过程**保留会话**:弹幕、进度、队列不变;换引擎时进度对齐。
- 每级上限(次数/时限)防抖动;超限 → failed + 用户可见原因(诊断可导出)。
- 直播与点播共用阶梯;直播多了"追帧"(落后直播间实时进度时快进追上,v1 已有经验)。
