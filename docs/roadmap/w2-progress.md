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

### 1.2 `packages/ecosystem/permission`(W2 波内 35 测试 → 现 46,持久 grant 见 §1.9)

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
     所以 app 侧 `flutter test` 当时过不了原生资源这一步。这是**环境与上游契约**问题,不是 §1.7 的装配问题。
   - 收尾(本轮):provenance 归属不再"等人定",因为插件本来就留了正确的口子 —— `hook/build.dart:237` 读
     `config[targetOS.name]` 作为该平台的工件来源,值既可以是 URL 也可以是**本地路径**,而本地分支
     (`hook/build.dart:260-276`)只做"存在即按大小比对后拷进它自己的缓存目录",**既不联网也不取上游校验和**。
     于是两 pubspec 的 `windows`/`android` 键改成本地相对路径 `native-assets/…`:
     - URL override 也被排除,因为它每次构建都重下(`hook/build.dart:251-258`),把 app 侧验证绑在网络健康上;
     - 不带 override 的默认分支更危险:它在缓存件已存在时仍去取上游 `sha256.txt`,与本仓库钉的 `e61684a9…`
       必然不符,判定"损坏"就删件(`hook/build.dart:333-350`)—— 是否触发取决于那一刻连不连得上,
       这正是 §1.8(2) 一开始把固定件弄丢的机制;
     - 来源因此**由本仓库钉死**:`tool/prefetch_android_native.ps1` 的 0.6.2 profile 校验哈希后把工件落进
       `native-assets/`(不入库,已加 `.gitignore` 规则),钩子只从那里取;`tool/verify_ffmpeg_native.py` 与
       `tool/build_local_release.ps1` 继续复核钩子真正消费的目录,三层各司其职。
   - **代价是一条顺序约束**:`native-assets/` 不入库,新克隆或 `flutter clean` 之后必须先跑 prefetch 再跑
     test/build,否则钩子报 `Local override not found`。`tool/local_ci.ps1` 与 `tool/build_local_release.ps1`
     都已经在 Flutter 阶段之前调用它,所以这条在既定入口里自动成立;裸敲 `flutter test` 才会撞上,报错也是
     指名道姓的缺件,不是网络超时。
   - 预取脚本顺带修了一处会静默混件的旧逻辑:版本戳原来只记在 `windows/` 子目录、只删解包目录,而不同
     builder 版本的 zip/aar **同名**,靠大小比对认不出来。现在戳记在缓存根,版本一变就把 windows+android
     两份派生缓存整体丢弃(路径仍在白名单内才动手),由钩子重新从 `native-assets/` 拷入。

`tool/local_ci.ps1` 的目录适配在同一轮落了(见 §4 第 6 条):`flutter pub get` / `test` / `analyze` 三个阶段
改到 `apps/pure_live` 里执行,格式化改成"只碰自己拥有的路径"的白名单。上面第 2 条收口之后,这条链路第一次
端到端跑通:`-Scope Focused -TestPath test/runtime_assembly_test.dart -OfflinePub -Analyze` 依次通过锁定解析、
原生资源预取、8 条组合根测试与 `flutter analyze`(§3 那张表有数值)。**仍然**没有设备/构建验收 ——
Focused 证明的是"装得起来、测得动",不是"能在真机上播"。

### 1.9 授权记录持久化(permission +11 测试,组合根改用持久 store)

§4 第 8 条的那笔欠账(每次开机把授权与拒绝问一遍)收掉:`KeyValuePermissionStore` 把 grant 存进
`pure_live_storage` 的 `KeyValueStore`,组合根现在写 `permissions.json`。选文件而不是 Drift 的理由与 §1.6 一样:
生态层要的是接口,后端是组合根的决定。

三件事值得单独写:

1. **键形状不是可有可无的**。扩展 id 本身是反向域名(`purelive.bilibili`),所以 `permission.<id>.<name>`
   这种前缀扫描会让清理 `purelive.a` 顺手删掉 `purelive.ab` 的全部授权。分隔符改成 `/`
   (`permission.<id>/<name>`),并有一条测试专门用这对会混的 id 钉住它。
