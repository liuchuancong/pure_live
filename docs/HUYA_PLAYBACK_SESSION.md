# 虎牙播放会话设计与回归基线

> 现网冻结日期：2026-08-30。这里记录的是虎牙官方网页的实际行为，不以第三方项目补丁作为协议依据。

## 1. 现网证据

- 普通网页观看不以账号登录为前提。虎牙帮助中心仍说明网页可直接观看，现网房间页也会在无账号会话中调用
  `POST https://udblgn.huya.com/web/anonymousLogin` 获取匿名观众 UID。
- 当前房间播放器资源为 `https://a.msstatic.com/huya/h5player/room/2608271115/vplayer.js`；本轮抓取到的房间页配置版本为
  `20260828173231`。
- FLV 不是一个可长期缓存的静态 URL。官方播放器先使用房间元数据中仍有效的 `sFlvAntiCode`；租约失效时才通过
  WUP `liveui.getCdnTokenInfoEx` 获取新的观众绑定 `sFlvToken`。请求包含 `sFlvUrl`、`sStreamName`、
  观众 `tId` 和 `iAppId=66`。
- 当前网页端传给 `getCdnTokenInfoEx` 的 `tId` 来自 `TafLink.getUserId()`：`sHuYaUA` 为
  `webh5&0.1.0&websocket`，并携带网页 Cookie。Windows `pc_exe` HYSDK 是另一套客户端身份，
  不用于网页播放令牌刷新。
- 签名身份是观众 UID（账号 Cookie 中的 `yyuid`，或匿名登录返回值），不是房间数据中的主播
  `lPresenterUid`。
- 网页播放器的 `rotl64` 只旋转 UID 的低 32 位并保留高 32 位。匿名 UID 通常超过
  `2^32`；截断高位会让 WUP 身份与 CDN 查询参数 `u` 不一致，FLV 首次连接直接返回 403，
  Windows 播放器只能延迟回退到 HLS，表现为先黑屏或偶发长播黑屏。
- `wsTime` 是服务端租约的一部分。客户端按租约失效时间提前约 30 秒刷新，不在本地把旧 `wsTime`
  延长一天。
- 刷新、重连、画质/线路切换都重新取得当前房间元数据和签名；播放器还会在 CDN/P2P 切换时保持
  已呈现画面并携带连续播放位置。说明黑屏并非账号必然要求，而是静态 URL 与破坏性换源造成的客户端问题。

原始页面、响应头和播放器脚本冻结在
`local-artifacts/research/huya-official-20260829/`，仅作为本地审查证据，不提交 Cookie 或账号数据。

2026-08-30 又冻结了当前官方房间入口及其实际加载资源：

- 房间页：`https://www.huya.com/660000`；
- 房间启动器：`roomPlayer_7bcba17f.js`，SHA-256
  `088B79C83A9C7A5172397A5ACC67CA34352DA2AB2497F57813CA9E601D539312`；
- 播放内核：`h5player/room/2608271115/vplayer.js`，SHA-256
  `F80D395A453DE6FE5233BF46C18F5AD67CAF4858FF014BF2B9F14D057B35D213`。

冻结副本位于 `local-artifacts/diagnostics/huya-official-web-20260830/`。其中房间页的外层
`hyPlayerConfig.vappid=10057` 不等于 CDN token 请求的应用号：播放内核把普通直播源配置为
`vAppid=66`，`HYPlayer.start` 再写入播放全局 `appid`，最终 `GetCdnTokenExReq.iAppId` 仍是 `66`；
`iLoopTime` 保持结构默认值 `0`。因此本仓库继续锁定 `iAppId=66 / iLoopTime=0`，不会把页面外层
`vappid` 机械写进 token 请求。

## 2. 本仓库不变量

1. **身份隔离**：`lPresenterUid` 只表示主播；播放签名仅使用账号 `yyuid` 或本进程稳定的匿名观众身份。
2. **租约不可伪造延长**：保留服务端 `wsTime`；过期签名直接淘汰并重新获取房间与 WUP 令牌。
3. **有效房间租约优先**：每次开流都生成独立的 `seqid/wsSecret`，但不会为了开流而丢弃尚有效的
   房间 FLV 模板；只有模板不可用时才刷新 WUP，并只合并同一瞬间、同一观众与同一线路的并发请求。
