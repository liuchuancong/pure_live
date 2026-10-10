# pure_live_iptv_feature

> 职责:导入播放列表(m3u 之类)之后的**换台遍历**与 **EPG 窗口**。纯模型,不碰网络、不碰播放器。
> 列表解析在 `providers/iptv`,播放与票据在 `integrations/media` / `ecosystem`。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `domain/zap_channel.dart` | `ZapChannel`(`isPlayable` / `primaryUrl?` / `headerNames`) | 用户导入的列表里"有名字没流"的条目是常态,能不能开必须是数据说得出的一句话 |
| `domain/channel_zapper.dart` | 不可变 `ChannelZapper` + `ZapStep`(`ZapMoved` / `ZapEmpty`)+ `LineupFailure` | 遥控器每秒可能按好几次,顺序、绕回、换组不跳台这三条得只有一个答案 |
| `domain/epg_window.dart` | `EpgWindow` / `EpgProgramme` / `windowFrom` | 节目单是别人写的、会迟到、会有重叠与空洞;模型要能"报告不一致"而不是抹平 |

## 行为契约

- **位置是内部货币**。范围用 `_channels` 的下标表表示,`select(n)` / `atIndex(i)` / `visibleNumber` 都按下标走。
  真实列表会把同一个台**整行重复**(同一 station 的第二条 CDN 就是这么列的),按值匹配会让两行都落到第一份,
  于是第二行永远选不到、显示的行号也是假的。`selectChannel(channel)` 仍按值,落第一份并在 doc 上写清了要按行就用
  `select` / `atIndex`,`positionsOf` 告诉你有几份。
- `ZapMoved` 带 `zapper`(移动后的 lineup)。以前它只带 channel,调用方只能再 `selectChannel(step.channel)`
  补一次位置 —— 在有重复行的列表上那一步会把人放到**另一份**上,按键落点不等于用户瞄准的行。
- 构造时**复制传入的 list**。旧写法 `channels` getter 返回 unmodifiable 视图,内部字段却还是调用方那个可 grow
  的 list,对方 `add`/`removeAt` 照样能改掉正在看的 lineup(测试 `callerListMutationCannotReorderTheLineup` 钉住)。
- **绕回**:第一个往上按到最后一个,最后一个往下按到第一个。方向是**列表顺序**而不是台号,绑定安卓 TV 的
  CH+/CH-(台号升降)时要么调 `zapDown` 当 CH+,要么在 surface 层显式取反 —— 这条写在方法注释里,因为它不能从
  名字读出来。
- **换组不跳台**:`withGroup(g)` 若当前台还在新范围内就原地不动;清空过滤也不动。
  `withSkipUnplayable(bool)` 同理(设置页开关灰掉行的那条路径),值没变时返回同一实例。
  (旧实现在设过滤时把光标推到新范围第一个台 —— 遥控器上"换个组看看"会变成"换台"。)
- **不可开条目**:遍历时默认跳过 `!isPlayable`;`select(number)` 仍能选中它们(按下数字是明确意图)。
  整组都不可开 → `ZapEmpty` 说明原因,而不是绕着黑屏打转。
- **数字选台**按可见范围 1 基计数;越界、空范围、`atIndex` 指到过滤外的行 → `LineupFailure`。
- `channels` 与 `visible` 都是不可变列表,`visible` 是 getter(旧版是每次重新过滤分配的方法,万次列表 + 按键连发
  下每次按都重算一边)。
- `toString()` **不含 header 值**(IPTV 流头常带 cookie,platform-models §16);`headerNames` 只给名字。
- EPG:`minutesRemaining` **向上取整**(剩 10 秒不该显示 0 分钟,与 `secondsRemaining` 共用一条算术),已过结束
  时间给 0,没有结束时间给 null;`nowDuration` 对"结束早于开始"的行给 null 而不是负时长。
- EPG 构建:`windowFrom` **自己按开始时间排序**,不要求调用方有序;"now" 必须是**已经开始**的行 —— 旧写法取
  "第一个还没结束的",在有空洞的单子里选中一个还没开播的节目,屏幕上就开始倒数一个没上画的东西。
  多行同时覆盖时取**开始最晚**的那条(垫档压在正片下面时,在播的是正片)。
- EPG 不一致要能**被产出**:`next` 从"当前行开始之后"往后找,而不是"当前行结束之后" —— 后者会把提前开始的邻节目
  直接跳过,`isOverlappingGuide` 于是只能由手写窗口触发,一个没人能置真的报告标志等于装饰。
  空洞(`nothing airs at …`)、跑完(`every guide entry had already ended`)、结束早于开始的行都走
  `onInconsistentData`;空洞返回的是**只有 next 的窗口**,不是 `unknown`,这样屏幕能把"这单子这里缺一段"和
  "这频道没节目单"画成两件事。

## 依赖

允许:`foundation/utils`。禁止:`platform` 之外的反向依赖、providers 直连、同层 feature、App 依赖。
(本包刻意不依赖 `pure_live_platform`:换台与节目单窗口是纯索引/时间算术,和平台模型无关 —— 少一条边就少一处耦合。)

## 平台矩阵

纯 Dart,无 io;Android / Android TV / Windows / iOS / web 一致。

## 验证

- `dart analyze` → No issues found;`dart test` → **35 passed**(`channel_zapper_test` 19 条 +
  `epg_window_test` 16 条)。
- 本轮新增的 9 条就是新行为的门:重复行可按位置选中、`ZapMoved` 带出移动后的 lineup、外部 list 改动不影响
  lineup、`withSkipUnplayable` 不跳台且同值返回同实例、`atIndex` 拒绝过滤外位置、EPG 空洞不当作在播、
  重叠邻节目能置真 `isOverlappingGuide`、乱序单子结果一致、结束早于开始的行被报告并跳过。

## 未验证

- **没有 App 消费者**(拆壳波未完成);上面 35 条测试是唯一门,且**没有一条真 m3u / 真 EPG 数据**跑过 ——
  解析侧的怪形状(跨组同名、时间戳不带时区、`tvg-id=` 没被消费)只能等真数据来打;换台与窗口本身也不接播放器。
- **自代且可逆的决定**:遍历时跳过不可开条目。若产品要"能停在一个灰掉的台",把 `skipUnplayable` 设 false
  即可,契约其余部分不变。
- 相等性仍是 `(name, group, urls)`(`ZapChannel`),所以 `selectChannel` 按值只到第一份 —— 这是保留行为,
  行级访问请走 `select` / `atIndex`;两种写法并存是有意的,不是没做完。
- CH+/CH- 与列表方向的绑定没有在 surface 侧验证(还没有 surface),README 里那条"方向是列表顺序不是台号"
  是当前唯二的提醒载体之一(另一处是方法注释)。

