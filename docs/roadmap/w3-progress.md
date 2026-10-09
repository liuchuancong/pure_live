# W3 进度(媒体管线接线)

> 验收口径来自 [milestones.md](milestones.md) 的 M2 另一半:媒体管线能播一个假源。
> 波次范围来自 [v2-roadmap.md](v2-roadmap.md) W3:MediaTicket / MediaPlan / PlayerKernel 接线 / Recovery / Watchdog。
> 动手前置:按 [../contracts/platform-models.md](../contracts/platform-models.md) §2 先做 media_core 复用盘点 —— 本文 §1 就是那份盘点。
> 工程规范按 [../DEVELOPMENT_STANDARDS.md](../DEVELOPMENT_STANDARDS.md)。

## 1. media_core 复用盘点(实测,不是照抄 §2)

盘点对象:pub git 缓存里应用钉住的那个 ref
(`apps/pure_live/pubspec.yaml` 钉 `5b047145422758d983a3724e689d8aa4b7d06863`,即
`Pub/Cache/git/media_core-5b04714…/packages/media_core/lib`)。共 26 个 `media_core*` 包,内核包有 30 个能力目录。

### 1.1 §2 表格逐条核对

| §2 的说法 | 实测 | 结论 |
|---|---|---|
| `lib/source/media_track.dart` 已有 MediaTrack | ✅ `source/media_track.dart:39 final class MediaTrack extends Equatable` | 按 ADR 0016 镜像 + 接线层映射(内核包依赖 Flutter,平台包必须纯 Dart) |
| `lib/task/` 已有 TaskCancelToken / TaskId | ✅ `task/task_cancel_token.dart:31`、`task/task_id.dart:9`(且整个 `task/` 还有 `TaskManager`、`TaskScheduler`、`TaskQueue`、`TaskState`、`TaskPriority`、`TaskContext`) | 见 §1.3:不是"直接复用",而是**镜像 + 映射**,且两侧词汇表并不一一对应 |
| kernel/session/playback 的 PlayerHandle、PlayerSession、SessionManager、PlaybackCommand、PlaybackPosition、Rate 已有 | ✅ `kernel/player_handle.dart`、`session/{player_session,session_manager}.dart`、`playback/{playback_command,playback_position,playback_rate}.dart` | 平台**不定义**这些;平台只到 MediaTicket 为止(models §2 正确) |
| `lib/{source,planning}/` 的 MediaSource / MediaSourcePlan / MediaSourcePlanner / ProgressiveMediaSource | ✅ `source/media_source.dart:55 sealed class MediaSource`、`planning/media_source_plan.dart:30 sealed`(Direct / Composite / Unsupported 三种 plan)、`planning/{media_source_planner,default_media_source_planner}.dart`、`source/progressive_media_source.dart` | 平台不重定义;`MediaTicket → MediaSource` 的转换是 W3 的核心工作 |
| `lib/error/` 的 PlayerErrorCode / PlayerErrorCategory / ErrorPolicy | ✅ `error/{player_error_code,player_error_category,error_policy,error_classifier}.dart` | 平台 `PlatformErrorInfo` 通过 `media.player.*` 命名空间与之互译 |
| `lib/source/source_descriptor.dart` 同名但语义不同 | ✅ 存在(媒体源描述) | 与 §2 的警告一致:两侧同名,别名在 `pure_live_media` 处理 |
| `lib/identity/` 的 GenerationId / OperationId / RequestId / SessionId / SlotId | ✅ 全在,另有 `player_id.dart`、`source_id.dart` | 关键差异:**这些是值对象**(`final class SourceId extends Equatable implements Comparable<SourceId>`),不是 String;而平台侧是 `typedef SourceId = String`。命名空间分离因此不只是文档约定,映射时必然要做 String ↔ 值对象转换 |

### 1.2 盘点发现的自身缺陷(已修)

