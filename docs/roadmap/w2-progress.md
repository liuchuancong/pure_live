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

### 1.4 `packages/ecosystem/extension`(27 测试)

规范:`platform-contracts.md` §4/§6/§7/§8/§19、`platform-infrastructure.md` §3。

| 件 | 内容 |
|---|---|
| 契约 | `Extension` / `ExtensionHandle` / `ExtensionRuntime` / `RuntimeInstance` / `Source` / `ExtensionGateway` / `ExtensionGatewayException` |
| 状态机 | `register → identified`(无匹配 Runtime 或 API 版本不合 → `incompatible` 并**留记录可查**);`load: identified/error → loading → validating → ready`;`start: ready → running`;`stop: running → stopping → ready`;`disable` 停+dispose 保留记录;`unload` 删记录 |
| 运行时选择 | `RuntimeRegistry`:按 `canHandle` 取首个匹配,同 id 覆盖(协议实现可升级) |
| 注入边界 | `ExtensionContext`(network / cookies / permissions / tasks / cache / storage / diagnostics);cache 与 storage 是**按扩展构造的视图**,隔离不依赖扩展自己写对命名空间 |
| 观测 | 每次状态变化 = 一条 `ExtensionStatus`(stream)+ 一条 `extension.<state>` 诊断事件,同源产生 |

对契约示例的两处有意形状差异(已写进包 README 与本文):`ExtensionRuntime` 用 `RuntimeDescriptor` 代替
裸 `id/version`;`load(descriptor, context)` 多了 context —— §19 规定服务只能经 `ExtensionContext` 取得,而
构造扩展实例的正是运行时。`changes` stream 同理:§17 要求 `extension.load/error` 可观测,不该让调用方轮询。

新增三个生命周期错误码并回写 models §14:`extension.disabled` / `extension.state_invalid` /
`extension.already_registered`。

**ADR 0019**:网关装配 `ExtensionContext` 需要 `pure_live_permission` 与 `pure_live_task`,而三者同层。
选择在护栏里白名单这一条定向边(而不是在网关内重抄一份 PermissionManager/TaskScheduler 接口 —— 那会变成同一
契约的两份拷贝,漂移了编译期看不出来),并用两条回归用例钉住范围:网关走这条边必须通过,**别的生态包走同一
条边必须报 `layer-direction`**。

### 1.5 `packages/ecosystem/plugin_api`(24 测试)

规范:`plugin-contract.md` §1/§2、`plugin-manifest.md` §1-3、`plugin-lifecycle.md` §1-2、
`plugin-permission.md` §1、`plugin-sandbox.md`、`provider-contract.md` §2(HostBridge)。

| 件 | 内容 |
|---|---|
| 现在就能强制 | `PluginManifestValidator`:未知能力名 / 未知权限名 / apiVersion 超出 min-max 区间 / id 不是反向域名形状 / 没有任何能力声明 → **拒绝安装**并给出结构化 `PluginIssue`(`plugin.unknown_capability`、`plugin.unknown_permission`、`plugin.api_incompatible`、`plugin.id_shape`、`plugin.no_capabilities`、`plugin.manifest_invalid`) |
| 词表桥接 | 清单 → 网关要的 `ExtensionDescriptor`:`type=plugin`、`protocol=pure_live_plugin`、`platformApiVersion=apiVersion`、权限表解析成 `Set<Permission>` 作为天花板。于是"Manifest 不能动态扩权"在 permission 包里就有机械执行 |
| 生命周期 | `PluginLifecycle` 迁移表:`installed → verified → loaded → initialized → enabled ⇄ disabled`,**disabled 回 enabled 必须重过 initialized**(桥要重注入、权限按当时声明重认);表里没有的转移抛 `PluginLifecycleException`;`uninstalled` 无后继;每次合法转移回调 `onChanged`(§2 要求发事件) |
| 接口(仅接口) | `PluginRuntime`(native/js/data 共同形状)、`HostBridge` + `PluginNetwork` / `PluginCookieAccess` / `PluginKvStore` / `PluginEventSink`、`ScriptSandbox` / `ScriptSandboxFactory` / `SandboxPolicy`(默认拒绝 fs / 进程 / native API / FFI / 系统命令 / 任意 socket)/ `SandboxLimits`(超时、输出体积、并发) |

依赖方向:plugin_api 只依赖 `pure_live_platform`,**不**依赖 `pure_live_extension` / `pure_live_permission`。
桥接口的类型全是平台模型(`NetworkRequest` / `NetworkResponse` / `Cookie`),所以既没有第二套词表,也没有
同层边;把 `ExtensionNetwork` 适配成 `PluginNetwork` 是宿主(同时接两边)的活。理由写在
`packages/ecosystem/plugin_api/README.md`:JS 插件不可能持有 Dart 的 `ExtensionNetwork` 对象,桥本来就是
子集。

## 2. 顺带修掉的工程缺陷

