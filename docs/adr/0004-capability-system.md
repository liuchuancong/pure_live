# ADR 0004:能力系统(Capability System)

- 状态:已接受(2026-10-08)

## 背景

"源"不是原子能力:B 站同时有直播/点播/搜索/弹幕/认证;把插件当黑名单式大接口会强迫所有实现者做全。

## 决策

能力拆为四类 20+ 个细粒度 Capability(基础/媒体附加/数据/平台);插件按需实现;CapabilityRegistry 按 capability 索引发现;每个 Capability 配契约测试,内置与 JS 实现同断言。见 [../contracts/capability-contract.md](../contracts/capability-contract.md)。

## 后果

- 正:小源只实现 Live 即可;UI 按能力渐进增强(有弹幕就显示弹幕开关)。
- 负:接口数量多——用"能力清单 + 默认实现"与文档索引消化。
