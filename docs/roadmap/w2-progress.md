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

### 1.4 `packages/ecosystem/extension`(W2 波内 27 测试 → 现 53,见 §1.6 与 w3-progress)

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

### 1.6 W2 收尾:持久 KV 底座与落盘视图(storage +18、extension +19 测试)

§4 原第 2 条(持久实现)与第 1 条(plugin_api 接口)一起收掉:第 1 条其实在 W2 波内就落了
(`plugin_runtime.dart` / `host_bridge.dart` / `sandbox.dart` 三件都在包里),此前只是清单没跟着改。

**`pure_live_storage` 的 `FileKeyValueStore`**(单文件 JSON,首次访问载入、写穿、串行队列):

- 写 = 写临时文件 + `rename`。改名覆盖已存在目标在 Windows 上是**可用**的(先探过再写代码),所以不需要
  "先删再改"这种会把窗口期变成"文件不见了"的写法。
- **读不懂就不覆盖**:文件存在但不是对象形状 → `StoreCorruptedException`,之后的 `write` 同样拒绝。
  空文件是唯一例外(那是首次写入中途被杀留下的,里面从来没有数据)。
- **编码失败 = 什么都没发生**:先编码候选 map 再动内存与磁盘。测试的钉子是"写入 `DateTime` 之后,原来的值还在、
  新键不在 `keys()` 里、文件字节与之前逐字相同"。
- 所有操作走一条队列(`_serialised`),失败的操作不卡死队列(有专门一条测试)。

