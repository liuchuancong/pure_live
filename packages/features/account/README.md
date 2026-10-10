# pure_live_account

> 职责:站点账号的**状态视图**与生命周期操作(登录写入、登出、是否值得刷新)。
> 凭据本体住在 `foundation/auth`,本包永远只在参数里过一次性密钥,不保存、不打印、不缓存。
> 见 [docs/security/credential-storage.md](../../../docs/security/credential-storage.md)。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `domain/site_account.dart` | `SiteAccount`(状态 + `secretPresent` + `canRefresh`)、`SiteAccountRepository`、具名失败 | "已登录"有三种必须分开的样子:没账号 / 会话过期(可刷新)/ 站点禁用(不可刷新);每个屏各自判一遍就会给出不同的提示 |
| `data/credential_site_accounts.dart` | `CredentialSiteAccounts`(over `CredentialStore`) | 存储本身不认识"主账号"这个概念,也不管体积与空白 id |

## 行为契约

- `accountsOf` 按 `accountId` 排序,不按存储键序 —— 遥控器要每次指到同一行。
- `primaryAccount`:先取可用会话里**过期最晚**的那个;全都不可用时取最值得一刷的。存储里没有"写入时间",
  过期时间是唯一可用的新旧事实;拿键序当新旧就是让规则跟着后端变。
- `secretPresent == false` 而会话记录还在:这是**部分清除**,不是登出。此时 `isUsable` 与 `canRefresh` 都是
  false —— 没东西可刷,只能重新登录。
- 登出只走 `CredentialStore.clearAccount`(一次调用删掉密钥与会话两条记录);`signOutSite` 清完整站点,
  中途失败也继续清并把"落下几个"报成 `AccountOperationFailure`。
- 空白 `siteId` / `accountId` → `ArgumentError`;空密钥或超过 `maxSecretSize`(默认 64 KiB)→
  `AccountInputFailure`,消息里带实际大小与上限。
- `markStatus` 对已不存在的账号抛 `AccountNotFoundFailure`,不像存储那样静默返回。
- `expiries` 是 auth 广播流的映射视图,本包不自建 controller,因此可弃而不留未关的汇。

## 依赖

允许:`foundation/auth`(唯一的凭据读写者)+ `foundation/utils`。禁止:providers 直连、同层 feature、App 反向依赖。

## 平台矩阵

纯 Dart。凭据的实际落盘由 App 绑定(`flutter_secure_storage` 在 Android / Windows),Android TV 与 Windows
已验证的是 auth 包而不是本包。

## 未验证

- **没有 App 消费者**:`apps/pure_live` 不装配本包;10 个测试是唯一的门,且全部跑在内存替身 vault 上。
- 真实 keystore 的**写入失败**路径(容量、锁死)未验证 —— 那需要真机。
- 多账号站点的"主账号"选择规则按过期时间;若某站点的会话根本不给过期时间,该站点就退回声明顺序,
  这条还没有真实数据校过。