4. **恢复优先刷新签名**：网络、源失效或长播无帧时，先刷新当前线路；再次失败才请求下一线路，然后进入通用引擎恢复。
5. **Windows 保帧切换**：同房间画质、线路和签名更新先在同引擎候选实例上打开；候选首帧到达后再替换活动实例。
6. **直播状态单一来源**：卡片状态、进入房间和多画面入口使用同一个 `mp.huya.com profileRoom` 状态模型；不再解析易漂移的移动页脚本正则。
7. **协议顺序不臆测**：保留虎牙返回的 CDN/FLV/HLS 顺序，不因为平台是 Windows 就无证据地强制 HLS 优先。

## 3. 确定性回归

- 匿名/账号 Cookie UID 解析，网页 WUP 身份字段、64 位 UID 高位保持、低 32 位旋转与签名字段保持；
- 有效房间 FLV 模板不触发 WUP，过期模板才切换到网页身份令牌刷新；
- `wsTime` 原值保持、过期拒绝、提前刷新边界；
- FLV/HLS 扩展名、对应 AntiCode、画质 `ratio` 替换；
- 手动线路切换重新取得短期 URL，而不是复用页面初次进入时的旧列表；
- 源错误先调用签名刷新解析器；Windows 候选源首帧前活动播放器保持可见；
- 显式下播状态与未知/接口异常分开处理；多画面添加下播房间不进入播放器初始化。

## 4. 运行时核验

Windows Debug 长播记录至少包含：房间号、匿名/账号会话类型（不记录 UID/Cookie）、初始线路、令牌刷新次数、
换线次数、首帧耗时、连续无帧恢复次数、播放器/纹理实例数、工作集与私有内存趋势。正式结论必须把确定性测试、
接口探测和运行时采样分别报告，单次能播放不等于长播稳定。

## 5. Windows 最小化恢复故障（2026-08-30）

当前维护分支曾在真实虎牙直播中稳定复现：最小化约 90 秒后恢复窗口，活动纹理不再出帧，界面提示
“播放源异常”。原生日志同时出现 TLS I/O 中断和 EOF。这个问题不是房间要求登录，也不是虎牙把直播
主动停掉，而是以下恢复缺口叠加：

1. 签名刷新返回与当前字符串相同的 URL 时，管理器把它当作刷新成功，却没有重新打开已经死亡的
   TLS/解复用会话；
2. 同引擎重建预算按整个房间会话只允许一次，健康播放很久后也不恢复预算；
3. 候选播放器可能在管理器订阅事件前同步进入 playing，切换完成后管理器仍继承旧传输的 loading 状态，
   无帧看门狗和预算恢复都不会再次启动；
4. 所有立即重试集中消耗在同一个短暂网络故障窗口，没有有界延迟后的新一轮传输重建。

修复后的恢复合同为：

- 只要恢复动作由源异常触发，即使解析结果 URL 字符串没有变化，也必须重新打开传输；Windows 继续使用
  首帧门控的候选播放器，避免先销毁仍可见画面；
- 候选接管后从候选播放器读取权威播放状态，统一清除旧 loading/error，并重新启动无帧看门狗、租约刷新
  和内容探针；
- 连续健康出帧 30 秒后恢复同引擎重建预算；
- 立即恢复耗尽后仅执行 750 ms、2 s 两轮有界延迟恢复，每轮重新取得播放源并重新分配线路、引擎和源恢复
  预算；显式暂停、切房、退房和释放都会取消延迟任务。

确定性测试覆盖同 URL 死传输重开、健康出帧恢复预算、立即恢复耗尽后的延迟轮次，以及显式暂停/生命周期
取消条件。修复后相关播放测试 82/82、完整 Flutter 测试 639/639、`flutter analyze` 0 issue。

修复版 Windows Release 在虎牙当前开播房间完成了以下实机复核：

- 最小化 90 秒期间帧计数 `142 → 295`；中间出现约 15 秒瞬态停帧（停在 249），随后自动建立新纹理并恢复，
  没有进入永久黑屏；
- 恢复窗口后画面立即可见，30 秒帧计数 `387 → 447`，弹幕持续更新；
- 随后前台连续 10 分钟帧计数 `526 → 1700`，21 个资源样本全部响应，线程约 `244 → 243`，句柄
  `1705 → 1719`，没有单调句柄/线程泄漏；Private Bytes 存在换源时的瞬时峰值，随后回落；
- 虎牙 `蓝光30M → 蓝光20M` 重新出帧成功；该房间只提供线路 1，因此线路菜单只能核验为单线路状态。

证据目录：
`local-artifacts/runtime/windows-huya-recovery-fixed-20260829T222802676Z/`。