2. **读不懂的记录按"没问过"处理并删掉**。留着它意味着每次加载都要重新决定怎么处理一条永远解析不了的记录;
   而把它当成 grant 是反方向的错(等于凭空授权)。`unknown` 是唯一还能被回答的状态。
3. **持久化让"默认拒绝"这个占位实现变得危险**。端口的规则是拒绝留存,而 manager 对已记录的 `denied`
   **不再重问**(那是设计意图:有人说过不要)。内存 store 时 `RejectAllPrompts` 只是fail-closed;
   store 一旦持久,它答出来的 `denied` 会被写下来 —— 于是"没人替用户做过决定"变成"用户做过否定决定",
   重启仍然成立,而没有 UI 的现在没有 `revoke` 的入口。所以新增 `UnaskedPrompts`(答 `unknown`:这次拒绝,
   但不冒充用户的选择),并把它作为组合根的默认;这条推论写进了包 README 的规则 4。

组合根侧加了 `boot(permissionPrompt:)` 接缝,并加了一条 app 测试(`purelive.grantor` 授权后重启仍然有效,
且第二个 runtime 用 `UnaskedPrompts` 也不需要重问)。**写这一段时它没跑到**:app 侧 `flutter test` 当时被
§1.8(2) 的 FFmpeg 原生工件卡住(钩子要的 `bundle-base-...-shared-small-lgpl.zip` 本机没有,而
`objects.githubusercontent.com` 那时连 TLS 握手都过不去,报 `HttpException: 信号灯超时时间已到`)。
所以那一轮对 app 的验证只有静态的 `flutter analyze`(No issues found),运行时验证与那条测试一起等工件落定;
store 本身的行为由 permission 包的 11 条测试覆盖,其中一条直接用 `FileKeyValueStore` 走真实文件往返。
**该等待已在 §1.8(2) 收尾时结束**:`test_grantedPermission_stillHoldsAfterAReboot` 现在真跑过并通过(§3),
这条记录的"未验证"状态随之作废 —— 保留原文是为了记下当时的结论是怎么被环境挡住又解开的。

### 1.10 迁移流程落地(storage +10 测试,共 44)

做 W5 的历史/收藏时撞上一个空档:`docs/migration/*.md` 写的是**流程 + 键名表**,而 `pure_live_storage` 里只有
`SettingsMigrator`(键映射执行器)与 `SchemaMigrator`(版本步进),没有"确认 → 逐域 → 计数校验 → 标记完成"这一层。
键名表这次**没有实现**:v1 的具体键不在本仓(legacy 已删),编一组出来测试会全绿、真迁移会全错。
所以落的是流程,键名留给各域自己的 spec 带。

三条值得单独说的:

- **"v1 只读"是结构,不是注释**。`MigrationDomainSpec` 只给一个 `read`(流)与一个"写 v2"的回调,迁移器拿不到
  改 v1 的手 —— 文档把这条列为原则,靠 API 形状守比靠自觉可靠。
- **断点续迁靠日志,不靠幂性等对方**。`KeyValueMigrationJournal` 记每域已迁键与已完成域:reader 半路断掉时,
  已写的键先落账,重试就只补剩下的(有测试:第一次写 r1/r2,重试只写 r3,且 r1/r2 不再写);
  已完成的域连读都不读。代价也写了:键值后端要带一份键列表,Drift 绑定该换成按行标记 —— 换的是这个类。
- **单条失败 ≠ 域失败**。映射抛 `MigrationReject` 或随便抛什么,都只是那一行进"待处理"桶,域照常完成;
  而"写 v2 失败"的记录**不记账**,下次重试会再试它一次。计数不平(`scanned != migrated + rejected`)或
  `expectedCount` 不符时该域不标记完成,并出现在 `discrepancies` 里 —— 这正是 database-migration.md 第 4 步。

