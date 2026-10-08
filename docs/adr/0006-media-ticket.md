# ADR 0006:MediaTicket(统一媒体凭据)

- 状态:已接受(2026-10-08)

## 背景

直播 URL 有 TTL(斗鱼 #35 每五分钟断流),点播/音乐地址同样会过期;v1 在直播域单独修,其他域重复踩坑。

## 决策

StreamTicket 升级为通用 **MediaTicket**(urls/expiresAt/refreshBefore/quality/line/refreshPolicy/capabilities),六域统一;RefreshReason 枚举;Provider 负责 resolve/refresh,内核负责 detect→switch;宿主按 refreshBefore 调度预取(到期换链成为所有源的标准能力)。见 [../contracts/media-contract.md](../contracts/media-contract.md)。

## 后果

- 正:断流防护一次实现全局受益;诊断轨迹标准化。
- 负:插件必须如实报 expiresAt(谎报由 Watchdog 403/中断检测兜底)。