## 6. Windows 覆盖页面返回后 0×0 黑屏（2026-08-30）

继续回归发现了第二条独立链路：虎牙直播进入录制中心等覆盖页面后返回，控件和音频仍可工作，但视频区域
永久黑屏。运行日志显示旧纹理此前持续输出非零画面；恢复期间虎牙候选源出现 HTTP 403/404，新建
`VideoOutput` 只收到 `width=0, height=0`，随后旧的非零纹理却被释放。由此可确定：

1. `Player.open` 完成或 `playing=true` 只表示 libmpv 接受了地址，并不表示 CDN 已返回可解码视频；
2. 原恢复路径在候选首帧前就提交新播放器，因而会用 0×0 候选替换最后一张有效画面；
3. Windows 覆盖页面会重挂载 Flutter `Texture`，控制器缓存的相同宽高曾阻止重新向原生输出提交尺寸。
4. 覆盖页面停留超过无帧阈值时，旧逻辑还会把“Texture 被主动卸载”误判成直播停帧，在后台创建第二个
   虎牙传输；即使它成功也会增加返回时的纹理/解码器切换，若候选恰逢 403/404 则放大为黑屏。

加固后的提交条件是 **候选播放器必须报告真实呈现帧后才能接管**。候选在期限内保持 0×0、收到源错误或
没有首帧时会被销毁，活动纹理和最后一帧继续保留，再由既有有界换线/重新取签名流程处理。Windows 视频
组件每次重挂载后的第一次布局还会强制重提 viewport，即使逻辑宽高与上一次相同；提交失败则保留重试状态，
不会把失败尺寸写入缓存。录制中心覆盖期间会明确暂停“呈现帧”看门狗，但保持网络传输、音频和弹幕会话；
返回且 Texture 完成首帧布局后再重新启用看门狗，因此覆盖页面停留多久都不会触发后台换源。

确定性回归覆盖：有首帧候选正常接管、0×0 候选不得释放活动纹理、健康出帧恢复下一轮预算、覆盖页面隐藏
期间不重开传输、同尺寸 viewport 强制重提交。专项结果 52/52 通过，`flutter analyze` 0 问题，质量记录为
`local-artifacts/build-records/20260830T011808450Z-quality-focused.json`。

## 7. Win11 约 130 秒断流与上游 v3.0.8 审查（2026-08-30）

在前台直接打开虎牙 `660000` 的 Release 诊断中，又分离出第三条独立链路：

- FLV 从稳定出帧到 `playing=false / loading=true / complete=true` 约 129.6 秒；
- 将协议改成 HLS 后仍在约 131 秒结束，下一次连接也在相近时长结束，播放列表刷新同时返回 HTTP 403；
- 两次源的 `wsTime` 都仍有接近一天有效期。因此这里只能把“活动连接约 130 秒结束”视为现网行为证据，
  不能继续把签名到期时间等同于单次传输寿命，也不能用 FLV/HLS 互换解释根因。

上游 `v3.0.8` 的发布提交 `83f3b73e` 只修改版本、发布配置和两处滚动物理；实际被发布说明称为
“修复 huya 断流”的功能代码来自更早的 `53bf0411`。该实现的核心是：改为解析房间 HTML 内嵌数据、
每次生成播放地址时调用 `getCdnTokenInfoEx`，并把原来永久缓存的 WUP token 改成固定两分钟缓存。
这能缓解“再次取得播放地址时仍复用旧 token”的问题，但没有建立长播连续性合同：

1. 上游播放器对 `onComplete` 只转发事件，没有刷新源、重新开流或首帧门控切换；
2. 固定两分钟缓存没有读取服务端 `wsTime`，也没有在正在播放时触发刷新；
3. 上游把 `sFlvToken` 同时用于 FLV/HLS，并用 `presenterUid`（当前构造中实际填入 `topSid`）参与签名，
   与已核对的网页观众身份流程不一致；
4. 没有覆盖“连续播放超过两分钟”的确定性测试或 Windows 长播证据。

因此本仓库不整文件替换为上游实现。保留观众身份、服务端到期时间、协议独立 AntiCode 和权威状态模型，
同时吸收“恢复时必须重新取得 token、禁止永久缓存”的正确方向。

Windows 的最终策略是把 **签名租约** 与 **活动传输租约** 分开：虎牙源在打开后 100 秒触发候选连接，
候选在屏幕外完成 DNS/TLS/解复用/解码，并在真实首帧到达后才接管当前纹理；旧连接在提交前持续显示。
候选失败时保留旧连接并在十秒后重试，绝不回退到先销毁活动播放器再重开。与此同时，原生帧探针只发布
帧进度，不再逐帧重复广播 `playing/loading`，避免看门狗、UI 监听器和计时器每秒被重建数十次。

