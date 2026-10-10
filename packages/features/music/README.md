# pure_live_music_feature

> 职责:音乐域的**播放队列规则**与**歌曲到流的解析契约**。
> 队列不发请求;解析由宿主提供的 lx 桥接完成 —— 本包不认识 `providers/music`。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `domain/music_queue.dart` | 不可变 `MusicQueue` + `QueueEntry` / `QueueAdvance` / `QueueAdvanceReason` / `QueueFailure` | "下一首是谁"在四个屏(队列页、播放器、通知、遥控器)都要同一个答案,而且必须是**提议/提交**两步 |
| `domain/music_source_bridge.dart` | `MusicSourceBridge` 端口 + `MusicSourceQualities` + `MusicSourceFailure` | 依赖规则 §3 明写 feature 不得直接 import providers;本包此前就 import 了 `providers/music` 的一个类 |
| `data/lx_music_repository.dart` | `LxMusicRepository` + 三个 metadata 常量 | `lxSource` / `quality` 的元数据约定只能有一处读它 |

## 依赖

允许:`ecosystem/platform` + `foundation/utils`。禁止:`providers/*` 直接依赖(改为实现 `MusicSourceBridge` 的**组合根**注入)、同层 feature、App 反向依赖。

`MusicSourceBridge` 是本包的**选择**(可逆):把 lx 主机的四个问题声明成端口,由装载脚本的那个 App 写适配器。
将来若判定这套形状该共享,端口原样搬到 `ecosystem` 即可,本包不用改。

## 行为契约

### 队列
- 删除**光标之前**的条目会把光标左移 —— 旧实现在列表左移时不动光标,**静默跳过一首**。
- 到末尾且 `endMode == stop` 给 `atEnd`(队列非空,只是放完了),不再谎报 `queueEmpty`。
- `peekNext()` 只提议;`commit(advance)` 校验那首歌**仍在**那个下标上,否则抛 `QueueFailure`
  (旧实现接受一个已过期的 step,把光标挪到"现在坐在那儿的别的歌")。
- `repeatOne` 与 `endMode` 正交;`atEnd` 与 `queueEmpty` 都不可 commit。
- 下标越界(空、负、超界)一律 `QueueFailure`,不再静默返回 false / 无操作。
- `entries` 不可变;`cleared()` 保留模式设置。

### 解析
- `lxSource` 缺失 → `MusicSourceFailure`(消息里带 `sourceId/contentId`,方便查是谁造的 ref)。
  "这源没歌词"与"这个 ref 根本不能播"是两种答案:前者 null,后者抛。
- 空 url 是失败而不是可播结果。
- `availableSources()` 在脚本宣布前返回 **null**(载入中与空列表是两回事);`servesMusicUrl == false` 的源被过滤掉。

## 平台矩阵

纯 Dart 模型;桥接实现由 App 提供(lx 脚本跑在 `integrations/js_runtime` 里)。

## 未验证

- **没有 App 消费者**,且 `pure_music` 应用壳还不存在(`apps/` 目前只有 `pure_live`)。
- 因此 **`MusicSourceBridge` 到现在还没有任何实现** —— 适配器要在 pure_music 建起来时写,
  届时才能确认端口形状够用。
- 队列没有 shuffle(契约里只有顺序/循环的语义,不发明);随机播放的模式位要等产品定规则。
