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
- `lib/src/key_value_permission_store.dart` —— `KeyValuePermissionStore`:把 grant 存进 L0 的 `KeyValueStore`
- `lib/src/extension_network.dart` —— `ExtensionNetwork`(插件唯一网络出口)、`NetworkLimits`、`NetworkTransport` 端口
- `lib/src/extension_cookie_store.dart` —— `ExtensionCookieStore`、`CookieJar` 端口与按扩展隔离的实现

`KeyValuePermissionStore` 依赖 `pure_live_storage` 的 `KeyValueStore` 接口(向下到 L0,不是新词汇):
存什么后端由组合根决定,本包不知道文件、Drift 或 Hive 的存在。键形状是
`permission.<extensionId>/<permission.name>` —— 分隔符必须是 `/`,因为扩展 id 本身带点,
用 `.` 做前缀扫描会让 `purelive.a` 的清理顺手删掉 `purelive.ab` 的授权。
读不懂的记录按"没问过"处理并删掉:一条永远解析不了的记录如果留着,等于每次加载都要重新决定怎么处理它,
而"没问过"是唯一还能被回答的状态。

数据模型(`Permission` / `PermissionGrant` / `PermissionScope` / `NetworkRequest` / `NetworkResponse` /
`Cookie`)在 `pure_live_platform`,归属划分见 [docs/adr/0018-contract-package-split.md](../../../docs/adr/0018-contract-package-split.md)。

## 规则(规范来自 platform-contracts.md §15、platform-infrastructure.md §7.2)

1. **descriptor 是天花板**:`request` 只能要到 descriptor 声明过的权限;未声明的一律 `permission.restricted`,
   **且不会去问 prompt** —— 否则扩展可以靠对话绕过自己的声明。
2. **未注册即无授权**:没 `register` 过的 extensionId,任何权限都拿不到。
3. **默认失败关闭**:不接 prompt 时用 `RejectAllPrompts`,忘记接线等于拒绝,而不是放开网络。
4. **拒绝要留存**:`refuse` 与 prompt 答 `denied` 都写记录,下一次 `request` 不再重问;`revoke` 才回到 `unknown`。
   - 这条与"记录能持久"合起来有一个必须显式守的推论:**接了持久 store 之后,占位 prompt 不能答 `denied`**。
     `RejectAllPrompts` 是内存时期的安全默认,但它的答会被写下来,而写下来的 `denied` 永不重问 ——
     于是"没人替用户做过决定"会变成"用户做过否定决定",且重启后仍然成立。没有授权 UI 时用
     `UnaskedPrompts`(答 `unknown`:这次拒绝,但不冒充用户的选择,下次仍然可问)。
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

`NetworkTransport` 已由 `pure_live_extension` 的 `NetworkClientTransport` 实现(架在 `pure_live_network` 的
`NetworkClient.sendBytes` 上),本包因此保持纯 Dart、可离线测。诊断事件出口也在那一步接
(`platform-contracts.md` §17)。

**这条链路没有被真实 HTTP 验证过**:桥的测试用脚本化 adapter,没有一次真连站点。到 W4 Bilibili 之前,
它的验收状态是"策略与桥有离线证明,线上无证据"。

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / iOS / macOS / Windows / Linux | ✅ | 判定与策略纯 Dart;授权持久化经 `pure_live_storage`(`dart:io`)。 |
| Web | ❌ 取决于装配 | 同上:web 上没有 `FileKeyValueStore`,授权记录就只能落进另一个 `KeyValueStore` 实现。 |

## 未验证

- **拒绝的持久性**:一次 denied 之后重启不再弹,这条靠 `KeyValuePermissionStore` 的读写保证,但真机上的进程被杀/存储被系统清理两种情况没有分别验过。
- 网络策略与 Cookie 隔离只在网关的假传输上验过;真实站点的 Set-Cookie 组合(多域、过期、属性名大小写)没跑过。
## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
