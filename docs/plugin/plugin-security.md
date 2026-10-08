# Plugin Security

## 1. 安装安全管线

```text
Download → Verify → Manifest Parse → API Compatibility
→ Permission Review → Sandbox → Install → Enable
```

校验维度:`signature`(签名,官方源)/ `checksum`(哈希)/ `version` / `publisher` / `trusted source`(来源信誉)。任一失败 → 拒装并记录诊断。

## 2. 运行时安全边界

- **JS 插件**:flutter_js 沙箱内执行;无文件系统、无原生通道、网络只经 PluginNetwork(域名白名单/超时/大小上限,见 [../security/network-security.md](../security/network-security.md));异常不得逃逸沙箱。
- **Native 插件**:进程内但以契约接口暴露;错误吞并降级,禁止跨包内部 import。
- **Data 插件**:解析器白名单格式;字段大小/条目数限额,防膨胀攻击。

## 3. 数据隔离

- 插件数据全部带命名空间(插件 id);不得读取其他插件命名空间(见 [../services/cache.md](../services/cache.md))。
- 凭据永不进入插件可见范围(见 [../security/credential-storage.md](../security/credential-storage.md))。
- 备份/同步默认不含插件代码与凭据(见 [../services/sync.md](../services/sync.md))。

## 4. 事故响应

- 插件被报告恶意/故障 → 用户可一键禁用;官方可通过 Repository 下架(更新策略拉黑)。
- 所有安全事件进 Diagnostics(见 [../diagnostics/logging.md](../diagnostics/logging.md)),可导出报告。
