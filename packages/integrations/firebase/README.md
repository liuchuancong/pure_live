# pure_live_firebase

> 职责:Firebase 厂商 SDK 接线,唯一允许直接依赖处

| 项 | 规则 |
|---|---|
| 层 | integrations(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;厂商 SDK 只允许出现在本层。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_firebase.dart`;内部实现放 `lib/src` |

## 内容

- `firebase_bootstrap.dart` —— `FirebaseBootstrap.ensureInitialized`:**没配 google-services / GoogleService-Info.plist 不炸第一个 frame**,回 `FirebaseStatus.unconfigured`;`invalid-api-key` / `no-options` / 消息里带 `FirebaseOptions` 都算"未配置"(社区构建的常态),其余算 `failed`。重复调用直接回记录,不再碰 SDK
- `firestore_remote.dart` —— `FirestoreSyncRemote implements RemoteStore`(`users/<uid>/sync`):
  - **游标是"见过的最大 updatedAt"**,不是 Firestore 的 page token —— token 会过期且不可比较,而 `SyncCursor` 要求同一路径单调前进
  - 拉取按 `updatedAt` 升序 + `pageSize`;短页=拉完,满页=引擎的翻页走查会继续要
  - 推送**按 500 条一批切**(Firestore 单批提交上限,超了不是变慢是整批失败),超过 `maxPushRecords` 的留在本地待下次(离线删了一百条收藏不该被一个上限吃掉),`truncatedPushes` 记账
  - 两端都用 `isCredentialKey` 拒凭据(引擎之外再挡一次:客户端 bug 不该是令牌进没进云端唯一的门)
  - 文档映射是**纯函数**(`documentFromRecord` / `recordFromDocument` / `encodeSyncCursor` / `decodeSyncCursor`):坏文档**跳过而不是抛**,一条旧版本写的坏行不该停掉整个用户的同步;墓碑**不带 value**,删除不能在云端留下被删内容的副本
  - key 走 `Uri.encodeComponent`:收藏键是斜杠分隔的复合串,原样拼进文档路径就变成子集合
- `crash_reporting.dart` —— `CrashGate` + `CrashConsentStore` 端口 + `CrashReporter` 端口 + `CrashLogSink`:
  - 开关默认关(docs/diagnostics/crash-report.md 的隐私规定),`unknown` 期间的报告进**有界缓冲**(首启崩溃发生在弹窗有答案之前,丢了就丢了唯一证据)
  - **答"不"就把缓冲销毁**,不是"留着以防以后改主意"
  - 缓冲里的报告超过 `maxAge`(默认 6h)不再补发(`CrashDropReason.expired`)—— 那描述的是设备早已不在的状态
  - 上传器抛异常只记 `uploadFailed` 并继续:崩溃上报器自己崩是第二次故障
  - `CrashLogSink` 挂在 `LogRouter` 上,**而不是每个 catch 里调一次**:忘记上报的那条异常路径恰好是唯一要紧的那条;`minLevel = error`(只报 fatal 会漏掉普通的未捕获异常)

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 依赖

- `firebase_core ^4.15.0`、`cloud_firestore ^6.10.0`(版本与 `apps/pure_live/pubspec.yaml` 一致,避免 workspace 里出现两份)
- `pure_live_sync`(`RemoteStore` 契约)、`pure_live_logging`(`LogSink`/`LogRecord`)、`pure_live_utils`(`Clock`)
- **没有** `firebase_crashlytics` / `firebase_analytics`:它们需要构建期 gradle 插件,接入与否在发布阶段决定,所以这里给的是端口 +  consent 门,厂商绑定由带插件的那个构建加。

## 平台矩阵

含 `cloud_firestore` / `firebase_core`,因此是 Flutter 包(Android / iOS / web / macOS / Windows 视插件支持而定);
**Android TV 上的 Firestore 未验证**(插件未声明 TV 支持,应用侧也还没接)。`dart run` 跑不了本包代码(要 `dart:ui`),
所以本包的验证只有静态一层。

## 验证

- 分析:`dart analyze packages/integrations/firebase`(2026-10-11:0 issue)
- 测试:**无**(`test/` 只有脚手架留下的 `.gitkeep`)。本包是 Flutter 依赖包,一次性 `dart run` 脚本起不来(要 `dart:ui`),
  `CrashGate` 的三条路径(unknown 缓冲 / granted 补发 / declined 销毁)、批大小切分、游标编解码**都只经静态检查与人工阅读**。

## 未验证

- **没有真机 Firestore**:读写、`orderBy` + `where` 复合索引是否要求(很可能要求:key 唯一性靠什么保证也没验)、
  `count()` 聚合在离线/受限项目下的错误形状,全部未观测。
- 凭据谓词由注入函数决定;真实键布局里"哪些算凭据"由 `ecosystem/identity` 与 App 组合根给,本包没有那份词表。
- Crashlytics 的实际绑定不存在,`CrashReport` 的字段是否够用只有等真接入时才知道。
- 整包零消费者:`grep -rn pure_live_firebase apps` 为空 —— `apps/pure_live` 目前自己直连 `cloud_firestore`,
  这条边应该改走本包(见下方待办)。

## 待办

把 `apps/pure_live` 对 `cloud_firestore` 的直接依赖改成本包的 `FirestoreSyncRemote`(依赖规则:厂商 SDK 只允许出现在
integrations 层)。这是一次 App 侧接线,不属于本包的改动。
