# Backup(备份)

> 快照式导出/导入(与 sync 的持续同步分离);版本化,支持迁移与回滚。

## 格式

```text
BackupFile
├── formatVersion(v1/v2/v3…只增)
├── createdAt / appVersion
├── data: settings / history / favorites / playlists / watchProgress
│        / plugin configuration / theme / repository configuration
└── checksum
```

## 操作

Export(全量/按域)/ Import / Migration(旧版本格式→当前)/ Validation(校验损坏)/ Rollback(导入失败自动回退)。

## 规则

- 导入可选覆盖/合并;覆盖前自动做一次"导入前备份"。
- 凭据与插件代码默认不进备份。
- 传输载体:本地文件 / WebDAV / 局域网直传(backup_ui 提供 UI)。
