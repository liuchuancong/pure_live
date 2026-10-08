# ADR 0018:行为契约按子系统分包,数据模型集中在 pure_live_platform

- 状态:已接受(2026-10-08)
- 相关:[0015-monorepo-layout.md](0015-monorepo-layout.md) · [../contracts/platform-models.md](../contracts/platform-models.md) §18 · [../architecture/platform-infrastructure.md](../architecture/platform-infrastructure.md) §9

## 背景

两份定稿文档对"契约接口放在哪个包"给出的形态不一致:

- `platform-models.md` §18 推荐**单一伞包** `pure_live_platform`,里面同时放 `models/` 与 `contracts/`。
- `platform-infrastructure.md` §9 又把 `pure_live_extension / _resolver / _identity / _permission / _task / _content / _capability` 列成**各自独立的包**。

W1 已按 §18 把数据模型集中进 `packages/ecosystem/platform`,并按 §9 建了 `packages/ecosystem/capability`
承载能力接口。W2 要落 Gateway / Permission / Task 的行为契约,这条分歧必须定下来,否则每个包都要重新辩论一次,
护栏也无从判定"谁可以依赖谁"。

## 决策

**数据模型集中在 `pure_live_platform`;带运行时状态与依赖注入边界的行为契约按子系统分包。**

| 类型 | 落点 | 例 |
|---|---|---|
| 纯数据模型(可序列化、无运行时资源) | `packages/ecosystem/platform` | ContentRef / MediaTicket / *Descriptor / PermissionGrant / TaskStatus / PlatformErrorInfo |
| 行为契约(接口 + 其实现与其测试夹具) | `packages/ecosystem/<子系统>` | Capability → `capability`;Gateway/Runtime/Source → `extension`;PermissionManager → `permission`;TaskScheduler → `task` |

理由:

1. §18 的伞包若容纳全部行为契约,`pure_live_platform` 会变成全仓的改动汇聚点,且一个只想取 `ContentRef` 的
   feature 会被迫看到 `ExtensionGateway`、`TaskScheduler` 与 `PermissionManager` —— 与 §20"Feature 只消费它
   需要的契约"直接冲突。
2. 行为契约需要向 L0 注入网络/缓存/存储/诊断,而 §18 明确要求 `pure_live_platform` 是零依赖的纯模型包;
   把契约放进去等于要么给它加依赖,要么把契约写成没有依赖可表达的空壳。
3. 分层护栏(§3)判定的是包与包的方向。契约与实现同包,`provider-touches-player`、`import-app` 这类源码级
   检查才有明确的归属对象;全仓一个 contracts 目录时,任何越界都能在同一包名内部自我解释。
4. §9 的包清单是已经写进架构文档的形态,W1 的 `capability` 包已按它落地并验证有效,不再另立第三种形态。

因此 §18 的"伞包"读作**模型伞包 + 各子系统契约包**,`pure_live_platform` 不再新增 `contracts/` 目录。
包名仍以 `pure_live_<短名>` 命名,目录仍是 `packages/<层>/<短名>`(ADR 0015 不变)。

## 后果

- 正:模型只有一个真源,不会出现第二套 `ContentRef`;契约包各自可以依赖 L0 底座并保持纯 Dart。
- 正:护栏的允许依赖矩阵按包生效,新增一个生态包就是一条目录规则,不需要改 `pure_live_platform`。
- 负:一次跨子系统的改动可能触及多个包;`tool/scaffold_package.ps1` 生成骨架并登记 workspace,使新增一个契约包
  的成本与新增一个模型字段相当,以此抵偿。
- 负:`platform-models.md` §18 的包布局示例与实际不再逐字一致,已在该节标注以本文为准,避免后来者按示例目录寻找。
