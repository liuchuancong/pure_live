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

- **绕回**:第一个往上按到最后一个,最后一个往下按到第一个。
- **换组不跳台**:`withGroup(g)` 若当前台还在新范围内就原地不动;清空过滤也不动。
  (旧实现在设过滤时把光标推到新范围第一个台 —— 遥控器上"换个组看看"会变成"换台"。)
- **不可开条目**:遍历时默认跳过 `!isPlayable`;`select(number)` 仍能选中它们(按下数字是明确意图)。
  整组都不可开 → `ZapEmpty` 说明原因,而不是绕着黑屏打转。
- **数字选台**按可见范围 1 基计数;越界或空范围 → `LineupFailure`。
- `channels` 与 `visible()` 都返回不可变列表 —— 旧实现里 `visible()` 直接给内部 list,调用方能改正在看的 lineup。
- `toString()` **不含 header 值**(IPTV 流头常带 cookie,platform-models §16);`headerNames` 只给名字。
- EPG:`minutesRemaining` **向上取整**(剩 10 秒不该显示 0 分钟),已过结束时间给 0,没有结束时间给 null;
  `isOverlappingGuide` / `hasGapBeforeNext` 把节目单自相矛盾暴露给屏幕自己决定怎么画。

## 依赖

允许:`foundation/utils`。禁止:`platform` 之外的反向依赖、providers 直连、同层 feature、App 依赖。
(本包刻意不依赖 `pure_live_platform`:换台与节目单窗口是纯索引/时间算术,和平台模型无关 —— 少一条边就少一处耦合。)

## 平台矩阵

纯 Dart,无 io;Android / Android TV / Windows / iOS / web 一致。

## 未验证

- **没有 App 消费者**(拆壳波未完成);24 个测试是唯一门,且**没有一条真 m3u/真 EPG 数据**跑过 ——
  解析侧的怪形状(重复台名、跨组同名、时间戳不带时区)只能等真数据来打。
- **自代且可逆的决定**:遍历时跳过不可开条目。若产品要"能停在一个灰掉的台",把 `skipUnplayable` 设 false
  即可,契约其余部分不变。
- 同名录像由 `ZapChannel` 的 `(name, group, urls)` 相等性区分;`selectChannel` 用 `indexOf`,同名同组同 url 会落到第一条。
