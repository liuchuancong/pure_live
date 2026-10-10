# 设计取舍

## 1. 只有五个模块,没有 misc

叶子包被所有人继承,所以它的失败模式不是缺东西,而是长成一第二个 `dart:core`。
判定规则:**两个以上包真正用到,且语义与业务无关**,才进这里;否则留在功能包。
"以后可能用得上"不是理由 —— 挪进来容易,请出去要先修所有调用点。

## 2. 顶层函数与扩展并存

`groupBy` / `mapNotNull` / `distinctBy` / `chunked` 保持顶层函数形式,因为已有六个包这样调用;
新能力优先做成扩展(`uniqueBy` / `appended` / `partitionBy`),读起来是"数据上的操作"而不是"工具类的方法"。
同一个语义不做两份实现:扩展内部不复述顶层函数的算法。

## 3. `Clock` 是函数类型,不是接口

消费者存的都是"一个可调用值",包成抽象类只会在调用点多一层 `.now()`。
但 `systemClock()` 走 `package:clock` 的全局时钟,这样测试里 `withClock(...)` 能影响没注入时钟的代码 ——
这是本包依赖 `clock` 的唯一理由,不是"以后用得上"。

## 4. 有界是默认,不是选项

`AsyncMemoizer.maxEntries`、`ListUtils.appended(maxSize:)` 都强制调用方给出上限。
缓存没有上限就是带个好名字的内存泄漏:这里的键是 ContentRef 和 URL,用户滚动就能无限增长。
`ttl` 允许是 `Duration.zero`(永不过期),但条数不允许无限。

## 5. 取消不是失败

`retryAsync` 看到 `OperationCancelledException` 立即上抛,不进入重试预算。
理由见 platform-models §20 不变量 9:用户按了返回,重试就是在违背他的操作意图。

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