**`pure_live_extension` 的 `PersistentExtensionCache` / `PersistentExtensionStorage`**(§19 的"实现可换而
Extension API 不变"第一次真的被换过一次):

- 命名空间 `extension.<id>.cache.<key>` / `extension.<id>.storage.<key>`,前缀由视图添加。所以"隔离"不靠调用方
  传对字符串:扩展就算把别人的属主写进键名(`extension.B.cache.token`),得到的仍是自己名下的那一个键。这条有测试。
- TTL 存**到期时刻**而不是时长:存时长的话,重启后的进程会拿自己的时钟重新计时,等于每次都把 TTL 续满。
- 缓存行读不懂 → 按未命中处理并**删掉那一行**,而不抛错:错的未命中代价是回源一次,抛错的代价是扩展起不来。
  `ExtensionStorage` 不做这种宽容(设置读不出来是事故,不是缓存失效)。
- 视图只收可 JSON 序列化的值,写不下当场 `ArgumentError`;内存视图没有这条限制 —— 这是两者唯一的语义差异,
  而它必须在这里失败,不能等重启后那一行悄悄消失。
- 网关加了 `cacheFactory` / `storageFactory`,**默认不变**(内存、随记录丢弃,原有那条"重载不继承上次缓存行"
  的测试仍然绿),所以本条没有改变任何现有扩展的行为。集成测试把两个网关接同一个 store,证明设置与缓存行都能
  跨"重启"读回,且另一个扩展名下的视图读不到。

一处**被测出来而不是想出来**的缺陷:`keys()` 最初用 `read()` 投影,于是"存了 null 的行"被当成"没有这一行"筛掉,
而内存视图会把它列出来。改成内部 `_Row(present, value)` 把"存在"与"值非空"分开,并补了一条
`test_keys_keepsARowWhoseValueIsNull`。

一处文档与实现的**命名分歧**:platform-contracts.md §19 把这两件叫 `PlatformCache` / `PlatformStorage`,
而代码、ADR 0019 与网关字段用的是 `ExtensionCache` / `ExtensionStorage`。以代码名为准(改名会牵动已发布契约面),
分歧已在 §19 就地标注。

### 1.7 组合根重建:apps/pure_live 装起 v2 运行时(app 侧 7 测试)

w1-progress 待办 7 写的是"分支**不可运行** …… 可运行性随 W2 运行时与组合根重建恢复"。W2 与 W3 都没有做这件事,
所以它一直是欠着的:W1 搬家之后 `apps/pure_live/lib/` 只剩 artisan 生成的两个空文件,没有 `main.dart`,
app 的 pubspec 也没引用 v2 栈里任何一个包 —— 换句话说 W2/W3 交付的那些包**没有任何一处被装起来过**。

本增量按 [runtime.md](../architecture/runtime.md) §1 的冷启动顺序落了它已有代码支撑的那几段:

| 段 | 装配 |
|---|---|
| CacheRuntime(部分) | `FileKeyValueStore`(仓库根数据目录下的 `extensions.json`)+ 每扩展 `PersistentExtensionCache` / `PersistentExtensionStorage` |
| DiagnosticRuntime(部分) | `InMemoryDiagnosticTracer`(512 条环形) |
| Permission | `PolicyPermissionManager` + `InMemoryPermissionStore` |
| Network | `NetworkClient` → `NetworkClientTransport` → `PolicyBackedExtensionNetwork`(权限门在这条链的最前面) |
| Cookie | `PolicyBackedCookieStore` + `InMemoryCookieJar` |
| PluginRuntime / CapabilityRuntime | `ManagedExtensionGateway`(带 §1.6 的两道工厂)+ `RuntimeRegistry` + `CapabilityRegistry` |
| Resolver | `ResolverRegistry` + `ResolverChain`(w3-progress §4 说的"没有装配点"从此有了) |
| **MediaRuntime** | **不装**:还没有引擎适配(w3-progress §4),在这里 new 一个 `PlayerKernel` 只是装配一个没人能驱动的对象 |

`main.dart` 先 binding 再 boot(路径解析走平台通道),首帧之前运行时就已经是完整的;`host.dart` 只做一件事 ——
把"装了哪些东西"列出来。它不是 UI:UI 层的波会换掉它,而现在没有它分支就跑不起来。

7 条测试钉的是**只有组合根会错的那类事实**(包测试测不到):

- `identical(context.tasks, runtime.tasks)` 与 `identical(context.permissions, runtime.permissions)`:
  一个进程一个调度器/一个授权器;复制一份就等于把插件的工作放到平台限额之外。
- 未声明 `network` 的扩展调 `context.network.send` → 拿到 `permission.denied` 而**不是**网络错误码,
  也就是说到不了 socket。这是"网关的网络确实用的是这个 permission manager"的唯一可观测证据。
- `resolverChain` 读的确实是同一个 `resolvers` 注册表(空 → `resolver.unsupported`,注册后 → 出票)。
- `supportedApiVersions` 这道门由根决定:默认空 = 不检查;给 `{'2'}` 之后,声明 `1` 的插件在 `register`
  就被拒并且记录停在 `incompatible`,声明 `2` 的正常到 `ready`。
- durability:扩展经 `context.storage/cache` 写的行**落在磁盘上那个 json 里**(断言直接读文件看命名空间键),
  第二次 boot 只共用目录就能读回 —— §1.6 那句"实现可换而 Extension API 不变"到这里才算被真的换过一次。
- 两个扩展共用一个 store 也读不到彼此的行。

### 1.8 顺带挖出的两处工具链失效(都在 W1 那次搬家之后)

这两条不是"改进",是**验证链路本身已经不成立**,所以必须记在进度里:

1. **`tool/flutterw.ps1` 无论调用方在哪,都 `Push-Location $workDir`(= 仓库根)。** ADR 0015 之后 Flutter 项目在
   `apps/pure_live`,于是 `flutter test/analyze` 一律在 hub 上跑:路径解析成 `D:/flutter/pure_live/test/...`
   然后报"Does not exist",而 hub 没有 flutter 依赖,根本不是一个 Flutter 工程。修法是新增
   `Resolve-PureLiveProjectPath`(把调用方目录映射进所选的短路径空间:物理 / junction / SUBST 三种都成立),
   调用方在仓库根时行为**逐字不变**;`tool/test_subst_path.ps1` 加了 6 条不起 Flutter 的用例钉住它,
   其中包括"仓库外的调用目录退回根"这条保守分支。
2. **`ffmpeg_kit_extended_flutter` 的构建钩子把"应用目录"算成 package_config 的上两级**,
   而这条我第一版的处理是错的,连同纠正一起记在这里:
   - 现象:pub workspace 把 `package_config.json` 放在仓库根,钩子于是读到 hub 的 pubspec,拿不到
     `ffmpeg_kit_extended_config`,退回它自己的默认 `base + small`;应用声明的是 `small: false`。
   - 第一版做法(把这段配置镜像到根 pubspec,commit `563a16c5a`)让**文件名**对上了仓库钉的那一份,
     于是暴露出更深的冲突:钩子接着去上游取该文件名的校验和,上游对
     `bundle-base-windows-x86_64-shared-lgpl.zip` 给的是 `ac4f7c68…`,而仓库自己的固定件是 `e61684a9…`
     (`tool/prefetch_android_native.ps1` 的 0.6.2 profile、`tool/verify_ffmpeg_native.py`、
     `tool/build_local_release.ps1` 三处一致,工件来自 `wzgrx/pure_live` 的 `native-ffmpeg-9.0.2-b1` release)。
     钩子据此判定缓存"损坏",**删掉仓库那份 zip** 并要求重下上游版本 —— 这与 BUILD_POLICY 的固定来源要求
     直接冲突,而且会不会发生取决于那一刻连不连得上校验文件所在的主机。
   - 已撤回该镜像(revert `14786aea4`),并用仓库自己的工具把被删的固定件从持久缓存
     `%LOCALAPPDATA%/PureLive/native-cache` 复原(17.2 MB,SHA256 已核对:
     `tool/prefetch_android_native.ps1 -SkipAndroidMedia`)。机器状态不劣于本轮开始之前。
   - 撤回后钩子回到默认的 small 那份:本机没有,而 `objects.githubusercontent.com` 此刻 TLS 握手失败,
     所以 app 侧 `flutter test` 今天过不了原生资源这一步。这是**环境与上游契约**问题,不是 §1.7 的装配问题。
   - 真正的修法要先定 provenance 归属:要么按 `third_party/` 的既有做法给这个插件的钩子打补丁,让它认项目
     自己的固定件;要么改用上游发布的 bundle 并同步改三处哈希。两者都是构建决策,不该由"在根上补一段 yaml"掩盖。

`tool/local_ci.ps1` 的目录适配在同一轮落了(见 §4 第 6 条):`flutter pub get` / `test` / `analyze` 三个阶段
改到 `apps/pure_live` 里执行,格式化改成"只碰自己拥有的路径"的白名单。修好之后 Focused 跑起来不再是"测试文件
不存在",而是进到 app 工程的原生资源构建,并最终停在上面第 2 条那个 FFmpeg 契约上 —— 因此本轮**不声称**
local_ci 端到端通过,只声称它的目录假设已经纠正、失败点已经前移到真实的环境问题上。

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
| `tool/flutterw.ps1` 把 Flutter 工程固定在仓库根,ADR 0015 之后 app 侧任何 `test`/`analyze` 都跑不起来 | 见 §1.8(1):新增 `Resolve-PureLiveProjectPath` + 6 条用例 |
| FFmpegKit 构建钩子在 workspace 下读不到应用配置,退回默认 bundle 并联网重下 | 见 §1.8(2):根 pubspec 镜像该配置段,并写明权威在哪一侧 |

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

W2 收尾(§1.6)复跑:

| 命令 | 结果 |
|---|---|
| `packages/foundation/storage` → `dart analyze .` / `dart test -j 1` | No issues found;**34 全绿** = 原有 16 + `FileKeyValueStore` 18 |
| `packages/ecosystem/extension` → `dart analyze .` / `dart test -j 1` | No issues found;**53 全绿** = 原有 34 + 持久视图 18 + 网关接缝集成 1 |
| 磁盘行为依赖的平台事实 | Windows 上 `File.rename` **可以**覆盖已存在的目标(先探针验证再写实现),所以"临时文件 + rename"不需要先删目标 —— 那会把窗口期变成"文件不见了" |
| 护栏与格式化 | 见 [w3-progress.md](w3-progress.md) §3:resolver 波之后 `packages=26 errors=0`、`142 文件 0 changed`、护栏回归 21 例 23 断言全过 |

组合根(§1.7)验证 —— 全部经 `tool/build_resource_guard.ps1` 的租约,`tool/flutterw.ps1` 在 `apps/pure_live` 下执行:

| 命令 | 结果 |
|---|---|
| `apps/pure_live` → `flutter pub get --offline` | Got dependencies(新增 8 个 workspace 路径依赖) |
| `apps/pure_live` → `flutter test --no-pub test/runtime_assembly_test.dart` | **7 全绿**(装配 4 + 持久化 2 + 宿主 widget 1) |
| `apps/pure_live` → `flutter analyze --no-pub` | No issues found(修掉两条:一处未用 import、一个未用测试参数) |
| FFmpegKit 原生资源 | 见 §1.8(2):钩子要的是上游 small 那份,本机既没有也下不到;仓库固定的非 small 那份已用 prefetch 复原 |
| `tool/local_ci.ps1 -Scope Focused -TestPath test/runtime_assembly_test.dart -SkipPubGet -Analyze` | 失败点已从"测试文件不存在"前移到 app 的原生资源构建(证明目录修复生效),最终因 FFmpeg 契约停下(§1.8(2)) |
| `tool/prefetch_android_native.ps1 -SkipAndroidMedia` | exit 0;Verified `bundle-base-windows-x86_64-shared-lgpl.zip`(复原被钩子删除的固定件) |
| `tool/test_subst_path.ps1` | PASS:8 条 SUBST + 6 条 project-path + wrapper syntax |
| `dart analyze packages` / `--strict` 护栏 / 格式化 | No issues found;`packages=26 errors=0`;显式路径 153 文件 0 changed |
| **仍未通过** | `tool/local_ci.ps1` 目录假设已纠正,但 Focused 停在 FFmpeg 原生资源(§1.8(2)),所以端到端未通过;分支现在**能编译、能起**(此前不能),但**没有做过设备/构建验收** |

## 4. 余下项(W2 未完成部分)

> 环境注意(会影响后续会话):本机 `dart test` 默认并发**间歇性**报
> `HandshakeException: Connection terminated during handshake`(无栈、`dart analyze` / `dart run` 正常),
> 加 `-j 1` 即稳定通过。全仓逐包验证请用 `dart test -j 1`;这不是包的失败,别照着它去改代码。

1. ~~`packages/ecosystem/plugin_api` + PluginRuntime / ScriptSandbox **接口**~~ —— 已落(§1.5,三件接口都在包里);
   JS 装载与沙箱**实现**随 W10。
2. ~~`ExtensionCache` / `ExtensionStorage` 的持久实现~~ —— 已落(§1.6)。底座选的是 `pure_live_storage` 的
   `FileKeyValueStore` 而不是 Drift:Drift 是应用组合根的选择,生态层要的是 `KeyValueStore` 接口。
3. `NetworkTransport` 的 `pure_live_network` 适配**已落**(`extension` 的 `NetworkClientTransport`),但它和
   权限、网络、任务、网关一样只有离线断言:测试用的是脚本化 adapter。真实站点
   (403 / 重定向 / 超大响应)要在 W4 Bilibili 参考实现上跑一次才算验收。
4. M2 的另一半"媒体管线能播一个假源"已在 W3 达成(接线层),见 [w3-progress.md](w3-progress.md) §2.2。
5. `ExtensionGateway.supportedApiVersions` 默认为空 = 不做版本检查;插件一旦能声明 `platformApiVersion`,
   组合根必须显式给出接受范围,否则 platform-contracts.md §23 的兼容性判定形同不存在。
6. `tool/local_ci.ps1` 的目录假设**已纠正**(§1.8(1)):Flutter 三个阶段改在 `apps/pure_live` 里跑,格式化改成
   "只碰自己拥有的路径"的白名单(packages / apps/pure_live 的 lib+test / tool),并排除 `*.g.dart`、`/build/`、
   `/.dart_tool/`、`/generated/` —— 旧的黑名单还写着搬家前的 `plugins/built_in_kotlin/`,那正是误格式化 53 个
   vendored 文件的成因。**仍欠两笔**:端到端跑通被 §1.8(2) 的 FFmpeg 契约挡住;以及"改了依赖必须重写锁文件"
   没有开关(现在固定 `pub get --enforce-lockfile`)。
7. **FFmpeg 原生工件的 provenance 归属要有人定**(§1.8(2)):插件钩子按上游校验和验收,仓库钉的是自己重烤的
   `native-ffmpeg-9.0.2-b1` 工件,两者对同一个文件名给出不同哈希。不解决就会在"能连上校验主机"的那次构建里
   悄悄删掉固定件、换回上游版本。
8. 组合根只装到 §1.7 那张表的范围:`InMemoryPermissionStore` 让授权与拒绝**活不过重启**(每次开机重新问一遍),
   `MediaRuntime` 没有装(没有引擎适配),`RuntimeRegistry` 是空的(没有运行时可注册)。前两条各有明确落点,
   第三条随 W3 的引擎适配。
9. 落盘视图留了两处口子(§1.6 里也写了,记在这里是为了不让它被当成已解决):
   - **卸载不清 data**:`ExtensionStorage` 契约没有 `clear()`(§19 就没有),网关也只有 `unload` 不叫 uninstall。
     清理只能由持有 `KeyValueStore` 的一方按 `ExtensionNamespace` 前缀做,而那需要一个真正的卸载入口。
   - **磁盘缓存没有条数上限**:过期只在读这一行或列键时被剔除。AGENTS.md 把"有界缓存"列为要守的性质,而策略该是
     哪种(按属主分桶的 LRU、需要写入时间戳;还是宿主定期 prune)要等 W4 的 Bilibili 参考插件真的用上缓存再定,
     现在定等于猜。
