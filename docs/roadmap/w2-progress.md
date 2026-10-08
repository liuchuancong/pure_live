# W2 进度(Plugin Runtime + Extension Gateway)

> 验收口径来自 [milestones.md](milestones.md) 的 M2:插件装载 / 权限 / 沙箱工作,媒体管线能播一个假源。
> 波次范围来自 [v2-roadmap.md](v2-roadmap.md) W2:ExtensionGateway(注册 / 发现 / 类型识别 / Runtime 选择 /
> 生命周期)、PluginRuntime、Registry、Permission、Sandbox、ExternalRuntime 框架(仅接口)。
> 工程规范按 [../DEVELOPMENT_STANDARDS.md](../DEVELOPMENT_STANDARDS.md);契约落点划分按
> [../adr/0018-contract-package-split.md](../adr/0018-contract-package-split.md)。
> 本文件只记 `v2` 分支的实际状态,不写计划外的乐观结论。

## 1. 已完成的单元

### 1.1 契约落点定稿(ADR 0018)

`platform-models.md` §18 要单一伞包含 contracts,`platform-infrastructure.md` §9 又按子系统列包 —— W2 必须选一个。
已定为:**可序列化数据模型集中在 `pure_live_platform`,带注入边界的行为契约按子系统分包**;
`pure_live_platform` 不建 `contracts/` 目录,§18 原文处标注以 ADR 0018 为准。

### 1.2 `packages/ecosystem/permission`(35 测试)

规范:`platform-contracts.md` §15、`platform-infrastructure.md` §7.2。

| 件 | 内容 |
|---|---|
| 模型侧新增 | `PermissionState` / `PermissionScope` / `PermissionGrant`、`NetworkRequest` / `NetworkResponse`、`Cookie`(models §12) |
| 判定 | `PolicyPermissionManager`:descriptor 是天花板(未声明的权限**不问 prompt 直接拒**)、未注册即无授权、默认 `RejectAllPrompts`(接线漏了等于关闭)、拒绝写记录而 `revoke` 才回到 `unknown`、到期报 `unknown` 而非 `denied`、扩大 host 作用域会重新询问并**合并**而非替换 |
| 网络出口 | `PolicyBackedExtensionNetwork`:先查 grant+target,夹取超时(`NetworkLimits.maxTimeout`),限并发与响应体积,**响应落地后再核 `finalUri`**(重定向是已授权 host 逃到未授权 host 的唯一路径) |
| Cookie | `PolicyBackedCookieStore`:一 extensionId 一 jar,读写需 `Permission.cookie`,`clear` 不需授权(只删数据);值在 `toString` / 诊断视图里脱敏 |
| 端口 | `PermissionStore` / `PermissionPrompt` / `CookieJar` / `NetworkTransport` —— 与 `pure_live_auth` 同一手法,避免 L0/L1 互 import |

错误码只用了 models §14 既有项:`permission.denied`、`permission.restricted`、`network.response_too_large`、
`network.rate_limited`。

`NetworkTransport` 仍无 dio 实现:适配属于组装 `ExtensionContext` 的那一层(随 `ecosystem/extension` 落),
所以本包保持纯 Dart 且策略可离线测。**这条链路目前没有被真实 HTTP 验证过。**

### 1.3 `packages/ecosystem/task`(19 测试)

规范:`platform-contracts.md` §16、`platform-infrastructure.md` §7.3。文档把 TaskScheduler 记在 W3,但
`ExtensionContext` 要注入它,故提前落接口与内存实现。

| 件 | 内容 |
|---|---|
| 模型侧新增 | `TaskDescriptor` / `TaskPriority` / `TaskState` / `TaskStatus` / `TaskResult`(models §13);`TaskStatus` 带 `taskId`(广播流里没有它就无法归属) |
| 契约 | `Task`(descriptor / run / cancel)、`TaskContext`(取消令牌 + 进度上报)、`TaskScheduler`(submit / cancel / pause / resume / find / running / pending / updates)、`TaskHandle` |
| 实现 | `InMemoryTaskScheduler`:优先级槽位调度、`deduplicationKey` 去重(返回同一 handle 而不是起第二个)、终态留存有界(默认 64) |

被测试钉住的规则:

- 取消 = 终态 `cancelled`,结果码 `task.cancelled` 且 `recoverable: true`,`handle.result` **正常 complete 不抛**
  (models §20 不变量 9:取消不是普通失败)。
