# pure_live_vod

> 职责:点播域的两条规则 —— **什么位置值得续播**,与**这一集之后播哪一集**。
> 站点取流在 `providers/*`,播放在 `integrations/media`;这里不认识 url、票据与播放器状态。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `domain/episode_navigator.dart` | `EpisodeQueue` / `EpisodeStep` / `EpisodeDirection` / `EpisodeNavigationFailure` / `sameContent` | vod-architecture.md 把连播定义成 PlaybackQueue;队列的顺序就是源的顺序,而"提交"只发生在播放器真的打开之后 |
| `data/watch_progress.dart` | `WatchProgress` / `WatchProgressRepository` / `StoredWatchProgress` / `WatchProgressReadFailure` | 续播阈值是产品规则不是字段;**行的形状**(版本、`positionMs`/`updatedAt` 缺哪个)由本包说,"信封/命名空间/记账有上界"是 `storage` 的机制说的 |

## 行为契约

### 连播
- `stepNext()` / `stepPrevious()` **只提议,不动光标**;`commit(opened)` 才移动,且必须是本队列里的集。
- 集与集的比较只看 `sourceId + contentId`(`sameContent`)。用 `ContentRef` 自带的全字段相等是本轮修掉的缺陷:
  票据层回来的 ref 带 `parentId`/`metadata`,和 detail 的子项**不相等**,连播会静默停在最后一集。
- 到边返回 `direction: none` **且** `atEdge: true`,屏幕才分得出"放完了"和"队列是空的"。
- `withEpisodes()` 刷新列表时尽量保住当前位置;当前集被删了才从第一集开始。
- 空队列合法;给空队列指定 `current` 是 `EpisodeNavigationFailure`,不是 `index == -1` 的静默半坏状态。

### 续播
- 双阈值:`position < resumeLead`(默认 30s)不续播(片头不值得回),
  `position >= duration - tailThreshold`(默认 30s)也不续播 —— **看完的剧集重开该从 0 开始**。
- `duration` 未知时只用片头规则,不猜长度;`progress` 此时返回 null 而不是编造比例。
- 键是 `identityKey([sourceId, contentId])`(带长度前缀),所以含 `/` 的 id 不会让两集共享一行
  (旧实现用 `/` 直拼,`a`+`b/c` 与 `a/b`+`c` 会互相覆盖)。
- 落盘 `{v:1, positionMs, durationMs, updatedAt}`;无版本字段当 v0 读;版本比本机新 → 拒读且不改写。
- 写拒绝:负位置、零/负时长(`ArgumentError`)。负时长会让每个位置都"已超尾阈值",从此永不续播。
- 读不抛:坏行 → null + `onReadFailure` 记账,下一次写入自然治好。
- 时间经注入 `Clock`;按 `namespace` 分 App。

## 依赖

允许:`ecosystem/platform` + `foundation/{storage,utils}`。禁止:providers 直连、同层 feature、App 反向依赖。

## 平台矩阵

纯 Dart;落盘经 `pure_live_storage`,Android / Android TV / Windows / iOS / web 一致。

## 未验证

- **没有 App 消费者**(拆壳波未完成),20 个测试是唯一的门。
- 双阈值的 30s 是沿用旧常量 + 新增尾阈值,**没有做过用户侧验证**;尾部阈值可能该随视频长度变(短视频 30s 占比过大)。
- 连播不含"循环/重复本集"模式:契约没写,这里就不发明。
- `presentation/` 为空,留给 UI 波。