确定性门禁为相关测试 55/55、`flutter analyze` 0 issue，质量记录：
`local-artifacts/build-records/20260830T033455147Z-quality-focused.json`。

新 Windows Release 随后在同一房间连续运行约八分钟，完成 4 次首帧门控接管（session 1→5），记录
930 次原生帧回调；全程没有 `complete=true`、`live_source_completed` 或 native error，第四次接管后帧仍持续
增长。两次换流资源峰值分别约 421/1075 MB 与 425/1098 MB（Working Set/Private Bytes），十秒后均回落到
约 362/803 MB、374/824 MB，线程保持约 242–247、句柄约 1687–1717，没有按接管次数单调增长。
Windows 构建记录：`local-artifacts/build-records/20260830T034959413Z-build-windowsx64-release.json`；运行证据：
`local-artifacts/runtime/windows-huya-proactive-handoff-20260830T035042734Z/`。

## 8. 官方续租与重连机制复核（2026-08-30）

当前官方脚本把签名、token 更新和传输重连分成三个状态层：

1. `AntiCode.parseAnticode` 从 `wsTime` 计算失效点：`wsTime * 1000 + 300000`，并把下一次刷新设为
   失效前 30 秒；定时检查命中后调用 WUP `liveui.getCdnTokenInfoEx`。响应的 `sFlvToken` 被解析成
   新 AntiCode 并触发 `REFRESH`，而 `iExpireTime` 虽然存在于 TARS 响应结构，当前网页逻辑没有直接
   用它替代 `wsTime` 计时。
2. FLV/P2P `VideoLoader.reconnect` 在重连前比较活动 URL 和 `loaderMgr.antiCode`；若已有新 AntiCode，
   就替换 URL 中的 `wsSecret/wsTime`，然后轮换域名、关闭旧连接并重新连接。连接超时、首包超时、
   EOF/close 都进入这套恢复链，而不是把一次 URL 当成永久连接。
3. HLS 开启 `autoReconnect`；分片失败、分片超时或播放列表异常会销毁当前 HLS 会话、重置解析状态并
   重新 `start(info)`。官方帮助中心也把切换线路、画质、解码和重新进入房间列为网页/PC 黑屏卡顿的
   标准恢复动作。

进一步把真实 HLS 地址与官方 `AntiCode.getAnticode` 对照后，还能确定每次开流的签发时间直接编码在
URL 中：官方生成 `seqid = viewerUid + Date.now()`；非 WAP 地址把同一个 viewer UID 旋转后写入 `u`，
WAP 地址则写入 `uid`。因此反向旋转 `u` 后，`seqid - viewerUid` 就是该 URL 的毫秒签发时间。现网三轮
HLS/FLV 都在签发后约 129～132 秒结束，而 `wsTime` 仍有近一天，这支持“CDN 另有短传输会话”的判断。
这是由官方签名关系和本地时序共同得到的推断，不把约 130 秒写成虎牙公开承诺值。

另外，播放器确实每 60 秒调用一次 `launch.wsTimeSync`，但继续追踪调用链后确认：其客户端时间来自
`performance.now()`，返回的同步时间仅用于把直播流 SEI 中的采集/发送时间换算为端到端延迟指标；
AntiCode、`wsTime`、`seqid` 和续租调度没有读取该结果。因此它不是 CDN 签名的服务器墙钟接口，不能
把 `lServerTime` 当 Unix epoch 写入播放签名。本仓库保留这一反证，避免以后引入额外 WUP 请求和错误时钟偏移。

这说明现网黑屏的根因不是“必须登录”。登录只会把匿名观众 UID 换成账号 UID；签名租约、CDN 单次
连接结束、HTTP 403、线路切换和解码恢复仍然存在。网页登录态也没有绕开 AntiCode 刷新和传输重连。

本仓库据此增加两层兼容：

- 同步官方当前 TARS UA `webh5&0.1.0&websocket`，并用回归测试锁定 `iAppId=66`、`iLoopTime=0`、
  viewer UID/GUID/Cookie，防止以后误把主播 UID、页面 `vappid` 或桌面 HYSDK 身份写入 token 请求；
- WUP 响应若给出比 `wsTime+5 分钟` 更早的 `iExpireTime`，在内存中用 SHA-256 URL 指纹保存该更早
  上界，最多保留 32 条且过期即删除；
