# Credential Storage

> 平台 Cookie/Token 的存取规则。

## 存储

- 系统安全存储:flutter_secure_storage(Android Keystore / iOS Keychain / Windows DPAPI / macOS Keychain / Linux libsecret)。
- auth 包是唯一读写方;任何插件/业务不得直接读凭据。

## 访问面

- Native Provider:经 auth 拿**会话句柄**(可发起已认证请求),不接触明文。
- JS 插件:默认布尔级登录态;经 Cookie 权限 + 白名单域才可携带 Cookie(由宿主注入,不回显)。

## 生命周期

- 写入(登录成功)/ 刷新(会话续期)/ 清除(登出全量清理——v1 斗鱼会话残留教训)。
- 不参与 backup/sync 明文同步;跨设备登录走重新认证。
- 泄露应急:单平台登出 + 强制下线;诊断报告不含凭据。