`MediaTrack.kind`:ADR 0016 声称字段级镜像,但平台侧把 `kind` 写成了 `MediaKind`(live/vod/music/file),
而 media_core 用的是 `MediaTrackType{video, audio, subtitle}`
(`source/media_track_type.dart:24`)。语义也不同层:`MediaKind` 说"这段资源整体是什么",
`MediaTrackType` 说"这一条流是哪种 essence"。按原样接线,DASH 的音频 essence 会被标成 `vod`。

已改:平台新增 `MediaTrackType{video, audio, subtitle}` 并把 `MediaTrack.kind` 换成它,`MediaTicket.kind`
保持 `MediaKind`;测试补了 essence 往返与未知值回退两条(platform 82 全绿)。
ADR 0016 的"字段级镜像"表述随之更正。

另一处已在代码注释里说明、无需改:`headers` 在 media_core 是值对象 `SourceHeaders`
(`source/source_headers.dart:8`,内部不可变 map,给 `toMap()`),平台镜像用 `Map<String, String>` ——
映射即构造时包一层,不改模型。

### 1.3 W3 范围的削减结论(最重要的一条)

文档把 W3 写成"MediaTicket / MediaPlan / PlayerKernel 接线 / **Recovery** / **Watchdog**",但 media_core
里这些**已经存在且成体系**:

```text
recovery/    RecoveryReason(union:Network/Timeout/Decoder/Renderer/Source/Resource/Initialization/
             Interrupted/Unknown,带字符串线索分类)+ RecoveryLadder / RecoveryStep / RecoverySession /
             RecoveryAction / RecoveryCandidateProvider / RecoverySnapshot / RecoveryState
fallback/    LineFallback / QualityFallback / BackendFallback + FallbackManager / FallbackContext
policy/      RecoveryPolicy / PlaybackPolicy / FallbackPolicy / PreloadPolicy / ResourcePolicy …
runtime/     PlayerRuntime + PlayerPlaybackBinding / PlayerGeometryBinding
reconciler/  PlayerReconciler / ReconcileScheduler / ReconcilePlan …
task/        TaskManager / TaskScheduler / TaskQueue(自带优先级与状态)
preload/     PreloadManager / PreloadScheduler(到期预取可复用)
kernel/      player_handle_recovery.dart(内核侧恢复入口)
```

因此 W3 **不再造第二套恢复/回退/看门狗**。平台的贡献只有内核不知道的那些信息来源:票据到期、权限被拒、
解析器失败、来源优先级 —— 把它们映射成 media_core 的 `RecoveryReason` / `FallbackReason`,并把
`MediaTicketPolicy`(allowRefresh / allowRetry / allowLineFallback / allowEngineFallback / seamlessRefresh /
retryDelay)翻译成 media_core 的策略对象。这条结论单独记 ADR(0020),因为它改变了 W3 的交付内容。

### 1.4 任务词汇表不对应(映射表,别当 1:1)

| 平台(`pure_live_task` / models §13) | media_core `task/` | 映射 |
|---|---|---|
| `TaskPriority{critical, high, normal, low, background}` | `TaskPriority` 值对象:`lowest(-100) / low(-10) / normal(0) / high(10) / highest(100)` + `custom(int)` | critical→highest,high→high,normal→normal,low→low,background→lowest;**没有 critical 的同号位,也没有第五档以下的区分** |
| `TaskState{pending, running, paused, completed, failed, cancelled}` | `TaskState{created, queued, running, completed, failed, cancelled}` | 平台 `pending` ← media_core `created`+`queued` 两者合一;**`paused` 在 media_core 无对应**,故暂停只在平台调度器一侧成立,内核态任务无法暂停 |
| `CancellationToken`(平台侧) | `TaskCancelToken` + `TaskCancelledException` | 纯 Dart 侧必须自有类型(media_core 依赖 Flutter),按 ADR 0016 的镜像+映射处理;"取消不是失败"(models §20 不变量 9)两侧一致 |
| `TaskId = String`(typedef) | `final class TaskId extends Equatable implements Comparable<TaskId>` | 跨层必做 String ↔ 值对象转换;命名空间按 contracts §3 分开(`media_core.player.*` / `purelive.*`) |

## 2. W3 要写的东西

盘点结论落定后的顺序(第 1—4 条已完成):