确认默认 `false`:向导没拿到"是"就一个字节都不动(v1-to-v2.md 的"绝不清空"在这层的形状)。

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
| FFmpegKit 构建钩子在 workspace 下读不到应用配置,退回默认 bundle 并联网重下 | 见 §1.8(2):根 pubspec 镜像该配置段并写明权威在哪一侧,再把 `windows`/`android` 两个键钉成 `native-assets/` 的**本地路径 override** —— 钩子既不联网也不按上游校验和删件 |

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
| `packages/foundation/storage` → `dart analyze .` / `dart test -j 1` | No issues found;**44 全绿** = 原有 16 + `FileKeyValueStore` 18 + `MigrationRunner` 10 |
| `packages/ecosystem/extension` → `dart analyze .` / `dart test -j 1` | No issues found;**53 全绿** = 原有 34 + 持久视图 18 + 网关接缝集成 1 |
| 磁盘行为依赖的平台事实 | Windows 上 `File.rename` **可以**覆盖已存在的目标(先探针验证再写实现),所以"临时文件 + rename"不需要先删目标 —— 那会把窗口期变成"文件不见了" |
| 护栏与格式化 | 见 [w3-progress.md](w3-progress.md) §3:resolver 波之后 `packages=26 errors=0`、`142 文件 0 changed`、护栏回归 21 例 23 断言全过 |

组合根(§1.7)验证 —— 全部经 `tool/build_resource_guard.ps1` 的租约,`tool/flutterw.ps1` 在 `apps/pure_live` 下执行:

| 命令 | 结果 |
|---|---|
| `apps/pure_live` → `flutter pub get --offline` | Got dependencies(新增 8 个 workspace 路径依赖) |
| `apps/pure_live` → `flutter test --no-pub test/runtime_assembly_test.dart` | **8 全绿**(装配 4 + 持久化 3 + 宿主 widget 1);§1.9 之后多了"grant 活得过重启"这一条 |
| `apps/pure_live` → `flutter analyze --no-pub` | No issues found(修掉两条:一处未用 import、一个未用测试参数) |
| FFmpegKit 原生资源 | 见 §1.8(2):钩子改走**本地路径 override**,从 `native-assets/` 拷件,全程不联网、不取上游校验和;日志行为 `Using local override path: native-assets/bundle-base-windows-x86_64-shared-lgpl.zip` |
| `tool/local_ci.ps1 -Scope Focused -TestPath test/runtime_assembly_test.dart -OfflinePub -Analyze` | **exit 0**,首次端到端通过:锁定解析 → prefetch(先于 Flutter 阶段)→ 8 测试全绿 → analyze `No issues found`,质量记录 `local-artifacts/build-records/20261009T040959920Z-quality-focused.json`。`-SkipPubGet` 会正确拒绝(依赖清单已改),所以这轮用 `-OfflinePub` |
| `tool/prefetch_android_native.ps1 -SkipAndroidMedia` | exit 0;`Verified bundle-base-windows-x86_64-shared-lgpl.zip` —— 从持久缓存按 `e61684a9…` 复核后落进 `native-assets/`,同时清掉上一轮 small 回退留下的派生缓存 |
| `packages/ecosystem/permission` → `dart analyze .` / `dart test -j 1` | No issues found;**46 全绿** = 原有 35 + 持久 grant 11(含一条真文件往返) |
| §1.9 的 app 侧 | `flutter analyze` No issues found;`flutter test` **8 全绿**,其中 `test_grantedPermission_stillHoldsAfterAReboot` 是真跑过的 —— 上一轮它只被静态读过 |
| `tool/test_subst_path.ps1` | PASS:8 条 SUBST + 6 条 project-path + wrapper syntax |
| `dart analyze packages` / `--strict` 护栏 / 格式化 | No issues found;`packages=26 errors=0`;显式路径 153 文件 0 changed |
| **仍未通过** | 没有**设备/构建验收**:Focused 证明的是装得起来、测得动,不是真机能播;原生工件的 macOS/iOS/Linux 三支仍走各自默认路径,没有像 windows/android 一样钉到本地 override |

