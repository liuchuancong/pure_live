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
- `engine.dart` —— `BackupEngine.build` 与 `RestoreEngine.apply`:**逐域隔离**,一个域失败只记在它自己头上,重试可以只喂 `onlyDomains`;两端都用注入的 `isCredentialKey` 拒凭据(手改的档也带不进来)

不支持的 schema 版本是**整包拒绝**,不做部分应用:半恢复的设置看起来跟恢复成功一模一样。

## 
## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
