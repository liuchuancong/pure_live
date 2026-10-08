# Permission Model

## 声明

插件在 Manifest 静态声明 `permissions`;未声明即调用 → 运行时拒绝 + 诊断记录;动态扩权无效。

## 授权

- 低风险(network 只读域名范围/storage 命名空间)安装即授。
- 高风险(account/clipboard/notification/background/location)逐项用户授权,安装页明示用途;拒绝 = 对应能力优雅降级。

## 管理

设置页:按插件查看已授权限、逐项撤回(撤回即降级)、一键禁用插件。

## 与凭据

`account` 权限 ≠ 凭据本体:Provider 拿会话句柄;JS 插件默认布尔级登录态。详见 [credential-storage.md](credential-storage.md)。