FFmpeg 收口(§1.8(2) 收尾)复跑:

| 命令 | 结果 |
|---|---|
| `tool/prefetch_android_native.ps1 -SkipAndroidMedia` | exit 0,两条 `Verified` 全部命中持久缓存,**零网络请求**;`native-assets/bundle-base-windows-x86_64-shared-lgpl.zip` 就位 |
| `apps/pure_live` → guarded `flutter pub get --offline` + `flutter test --no-pub test/runtime_assembly_test.dart` | exit 0,8 全绿;钩子日志 `Using local override path: native-assets/…`(上一轮同一行是 `Using remote override URL: …` 然后 `SocketException … github.com`) |
| 工件完整性 | `native-assets/` 里那份 zip 的 SHA256 = `e61684a9…`,与 prefetch profile、`tool/verify_ffmpeg_native.py`、`tool/build_local_release.ps1` 三处钉的一致;钩子拷进自己缓存目录后由后两个工具复核 |
| 冷启动(清空 `ffmpeg_kit_cache/` 后) | `tool/prefetch_android_native.ps1 -SkipAndroidMedia` 重建空缓存根 → guarded `flutter test --no-pub` 仍 8 全绿;钩子自己从 `native-assets/` 拷件并解包,等价于 `flutter clean` 之后的第一次构建 |
| `git check-ignore native-assets/…zip` | 命中 `.gitignore:46:/native-assets/`,17.2 MB 的二进制不进库 |
| `dart run tool/check_architecture.dart --strict` | `packages=32 errors=0 warnings=0`(§1.7 那张表写的 26 是当时的包数,identity/services 落完已涨到 32) |
| `dart format --output=none --set-exit-if-changed` 护栏路径 | 181 文件 **0 changed**(`tool/probes/` 有 3 份预存未格式化文件,属 opt-in 目录,不在闸门内) |
| `tool/local_ci.ps1 -Scope Focused -TestPath test/runtime_assembly_test.dart -RefreshLockfile -OfflinePub -Analyze` | exit 0:新增的 `Dependency manifest refresh` 阶段跑 `pub get --offline`(不带 `--enforce-lockfile`)→ 10 测试全绿 → analyze 干净;`pubspec.lock` 逐字节未变,即"刷新路径执行了且当前依赖图无漂移"。两个禁止组合(`-Scope Full -RefreshLockfile`、`-RefreshLockfile -SkipPubGet`)都当场抛错 |

## 4. 余下项(W2 未完成部分)

> 环境注意(会影响后续会话):本机 `dart test` 默认并发**间歇性**报
> `HandshakeException: Connection terminated during handshake`(无栈、`dart analyze` / `dart run` 正常),
> 加 `-j 1` 即稳定通过。全仓逐包验证请用 `dart test -j 1`;这不是包的失败,别照着它去改代码。
>
> 第二条环境事实:本机裸 `python` / `python3` 解析到 `D:\Software\msys64\mingw64\bin\python.exe`,它缺标准库,
> 任何脚本一进门就 `ModuleNotFoundError: No module named 'encodings'`(Git Bash 与 PowerShell 同一路径)。
> 能用的是 `py -3`(3.9.13)。因此 `tool/local_ci.ps1` 的 python 类步骤、`tool/audit_repository.py`、
> `tool/interface_probe.py` 在这里**都跑不了**,而 `tool/validate_agent_workflow.py` 自称需要 Python 3.11+,
> `py -3` 也满足不了。看到这些步骤"失败"时先确认是哪条事实,别照着它去改代码。

