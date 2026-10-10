# pure_live_search_feature

> 职责:搜索域的**消费面** —— 查询词的规范化、历史、跨 App 一致的结果排序、单世代执行。
> 扇出与逐源失败隔离在 `services/search`,站点实现在 `providers/*`;这里不认识任何站点。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `domain/search_term.dart` | `SearchTerm`(`display` + 折叠后的 `matchKey`) | 四个 App 各自 trim/大小写处理会让同一次搜索变成两条历史;折叠规则必须只有一处 |
| `domain/search_history.dart` | `SearchHistoryEntry` + `SearchHistoryRepository` 接口 | presentation 只依赖规则,不依赖存储;换库、按账号分表、不存历史都是换实现 |
| `domain/search_result_order.dart` | `rankSearchResults` / `relevanceOf` / `RankedResult` | 聚合器按"谁先答"给桶,直接拼接就让同一查询在不同启动顺序下换行序 |
| `domain/search_controller.dart` | `SearchController` + `SearchOutcome`(Answer/Rejected/Superseded) | 世代栅栏属于"知道用户又敲了一个字"的这一层;service 只知道一次查询 |
| `data/stored_search_history.dart` | `StoredSearchHistory`(kv、带版本信封、有界、可读回) | 落盘格式与迁移是这个包的债,不是 App 的 |

## 依赖

允许:`L0 foundation`(`pure_live_utils` / `pure_live_storage`)+ `ecosystem/platform` + `services/search`。
禁止:同层互依、providers 直连、应用壳、Flutter/presentation 反向依赖。
见 [依赖规则](../../../docs/architecture/dependency-rules.md) §3 与 `tool/check_architecture.dart`。

## 行为契约

- 空词(折叠后为空)在扇出**之前**被拒:返回 `SearchRejected`,`SearchAggregator` 一次都不被调用。
- 新一次 `run` 放弃上一次:被放弃的答案返回 `SearchSuperseded`,**不写历史**;已在途的 io 由 service 自己走完,
  这里不谎称取消了它。
- `currentToken` 只在**被放弃**时触发;正常答完不触发。spinner 等的不是成功。
- 历史按 MRU;时间戳相同按 `matchKey` 定序,所以两个 App 读同一份数据渲染同一顺序。
- 读盘不抛:不可读 → 空列表 + `onReadFailure` 记账;版本比本机新 → 不读也不改写。

## 平台矩阵

纯 Dart。Android / Android TV / Windows / iOS / web 一致;无 io、无插件、无条件导入。

## 未验证

- **没有 App 消费者**:`apps/pure_live` 目前不装配这个包(拆壳波次未完成),所以以上契约只被包内 22 个测试钉住,
  没有真机 UI 验证。
- `presentation/` 为空,按计划留给 UI 波(台账 §3 第 3 行)。
- 排序的三档相关性是内容规则,没有做过用户侧点击验证;"重复标记不删除"是否会改变可见结果数,取决于 UI 怎么渲染。
