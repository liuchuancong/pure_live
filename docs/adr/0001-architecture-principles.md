# ADR 0001:架构原则

- 状态:已接受(2026-10-08)
- 关联:总纲 [../architecture/architecture.md](../architecture/architecture.md)

## 背景

v1 把站点解析、播放策略、UI 耦合在单包内,新增源/域都要动核心;生态(插件/主题)无从谈起。

## 决策

采纳五段职责句:**Core 提供规则,Plugin 提供能力,Provider 提供内容,Media Core 提供播放,Feature 提供体验**。确立四概念链 Plugin → Capability → Content → Media 与十大不变量 I1-I10(见 [../architecture/dependency-rules.md](../architecture/dependency-rules.md))。

## 后果

- 正:扩展不动核心;多宿主(TV/桌面)可复用;第三方可接入。
- 负:契约设计成本前置;包数量上升(melos 承担);抽象泄漏风险需护栏与契约测试约束。
