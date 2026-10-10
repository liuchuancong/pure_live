# pure_live_backup_feature

> 职责:设置页调用的**备份编排** —— 推送今天的状态、列举远端归档、恢复某个归档、只重试失败的数据域。
> 归档格式与凭据拒收在 `foundation/backup`(引擎 + manifest + WebDAV store),这里只做编排与报告。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `domain/backup_reports.dart` | `ArchiveContents` / `BackupRestoreReport` / `RemoteSnapshot` + 具名失败 | 数据层返回中文句子就翻不了译,也拿不到数字;报告必须是数据 |
| `domain/snapshot_remote.dart` | `SnapshotRemote` / `SnapshotListing` 端口 | `WebDavBackupStore` 是 final class,外部无法替换 —— 有了端口才能真的"注入传输以便测试" |
| `data/webdav_snapshot_remote.dart` | `WebDavSnapshotRemote` 适配器 | 只做类型映射,路径与凭据留在 L0 |
| `data/backup_document.dart` | `encodeBackupBundle` / `decodeBackupDocument` / `encodeBackupText` / `decodeBackupText` | `{manifest,payload}` 是**归档格式**,不是 App 接线;此前它抄在 `apps/pure_live/lib/app/user_backup.dart` 里 |
| `data/webdav_backup_service.dart` | `BackupService` + `WebDavBackupService` | 快照名、列举顺序、失败具名是编排层的知识 |

## 行为契约

- 报告在**上传之前**由类型化 bundle 生成:manifest 形状变化不会让一个已经落地的备份被报成失败。
- 快照名是**不可信输入**:含 `/`、`\`、`..`、控制字符或空白 → `BackupServiceFailure` / `ArgumentError`。
  它会变成别人 WebDAV 上的路径分量,引擎守内容,这一层守位置。
- `listRemote()` 按 `modifiedAt` 倒序 —— 传输给的顺序是服务器给的顺序。
- 恢复逐域记录结果,一个域失败不影响其余;`retry()` 只碰 `failed` 集合,对完整报告**不再写第二次**。
- 解码拒绝:缺 `manifest` / 缺 `payload`、manifest 声明含凭据、schema 版本不认识、
  manifest 列了某域而 payload 没有它的值(否则会以"空"覆盖设备上真实数据)。
- 凭据键自始自终不进归档(`isCredentialKey` 由组合根从 auth 传入),恢复端再拒一次。

## 依赖

允许:`foundation/backup` + `foundation/utils`。禁止:providers 直连、同层 feature、App 反向依赖。

## 平台矩阵

纯 Dart;真实 WebDAV 请求由 `foundation/backup` 的 store 发出,Android / Android TV / Windows 沿用其平台矩阵。

## 未验证

- **没有 App 消费者**:`apps/pure_live` 现在自己抄了一份 `{manifest,payload}` 编解码(`lib/app/user_backup.dart`),
  等拆壳波把它换成本包 —— 换之前这份格式知识存在两处,是已知重复,不是本包的门。
- 18 个测试全部跑在 `InMemoryRemote` 上;真实 dav 服务器的 401 / 404 / 目录不存在路径**未验证**。
- 归档体积上限没做:远端返回超大文档时目前会整个吃进内存,等有真实配额再加。