- 从 URL 的 `seqid/u/uid` 恢复稳定签发时间，签发后 100 秒进入续租、125 秒进入失效边界。这个时间不再
  随 `getPlayUrlRefreshAt` 被调用的时刻向后漂移，也不会让缓存中的旧 URL 因为晚读元数据而获得一轮
  新的 100 秒寿命。所有平台共享该短会话元数据；Windows 在 100 秒处首帧门控热切换，其他平台提前
  预取新签名并在真实重连时消费。播放器最终取 `wsTime`、WUP 服务端上界和短会话三者中的最早时间；
  URL 原文、Cookie、UID 和 token 不进入日志或持久化文件。

本轮虎牙 URL/身份/短会话与播放器恢复定向门禁 53/53 通过，`flutter analyze` 0 issue；质量记录：
`local-artifacts/build-records/20260830T055447060Z-quality-focused.json`。

## 9. 录制内核的租约续接（2026-08-30）

播放器完成无黑场热切换后，录制内核仍有一条独立缺口：原生 FFmpeg 输入结束时，控制器先把本轮 TS
同步封装为 MP4，再启动下一次输入。一次封装在真实磁盘上需要约 10～20 秒，所以即使重连计时器只有
1～2 秒，最终文件之间仍会产生明显缺口。另一个生命周期错误是 `FFmpegService.start()` 会一直等待
原生会话结束；如果把租约定时器写在 `await start()` 后面，该代码只有录制结束后才会执行，运行中的
100 秒续租实际上从未被安装。

当前实现把录制会话、原生输入尝试和最终媒体文件明确分成三层：

1. `startAck` 是原生输入已建立的权威边界，控制器在这里按当前 URL 的 `refreshAt/invalidAt` 安装预取与
   切换定时器，而不是等待 `start()` 返回；
2. 到刷新点前 5 秒重新解析同一画质、同一线路，结果只保存在内存；到刷新点主动取消旧 FFmpeg 输入，
   该终止被标记为静默、可重试的 `leaseRefresh`，不等同于用户停止、下播或录制失败；
3. 每个原生输入尝试使用独立目录和文件前缀。旧输入产生的 TS 只登记为待封装产物，下一次输入先启动；
   用户真正停止录制后，再按顺序统一封装并删除 TS。待封装清单随任务 schema v5 持久化，进程异常退出后
   仍能从原绝对目录恢复，不会把上一轮片段遗失或混入新前缀；
4. 诊断只记录平台、距刷新/失效的毫秒数、会话年龄和失败分类，不记录 URL、Cookie、UID 或 token。

当前源码 Windows x64 Release 候选在公开虎牙房间连续录制 342 秒，跨越三次主动输入切换。录制中心的
时长和大小持续增加，窗口 61/61 个样本全部响应；停止后生成 4 个非空 MP4，`ffprobe` 总时长
`342.093 s`，与 UI 的 `342 s` 一致，全部为 H.264 1920×1080 + AAC，残留 TS 数为 0。资源采样期间
CPU 平均 `1.12%`、P95 `1.82%`，线程 `248 → 247`；Private Bytes 在换流时峰值约 `1.02 GiB`，结束前
回到约 `0.79 GiB`，没有随切换次数单调增加。

证据：

- `local-artifacts/runtime/windows-full-matrix-20260830/20260830T074635793Z-huya-current-source-recorder-lease-rotation-pid46468-summary.json`；
- `local-artifacts/runtime/windows-full-matrix-20260830/20260830T075147000Z-huya-current-source-recorder-lease-media-summary.json`；
- `local-artifacts/build-records/20260830T073018790Z-quality-focused.json`；
- `local-artifacts/build-records/20260830T074217142Z-build-windowsx64-release.json`。

这里仍把约 129～132 秒写成由官方签名公式与现网时序共同得到的**观测推断**，而不是虎牙公开 SLA。
官方网页脚本直接证明的是：AntiCode 有独立失效/提前刷新状态，FLV/HLS 具有自动重连状态机，
`GetCdnTokenExReq` 使用观众身份和 `iAppId=66`；当前网页代码虽解析 `iExpireTime` 字段，但没有直接用它
替代 `wsTime` 的计时逻辑。本仓库只把服务端给出的更早 `iExpireTime` 当作保守上界。

## 10. AntiCode 模板逐字段复核（2026-08-30）