| 缺陷 | 处理 |
|---|---|
| 权限词表三处不一致:`plugin-permission.md` §1 写 `cookies`(枚举是 `cookie`),并要求 `filesystem` / `location`(枚举里没有);`capability-contract.md` §1 写 `lyric`(`ExtensionCapability.lyrics`) | 以枚举为规范名,别名在 `PluginManifestValidator.permissionAliases` / `capabilityAliases` 映射;`filesystem` 与 `location` 按 append-only 追加进 `Permission`;三处文档各自标注以谁为准,并说明改文档必须同时改两侧测试 |
| `plugin-manifest.md` §1 的示例声明 `danmaku` / `comment` / `subtitle` / `auth`,而粗路由集 `ExtensionCapability`(platform-contracts §5)没有这些项 —— 按"未知能力名一律拒绝"的字面读法,**文档自己的示例会被自己的校验器拒绝** | 拆成两件事:插件面名单(§1,22 项)决定"是否合法声明",平台路由集决定"有没有路由条目"。校验器按前者拒绝、按后者映射,`pure_live_plugin_api` README 与 capability-contract §5 都写清了这个区分 |
| 包 README 手写时把公共面写成 `lib/pure_live_plugin.dart`(实际是 `lib/pure_live_plugin_api.dart`) | 已改正 |
| `dart format` 不从仓库根 `analysis_options.yaml` 继承 `formatter.page_width`,包目录按默认 80 列跑,而 `docs/development/coding-style.md` 写的是 120 —— W1 的包其实从没按文档格式化过 | `analysis_options.package.yaml` 补 `formatter.page_width: 120`(经实测:`include` 链上的 formatter 设置**会**被读到),全量重格式化并加 CI 步骤 `--set-exit-if-changed`(范围 = `packages` + 两个护栏脚本;`tool/probes/**` 是 v1 opt-in 探针,顺手改到的格式化已还原) |
| 10 个包的 `lib/src/.gitkeep` 在目录已有真实文件后仍留存 | 删除;护栏新增 `stale-scaffold-marker` 规则,并在回归里加"占位符留在已填充目录必须报错"的用例(fixture 生成器同步改成写真实文件时不再放占位符,免得 import 用例顺带触发别的规则) |
| `coding-style.md` 写"中文注释",与 `DEVELOPMENT_STANDARDS.md` §4"代码注释一律英文"冲突 | 以 DEVELOPMENT_STANDARDS 为准:代码注释英文,`docs/` 与包 README 中文;已改写该条 |
| W1 记录里 "241 测试" 是逐包数字加错(实际 194) | 已在 w1-progress.md 更正,并改为按逐包实跑数字记录 |

## 3. 验证证据

| 命令 | 结果 |
|---|---|
| `packages/ecosystem/permission` → `dart analyze` / `dart test` | No issues found;**35 全绿** |
| `packages/ecosystem/task` → `dart analyze` / `dart test` | No issues found;**19 全绿** |
| `packages/ecosystem/extension` → `dart analyze` / `dart test` | No issues found;**27 全绿**(网关与真实 permission/task 包一起跑,ADR 0019 那条边因此不只是纸面可用) |
| `packages/ecosystem/platform` → `dart analyze` / `dart test` | No issues found;**80 全绿**(W1 的 37 + permission/network/cookie 31 + task 12) |
| 逐包全量跑(21 个有测试的包,`dart test -j 1`) | **全部 All tests passed**;合计 **408 测试** = L0 194 + platform 80 + capability 29 + permission 35 + task 19 + extension 27 + plugin_api 24 |
| 仓库根 `dart analyze .` | **No issues found!** |
| `dart run tool/check_architecture.dart --strict` | `packages=25 errors=0 warnings=0` |
| `dart format --output=none --set-exit-if-changed packages tool/check_*.dart` | 123 文件 0 changed(收敛稳定) |
| `tool/test_check_architecture.ps1` | **PASS: 21 assertions across 19 cases** —— 含 stale-scaffold-marker 反例、ADR 0019 白名单"网关可走 / 别家走同一边必须报错"两条 |
| `dart run tool/check_workflow_yaml.dart` | 4 个 workflow/action 文件解析通过 |
| 护栏非空转验证 | 临时放置 `packages/foundation/utils/lib/src/.gitkeep` → 报 `stale-scaffold-marker` 且 `errors=1`,删除后回 0 |

## 4. 余下项(W2 未完成部分)

> 环境注意(会影响后续会话):本机 `dart test` 默认并发**间歇性**报
> `HandshakeException: Connection terminated during handshake`(无栈、`dart analyze` / `dart run` 正常),
> 加 `-j 1` 即稳定通过。全仓逐包验证请用 `dart test -j 1`;这不是包的失败,别照着它去改代码。

1. `packages/ecosystem/plugin_api` + PluginRuntime / ScriptSandbox **接口**(JS 装载与沙箱实现随 W10)。
2. M2 的另一半"媒体管线能播一个假源"属 W3,未开始。
3. `NetworkTransport` 的 dio 适配(架在 `pure_live_network` 上)与 `ExtensionCache` / `ExtensionStorage` 的持久
   实现尚未落地:网关目前用内存默认实现,所以权限、网络、任务与网关四条都只有离线断言;真实站点
   (403 / 重定向 / 超大响应)要在 W4 Bilibili 参考实现上跑一次才算验收。
4. `ExtensionGateway.supportedApiVersions` 默认为空 = 不做版本检查;插件一旦能声明 `platformApiVersion`,
   组合根必须显式给出接受范围,否则 platform-contracts.md §23 的兼容性判定形同不存在。
