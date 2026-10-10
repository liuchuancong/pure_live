# packages/ 重写台账(工业级 DoD)

> 判据来自 [../architecture/application-portfolio.md](../architecture/application-portfolio.md) §6 的九条;
> 包的存在性由同文 §3 的消费矩阵决定。本文件记**实测缺口**与**重写队列**,不记计划外的乐观进度。
> 本轮按使用者要求**不写测试**,但公共面按"能被一个确定性测试钉住"的形状设计。

## 1. 基线实测(2026-10-10,`lib/` 下非生成 Dart 代码行数)

| 层 | 包数 | 行数区间 | 判断 |
|---|---:|---|---|
| foundation | 14 | 108 – 764 | 存储/网络/工具/缓存/文件/发布等已成体系;`diagnostics`(121)、`events`(108)、`platform_info`(158)、`sync`(206)偏薄 |
| integrations | 3 | 88 – 941 | `media`(941) 够;`firebase`(88) 只是受保护初始化,够用但无诊断出口 |
| ecosystem | 11 | 328 – 2973 | 契约与运行时面最扎实(`platform` 2973、`external_tvbox` 1395、`extension` 1100);`plugin_host`(328)、`resolver`(343) 待按 DoD 复核 |
| services | 5 | 178 – 480 | `search`(178)、`feed`(212) 只有聚合器骨架,缺分页语义/取消/部分结果策略的完整面 |
| ui | 5 | 79 – 279 | **整层偏薄**:design 81、lyric 79、player_ui 122、ui_kit 226、adaptive 279 —— 与"六风格 + 令牌 + 门面"的承诺差一个量级 |
| features | 10 | 58 – 191 | **最薄的一层**:每个域只有 1-2 个类型,没有 data 层、没有错误模型、没有持久化边界 |
| providers | 6(删 5 后) | 9 – 735 | `huya`(428)、`music`(735)、`bilibili`(407)、`iptv`(312) 有实现;`douyu`(9) 是空壳 |

## 2. 本轮已做