再次以 `Cache-Control: no-cache` 获取房间 `660000` 后，页面仍加载相同的
`roomPlayer_7bcba17f.js` 和 `h5player/room/2608271115/vplayer.js`；两个文件的 SHA-256 与本页第 1 节
冻结值完全一致。当前服务器合同没有发生版本漂移。

这次把 `AntiCode.getAnticode` 的实际模板处理进一步落实到实现：服务端 `fm` 解码后是包含 `$0/$1/$2/$3`
的完整签名模板，官方代码是在原字符串上依次替换观众 UID、流名、`md5(seqid|ctype|platform)` 和
`wsTime`，再对完整结果做 MD5。它没有承诺模板一定是 `prefix_$0_$1_$2_$3`。因此本仓库取消“按下划线
截取第一个字段再自行拼装”的隐含结构假设，完整保留服务器模板与分隔符；任一占位符缺失时在打开 CDN
之前直接淘汰该模板并走既有的 WUP/房间刷新路径。

`fm` 只属于本地签名材料：官方在解析阶段消费它，最终媒体查询只携带重新生成的 `wsSecret`、原
`wsTime`、新 `seqid`、`ctype`、`ver=1` 和其余服务端参数。本仓库现也从最终 URL 中移除 `fm`，减少
向 CDN 回传无关模板材料，并用非下划线、乱序占位符夹具锁定完整模板替换。这个修正不会改变匿名/账号
策略；两者仍只是 viewer UID/Cookie 不同，续租与重连合同相同。

服务器可以在同一个房间快照内按 CDN/协议分别滚动 AntiCode，FLV 与 HLS 字段相同只是当前部分房间的
现象，不是接口保证。地址生成现在先按协议选取对应的 `sFlvAntiCode` 或 `sHlsAntiCode`；一条线路模板
过期、畸形或 WUP 刷新失败时，只淘汰该线路，仍并行保留同批次中可正确签名的其他 CDN/协议。这样服务端
灰度发布一条新 token 模板时不会把整个房间的健康备选一起清空，也不会在 FLV 刷新失败后误拿 HLS token
拼接 FLV 地址。

匿名登录接口短暂失败时仍使用本进程稳定的临时 UID 完成本轮有界恢复，但该临时 UID 不再缓存到进程结束；
下一次独立取源会重新请求官方匿名身份。此前把本地临时 UID 永久缓存后，第一次网络抖动可能使后续所有
AntiCode 都绑定到服务器未确认的观众身份，表现为重启应用前持续 403。官方身份一旦取得仍正常缓存，避免
每条线路重复登录。

该故障注入还暴露了原回退 UID 生成器的隐藏崩溃：Dart `Random.nextInt` 的上限是 `2^32`，旧代码直接请求
1000 亿范围，只在匿名登录失败、首次真正读取回退值时抛出 `RangeError`。现用两个合法均匀区间组合出同样
的 1000 亿范围，匿名接口故障会进入有界回退/重试而不是打断整个取源 Future。

同日又执行了一次不含账号 Cookie 的在线合同探针：`anonymousLogin` 返回 HTTP 200 和正整数 UID；使用该
UID、当前房间完整 `fm` 模板及官方公式生成查询，移除 `fm` 后直接连接官方 AL FLV CDN，返回 HTTP 200、
`video/x-flv`，读取的 4096 字节以 `FLV` 文件头开始。探针摘要位于
`local-artifacts/diagnostics/huya-official-web-20260830-refresh/official-media-probe-summary.json`，仅记录
字段名、布尔结果、CDN 类型和状态码，不记录 UID、token、Cookie 或完整媒体 URL。

上述服务器模板、协议隔离、匿名重试和回退随机数用例在虎牙取流测试文件中 28/28 通过。

## 11. 当前 profileRoom 线路矩阵与旧 token 兼容（2026-08-30）

继续对当前 `mp.huya.com/cache.php?m=Live&do=profileRoom&showSecret=1` 返回做脱敏核对。公开房间
`660000` 在本次采样中给出 5 条可选 CDN（AL、TX、HS、TX15、HS24），每条同时提供 FLV 与 HLS，
另有一条优先级为 `-1` 的 AL13 基础描述没有进入 `multiLine`，客户端不会把它误列为可选线路。当前
AntiCode 是 `ctype=tars_mp / t=102`；它与房间 HTML 中另一组 `huya_live` 模板属于不同入口，不能把
某个入口的固定值覆盖到另一个入口。