`5a06d9d22` 那次"删 v1 遗留文档"删多了:`AGENTS.md`、`CLAUDE.md`、`BUILD_POLICY.md`、`MAINTENANCE_POLICY.md`
和 `tool/DEVICE_UI_MAP.md` 仍然链接 `docs/AGENT_WORKFLOW.md` 与 `docs/ANDROID_DEVICE_TEST_ROTATION.md`。
两份都已按 v2 的实际入口重建(前者保留 `#model-and-task-handoff` 这个被 AGENTS.md 直接链接的锚点;后者只留
仍然成立的租约与设备边界,v1 的逐日调度段不重建)。**同类风险记下来:删文档之前要先反查引用方,删被引用的
文件不等于删掉那条规则。**

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
   vendored 文件的成因。**端到端已跑通**(§3 那条 `-OfflinePub -Analyze` 记录,exit 0)。之前欠的那笔开关
   也补上了:`-RefreshLockfile` 走 `flutter pub get`(不带 `--enforce-lockfile`),与 `-SkipPubGet` 互斥、
   且 `-Scope Full` 拒绝 —— 全量验证必须按已提交的锁文件解析,"锁该动了"只是 Focused 里的决定。改完依赖之后
   `-SkipPubGet` 的报错现在直接指名这个开关。
