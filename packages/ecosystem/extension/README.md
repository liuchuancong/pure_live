# pure_live_extension

> 职责:扩展统一入口:ExtensionGateway、Runtime 选择与生命周期、Source 契约与 ExtensionContext 注入边界

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation + 共享模型伞包 `pure_live_platform`;并按 [ADR 0019](../../../docs/adr/0019-gateway-service-edges.md) 定向依赖 `pure_live_permission` 与 `pure_live_task`(只用于装配 `ExtensionContext`) |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);除 ADR 0019 之外禁止同层互依 |
| 公共面 | 只有 `lib/pure_live_extension.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/extension.dart` —— `Extension`(扩展实现方)与 `ExtensionHandle`(平台看到的扩展)
- `lib/src/runtime.dart` —— `ExtensionRuntime` / `RuntimeInstance` / `RuntimeRegistry`
- `lib/src/source.dart` —— `Source` 契约
- `lib/src/context.dart` —— `ExtensionContext` 注入边界 + `ExtensionCache` / `ExtensionStorage` / `DiagnosticTracer` 与其内存实现
- `lib/src/gateway.dart` —— `ExtensionGateway` 契约与 `ExtensionGatewayException`
- `lib/src/managed_extension_gateway.dart` —— 生命周期状态机与运行时选择
- `lib/src/persistent_context.dart` —— `PersistentExtensionCache` / `PersistentExtensionStorage`:按属主分命名空间的落盘视图
- `lib/src/network_transport_bridge.dart` —— `ExtensionNetwork` 的 `pure_live_network` 适配

## 生命周期(platform-infrastructure.md §3)

| 动作 | 转移 | 抛出 |
|---|---|---|
| `register` | → `identified`;无匹配 Runtime 或 API 版本不合 → `incompatible` | `extension.incompatible`、`extension.already_registered` |
| `load` | `identified`/`error` → `loading` → `validating` → `ready` | `extension.load_failed`、`extension.disabled`、`extension.state_invalid`、`extension.not_found` |
| `start` | `ready` → `running` | `extension.state_invalid`、`extension.load_failed` |
| `stop` | `running` → `stopping` → `ready` | `extension.state_invalid` |
| `disable` | 任意存活态 → `disabled`(停 + dispose,**保留记录**) | `extension.not_found` |
| `unload` | 同上但**删除记录**,须重新 register 才能回来 | `extension.not_found` |

`ERROR → RETRY` 是文档里的失败分支,所以 `load` 允许从 `error` 重来;重试前会先释放失败留下的实例。
每次状态变化同时产生一个 `ExtensionStatus`(stream)与一条 `extension.<state>` 诊断事件,二者同源。

## 相对契约示例的两处形状差异(以本文与实现为准)

`platform-contracts.md` §7 的示例写 `String get id; String get version;` 与 `load(descriptor)`。实现改为:

1. `ExtensionRuntime.descriptor`(`RuntimeDescriptor`)—— 选择运行时本来就要用 `protocols` 与 `supportedTypes`,
   两个裸 getter 会把这些信息重复一遍。
2. `load(descriptor, context)` —— §19 规定扩展只能经 `ExtensionContext` 取得平台服务,而**构造扩展实例的正是
   运行时**,所以 context 必须在 load 时交给它;示例里没有它。

`changes` stream 同理:§6 只列了 `find/getAll`,而生命周期迁移必须能被发现(§17 要求 `extension.load/error`
可观测),否则调用方只能轮询。

## 已知边界

- `supportedApiVersions` 默认空 = 不做版本检查;插件可声明 `platformApiVersion` 时必须由组合根显式给值。
- 本包**不**装 JS/Python:PluginRuntime、TvBoxRuntime 等是 `ExtensionRuntime` 的实现,分别落在
  `ecosystem/plugin_api`(W2 接口)与 `ecosystem/external_tvbox`(W7)。
- `ExtensionCache` / `ExtensionStorage` 的**默认**实现是内存且随记录一起丢弃(重载不继承上一次的缓存行);
  要留就注入 `PersistentExtensionCache` / `PersistentExtensionStorage`(§19 "实现可换而 Extension API 不变")。
  网关的两个工厂参数 `cacheFactory` / `storageFactory` 就是这道接缝 —— 网关自己不决定文件在哪儿。
- 落盘视图的命名空间是 `extension.<id>.cache.<key>` / `extension.<id>.storage.<key>`(§19 要求含属主)。前缀由视图
  添加,扩展猜不到别人的字符串:它写出的键永远落在自己名下。
- 落盘视图只收可 JSON 序列化的值,写不下当场 `ArgumentError`;内存视图没这条限制(它原样持有对象)。这是两条
  实现唯一的语义差异,所以宁可在这里失败,也不要重启之后发现那一行悄悄没了。
- 磁盘缓存**没有条数上限**:过期只在"读这一行"或"列出键"时剔除,一个只写不列的扩展仍会把文件写大。
- 卸载一个扩展要清掉它的 `storage` 行,而 `ExtensionStorage` 契约里没有 `clear()`(§19 就没有),
  所以清理只能由持有 `KeyValueStore` 的一方按 `ExtensionNamespace` 前缀做。

## 网络出口的落地(`NetworkClientTransport`)

`ExtensionContext.network` 需要有人真的把请求发出去。`src/network_transport_bridge.dart` 是那一层:
平台的 `NetworkRequest` → `pure_live_network` 的 `NetworkClient.sendBytes` → 平台的 `NetworkResponse`。
有四件事值得单独说:

- **HTTP 实现留在 L0**:本包不 import dio(只有测试 import,列在 dev_dependencies),所以 L0 换实现不会波及契约;
- **L0 的 `NetworkFailure` 在这里翻成 `ExtensionNetworkException` + `PlatformErrorInfo`**:扩展看不到 foundation
  类型,否则每次 L0 改动都是插件可见的破坏;错误码直接用 `failure.code`(W1 已按 models §14 对齐);
- **策略夹过的超时必须真的传到客户端**:`request.effectiveTimeout` 作为 per-request receive timeout 交下去,
  否则 `NetworkLimits.maxTimeout` 只是纸面数字。
- 借来的 `NetworkClient` 不由本 transport 关闭(默认 `ownsClient == false` 当 client 是传进来的)。

真实站点仍**没有**跑过:测试用脚本化 adapter。到 W4 Bilibili 之前,这条链路的验收状态是"策略与桥有离线证明,
线上无证据"。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