用官方匿名 UID 和各线路自己的完整模板分别签名后，10/10 媒体入口都返回有效内容：5 条 FLV 为
HTTP 200、`video/x-flv` 且以 `FLV` 开头；5 条 HLS 均以 `#EXTM3U` 开头，其中部分 CDN 对 Range 请求
返回 HTTP 206 和 `application/x-mpegurl`，其余返回 HTTP 200 和
`application/vnd.apple.mpegurl`。因此 206 是健康的分段响应，不应被错误分类成线路失败。不同线路
实际落在 Tengine、MC_VCLOUD_LIVE、Bytedance NSS 等不同边缘实现上，单次首包延迟也不相同；这解释了
为什么官方客户端保留线路切换和自动重连，而不是把一次成功 URL 当成永久连接。脱敏摘要：
`local-artifacts/diagnostics/huya-official-web-20260830-refresh/current-profile-all-lines-probe.json`。

本次审查还修正了两个兼容缺口：

- `multiLine` 的字段名是 `cdnType`，旧代码却把 `sCdnType` 写入模型，导致诊断和后续线路身份只得到
  `null`；现保留服务器真实 CDN 名称，同时仍按服务器给出的 `multiLine` 顺序展示；
- 当前模板带 `seqid` 时可从 URL 恢复签发时间，旧式静态 token 则没有该字段。现在每一个由当前
  `HuyaSite` 构造的虎牙 CDN URL 都用 SHA-256 指纹记住内存中的签发时刻；即使没有 `seqid`，也在
  100 秒进入首帧门控续接、125 秒进入失效边界，不再退回很晚的 `wsTime+5 分钟` 后等待黑屏 EOF。
  过期边界不会在查询瞬间删除，避免死 URL 再次看起来有效；缓存最多 64 条，不持久化完整 URL。

`HuyaLineModel.toString()` 同时取消输出完整线路 URL、FLV/HLS AntiCode 和流名，只保留 host、协议、
CDN 类型和码率，防止异常诊断把 `wsSecret`、`fm` 或流标识写入日志。

本节新增的旧 token 短租约和诊断脱敏用例加入后，虎牙取流测试为 30/30 通过，`flutter analyze`
为 0 issue；质量记录：
`local-artifacts/build-records/20260830T101435076Z-quality-focused.json`。

## 12. CDN 会话窗口与 Windows 提前续接（2026-08-30）

继续把“URL 签名有效”和“这条媒体连接还能持续多久”拆开验证后，服务器行为可以归纳为五层：

1. **观众身份层**：账号 Cookie 的 `yyuid` 或 `anonymousLogin` 返回的 UID 只确定观众身份；登录不会把
   CDN 连接变成永久连接，也不会取消线路、Token 与传输重连。
2. **房间快照层**：`profileRoom` 返回当时可用的 CDN、协议、流名与 AntiCode 模板；它是可刷新快照，
   不是可永久保存的播放清单。
3. **签名租约层**：`fm/wsTime/seqid/u(or uid)` 共同约束一个观众的一次签发。`wsTime+5 分钟` 是网页
   AntiCode 计时上界，但不是媒体 socket 的承诺时长。
4. **边缘传输层**：即使初始响应为 HTTP 200，Tengine 等边缘也可通过 `Connection: close` 正常结束
   FLV；同一签名被晚启动或并发复用时，可用窗口还会明显缩短。
5. **呈现层**：客户端必须把重新解析、候选播放器初始化、首帧确认和 Texture 交接视为一个事务；只在
   EOF 后破坏式重开，必然把服务器的短会话窗口暴露成黑屏。

本轮对同一个匿名签名 URL 做了两组只记录脱敏统计的实验：

- 单连接立即打开约 `100.780 s` 后收到 EOF；同一个 URL 在签发后 90 秒再打开，虽然仍返回 HTTP 200，
  但只持续 `20.476 s`。两条连接落到不同 `live*.cn3848` 边缘，均由 Tengine 主动关闭。
- 同一 URL 在签发后 0 秒和 30 秒并发打开时，两条连接分别只持续 `80.596 s` 与 `40.469 s`。

这组结果排除了“每次 TCP 连接都固定拥有约 130 秒”的假设，也说明拿到 HTTP 200/首帧后不能停止续租。
证据只保存 host、状态、时长、字节数和响应头摘要，不保存 UID、完整 URL、Cookie 或 Token：

- `local-artifacts/diagnostics/huya-official-web-20260830-refresh/same-signed-url-concurrent-lifetime-probe.json`；
- `local-artifacts/diagnostics/huya-official-web-20260830-refresh/same-signed-url-sequential-lifetime-probe.json`。

