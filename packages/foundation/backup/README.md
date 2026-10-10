# pure_live_backup

> 职责:本地备份与恢复,不含凭据明文

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_backup.dart`;内部实现放 `lib/src/` |

## 内容

- `manifest.dart` —— `BackupDomain` / `BackupManifest`(带 `validate`:拒绝声明含凭据的档、拒绝不认识的 schema 版本、拒绝重名域)+ `RestoreReport` / `DomainOutcome`
- `engine.dart` —— `BackupEngine.build` 与 `RestoreEngine.apply` / `.plan`:**逐域隔离**,一个域失败只记在它自己头上,重试可以只喂 `onlyDomains`;两端都用注入的 `isCredentialKey` 拒凭据(手改的档也带不进来);`maxKeysPerDomain` 上限拒超大域;`supportedSchemaVersions` 可注入(旧实现硬编码 `{1}`)
- `codec.dart` —— `encodeBundle` / `decodeBundle`:档 = `{format, container, manifest, payload, digest, manifestDigest}`。**两个摘要**都要校验:payload 的 SHA-256 走**规范化 JSON**(键排序),否则同一份内容在另一台设备上顺序不同就校验失败;manifest 单独摘要,改档名一个域或翻 `includesCredentials` 都会让档失效。读取前先量字节数(`kBackupMaxBytes`),不是解析完再说
- `archiver.dart` —— `BackupArchiveStore` 端口(按**字节**,不按 JSON 文档)+ `InMemoryArchiveStore` + `BackupArchiver`(`archive` = build→encode→write→prune 一趟做完,返回 `prunedNames`)/ `newest` / `load` / `loadLatest`;`backupArchiveName` 产可排序的 UTC 名,`archivesToPrune` 施 `RetentionPolicy`(**条数 + 账龄双限**:只按条数等于"一年一备的机器存了八份同一个月",只按账龄等于"每次开机的备份都留着")
- `webdav_store.dart` —— `WebDavBackupStore`:PROPFIND/GET/PUT/DELETE 的远端实现(坚果云 / Nextcloud / 自建 Apache),一档一个 JSON 文档;它走的是文档形状,套 `BackupArchiveStore` 的字节形状需要一层适配 —— **这层适配还没有做**

不支持的 schema 版本是**整包拒绝**,不做部分应用:半恢复的设置看起来跟恢复成功一模一样。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 依赖

- `crypto ^3.0.0` —— SHA-256(摘要自己写是不造轮子的反面)。`webdav_client ^1.2.2` 给远端。`pure_live_utils` 给 `Clock`。

## 平台矩阵

纯 Dart(`dart:convert` + `crypto` + `webdav_client`),不含 `dart:io`,理论上 web 可用;但 `webdav_client` 依赖浏览器 XHR/http 适配器,其在浏览器端的**实际行为未验证**。压缩**没有做**:gzip 要么引 `dart:io`(丢 web),要么引 `archive`(新增依赖),当前取舍是先不压。

## 验证

- 分析:`dart analyze packages/foundation/backup`(2026-10-11:0 issue)
- 测试:`dart test` —— **11 例**全绿(逐域隔离、手改档拒凭据、未知域跳过、不支持版本整包拒绝)。
  `codec.dart` / `archiver.dart` / `RestoreEngine.plan` **没有新增测试**;行为用仓库外一次性脚本观测:
  写入→读回摘要一致、改 payload 一个值 → `digest does not match`、翻 `includesCredentials` → 拒、
  `plan` 报 `1/2 domains, 3 keys` 且 `hasUnmatchedDomains=true`、`maxArchives=2` 时连写 4 份后远端只剩最新 2 份。
  脚本已删除,观测不可重放。

## 未验证

- **真机 WebDAV**:上传/列表/下载/删除与鉴权失败路径没在坚果云或 Nextcloud 上跑过;`connect()` 的 `ping()` 之外没有超时与重试策略。
- 摘要覆盖的是**规范化 JSON**,不是原始字节:传输层若改写了转义或键顺序,校验仍然通过(这是设计意图,但意味着摘要防的是"内容与声明不符",不防"字节级篡改")。
- `archivesToPrune` 对**名字不带时间戳且 store 不报 modifiedAt** 的档只施条数上限、不施账龄(不敢猜着删),这条保守路径未在任何真实 listing 上验证。
- 恢复过程**不是原子的**:逐域写,中途崩溃会留下"一半新数据一半旧数据"的状态;`RestoreJournal`(类似迁移日志的断点)还没实现。
- 整包零消费者:`grep -rn pure_live_backup apps` 为空,备份按钮在 app 侧还不存在。