7. ~~**FFmpeg 原生工件的 provenance 归属要有人定**~~ —— 已收口(§1.8(2) 收尾):既不 patch 钩子也不改用上游
   bundle,而是用钩子自带的**本地路径 override** 把来源钉在 `native-assets/`,由
   `tool/prefetch_android_native.ps1` 校验哈希后落盘。"能连上校验主机就悄悄删固定件"这条路径已经不存在。
   留下两笔要盯的:
   - **顺序成了契约**:`native-assets/` 不入库,`prefetch` 必须在 `test`/`build` 之前。仓库入口
     (`local_ci.ps1`、`build_local_release.ps1`)都自己调,但 `.github/workflows/build_pure_live_release.yml`
     的 android/windows 两个 job 还没有这一步 —— 手工触发发布时会在钩子里报 `Local override not found`。
     这一条**故意留在欠账里**:那两个 job 跑在 ubuntu/windows runner 上,而
     `tool/prefetch_android_native.ps1` 是按 Windows 写的 —— 路径用 `Join-Path … 'a\b'` 反斜杠拼接、持久缓存取
     `$env:LOCALAPPDATA`,在 Linux pwsh 下会生成字面含 `\` 的目录名(工件仍能落到 `native-assets/`,但缓存复用与
     media_kit 那几路 seeding 会失效)。要在 runner 上补这一步,得先把脚本改成平台无关再在对应 runner 上验一次,
     而这台机器验不了 —— 与其加一条只能靠读过的 CI 步骤,不如把它记成显式欠账。
   - **只钉了 windows/android**:macOS/iOS/Linux 仍走钩子默认路径(取上游并按上游校验和验收)。Linux 是本机
     之外的 runner 平台,CI 的 quality job 在 ubuntu 上跑 `flutter test` 因此不受本次改动影响;但一旦要在那三支
     上也用自烤件,得同样加本地 override + 预取,不能只改 `tool/verify_ffmpeg_native.py` 里那三行哈希。
8. 组合根只装到 §1.7 那张表的范围:`MediaRuntime` 没有装(没有引擎适配),`RuntimeRegistry` 是空的
   (没有运行时可注册),而授权 UI 还没有 —— 现在默认 `UnaskedPrompts`,第三方扩展**一律拿不到权限**,
   直到设置界面能真答一次为止;§1.9 把 store 换成持久之后,这条从"每次重问"变成"问了能留下"。
   还欠一个入口:用户对某条已记录的 `denied` 反悔时,需要一处 `revoke` 的设置项(内存时代无所谓,
   持久化之后那是唯一的重问路径)。
9. 落盘视图留了两处口子(§1.6 里也写了,记在这里是为了不让它被当成已解决):
   - **卸载不清 data**:`ExtensionStorage` 契约没有 `clear()`(§19 就没有),网关也只有 `unload` 不叫 uninstall。
     清理只能由持有 `KeyValueStore` 的一方按 `ExtensionNamespace` 前缀做,而那需要一个真正的卸载入口。
   - **磁盘缓存没有条数上限**:过期只在读这一行或列键时被剔除。AGENTS.md 把"有界缓存"列为要守的性质,而策略该是
     哪种(按属主分桶的 LRU、需要写入时间戳;还是宿主定期 prune)要等 W4 的 Bilibili 参考插件真的用上缓存再定,
     现在定等于猜。
10. **`local_ci.ps1 -Scope Full` / `-IncludeRepositoryChecks` 的仓库阶段还是 v1 的**,不能当成 v2 的交付门:
    `repository_preflight` 的 `validate_build_policy.ps1` 原先因 `$requiredFiles` 有 5 项指向已删文件而第一个抛错,
    **这一项已修**(5 个文件按原归属恢复,7 处原生工程路径改到 `$appRoot`,细节见 [w1-progress.md](w1-progress.md)
    §3.2 第 3 条);现在停在 `tool/validate_build_policy.ps1:336` 的 `plugins\flv_lzc\android\build.gradle` ——
    v1 vendored 插件、`lib/modules/**`、`lib/player/**`、三个 v1 workflow 与 `lib/gen/env.g.dart` 属同一类,
    要重定义而不是改路径。**2026-10-09 之后:这一段已经推到只剩 python。** `validate_build_policy.ps1` 在本分支
    首次 exit 0(11 条记名跳过 + 两条按 v2 形态重定义的检查 + 顺带修掉发布工作流的两处真实违规与
    `sync_owner_refs.ps1` 的 5 条死路径,全部细节见 [w1-progress.md](w1-progress.md) §3.2 第 3 条),而它后面的
    9 个 PowerShell 步骤(`test_subst_path.ps1` 与 8 个 `test_android_*` 只读回归)**逐个单独跑也都是 exit 0**。
    于是 `repository_preflight` 剩下的唯一阻塞点就是那条 python 事实:`validate_device_ui_map.py` 起,以及
    `repository_audit` 的 5 个 unittest + `audit_repository.py`(v1 规则残留 9 条 error)+
    `audit_built_in_kotlin.py`(要 Java 21)。让入口能选解释器是下一步该做的机械活,不是判定活。
    **那件机械活随后就做掉了:** 新增 `tool/pythonw.ps1`(按 `flutterw.ps1` 的约定探测解释器并转发退出码 ——
    候选 `python` → `python3` → `py -3`,只有能打印自身版本者才算可用;`PURE_LIVE_PYTHON` 可显式钉死),
    `local_ci.ps1` 的 9 处与 `test_android_ui_map.ps1` 的 1 处 python 调用全部改走它。实测
    `validate_device_ui_map.py` 通过(4 profiles / 170 points / 41 sequences),解释器不再是阻塞。
    audit 阶段因此**跑起来并露出真实失败**:`audit_repository.py` 报 `errors=4`,其中
    `live_back_invariant_missing` 指向已删除的 `lib/modules/live_play/**`;`tool/tests` 的 unittest 因 v1 主题
    缺失而失败(`lib/core/sites.dart`、`docs/ACCEPTANCE_MATRIX_3_1_0.md` 的 FileNotFoundError,及
    `test_release_workflow_data` 的 import 失败)。**Full 剩下的阻塞从此全是判定活** —— 环境因素已排除,
    这些规则要么按 v2 语义重写,要么按来源记录后删除。
    `repository_audit` 跑 5 个 python unittest,其中 `test_acceptance_status_alignment.py` 校验的 `ACCEPTANCE_*`
    文档已在 `5a06d9d22` 删除。叠加本机 python 事实,这一整段今天既不适用也跑不动。**修它需要先逐项判定去留**
    (哪些是 v2 还要的机制、哪些随 v1 一起走),那是独立清理任务而不是本轮的顺手改动;在此之前 Full 的失败不
    作缺陷证据,Focused(§3)才是当前可用入口。
