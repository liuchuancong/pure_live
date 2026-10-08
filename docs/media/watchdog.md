# Watchdog

> 独立于播放内核的看门狗:内核卡死/静默故障的最后防线。

## 1. 监控项

| 项 | 判定 | 动作 |
|---|---|---|
| 起播超时 | preparing 超 N 秒无首帧 | recovery(先 refresh 后换线) |
| 无进度心跳 | 内核 position 停滞且 buffering 超 M 秒 | refresh → lineSwitch |
| 缓冲率异常 | 滑动窗口缓冲占比超阈值 | 降画质建议/自动降档 |
| 票据过期 | now > expiresAt 且未刷新 | 强制 refresh |
| 时钟漂移(直播) | 落后边缘服务器时间过多 | 追帧 |

## 2. 规则

- Watchdog 只**发起**恢复请求,恢复阶梯由 Recovery 统一执行(避免多方同时救火)。
- 所有触发与动作写播放诊断轨迹(见 [../diagnostics/playback-diagnostics.md](../diagnostics/playback-diagnostics.md)),用户报障时可导出完整证据链。
- 参数(阈值/时限)全局默认 + 每源可覆写(插件 manifest 可声明)。