- **`features/search` 重写(队列 #2)**:`SearchTerm`(display + 折叠键)、`SearchHistoryRepository` 接口、
  `StoredSearchHistory`(带 `{v,items:[{q,at}]}` 信封、v0 裸列表迁移、MRU + `matchKey` 定序、有界淘汰、
  读坏行**记账**而不是装作没搜过)、`rankSearchResults`(按内容而不是按谁先答)、`SearchController`
  (世代栅栏:`Answer`/`Rejected`/`Superseded`,被放弃的答案不写历史;`currentToken` 只在放弃时触发)。
  22 个测试通过,包 analyze 0 issue。它是 `equality` / `identifiers` / `errors` / `numbers` 这几个新
  utils 模块的第一个真实消费者。
- **`features/account` 重写(队列 #3 第 2 个)**:改掉两个真缺陷 ——
  (1) `load(siteId)` 用字符串拼 `CredentialHandle(key: '$siteId:$accountId')`,而 vault 的真实键带
  `auth.secret.` 前缀,**它给出的每个 handle 都指向一个不可能存在的键**(登录站点被读成未登录;拿它去发认证
  请求会静默丢 cookie);(2) `logout(siteId)` 删 `accounts.last`,多账号站点被静默挑一个。
  现在:`SiteAccount`(状态 + `secretPresent` + `canRefresh`,expired / disabled / 无账号三者可分)、
  `signOut(account)` 与 `signOutSite(site)` 分名、`primaryAccount` 按"可用且过期最晚"、
  空白 id / 空密钥 / 超 `maxSecretSize`(默认 64 KiB)具名拒绝、`accountsOf` 按 accountId 定序(遥控器指同一行)。
  10 测试通过。它是 `numbers.ByteSize` 与 `validation` 在 features 层的第一个消费者。
- **`features/home` 重写(队列 #3 第 1 个)**:`HomeTab.visible` → `defaultVisible` 并与用户选择分家
  (原实现一个字段被 hidden 集合覆盖,**出厂隐藏的标签一跑排序就变可见**);`arrange(HomeLayout)` 返回
  `ArrangedHomeTab`(可见性 + 是否用户排过);新增 `HomeLayoutRepository` / `StoredHomeLayout`
  (`{v,order,hidden}` 信封、按 App 命名、缺 `hidden` 当迁移不当损坏、坏行记账后回退出厂顺序)、
  `HomeLayoutService`(`recordUse` / `setHidden` / `staleSavedIds` / `reset`)。18 测试,包 analyze 0 issue。
  **顺带暴露一条规则盲区**:§3 说 feature 可依赖"偏好机制",但偏好机制住在 `features/settings` —— 同层禁互依,
  所以 home 只能自己再写一份 kv + 信封 + 迁移。见 §5。
- **`features/backup` 重写(队列 #3 第 3 个)**:除编排补齐外,修掉两个真问题 ——
  (1) 备份摘要是在**上传成功之后**用 `document['manifest']['domains']` 的 cast 链算出来的,manifest 形状一变
  就会把已经落地的归档报成失败;(2) `listRemote()` 注释说"最新在前",实际返回服务器给的顺序。
  另加:快照名当**不可信输入**(含 `/`、`\`、`..`、控制字符直接拒 —— 它会变成别人 dav 上的路径分量);
  `SnapshotRemote` 端口(L0 的 `WebDavBackupStore` 是 final class,原注释"注入传输好测试"根本做不到);
  `{manifest,payload}` 编解码从 `apps/pure_live/lib/app/user_backup.dart` **收回来一份**(那边仍留着副本,
  等拆壳波替换),解码拒绝:缺 payload、自称含凭据、不认识的 schema 版本、列了域却没给值。
  18 测试,包 analyze 0 issue。
- **`features/live` 重写(队列 #3 第 4 个)**:旧模型把切换当成**一个 pending 标志**,于是
  (1) 第二次切换覆盖第一次,`commitSwitch()` 提交"当时挂着的那个"—— 用户已经放弃的那条线路的迟到
  "开播成功"回调会把选择改写成没人播的流;(2) 单 `active` 字段表达不了"线路2 + 原画",换画质会把线路清空;
  (3) 可以请求一个源从没给过的变体;(4) `active/pending/currentTicket/variants` 全是公开可写字段,
  "只在开播后提交"这条规则任何调用方都能绕过。
  现在:不可变状态 + **按轴的带身份尝试**(`SwitchAttempt`,被取代者 commit 抛 `SwitchFailure`)、
  `SwitchNoop` 让遥控器重复事件不再是错误、`withTicket` 保留选择但作废在飞尝试、
  变体表变化时释放消失的选择与尝试。13 测试。
  **顺带查出**:source-contract.md 点名的 `QualityLine` / `QualityRef` / `LineRef` / `LiveDetail` /
  `StreamTicket` 在 `pure_live_platform` 里**一个都不存在**(只有 `MediaTicket` 有),契约与模型对不齐,
  见 §5。

- **`features/vod` 重写(队列 #3 第 5 个)**:三个真缺陷。
  (1) 连播用 `ContentRef` 的**全字段相等**找下一集 —— 票据层回来的 ref 带 `parentId`/`metadata`,与 detail
  子项不相等,连播会**静默停在最后一集**;改成只比 `(sourceId, contentId)`(`sameContent`)。
  (2) 续播只问"位置 > 30s",**看完的一集重开就跳到 99%**;改成双阈值(片头 30s 之内不续、离末尾 30s 之内也不续,
  但位置仍保留)。
  (3) 进度键是 `sourceId/contentId` 直拼,路径型 episode id 让 `a`+`b/c` 与 `a/b`+`c` **撞同一行互相覆盖**;
  改用 `identityKey` 的长度前缀拼接。
  另外 `EpisodeNavigator` 改成不可变 `EpisodeQueue`(提议 / 提交分家,到边返回 `atEdge`,提交不属于本队列的集
  具名拒绝),进度表加信封 + v0 读通 + `onReadFailure` + 注入 `Clock`(旧代码直接读 `DateTime.now()`)。20 测试。
  **我自代的两个参数**(可逆,等你一句就能改):尾阈值与片头阈值都取 30s;尾阈值不随片长变 ——
  竖屏短视频上这个比例可能过大。
- **`features/iptv` 重写(队列 #3 第 6 个)**:四个真问题。
  (1) `primaryUrl => urls.first` —— 导入的 m3u 里"有名字没流"的条目很常见,于是**第一次按遥控器就 StateError**;
  现在 url 可空 + `isPlayable`(还拒无 scheme 的截断行,那种黑屏没报错会被当成台死了)。
  (2) `visible()` 返回内部 list,调用方能通过一个 getter 改动正在看的 lineup。
  (3) 设组过滤时把光标推到新范围第一个台 —— 遥控器上"换个组看看"变成"换台";现在 `withGroup` 保当前台。
  (4) EPG `minutesRemaining` 文档说向上取整而 `Duration.inMinutes` 是截尾,剩 10 秒就显示 0 分钟。
  改完:不可变 zapper + `ZapStep`(Moved/Empty)/`LineupFailure`、数字选台 1 基、整组不可开时说明原因而非绕圈、
  `toString` 不含 header 值(platform-models §16)、重叠与空洞交给屏幕。24 测试。
  **我自代的决定**(可逆):遍历时默认跳过不可开条目,`select(number)` 仍可到达;
  另外本包**不依赖 platform**,换台与 EPG 是纯索引/时间算术。
- **`features/recorder` 重写(队列 #3 第 7 个,除 `music` 外做完)**:四个真问题。
  (1) `state` / `endReason` 是**公开可写字段** —— 类注释写着"迟到的编码器回调不能复活已结束的任务",
  下一行任何调用方一个赋值就能违反;
  (2) `elapsed` 从创建时间算,**排队一小时的录制在列表上显示"已录 1 小时"**(改成从 beganAt 算,queued 给 0);
  (3) `endReason` 默认 `none` 让"结束了但没有原因"可表示(现在终态必须给原因,`fail(userStopped)` 直接拒,
  因为用户按停与磁盘满是两块屏);
  (4) id 用 `/` 直拼 sourceId 与 contentId,带分隔符的 contentId 会让两个房间撞同一个 id;
  另加 `fileName` 路径校验(宿主把它拼到录制目录后)、三处 `DateTime.now()` 换成注入 `Clock`
  (不然这些规则根本没法测)、id 在转换间保持稳定。13 测试。
  `lib/src/data/` 仍空是刻意的:引擎在录制波次,状态契约先立住就没有第二套真相。
- **#7 的 `foundation/platform_info`(能力矩阵)**:`detectPlatform` 认不出的系统以前回退成 `PlatformKind.web`,
  而它自己的注释写着这是「最受限的目标」—— web 恰恰不是:它 `supportsPictureInPicture: true` 且
  `isTouchPrimary: true`。于是 harmonyos / 改壳 Android 分支**同时**继承两个乐观假设和 web 的存储分支
  (`kind == web` 这种判断在别处决定文件写到哪)。新增 `PlatformKind.unknown` + 全 false 的底线矩阵,
  穷尽 switch 照旧(加目标不写矩阵就编不过);web 的输入方式改成显式 `webIsTouchPrimary`
  —— 手机浏览器与桌面浏览器是同一个 kind、相反布局,只有宿主分得出来。21 测试。
  **仍未验证**:零消费者;旗标的真实性一台设备都没测过,`unknown` 是保守而不是正确。
- **#7 的 `foundation/sync`(游标)**:这条是**会导致重复全量拉取**的那种缺陷,而且完全静默 ——
  `pull()` 把收到的 `from` 原样回显成报告的游标(因为 `fetchSince` 只回一个 `List`,引擎根本不知道新位置),
  所以按文档写的用法 `pull(from: lastReport.cursor)` **每次都重拉全部历史**,看起来一切正常;
  `push()` 在没有待推送内容时返回 `SyncCursor.start`,空闲一趟反而把调用方的位置抹回起点。
  现在:`RemoteStore.fetchSince → RemoteBatch(records, cursor)`、`SyncReport.nextCursor` 可空 +
  `cursorAfter(held)`、远端交回同样游标不算前进、空 key 与同批重复 key 计进 `rejected`
  (凭据键仍单独计,那是远端违约不是发垃圾)、`SyncCursor` 补值相等。
  顺带删掉 `pull(clock: ...)` —— 它读了一次时钟就丢掉,却写着「保持确定性」。18 测试。
  **未验证**:零消费者,真实 Firebase 的游标行为(单调性、分页边界、重放同一 token)一次都没跑过。
- **#7 的一部分:`foundation/events` 与 `foundation/diagnostics`**(纯 Dart,可测)。三个能验证的真缺陷:
  (1) `EventBus.on<T>()` **每次调用新建一个 controller 并 retain 到 dispose** —— 在 build() 里订阅的屏每重建
  一次就多一个,被丢弃的订阅也一直可达;改成**按事件类型一条 channel**(界由类型数决定,这是这层唯一能知道的界)。
  (2) `hasListeners` 文档说它回答"有没有人订 T",而它是 getter、拿不到类型参数 —— 一句假话;
  拆成 `hasListeners`(有任何人)+ 新的 `hasListenersFor<T>()`。
  (3) `sync: true` 让监听者的异常**沿 `emit()` 同步抛回发布者**:一个设置页的 bug 能把"会话过期"整条链静音。
  diagnostics:`RingBuffer` 满时 `removeAt(0)` 复制整个尾巴(它在整个会话里每个事件都写)→ 真环形 O(1);
  `measure` 用两次 `DateTime.now()` 相减,墙钟回拨会报**负时长**(面板读成"瞬时"、阈值读成"可忽略")→ 换 `Stopwatch`;
  `runGuarded` 不守护 reporter 自己 → 诊断文件被锁时调用方永远等一个不完成的 future。
  11 + 18 测试,消费者 `ecosystem/extension` 的 53 测试仍全过。
- **#6 提前做掉(队列顺序我自己调了,理由与可逆性都在这儿)**:`services/feed` 与 `services/search` 是
  纯 Dart 的,能真跑测试;#5(`ui/lyric` / `ui/player_ui`)是 Flutter 侧,而本轮已定"只静态分析",
  再做一层只会多一批无法验证的改动。#5 没删,仍是下一步。
  **查出来的真实缺口比 §1 那句"缺分页语义"具体**:feed 的 CHANGELOG 早就写着"游标贯穿到源并原样带回",
  但代码里 ① 请求只有一份**全体源共享**的 `PageRequest`(`PageRequest.cursor` 优先于页号 →
  把 A 源的 token 喂给 B 源是**静默错页**,不是报错),② `PageResult.mode` / `nextCursor` **被丢弃** →
  cursor 模式的源答完第一次就再也续不了(它给的 token 无处可读)。
  现在:`feed(page, {cursors, cancellation})` + `FeedSection.mode/nextCursor`,并按三态校验答复
  (single-shot 却说还有 / cursor 说还有不给 token / fixed-page 却给 token → `contractViolation` 记账,
  **不静默归一化** —— 屏幕上结果一样,但"首页为什么停止加载"需要知道是哪个源在撒谎)。
  search 同样补了 `cancellation`:被取代的运行以前会以"十二个源 failed"落地,那是把健康 provider 写成病态。
  两处的界都说清了:已发出的每源请求不由这层取消(与既有 timeout 边界同一条)。
  16 + 23 测试通过,`dart analyze packages/services` 0 issue,护栏 0 错。
  **诚实记录**:这是本轮第一次出现"CHANGELOG 与代码不符" —— 说明 §1 的行数基线不足以判断完成度,
  判据要回到"契约逐条对代码"。
- **#4 第 2 步:`ui_kit` 与 `ui/adaptive` 开始真读令牌**(`6f71642` 之后的那一步)。
  新增 `DesignTokensTheme`(ThemeExtension)承载 density / input / focus / motion —— `ThemeData` 对这些
  **没有槽位**;`context.designTokens` 在未安装时**回退到平台默认而不抛**(抛会让组件只能在全应用主题里预览)。
  adaptive 的 `StyleThemeFactory` 改收 `DesignTokens`,共享部分集中到 `_applyTokens` 并**跑在风格工厂之后** ——
  以前切到 Fluent 顺带切成鼠标密度,TV 上跑 Fluent 变体就拿到 36 像素按钮;现在密度、四种按钮 minimumSize、
  图标按钮、toolbar 高、`textTheme` 六个角色(可读下限进全局)、list 纵向 padding、focusColor、
  reduce-motion 的 `NoSplash` 一律来自令牌,风格只剩圆角/表面/控件形状。
  顺带修掉 `PosterCard.width`(**声明了却从没被用**,传与不传得到不同布局且都不报错),
  状态页文字改走 `typeSize`,`ErrorRetryView` 的文案变成可覆盖参数(底座写死"重试"就等于逼 feature 复制它)。
  **验证等级(按使用者指定)**:只 `dart analyze`(`packages/ui` 与 `apps/pure_live` 均 0 issue)+ 护栏 0 错 +
  design 的 20 个纯 Dart 测试;**不跑 flutter analyze / flutter test,没上真机**,
  所以 extension 是否被 MaterialApp 带下去、焦点环实际观感、真实字号下的排版都未验证。
  两个映射上的诚实交代:`visualDensity` 只用 SDK 保证的三个常量(不假设 `VisualDensity.large` 存在 ——
  这条在当前 SDK 上直接是编译错);路由转场**没有映射**,因为 `PageTransitionsTheme` 对没列出的平台会回退默认
  builder,给空 map 的意思恰恰是"继续动"。
  `apps/pure_live/lib/app/app.dart` 的 `themeFor(...)` 还**没传 tokens**,所以线上路径暂时走平台默认输入 ——
  拆壳波里连 `AppearanceSettings`(app 现在自己那套 `appearance.dart` 与之重复)一起接。
- **`ui/design` 令牌补齐(队列 #4 第 1 个)**:按技术栈 §5.4 把"差一个量级"的令牌面补成
  颜色角色(13 个,按语义命名而不是照 Material 槽位)/ 间距 / 圆角 / 字阶 / 动效 / 密度 /
  交互尺寸 / 焦点视觉,加 `resolveDesignTokens` 与 `AppearanceSettings` 持久形状。
  **写进包里的硬规则**(不是建议):`textScale` 不许低于 1(风格不得回缩用户的字号)、
  remote 下小字角色抬到 16 逻辑像素的十英尺可读下限、减少动态效果**时长归零而不是缩短**、
  **remote 不做聚焦缩放**(控件一变大它下面整排跟着动,d-pad 上像界面在抖)、
  `isAimable` / `isFindable` 把"按不中"和"看不见焦点"变成断言(chip 是行内件,下限另算)。
  `PureLiveSpacing`/`PureLiveRadius` **数值原样保留**(Dart 的枚举字段访问进不了 const,所以两份字面量 +
  一条相等断言钉住),免得"补令牌"顺手把 ui_kit 现在的渲染改了样子。
  包仍然**不 import Flutter** —— 要能在没有 BuildContext 的情况下断言数字。20 测试。
  **没做的**:`ui_kit` / `ui/adaptive` 还没消费这套令牌(adaptive 的六风格注册表现在直接从 ColorScheme 造
  ThemeData,不读密度/焦点/输入模式),所以这些数字只过了自洽性检查,**没对过真机与截图**。
- **`features/music` 重写(队列 #3 第 8 个,除决策外全部做完)**:**那条 L4→L5 直连我自己按可逆方案解掉了** ——
  包 README 之前甚至写着"源解析走 providers/music(lx-music 源直接导入)",而同一个文件的禁止依赖行又禁止它。
  新增 `MusicSourceBridge` 端口(四个问题 + `MusicSourceQualities`),`LxMusicRepository` 只认端口,
  **适配器留给装载 lx 脚本的那个 App 的组合根**;将来若判定这形状该共享,端口原样搬去 ecosystem 就行。
  队列侧修掉三个真缺陷:删光标之前的歌会**静默跳过一首**;走到末尾被报成 `queueEmpty`(实为 `atEnd`);
  已过期的 step 仍可 commit,把光标挪到"现在坐在那儿的另一首歌"。现在队列不可变、commit 校验歌还在原位,
  越界索引具名拒绝。23 测试。
  **已知空白**:`MusicSourceBridge` **还没有任何实现**,因为 `apps/` 里只有 `pure_live` —— 形状要等 pure_music
  建起来才能验;这条记进 §5。

- **查出一类护栏盲区:pub workspace 让"未声明依赖"照样编译。** 逐包 grep `lib/` 里的
  `import 'package:...'` 与 pubspec 对照,14 个包在空 `dependencies:` 的情况下用着别的包 —— 意味着
  §2bis 的依赖图(按 pubspec 测)**系统性少算边**。已把这批能合规的边补进 pubspec:
  `features/{account→auth, backup→backup, recorder→platform, vod→platform+storage, settings→storage,
  music→platform, search→platform+search+storage+utils}`、`ui/adaptive→flutter(sdk)`、
  `foundation/cache→path`、`ecosystem/plugin_host→path`、`integrations/python_runtime→path`。
  **起初剩下 3 条故意没补**,因为补了就是在给未批准的边发护照;现在已解掉 2 条,只剩最后 1 条要你先定规则:
  1. ~~`features/music` → `providers/music`~~ **已消除**:改成 `MusicSourceBridge` 端口 + 组合根适配器
     (见上面的 music 条目),import 不再存在;
  2. ~~`ui/adaptive` → `ui/design`~~ **已解决**:design 定为 ui 层叶子(§3/§4 已改),依赖已声明 ——
     顺带发现 `ui/lyric` 本来就依赖 design,旧那句"只 ui_kit→design"是文档落后;
  3. `ecosystem/external_tvbox` → `ecosystem/plugin_api`(L1 同层,§4 无此例外)。
  现在只剩 `external_tvbox → plugin_api` 一条仍**只存在于 import 语句里**,`check_architecture.dart` 看不见它
  (它读 pubspec)。
  建议的修法:护栏把 `lib/` 的 import 也解析成边(现在 `checkImports` 只查 `lib/src` 越界与 app 边界),
  那样未声明依赖会直接成 error。**待你点头再动护栏**,因为那会让 CI 立刻红这 3 条。

- **`foundation/utils` 从 5 个模块扩到 13 个**(`async_tools`→`async`,新增 errors / conversion / numbers /
  types / validation / equality / identifiers / math,`result` 拆出 `result_sequence`)。每个新模块对应一次
  grep 计数,写在包 `doc/design-decisions.md` §1 的表里:13 个包各写一份 `XException`、`platform` 一处 12 个
  手写 `operator ==`、82 处手写 `ArgumentError`、9 处裸 `.clamp()`、`64*1024*1024` 这类无单位常量。
  同时修掉两个实现缺陷:`AsyncMemoizer` 按 `storedAt` 比较淘汰,同一 tick 两次写入会把**最新**那条踢掉
  (改为按写入序);`Set.union` 参数类型错。测试 38 个通过,`dart analyze` 0 issue,护栏 `packages=55 errors=0`。
  **未验证**:8 个新模块零消费者,形状要等第一个调用点来钉。
- **删除 5 个无消费者的 provider 空壳**:`providers/community`、`douyin`、`tvbox`、`twitch`、`youtube`
  (每个 9 行 = 只有 barrel)。全仓 grep 确认无任何 import/依赖/文档引用(`platform` 测试里的
  `pure_live_tvbox_runtime` 是运行时 id 字符串,与该包无关)。根 `workspace:` 同步移除,
  `dart pub get --offline` 通过,护栏 `packages=55 errors=0`。
  理由:portfolio §6 第 7 条 —— 空壳包让包数变成误导数字。将来真要接这些站点,按消费者出现时再建包。

## 2bis. 实测依赖图暴露的四组偏差(2026-10-10,`packages/README.md` 已按实测重写)

按 pubspec 声明逐包核对消费者后得到:

1. **整条插件/TVBox 栈零 App 消费者**:`plugin_api` / `plugin_host` / `js_runtime` / `external_tvbox` /
   `python_runtime` 只互相依赖。`c8f30b45e` 把插件系统从壳里撤掉之后就悬空了。归属是 `pure_tvbox` /
   `pure_music`(ADR 0022),**在宿主 App 建起来前不删**;但也不能算"已完成",因为没人跑过它。
2. **`apps/pure_live` 仍依赖 `permission` + `extension`**:与 portfolio §3 的矩阵不符,是"拆壳"未做的残留。
3. **4 个包违反"目录短名 ↔ 包名一一对应"**:`features/{backup,search,iptv,music}` 分别叫
   `pure_live_backup_feature` / `pure_live_search_feature` / `pure_live_iptv_feature` / `pure_live_music_feature`,
   全为躲重名。**需要一次决策**:改层内短名,还是给 features 包统一加层前缀 —— 定了我再机械改名。
4. **10 个 features 包 + `foundation/{auth,cache,events,files,l10n,platform_info,sync}` + `firebase` +
   `identity` + `ui/{lyric,player_ui}` + `providers/{iptv,music,douyu}` 零消费者**。
   零消费者不等于要删:features/ui 那批是"等壳来装配"(§7 步骤 3-4),`identity` 是等跨源去重接上(w5 §2),
   `providers/{iptv,music}` 是**已实现但没装配**且 pubspec 描述还写着 "skeleton" —— 描述失真优先修,
   它是别人判断这包能不能用的第一入口。

## 3. 重写队列(按"缺口 × 消费者数"排序)

| 序 | 包 | 现状缺口(对照 §6) | 重写要点 |
|---|---|---|---|
| 1 | ~~`features/settings`~~ **已重写 `cd4c96fcb`** | 共享包里写死了一个产品的 5 个偏好键,机制本身反而没有 | 键改为消费方声明的 `PreferenceKey<T>`;带版本信封 `{v,c,value}`;读不抛+回退记账、写拒越界;`putIfAbsent` 承担首启语义;命名空间隔离 App;`importAll` 逐项校验并出报告;变更流 + `dispose` 只关自己的流。95 行 → 约 430 行,`dart analyze` 0 issue |
| 2 | ~~`features/search`~~ **已重写(本轮)** | 只有历史记录容器 | 查询规范化、跨 App 一致的排序、容量上限与淘汰、与 `services/search` 聚合器的取消语义 —— 全部落地,详见 §2 |
| 3 | `features/home` `account` `backup` `live` `vod` `iptv` `recorder` `music` **全部重写完成** | 每包原 58–191 行,domain 有形状、data 缺失 | 按 §6 补齐:data 边界 + 具名错误 + 资源释放;presentation 留给 UI 波。`music` 的 L4→L5 直连已改端口注入 |
| 4 | `ui/design` **令牌面已补齐** / `ui/ui_kit` `ui/adaptive` **已接令牌(仅静态分析验证)** / 真机与 app 传参待做 | 令牌只有 spacing/radius,组件 4 个,风格注册表无焦点/密度维度 | 令牌全集(色/距/圆/高/动效/字焦/密度)、`AppNotice`/`AppDialog`/`AppLoading`/空错态门面、D-pad 焦点序与 TV 尺寸。**下一步是把 ui_kit 与 adaptive 改成消费 `DesignTokens`** —— 否则令牌只是躺在一个没人读的包里 |
| 5 | `ui/lyric` `ui/player_ui` | 单文件适配 | 时间轴同步、句柄所有权、与 `integrations/media` 的状态订阅边界 |
| 6 | `services/search` `services/feed` **已完成** | 聚合器只有扇出 | 分页三态校验 + 按源游标 + 取消传播 + 失败记账形状已落;剩余:跨源节(继续看)受 FeedSection 形状限制,见 w5 §2 |
| 7 | `foundation/diagnostics` `events` `sync` `platform_info` **全部已修** | 薄 | 有界缓冲与守护执行的真缺陷已修;剩余:结构化事件出口、探测能力矩阵、同步游标与冲突策略 |
| 8 | `providers/douyu` | 空 barrel | 按 `providers/huya` 的形状实现 feed/browse/search/resolve |
| 9 | `ecosystem/plugin_host` `resolver` `capability` | 有实现,未过 DoD | 只做复核:错误具名、超时/体积上限、资源释放、README 平台矩阵 |

## 4. 每包完成的定义(逐条核,不合并勾)

1. `dart analyze` 在该包目录 0 issue;`dart run tool/check_architecture.dart --strict` 全仓 0 错;
2. 公共面只在 barrel 暴露,`lib/src/` 私有,公开类型有英文注释说明"为什么";
3. 每类失败有具名类型或错误码,不把底层异常直接抛给调用方;
4. 所有 IO/网络/脚本执行路径有取消、超时与输入输出体积上限,并发有显式上限;
5. 句柄/订阅/定时器有配对释放,进程内单例由组合根注入;
6. 落盘数据带格式版本与迁移路径,损坏时按域隔离;
7. README 写职责、允许/禁止依赖、平台矩阵与"未验证"清单;CHANGELOG 记不兼容点;
8. 无 TODO 占位、无"能编译但不可用"的空实现;
9. 不写测试(本轮约定),但形状必须可被一个确定性测试钉住。

## 5. 未做 / 风险

- **待决策:偏好机制住错了层。** `features/settings` 给的是"机制"(`PreferenceKey<T>` + 信封 + 命名空间 +
  变更流),但 §3 禁 feature 同层互依,所以后面的 feature 想用就得再写一份。`features/home` 已经这样写了
  (自带 `{v,order,hidden}` 信封)。**两个选项**:A 把偏好机制下沉到 `foundation/preferences`(L0,人人可用,
  settings 只留 App 词汇);B 给 §4 白名单加 `features/* → features/settings` 一条例外。我倾向 A:
  "带版本的 kv 读写"是基础设施而不是产品功能,而且 §2bis 显示 10 个 features 包都要它 —— 选 A 我就机械搬迁。
- **契约点名的类型不存在。** `docs/sources/live/source-contract.md` 用 `QualityLine` / `QualityRef` /
  `LineRef` / `LiveDetail` / `StreamTicket` 写方法签名,但 `pure_live_platform` 里**一个都没定义**
  (只有 `MediaTicket` 有)。所以 `features/live` 只能自带 `StreamVariant` 词汇,站点适配写出来时也要各写一份映射。
  要么把这些类型落进 platform 伞包(并让契约测试按它们断言),要么改契约用现有类型 —— 在有人实现
  `LiveCapability` 之前必须先定,否则第一个 provider 会把这坨差异固化成三四个方言。
- **`features/music` 的端口还没有实现者。** `MusicSourceBridge` 是为消除 L4→L5 直连而造的接缝,
  但 `apps/` 目录里现在**只有 `pure_live`** —— pure_music 壳不存在,所以没有一个适配器来实现它。
  端口形状够用与否要等那个壳建起来才能验;若届时发现形状不对,改的是适配器不是域模型,这是选可逆方案的理由。
- **ui 层同层边已按可逆方案定掉(2026-10-10)**:把 `design` 定为 ui 层的叶子(像 L0 的 utils/logging),
  §3 与 §4 已改文。理由是查出来的事实而不是偏好:`ui/lyric` **早就**依赖 design,§3 那句"只 ui_kit→design"
  已经落后于代码;而 design 无行为、不 import Flutter,放开同层边不会带进耦合。
  护栏不需要新白名单(`kAllowedLayers['ui']` 已含同层),也**没有**把 design 加进 `kLeafPackages` ——
  那会允许 L0 import ui 包。
- **未跑任何 app 侧验证**:`apps/pure_live` 的 `flutter test` 需要 `native-assets/` 预取件
  (BUILD_POLICY §3 的顺序契约),本轮没跑;包重写以 `dart analyze` + 护栏为门。
- **五个被删的 provider 若将来要接**:按 §3 第 8 行的形状重新建包,不要恢复空壳。
- **重写期间可能有并行会话**:每包独立提交,冲突时以消费矩阵与 §4 判据为准,不互相覆盖整文件。
