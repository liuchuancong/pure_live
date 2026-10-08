# Plugin Lifecycle

## 1. 状态机

```text
Installed → Verified → Loaded → Initialized → Enabled ⇄ Disabled → Uninstalled
```

| 状态 | 含义 |
|---|---|
| Installed | 落盘、登记注册表,尚未校验 |
| Verified | Manifest/签名/兼容性校验通过 |
| Loaded | 代码加载完成(Native 编译体 / JS 脚本编译 / Data 解析器就绪) |
| Initialized | `init(HostBridge)` 执行成功,拿到沙箱桥 |
| Enabled | 对 CapabilityRegistry 可见,可被业务消费 |
| Disabled | 保留数据、退出注册表、回收资源 |
| Uninstalled | 清除代码与命名空间数据 |

## 2. 关键规则

- **崩溃隔离**:插件崩溃/超时不得影响主 App——JS 异常捕获在沙箱内,Native 契约异常吞掉并标记插件 degraded;连续失败自动禁用并通知用户。
- 状态迁移必须发事件:`plugin.enabled` / `plugin.disabled`(见 [../architecture/runtime.md](../architecture/runtime.md) 事件总线)。
- Disabled→Enabled 需重新走 Initialized(HostBridge 重新注入,权限以当时声明为准)。
- Uninstall 必须清理该插件的 cache/kv 命名空间(命名空间见 [../services/cache.md](../services/cache.md))。
