# pure_live_storage

> 职责:统一 kv 与安全存储,承载设置迁移边界

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_storage.dart`;内部实现放 `lib/src/` |

## 内容

- `stores.dart` —— `KeyValueStore` / `SecureStore` 接口 + 类型化读取(`readInt` 兼容旧库存成文本的数字)+ 内存实现;真实后端由应用组合根绑定
- `file_key_value_store.dart` —— `FileKeyValueStore`:单文件 JSON 的 `KeyValueStore`,首次访问时载入、每次改动写穿
- `migration_runner.dart` —— `MigrationRunner` / `MigrationDomainSpec` / `KeyValueMigrationJournal`:逐域迁移流程
- `migration.dart` —— `SettingsMigrator`(旧键 → 新键 + 转换函数表,未知键记录不丢)+ `SchemaMigrator`(版本步进链,断点续迁)
- `preferences/preference_key.dart` —— `PreferenceCodec<T>`(闭集 bool/int/double/String/List<String> + `of()` 自定义)、`PreferenceKey<T>`(名 + codec + 默认值 + 可选 `validate` + 可选 `upgrade`)、`PreferenceKeyInfo`、`PreferenceFailure` / `PreferenceRejection` / `PreferenceChange` / `PreferenceDecodeReject`
- `preferences/preferences_store.dart` —— `PreferencesStore`:类型化偏好的落盘机制(信封 `{v,c,value}`、命名空间、`putIfAbsent` 首启语义、`exportAll` / `importAll` 逐项报告、变更流、`upgradedKeys`)

迁移语义按 [docs/migration/settings-migration.md](../../../docs/migration/settings-migration.md) 与 [v1-to-v2.md](../../../docs/migration/v1-to-v2.md):一个键转换失败只记在它自己头上,其余继续;schema 版本每步落盘,重试从断点接上,链上有缺口或重复步在动手前就报错。

`FileKeyValueStore` 的三条规矩,都是围绕"别把用户的数据变成没有":

- **读不懂就不覆盖**:文件存在但不是 `{"key": value}` 形状时抛 `StoreCorruptedException`,之后的 `write` 也一并拒绝。
  把"读不出来"当成"本来就是空"会让下一次写入把不可读永久变成丢失(空文件例外:那是首次写入中途被杀留下的,里面从来没有数据)。
- **编码失败 = 什么都不发生**:先把候选 map 编码,再动内存与磁盘,所以一个不能序列化的值(例如 `DateTime`)抛
  `ArgumentError`,而文件与原值分毫未动。
- **写 = 临时文件 + rename**:读者只会看到完整的旧文件或完整的新文件;所有操作走一条队列,否则两个扩展同时
  读-改-写会在同一个文件上互相覆盖。

应用目录由组合根与 `pure_live_files` 决定,本包只收一个路径 —— L0 之间不建依赖边。

## 偏好机制为什么在本包

`docs/architecture/application-portfolio.md` §5 把"机制"与"词汇表"分开:键是消费方自己声明的,存储只负责
**怎么存、怎么验、怎么播报**。它原先住在 `features/settings`,而 §3 禁 feature 同层互依 —— 结果是需要它的
四个地方各自手写了版本化文档(`features/home` 的 `{v,order,hidden}`、`features/search` 的 `{v,items}`、
`features/vod` 的进度行、app 的 appearance)。搬进 `foundation/storage` 而不是新建 `foundation/preferences`,
理由是同一条 §3:偏好机制必须用 `KeyValueStore`,那是本包的类型,而 L0 之间不建依赖边(叶子只有 utils 与
logging)。第二个理由更实际:**信封之前的旧行要靠 schema step 回写**,`SchemaMigrator` 就在这层。

钉住的规则:

| 规则 | 落法 |
|---|---|
| 读永不抛 | 任何坏形状回默认值,并记 `PreferenceRejection`(只记原值的**运行时类型**,不记原值:偏好里可能是路径或标签,不该进诊断报告) |
| 写会抛 | 越界值抛 `PreferenceException`,不落盘 —— 读端宽容不等于把坏值写下去 |
| 类型不被字符串化 | 门禁是信封里的 `c`(codec 名),不是 JSON 类型:同名换类型判 `codecMismatch`,免得 `'${5}'` 把数字变成 `'5'` 后错误永久化 |
| 首启 | `putIfAbsent` 而不是 `read() == default`:后者分不出"没设过"与"设回默认值",于是首启提示会为用户已经关掉的东西再弹一次 |
| 两个 App 共用一个文件 | `namespace` 前缀是唯一隔离手段;`exportAll` 也只交本命名空间的行,备份不会带走别家的键 |
| 旧形状可升级不可丢弃 | `PreferenceKey.upgrade` 读信封前的行;升级记进 `upgradedKeys` 而**不是** `rejections`(更老的形状不是故障);**读不回写**,回写是 schema step 的活 |
| 拒绝要说得出为什么 | codec 抛 `PreferenceDecodeReject(reason)` 就是"我认识这形状但拒了",记成 `refusedByCodec` 并把理由带进 `PreferenceRejection.reason`;返回 null 只表示"不认识"。codec 抛**别的**东西照原样上抛 —— 那是 codec 的 bug,不该被洗成一个看起来正常的默认值 |
| 诊断账本有上界 | `rejections` 只留最近 `kPreferenceRejectionLimit`(64)条,最旧的先走;`upgradedKeys` 只列 `kPreferenceUpgradeReportLimit`(64)个键,其余计入 `upgradedCount` 而不是无声丢掉 —— "还有更多"本身就是需要知道的事 |
| 备份部分可用 | `importAll` 逐项 accept/reject 并回报 `unknownKeys`,坏一条不连坐;更大信封版本按拒绝处理,放宽它属于一次真正的 schema 升级 |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 迁移流程(`MigrationRunner`,不是键名表)

三份 `docs/migration/*.md` 给的是**流程 + 键名表**。键名表里的 v1 具体键名不在本仓里(v1 源码已删),
所以这里只实现流程,键名留给各域自己的 spec 带 —— 编一组键名出来测试会全绿,而真迁移时会全错。

钉住的规则(逐条来自 v1-to-v2.md 与 database-migration.md):

| 规则 | 落法 |
|---|---|
| 摘要 → 用户确认 → 才动手 | `confirmed` 默认 **false**:没拿到"是"就一个字节都不读不写 |
| v1 只读不改 | `MigrationDomainSpec` 只暴露 `read`(流)与"写 v2"的回调 —— 结构上拿不到写 v1 的手 |
| 逐域独立、失败隔离可重试 | 每域单独跑;reader 断了只影响这一域,其它域照跑;该域不标记完成 |
| 断点续迁不重复 | `MigrationJournal` 记住每域已迁的键 + 已完成的域;重跑时已完成的域**根本不读**,半路断的域跳过已写键 |
| 单条失败进"待处理",不阻塞整体 | `MigrationReject`(或映射随便抛什么)只让这一行进 `RejectedRecord` 桶;域仍可完成 |
| 计数校验 + 差异报告 | `scanned == migrated + rejected` 才算对得平;`expectedCount` 不符则该域不完成并计入 `discrepancies` |
| 绝不清空 | 全程没有删除 v1 的 API;回滚按文档就是"清 v2 重来" |

`KeyValueMigrationJournal` 把"哪些键已迁"记成一份键列表。这是**键值后端的代价**,不是模型的必然:
一个几万条的历史域会带一份同样长的键表,而 Drift 绑定该把它换成按行的已迁标记 —— 换的是这个类,不是接口。

## 验证

- 分析:`dart analyze packages/foundation/storage`(0 issue)
- 测试:`dart test` —— **84 例** = 文件 KV 与并发/损坏语义、迁移流程、存储接口,加自 `features/settings` 搬来的
  32 例偏好机制测试(信封与 codec 门禁、读不抛并记账、写拒越界、首启、命名空间隔离、变更流与 dispose 幂等、
  `importAll` 逐项报告、旧形状升级的两个方向)

## 未验证

- **与 `FileKeyValueStore` 的真实串接没跑过**:两个消费者(`features/home` 的布局行、`features/search` 的历史行)  的测试都只用 `MemoryKeyValueStore`。真机上偏好与收藏/历史同处一个 JSON 文件时的行为,以及 `dispose()` 之后  还能不能读到流,都没有观测。两个仓库的 `dispose()` 也还**没有调用者** —— App 侧尚未装配这两个仓库。
- `importAll` 收到**更大**信封版本时按拒绝处理,不是迁移。放宽它的正确做法是加一条 `SchemaStep`,
  但这条组合(`PreferencesStore` 的行由 `SchemaMigrator` 升级)还没有实现与测试。
- `SecureStore` 的真实后端由组合根绑定,本包的内存实现只证明接口形状,不证明平台安全存储的行为。

