# Sync(多设备同步)

> 与 backup 分离:backup = 快照导出导入;sync = 多设备持续同步。

## 管线

```text
Local State 变更 → SyncEngine(增量队列)→ Remote(firebase / WebDAV / LAN bonsoir)
→ 其他设备拉取 → 冲突合并
```

## 同步对象

settings / history / favorites / playlist / watchProgress / accounts metadata(不含凭据本体)/ plugin configuration / theme configuration / repository configuration。

## 规则

- **敏感 Credential 不默认同步明文**(见 [../security/credential-storage.md](../security/credential-storage.md));跨设备登录走重新认证。
- 冲突合并:集合类(收藏/歌单)并集优先;标量类(设置)last-writer-wins;合并策略按对象类型注册。
- 后端可插拔(firebase 保留/WebDAV/LAN);凭据各自配置,不同步后端凭据。
- 全程可观测:`sync.completed` 事件与冲突报告。
