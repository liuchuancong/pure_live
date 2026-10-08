# Auth(认证)

> 账号 Provider 化;凭据永不外泄(见 [../security/credential-storage.md](../security/credential-storage.md))。

## 模型

```text
Account { providerId, accountId, profile, credential(句柄), session, status }
AuthManager → AccountStore → SourceAuthProvider(在各源插件内实现 AuthCapability)
```

支持:Cookie / Token / OAuth / QR 扫码 / Device Login / Anonymous。

## 会话生命周期

- 统一事件 `auth.expired`(EventBus);Provider 负责刷新或重登,宿主负责引导 UI。
- 过期不静默失败:取流/详情遇 `AuthRequired` → 上层引导登录(v1 斗鱼会话修复的经验:登出必须完整清理会话)。
- 多平台会话并存;JS 插件只见"是否已登录"布尔级。

## 登录方式落点

扫码(B 站矩阵,qr 库)/ Cookie 导入(粘贴/文件)/ OAuth(回调经 platform 深链接)/ 用户名密码(表单,按站)。
