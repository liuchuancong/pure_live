# 设计取舍

## 1. 模块数量由实测重复决定,没有 misc

叶子包被所有人继承,所以它的失败模式不是缺东西,而是长成一第二个 `dart:core`。
判定规则:**两个以上包真正用到,且语义与业务无关**,才进这里;否则留在功能包。
"以后可能用得上"不是理由 —— 挪进来容易,请出去要先修所有调用点。

模块数不是常量。第一批五个是这么来的;后来九个每个都对应一次 grep 计数,写在各自文件头的注释里:

| 模块 | 实测重复 |
|---|---|
| `errors` | 13 个包各写一份 `class XException implements Exception` + 自己的 toString,多数丢了 cause |
| `equality` | `ecosystem/platform` 一处就有 12 个手写 `operator ==`;含 List 字段的按身份哈希,相等的一对会 disagree |
| `conversion` | providers / storage / release / settings 各自写 `int.tryParse('$raw')` 与 `raw is num ? … : null` |
| `validation` | 82 处手写 `ArgumentError` / `StateError`,消息格式各不相同 |
| `numbers` | 9 处直接 `.clamp()`(返回 `num`,调用点被迫再转),`64 * 1024 * 1024` 这类裸字节常量散在 cache / sandbox / permission |
| `types` | 偏好编解码里同一个 `raw is bool ? raw : null` 写了 6 次;`Result<void, E>` 根本无法构造 |
| `identifiers` | 复合缓存键用分隔符拼接,分隔符出现在 id 里就让两个对象共享一条缓存 |
| `async` 新增件 | `ecosystem/task` 有自己的 `TaskCancelledException` 与内部 bool,重试环再定义一份取消语义 |
| `math` | 进度条 / 音量 / 缓冲三处各写同一套 min-max 映射,零宽区间一处给 NaN 一处给 Infinity |

`result` / `strings` / `time` / `collections` 的理由不变,`conversion` 与 `strings` 的分工是:后者处理**人已
经写下来**的文本与其脱敏,前者处理**形状未知**的运行时值。

## 2. 顶层函数与扩展并存

`groupBy` / `mapNotNull` / `distinctBy` / `chunked` 保持顶层函数形式,因为已有六个包这样调用;
新能力优先做成扩展(`uniqueBy` / `appended` / `partitionBy`),读起来是"数据上的操作"而不是"工具类的方法"。
同一个语义不做两份实现:扩展内部不复述顶层函数的算法。

## 3. `Clock` 是函数类型,不是接口

消费者存的都是"一个可调用值",包成抽象类只会在调用点多一层 `.now()`。
但 `systemClock()` 走 `package:clock` 的全局时钟,这样测试里 `withClock(...)` 能影响没注入时钟的代码 ——
这是本包依赖 `clock` 的唯一理由,不是"以后用得上"。

## 4. 有界是默认,不是选项

`AsyncMemoizer.maxEntries`、`AsyncOnce.maxEntries`、`ListUtils.appended(maxSize:)` 都强制调用方给出上限。
缓存没有上限就是带个好名字的内存泄漏:这里的键是 ContentRef 和 URL,用户滚动就能无限增长。
`ttl` 允许是 `Duration.zero`(永不过期),但条数不允许无限。
淘汰跟**写入序**,不跟时间戳比较:两次写在同一 tick 落下时,`storedAt.isBefore` 会把最新的那条当成最旧的
踢掉 —— 这条是被测试抓出来的。

`AsyncOnce` 与 `AsyncMemoizer` 都在,区别是后者需要时钟与过期,前者只是一闩:没有 TTL 就不能在两次读之间
悄悄变答案。失败都不记,否则一次瞬时的 io 错误会把功能永久锁死。

## 5. 取消不是失败

`retryAsync` 看到 `OperationCancelledException` 立即上抛,不进入重试预算。
理由见 platform-models §20 不变量 9:用户按了返回,重试就是在违背他的操作意图。
异常类型住在 `cancellation_token.dart`(信号与"被它打断"是同一件事的两半),`retry.dart` 只是 re-export。

## 6. 截断要选策略

`String.truncate` 按码元截,快但能撕裂代理对;`Truncator.at` 提供 hard / word / grapheme 三种,
默认 grapheme。标题、简介这类人写的文本用 `Truncator`,固定宽度字段(时间戳、id)用 `truncate`。
CJK 词间无空格,所以 word 模式把"汉字与非汉字之间"也算边界。

## 7. 脱敏集中在 strings

`redactHeaders` / `redactQuery` 只在这一处知道哪些头与查询参数敏感。
日志、诊断、备份三个出口都调它,而不是各自维护一份黑名单 —— 半完成的脱敏比不脱敏更危险,
因为它会让人以为已经处理过了。

## 8. epoch 单位必须写在名字里

`Timestamps.fromSeconds` / `fromMilliseconds` / `fromMicroseconds` 三个名字,不做"猜单位"的默认路径。
`parseAmbiguous` 是给同一字段跨版本换单位的源用的例外,阈值与理由写在文档注释里。
单位读错的后果是过期时间偏三个到六个数量级,看起来像"票据很久以后才过期"。
