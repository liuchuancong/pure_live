# 安全模型

> 分四道防线:插件准入 → 运行时沙箱/权限 → 数据隔离 → 可审计。

## 防线

1. **准入**:安装管线(签名/哈希/兼容性/权限评审)——见 [../plugin/plugin-security.md](../plugin/plugin-security.md)
2. **运行时**:JS 沙箱(fjs ^3.3.2)+ 权限运行时拒绝(未声明即拒)——见 [plugin-sandbox.md](plugin-sandbox.md)、[permission-model.md](permission-model.md)
3. **数据**:凭据系统安全存储、命名空间隔离、备份/同步不含凭据与插件代码——见 [credential-storage.md](credential-storage.md)
4. **网络**:统一出口 + 域名白名单 + 代理策略——见 [network-security.md](network-security.md)

## 原则

- 最小权限(I8);默认拒绝;优雅降级而非崩溃。
- 一切安全事件可诊断、可导出(见 [../diagnostics/](../diagnostics/))。
- 用户可见:安装页权限明示、设置页插件权限管理、一键禁用。