- `pause` 只对 pending 有效并返回 bool;运行中的协作式暂停契约里没定义,不假装支持。
- 任务 `throw` 与返回 `TaskResult(success: false)` 都记 `failed`,状态不取决于任务选了哪种表达。
- `find()` 的留存有界,而 `TaskHandle` 读自己那条 entry:淘汰动作不得把已完成任务变成假状态。

已知边界(不提前设计):单 isolate 无持久化,进程重启不恢复 pending;
`networkRequired` / `backgroundAllowed` 暂为记录字段,调度器不据此门控 —— 没有设备状态源就判,等于写一段
假装已生效的逻辑;`TaskContext` 也暂不带 `traceId`,理由同上,trace 随 `ecosystem/extension` 的
`ExtensionContext` 一起接。

顺带:护栏新规则当场抓到 scaffold 留下的 `.gitkeep`(task 包两个),已删除 —— 证明该规则会抓到自己的工具。

## 2. 顺带修掉的工程缺陷

| 缺陷 | 处理 |
|---|---|
| `dart format` 不从仓库根 `analysis_options.yaml` 继承 `formatter.page_width`,包目录按默认 80 列跑,而 `docs/development/coding-style.md` 写的是 120 —— W1 的包其实从没按文档格式化过 | `analysis_options.package.yaml` 补 `formatter.page_width: 120`(经实测:`include` 链上的 formatter 设置**会**被读到),全量重格式化并加 CI 步骤 `--set-exit-if-changed`(范围 = `packages` + 两个护栏脚本;`tool/probes/**` 是 v1 opt-in 探针,顺手改到的格式化已还原) |
| 10 个包的 `lib/src/.gitkeep` 在目录已有真实文件后仍留存 | 删除;护栏新增 `stale-scaffold-marker` 规则,并在回归里加"占位符留在已填充目录必须报错"的用例(fixture 生成器同步改成写真实文件时不再放占位符,免得 import 用例顺带触发别的规则) |
| `coding-style.md` 写"中文注释",与 `DEVELOPMENT_STANDARDS.md` §4"代码注释一律英文"冲突 | 以 DEVELOPMENT_STANDARDS 为准:代码注释英文,`docs/` 与包 README 中文;已改写该条 |
| W1 记录里 "241 测试" 是逐包数字加错(实际 194) | 已在 w1-progress.md 更正,并改为按逐包实跑数字记录 |

## 3. 验证证据

| 命令 | 结果 |
|---|---|
| `packages/ecosystem/permission` → `dart analyze` / `dart test` | No issues found;**35 全绿** |
| `packages/ecosystem/task` → `dart analyze` / `dart test` | No issues found;**19 全绿** |
| `packages/ecosystem/platform` → `dart analyze` / `dart test` | No issues found;**82 全绿**(新增 permission/network/cookie 31 条 + task 13 条) |
| 仓库根 `dart analyze .` | **No issues found!** |
| `dart run tool/check_architecture.dart --strict` | `packages=23 errors=0 warnings=0` |
| `dart format --output=none --set-exit-if-changed packages` | 102 文件 0 changed(收敛稳定) |
| `tool/test_check_architecture.ps1` | **PASS: 19 assertions across 17 cases**(含新增 stale-scaffold-marker 反例) |
| `dart run tool/check_workflow_yaml.dart` | 4 个 workflow/action 文件解析通过 |
| 护栏非空转验证 | 临时放置 `packages/foundation/utils/lib/src/.gitkeep` → 报 `stale-scaffold-marker` 且 `errors=1`,删除后回 0 |

## 4. 余下项(W2 未完成部分)

1. `packages/ecosystem/extension`:`Extension` / `ExtensionHandle` / `ExtensionRuntime` / `RuntimeInstance` /
   `Source` 契约、`ExtensionGateway` 实现(注册、`canHandle` 选择、生命周期状态机、`incompatible` 与结构化错误)、
   `ExtensionContext` 注入边界与 dio 版 `NetworkTransport` 适配。
2. `packages/ecosystem/plugin_api` + PluginRuntime / ScriptSandbox **接口**(JS 装载与沙箱实现随 W10)。
3. M2 的另一半"媒体管线能播一个假源"属 W3,未开始。
4. 权限、网络与任务至今只有离线断言;真实站点(403 / 重定向 / 超大响应)要在 W4 Bilibili 参考实现上跑一次才算验收。
