# Line Switch(线路切换)

> 多线路 + 到期预取 + 关键帧无缝切换——直播稳定性的核心能力(斗鱼 #35 模式产品化)。

## 1. 预取换链(正常路径)

```text
T-45s(refreshBefore)宿主调度
 → Provider.refresh(reason: expiring) → 新 MediaTicket
 → 内核在关键帧/安全点无缝切换(不重新起播、不重缓冲)
 → 旧票据作废;弹幕/进度/会话全程保留
```

换链失败 → Recovery 阶梯(线路 → 画质 → 引擎 → 退避)。

## 2. 手动换线(用户路径)

清晰度/线路菜单(player_ui)→ `switchQuality/switchLine` 命令 → 新 resolve → 关键帧切换;切换记忆按"平台×房间"(settings_repository)。

## 3. 规则

- 直播切换必须**无损**:不允许黑屏重连(那是 recovery 的最后手段)。
- 点播 seek 后的线路地址过期同样走 refresh(续播位置不变)。
- 每次切换写诊断事件:`line.switch`(原因/耗时/结果),进入 play_success_rate 等指标(见 [../diagnostics/tracing.md](../diagnostics/tracing.md))。
