# pure_live_permission

> 职责:权限契约:最小授权判定、扩展网络出口策略与按扩展隔离的 Cookie 存储

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_permission.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/permission_manager.dart` —— `PermissionDecision` 与 `PermissionManager`(register / check / request / revoke / refuse / held)
- `lib/src/policy_permission_manager.dart` —— 最小授权实现
- `lib/src/ports.dart` —— `PermissionStore` / `PermissionPrompt` 两个端口与其内存实现
- `lib/src/extension_network.dart` —— `ExtensionNetwork`(插件唯一网络出口)、`NetworkLimits`、`NetworkTransport` 端口
- `lib/src/extension_cookie_store.dart` —— `ExtensionCookieStore`、`CookieJar` 端口与按扩展隔离的实现

数据模型(`Permission` / `PermissionGrant` / `PermissionScope` / `NetworkRequest` / `NetworkResponse` /
`Cookie`)在 `pure_live_platform`,归属划分见 [docs/adr/0018-contract-package-split.md](../../../docs/adr/0018-contract-package-split.md)。

## 规则(规范来自 platform-contracts.md §15、platform-infrastructure.md §7.2)

1. **descriptor 是天花板**:`request` 只能要到 descriptor 声明过的权限;未声明的一律 `permission.restricted`,
   **且不会去问 prompt** —— 否则扩展可以靠对话绕过自己的声明。
2. **未注册即无授权**:没 `register` 过的 extensionId,任何权限都拿不到。
3. **默认失败关闭**:不接 prompt 时用 `RejectAllPrompts`,忘记接线等于拒绝,而不是放开网络。
4. **拒绝要留存**:`refuse` 与 prompt 答 `denied` 都写记录,下一次 `request` 不再重问;`revoke` 才回到 `unknown`。
5. **过期不是拒绝**:`expiresAt` 到期后 `check` 报 `unknown`(可再申请),而不是 `denied`。
6. **网络按 host 作用域**:grant 带 `PermissionScope.hosts`;`*.example.com` 只覆盖子域,不含裸域。
   `ExtensionNetwork` 在**响应落地之后**再核一次 `finalUri`,重定向逃授权直接 `permission.restricted`。
7. **超时/体积/并发在出口统一夹取**:`NetworkLimits.maxTimeout`(默认 30s 上限,单请求默认 15s)、
   `maxResponseBytes`(8 MiB,超过即 `network.response_too_large`)、`maxConcurrentRequests`(超出报
   `network.rate_limited`)。
8. **Cookie 按扩展隔离**:一个 extensionId 一个 jar,读与写都要 `Permission.cookie`;
   `clear` 不需要授权(它只删数据)。Cookie 值在 `toString` / 诊断里一律脱敏。
9. **错误码稳定**:`permission.denied` / `permission.restricted` / `network.*`,恢复阶梯按码分支,不按文案。

## 接线状态

`NetworkTransport` 由上层用 `pure_live_network` 实现(该适配随 `ecosystem/extension` 的 `ExtensionContext`
组装一起落),所以本包现在是纯 Dart、可离线测;诊断事件出口也在那一步接(`platform-contracts.md` §17)。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
