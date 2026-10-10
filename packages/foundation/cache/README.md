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

## HTTP 语义与加载缓存(2026-10-11 补齐)

| 文件 | 提供 |
|---|---|
| `src/cache_control.dart` | `CacheControl.parse` / `lifetimeFor`、`CacheVerdict`、`decideCacheUse`、`revalidationHeaders`、`parseHttpDate` |
| `src/http_cache.dart` | `HttpCache`(按 url 存字节、单飞、条件请求、SWR)、`HttpCacheEntry`、`HttpFetchOutcome`、`HttpCacheRead` |
| `src/loading_cache.dart` | `LoadingCache<K,V>`(miss 时加载 + 同键并发合并)、`JsonDocumentLoader`、`CacheLoadFailure` |
| `src/cache_stats.dart` | `CacheStats`(命中率、合并次数、淘汰量、加载耗时) |

规则:

- **年龄按源的 `Date` 算**,不按"我看到它的时刻"。一份在 CDN 里躺了一小时的响应,到这里就已经老了一小时。
- `immutable` 压过时钟;`no-cache` 压不过(它要求每次都回源验证);共享缓存不吃 `private`;
  过期且**没有 validator** 的条目判为不可用,而不是猜一个寿命。
- `304` 不是"没有答案":它意味着手里的 body 仍然正确,只把新鲜度事实往前推 —— 把 304 当失败会重新下载
  刚刚证明过已经有的那份 body。
- `stale-while-revalidate` 立刻返回旧值,刷新在背后跑且**不 await**;后台刷新失败就留着旧值,下次读再试。
- `serveStaleOnError` 默认开(弱网下把屏幕变成空白比给一份旧数据更糟),但签名流地址那类
  "正确性优先于可用性"的调用方要显式关掉。
- url 作键先 `sha256`:url 无界且含文件名不该有的字符,映射是单向的,所以条目自己留着它来自哪个 url。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
