# 播放诊断

> 播放问题从"复现不了"变成"导出证据链"。

## 诊断会话

一次播放 = 一个 `PlaybackTrace`:ContentRef / source / MediaTicket 生命周期(签发/刷新/换线)/ 内核事件(buffering/error/engine)/ Recovery 动作 / 网络摘要。

## 用户路径

设置 → 诊断 → "导出播放诊断报告":自动附加上次失败的 PlaybackTrace(播放日志 + 最近 ticket/refresh/line.switch 事件 + 环境信息:平台/引擎/网络类型)。**报告不含凭据与个人数据**(脱敏强制)。

## 反馈闭环

用户报"某站播不了" → 请求诊断报告 → 定位在 resolve(协议变了→源要更新)/ ticket(风控→UA 问题)/ playback(引擎问题)——每类对应不同的修复 Owner(源插件 / network / media)。
