# pure_live_settings

> 偏好设置的**机制层**:类型化键、带版本的落盘信封、命名空间隔离、变更通知、导入/导出与逐项校验报告。
> 本包**不定义任何具体偏好**——键由使用它的 App 声明(见 [../../../docs/architecture/application-portfolio.md](../../../docs/architecture/application-portfolio.md) §5)。

## 为什么这样切

四个 App 共享这一个包。如果把 `preferredQuality`、`homeTabOrder` 这类键写进来,就等于让一个产品
的词汇表变成四个产品的 API:直播的默认弹幕开关会出现在音乐客户端的公共面里,而任何一侧想改语义
都得动共享包。所以这里只有 `PreferenceKey<T>`(名字 + 类型 + 默认值 + 可选范围规则)和
`PreferencesStore`(怎么存、怎么校验、怎么通知),词汇表留在各 App。

## 规则

1. **读永不抛**:没有有效值就回 `defaultValue`。设置面不能因为一条坏数据而开不了。
2. **但坏数据必须可见**:每次回退都记 `PreferenceRejection`(键名 + 失败类型 + 原值的运行时类型,
   **不记原值本身** —— 偏好里可能存路径或标签)。`store.rejections` 给诊断面读。
3. **写会抛**:越出 `validate` 范围的值直接 `PreferenceException(invalidValue)`,不静默写坏。
4. **信封带版本与 codec 名**:`{'v':1,'c':'bool','value':true}`。同名换类型时旧值判为 `codecMismatch`
   并回默认,而不是被字符串化成"看起来对"的值。
5. **`putIfAbsent` 才是首启用判断**:`read() == default` 分不清"没设过"和"用户设回默认",
   靠它做首次横幅会对后者再弹一次。
6. **命名空间隔离 App**:两个 App 共用一个 store 文件时靠 `namespace` 分界,前缀外的键一律不可见。
7. **导入是外部输入**:`importAll` 按调用方给的键表逐项校验,未知/坏形状只拒该条并计入报告,
   其余照常落地 —— 全有才落地的语义等于永远恢复不了。
8. **变更流不补历史**:后订阅的听不到之前的改动;设置面的正确顺序是先 `read` 再 `listen`。
9. **`dispose()` 只关自己的流**,不关注入的 `KeyValueStore`(所有权在组合根)。

## 公共面

| 类型 | 作用 |
|---|---|
| `PreferenceCodec<T>` | `boolean` / `integer` / `real` / `string` / `stringList` + `of()` 自定义 |
| `PreferenceKey<T>` | 一个偏好:名称、codec、默认值、可选 `validate` |
| `PreferencesStore` | `read` / `readIfStored` / `write` / `putIfAbsent` / `reset` / `isStored` / `exportAll` / `importAll` / `changes` / `rejections` / `dispose` |
| `PreferenceException` / `PreferenceFailure` / `PreferenceRejection` / `PreferenceImportReport` / `PreferenceChange` | 具名失败与报告 |

## 用法(消费方声明自己的键)

```dart
const quality = PreferenceKey<String>(
  name: 'player.preferred_quality',
  codec: PreferenceCodec.string,
  defaultValue: '',
  validate: _knownQualityLabels.contains,
);

final settings = PreferencesStore(store: appKeyValueStore, namespace: 'pure_live.settings.');
await settings.putIfAbsent(firstRun, true);
final label = await settings.read(quality);
```

## 允许 / 禁止依赖

- 允许:`pure_live_storage`(L0 的 `KeyValueStore` 接口)、`dart:async`。
- 禁止:任何 App 包、Flutter SDK、其它 features 包、具体产品的键定义。

## 平台与验证状态

纯 Dart + 注入的 KV 接口,平台无关。`dart analyze` 0 issue、架构护栏 `--strict` 通过,
`dart test` **32 例**(本包第一批测试:信封与 codec 名的门禁、读永不抛并记账、写拒越界、
`putIfAbsent` 的首启语义、命名空间隔离与备份只含本命名空间、变更流与 `dispose` 幂等、
`importAll` 的逐项接受/拒绝、以及下面那条旧文档升级路径)。

## 旧文档升级(`PreferenceKey.upgrade`)

**采纳这套机制是否安全,取决于这一条。** 没有它,一个在信封之前写下的行会被判成
`unreadableEnvelope`,读回落到 key 的默认值,而**下一次写入就把默认值当成用户的选择存下去** ——
用户的设置不是被读到,是被替换掉。所以:

- `upgrade(raw)` 返回 codec 能吃的**内层值**(不是信封),或返回 null 表示"这形状我没写过"。
- 升级成功记进 `upgradedKeys`,**不进** `rejections`:"盘上是更老的形状"不是故障。
- 读**不回写**。一个只是来显示值的界面不该顺手改存储;把行换成信封是
  `pure_live_storage` 的 `SchemaMigrator` 步骤该做的事,`upgradedKeys` 就是告诉调用方还有活要干。
- 升级出来的值仍要过 `validate`,越界照样是 `invalidValue` 回落默认。

## 未验证

- 与 `FileKeyValueStore` 的真实文件往返(属存储包自己的用例覆盖范围;本包用 `MemoryKeyValueStore`)。
- `importAll` 收到**更大**信封版本时仍按"拒绝并报告"处理,不是迁移 —— 已知的形状边界,
  放宽它属于一次真正的 schema 升级,跟着 `SchemaMigrator` 的步骤一起做。
- 零消费者:机制本身还没有 app 或 feature 装配(台账 §2bis 第 4 组),形状要等第一个调用点来钉。