此前 Windows 实机的第 5 次续接也暴露了客户端余量不足：旧源在 `18:44:20.012` 完成，而从开始解析
新源到候选播放为 `46.976 s`，到完整提交为 `50.734 s`；原 100 秒续接点只剩约 30 秒服务端余量，
因此出现约 17～20 秒无新帧。新的 Windows 虎牙策略以**当前安装的传输**为基准，取服务端声明刷新点
与本地 40 秒提前续接点中的更早值；解析出的新 URL 在候选实例产生真实首帧后才提交，候选失败则保持
旧画面并在 10 秒后重试。该限制只匹配虎牙 `.flv/.m3u8` host，不改变 Android、其他平台或普通 URL。

## 13. 官方重连状态机与 Windows 双实例续接（2026-08-30）

对当前官方 `vplayer.js` 的 AntiCode 和 `VideoLoader` 两个状态机逐字段复核后，可以进一步确认：

- AntiCode 将十六进制 `wsTime` 换算为 `wsTime × 1000 + 300000 ms` 的失效点，并在失效点前
  `30000 ms` 触发刷新；刷新调用 `liveui.getCdnTokenInfoEx`，请求携带当前网页观众 `tId`、流地址、
  流名和播放 `appid`。它没有因为用户已登录而跳过续租。
- 每次签名使用 `seqid = viewerUid + Date.now()`，完整替换服务端 `fm` 的 `$0/$1/$2/$3` 后生成
  `wsSecret`。账号与匿名会话只改变 viewer UID/Cookie，签名、线路和传输生命周期完全相同。
- `VideoLoader.reconnect()` 会把刷新后的 `wsSecret/wsTime` 写回当前 URL、轮换可用域名并重新连接；
  `onclose`、连接超时、首包超时和无切片数据分别进入有界恢复，HTTP 403/404 还有单独统计与 403
  回调。由此可知，官方网页本身也把“Token 刷新”和“活动传输重连”当作两件事。

本仓库在 Windows 上比官方网页的 EOF 后恢复多加了一层无黑场事务：活动播放器继续呈现，候选播放器
拿到真实首帧后才提交。此前每 40 秒都重新创建 libmpv、D3D renderer 和 Flutter Texture，首轮实测可
消耗 `8.841 s`，极端历史样本甚至约 51 秒，也会让短时内存随交接抖动。本轮改成固定两个 Windows
MediaKit 实例交替工作：退役实例先 `softStop` 卸载 Media，从而关闭旧 CDN 连接并释放解复用/解码缓存，
但保留已初始化的 native Player 与 D3D renderer，作为下一次候选。移动端仍保持原生命周期策略。

最新 Debug 对公开房间 `660000` 连续完成 8/8 次提前续接，失败保留旧源 0 次、原生错误 0 次、终止错误
0 次。首个冷候选耗时 `8841 ms`；进入双实例交替后分别为
`1082/1775/1020/604/602/514/1008 ms`。整段只初始化两个 VideoOutput：日志中的 4 次 Texture create
是两个输出各自从 0×0 切换为 1920×1080 时的正常一次重建，后续 7 次续接没有继续创建或销毁
VideoOutput；第 8 次提交后仍持续收到 `VideoOutput.Frame`。

241.674 秒资源采样 49/49 全部响应：CPU 平均 `2.139%`、P95 `2.996%`；线程 `322 → 325`、句柄
`2001 → 2019`。Working Set `850.5 → 926.4 MiB`，Private Bytes `1173.0 → 1212.6 MiB`，期间换源/缓存
回收峰值 `1520.5 MiB`。这段短采样仍保留正向缓存斜率，不能单独当作无限时内存结论；但 native
实例数和 Texture 数已被锁定为 2，不再随 40 秒续接次数线性增长。

验证证据：

- `local-artifacts/runtime/windows-huya-ping-pong-20260830/stdout.log`；
- `local-artifacts/runtime/windows-huya-ping-pong-20260830/20260830T134305205Z-huya-ping-pong-warm-standby-pid64796-summary.json`；
- `local-artifacts/build-records/20260830T134003653Z-build-windowsx64-debug.json`。

对应门禁为 `player_error_recovery_test.dart`、`huya_play_url_test.dart` 和
`media_kit_video_geometry_test.dart` 合计 67/67 通过，`dart analyze lib/player` 为 0 issue。生产适配器另有
Windows-only 可复用合同测试，避免测试替身支持复用、真实 MediaKit 却仍被销毁的配置漂移。