0. 播放诊断:`docs/diagnostics/playback-diagnostics.md` 的轨迹与导出报告已落(§2.5);**"设置 → 诊断 → 导出"
   的 UI 与文件落盘还没有**,那是 feature 层的活。
1. ~~`pure_live_media`:`MediaTicket → MediaSource` 映射~~ —— 已落(§2.1)。
2. ~~假引擎跑通"播一个假源"~~ —— 已落(§2.2),M2 的另一半在**接线层面**达成。
3. ~~票据到期与预取调度(平台侧看门狗)~~ —— 已落(§2.3)。
4. 引擎适配(media_kit / ijk / better_player)与真实设备播放:前两条证明的是接线到得了引擎,不代表任何
   真机在播。
4. ~~`MediaTicketRefreshInfo`(`refreshBefore`,models §11)~~ —— 已落(§2.4),预取提前量改为"逐票建议优先、
   全局默认兜底"。
5. Watchdog 的其余三项监控(帧心跳、适配器错误、缓冲率细节)**不做**:内核已经在报,重复判定就是 ADR 0020
   反对的多方救火。触发后的"降画质建议 / 追帧"两个动作也没有实现,它们需要 UI 与直播时钟源,随各波落地。

### 2.1 已完成:`pure_live_media` 的票据映射(15 测试)

包从纯 Dart 骨架重脚手架为 Flutter 包(`tool/scaffold_package.ps1 -Flutter -Force`,原因:mapping 的一侧是
media_core,而它 `dependencies: flutter: sdk: flutter`),依赖 = `media_core`(git,与应用同一 ref)+
`pure_live_platform` + `flutter_test`。护栏允许 integrations → 模型伞包(ADR 0018 的共享模型规则只排除
foundation 层)。

落地的三个映射(字段级、无反射,任何一侧加字段这里就编译不过或测试就红):

- `media_track_mapping.dart`:平台 `MediaTrack` ↔ 内核 `MediaTrack`,含 `MediaTrackType` 逐值互转;
  **空 header map 映射为 null**(内核里"没写"= 继承源级头,"空"= 明确不发头)。
- `ticket_source.dart`:`MediaTicket` → `MediaSource`。无 tracks → `ProgressiveMediaSource(url)`,essence 由
  `MediaKind` 推(`music → audio`);单条 track → progressive;多条 → `CompositeMediaSource` 按 essence 分组并
  **保持原顺序**(平台顺序即内核候选优先级);只有字幕的多条退回 ticket 自身 url,因为
  `CompositeMediaSource` 断言至少一条 video/audio。`live` 取 `kind == live || metadata.isLive`。
- `ticket_policy.dart`:`MediaTicketPolicy` → `RecoveryPolicy` / `FallbackPolicy`。只映射票据真有的意图:
  `allowRetry → enabled`、`retryDelay → retryDelay`、`allowRefresh → allowSourceFallback`、
  `allowEngineFallback → allowBackendFallback`、`allowLineFallback → allowLineFallback`;
  重试次数与退避沿用内核默认(票据不带这两个字段);`downgradeQualityOnFailure` 显式为 false,因为 PureLive
  的画质变更是"带另一个 SelectionRef 重新 resolve",不是播放中降级;`allowRedirect` / `seamlessRefresh`
  在内核无对应,留在平台侧。

规则表与边界写在包 README。

### 2.2 已完成:假引擎端到端播放(5 测试,`test/fake_engine_playback_test.dart`)

先按 §2 的要求查了 media_core 有没有现成假引擎 —— **有**:`package:media_core/testing/library.dart` 是它自己
公开的测试替身库(`FakePlayerAdapter` / `FakePlayerAdapterFactory` / `TestScenarios` / `TestSessionFactory` /
`FakeClock` …),因此本波不自建假引擎,只写一个把 adapter 收集起来的 `PlayerAdapterFactory`。

跑通的路径是真实内核,不是替身调用链:

```text
platform.MediaTicket → toCoreSource() → PlayerKernel.registerBackend(fake)
→ kernel.createFromMedia() → DefaultMediaSourcePlanner.plan() → PlayerHandle
→ initialize() → open(PlayerSource) → play() → stop()
```

被断言的事实:

- 引擎收到的 `PlayerSource.uri` **就是**票据里那个 url(映射没有重新推导、没有丢 scheme);
- VOD / live 两种票据都能落到 open;
- 多条 essence 的票据在内核里仍是 `CompositeMediaSource`,配 `CompositeSupport.native` 时走 composite plan;
- **能力不合的引擎在起播之前就被拒**:换成只声明单 url 能力的 backend(`compositeSupport` 默认 none),
  planner 出 `UnsupportedPlan`,`createFromMedia` 抛 `UnsupportedError`,并且**一个 adapter 都没被创建** ——
  这正是 ADR 0020 "判断归内核"的实际形状,平台侧不提前替内核决定;
- `initialize → open → play → stop` 的调用次序由 adapter 自己记录的调用序列证明。

边界(必须与成就分开写):这一条证明的是**接线能到引擎**,不是任何真机在播。media_kit / ijk / better_player
适配与设备验收还没有。

### 2.3 已完成:平台侧看门狗(现 19 测试,`lib/src/watchdog.dart`)

`docs/media/watchdog.md` 的五项监控里,只有两项是平台能观察的,盘点也证实内核把这两项留给宿主:
`kernel/player_handle_recovery.dart:176` 明写"之后再停的时钟是 position-stall watchdog 的活",而票据 TTL 根本
不进内核(内核只拿到 url)。因此这里只做:**票据过期 / 到期预取 / 位置停滞 / 起播超时**,
`reportStall` 与 `reportStartTimeout` 通过 `PlayerHandle.reportFailure` 交给内核阶梯
(`RecoveryFailureSource.watchdog`),看门狗自己不执行任何恢复(§2 规则:只发起)。

架构上一处被源码事实推翻的设计:原打算让看门狗直接持有 `PlayerHandle`,但 `PlayerHandle` 是 final class,
外部无法 implement,测试也就无法替身 —— 改成注入 `reportFailure` 回调。这不是妥协:持有 handle 的一方本来
就该决定故障往哪儿报。

判定里"不做"的部分与被断言的部分同样重要,测试逐条钉住:`paused` / `idle` 冻结不报(那是用户意图)、
无 `expiresAt` 不预取(静态流永不过期)、`allowRefresh == false` 不预取(源禁止换链)、过期优先于停滞、
一次只允许一个换链在飞。真实链路那条测试断言的是
`handle.recoveryFailure.source == RecoveryFailureSource.watchdog`,即"报到了阶梯里",而不是"回调被调了"。

### 2.4 已完成:票据刷新信息与逐票预取提前量

models §11 的 `MediaTicketRefreshInfo{supported, expiresAt, refreshBefore}` 补上,挂在 `MediaTicket.refresh`
(可空:null = 源没说过,不等于"不可能换")。这同时补掉了 §2 原来那条"预取提前量没有逐票落点"的欠账。

两个模型的分工写进了注释,因为它们很容易被合成一个:`MediaTicketPolicy` 是**平台被允许做什么**,
`MediaTicketRefreshInfo` 是**源自己能给什么**。`policy.allowRefresh == true` 而 `refresh.supported == false`
是真实存在的组合(一次性签名 url),此时**源的限制优先**:换链注定失败,而在直播上那一次失败的代价是观众看得见
的卡顿。

预取时刻 = `expiresAt - (refresh.refreshBefore ?? thresholds.prefetchLead)`;建议值为 0 或负数按"到期即换"
处理(那不是"不必调度")。`nextRefreshAt` 里 `ticket.expiresAt` 优先于建议自带的 `expiresAt`,因为 §11 说前者
才是权威期限。

### 2.5 已完成:播放诊断轨迹与导出报告(12 测试,`lib/src/playback_trace.dart`)

`docs/diagnostics/playback-diagnostics.md` 的目标是把"复现不了"变成"能导出证据链",所以这里落的是**记录 +
脱敏导出**:`PlaybackTrace` 存阶段/票据/网络摘要/末端故障,`report()` 出可直接外发的 map。

