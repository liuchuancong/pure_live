# pure_live_plugin_api

> 职责:插件清单与生命周期:Manifest 校验、安装管线阶段、PluginRuntime / HostBridge / ScriptSandbox 接口

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation + 共享模型伞包 `pure_live_platform`。**不**依赖 `pure_live_extension` / `pure_live_permission`:桥面是插件可见的子集,由同时接两边的宿主去适配 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(I9);同层互依 |
| 公共面 | 只有 `lib/pure_live_plugin_api.dart`;内部实现放 `lib/src/` |

## 结构

- `lib/src/manifest_validator.dart` —— `PluginManifestValidator` / `PluginIssue` / `PluginValidationResult`,并把清单翻成网关要注册的 `ExtensionDescriptor`
- `lib/src/lifecycle.dart` —— `PluginLifecycleState` 与迁移表 `PluginLifecycle`
- `lib/src/host_bridge.dart` —— `HostBridge` 与 `PluginNetwork` / `PluginCookieAccess` / `PluginKvStore` / `PluginEventSink`
- `lib/src/plugin_runtime.dart` —— `PluginRuntime`(native / js / data 三种形态的公共形状)
- `lib/src/sandbox.dart` —— `ScriptSandbox` / `ScriptSandboxFactory` / `SandboxPolicy` / `SandboxLimits` / `SandboxOutcome`

## 现在就被守住的规则(不是纸面声明)

1. **能力名与权限名是天花板**:未知能力名或未知权限名 → 拒绝安装(`plugin.unknown_capability` /
   `plugin.unknown_permission`),而不是"能认多少算多少"。
2. **apiVersion 按区间判**:`plugin.api_incompatible`,区间由宿主给(min/max),不是字符串相等。
3. **id 形态**:反向域名形状(`plugin.id_shape`)。
4. **无能力声明的插件**没有消费方 → 拒绝(`plugin.no_capabilities`)。
5. **缺字段**产出结构化 issue(`plugin.manifest_invalid`),不把 FormatException 抛给安装界面。
6. **Disabled → Enabled 必须重过 Initialized**(plugin-lifecycle.md §2:桥要重注入、权限按当时声明重认);
   迁移表里没有的路径一律 `PluginLifecycleException`。每次合法迁移都回调 `onChanged`,§2 要求的
   `plugin.enabled` / `plugin.disabled` 事件由宿主在这里发。

## 名称对齐(文档之间原本不一致)

- `plugin-permission.md` §1 写 `cookies`,`platform-models.md` §12 的枚举是 `cookie`。枚举为准,
  读清单时按 `permissionAliases` 映射。
- 该文档还列了 `filesystem` 与 `location`,而枚举里没有 → 已**追加**进 `Permission`(append-only,符合
  `architecture/evolution.md`)。`location` 默认拒绝,不得静默授予。
- `capability-contract.md` §1 用 `lyric`,`ExtensionCapability` 用 `lyrics` → `capabilityAliases` 映射。
- §1 的 `danmaku` / `comment` / `subtitle` / `chapter` / `iptv` / `history` / `favorite` / `quality` / `line` /
  `auth` 在粗路由集 `ExtensionCapability` 里没有对应项:它们是**合法声明但不产生路由条目**,不算拒绝。
  两处名单各由自己包的测试对着文档钉住(`pure_live_capability` 的 `CapabilityKind` 测试与本包的
  `pluginCapabilityNames` 测试),改文档必须两处同改。

## 仍是接口(W2 只到接口)

- `PluginRuntime` 的三个实现(native 调用表 / js 走 fjs / data 解析器)与 `ScriptSandbox` 的真引擎在 W10 的
  plugin_host 落;`SandboxPolicy.defaultDenials`(文件系统 / 进程 / native API / FFI / 系统命令 / 任意 socket)
  现在只是**声明 + 查询**,没有执行体去违反它,也就还没有"违规被拒"的运行证据。
- 连续失败自动禁用(plugin-lifecycle.md §2)需要执行体才有意义,失败预算的计数随 plugin_host 一起落。
- 下载 / 签名校验(plugin-contract.md §2 管线的前两阶段)属宿主与生态侧,不在本包。

## 验证

- 分析:`dart analyze`;测试:`dart test`
