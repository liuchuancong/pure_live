# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `FeedAggregator` / `CapabilityFeedAggregator`:按 `CapabilityRegistry` 枚举 feed 源、单源超时与失败隔离、
  节顺序取注册顺序而不是到达顺序,游标贯穿到源并原样带回(刷新 = 重新取第 1 页)。
  注:「原样带回」在 2026-10-10 之前是不成立的,见下一条修复。
- **修复(2026-10-10)**:上面那条「游标贯穿到源并原样带回」以前只做了一半 —— 请求里的 `PageRequest` 是
  **全体源共享的一份**,而 `PageResult.mode` / `nextCursor` **被丢弃**:`cursor` 模式的源第一次答完就再也没法
  续页(它给的 token 无处可读),共享的那份还会把 A 源的游标喂给 B 源 —— `PageRequest.cursor` 优先于页号,
  所以后果是静默错页而不是报错。现在 `feed(page, {cursors, cancellation})`:`cursors` 按源给,
  `FeedSection` 带出 `mode` 与 `nextCursor`,并按声明的三态校验答复:single-shot 却说还有、
  cursor 说还有却不给 token、fixed-page 却给 token,一律记进 `contractViolation`
  (屏幕上的结果一样,但「首页为什么停止加载」需要知道是哪个源在撒谎,静默归一化会把唯一的证据抹掉)。
  `cancellation` 只中止装配:已发出的请求不归这层取消(与 `perSourceTimeout` 同一条界),
  但被放弃的运行不再把十几个源报成 `failed`。
- `FeedSection` 不带标题:首页编排(哪些节显示、顺序、名字)是用户数据,聚合器再造一个标题就是两处真相。
- 节内丢弃指向别源的行(`foreignItems`)与重复 ref(`duplicateItems`);跨源不去重。
