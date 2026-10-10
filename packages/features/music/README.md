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
- **一切编辑都以"歌"为单位而不是以下标**:`insertAt` 在光标及其之前插入会把光标右移,`move(from,to)` 让正在播的
  歌跟着自己走,`withEntries` 换整张表时把光标重新落到同一首歌上 —— 找不到就给 `-1`,**不停到第 0 行**。
  音乐界面在播放中改列表是常态(拖拽、插入下一首、从歌单整张替换),按索引保位置就是"屏幕上高亮的行和声音不是
  同一首"。
- `peekNext()` 只提议;`commit(advance)` 校验那首歌**仍在**那个下标上,否则抛 `QueueFailure`
  (旧实现接受一个已过期的 step,把光标挪到"现在坐在那儿的别的歌")。
- `repeatOne` 与 `endMode` 正交;`atEnd` / `atStart` / `queueEmpty` 都不可 commit
  (`atEnd`/`atStart` 带 current 只是为了让界面知道"卡在哪",提交它等于把当前这首再开一遍)。
- **用户按"下一首"不等于一首歌自然放完**:`nextFor(skip: true)` 在 `repeatOne` 下仍然前进。旧模型只有一个
  `peekNext`,于是开了单曲循环就跳不出第一首。
- `peekPrevious()` 是反向的那一条:光标 > 0 走上一行,在首行且 `repeatAll` 才绕到末行,否则 `atStart`。
- `upcoming({limit})` 给"接下来播"的窗口:光标之后的行,只在 `repeatAll` 下回绕,且**长度不超过队列歌曲数**
  (两首的队列不该画出十行)。它是列表窗口,不是 repeat-one 下的预测 —— 那一格问 `peekNext`。
- `indexOfSong` / `containsSong` / `countOfSong` 按 `(sourceId, contentId)` 认歌(显示卡不参与),
  `countOfSong` 就是"从两个歌单撞进同一首"时界面该显示的数字。
- 下标越界(空、负、超界)一律 `QueueFailure`,不再静默返回 false / 无操作。
- 构造时**复制传入的 entries**(因此不再是 `const`):`entries` getter 早就不可变,但内部字段还指着调用方那个
  可 grow 的 list,外面 `removeAt` 一样能换掉正在播的歌。
- `entries` 不可变;`cleared()` 保留模式设置。

### 解析
- `lxSource` 缺失 → `MusicSourceFailure`(消息里带 `sourceId/contentId`,方便查是谁造的 ref)。
  "这源没歌词"与"这个 ref 根本不能播"是两种答案:前者 null,后者抛。
- 空 url 是失败,`'null'` / 一段没有 scheme 或 host 的字符串也是失败(消息带上源、歌与质量)。lx 处理器在查不到
  歌时就是回一个字面 `null` 字符串,而播放器把它当 url 收下就变成**没有错误的静音**。
- **`cover` 的不可用值是 null,不是失败**:封面不是可播放音频,有占位图比"这首歌开不了"更接近正确答案。
- `defaultQuality` 由宿主声明(源只出 320k 时不该每次落到 `128k`),ref 里没写才用它。
- 脚本宣布过的源 + 质量对不上时**先拒绝再问**:错误里列出该源真正回答的质量标签,`bridge.calls` 保持空 —— 一次
  注定失败的脚本调用不必发出去。未宣布的源不算证据,放行。
- 脚本抛出的**异类异常**统一包成 `MusicSourceFailure` 并保留 `cause`(调用方没法知道某个脚本运行时选了哪种
  异常);`MusicSourceFailure` 自身原样上抛。
- 空白歌词与空白封面都是 null( trim 后为空就不算有)。
- `availableSources()` 在脚本宣布前返回 **null**(载入中与空列表是两回事);`servesMusicUrl == false` 的源被过滤掉;
  `qualitiesFor` / `servesQuality` 是同一份宣布数据的两个读法。

## 验证

- `dart analyze` → No issues found;`dart test` → **37 passed**(`music_queue_test` 24 条 +
  `lx_music_repository_test` 13 条)。
- 新增的 15 条钉住:插入/拖拽/整表替换后的光标归属、`nextFor(skip)` 在 repeat-one 下的两条路径、`peekPrevious`
  的三种收口、`upcoming` 的窗口与回绕、外部 list 改不动队列、`'null'` 串 url、未宣布质量先拒绝且不发消息、
  宿主异常带 `cause` 上抛、封面退化 null、`defaultQuality` 生效。

## 平台矩阵

纯 Dart 模型;桥接实现由 App 提供(lx 脚本跑在 `integrations/js_runtime` 里)。

## 未验证

- **没有 App 消费者**,且 `pure_music` 应用壳还不存在(`apps/` 目前只有 `pure_live`)。
- 因此 **`MusicSourceBridge` 到现在还没有任何实现** —— 适配器要在 pure_music 建起来时写,
  届时才能确认端口形状够用。
- 队列没有 shuffle(契约里只有顺序/循环的语义,不发明);随机播放的模式位要等产品定规则。
