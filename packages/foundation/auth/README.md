# pure_live_auth

> 职责:凭据与安全存储抽象,登录态生命周期

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_auth.dart`;内部实现放 `lib/src/` |

## 内容

- `session.dart` —— `AuthMethod` / `AccountStatus` / `CredentialHandle`(凭据句柄,不含明文)/ `AccountProfile` / `AuthSession`(过期判定接 `Clock`)
- `credential_store.dart` —— `CredentialStore`:凭据写 `SecureStore`、会话状态写 `KeyValueStore`;`clearAccount` 一次清干净;`expiryEvents` 通知宿主该弹登录了;`describeForDiagnostics` 与 `isAuthOwnedKey` 保证凭据不进诊断包、不进备份

按 [docs/security/credential-storage.md](../../../docs/security/credential-storage.md):本包是凭据的唯一读写方,Provider 只拿句柄发已认证请求;凭据不参与 backup/sync,跨设备走重新认证。

## 会话侧的三块新面(2026-10-11 补齐)

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `src/cookies.dart` | `AuthCookie`(parse/matchesHost/matchesPath/isLiveAt/toJson)、`AuthCookieJar`(上限、过期剪枝、`headerFor`、`describe`) | 每个 provider 都在手写 Set-Cookie 解析;RFC 6265 的匹配规则只该有一处 |
| `src/token_refresh.dart` | `TokenRefreshCoordinator`、`RenewedCredential`、`RefreshStatus`/`RefreshOutcome`、`RefreshFailure` | "到期前换、失败退避、拒了别再问"每个源都要做一遍,而且各自都会做错 |
| `src/request_auth.dart` | `AuthScheme`/`CredentialPlacement`、`RequestAuthorizer`、`AuthRequest.redact` | 凭据往请求上怎么放是四个变体,是数据不是代码;而"日志里不能带凭据"每次都被人忘记 |

规则:

- **Max-Age <= 0 是删除指令**,不是"存成 1969 年":jar 收到它要移掉同名 cookie,留着就违背服务器明确的指示。
- **域匹配要有点边界**:`example.com` 覆盖 `www.example.com`,不覆盖 `notexample.com`;`domain` 与请求 host
  不是同一回事时直接拒收,而不是"收窄了存着"—— 收下就等于允许一个响应往别的站点种 cookie。
- **路径匹配在分隔符边界上取前缀**:`/app` 覆盖 `/app/edit`,不覆盖 `/application`。
- **超限淘汰先丢已过期的、再丢将会过期的,session cookie 最后丢**:没有过期时间的cookie 意味着服务器打算
  下次登录重新发,丢掉它的代价是一次登录。
- **换新的提前量带抖动,且只往短了抖**:十个账号在同一个瞬间一起回源是把自己的提供商打进自己的速率限制;
  把 lead 抖长则只会更早地问,那不是省请求。
- **永久拒绝(refresh token 无效)与超时分开**:`RefreshFailure.permanent` 直接把账户标 `expired`,
  其余按 `backoffBase * 2^n` 递增、`maxBackoff` 封顶,连续到 `failureLimit` 同样标 expired。
- **日志面**:只有 `describe()` / `toDiagnosticJson()` / `redact()` 可以进日志;它们给名字、作用域与长度,
  永远不给值。
## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
