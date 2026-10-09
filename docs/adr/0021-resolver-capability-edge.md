# ADR 0021:Resolver 适配 Capability 是同层例外,不是把契约再抄一遍

- 状态:已接受(2026-10-09)
- 相关:[0018-contract-package-split.md](0018-contract-package-split.md) · [0019-gateway-service-edges.md](0019-gateway-service-edges.md) · [../architecture/dependency-rules.md](../architecture/dependency-rules.md) §3/§4 · [../contracts/platform-contracts.md](../contracts/platform-contracts.md) §10/§12

## 背景

`platform-contracts.md` §12 规定平台消费的是 `Resolver`(`descriptor` + `canResolve` + `resolve` → `ResolveResult`),
而 §10 规定源实现的是 `ResolveCapability`(`resolve(ref, {quality, line})` → `MediaTicket`)。两者不是同一个东西:
Capability 交出一张票据,Resolver 交出一组票据加一条选择策略,并且注册表要在**不发请求**的前提下问出"谁能服务这个内容"
(`canResolve` 必须离线可答,否则一次解析会把所有候选都打一遍网络)。

`packages/ecosystem/{capability,resolver}` 都在生态层(§3 的矩阵如此划分),因此 `CapabilityResolver` 这个适配器
要么依赖同层的 `pure_live_capability`(违反"同层禁互依"),要么在 resolver 包里**重新声明一份** `ResolveCapability`
接口,由应用层把实现传进来。

重新声明这条路 ADR 0018 已经否过一次了:两份同名接口靠鸭子类型对接,签名漂移只能在运行时发现,而契约测试
(`pure_live_capability/testing.dart`)绑在原接口上,复制体拿不到断言。剩下的是第三种:把 Capability 的定义下沉到
`pure_live_platform`。但 §10 的 Capability 是"实现侧词汇",platform 是"边界上的数据形状"(ADR 0018 的划分),
把行为接口放进 model 包会让 platform 从"只有数据"变成"带抽象方法",与它不做选择、不持有状态的定位冲突。

## 决策

批准一条**指名到包**的同层边,与 ADR 0019 同表登记:

```text
pure_live_resolver  ->  pure_live_capability
```

约束:

1. 只有 `pure_live_resolver` 可以走这条边。其他生态包(integration、UI、feature)要解析能力时,依赖
   `pure_live_resolver` 的 `CapabilityResolver`,而不是自己去 import capability。
2. 方向单向:`pure_live_capability` 永远不得依赖 `pure_live_resolver`。Capability 不知道注册表、优先级与降级链的存在。
3. 这条边的用途只有"把一个 Capability 提升成 Resolver"。适配器不得借它读取 capability 包的内部实现——
   它只用 barrel 上的 `ResolveCapability`。
4. 白名单落在 `tool/check_architecture.dart` 的 `kApprovedExceptions`,文档落在
   `docs/architecture/dependency-rules.md` §4;`tool/test_check_architecture.ps1` 同时钉住正例(该边走得通)与
   反例(别的生态包伸手拿 capability 仍被 `layer-direction` 拦下)。

## 后果

- 正:契约只有一份,签名不匹配在编译期失败,`testing.dart` 的 `checkResolveCapability` 对适配器背后的真实实现依然有效。
- 正:适配器成了票据进入 `ResolveResult` 的唯一通道,过期判定(交出不可能成功的票据是错的)因此有了一个可以钉住的落点。
- 负:生态层不再是无环平铺,读图时要记得"resolver 是 capability 的平台形状"。
- 负:若 provider 侧将来想在 capability 上加分页/批量解析,`CapabilityResolver` 会跟着长;这是把变更集中在一处的代价,
  而不是允许别处再开一条同层边的理由。
