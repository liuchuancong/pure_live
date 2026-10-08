# ADR 0019:ExtensionGateway 对 permission / task 的装配依赖是同层例外

- 状态:已接受(2026-10-08)
- 相关:[0018-contract-package-split.md](0018-contract-package-split.md) · [../architecture/dependency-rules.md](../architecture/dependency-rules.md) §3/§4 · [../contracts/platform-contracts.md](../contracts/platform-contracts.md) §2/§15/§19

## 背景

`platform-contracts.md` §19 规定扩展只能通过 `ExtensionContext` 取得平台服务,而 `ExtensionContext` 的字段是
`ExtensionNetwork` / `ExtensionCookieStore` / `PermissionManager`(在 `pure_live_permission`)与
`TaskScheduler`(在 `pure_live_task`)。`platform-infrastructure.md` §9 又把 extension / permission / task
三者都列在生态层。于是网关要么依赖两个同层包(违反"同层禁互依"),要么不实现 §19 的注入边界。

另一种做法是在网关内重新声明一套 PermissionManager / TaskScheduler 接口,由应用层把实现传进来。这与
`pure_live_auth` 用 ports.dart 绕过 L0 互依的情形不同:那里绕开的是**无人需要的重复**;这里重发的正是同一份
平台契约,两套接口迟早漂移,而漂移后编译期看不出来。ADR 0018 立"模型只有一个真源"就是为了挡这类重复。

## 决策

允许一条**定向且封闭**的同层边:

```text
pure_live_extension  ->  pure_live_permission
pure_live_extension  ->  pure_live_task
```

约束:

1. 只有 `pure_live_extension` 可以走这条边,方向只能是网关指向服务包;permission / task 永远不得反向依赖网关。
2. 这条边的用途只有"把服务装进 `ExtensionContext`"。服务包不得借它暴露只有网关用的内部实现(公共面仍是各自 barrel)。
3. 白名单写在 `tool/check_architecture.dart` 的 `kApprovedExceptions`,与 danmaku/background → media 等既有例外同表,
   `docs/architecture/dependency-rules.md` §4 逐条列明;新增一条要走 ADR,不允许就地加行。

## 后果

- 正:网关与服务的契约同源,签名对不上直接编译失败,不需要接线层再翻译一次。
- 正:例外显式可查,护栏仍然机械生效 —— 任何第三个生态包想吃 permission 都会被 `layer-direction` 拦下。
- 负:生态层内部不再是严格无环的平铺;读图时必须记得"网关是这些服务包的装配点"。
- 负:若将来 permission / task 反过来需要网关(例如按扩展枚举权限),这条例外就会被破坏。当前契约里没有这种需求,
  真出现时应把共同依赖的部分下沉为模型(归 `pure_live_platform`)而不是放开反向边。