脱敏不做成调用方的责任(文档写的是"报告不含凭据与个人数据(脱敏强制)"):票据只留 host,query 全删,
自由文本过 `redactText`,environment 的字符串值同样过。测试里有一条专门盯
`Authorization: Bearer <token>` —— 值类若停在第一个空格,secret 就从第二个词漏出去了,这条是**测出来的**不是想到的。

`classifyFault()` 按文档的反馈闭环把故障归给能修它的一方(源插件 / network / media),而不是统一句"播放失败";
带命名空间的插件自定义码(`tvbox.*`)靠 `category` 落归属,不硬猜 unknown 之外的类别。

## 3. 验证证据

| 命令 | 结果 |
|---|---|
| `packages/integrations/media` → `flutter analyze` | No issues found |
| `packages/integrations/media` → `flutter test` | **51 全绿** = 15 票据映射 + 5 假引擎端到端播放 + 19 看门狗 + 12 播放诊断轨迹;跑在真实 `flutter test` 上、对钉住的 media_core ref(不是对桩) |
| `packages/ecosystem/platform` → `dart test -j 1` | **89 全绿**(+7 条 `MediaTicketRefreshInfo` 调度与往返) |
| 假引擎播放的路径 | `PlayerKernel.createFromMedia` 走内核自己的 planner(`DefaultMediaSourcePlanner`)与 `PlayerHandle.initialize/open/play/stop`;`FakePlayerAdapter` 来自 media_core 自带的 `testing/library.dart` |
| 看门狗 → 阶梯的证据 | 断言 `handle.recoveryFailure.source == RecoveryFailureSource.watchdog`(真实 handle,不是替身回调) |
| 环境 | `flutter test` 每次会触发一次 pub 解析;本网络下只有先 `flutter pub get --offline` 才不报 `Connection terminated during handshake`。已把这条顺序固定下来 |
| `flutter pub get --offline`(仓库根) | Got dependencies;media_core 复用应用同一 git checkout,未新增解析 |
| `dart analyze packages` / `dart analyze .` | No issues found |
| `dart run tool/check_architecture.dart --strict` | `packages=25 errors=0 warnings=0` |
| `dart format --output=none --set-exit-if-changed packages tool/check_*.dart` | 127 文件 0 changed |

事故记录:`dart format ../../..` 误从包目录指到仓库根,把 `third_party/built_in_kotlin/**`(53 个 vendored
文件)与 `apps/pure_live` 的 3 个生成文件、`tool/probes/**` 3 个 v1 探针一并重格式化。已用 `git checkout --`
全部还原,工作树只剩本包改动。**教训:格式化命令的路径必须写死为 `packages` + 明确的工具脚本,不用相对上溯。**

## 4. 已知欠账

- docs/media/{watchdog,recovery,line-switch,media-plan,media-architecture}.md 与 §1.3 的结论冲突,需按 ADR 0020
  修订;不能让文档继续指向一套不该存在的实现。
- 播放只在**假引擎**上打通:没有真实引擎适配(media_kit / ijk / better_player),没有真机验收,也没有画面/音频
  输出证据。M2 的"能播一个假源"达成,"能播"这件事本身还没达成。
- 换链的**执行端**还没有:`onTicketRefresh` 回调由谁去重新 resolve、拿到新票据后怎么 `handle.open` 上去
  (且要保住会话与进度,docs/media/media-ticket.md §4),要等 resolver(W4 之前)与播放会话归属定下来。目前
  看门狗只会"提出要换",不会真的换。
- 内核阶梯被**触发过**一次(测试里 `reportFailure` 进到 `handle.recoveryFailure`),但没有走完一轮恢复:
  没有候选线路、没有 `RecoveryLadderEvent` 断言。真实恢复路径的验证随引擎适配一起做。
- `MediaTicketRefreshInfo` 目前只有模型与读法,**没有任何 resolver 会填它**:字段是先给 W4/W7 用的,不是
  "已生效"。

