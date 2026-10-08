# pure_live_cache

> 职责:有界缓存策略与失效规则,含内存与磁盘两级

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_cache.dart`;内部实现放 `lib/src/` |

## 内容

- `policy.dart` —— `CacheNamespace`(docs/services/cache.md 那 9 个)、`CachePolicy`(ttl / maxBytes / maxEntries / 淘汰法)、`CacheUsage`
- `store.dart` —— `CacheHub` 按命名空间发 `NamespaceCache`;`NamespaceCache` 上**没有**接命名空间参数的方法,所以一个插件读不到、清不掉别人的条目

这是内存层。磁盘层用同一套 `CachePolicy` 接在后面,两边对"超容量"的判断才一致。`write()` 返回本次被逐出的 key,方便上层记压力指标。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
