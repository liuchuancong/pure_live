# Plugin Permissions

## 1. 权限清单

```text
network        经 PluginNetwork 发起网络请求(域名白名单在声明里细分)
cookies        读写指定域 Cookie
account        访问本站登录态(布尔级与资料;凭据本体不外泄)
storage        本插件命名空间内的 kv/文件
filesystem     用户显式选择的文件读写(经 files 包)
clipboard      读剪贴板(敏感,需确认)
notification   本地通知
background     后台任务(下载/录制续跑)
media          直接贡献 MediaTicket 的播放能力
location       位置(默认拒绝)
```

## 2. 授权模型

- **权限最小化(I8)**:插件只能访问声明过的权限;未声明即调用 → 运行时拒绝 + 诊断记录。
- 高风险权限(clipboard/location/background/account)需**用户逐项授权**,安装页明示用途。
- 权限在 Manifest 中静态声明;运行时动态扩权一律无效(见 [plugin-manifest.md](plugin-manifest.md))。
- 拒绝授权的效果是优雅降级(对应 capability 不可用),不是插件崩溃。

## 3. 与凭据的关系

`account` 权限不等于拿到凭据本体:Provider 经 auth 包拿到会话句柄,凭据始终在系统安全存储(见 [../security/credential-storage.md](../security/credential-storage.md));JS 插件默认只有"是否已登录"布尔级信息。
