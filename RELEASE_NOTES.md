# Pure Live v3.1.1

v3.1.1 build 4114 是 Android / Windows 多画面体验补丁。本轮没有合并新的上游提交；修复 Issue #820 中只有 1+3 布局可调音量、其他布局弹幕按钮不工作，以及格子重建后音量丢失的问题。Android `arm64-v8a`、Windows x64 安装程序和便携 ZIP 从同一源码提交串行构建。

## 多画面声音与音量

- 1×1、1×2、2×2、1+3 四种布局都增加当前声音来源格的音量入口；没有有效播放格时入口保持禁用。
- 声音来源改为唯一响应式状态，音频启用、工具栏、音量弹窗和弹幕目标不再依赖多处手动刷新。
- 音量弹窗显示房间名称、实时百分比与滑杆；复用普通直播间的按房间音量存储，移除格子、重建播放器或重新进入后继续恢复用户设置。
- 音量存储异常只进入诊断，不会阻断播放、切台或播放器释放。

## 多画面弹幕

- 1+3 布局继续把弹幕绑定到大画面；1×1、1×2、2×2 改为绑定当前声音来源格。
- 切换声音来源会同步切换弹幕会话与渲染目标，旧格不会残留同一房间弹幕。
- 修复顶部弹幕按钮在非 1+3 布局只改变视觉状态、实际没有连接和渲染目标的结构问题。

## 验证与交付

- 聚焦 Analyze 为 0 issue，`test/multiview_test.dart` 45/45 通过；新增 2×2 弹幕目标切换与按房间音量重建恢复测试。
- 冻结源码完整门禁通过：Analyze 0 issue、Flutter 669/669、公开平台接口 42/42、全仓审计 0 error。
- Windows Debug 2×2 页面确认全布局音量入口实际渲染；v3.0.1 以来的跨模式比例、播放器释放和录制状态回归继续进入完整门禁。
- v3.1.0 Windows 便携正式包补充 Bilibili 播放/弹幕/设置/画质/录制与 10 分钟资源采样证据，详细记录见 `docs/ACCEPTANCE_MATRIX_3_1_0.md`。
- APK、Windows 安装程序和便携 ZIP 均附独立构建元数据及 SHA-256；完整根因、改动和证据边界见 `docs/STAGE_UPDATE_3_1_1.md` 与 `docs/ISSUE_AUDIT_2026_08_31.md`。

---

# Pure Live v3.1.0

v3.1.0 build 4113 是 Android / Windows 稳定性与网络一致性更新。本轮没有合并新的上游提交；以维护分支 v3.0.24 为基线，集中交付后台播放策略、Bilibili 弹幕有界解析、统一应用代理、启动竞态与本机构建门禁修复。Android `arm64-v8a`、Windows x64 安装程序和便携 ZIP 从同一源码提交串行构建。

## 后台播放、纯音频与助眠

- 修复关闭后台播放后，手动纯音频仍隐式取得后台保活权限的问题；耳机按钮只改变当前房间呈现/功耗模式。
- 后台继续播放现在只接受两个明确意图：用户打开后台播放，或用户已经启动带停止计时的助眠会话。
- 主动系统 PiP 继续播放，普通退后台按总开关暂停；回前台恢复和计时停止使用同一策略边界。
- Android 16 实机四组合已核对媒体状态、CPU/Wi-Fi lock、回前台恢复及 1 分钟到点资源释放。

## Bilibili 与实时弹幕

- Bilibili 多包及 zlib/Brotli 嵌套协议增加传输大小、解压输出、帧数和嵌套深度硬边界；零长度、截断或压缩放大帧不会形成死循环或无限内存增长。
- 当前坏帧只终止当前 WebSocket 消息解析，后一条正常弹幕仍可继续进入列表和画面。
- 用户名优先选择完整富字段，平台返回掩码名时保留完整旧字段回退；观看累计与平台热度继续保持不同指标语义。
- WebSocket 的单连接、静默半开检测、有界轮换和房间关闭代次隔离保持回归覆盖。

## 代理、封面与弹幕连接

- 修复应用代理只覆盖 Dio 的结构缺口：平台 API、封面/头像缓存和所有平台弹幕 WebSocket 现在读取同一套实时应用代理设置。
- 播放器媒体流继续由独立播放器代理控制，接口代理不会无意改写解码链路。
- 中文输入法输入 `127。0。0。1` 等全角地址时即时转换为 ASCII；初始化、备份导入和保存同样归一化。
- 代理主机、端口与 IPv6 指令统一校验；分号/换行注入、空主机和越界端口保持直连。
- 虎牙当前公开房间协议探针完成 WebSocket 101、分组注册、心跳并收到 command 22；Android Debug 已验证代理下目录、封面和头像一致加载。

## 启动、测试与交付

- 应用首次启动等待设置服务完成注册，避免升级或新安装时首帧先于依赖初始化而出现白屏/重复启动。
- Android UI 自动化补充启动稳定等待、控制层确定性唤出和包版本校验；后台播放、助眠和 PiP 证据写入 v3.1.0 验收矩阵。
- APK 门禁核对包名、版本、唯一 arm64 ABI、Flutter 资源、FFmpegKit、SQLite、MediaKit、应用原生库、签名状态和 SHA-256。
- Windows 安装程序继续支持自选目录，并同时提供便携 ZIP；两个平台分别记录构建命令、耗时、峰值资源、产物路径和校验文件。
- 冻结源码完成一次 Analyze（0 issue）、完整 Flutter 回归（667/667）、公开平台接口探针（42/42）和全仓审计（3884 个文件、0 error）；质量记录为 `20260831T032317652Z-quality-full.json`。

## 证据与已知边界

- 完整证据和根因：`docs/STAGE_UPDATE_3_1_0.md`、`docs/NETWORK_PROXY_AUDIT_3_1_0.md`、`docs/ISSUE_AUDIT_2026_08_31.md`、`docs/ACCEPTANCE_MATRIX_3_1_0.md`。
- 公开接口探针只证明当前匿名 API 合同；平台账号风控、地区限制、主播下播、CDN 与用户网络波动仍按运行时诊断处理。
- Linux、macOS 和 iOS 本轮没有重新构建，继续使用已有 Release 资产。

---

# Pure Live v3.0.24

v3.0.24 build 4112 集中交付虎牙现网播放会话、Windows 长播连续性、直播状态、多画面离线空态和录制续租修复。本轮串行发布 Android `arm64-v8a` 与 Windows x64 安装包；Android 使用平台原生播放路径，Windows 对虎牙短连接增加首帧门控的双播放器暖切换。

## 虎牙匿名取流与服务器会话

- 对齐虎牙当前网页匿名观看流程：账号登录只改变观众 UID/Cookie，匿名观看仍可使用；主播 UID、网页观众 UID 与 Windows HYSDK 身份彻底分离。
- 保留 64 位观众 UID，高 32 位不再被截断；TARS UA、`iAppId=66`、`iLoopTime=0`、FLV/HLS 独立 AntiCode 和线路顺序均按当前官方播放器合同锁定。
- AntiCode 改为在服务端完整 `fm` 模板原位替换占位符；模板畸形、签名过期或单线路失败只淘汰对应候选，不再清空同一快照中的其他健康线路。
- 综合 `wsTime`、WUP `iExpireTime`、`seqid` 签发时间和活动传输寿命判断刷新边界；同一个旧 URL 不会因晚读取元数据而获得新的有效窗口。
- 匿名登录瞬态失败不再永久缓存临时身份；随机 UID 生成保持在 Dart 合法范围，后续请求可重新取得官方匿名身份。

## Windows 长播无黑场续接

- 虎牙活动传输按本地 40 秒与服务器声明刷新点中的较早值启动候选连接；候选完成 DNS、TLS、解复用并实际呈现首帧后才接管，旧画面在提交前持续显示。
- 固定复用两个 MediaKit/D3D 输出交替续接，旧 session 的迟到 `complete/buffering/error` 由代次栅栏丢弃；相同 URL 的死亡传输也会真正重新打开。
- 0×0 或首帧超时的候选只释放候选自身，不替换最后一个有效纹理；覆盖页面返回时强制重新提交 viewport，隐藏期间暂停呈现帧看门狗而不破坏网络、音频和弹幕会话。
- 原生帧探针只发布帧进度，不再逐帧重复广播相同播放状态；暖机后的播放器、VideoOutput 与 Texture 数量保持固定，减少换源抖动和资源增长。

## 直播状态、多画面与返回

- 卡片、进入房间和多画面统一使用权威直播状态；明确下播、接口未知和解析失败分开表示，应用冷启动及恢复前台会重新核验，旧的“正在直播”缓存不会继续冒充当前状态。
- 多画面加入下播房间时显示可重新选台的业务空态，不请求画质或播放地址，也不创建原生播放器；替换为开播房间后再初始化并成对释放资源。
- Windows 离线直播页保持页面级 Escape 返回；播放器尚未创建时不会读取残留的全屏状态或注册无效音量、录制快捷键。

## 录制租约与恢复

- 原生输入建立后的 `startAck` 成为续租计时边界；刷新点前预取同画质、同线路的新签名，到点静默切换输入，不把租约续接误报为用户停止、下播或录制失败。
- 每次输入使用独立目录和前缀，上一轮 TS 先登记为持久化待处理组，新输入优先建立；真正停止录制后再统一封装，避免同步 remux 造成十余秒录制缺口。
- 任务 schema 升级并保存待处理产物，异常退出后仍可继续整理；诊断只记录脱敏后的时间边界和失败分类。

## 验证与证据边界

- 虎牙当前房间的 5 条 CDN、FLV/HLS 共 10 个入口完成媒体头探测；Windows 公开房间完成 8/8 次提前续接，后 7 次暖切换耗时约 0.5～1.8 秒，第 8 次提交后仍持续出帧。
- Windows 虎牙录制连续 342 秒并跨越三次主动输入切换，最终 4 个 H.264/AAC MP4 总时长与界面累计一致，残留 TS 为 0。
- 最终源码 `flutter analyze` 为 0 issue，完整 Flutter 回归 661/661、公开接口探针 42/42 通过；Android APK 内容门禁与 Windows 安装器/便携包继续按产物阶段独立核验。真实服务器和极端网络仍按脱敏诊断继续观察。

---

# Pure Live v3.0.23

v3.0.23 build 4111 完善 Android 全面屏上的竖屏全屏呈现。根因不在竖屏识别，而是 9:16 直播源与约 20:9 手机屏幕的比例差必然产生上下空白，旧版又用 45% 黑色蒙层压暗封面背景，使空白区域看起来仍像纯黑边。本轮只更新 Android `arm64-v8a`；Windows 继续使用 v3.0.19 稳定安装版与便携版。

## 四种竖屏全屏画面模式

- **完整画面**：保持全部直播内容与原始比例，空白区使用纯色，适合字幕、游戏 UI 或边缘内容较多的直播。
- **沉浸背景（默认）**：前景完整不裁剪，上下空白使用缓存封面模糊延展；暗色蒙层由 45% 降到约 15%，并使用镜像模糊边界防止边缘重新发黑。
- **平衡填充**：根据设备与直播源比例计算放大倍数，最高限制为 1.08，只轻微裁剪左右，剩余空白继续使用沉浸背景。
- **铺满裁剪**：明确委托原生播放器使用 `cover` 铺满屏幕，当前 20:9 与 9:16 组合约裁掉左右总计 19%；该模式只由用户主动选择。

## 交互、隔离与性能

- 竖屏全屏控制条增加即时切换入口，设置页增加持久化选项；旧配置或损坏枚举安全迁移到“沉浸背景”。
- 新模式只在稳定竖屏源的专用竖屏全屏状态生效；普通直播页、横屏全屏、Android 系统画中画和应用小窗沿用各自比例，不共享裁剪状态。
- 背景使用缓存封面和静态渐变，不启动第二路播放器、不持续截取视频帧，避开 Android 硬解截图曾导致 Surface 分离和随机暂停的问题。

## 验证

- 新增旧配置迁移、背景层隔离、1440×3168 全面屏缩放上限、铺满模式原生 `cover` 委托以及控制层保持全屏尺寸的确定性回归。
- Android arm64 正式交付执行完整静态分析、完整 Flutter 测试、APK 内容检查与连接设备场景采样；实机证据与剩余限制按最终 Release 记录为准。

---

# Pure Live v3.0.22

v3.0.22 build 4110 为 Android 竖屏直播新增“下滑隐藏弹幕栏并进入竖屏全屏”的独立交互；该能力只由稳定竖屏源启用，普通直播和 Windows 布局不进入此分支。本轮只更新 Android `arm64-v8a`；Windows 继续使用 v3.0.19 稳定安装版与便携版。

## 竖屏专属进入条件

- 入口同时要求 Android 手机、稳定竖屏源、已开启竖屏适配与自适应高度、非兼容布局；任何条件不满足都沿用原播放器布局。
- 普通比例直播不显示下滑提示，也不响应面板退出手势；Windows 端继续使用桌面分栏，不新增移动端手势。
- 进入前再次读取当前竖屏识别和设置，避免画质切换或直播源变化时使用过期判定。

## 面板手势与沉浸观看

- 弹幕面板先收缩到最小停靠点，再随手指继续向屏幕底部移动；超过 30% 自适应距离或明确下甩后进入竖屏全屏，短距离拉动会平滑回弹。
- 竖屏全屏使用独立展示状态并锁定竖向；播放器控制层按既有 2 秒计时自动隐藏，底部恢复提示在 3 秒后淡出，稳定画面只留下直播与画面弹幕。
- 屏幕底部上滑可恢复弹幕栏；顶部返回、双击退出与 Android 系统侧滑返回仍然有效，首次返回只退出展示层，不离开直播间。

## 状态加固与回归

- 重复拖动只允许一个进入请求；进入期间若识别失效、设置变化或系统返回，立即回收沉浸状态与方向锁，不残留隐藏系统栏。
- 新增距离/速度阈值、短拉回弹、普通直播隔离、提示淡出、全屏状态以及竖屏识别稳定性回归。
- Android arm64 正式交付执行完整静态分析、完整 Flutter 测试、APK 内容检查和连接设备实机验证；Windows 通过共享布局与状态回归确认无移动端入口。

---

# Pure Live v3.0.21

v3.0.21 build 4109 修复分类页顶部标签左右拖动没有明确边界的问题，并把同类平台、筛选与分页导航统一到同一套有界滚动行为。本轮只更新 Android `arm64-v8a`；Windows 继续使用 v3.0.19 稳定安装版与便携版。

## 分类与导航边界

- 分类页的一级平台栏、二级分类栏和对应页面都使用硬边界：到达第一项或最后一项后不再产生额外位移，标签内容动态缩短时旧偏移会立即夹回新范围。
- 分类页外层平台通过顶部标签切换，内层分类保留左右页面手势，消除两个同方向分页容器同时争抢一次拖动造成的卡住和方向跳变。
- 热门、关注、收藏分区、搜索平台、搜索筛选、WebDAV 路径、直播间分页与播放器横向控制条同步使用相同规则，避免同一种交互在不同页面表现不一致。
- 关注页“直播中/录制中/未开播”固定为三等分标签，不再创建没有必要的横向滚动范围；录制中心任务列表复用公共边界实现。

## 左右与上下滑动流畅度

- 分类数据首次进入页面时已经完整加载；切换分类改为同步选择本地数据切片，不再重新进入异步加载入口，减少标签、页面和网格分帧更新造成的顿挫。
- 分类、热门与关注的页面切换动画统一为 220 ms；普通内容列表保持 Android 原生 Clamping 滚动和 Flutter 快速滑动延迟解码策略。
- Android 搜索结果移除维护分支误加的 iOS 弹性滚动，恢复与其他纵向列表一致的有界行为；网格继续使用懒构建、重绘隔离和有限缓存范围。

## 回归

- 新增横向标签首尾、分页首尾、标签数量缩短以及分类本地同步切换回归。
- 分类、搜索、关注标签与录制列表定向测试通过；正式 APK 继续执行完整静态分析、完整测试和公开平台接口探测。

---

# Pure Live v3.0.20

v3.0.20 build 4108 将 v3.0.19 Android APK 发布之后完成的移动端修复正式交付到 `arm64-v8a`。本轮只更新 Android；Windows 继续使用已完成完整回归的 v3.0.19 安装版与便携版。

## 返回、小窗与直播会话

- Android 预测性返回由原生 `OnBackInvokedDispatcher` 与 Flutter 路由状态共同管理：普通直播页返回首页，横屏/全屏先退出展示层，弹窗先关闭弹窗，小窗交接不提前清理播放器与弹幕会话。
- 直播间返回、重新进入和小窗恢复使用显式会话交接令牌；旧路由的迟到回调不会清理新页面正在使用的播放器、尺寸或弹幕连接。
- 普通退出仍关闭当前播放源；没有播放、小窗或画中画会话时，播放器在空闲宽限后释放原生纹理、解码线程和网络资源。

## 弹幕与本地互动

- 同一直播间切换画质、线路或播放器内核时，本地弹幕队列继续按房间身份交付，不再因内部加载代次变化丢失。
- 弹幕列表第一次明确上滑即暂停自动跟随；程序滚动、小窗恢复产生的视口通知不会误触发阅读暂停，回到最新后再恢复实时跟随。
- 播放器控制条区域与画面弹幕点击/长按命中分离，减少小窗、耳机、画质和全屏入口与弹幕操作冲突。

## 录制与启动稳定性

- 录制统计过滤 MPEG-TS 源时间戳与 `INT32_MAX` 哨兵，时长按真实会话墙钟夹持；旧任务中已经持久化的异常超大计数在恢复时迁移。
- 录制重连继续累计真实时长、文件大小、码率与速度，Android 安装脚本在 ADB 多设备环境中要求明确目标，避免把测试包装到错误设备。
- IPTV、设置服务与播放器初始化采用唯一生命周期所有者和按需启动，减少普通启动阶段的重复控制器与后台资源工作。

---

# Pure Live v3.0.19

v3.0.19 build 4107 以用户实际回归暴露的问题为准，修正 v3.0.18 仍存在的随机暂停、录制进度不可见与录制中心拖动越界。首批已发布 Android `arm64-v8a` Release APK；同版本稳定版现补充 Windows x64 可选目录安装包与便携 ZIP。已恢复正常的竖屏画面几何不再改动。

## 播放连续性

- 找到缓冲事件的顺序竞争：原生播放器经常先报告 `buffering=true`、随后才报告 `playing=false`，旧监督器在第一次事件仍看到旧播放状态，第二次事件又因页面已是缓冲态而跳过，最终没有恢复计时器。现在以第二个权威状态重新挂载缓冲看门狗，持续卡住时进入现有线路/内核恢复。
- Android 旋转、Surface 替换和进入小窗产生的短暂 `hidden/paused` 合并为 1.5 秒生命周期窗口；应用内小窗继续视为可见播放载体，避免切换过程中被后台策略误暂停。
- 用户主动暂停、系统音频中断与真正进入后台仍使用独立意图令牌，不会被连续性监督器误恢复。

## 录制与实时统计

- 斗鱼当前 H5 响应若在 `rtmp_live` 直接返回完整签名地址，优先采用该地址；避免再次拼接 CDN 基址而形成 `.../https://...` 的错误 FFmpeg 输入。
- 录制卡片从“准备中”开始就显示 `00:00 / 0 B / 码率 / 速度`，每秒把 FFmpeg 原生统计与磁盘 TS 分片取较大值，不再因 segment muxer 报零而隐藏整个统计区域。
- 分片跟踪器可发现恢复后首个编号不是 `000000` 的文件，之后继续使用固定成本的顺序采样；签名刷新后的会话累计值保持单调。

## 录制中心边界

- “全部/录制中/等待开播”等九个状态改为固定自适应网格，不再嵌套可横向拖动的标签栏和分页视图；状态只通过明确点击切换。
- 任务列表持有独立控制器与硬边界物理效果；筛选或删除任务导致列表缩短时，在布局完成后立即把旧偏移夹回有效范围。
- 新增生命周期竞争、缓冲事件顺序、斗鱼完整地址、非零首分片、固定状态选择器及列表缩短边界回归。

## Windows x64 稳定版

- 普通启动不再提前初始化 FFmpeg，也不会在用户尚未进入 IPTV 时下载并导入内置 M3U/EPG；设置服务与 IPTV 控制器采用唯一生命周期所有者，避免冷启动重入和重复后台任务。
- 普通直播页退出会关闭当前播放源；软停止保留 45 秒快速重开窗口，之后在没有播放、小窗或画中画会话时完整释放原生播放器、纹理、线程和网络资源。
- 修复普通直播间按 `Escape` 误入全屏后又因事件无人消费而留在房间的问题；普通房间现在明确返回上一页，全屏 `Escape` 只退出当前展示层，不提前销毁播放器或弹幕会话。
- 录制统计过滤 MPEG-TS 源 PTS/哨兵值，恢复后时长、大小、码率和速度继续单调累计；录制中心九状态与任务列表保持有界滚动。
- 同房间画质、线路或播放器重载不再取消排队中的本地弹幕；弹幕列表首次鼠标滚轮上移即停留阅读，只有明确回到最新才恢复跟随。
- Windows 播放器控制条上下 56 px 与画面弹幕点击/长按分离，避免耳机、小窗、画质和全屏入口被误解释为弹幕操作。
- 正式交付包含 `PureLive-3.0.19-4107-windows-x64-setup.exe` 与 `PureLive-3.0.19-4107-windows-x64-portable.zip`；安装目录可选择非系统盘，升级保留安装目录 `AppData` 中的关注、设置、历史、IPTV 与录制数据。

---

# Pure Live v3.0.18

v3.0.18 build 4106 用 Android 真机证据替代 v3.0.17 仅依赖确定性测试的播放与录制结论。本轮正式产物覆盖 Android `arm64-v8a` Release APK、Windows x64 便携包与可选目录安装程序；已经正常的竖屏画面几何保持冻结。

## 播放连续性

- 默认关闭 MediaKit 自动截图内容探测。该探测曾在首帧后的多个时间点反复截图，在 ColorOS/Qualcomm 硬解路径会短暂分离 Surface，随后出现解码丢帧、画面停止并触发恢复，外观就是直播随机暂停或重载。
- 方向判定继续使用解码宽高、平台几何提示、稳定房间快照和手动覆盖；主动内容探测保留为显式诊断选项，不再参与普通播放默认路径。
- 移动端应用内小窗的首个点击先显示暂停/关闭控件，第二次点击才返回直播间，避免控件三秒隐藏后每次点击都直接重开页面。

## 录制连续性与实时统计

- 虎牙 FLV/HLS 地址不再复用房间详情中已计算的 `wsSecret`。播放器和录制器分别以主播 UID、当前时间与独立序列号重新签名，修复播放连接占用后第二条录制连接返回 403 的问题。
- 直播录制进程正常返回 EOF、`AVERROR_EOF` 或短时 403 时刷新签名 URL 并按 2–15 秒有界退避继续；这类短连接恢复不会落入分钟级等待开播，也不会在普通重试次数后提前结束任务。
- 多次连接尝试之间累计已写字节与时长；界面持续显示会话总大小、实时码率和速度，不再在刷新线路后归零。视频整理时限由固定 5 秒调整为按素材时长扩展的 30–3600 秒。

## 真机验证

- 虎牙录制运行 6 分 13 秒，累计约 60 MB；服务器约 119 秒断开后自动刷新三次签名，三个 MP4 分片均为 H.264 1080p60 + AAC。
- 斗鱼原画 1080p60 录制 3 分 05 秒，实时卡片显示 154.25 MB / 8.4 Mbps，最终 MP4 为 171,171,384 字节并通过 ffprobe。
- 录制中心状态标签左右首尾、状态页首尾和短任务列表上下边界均经真机反复拖动，未再越界；播放稳定窗口内未观察到播放器停止、ANR 或解码故障。
- 这些证据覆盖当前虎牙与斗鱼样本；其他平台仍由录制合同与公开接口探针覆盖，不把两个样本描述为十个平台全部实录。

## Windows x64

- 锁定依赖后 Windows 构建使用 `--no-pub`，避免长路径目录联接下重复刷新插件符号链接；Debug 与 Release 包装分别读取对应 CMake install manifest。
- 安装程序覆盖升级时仅清理可替换的 `data`、根目录 DLL 与链接器文件，`AppData` 继续保留关注、设置、历史、IPTV 和录制数据。
- Windows 播放、弹幕、录制、搜索、滚轮平滑、全屏/小窗、多实例和升级迁移完成专项回归与真实 Win11 客户端巡检。
- 修正原生播放器短暂上报 `paused` 时覆盖直播连续性状态的问题；直播仍由页面持有时保持缓冲/恢复语义，用户主动暂停仍立即生效。
- 录制卡片在停止或完成后保留真实时长与文件大小；Win11 实录验证中统计从 `24.50 MB` 持续增长到 `45.25 MB`，生成的 1440p60 H.264/AAC MP4 通过 ffprobe。
- 录制中心九个状态固定在自适应网格，任务列表严格夹持首尾；关闭首页、直播页和录制中心时均以退出码 0 结束，未捕获未处理异常。
- Windows Runner 在派生类成员销毁前主动拆除 Flutter 子窗口，并屏蔽拆除期间的重入消息，消除退出时 `flutter_windows.dll` 访问冲突。

---

# Pure Live v3.0.17

v3.0.17 build 4105 重新验证并替代 v3.0.16 对播放器连续性和录制中心稳定性的结论。本轮正式产物仅为 Android `arm64-v8a` Release APK；竖屏画面比例链路保持冻结。

## 直播连续性

- 播放器现在分别记录用户播放意图、应用生命周期暂停和系统音频中断。来电、通知、拔耳机、通知栏播放/暂停/停止不再绕过 `PlayerManager` 直接改变原生播放器。
- 直播源无加载、无显式暂停时出现意外 `playing=false`，先在当前来源原位恢复；仍未恢复才进入既有线路和播放器内核回退。直播异常 EOF 使用同一恢复链路，回放及时移仍可自然结束。
- 每次恢复都绑定来源 session 和用户意图代次；用户主动暂停、停止、切换房间后，旧生命周期或音频焦点令牌不会重新播放旧来源。

## 录制真实性与实时统计

- FFmpeg native session 注册只进入“准备中”；首个有效媒体统计或实际 TS 分片字节出现后才显示“录制中”，输入打开失败不再短暂伪装为正在录制。
- segment muxer 常见的 `statistics.size=0/N/A` 不再覆盖界面。录制器直接跟踪当前 `%06d.ts` 分片的真实磁盘字节，并据相邻样本计算实时码率、提供录制时长后备。
- 分片跟踪每秒只检查当前和下一文件，长时间录制保持固定采样成本；界面每秒更新，任务持久化按十秒节流，减少磁盘写入和 CPU 占用。
- FFmpeg 正数统计按单调值合并，空统计不会把已经显示的大小、码率、速度或帧率清零；既有严格房间、按需清晰度/线路、签名 URL 刷新与错误分类继续保留。

## 录制中心与验证

- “全部/录制中/等待开播”等顶部状态标签、左右状态页和纵向任务列表统一关闭越界效果并使用 Clamping 边界；首尾位置不再继续拖动。
- 新增意外暂停、用户暂停、音频中断令牌、直播 EOF、增量分片大小和横纵滚动边界回归；既有播放器、音频模式、生命周期及十个平台录制合同继续纳入门禁。
- 完整根因、来源分类、证据边界和发布条件记录在 `docs/BUG_AUDIT_2026_08_28_PLAYBACK_RECORDER.md`。本轮遵循源码与确定性测试流程，不操作手机或 ADB。

---

# Pure Live v3.0.16

v3.0.16 build 4104 是播放器生命周期、Android Surface/画面几何和十个平台录制链路的稳定修正版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 播放器与 Android 画面

- 页面、播放器管理器和后端适配器不再同时决定前后台暂停/恢复；生命周期意图集中到单一协调器，音频模式、助眠、后台播放和普通视频分别执行明确策略。
- 来源打开和播放器内核切换采用代次隔离与事务提交。旧来源的晚到事件不会覆盖当前状态，失败切换保留旧内核，成功后才释放旧资源。
- Android `SurfaceProducer` 变化按每个 renderer 的 Surface 生命周期处理，视频纹理在录制页等覆盖场景保持挂载；仅在强竖屏提示与横屏画布冲突时启动主动帧探测，避免普通直播常驻截图和 CPU 开销。
- 成对视频宽高成为几何事实来源，普通竖屏、横屏全屏、应用小窗和系统 PiP 共享同一几何快照，普通横屏直播不受竖屏识别路径影响。

## 录制根因修复

- 斗鱼 H5 响应中的 `rtmp_url/flv_url` 可能只是 CDN 基础目录，旧代码因其是合法 HTTPS 地址而提前返回，FFmpeg 最终报告输入地址格式错误。本版本先与 `rtmp_live` 拼成实际媒体地址，裸目录不再进入录制内核。
- 旧录制器在启动 FFmpeg 前顺序获取全部清晰度和全部 CDN，延迟首字节并让先取得的短时签名 URL 提前老化。现在首次只解析首选清晰度和当前线路；失败后按“同档下一线路 → 下一清晰度首线路 → 刷新首线路”推进。
- 斗鱼、虎牙增加单线路录制游标，每次只签名本次真正使用的一条 CDN；哔哩哔哩、抖音、快手、CC、Twitch、SOOP、YY 和 IPTV 继续使用各自一次响应或本地候选合同。
- `Error opening input ... Invalid argument` 进入可恢复输入分类并刷新平台 URL；只有明确选项解析、协议/复用器缺失和本地输出权限错误停止重试。
- 任务 schema 升级到 4，只保存清晰度 ID 与线路索引，不保存签名 URL。录制中心保持卡片原位置，准备/重连阶段不再显示伪造的 `0 B / 0.0x / 0M` 数据，真实码率按 kbps/Mbps 显示并移除常驻无界进度动画。

## 上游、依赖与验证

- 逐项审查并记录上游 `e696bb79` 与 `9b1c0a6e`。版本回退、FFmpegKit 降级和发布索引覆盖没有进入维护分支；已接受的祖先关系与兼容意图保留在审计文档。
- FFmpegKit 继续锁定已校验的 `0.5.13` / builder `0.10.5` / FFmpeg 8.1.2 组合；本地构建包装器会跳过损坏的 Git 可执行文件，并支持锁文件离线缓存验证。
- 确定性回归覆盖播放器事件/内核/Surface/几何、十个平台画质和录制合同、斗鱼/虎牙单线路游标、FFmpeg 参数与错误分类、任务迁移和录制存储边界。本轮不连接或操作手机。

---

# Pure Live v3.0.15

v3.0.15 build 4103 是 Android 播放器回归修正版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。v3.0.14 的播放器恢复设计已由本版本替代。

## 根因与修复

- v3.0.14 将 libmpv 的原生 `path` 精确字符串、可选首帧属性和公共 `playing` 状态错误地串成硬门槛。CDN 重定向、协议重写、Android 后端未提供首帧属性或事件在 `open` 期间先到时，正常直播会被判定为未播放。
- 原生 `playing=true` 重新成为播放状态的唯一权威；首帧和解码属性只保留为诊断证据，不再阻断画面、加载完成或管理器状态。
- 来源代次仍在新流打开期间隔离旧回调，但打开完成后不再要求 URL 字符串完全一致。重定向 URL 和没有原生 path 回调的来源均可继续发布当前尺寸与播放事件。
- 下线适配器 10 秒与管理器 12 秒两套推测式“无首帧即失败”计时器。只有明确的打开异常或原生故障进入线路/内核恢复，避免正常缓冲中的直播被自动重开、表现为暂停或黑屏。
- 新来源完成打开后立即回读原生播放状态和成对视频尺寸，恢复竖屏、横屏、全屏与小窗共享的当前来源几何链路。

## 验证范围

- 回归覆盖原生路径被 CDN 改写、完全没有 path 回调、缺少可选 mpv 首帧属性、默认策略不推测重开慢流、当前来源 `720×1280` 尺寸进入竖屏几何，以及既有音频模式、全屏和小窗状态机。
- 本轮不连接或操作手机；自动化与本机构建证据和设备安装后的实际样本分层记录。

---

# Pure Live v3.0.14

v3.0.14 build 4102 是 Android 播放器来源隔离、解码恢复与录制故障分层修正版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 根因修复

- 原播放器把 libmpv 的日志字符串直接当成终止错误，并让页面、适配器和管理器同时改变播放状态；旧 URL 的晚到回调、同步打开失败和新的来源代次因此会互相覆盖。本轮建立单一恢复所有权、来源代次栅栏和稳定错误代码。
- 修复同一 URL 软件解码重试被适配器提前返回的确定性错误：管理器已经清空新来源状态，适配器却没有重新打开流，最终表现为黑屏、加载不结束或“解码回退无效”。
- 原生打开、首个可播放帧、线路轮换、软件解码和播放器内核切换现在分别有明确边界；硬件视频解码失败只重开一次软件解码，音频解码错误不会误走视频回退，全部策略耗尽后才向页面发布一次最终错误。
- MediaKit 以原生 `path` 和真实解码帧信号确认当前来源；Fijk/BetterPlayer 在打开前接管同步错误；播放器监听在打开前绑定。初始化、内核替换和小窗清理都采用有界、可回滚生命周期。

## 录制与诊断增强

- 录制重试不再只轮换当前清晰度的一组 URL，而是收集全部可用清晰度与 CDN 候选；刷新后的签名 URL 按稳定线路身份去重和轮换。
- FFmpeg 错误分为输出目录、命令参数、HTTP 权限、传输、输入打开、输入格式、解码和原生故障；任务页显示脱敏后的实际阶段，只有可恢复类别进入下一线路/清晰度。
- FFmpegKit 原生包使用受校验的固定版本配置，Dart 包版本、构建器版本与 Android/Windows 原生归档 SHA-256 必须匹配，避免同一应用源码混入另一套二进制。

## 验证范围

- 确定性回归覆盖同 URL 软件解码重开、音视频错误分流、旧来源回调隔离、打开与首帧超时、连续线路/内核降级、同步打开失败、小窗回切和录制候选/错误分类。
- 完整静态分析、全量 Flutter 回归、公开接口探测、仓库审计和 Android arm64 APK 内容/签名核验随 Release 保存；本轮不操作手机。硬件厂商解码器、地区/登录 CDN 和直播源本身损坏仍属于运行环境差异，应用会按上述状态机回退并给出最终可诊断错误。

---

# Pure Live v3.0.13

v3.0.13 build 4101 是 Android 录制启动与十个平台录制契约修正版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 根因修复

- 恢复 Android 启动阶段非阻塞预热 FFmpegKit；录制入口等待同一幂等初始化，关闭首次点击录制时原生库尚未就绪的 I/O 失败窗口。桌面端仍保留延迟预热。
- 旧录制器把 UI 为保留画面而生成的“离线占位房间”当成权威状态，接口短暂失败时会在取得画质和 URL 之前终止。本轮为十个平台全部增加严格、包含播放字段的录制房间解析；网络/结构错误进入有界重试，明确下播/封禁才停止。
- FFmpegKit 改用原始参数向量，签名 URL、CRLF 请求头、Cookie 和含空格存储目录不再经过命令字符串二次解析。

## 十个平台与可诊断性

- 逐一核对哔哩哔哩、斗鱼、虎牙、抖音、快手、网易 CC、Twitch、SOOP、YY、IPTV/自定义源的房间状态、画质、线路、URL、请求头和协议；兼容关键状态字段的字符串/数字漂移。
- SOOP 签名失败不再静默返回空 URL；快手只在真实存在回放流时使用当前房间回退；虎牙只把明确 OFF/OFFLINE/CLOSED 判为下播；SRT 加入可录制协议。
- 立即录制只提交一次启动意图；任务页新增房间、画质、线路、网络、FFmpeg、合并、调度等脱敏失败阶段，完整签名 URL 和凭据不会持久化。
- Android 最低系统版本对齐 FFmpegKit 依赖要求 API 26，避免在原生录制库不支持的系统上生成“可安装但录制失败”的包。

## 验证范围

- 确定性回归覆盖十个平台严格录制能力、房间错误分类、FFmpeg 参数向量、请求头/URL/空格路径、启动策略、错误脱敏、任务迁移和既有录制生命周期。
- 完整静态分析、全量 Flutter 回归、九个网络平台公开接口探测、仓库审计与 Android arm64 APK 内容/正式签名核验随 Release 保存；本轮不操作手机，用户 IPTV、付费/登录和地区限制房间保留环境差异。

---

# Pure Live v3.0.12

v3.0.12 build 4100 是 Android 录制稳定性与全平台画质契约修正版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 全平台画质准确性

- 哔哩哔哩、斗鱼、虎牙、抖音、快手、网易 CC、Twitch、SOOP、YY 与 IPTV 的显示名称、排序、稳定请求 ID 和实际 URL 归属统一核对；UI 中文名与平台接口参数彻底分离。
- 抖音兼容新旧 SDK 档位：`ORIGION/origin→原画`、`FULL_HD1/uhd→蓝光`、`HD1/hd→超清`、`SD2/sd→高清`、`SD1/ld→标清`、`MD/md→流畅`；补齐 `sdk_params`，并去除指向同一 URL 的伪重复档位。
- 哔哩哔哩回读服务端实际 `current_qn`；斗鱼保留不透明 `rate` 的服务端顺序；虎牙正确替换或移除 `ratio`；SOOP 始终发送原始 preset；CC、Twitch、SOOP 在源流缺码率时仍保持原画优先。
- 快手合并同画质多 CDN 并优先兼容 AVC，YY 保留真实 gear 并在匿名 StreamManager 失败时回退实际可用移动 HLS，IPTV 不制造不存在的多码率选项。

## 录制稳定性与完整性

- 每次尝试重新获取房间、画质和签名 URL；失败后轮换 CDN，HTTP/RTSP/UDP/RTMP 使用各自适用的 FFmpeg 参数，403/404 交给上层刷新而不是无限重试旧地址。
- FFmpeg 事件增加 session 代次，旧回调不再覆盖新任务；取消、停止、自动重连、下播轮询和恢复使用同一生命周期栅栏及有界退避。
- 分片使用毫秒级尝试前缀；普通重试只合并本次 TS，旧版无前缀分片仅在明确的崩溃恢复中迁移。MP4 先写 `.partial`，成功后原子提交并删除源片段，失败保留 TS。
- 活跃录制目录改为引用计数保护，清理和容量限制不再误删并发任务；签名 CDN URL 不写入本地任务配置，日志中的 URL、Cookie、Authorization 和 token 会脱敏。
- 录制缓存扫描改为有限快照与异步文件操作，进度更新不重排整个任务列表，轮询不重入，关闭时取消计时器与后台任务。

## 验证范围

- 确定性回归覆盖十个平台画质解析/排序/真实请求、播放与录制请求头、FFmpeg 命令、调度取消、任务迁移、重连策略、缓存保护、分片隔离和 concat 清单。
- 完整静态分析、全量 Flutter 回归、公开接口探测、仓库审计与 Android arm64 APK 内容/签名核验随 Release 保存；本轮不操作手机。

---

# Pure Live v3.0.11

v3.0.11 build 4099 是 Android 播放比例跨模式隔离修正版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。版本号跳过 3.0.10，使安装过错误候选包的设备也能按更高 `versionCode` 正常升级。

## 错误版本清理

- 3.0.10 的草稿 Release 与远端/本地标签已经删除；它没有进入稳定 Release 列表。
- `master` 先回滚到 v3.0.9 的稳定播放器合同，再从该基线实现隔离修复；错误提交仍保留在 Git 历史中，便于审计与回归归因。

## 根因与修复

- 来源归类为 `fork-regression`。3.0.10 将横屏全屏里的竖屏 `contain` 作为 `fitOverride` 一路传到共用播放器适配器；普通页、全屏、小窗在路由切换期间会短暂共用一个原生播放器与控制器。
- MediaKit/Fijk 的 Widget 创建会回写 `_videoFit`，BetterPlayer 会进一步调用共享 Controller 的 `setOverriddenFit`；多个呈现树的重建顺序形成“最后写入者生效”，全屏比例因此泄漏到普通竖屏、小窗和普通横屏。
- v3.0.11 不扩展 `UnifiedPlayer` 或各适配器合同，也不写入特殊 `BoxFit`。只有横屏全屏路由把**解码视频图层**置于可信节目比例的居中 `AspectRatio` 视口，弹幕与控制层仍覆盖整屏。
- 普通竖屏、普通横屏、应用内小窗与 Android PiP 不传入该局部视口，继续使用 v3.0.9 已验证的原生单层缩放路径。
- 竖屏全屏背景按房间封面、房间头像顺序回退，并提供暗色渐变兜底；背景只做低成本静态模糊，不复制视频解码。

## 回归与交付

- 新增同一共享播放器从“竖屏横屏全屏”回到普通页的 Widget 回归：核对 9:16 视频视口、1280×720 整屏控制层，以及用户选择的 `fill` 在全部重建中保持不变。
- 覆盖普通横屏、直接竖屏、实测黑边、普通直播页、应用小窗、PiP、音频模式和播放器生命周期；本轮按仓库策略不操作手机。
- 完整静态分析、全量 Flutter 回归、接口探测、仓库审计与 APK 内容/正式签名核验记录随 Release 保存。

---

# Pure Live v3.0.9

v3.0.9 build 4097 是 Android 竖屏原生渲染链修正版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 已确认的根因

- 实际抖音竖屏样本由解码器输出 HEVC `1088×1920`，首帧本身是完整 9:16 画面；异常窄条来自应用渲染链，而不是该直播源的编码比例。
- 首个错误状态由维护分支提交 `6f50a445` 引入：播放器管理层为移动端增加外层比例 `FittedBox` 并把原生播放器设为 `fill`，而 MediaKit、Fijk 与 BetterPlayer 内部原本就拥有纹理比例和缩放。外层旧 16:9 快照与内层新 9:16 纹理跨帧组合后，比例被重复应用。
- v3.0.8 又允许仅含宽高、没有像素坐标的平台提示生成临时对称裁边；晚到的旧解码事件可让直接竖屏纹理再被裁一次，同一错误随后传播到普通页、横屏全屏、应用内小窗与系统 PiP。

## 抖音官方模型与修复

- 按抖音官方模型将源 `orientation`、容器 `object-fit`、全屏 `direction` 与分辨率变化拆为独立状态；源方向只用于分类，不再同时承担缩放、裁边或屏幕旋转。
- 普通帧把当前 `BoxFit` 直接交给原生 Video Widget，移除移动端外层比例视口；只有两次一致的真实帧像素证据确认黑边后，才建立一次“原生 fill → 实测裁边 → 最终 fit”的特殊路径。
- 选中 URL 对应的流级分辨率只用于首帧前分类；首个合理的解码 `dw/dh + rotation` 成为纹理事实来源。平台元数据只在解码比例超出系统合理范围时参与纠错。
- 普通竖屏页、横屏全屏、应用内小窗与 Android PiP 统一读取不可变 `VideoPresentationGeometry`；横屏源继续使用原生实际比例，三套已设计界面不再各自解释画布。

## 回归与交付

- 新增等价模拟 MediaKit 内部固有纹理比例和 `FittedBox` 的 Widget 回归，直接覆盖“管理器仍为 16:9、原生纹理已为 9:16”的真实事件顺序。
- 覆盖直接竖屏、横屏画布、实测黑边、错误平台提示、线路/清晰度换代、普通页、横屏全屏、应用小窗、PiP 和播放器生命周期；本轮不操作手机。
- 完整静态分析、全量 Flutter 回归、接口探测、仓库审计与 APK 内容/签名核验记录随正式产物保存。

---

# Pure Live v3.0.8

v3.0.8 build 4096 是 Android 竖屏直播与小窗比例修正版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 根因与选中流识别

- 修正抖音元数据契约：`stream_orientation` 是普通/双画面流选择标志，并非横竖屏枚举；顶层 `extra.width/height` 也可能是音频占位尺寸，不再据此改变画面。
- 几何解析改为把当前实际播放 URL 关联到同一个 `sdk_key`，读取该流的 `sdk_params.resolution` 或清晰度分辨率；关联失败时保持未知，不借用默认线路误裁当前画面。
- 精确选中流可以在 Android 截图暂时缺席时建立一组比例一致、可被真实帧证据撤销的居中裁边，避免 16:9 传输画布中的 9:16 节目长期显示成窄条。

## 竖屏、小窗与 PiP

- 应用内小窗不再冻结创建时的 16:9 外框；晚到的解码/视觉证据会同时更新视频与窗口尺寸，竖屏流形成随源比例的竖长小窗。
- Android PiP 先完成紧凑视频 Surface 布局，再从真实可见视频区域生成 `sourceRectHint`，使进入动画、窗口比例和画面内容使用同一几何。
- 两次一致的全帧证据可清除过期平台提示和 provisional 裁边；普通横屏、直接竖屏、清晰度与线路换代继续经过保护门禁。

## 验证与交付

- 覆盖选中 URL 键控、占位字段隔离、关联失败保护、可逆裁边、晚到小窗比例和 PiP 可视矩形测试。
- 本轮保持上游冻结、不操作手机；完整质量门禁后串行构建 Android `arm64-v8a` Release，并核验版本、包名、ABI、关键资源、原生库和 SHA-256。

---

# Pure Live v3.0.7

v3.0.7 build 4095 是 Android 竖屏真实画布与横屏全屏入口修正版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 根因与画面比例

- 根因不是单纯“识别不到竖屏”，而是平台声明、解码元数据和截图裁边使用了不同坐标系：旧实现把截图边界套到解码器比例，又会依据平台方向虚构对称黑边，最后把原生纹理按呈现比例强制改宽，叠加后形成细条、拉伸或错误裁切。
- 截图观测现在同时保存截图画布比例与有效内容边界；两次一致证据提交后，由这一组原子证据统一计算节目比例，异常或过期的解码宽高不再污染裁边。
- 平台元数据继续用于快速方向提示，但不生成裁剪坐标；原生纹理始终保持真实画布比例，只有实测黑边才建立裁剪视口。

## 竖屏、横屏与小窗

- 普通竖屏页在可拖动弹幕面板上方增加始终可见的“横屏全屏”入口，解决原播放器底部控件被互动面板覆盖的问题。
- 横屏全屏是一项单次操作：直接进入沉浸式横屏，同时保留用户原有的“跟随直播源 / 跟随系统 / 始终横屏”长期设置。
- 普通页、横屏全屏、系统 PiP 和应用内小窗读取同一有效节目比例与同一裁边结果；普通横屏源继续沿用原路径。

## 参考审查与回归

- 审查 `chen-zeong/dtv_mobile` 的 Media3 实现，吸收“原子视频尺寸、单一缩放所有者、显式全屏状态”的设计思想；其竖屏源会隐藏全屏按钮，因此没有照搬该行为。
- 覆盖截图画布与解码元数据冲突、实测黑边、全帧纠错、平台提示不推导裁边、原生纹理防拉伸以及竖屏页显式横屏入口。
- 本轮保持上游冻结、不操作手机；完整质量门禁后串行构建 Android `arm64-v8a` Release，并核验版本、包名、ABI、关键资源、原生库和 SHA-256。

---

# Pure Live v3.0.6

v3.0.6 build 4094 是 Android 竖屏几何仲裁修正版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 根因修复

- 修复 v3.0.5 的渲染契约漏洞：外层已把异常比例回退到 9:16 后，内部仍会套用旧裁边并重新算出约 0.18 的超窄视口；现在裁边结果必须与最终呈现比例一致，否则在纹理边界直接丢弃。
- 线路、清晰度、重连等同房间新 URL 都会清除上一解码画布的裁边；短时缓存只携带最终有效比例，不再跨代复用黑边坐标。
- 已经是竖屏的解码画布拒绝再次裁左右边，避免主播画面在普通竖屏页、横屏全屏和小窗同时被二次压窄。

## 抖音识别与证据仲裁

- 新增抖音 `stream_url.extra.width/height`、默认清晰度 `resolution`、`stream_data.main.sdk_params` 与候选分辨率解析；平台声明比例、解码画布比例、有效内容裁边和最终呈现比例各自保存。
- 强平台证据可修正异常采样宽高，也可为“横屏传输画布内嵌竖屏节目”推导对称裁边；两次可靠全帧结果仍可纠正过期或冲突的平台声明。
- 截图检测改为 500 ms 起的最多六次有界采样；空首帧、转场或一次不一致不会提前结束，得到两次一致证据后立即停止，稳态不运行持续检测。

## 回归与交付

- 新增直接竖屏防二次裁边、清晰度换代、平台比例修正、元数据解析、冲突回退、隐式柱状黑边及渲染末端门禁回归。
- 本轮不合并上游、不操作手机；完整质量门禁通过后串行构建 Android `arm64-v8a` Release，并核验包名、版本、ABI、资源、原生库和 SHA-256。

---

# Pure Live v3.0.5

v3.0.5 build 4093 是 Android 有效画面识别与竖屏三模式增强版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 有效画面识别

- 将编码画布与有效节目区域分离：继续原子读取解码 `dw/dh` 和旋转，同时用两张低分辨率帧验证左右/上下对称黑边、中心活跃度与一致性。
- 修复 16:9 编码画布内嵌 9:16 节目时仍按横屏识别的问题；先裁掉编码黑边，再执行唯一一层 contain/cover/fill，画面不再被横向压缩或直接拉伸。
- 房间、线路和清晰度切换使用独立几何代际；短时房间缓存减少重进跳变，暗场、转场与低置信证据保持原比例。

## 竖屏页、横屏和小窗

- 普通竖屏页新增收起/中间/展开三档互动面板，面板把手与弹幕列表滚动手势分离，视频可利用更完整的手机画布。
- 横屏全屏保持竖屏节目居中，并使用缓存封面的模糊暗化背景填充两侧；控制层仍覆盖整个屏幕。
- Android 系统 PiP 在稳定比例变化时更新活动窗口参数；应用内小窗同步跟随有效竖屏比例。
- 普通横屏、方形与未知源继续沿用既有页面、全屏和 16:9 小窗合同。

## 回归与构建范围

- `flutter analyze` 0 问题，27 项定向几何、裁边与布局测试通过；正式构建前继续执行完整回归。
- 本轮不合并上游、不连接手机，只串行构建 Android `arm64-v8a` Release，并核验版本、包名、ABI、资源、原生库和 SHA-256。

---

# Pure Live v3.0.4

v3.0.4 build 4092 是 Android 移动画面比例与历史记录增强版。本轮只构建 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 普通页、全屏与小窗统一比例

- 修正 v3.0.3 仍存在的多层比例控制：移动端由播放器管理层提供唯一可信显示比例，MediaKit/Fijk 只在受控画框内填充，避免外层布局、适配器和原生纹理各自缩放。
- 普通横屏源保持可信横屏比例，稳定竖屏源保持可信竖屏比例；缺失、瞬态或异常解码尺寸按展示方向回退到安全比例，避免普通直播被误压成细条。
- 普通竖屏页面、横屏全屏、系统画中画和应用内小窗复用同一比例解析结果，房间、线路、清晰度和展示模式切换不会各自形成不同画面几何。

## 历史记录与上游整合

- 直播记录显示完整本地日期与时间，容量支持任意正整数；`0` 表示长期保留全部记录，升级、备份和恢复使用同一裁剪语义。
- 同步并审查上游到 `liuchuancong/pure_live@c7d99cc3`，吸收录制目录与权限检查，保留经过回归的系统返回、FFmpeg 延迟预热和 HTTPS 校验策略。
- 修正 Windows 长路径下 Flutter 测试与原生资源 Hook 的执行路径，质量脚本稳定复用短路径映射并记录实际测试参数。
- 固化 Bug 修复默认交付闭环：每个完成的修复批次递增补丁版本，在本机构建 Android arm64 Release，再用 GitHub Secrets 短时正式签名，并同步源码、标签、APK、校验文件和发布索引。

## 回归与构建范围

- 覆盖横屏、竖屏、近方形、异常比例、手动覆盖、普通页、全屏、画中画、应用内小窗、历史日期和无限容量回归。
- 正式构建执行完整 Analyze、自动化测试与仓库门禁，随后只构建 Android `arm64-v8a` Release 并核对包名、版本、ABI、关键资源、原生库和 SHA-256。

---

# Pure Live v3.0.3

v3.0.3 build 4091 是 Android 竖屏 Surface 比例与横屏直播记录布局修正版。本轮目标为 `arm64-v8a` Release APK；其他平台继续使用既有安装包。

## 竖屏画面与切换稳定性

- 修复 Android 原生 Surface 将缺失旋转元数据误判为 90/270 度、把已经是竖屏的尺寸再次交换的问题；普通页、横屏全屏、系统画中画和应用内小窗不再共同出现横向压窄。
- 将 MediaKit 应用层识别和 Android Surface 统一到同一个显示尺寸解析器：优先使用完整 `dw/dh`，否则回退完整 `w/h`；旋转归一化后只交换一次。
- Surface 尺寸更新按解码事件顺序串行提交，避免房间、线路、清晰度、全屏或小窗切换期间旧的异步返回覆盖新尺寸。

## 横屏直播记录布局

- 修复上游布局改动把双列阈值提高到 520 logical px 后，手机右半屏直播记录恒为单列的问题。
- 改为依据实际内容宽度与最小可读卡片宽度自动选择一列或两列；常见横屏手机恢复 `2 × 2`，狭窄窗口安全回退单列。
- 压缩标题栏、Tab、网格间距和卡片信息区，重新启用两行高度约束，让四个直播间卡片完整显示。

## 回归与构建范围

- 增加缺失旋转、负数/超范围旋转、不完整尺寸对、Surface/识别一致性、半屏双列与两行卡片高度回归。
- 正式构建前执行一次完整 Analyze、完整自动化测试与仓库/接口门禁，随后只构建 Android `arm64-v8a` Release。

---

# Pure Live v3.0.2

v3.0.2 build 4090 是 Android 播放比例与弹幕布局紧急修正版。本轮只构建 `arm64-v8a` Release APK；Windows、Linux、macOS 与 iOS 安装包继续使用 v3.0.0。

## 根因与播放比例修复

- 根因是上游移动端播放器新增了一层外部 `FittedBox`，而 MediaKit/Fijk 适配器内部已经负责画面缩放；v3.0.1 又移除了普通直播间原有的 16:9 几何边界，并把同一检测比例传播到普通页、全屏、画中画和应用内小窗。两组改动叠加后，普通横屏源会被重复缩放或沿错误比例压缩成细条。
- 恢复普通横屏及尚未稳定识别视频源的 16:9 布局边界。只有经过稳定门确认且比例合理的竖屏源才进入自适应布局，异常、未知和近方形元数据不会改变页面结构。
- 移除播放器管理层的第二次 `FittedBox`，由 MediaKit/Fijk 原生适配器唯一处理 `BoxFit`，避免普通页、横屏全屏与小窗出现不同的缩放结果。

## 尺寸事件、全屏与小窗

- MediaKit 从同一个 `VideoParams` 事件原子读取显示校正后的 `dw/dh` 和旋转信息，避免清晰度、线路或方向切换时组合出一帧新旧尺寸。
- Fijk 在宽度或高度任一项变化时发布完整尺寸，不再只依赖宽度变化；跨房间、重连和播放器重建仍会清空旧元数据。
- Android 画中画与应用内小窗使用隔离后的紧凑比例策略：普通横屏、未知尺寸和不合理比例保持 16:9，稳定竖屏源才跟随真实比例。

## 弹幕布局与回归

- 手机弹幕列表改用当前主题的全宽表面，移除硬编码黑色背景、巨大灰色圆角容器及其造成的颜色割裂；桌面端继续保留独立面板层次。
- 增加普通横屏、稳定竖屏、异常比例、旋转尺寸、画中画/浮窗与弹幕布局静态回归，防止后续竖屏适配再次污染普通直播。
- 完整质量门禁通过后只构建 Android `arm64-v8a` Release；正式 APK 由 GitHub Secrets 中的固定发布证书短时签名并校验证书指纹、版本、包名和 ABI。

---

# Pure Live v3.0.1

v3.0.1 build 4089 是 Android 竖屏直播源适配更新。本轮只构建 `arm64-v8a` Release APK；Windows、Linux、macOS 与 iOS 安装包继续使用 v3.0.0。

## 竖屏源识别与布局

- 识别对象是直播视频源本身，而不是手机当前方向。播放器对解码后的宽高做 120 ms 成对合并，再经三次一致采样或 500 ms 稳定门确认；`0.90–1.10` 的近方形源保持中性，跨房间立即清空旧尺寸。
- 普通手机直播页默认使用“均衡”布局：竖屏源增大视频区域，但上限为可用高度 60%，并为画质栏和弹幕列表保留至少 200 px；另提供沉浸和兼容 16:9 模式。横屏源、IPTV 与桌面分栏不改变原有结构。
- 画面高度只在稳定状态变化时执行一次 220 ms 布局过渡，播放器控制器、原生纹理和弹幕会话保持原实例，画质或线路的瞬态元数据不会反复重建画面。

## 全屏、横屏与小窗

- 全屏方向提供“跟随直播源”“跟随系统”“始终横屏”三种策略。默认跟随稳定源方向；Android 16+ 的 600dp 大屏、折叠屏和分屏窗口跳过强制方向，继续按实际窗口约束响应式布局。
- Android 画中画在进入前使用稳定的真实宽高，极端比例限制到系统允许的 `1:2.39–2.39:1`，并保留源矩形与无缝缩放；应用内浮窗同步使用稳定源比例。
- 播放器新增“自动识别 / 强制竖屏 / 强制横屏”直播间快捷覆盖，可选择只在当前会话使用或记住到下次进入；切换实时应用，无需重开播放器。

## 弹幕、诊断与回归

- 竖屏源可单独选择跟随全局、顶部 25%、精简 50% 或隐藏画面弹幕，设置不回写全局字号、速度和样式。
- 可选诊断层显示解码尺寸、宽高比、候选/稳定方向及房间覆盖，诊断完全事件驱动，不增加轮询。
- 新增检测防抖、单次尺寸事件、近方形、瞬态画质切换、跨房间重置、Android PiP 边界、手机自适应高度和大屏方向锁边界回归。

---

# Pure Live v3.0.0

v3.0.0 build 4088 是对错误 build 4087 的原位修正版：在既有直播页布局、播放状态机、平台接口、录制可靠性与全平台验证基础上，修复 Android 直播页系统侧滑返回失效，并加入全上游差异与全仓源码审查门禁。Release 中旧资产由同一源码提交重新构建的 build 4088 完整替换，不混用两个 build。

## build 4088 返回、审查与桌面修正

- 根因是直播页沿用全局 `back_button_interceptor_plus`，同时 Android Manifest 关闭预测性返回；正常返回分支还在路由真正退出前清理播放器监听。Flutter 3.47 / targetSdk 37 下，这套旧模型会和系统侧滑手势及嵌套路由竞争，表现为进入直播后侧边返回没有响应或页面状态残缺。
- 删除全局返回拦截并启用 Android 预测性返回。直播路由使用局部 `PopScope`：普通竖屏直接退出；横屏/全屏第一次返回普通竖屏，第二次退出；弹窗和底部面板优先自行关闭；路由确认退出前不拆播放器监听。
- 新增返回行为 Widget 回归，覆盖普通直播页、横屏/全屏两段式返回和弹窗优先级；全仓审计同时禁止重新引入全局 `SystemChannels.navigation` 或旧拦截依赖。
- 新增手动只读 `Audit Upstream Update` 工作流：冻结上游 SHA，以 merge-base 盘点每个入站提交、文件、重命名、二进制和风险类别；合并后再扫描全部已跟踪文件。Git 依赖固定为 40 位提交，避免远端分支漂移。
- 修正旧全平台工作流仍可能并发占用多个 runner 的问题，Android、Windows、Linux、Apple 阶段依次排队；所有平台和发布输入继续默认关闭。
- 修复 Windows/MSIX“打开日志目录”检查父目录却打开不存在子目录、且忽略打开结果的问题；日志写入与 UI 统一解析实际 `LOGS/log` 路径。

## 上游同步与页面状态

- 以真实合并历史同步并审查到 `liuchuancong/pure_live@e808dcae`，吸收关注页/热门页状态绑定、无效关注记录清理、录制配置持久化与目录检查、Android ABI 管理、播放器生命周期串行化、移动端画面适配、多窗口开关和历史记录容量管理。
- 修复上游 `eae6c9e7` 引入的普通直播页回归：删除默认关闭的全屏翻转 Shell；手机重新同时显示顶部栏、视频、画质/线路和弹幕列表，桌面保留 300–400 px 可见侧栏，IPTV 不预留空面板。
- 新增普通直播页几何 Widget 回归和上游高风险差异门禁，后续涉及播放器、持久化设置、平台接口、工作流、版本或原生平台的上游改动必须先审查并记录处置。
- 修正新历史容量功能的 GetX 测试耦合、1–5000 边界、备份恢复与响应式持久化；多画面/新窗口开关在旧安装缺失键时保持原入口可用。
- 修正英文录制目录提示键名与正文，并让平板多画面入口随设置实时更新。
- 热门页只使用控制器发布的响应式平台快照构建 `TabBar` 与内容页，避免设置变化期间列表与控制器长度短暂错位。
- 关注平台列表重建时按平台 ID 保留当前选择；已移除的平台使用有界索引回退，并在下一帧同步筛选状态。
- 关注数据在启动、备份恢复和显式清理时统一过滤空平台、空/占位房间号并按平台内身份去重，损坏的旧记录不再进入首页刷新队列。
- 维护发行版继续使用 `wzgrx/pure_live` 更新源，上游批量替换的仓库地址没有覆盖维护分支的安装包、版本历史和下载入口。

## 播放器、画中画与平台接口

- 修复上游 #797：切换房间时立即清理上一直播间的宽高与竖屏标志，只有成对有效的视频尺寸才参与比例计算，避免竖屏房间后打开横屏直播被旧比例压缩。
- 修复上游 #794：Windows 进入画中画前保存全屏/宽屏表达状态，退出后按原状态恢复 UI，不再统一重置为普通窗口。
- 修复上游 #793：无参数重复启动在 Windows native runner 创建 Flutter engine 前拦截并激活已有窗口；分享链接、协议参数和显式多窗口参数仍交给 Dart 转发。
- 修复上游 #798：YY StreamManager 请求对齐当前官方 bid、SDK 版本和正文类型；遇到 `ErrAuthNotPass` 或空结果时自动使用匿名移动 HLS，并按实际视频流去重清晰度选项。
- YY 发布探针新增 #798 指定房间的 M3U8 实读；斗鱼新增 #799“寅子”房间元数据、H5 描述和实际 FLV 文件头验证；全平台公开接口门禁由 40 项扩展到 42 项。
- 复核上游 #799：报告使用 v2.9.4，当前分支的纯 Dart 签名、同会话 DID、H5 有界重试、播放请求头与 CDN URL 校验已覆盖其根因链，并对截图对应的 `71415` 房间执行在线实流验证。
- 抖音匿名搜索探针在同一 Cookie 会话内对 HTTP 503 等瞬态故障执行至多三次有界重试，持续故障仍直接失败并保留端点诊断。

## Android 录制与长时间稳定性

- 修复上游 #791：播放器、多画面、音频转发和录制共用同一平台播放请求头；斗鱼录制补齐房间 Referer、Origin、User-Agent 与进程级 DID Cookie。
- 移除 Bilibili CDN 请求中的错误 API authority；YY、IPTV 与虎牙录制头不再和播放器策略漂移。
- FFmpeg 正确引用带 `&` 的签名 URL和含空格的输出目录；音频或视频轨暂时缺失时使用可选映射，避免初始化阶段直接退出。
- CDN 403/404、AVERROR(EIO) 与短时输入错误会重新解析最新地址后有界重试；本地路径、权限及无效输出参数仍立即结束任务。
- 默认私有录制目录先实际探测写入能力，再决定是否申请 Android 存储权限；主播名和平台名统一处理非法字符、保留设备名与超长组件。
- FFmpeg 高频进度只更新对应任务，不再反复排序完整列表；Hive 持久化合并为两秒节流并在控制器关闭时刷新，减少长时间录制的 UI、CPU 与磁盘负载。
- FFmpeg 改为首次录制时惰性初始化，直接服务调用也执行初始化保护；一次瞬时 native/文件系统失败不会永久污染进程内初始化状态。
- 录制页布尔开关改为响应式 Hive 持久化，缓存限制不再使用进程启动时的静态快照；FFmpeg 仍校验 HTTPS 证书，不以关闭 TLS 校验掩盖 CDN 或证书故障。
- Android 私有录制目录在创建任务和申请广泛存储权限前拦截，避免留下不能启动的任务；私有路径识别覆盖所有数字用户/工作资料 ID，并排除外部同名目录误判，轮询任务在路径未修正时继续等待。

## 依赖、工作流与交付

- hosted 依赖统一使用官方 `pub.dev` URL与当前归档哈希；除需要全应用迁移到 `material_ui.ColorScheme` 的 `dynamic_color` 2.x 外，直接依赖均为 Flutter 3.47 当前兼容线的最新版本。
- 修复全平台工作流中 Windows artifact Action 多余字符导致的无效 SHA；第三方 Release/读文件 Action 固定到完整提交。
- 全平台发布汇总支持复用本机编译、GitHub Secrets 短时签名后的 Android APK与本机 Windows 包；发布前强制核对 Android 包名、版本、ABI、固定证书指纹及 Windows 源码提交，并清理草稿中的阶段资产。
- Release 仅在本轮明确请求的每个平台都构建成功后创建，避免某个阶段失败时误发布不完整的“全平台”版本。
- 版本：`3.0.0+4088`；Android arm64-v8a、Windows x64、Linux x64、macOS Universal 与 iOS arm64 串行构建发布。

---

# Pure Live v2.9.7

v2.9.7 build 4086 is an Android audience-metric and ranking consistency update.

## Audience semantics

- Audited current public payloads for Douyu, Huya, Douyin, Kuaishou, NetEase CC, Twitch, SOOP Live and YY Live. Douyu `ol/hot`, Huya `totalCount/userCount/iAttendeeCount` and YY `users` remain platform heat rather than concurrent head counts.
- Douyin now reads the current anonymous feed's top-level `user_count` as concurrent viewers and no longer stores that value as cumulative views when `total_user` is an unavailable zero placeholder.
- NetEase CC now treats `webcc_visitor`, `hot_score` and `visitor` as heat aliases; only `vision_visitor/online_num` can populate the online-viewer field.
- SOOP recommendation and search cards now use `total_view_cnt`, including both PC and mobile viewers. Category `view_cnt` remains authoritative, explicit PC/mobile fields are summed as a fallback, and missing player-detail counts remain pending instead of becoming a false zero.

## Ranking and regression coverage

- Popular-platform pages now share the same descending, metric-aware and deterministic comparator as favourites, search and room pickers. Changing heat/online mode refreshes and re-ranks the active platform; CC uses a 100-room candidate window for meaningful real-online ordering.
- Existing interface probes now verify each platform's audience-field contract as part of the 40-check gate, while focused parser tests cover the Douyin, CC and SOOP regressions and heat/online ordering.
- Synchronized remotes before source freeze; upstream remains `liuchuancong/pure_live@974f4c32` with no newer commit at release preparation time.
- Version: `2.9.7+4086`.
- This release publishes Android `arm64-v8a`; Windows, Linux, macOS and iOS remain on their v2.9.4 artifacts.

---

# Pure Live v2.9.6

v2.9.6 build 4085 is an Android platform-interface and upstream synchronization update.

## Platform interfaces

- Fixed the current Douyin recommendation envelope that could otherwise index a string/list as a map and surface `type 'String' is not a subtype of type 'int' of 'index'`.
- Douyin parsing now accepts current and legacy response shapes, embedded room JSON and missing optional fields; its live probe also requires a real playback descriptor rather than only card metadata.
- Bilibili popularity uses the public `sort=online` ranking source plus deterministic descending client sorting instead of a personalized recommendation order.
- Bilibili room metadata validates signed responses before indexing, refreshes stale WBI keys and performs one bounded retry when the platform rejects the signature.
- Added playback-level live probes for Bilibili quality/CDN descriptors, Huya room/bitrate/FLV-HLS lines and CC's two-step room mapping/playback contract.

## Upstream and regression coverage

- Synchronized and merged upstream through `liuchuancong/pure_live@974f4c32`, including download confirmation, version history and fullscreen viewing-record improvements.
- Preserved the maintained repository's launch refresh, background playback continuity, quality switching, local-first serial build policy and official signing workflow.
- The final gate covers 40 public interface checks across Bilibili, Douyu, Huya, Douyin, Kuaishou, CC, Twitch, SOOP Live and YY Live, in addition to Flutter Analyze and the complete automated test suite.
- Version: `2.9.6+4085`.
- This release publishes Android `arm64-v8a`; Windows, Linux, macOS and iOS remain on their v2.9.4 artifacts.

---

# Pure Live v2.9.5

v2.9.5 build 4084 is an Android stability update for playback quality, platform interfaces and the newly synchronized YY platform.

## Quality and line switching

- Added a shared stable quality identifier and transactional switching: the UI changes only after the target source opens, stale requests are discarded, failed opens keep the previous source, line indices are clamped and duplicate/blank lines are removed.
- Bilibili now reads the server's actual `current_qn`; Huya replaces a stale `ratio` (and removes it for source quality); Douyin joins streams by `sdk_key`; Douyu preserves the platform's opaque rate order instead of numerically sorting it.
- Twitch master variants are parsed as attribute/URI pairs without shared mutable state; Kuaishou, CC, SOOP, YY and IPTV received stable IDs, defensive payload handling and deterministic playback fixtures.
- The fullscreen quality/line dialog now derives its total size from the real option rows. It removes redundant header values, gives the choice buttons the main visual area and only keeps large panes when their content actually needs scrolling.
- A handled playback error finishing after an overlay lifecycle change no longer triggers a second uncaught toast exception.

## Audience metrics and ranking

- CC `webcc_visitor` heat is separated from `vision_visitor/online_num` concurrent viewers.
- Concurrent ranking compares explicit, pending and heat-only tiers before numeric values, then uses stable room identity to stop equal cards from jumping during refresh.
- Douyin no longer treats cumulative `total_user` fields as current online viewers; SOOP joins the supported concurrent-platform settings.

## Douyu playback

- Synchronized the upstream baseline through `liuchuancong/pure_live@a161a324` with real merge ancestry, including the latest version-history transport/parser update.
- The H5 stream request now uses one session DID and consistent browser headers, refreshes stale signing descriptors, and performs one bounded retry.
- Quality and CDN parsing tolerates partial response shapes, removes duplicate lines, and validates the final decoded stream URL.
- Actual media requests now receive Douyu Referer, Origin, User-Agent and matching DID cookies on every player backend.
- The public interface gate now verifies signing, H5 metadata, CDN selection, and a real FLV header instead of stopping at the encryption descriptor.

## YY integration

- Added categories, room lists, search, room status, quality/line playback, danmaku and local Cookie settings from upstream.
- Replaced the native JavaScript runtime used for a simple page literal with a pure-Dart parser, keeping Android and desktop packages smaller and deterministic.
- Upgraded public URLs to HTTPS and switched room refresh to the direct authoritative room-detail endpoint.
- Corrected live/anchor search contracts, live-state parsing, room identifiers, and YY Cookie status display.

## Search stability and discovery

- Replaced the search page's auto-centering `TabBar` with a dedicated bounded platform strip. It remains horizontally scrollable when platforms exceed the screen width, but the first and last item are now hard boundaries and the selected state cannot drift away from the active platform.
- Keeps one stable adapter snapshot for the page, preserving pagination cursors and preventing platform order/index mismatches while results are loading.
- All-platform search now publishes each completed platform immediately, caps an individual request at 12 seconds, deduplicates results, and isolates partial failures instead of blocking the whole grid behind one slow endpoint.
- Added YY native search coverage, respected requested page sizes for Bilibili, Douyu, Huya, CC and SOOP, and kept IPTV local search separate from web continuation.
- Web result detection now supports Bilibili, Douyu, Huya, Douyin, Kuaishou, CC, Twitch, SOOP and YY, rejects navigation/lookalike URLs, preserves the detected platform identity, and suppresses duplicate room prompts.

## Regression coverage and delivery

- Multiview sorting now understands localized ten-thousand/hundred-million suffixes as well as values such as `18.3k`.
- Added deterministic Douyu/YY/search parser and bounded-scroll tests plus 36 public probes across Bilibili, Douyu, Huya, Douyin, Kuaishou, CC, Twitch, SOOP and YY.
- Version: `2.9.5+4084`.
- This release publishes Android `arm64-v8a`; Windows, Linux, macOS and iOS remain on their v2.9.4 artifacts.
- No ADB or phone automation was used; the signed APK is ready for independent device acceptance.

---

# Pure Live v2.9.4

v2.9.4 build 4083 是上游多画面同看、录制数据保护、平台播放兼容和长时间资源治理的全平台稳定更新，发布到 `wzgrx/pure_live`。

## 上游同步与多画面

- 合并发布时最新的 `liuchuancong/pure_live@99ef708c`，吸收多画面同看、斗鱼/抖音纯 Dart 签名、语言切换、Windows MSIX 数据路径、视频显示模式和房间增量合并；保留维护分支已有的弹幕、PiP、高刷新率、音频模式和横屏交互增强。
- 修正最新上游合并后的三个边界：迟到的旧房间详情先通过“代次 + 平台 + 房间号”围栏再更新；稀疏响应不再把关注房间误写为下播或覆盖本地标签；视频适配由各播放器内核直接应用，避免等待尺寸造成首帧空白及 Windows 纹理按源分辨率过度分配。
- 多画面音频焦点改为串行“最后一次选择生效”，快速连续切换不再因原生静音 Future 乱序留下多个声源。
- 播放器暂停失败时仍进入内核销毁，避免某一格释放异常阻断其他格；移动端限制 4 路同时解码，桌面端保留 9 路上限。

## 数据安全与长时间稳定性

- 修复上游 #778：自定义录制路径只作为父目录，录制、容量统计和清理统一限定在带所有权标记的 `PureLiveRecords` 子目录，选择“下载”等公共目录也不会删除无关文件。
- 自动容量限制改为一次递归快照按时间清理，覆盖平台/主播/日期多层目录；文件轮转、锁定或空目录均以有限步骤结束，消除持续循环和 CPU 异常升高风险。
- 调试日志保留最近 2000 条，EPG 模糊匹配缓存按数据源隔离并限制 1024 项；房间详情失败只回退到身份相同的当前房间，且不再原地改写活动状态。

## 关注、搜索与弹幕显示

- 修复上游 #784：关注页当前标签在响应构建阶段完成订阅，“全部 → 自定义 → 全部”可稳定往返，筛选数据与 ChoiceChip 选择态保持一致。
- 搜索结果在 Android/iOS 恢复短列表和长列表回弹；平台分类栏保持起始对齐和有界横向滚动，不再把整行拖离首尾位置。
- 修复上游 #783：弹幕原生描边由四次偏移叠加恢复为单次清晰绘制，减少重复绘制；低透明度轮廓使用连续伽马曲线，在亮色画面上保留更多边缘对比度。

## 平台接口与依赖

- 快手同时解析房间页 `{h264/hevc}` 和推荐/录播列表 `adaptationSet` 结构，同清晰度的多 CDN 地址合并为线路；房间页明确下播但卡片带有效录播地址时进入录播模式。
- 斗鱼与抖音签名统一迁移到纯 Dart，移除 JS 运行时及其桌面原生插件；斗鱼加密描述符按 Unix 秒缓存并合并并发刷新，避免每次画质/线路切换重复请求。
- 抖音签名 URL 不再改写调用方参数，保留基础 URL 既有查询；随机令牌复用单个安全随机源。新增斗鱼加密描述符和快手播放结构接口探测。
- 快手 #782 的后续反馈确认“全部无法播放”来自旧 Cookie 触发平台风控，用户刷新 Cookie 后恢复；直播/录播双结构解析继续覆盖真正的数据形状差异。
- 直接依赖已复核到 Flutter 3.47 可解析的最新兼容组合；固定 Git 依赖均再次与远端 HEAD 对齐。`dynamic_color` 维持兼容 Flutter Material `ColorScheme` 的 1.9.0 系列。
- Windows ZIP/安装程序改用当前 CMake 安装清单与必要 runner 运行时白名单，排除增量输出遗留的 QuickJS DLL、旧插件资源和开发文件。

## 交付范围

- 版本更新为 `2.9.4+4083`。
- Android arm64-v8a、Windows x64、Linux x64、macOS Universal 与 iOS arm64 按构建资源策略分阶段串行完成正式构建和校验。
- 完整门禁、近期 Issue 结论、平台产物及 SHA-256 记录见 `docs/STAGE_UPDATE_2_9_4.md`、`docs/ISSUE_AUDIT_2026_08_24.md` 和 Release 元数据。

---

# Pure Live v2.9.3

v2.9.3 build 4082 是横屏画质与线路面板内容驱动布局专项 Android 更新，发布到 `wzgrx/pure_live`。

## 画质与线路布局

- 取消手机横屏面板中画质区与线路区固定 `4:3` 比例；画质区改为按真实选项行数计算高度，线路区使用全部剩余空间。
- 四个画质在常见横屏宽度下使用均衡的 `2×2` 排列，不再出现三项占第一行、一项占第二行并留下大片空白的情况。
- 五至六个画质继续使用三列；更窄面板自动退化为两列或一列，保证文字和点击区域完整。
- 小高度视口中画质区最多占三行，同时为线路列表保留最低可操作高度，避免底部线路被裁切。

## 状态与回归

- 画质和线路的当前项统一使用状态色、强调边框和勾选图标，标题区继续展示当前选择。
- 新增常见四画质、多画质、小高度视口及选项列数平衡测试，覆盖内容高度、剩余线路空间和自适应列数边界。
- 正式交付执行 Flutter Analyze、完整自动化测试与公开接口探测，结果和构建记录随 Release 元数据一并保留。

## 交付范围

- 本轮仅构建并发布 Android `arm64-v8a` Release；其他平台继续使用 v2.9.0 对应资产。

---

# Pure Live v2.9.2

v2.9.2 build 4081 是横屏右侧半屏布局二次优化与本地弹幕实时预览专项 Android 更新，发布到 `wzgrx/pure_live`。

## 画质与线路

- 右侧半屏面板压缩总标题、分区标题、外边距、分区间距与选项卡高度，把纵向空间优先交给蓝光、超清等画质和线路内容。
- 半屏宽度允许时由双列提升为三列，每个选项保持当前状态和切换反馈，可见项目数量明显增加。
- 画质与线路仍共用原地切流逻辑，切换期间保留顶部进度提示，不重建直播页。

## 直播记录

- 缩小面板顶部工具栏以及“已开播 / 录播 / 观看记录”标签栏，减少顶部空白。
- 双栏卡片底部信息区由 48 px 收紧为 36 px，并依据可用高度动态计算卡片尺寸，横屏手机首屏可完整容纳 2×2 四张直播卡片。
- 平台、热度/观看时间、标题和主播信息继续保留，封面仍是卡片视觉主体。

## 本地弹幕样式

- 横屏面板固定占右侧约半屏，内部改为左右双栏：左侧常驻实时预览，右侧独立滚动全部设置。
- 颜色、字号、字体、透明度、字距、粗斜体、描边、阴影和位置修改即时反映到左侧；滚动弹幕速度也以真实循环动画即时呈现。
- 实时预览动画仅在编辑器打开期间运行，不增加正常播放界面的持续渲染负担。

## 验证与交付

- 增加半屏双栏、三列画质/线路和四卡完整可见的布局边界回归；Flutter Analyze 0 issue、249/249 项自动化测试与 27/27 项公开接口探测通过。
- 本轮仅构建并发布 Android `arm64-v8a` Release；质量门禁和正式签名结果随 Release 元数据记录。

---

# Pure Live v2.9.1

v2.9.1 build 4080 是横屏半屏内容面板与本地弹幕个性化专项 Android 更新，发布到 `wzgrx/pure_live`。

## 横屏内容优先面板

- 清晰度/线路、直播记录和本地弹幕样式统一从屏幕右侧打开，动态占用约半屏宽度，保留左侧直播画面作为操作参照。
- 清晰度与线路卡片压缩标题和留白，质量区域按 4:3 获得更多内容空间；切换状态继续使用原地切流和顶部进度提示。
- 直播记录在半屏宽度内使用双栏 16:9 封面卡片，平台与观看时间覆盖在封面上，标题和主播信息收敛到紧凑底栏。

## 本地弹幕个性化

- 模板由 4 组扩展到清爽、醒目、霓虹、极简、底部字幕和赛博 6 组，主色扩展为 12 种，并提供独立描边/阴影效果色。
- 新增滚动、顶部固定、底部固定三种位置；增加系统/圆润/衬线/等宽字体、透明度、字间距、粗体、斜体、描边颜色和宽度。
- 新增阴影/微光颜色、模糊、偏移，以及固定弹幕 2–10 秒停留时间；预览会跟随位置和全部效果实时变化。
- 同一持久化编辑器复用于竖屏、横屏、小窗、本地弹幕发送框、本地互动页和设置页，修改后无需重启。

## 渲染与验证

- `flame_barrage` 支持每条消息独立的字体、位置、透明度、字距、描边、阴影和固定时长；文字效果编译进有界 Paragraph/Picture 缓存，不增加逐帧离屏图层。
- 固定弹幕轨道记录独立释放时间，避免不同停留时长互相占用；主画面与 PiP 使用相同样式映射。
- Flutter Analyze 与本地弹幕、横屏布局、弹幕缓存定向回归完成；本轮仅构建 Android `arm64-v8a` Release。

---

# Pure Live v2.9.0

v2.9.0 build 4079 是清晰度切换、横屏全屏控制层、本地弹幕样式和上游播放稳定性整合的全平台正式更新；发布到 `wzgrx/pure_live`。

## 上游同步与播放稳定性

- 真实合并上游 `liuchuancong/pure_live@25f833ea`，吸收从录制页返回直播时延迟挂载视频层的崩溃修复，并保留维护分支已有播放器生命周期与音频模式优化。
- 清晰度和线路切换改为播放器原地切流：旧流持续播放到新地址解析完成，按请求代次只应用最后一次选择，避免销毁直播页控制器、重复请求房间详情或被默认清晰度异步覆盖。
- 竖屏与横屏共用同一选择状态，切换期间显示明确进度；质量或线路数量变化时自动校正索引并保留可用回退流。

## 横屏界面、历史与本地互动

- 横屏左上角调整为返回、时间和电量，Android 小窗入口移到右上角；直播间切换/历史入口改为响应式双栏卡片，展示平台、主播、状态和最后观看时间。
- 右下角把线路与清晰度合并为横屏专用双栏选择面板，当前项、切换状态与可选线路更加直观。
- 本地弹幕增加预设、颜色、字号、速度、粗体、描边和描边宽度；横屏输入框、竖屏输入、本地互动面板及设置页共享同一持久化配置。
- 观看历史使用“平台 + 房间号”复合身份，保留详情刷新前后的时间元数据并限制为最近 50 条。

## 构建与发布

- 发布资产统一使用 `版本-构建号-平台-架构` 命名；版本更新为 `2.9.0+4079`。
- Android arm64、Windows x64、Linux x64、macOS Universal 与 iOS arm64 按资源策略串行构建和校验。
- 完整质量门禁、接口探测、平台任务、产物哈希和来源提交记录见 `docs/STAGE_UPDATE_2_9_0.md` 与 Release 元数据。

---

# Pure Live v2.8.0

v2.8.0 build 4078 是上游同步、关注状态权威刷新、抖音搜索和桌面播放增强的全平台稳定更新；仅发布到 `wzgrx/pure_live`。

## 上游同步与近期 Issue

- 真实合并上游 `liuchuancong/pure_live@4ca626d9`，吸收抖音搜索、前台恢复刷新开关、Windows PiP 几何校验、RTX VSR 可选项及结构整理。
- 针对 #774，保留逐平台可见下拉动画，并将前台恢复刷新设为新旧配置缺省行为；启动、恢复、定时和手动刷新统一使用权威快照，失败房间进入“状态待确认”，不再继续显示旧开播状态。
- 针对 #775，抖音搜索在匿名原生搜索需要登录时自动回退到公开分区检索；补全匿名 Cookie、Cookie 切换、备用域名、分页、稳定房间身份和下载链接，并增加“三角洲”真实接口探测。
- 针对 #767，继续启用 Windows 可见物理视口纹理限幅与防抖尺寸更新，避免 4K/高 DPI 小窗口维持超过实际需要的源纹理；RTX VSR 保持明确的按需开关。
- 吸收上游最新直播流 seek 调整并消除重复原生属性写入；补齐旧版 Windows 小窗扁平几何字段和播放器归属开关向当前窗口设置的无损迁移。

## 稳定性与构建

- 关注刷新只失效本次核验的平台/标签范围，其他平台卡片和排序保持不动，减少刷新期间的视觉跳动。
- 横屏/全屏弹幕设置面板移除固定深色背景和白色文字，背景、标题、边框、按钮及内部卡片实时继承应用当前浅色、深色或跟随系统主题。
- 保留维护仓库更新源、Windows 覆盖升级 AppId、本机优先构建、Android 正式签名与串行全平台发布策略。
- 版本更新为 `2.8.0+4078`；Android arm64、Windows x64、Linux x64、macOS Universal 与 iOS arm64 按平台串行构建。
- Flutter Analyze 0 issue、236/236 项单元/Widget 测试与 27/27 项公开接口探测通过。
- 完整质量门禁、接口结果、平台任务、产物哈希与运行采样记录见 `docs/STAGE_UPDATE_2_8_0.md` 和 Release 附带元数据。

---

# Pure Live v2.7.0

v2.7.0 build 4077 是最新上游整合、热门页生命周期和全平台交付更新；Android 资产已用关注刷新修复后的源码重新构建，仅发布到 `wzgrx/pure_live`。

## 上游同步

- 真实合并上游 `liuchuancong/pure_live@81ec372a`，保留完整提交关系，后续同步可继续按共同祖先合并。
- 吸收热门页关闭状态、加载代次、平台配置防抖及延迟预热隔离，防止页面销毁或平台列表重建后旧任务继续刷新当前界面。
- 吸收取消关注弹窗路由修复，并进一步让按钮绑定弹窗自己的 `BuildContext`，避免导航转场期间误退直播页面。
- 对上游 Windows 小窗、图片缓存、更新源、应用 AppId、ABI 清单与全平台工作流逐项审查；保留维护版已经验证的位置/大小记忆、跨屏边界恢复、有界图片缓存、覆盖升级 AppId、`wzgrx` 更新源及串行构建策略。

## 稳定性与兼容性

- 热门页控制器在关闭时取消切换计时器、相邻平台预热和设置监听，并以 generation 隔离过期异步结果。
- 平台开关或排序变化后按平台 ID 恢复选中项；控制器按需重建并保持滚动状态，降低快速横滑时的数据竞争。
- 关注页下拉刷新二次加固：改用 `EasyRefresh.builder`，将刷新器提供的滚动物理直接安装到当前平台的唯一纵向列表；Material 刷新头、空列表和短列表均通过真实拖动回归。
- 启动、恢复、定时和手动刷新统一为串行快照事务；冷启动先显示位置稳定的“正在核验”状态，成功结果一次性发布，网络失败保留“状态待确认”，不再沿用上次进程的开播位。
- CC、Twitch、SOOP 使用严格状态刷新语义；虎牙回放进入录播分组，平台返回规范房间号时仍绑定原收藏身份。
- 继续保留播放器、弹幕、PiP 返回、音频/视频切换、首页批量刷新及长时间资源治理的既有回归覆盖。
- 版本更新清单只声明实际发布的 Android `arm64-v8a`，所有下载地址继续指向维护仓库正式 Release。

## 构建与验证

- 版本更新为 `2.7.0+4077`。
- Android arm64、Windows x64、Linux x64、macOS Universal 与 iOS arm64 按资源策略串行构建；最新 Android APK 在本机完成 Flutter/Gradle 编译，远端任务只执行正式证书签名与资产校验。
- Flutter Analyze 0 issue、229/229 项单元/Widget 测试及 26/26 项公开接口探测通过。
- 完整质量门禁、平台任务、产物哈希与运行采样记录见 `docs/STAGE_UPDATE_2_7_0.md` 和 Release 附带元数据。

---

# Pure Live v2.6.0

v2.6.0 build 4076 是上游同步、近期 Issue 修复、播放器与长时间资源治理的阶段稳定版；仅发布到 `wzgrx/pure_live`。

## 上游与近期问题

- 真实合并上游 `liuchuancong/pure_live@c3ae29bb`，保留其关注刷新、房间详情补全、版本历史容错和弹幕模板状态修复。
- 吸收上游 BetterPlayer 尺寸修复和 Windows 小窗记忆入口；合并时保留非 Exo 首帧防死锁、iOS 新配置 IJK 默认值、维护仓库更新源及完整位置/大小越界校正。
- 修复链接解析或普通入口进入直播间后关注状态不更新：关注按钮直接观察持久化收藏列表，并统一使用“平台 + 房间号”身份。
- 修复多文件字体目录不一致、重启后选择丢失、弹幕字体未即时注册；下载完成后多字重字体进入明确选择页。
- Windows 小窗增加记忆开关与重置入口，保存用户调整后的位置和大小；默认在应用所在显示器打开，跨显示器恢复时保持可见，并与主窗口尺寸持久化分离。
- 醒目留言列表实时观察消息集合，切换直播间时用房间代次隔离异步结果；列表边界改为有界滚动物理效果。
- iOS 新安装默认使用已有画面的 IJK 内核，并通过原生通道回报设备最高刷新率；已有用户的播放器选择保持不变。
- 修复 Xcode 26 下隐式 Flutter 引擎插件 registrar 为可选值时的 iOS 编译错误，重新完成 unsigned app 与 TrollStore IPA 构建。

## 播放、画面与资源

- 非 Exo 播放器原生纹理先挂载再等待真实视频尺寸，消除强制销毁、换核或重新进入后的初始化死锁和持续转圈。
- 画面适配只更新呈现尺寸，不再通过重新请求数据源实现缩放；Windows 高 DPI 下按可见视口约束纹理合成面积。
- 首页封面、头像和分区图片恢复有界解码缓存，取消每张卡片首次挂载时主动删除磁盘缓存，减少重复网络、解码、CPU 与卡片跳动。
- 直播间、弹幕、醒目留言、PiP 和播放器继续使用房间/加载代次、队列上限及显式订阅释放，阻止旧房间异步结果回写当前会话。

## 依赖与构建

- `scrollview_observer` 更新至 1.27.1；其余 Dart 直接依赖已处于解析器可升级的最新兼容组合。
- `dynamic_color` 保持 1.9.0：2.x 的 `material_ui.ColorScheme` 与当前 Flutter Material 类型边界不同，待完整主题迁移后单独升级。
- Android 保持官方 AGP 9.3.1 推荐的 Gradle 9.5.0、Google Services 4.5.0、compile/target SDK 37 与 Built-in Kotlin。
- Android 本轮只构建正式签名 `arm64-v8a`；Windows x64、Linux x64、macOS Universal 与 iOS arm64 按平台串行构建。
- Flutter Analyze 0 issue、224 项单元/Widget 测试与 26/26 项公开接口探测通过；各平台产物结果写入 `docs/STAGE_UPDATE_2_6_0.md` 与 Release 元数据。
- Windows Release 完成 6 分钟隔离实例烟雾采样，工作集保持平稳；全部平台产物均复核 SHA-256 与归档结构。

---

# Pure Live v2.5.3

v2.5.3 build 4075 是竖屏弹幕导航约束与横屏小窗快捷入口专项更新，来源为合并后的 `master`。

## 竖屏弹幕功能栏

- “弹幕列表 / 醒目留言 / 弹幕设置 / 屏蔽管理”由自由横向滚动改为四栏等宽固定布局。
- 标签栏本身不再被连续拖离原位；对应内容页仍可在第一页到最后一页的有效范围内左右切换。
- 较窄屏幕使用紧凑标签间距，四项入口保持完整、稳定且容易点击。

## 横屏小窗入口

- Android 横屏全屏控制栏左上角在返回按钮旁新增小窗图标。
- 横竖屏复用既有 PiP 入口与播放器生命周期，避免产生第二套状态切换逻辑。
- Windows 原有窗口模式入口保持不变。

## 构建与验证

- 新增固定标签布局、拖动约束及 Android 横屏小窗动作顺序测试。
- Flutter 3.47.0 / Dart 3.13.0；217 项单元与 Widget 测试全部通过。
- 构建使用本机资源互斥、Gradle 增量缓存与正式签名记录；Android 本轮仅生成 `arm64-v8a` Release。
- Windows 与其他平台继续使用 v2.5.0 对应构建。

---

# Pure Live v2.5.2

v2.5.2 build 4074 是启动关注刷新、动态高刷联动、弹幕帧同步和竖屏列表手势专项更新，来源为合并后的 `master`。

## 启动刷新

- 关注核验在 Flutter 首帧后立即开始，与启动页动画重叠；启动页结束时仅保留 350 ms 有界等待，慢平台继续在后台完成。
- 哔哩哔哩、斗鱼、虎牙、快手新增轻量元数据刷新路径，收藏卡片不再提前请求播放线路、签名和弹幕凭据。
- 同一刷新批次复用平台适配器、设备 Cookie、WBI 密钥和会话初始化；请求继续由 4 路有界异步 I/O 调度。

## 刷新率与弹幕

- 通用界面刷新率统一为省电、均衡、最高（设备上限）三档；切换后立即作用于现有界面和自动弹幕渲染器。
- 省电档主画面/小窗弹幕上限为 60/30 FPS，均衡档为 60/60 FPS，最高档两者跟随当前设备检测上限。
- 主画面与小窗保留各自的自动跟随开关；关闭后使用该画面的独立手动 FPS，不影响全局档位和另一个画面。
- `flame_barrage` 从周期计时器切换为 Flutter `Ticker`，弹幕推进对齐 vsync，并按真实经过时间保持统一移动速度。

## 列表手势与验证

- 手指按下竖屏弹幕列表时立即使排队中的自动追尾失效，避免帧尾 `jumpTo` 取消快速上滑。
- 自动恢复前重新核对活动指针、滚动状态和列表版本；保留反向懒构建与“新消息/回到最新”入口。
- Flutter 3.47.0 / Dart 3.13.0；Flutter Analyze 0 issue，215 项单元与 Widget 测试全部通过。
- Android `arm64-v8a` 正式签名更新；Windows 与其他平台继续使用 v2.5.0 对应构建。

---

# Pure Live v2.5.1

v2.5.1 build 4073 是关注页平台横滑与收藏完整性专项更新，来源为合并后的 `master`。

## 关注页与平台横滑

- 当前平台筛选为空时继续保留完整 `TabBarView`，滑到零结果平台后仍可横滑返回。
- 平台控制器改为按平台 ID 保持选中项；平台显示开关或排序变化时同步视觉页面、数据索引和独立纵向滚动位置。
- 收藏标签条移到分页外层，减少两个同方向横向列表争抢手势。
- 空结果区分“尚未关注”和“当前开播筛选为空”，保留下拉刷新，并可直接进入未开播列表。

## 刷新与数据完整性

- 平台、开播状态和标签重置合并为单次筛选事务；收藏快照未变化时跳过延迟的第二次全量筛选与排序。
- 收藏、标签、房间刷新和卡片状态统一使用“平台 + 房间号”复合身份，修复不同平台相同房间号互相覆盖的问题。
- 启动和备份导入时规范化平台 ID 的大小写与首尾空白，并迁移旧房间号标签映射。

## 构建与验证

- Flutter 3.47.0 / Dart 3.13.0。
- Flutter Analyze：0 issue。
- 211 项单元与 Widget 测试全部通过。
- Android arm64-v8a 正式更新；Windows 与其他平台继续使用 v2.5.0 对应构建。

---

# Pure Live v2.5.0

v2.5.0 build 4072 聚焦首页首刷速度、设备刷新率分档、Windows 视频纹理资源边界和可复现本机构建，并以真实 merge 同步上游至 `b84a847d`。

## 首页与列表

- 收藏核验从“固定批次整批等待”改为 4 路有界异步工作池；完成一个网络任务后立即领取下一个，慢平台不再阻塞同批后续房间。
- 房间超时从 12 秒收紧为 10 秒；后台版本检查延后到首帧后 2 秒，降低启动时的带宽与调度竞争。
- 刷新结果完整后一次性发布，保留旧卡片、稳定排序和滚动位置，避免加载期间卡片分批插入和跳动。
- 修复首次收藏快照为空时被“相同空列表”短路的问题；空收藏现在立即进入空状态，不再让隐藏的无限加载动画持续占用 Windows CPU/GPU。
- 热门接口短时失败时保留上一份可用快照；分区卡片尺寸和切换房间滚动物理效果同步上游修复。

## 刷新率与功耗

- 新增省电、均衡、高性能三档刷新率模式；设置页展示当前刷新率、设备最高刷新率和各档耗电提示。
- 新安装默认省电，由系统动态选择刷新率；均衡在触摸、滚动和转场时请求最高刷新率，稳定 1.5 秒后释放；高性能在应用前台持续请求最高刷新率。
- 旧版高刷开关自动迁移为均衡档；播放器视频帧率与界面刷新率保持独立，避免低帧率直播重复渲染。

## Windows 与播放器

- Windows MediaKit 原生视频输出按可见控件的物理像素尺寸设置，保持源视频比例且不超过源分辨率。
- 窗口尺寸变化使用 180 ms 去抖，降低拖动、缩放和小窗场景的纹理重建频率。
- 保留既有播放器/弹幕会话代次、PiP 返回重订阅、长时间队列上限与资源释放回归。

## 依赖、构建与上游

- 更新 `ffmpeg_kit_extended_flutter` 0.6.0、`flutter_color` 2.1.1；`dynamic_color` 使用 Flutter 3.47 可直接兼容的 1.9.0。
- FFmpeg builders v0.11.0 的 Android AAR 和 Windows Native Assets ZIP 在构建前执行 SHA-256 校验并复用持久缓存。
- `tool/local_ci.ps1` 在一次锁文件解析后使用 `--no-pub` 完成 Analyze/测试，减少重复网络和原生资产准备。
- 同步上游 `b84a847d`，同时保留维护仓库发布地址、Windows 数据目录和升级迁移逻辑。

## 构建目标

- Flutter Analyze 0 issue、208 项单元/Widget 测试、26/26 平台公开接口探测通过。
- Android `arm64-v8a` 正式安装包。
- Windows x64 便携包与可选安装程序。
- Linux x64、macOS Universal、iOS arm64 设备归档由对应系统的阶段构建补齐。
- 同一 Release 提供 `SHA256SUMS.txt` 与 `BUILD_METADATA.json`，记录源码提交、签名状态和平台来源。

完整设计和验收边界见 [v2.5.0 阶段稳定版](docs/STAGE_UPDATE_2_5_0.md)。

---

# Pure Live v2.3.0

v2.3.0 build 4070 聚焦系统画中画返回后的弹幕会话、高刷设备 CPU、全局滚动流畅度，以及 Windows/Android 长时间运行的资源边界；维护分支已同步至上游 `e51df666`，包含 SC、平台目录整理、虎牙增强、SOOP/Twitch 和播放器/导航修复，并修复同步后斗鱼同包普通弹幕与 SC 解析回归。

## 弹幕生命周期

- 修复 GetX 响应式流桥接的真实断点：旧实现创建广播流时就注册上游监听，却把返回的注销函数交给 `onCancel`；竖屏列表进入 PiP 被销毁后，最后一个监听者会永久注销上游，随后重建只能订阅到仍打开但已断流的广播控制器。新实现严格在 0→1 个监听者时挂载上游、1→0 时卸载，取消后重订阅继续收到更新。
- Android 从系统画中画返回全屏或竖屏时，由持续存活的直播控制器发布恢复 revision；恢复先检查同房间传输健康度，健康连接保留，已断开的连接才原位重建。
- 弹幕列表重建后在首帧重新获取当前 500 条快照、提交待处理批次并恢复实时跟随；Android 只有存在真实触摸指针时才把拖动通知视为用户上滑，转场遗留通知不再暂停列表。
- 弹幕列表仅在 80 ms UI 批次落地时复制可见快照；本地消息仍立即同步到列表与画面。
- 弹幕文本解析、段落布局、图片和表情 Token 缓存全部改为有界 LRU；主画面和小窗分别使用符合轨道规模的缓存/对象池上限。

## 启动刷新与横屏交互

- 收藏房间在控制器初始化阶段先清除上一进程遗留的开播位，再立即核验；每个有界批次先更新内存状态，至少 20 个房间再合并持久化，兼顾新鲜度与滑动流畅度。
- 应用在后台停留超过 15 秒后返回，刷新当前热门/分区平台；单房间请求设置 12 秒上限，单个平台异常不会阻塞其余收藏。
- 横屏弹幕设置改为靠右紧凑侧栏，不再把小窗的长设置表单重复塞入直播设置；模板和数值继续实时作用于画面。
- 全屏底部左右控制组之间增加本地弹幕输入，沿用当前房间代次和 2 秒投递队列，防止延迟消息串入下一直播间。

## 性能与稳定性

- 切换清晰度、线路或刷新播放器前完整释放旧 `VideoController` 的弹幕引擎、计时器和订阅，修复 Windows 多次换线后的资源累积。
- 修复音量隐藏和配置去抖计时器未保存引用的问题；所有播放器计时器在销毁时统一取消。
- media_kit/mpv 直播前向缓存限制为 32 MiB、回看缓存限制为 4 MiB，保留 2 秒预读；该预算仍可覆盖约 8 秒的 32 Mbit/s 码流，同时缩短原生内存预热爬升。
- 同一 Bilibili 实时房间对照采样中，32/4 MiB 预算把 private bytes 峰值从 951.5 MiB 压到 738.2 MiB；6.5 分钟结束时 private bytes/工作集分别少 30.3/35.4 MiB，最后一分钟 private bytes 回落 5.1 MiB，句柄和线程没有单调增长。
- Windows 恢复鼠标拖动滚动，连续滚轮脉冲使用可重定向的 Chromium EaseInOut 轨迹合并；主画面弹幕限制高峰入场频率、可见数量和过期队列。
- 应用 UI 继续请求设备最高刷新率；自动弹幕渲染主画面限制 60 FPS、小窗限制 30 FPS，手动模式仍支持最高 240 FPS，避免视频、UI 与弹幕三套高频时钟同时拉满 CPU。
- 首页/设置阶段不再提前创建 MediaKit 原生播放器；FFmpeg、录制、解析与账号服务按真实功能入口加载，空 SC 列表也不再保留每秒唤醒定时器。
- Flame 弹幕引擎在等待队列和活动弹幕都为空时停止显示刷新循环，收到新弹幕再唤醒；热门卡片的加载占位改为静态图标，网格恢复独立重绘边界。
- 直播页和二、三级控制器显式释放全局 GetX Worker、滚动/刷新控制器、DLNA/FFmpeg 订阅与表情解码 Codec，避免关闭页面后仍保留整棵播放器和消息缓存。
- 播放器适配器公开类型安全的引擎/原生播放器访问接口；导航设置至少保留一个主页入口，修复全部隐藏后主页空白且无法返回设置的问题。
- 进入录制中心前先等待弹窗退场并卸载一帧原生视频层，返回后恢复同一直播会话，修复 media_kit 在路由叠加时的崩溃与画面遮挡竞态。

## 构建与核验

- Flutter 3.47.0 / Dart 3.13.0；Built-in Kotlin 审计和 Flutter Analyze 零问题。
- 189 项单元/Widget 测试及 26/26 平台公开接口探测通过。
- Android arm64 与 Windows x64 由本机构建；每个产物的提交、签名类型、ABI、版本与 SHA-256 记录在 `BUILD_METADATA.json` 和 `SHA256SUMS.txt`。

---

# Pure Live v2.2.0

这是播放器生命周期、弹幕稳定性与 Windows 桌面体验的阶段性稳定更新，并同步上游 `2f553c8b` 的弹幕字体粗细和相似文本过滤。

## 音频/视频无重开切换

- 音频与视频模式复用同一播放器、直播地址和纹理；前台保留视频热状态，优先实现即时返回。
- 后台立即停用视频轨以节省解码、GPU 和电量，回到前台后静默预热。
- 深度恢复使用最新目标栅栏、首帧合成宽限和有界等待；恢复期间显示可操作的渐变音频卡片和明确进度，不再用黑屏或整页转圈遮挡操作。
- 连续点击、房间重进、悬浮窗交接、横竖屏和后台恢复统一进入串行状态机，解决白屏、黑屏、永久加载和控制器错配。

## 弹幕与设置

- 竖屏、横屏和全屏共用同一弹幕设置界面，所有参数实时作用于画面。
- 主画面和小窗支持字体粗细；最佳/舒适/高密度模板及自定义模板同步保存和恢复粗细值。
- 增加精确重复文本合并和相似弹幕过滤；本地弹幕不参与过滤。
- 相似过滤的模糊比较上限固定为每条 96 次，屏蔽列表改用懒构建 Sliver，降低高弹幕量和长列表滚动时的主线程尖峰。

## Windows 与稳定性

- Windows 支持带独立数据目录的多实例启动，并防护非法实例 ID 和路径穿越。
- 优化二、三级页面鼠标滚轮、并行 Release 编译和非必要原生启动任务。
- 保留可选安装目录与安装目录 `AppData` 数据策略；旧配置、关注和缓存继续按升级迁移规则处理。
- 录制意外退出后按配置恢复监控；GitHub 更新源支持官方直连并限制镜像探测时间。

## 验证

- Flutter 3.47.0 / Dart 3.13.0；Built-in Kotlin 审计和 Flutter Analyze 零问题。
- 151 项单元/Widget 测试及 26/26 平台公开接口探测通过。
- Android 16 / 120 Hz arm64 真机覆盖安装，完成视频/音频重复切换、前台长驻、后台省电和回前台恢复回归。

---

# Pure Live v2.1.8

本版本撤销音频模式切换时销毁并重建原生播放器的高风险链路，修复点击耳机后持续加载、按钮锁死，以及音频模式返回/小窗重进后播放器状态错乱。

## 音频模式生命周期

- 音频/视频模式改为在同一个播放器与直播流上切换视频轨道，不再重新请求地址、关闭 CDN 流或重建 MediaCodec。
- 切换期间保留房间、弹幕、手势和播放器监听，不再调用会永久移除错误/音量/电池订阅的 `clearListener()`。
- 页面不再进入整块播放器加载态；原生轨道切换和媒体服务绑定均有 5 秒上限，失败后恢复原模式并释放按钮锁。
- `AudioService` 初始化改为共享同一个可完成 Future；初始化异常会传递给所有等待者并允许下次重试，不再以轮询方式永久等待空 handler。
- 退出直播统一经过媒体服务停止与播放器关闭流程，音频模式不再绕过媒体服务清理。

## 回归门禁

- 新增播放器身份、直播地址复用、超时回滚和按钮解锁测试。
- 正式包发布前必须完成 Android 真机“视频→音频→视频、返回→小窗→重进、连续重复点击”验收。

---

# Pure Live v2.1.6

本版本修复 Android 音频模式与视频模式反复切换后播放器区域变成灰白错误占位，以及音频模式退到桌面或锁屏后需要从通知栏再次点播放的问题。

## 音频/视频模式切换

- 模式切换由房间级局部防抖升级为播放器级串行队列；切换过程中收到多次操作时合并为最后一次目标状态，避免多个播放器初始化与销毁交叉执行。
- 先从 Flutter 组件树移除旧视频组件，等待原生 Surface 脱离后再销毁 MediaCodec/播放器，避免已销毁的视频控制器继续参与构建并触发发布模式灰色 `ErrorWidget`。
- 单次播放器构建固定使用同一个播放器引用，并校正历史画面适配索引；异步销毁无法再在外层空值检查与内层视频构建之间插入，触发空值断言。
- 新控制器暴露可等待的初始化任务，队列在播放初始化结束前保持占用；播放器硬销毁同时作废旧会话，迟到结果不会重新绑定已销毁的播放器。
- 重播保留当前音频模式，不再因重试路径遗漏 `audioOnly` 状态而意外切回视频。

## 后台音频（issue #750）

- 后台播放策略显式包含“当前房间处于音频模式”，即使通用后台播放开关关闭，主动切入音频模式后退到桌面或锁屏也会继续播放。
- 前台生命周期不再对允许后台播放的流主动调用 `resume()`，避免把用户手动暂停的直播错误恢复。
- 通知栏媒体会话、CPU/Wi-Fi 保活与 Flutter 生命周期共用同一后台策略；播放器重绑定改为可等待操作，并消除音频会话尚未初始化完成的竞争窗口。

## 验证

- Flutter 3.47.0 / Dart 3.13.0，Built-in Kotlin 审计、Flutter Analyze、完整自动化测试与公开接口探测。
- Android 16 / ColorOS 真机覆盖安装，执行连续音频/视频切换、退到桌面和媒体会话状态回归。

---

# Pure Live v2.1.5

本版本集中修复本地弹幕投递、Android 弹幕列表阅读、弹幕模板状态和 Windows 鼠标滚轮顿挫，并从同一源码提交重新生成全平台安装包。

## 本地弹幕与列表阅读

- 本地用户发送弹幕后等待 2 秒，由同一投递回调同步加入弹幕列表和直播画面；播放器启动或短暂缓冲期间也保留本地画面弹幕。
- 待发送消息绑定当前房间代次，切换直播间或关闭控制器时统一取消，避免延迟消息进入其他直播间。
- Android 竖屏列表在第一次真实手指拖动时立即暂停自动跟随，不再等待移动超过固定距离；阅读期间冻结可见快照并累计新消息数量。
- 程序自动滚动不会误触发阅读暂停；回到底部或点击“回到底部”后一次同步当前消息。

## 弹幕模板

- “最佳观看、舒适、高密度、默认”改为根据当前实际区域、速度、字号、描边、透明度和动态 FPS 参数计算选中状态。
- 切换模板后选中项立即跟随；手动调整任意参数后清除模板选中，解决操作结果与界面标记不一致。

## Windows 平滑滚动

- Windows 离散鼠标滚轮增量使用 Chromium Impulse 动画轨迹，连续滚轮输入合并到同一目标，减少逐格跳变造成的顿挫。
- 首页、热门、分区、收藏、搜索、直播弹幕列表、节目单和弹幕设置页统一接入；Android 触控继续使用原生滚动控制器。
- Windows 安装程序继续支持选择其他磁盘，便携包和安装器均保持安装目录 `AppData` 数据策略。

## 验证与构建

- Flutter 3.47.0 / Dart 3.13.0，Built-in Kotlin 审计与 Flutter Analyze 零问题。
- 92 项单元/Widget 测试及 26/26 平台公开接口探测通过。
- Android arm64、Windows x64、Linux x64、macOS universal 和 iOS arm64 设备归档从 v2.1.5 源码重新构建；Android 使用正式持久签名。

---

# Pure Live v2.1.4

这是一次阶段性全平台更新：同步上游 `5d3e526a` 的 SOOP Live 当前播放与链接兼容修复，并汇总 Bilibili 热门封面、Windows 高刷新率、桌面交互性能、安装目录数据迁移和跨平台构建工程。

## 上游同步与平台接口

- SOOP Live 同步当前 `player_live_api`、RMD/CDN 地址分配、聊天室端口和播放令牌逻辑，并同时识别 `sooplive.com` 与 `sooplive.co.kr` 链接。
- Bilibili 热门由持续触发 `-352` 风控的旧分区接口切换到当前匿名推荐接口，提供有界重试、独立匿名回退和响应结构校验。
- 推荐分页增加房间去重、无进展终止和最大请求数；固定批量或重复响应不会生成重复卡片或无限补页。
- Bilibili 图片域名补齐浏览器请求头；房间、头像与分区封面统一使用稳定磁盘缓存键，避免刷新时间戳造成重复下载与缓存膨胀。

## Windows 高刷新率与流畅度

- 原生 Runner 读取窗口所在显示器的分辨率、当前刷新率、同分辨率最高刷新率与支持列表；跨显示器或显示模式变化后自动刷新。
- 本机 3840 × 2400 / 200 Hz 已正确识别。Flutter 渲染跟随 Windows 垂直同步，不在应用内强制修改系统显示模式。
- Windows 次级页面使用轻量前进转场，滚动统一桌面夹持物理模型，拖动时自动收起键盘。
- 修复收藏页在响应式重建中重复注册平台切换监听器的问题，减少运行时间增长后的切页和刷新抖动。
- 头像取消列表批量淡入动画，封面复用稳定缓存；窗口移动时先做轻量显示器身份判断，避免每个移动消息枚举全部显示模式。

## 安装、数据与全平台构建

- Windows EXE 保留目录选择和安装目录 `AppData`；设置、关注、历史、IPTV、录制与缓存继续支持旧安装位置合并和迁移前回滚备份。
- Android 保持正式包名 `com.mystyle.purelive`，提供 arm64-v8a 持久签名 APK，可覆盖旧正式版。
- 构建矩阵包含 Android arm64、Windows x64 EXE/便携包、Linux x64、macOS universal ZIP/DMG 与 iOS arm64 未签名设备应用归档。
- 阶段工作流统一使用带 build number 的规范化附件名，普通提交不自动触发跨平台构建。

## 验证

- Flutter 3.47.0 / Dart 3.13.0，Built-in Kotlin 审计与 Flutter Analyze 零问题。
- 82 项单元/Widget 测试、26/26 平台公开接口探测通过。
- Windows x64 release、本机高刷新率信息、Bilibili 热门页与封面完成编译和界面烟雾验证。

---

# Pure Live v2.1.2

本版本是 Windows 数据安全与流畅度专项更新，重点解决换盘安装、从 2.0.x/2.1.1 升级后关注丢失，以及桌面端列表、切页和窗口缩放时的卡顿。已同步上游 `222b3bfb`。

## Windows 安装与集中数据

- EXE 安装向导保留目录选择页，可安装到 C 盘之外的可写目录，并统一使用当前稳定 AppId。
- Hive 配置、关注、历史、屏蔽规则、IPTV、录制、图片/表情/插件缓存和应用临时文件统一收口到 `{app}\AppData`。
- `path_provider`、`shared_preferences`、IPTV/EPG 同步临时文件和录制缓存共用安装目录路径，避免持续在系统盘分散业务数据。
- 卸载/重装保留 `AppData`；换盘时安装器记录上一个安装位置，新版首次启动再自动导入。

## 配置升级与关注恢复

- 修复 2.0.x 使用 `List<String>`、2.1.x 使用 JSON `{"list": [...]}` 后，仅复制 Hive 文件却读取为空的根因。
- 在所有设置控制器初始化前执行原始 Hive 升级，合并历史安装目录、Documents 旧数据和大小写不同的 `PureLive/pure_live`。
- 关注按平台与房间号去重，同时合并历史、分区、WebDAV、屏蔽用户/关键词和菜单配置；目标已有新配置时不被旧标量覆盖。
- 迁移前创建带来源清单的 Hive 回滚备份；导入指纹避免重复，锁定/损坏源留待后续启动重试。
- 应用正常退出前主动 `flush()` 设置，降低快速重启或更新过程中末次配置丢失的概率。

## Windows 滑动与交互性能

- 移除同一列表的重复指针与滚动通知监听，回到顶部/底部动画按距离动态控制时长。
- 首页和分区页只在 Tab 完全停稳后触发数据加载，避免横滑中间帧发起网络请求与网格重建。
- 收藏、首页、分区、搜索根据桌面端使用适应的懒加载范围和稳定 Key，避免重复 keep-alive/repaint 层。
- 分区封面加载状态改用静态占位，降低多张动画在滚动中同时重绘的压力。
- Windows 窗口拖动和缩放时把密集原生尺寸请求合并到 80 ms 稳定帧，减少布局颠簸。

## 更新链路与构建

- 应用内版本检查、历史记录、Issue 和 Release 链接恢复到 `liuchuancong/pure_live`。
- 修正 Android arm64、Windows EXE/便携 ZIP 和 macOS universal ZIP 的实际附件名，不再展示本轮没有生成的 arm32/x86_64 APK 与 MSIX。
- 更新源按平台发布状态选择版本，Windows 专项版不会让 Android/macOS 客户端获取到尚未发布的附件。
- 本机质量门禁通过：Built-in Kotlin 审计、Flutter Analyze 零问题、76 项单元/Widget 测试、25/25 平台接口探测通过。

---

# Pure Live v2.1.1

本版本集中修复观看口径设置空白、首页平台横滑掉帧和跨平台搜索能力不透明的问题，并继续以 Android arm64 与 Windows x64 为本机优先构建目标。

## 设置与首页流畅度

- 修复“真实在线平台开关”中仅提供热度的平台仍被错误包入无响应式读取的 `Obx`，导致 GetX 拒绝构建并只留下大块灰色卡片的问题。
- 支持真实在线的平台继续提供独立开关；Bilibili、斗鱼、虎牙等仅提供热度的平台显示禁用状态、数据来源和口径说明。
- 首页手势横滑到半程时不再提前启动目标平台网络请求和网格重建；页面完全停稳后再加载，并保留已构建页面、列表与滚动位置。
- 平台目录一次建立 ID 索引，避免按每个已启用平台重复实例化全部适配器；直播卡片使用稳定 Key，减少切页时的无效重建。

## 跨平台搜索

- 搜索页增加“包含未开播”筛选，以及综合、平台顺序、观众优先、粉丝优先四种排序。
- 综合排序固定直播中的房间优先，再比较当前观看口径、粉丝数和主页平台顺序；平台优先直接使用用户在主页平台设置中的拖动顺序。
- 每个平台独立维护翻页结束状态，空页、重复页和非分页来源会停止继续请求，避免反复拉取相同结果。
- 搜索页动态显示当前平台覆盖范围：Bilibili、斗鱼、网易 CC、Twitch 可返回部分未开播结果；虎牙、抖音、SOOP 主要返回当前直播；快手使用网页搜索；IPTV 搜索本机导入频道。
- Bilibili 与网易 CC 搜索结果补充可用粉丝字段；平台响应缺少粉丝数时保持稳定次序，不以热度冒充粉丝。

## Windows 安装与小窗

- Windows 安装向导固定显示安装目录页，首次安装和覆盖更新都可以浏览并选择其他磁盘，同时保留用户上次选择的目录。
- Windows 小窗改为默认普通窗口层级，切换到其他应用后可以被其覆盖；播放行为设置增加“小窗始终置顶”开关，需要时可恢复置顶并立即生效。

## 构建与验证

- Built-in Kotlin 审计与 Flutter Analyze 零问题，71 项单元/Widget 测试通过。
- 25/25 平台公开接口探测通过，覆盖分类、推荐、搜索、弹幕节点、房间元数据和播放令牌。
- Android 继续使用正式包名 `com.mystyle.purelive`，优先生成 `arm64-v8a` release；Windows 生成 x64 便携 ZIP 与可选择安装目录的安装程序；Linux、macOS 与 iOS 补齐对应平台归档。

---

# Pure Live v2.1.0

这是一次阶段性大更新：同步上游 `24ff92b6`（2026-08-18）的 Twitch、SOOP Live 与网页内核更新，并汇总此前完成的弹幕稳定性、小窗、120 Hz、播放、助眠、本地互动、Built-in Kotlin 和本机发布工程。

## 上游同步、Twitch 与 SOOP Live

- 新增 Twitch 分类、推荐、频道搜索、房间详情、直播清晰度、外部打开、Cookie 设置和 IRC 弹幕。
- Twitch `viewersCount` 作为真实并发人数进入显示、筛选和排行；本地互动同步增加 Twitch 徽章、Bits、订阅等级与礼物体验包。
- Twitch IRC 解析支持无颜色用户、转义显示名、用户 ID、消息 ID、平台时间与多行数据；登录 Cookie 中的 `auth-token`/`login` 用于聊天认证。
- 新增 SOOP Live 分类、推荐、搜索、房间详情、播放线路、Cookie、弹幕、并发在线人数、链接识别与本地互动体验包。
- 接口探测从 15 项扩展为 25 项，覆盖 Twitch 与 SOOP Live 的分类、目录/推荐、搜索、房间元数据和播放令牌。

## 弹幕、依赖与界面

- 主画面和小窗增加“纯文字模式”，小窗预览实时反映该开关；兼容上游旧存储键。
- 合并 `file_picker 12.0.0` 稳定 API、`windows_single_instance 1.2.0`、锁定修订版 `flutter_inappwebview 6.2.0-beta.3`、默认音量百分比修正和网页关闭清理；补齐网页内核的 AGP 9 / R8 兼容补丁，Linux 网页搜索使用系统浏览器。
- 继续保留统一 px/s 速度、动态跟随屏幕最高刷新率、过期队列淘汰、房间会话隔离、手机固定小窗预览和 AGP 9 Built-in Kotlin 修复。
- 更新仓库说明、平台兼容表、依赖审计和阶段更新文档。

## 全平台构建

- Android arm64 与 Windows x64 继续优先在本机完成质量门禁、正式构建和启动验证。
- 阶段工作流扩展到 Linux x64、macOS universal 和 iOS arm64 设备编译；Apple 两个平台共用一次 macOS 作业。
- Linux 使用 Ubuntu 24.04 构建，以匹配当前锁定 `libmpv` 的 glibc/GLIBCXX 基线；macOS 主程序实测同时包含 x86_64 与 arm64。
- iOS 生成无签名设备 `.app` 归档，供后续证书签名与 IPA 封装。
- Built-in Kotlin 审计与 Flutter Analyze 零问题，64 项单元/Widget 测试及 25/25 平台接口探测通过。

---

# Pure Live v2.0.36

本版本集中修复 Android 系统画中画切换停顿、手机长设置页看不到小窗弹幕预览、哔哩哔哩访客昵称脱敏来源不清，以及热度/在线人数切换与排行不一致的问题。

## 画中画与设置预览

- 进入 Android 系统画中画前先构建并渲染紧凑视频层，复用同一播放器 Element，减少 Texture 重新挂载时出现的应用图标、黑帧和画面延迟。
- 向系统传入当前视频物理边界 `sourceRectHint`；Android 12+ 启用视频无缝缩放，并移除播放器上内容相同的二次 `AnimatedSwitcher`。
- 画中画状态探测周期从 10 ms 调整为 100 ms，显著减少普通播放期间持续的平台通道压力。
- 手机端小窗弹幕设置改为“上方固定预览 + 下方独立滚动参数”，桌面/平板使用双栏布局；字号、颜色、速度、密度、透明度、区域和 FPS 继续实时作用于预览。

## 弹幕昵称

- 当前哔哩哔哩访客 WebSocket 会话实测会同时脱敏旧用户名、rich user 名称与 UID；这是平台返回数据，并非客户端把昵称改成星号。
- 解析器优先读取新版 `info[0][15].user.base.name`，登录会话返回完整 rich user 时直接显示完整昵称；访客仍收到脱敏值时，弹幕列表只提示一次数据来源与登录入口。
- 新增新版 rich user、脱敏兼容和累计观看消息回归测试。

## 热度、在线与累计观看

- WebSocket 观看更新改为带类型数据：哔哩哔哩 operation 3 只更新热度，`WATCHED_CHANGE` 只更新本场累计看过；抖音 `onlineUserForAnchor` 只更新并发在线。
- 虎牙弹幕同步到当前网页协议：使用 `wsapi.huya.com`、房间组注册与批量推送；实连确认列表/详情的 `totalCount/userCount` 及直播间 URI 8006 `iAttendeeCount` 都处于同一热度口径，不再标成真实在线人数。
- 平台能力与房间当前是否已取得数值分离：抖音/快手/网易 CC 可从列表或详情取在线；哔哩哔哩、斗鱼和虎牙公开数据继续按热度/累计口径标注。
- 真实在线模式下，支持平台尚未取得明确值时显示“待刷新”，几百万热度不再代替在线数参与排行；不支持并发人数的平台排在支持平台之后。
- 收藏和搜索结果监听全局口径与分平台开关，切换后立即重新排序。

## 验证与构建

- Flutter Analyze 零问题，59 项单元/Widget 测试通过；15/15 平台公开接口探测与虎牙当前 WebSocket 实连通过。
- Android 继续优先构建正式包名 `com.mystyle.purelive` 的正式签名 `arm64-v8a` APK，并在连接设备上覆盖安装验证。

---

# Pure Live v2.0.35

本版本修复真机回归中发现的哔哩哔哩热门直播间热度偶发显示为 `1`，并完成 Android 120 Hz、游客弹幕、横竖屏、小窗、纯音频和后台播放链路验收。

## 观看指标稳定性

- 进入同一直播间时合并列表、详情接口和弹幕心跳中的观看指标，详情接口短暂返回哨兵值时保留列表中的可靠热度。
- 哔哩哔哩热门房间从千级以上瞬时骤降至 `1` 时不再覆盖现有热度；后续数值合理的实时心跳仍会正常刷新。
- 运行时观看指标忽略无效零值，在线人数、累计观看与平台热度继续使用各自独立字段和标签。

## 真机验收

- OnePlus Android 16 arm64 真机覆盖安装保留应用数据；多次冷启动无崩溃，前台窗口和弹幕动画以设备最高 120 Hz 运行。
- 哔哩哔哩游客直播间弹幕连续刷新；竖屏、横屏、全屏及系统画中画均验证画面弹幕，设置页字号预览实时变化。
- 纯音频切换、系统媒体会话、前台服务通知、Partial WakeLock 与 Wi-Fi Lock 均通过后台探测。

## 构建与验证

- 本机质量门禁覆盖 Built-in Kotlin 审计、Flutter Analyze、完整测试及 15 个平台接口探测。
- Android 继续优先生成正式包名 `com.mystyle.purelive` 的正式签名 `arm64-v8a` APK。

---

# Pure Live v2.0.34

本版本完成 Android AGP 9 Built-in Kotlin 迁移，并升级本机构建工具链，重点解决第三方插件各自加载不同 Kotlin/AGP 版本造成的配置冲突和后续 Flutter 兼容风险。

## Android 构建工具链

- Android Gradle Plugin 升级到 9.3.1，Gradle Wrapper 升级到 9.5.0；compileSdk/targetSdk 继续使用 API 37。
- 主应用和本地插件移除 `kotlin-android`、独立 KGP classpath、旧 `android.kotlinOptions` 以及把 Kotlin 目录挂到 Java source set 的旧配置。
- Java 25 用作 Gradle/lint 构建运行时，应用和插件产出的 Java/Kotlin 字节码统一为 17，兼顾新工具链与 Android 运行版本。
- 长路径 Windows 工作区继续使用稳定短盘符；针对 Pub Cache 与工作区跨盘，关闭会损坏可迁移缓存的 Kotlin 增量模式。

## 插件兼容与依赖

- 内置 `better_player_plus`、`floating`、`flutter_exit_app`、`flutter_js`、`mobile_scanner`、`share_handler_android` 的最小兼容补丁，并保留各自许可证、上游地址和原版本。
- `flv_lzc` 同步迁移到 Built-in Kotlin；所有本地插件统一复用根项目 AGP，不再把旧 AGP 带入 lint/构建 classpath。
- 所有直接运行时依赖仍处于当前可解析最新版；`pub outdated` 剩余更新均为 Flutter SDK或上游约束锁定的传递依赖，未使用破坏兼容性的强制覆盖。

## 自动回归

- 新增 `tool/audit_built_in_kotlin.py`，在本地 CI 中检查工具链下限、Built-in Kotlin 开关和所有本地 Gradle 模块，阻止旧 KGP/AGP classpath 重新进入项目。
- GitHub 手动构建同步使用 Java 25；本机仍优先生成正式包名 `com.mystyle.purelive` 的 `arm64-v8a` APK，Windows x64 按需构建。

## 验证结果

- Built-in Kotlin 审计和 Flutter Analyze 零问题，49 项单元/Widget 测试及 15/15 平台接口探测通过。
- Android `arm64-v8a` release 编译通过，APK 包名 `com.mystyle.purelive`、版本 `2.0.34 (2045)`、targetSdk 37、单一 arm64 ABI 与 v2 签名结构核验通过。
- Windows x64 release 编译通过；便携程序持续启动 20 秒，进程存活、主窗口响应、MediaKit D3D11 与 FFmpeg Kit 正常加载。

---

# Pure Live v2.0.33

本版本集中重构弹幕房间会话、协议去重、积压队列和高刷新率运动时钟，修复串房、旧消息重放、偶发停更、重复循环以及横竖屏/小窗切换后的不稳定问题，并同步优化 Android 与 Windows 的弹幕列表和设置页面滚动。

## 弹幕连接与房间隔离

- 所有房间切换、设置开关和小窗销毁操作进入串行会话队列；回调携带平台、房间与会话编号，旧 WebSocket 的迟到消息不会进入新房间。
- 房间详情请求增加代次校验，快速切房或切换线路时丢弃上一房间的迟到响应，避免旧详情重新覆盖当前播放器和弹幕连接。
- WebSocket 关闭改为可等待的完整清理，连接代次同时约束消息、错误和关闭事件；Bilibili、抖音、斗鱼、虎牙都在重启前释放旧连接并清空全部回调。
- 应用悬浮窗离开直播页后保留轻量弹幕会话，关闭悬浮窗时再按顺序停止连接、清空画面和释放控制器；重新进房不会继承残留队列。

## 平台协议稳定性

- Bilibili 读取弹幕时间戳和消息随机 ID；抖音校验消息内房间 ID，并保存消息 ID、用户 ID 和发送时间；斗鱼校验 `rid/cid/cst`，虎牙补充用户 ID。
- 稳定平台消息 ID 使用 10 分钟重放窗口，无 ID 平台使用 2.5 秒短指纹窗口；超过 45 秒的平台历史消息直接丢弃，兼顾断线去重和正常重复发言。
- 修正抖音 ACK 将扩展游标误写到 `payloadType` 的问题，并兼容压缩标记缺失但具有 GZip 文件头的响应。
- 斗鱼现在解析同一 WebSocket 帧内的全部协议包，不再只处理第一条造成热门房间间歇性漏弹幕。

## 渲染、速度与列表

- 主画面与小窗等待队列分别限制为 120/36 条，并淘汰 5/3 秒未取得轨道的消息，轨道拥堵或应用恢复后不再补放几分钟前的内容。
- Flame 弹幕改用受帧间隔约束的逻辑时钟，后台恢复不产生大跨度跳动；所有轨道严格使用用户设置的同一 px/s 速度，Android、横竖屏、小窗与 Windows 表现一致。
- 修正 20% 显示区域被重复计算成 4% 的轨道高度问题；补全字体、描边与颜色缓存键，样式调整后相同文字也会立即使用新画面。
- 弹幕历史按 32 ms 批量合并，移除逐条复制 500 条列表和重建直播页的路径；上滑阅读时只更新独立新消息计数，列表使用反向懒加载并降低预缓存范围。
- 屏蔽管理改为虚拟化 Sliver 列表，弹幕设置按区域局部响应式更新；移除列表每行阴影，改善 Android 120 Hz 与 Windows 鼠标滚轮滚动。

## 验证与构建

- Android 继续优先构建正式包名 `com.mystyle.purelive` 的 `arm64-v8a` 安装包。
- Windows x64 使用同一会话、队列、逻辑时钟和滚动实现，并重新生成便携包/安装器。
- 新增平台消息时间、房间校验、重复抑制、斗鱼合帧解析和渲染队列上限回归测试。
- Flutter Analyze 零问题，49 项单元/Widget 测试和 15/15 平台接口探测通过；Android arm64、Windows x64 编译及 Windows 启动响应探测通过。

---

# Pure Live v2.0.32

本版本重新校正观看数据口径，重做三类定时器的名称与交互，完善画面弹幕的实时样式、模板和点击操作，并将本地互动扩展为六个平台体验包。

## 观看数据与排行

- `LiveRoom` 分别保存平台热度、真实并发在线和本场累计观看，旧版 `watching` 字段只用于备份兼容。
- 增加“平台热度优先 / 真实在线人数优先”全局排行方式，以及抖音、快手、网易 CC 的独立真实在线开关。
- 虎牙列表/详情的 `totalCount`、`userCount` 以及房间 URI 8006 `iAttendeeCount` 都按热度处理；抖音 `display_value/total_user` 保留为累计观看，`user_count/onlineUserForAnchor` 按在线人数处理。
- 哔哩哔哩 `online`/心跳和斗鱼 `ol/hot` 保留热度标签，避免把几百万热度误显示为同时在线人数。

## 助眠与定时器

- “新直播间自动助眠”仅决定新房间是否自动进入纯音频；耳机按钮只切换当前房间，电视按钮仍为投屏。
- 自动助眠停止时长支持快捷选项和 1 分钟至 365 天任意分钟输入，重新排版输入框与操作按钮，解决窄屏文字重叠。
- 直播间菜单改名为“当前直播间播放定时器”，到时暂停当前直播和后台音频；通用设置改名为“应用定时退出”，到时退出整个应用，三种行为互相独立。

## 弹幕与交互

- “最佳观看”模板调整为画面顶部约 20%，速度 118 px/s、字号 16 px、描边 1.5 px；舒适与高密度模板分别占顶部约 35% 和 55%。
- 设置页的区域、速度、字号、描边、透明度和帧率通过同一响应式控制器立即更新直播画面，并补充单位和实时生效说明。
- 修正描边值被错误映射成字体粗细的问题；描边宽度改为 0–4 px 连续值。
- 画面弹幕点击/长按默认启用，指针统一从全局坐标换算到弹幕画布坐标，竖屏、横屏和全屏均与单击播放、双击全屏等手势分流。
- 弹幕操作面板打开时暂停画面弹幕，下滑关闭后继续；弹幕列表上滑阅读时冻结快照，回到底部后再同步新消息。

## 本地互动与播放器

- 六个平台体验包分别提供主题色、身份徽章、等级称呼、本地体验币和礼物目录，可单独控制身份、等级与礼物画面效果。
- 高价值本地礼物在直播画面显示更醒目的主题横幅；所有充值、等级、弹幕和礼物记录仍只保存在本机。
- `video_player` 更新至 2.14.0，`better_player_plus` 1.3.5 与 MediaKit 修订分支最新固定提交完成兼容复核。

## 构建目标

- Android 正式包名保持 `com.mystyle.purelive`，本地优先构建 `arm64-v8a`。
- Windows 构建继续按需执行，本版本发布先提供 Android arm64 安装包。
- Flutter Analyze 零问题，39 项单元/Widget 测试与 15/15 平台接口探测通过。

---

# Pure Live v2.0.31

本版本修正直播间顶部栏空间分配与音频/投屏图标语义，并完成 ASMR 自动助眠和房间纯音频的最终解耦。

## 直播间布局

- 手机端将“已关注/关注”和“录制/监控中”收敛为带长按提示的紧凑图标，主播头像、名称和分区使用剩余宽度并自动省略。
- 平板和桌面继续显示文字按钮，关注、录制状态与原操作流程保持一致。
- 修复主播昵称为空时取消关注弹窗的空值崩溃点。

## 音频、投屏与 ASMR

- 播放画面右上控制顺序统一为“耳机纯音频 → 电视投屏 → 小窗播放”；耳机在启用纯音频后保持耳机形状并高亮，电视图标仅表示 DLNA 投屏。
- 移除房间月亮按钮和播放器内核页的遗留全局纯音频默认项，手动耳机切换仅对当前房间生效，切换房间后重新遵循 ASMR 设置。
- 新增一次性配置迁移，清理旧版 `audioOnly` 持久值；ASMR 关闭时，新打开或切换的直播间从视频模式开始。
- ASMR 开启时，新房间自动进入纯音频、启用后台保活和停止计时；手动恢复视频同步结束该次助眠计时。
- 关闭设置页 ASMR 开关时立即撤销活动中的助眠计时。
- 纯音频和视频切换复用当前清晰度与播放线路，省去房间详情、清晰度和地址的重复网络获取，缩短切换等待。

## 验证

- Flutter Analyze 零问题。
- 30 项单元测试与 Widget 测试全部通过。
- Android 优先构建 `arm64-v8a`。

---

# Pure Live v2.0.30

本版本集中修复 ASMR 状态、Bilibili 访客弹幕、横屏弹幕、列表阅读、首次启动与直播首帧问题，并补齐动态弹幕帧率、平台人数口径和本地互动输入。

## ASMR 与后台播放

- 设置页“进入直播自动启动助眠”只控制新房间默认行为；直播间月亮按钮只控制当前会话；通用纯音频偏好保持独立。
- 增加 v2.0.29 遗留状态一次性迁移，关闭 ASMR 后新房间恢复画面。
- 停止时间支持预设和 1–720 分钟自定义输入。
- 音频模式直接使用播放器原生音频输出，移除 FFmpeg 二次解码、固定等待和管道超时。
- 媒体前台服务在短暂中断期间保持，CPU/Wi-Fi 锁按播放会话同步；定时到点完整停止并释放资源。

## 弹幕

- Bilibili 房间播放和弹幕发现解耦；token、buvid 与 WebSocket 节点支持后台刷新、认证拒绝重取和有界重连。针对部分移动 DNS 不解析区域 comet 域名的情况，优先连接官方通用网关，再轮换区域节点。
- 访客 `uid=0` WebSocket 实连通过，公开直播弹幕接收不依赖账号登录。
- 横竖屏切换只保留一个 Flame 弹幕引擎，修复共享控制器被旧过渡页面解绑的问题。
- 弹幕 FPS 参数进入引擎更新调度；主播放器与小窗支持动态跟随设备最高刷新率。
- 新增最佳、舒适、高密度模板，支持保存和恢复自定义模板。
- 画面弹幕提供可选点击和长按操作；弹幕列表长按/右键可复制、屏蔽用户或屏蔽关键词。
- 用户上滑列表后冻结当前快照并累计新消息，回到底部时一次同步；列表容量提升到 500 条并以 80 ms 合帧更新。
- 修正自定义字体与描边下的顶部裁切，轨道高度随字号动态调整。

## 互动、人数与流畅度

- 本地互动开关启用后，弹幕列表底部直接显示输入框；本地弹幕可进入列表和画面弹幕。
- 六个平台分别提供礼物目录、等级徽章和高价值礼物效果标记，充值、等级、头衔和历史仅保存在本机。
- 新增“优先显示真实在线人数”和平台支持说明；虎牙/快手显示在线人数，其他平台保留热度、累计观看或粉丝等原生统计口径。
- Android 与桌面列表采用夹持滚动物理模型，iOS/macOS 保留弹性模型；全应用页面移除统一强制弹簧阻尼。
- 收藏刷新改为整批只持久化一次并保留本地标签，减少热门房间定时刷新造成的 Hive 放大写入与界面抖动。
- MediaKit 修正探测参数名，将直播流分析窗口缩短至 2 秒、网络超时收紧至 15 秒；Bilibili CDN 请求头移除错误的 API authority。
- 播放器原生音量、房间持久值和控制栏改用同一响应式状态。

## 启动与稳定性

- 数据库、设置、自定义字体和直播页必需依赖在首屏前完成注册，修复更新安装后首次点击闪退与搜索结果快速进房竞态。
- 保留 Room 生成数据库的反射构造器，修复 release 混淆后 WorkManager 在 Flutter 首帧前崩溃。
- 内置修订版 `flv_lzc`，移除插件注册阶段创建临时 `SurfaceTexture` 的探测代码，修复 Flutter 3.47 下偶发原生 `registerTexture` 终止。
- 后台媒体通知只显示直播流实际支持的播放/暂停与停止动作，并保留其图标资源，消除 release 资源压缩后的通知动作异常。
- 直播路由增加防重复推入，避免连续点击创建多个播放器会话。
- 自定义字体在首个 ThemeData 构建前注册，重启后首次界面直接应用选择。

## 依赖与验证

- `synchronized` 更新至 3.4.1+2；其余直接运行时依赖复核为当前上游版本或固定 Git 提交。
- Flutter Analyze 零问题（固定的第三方播放器源码独立排除）。
- 28 项单元测试与 Widget 测试全部通过。
- 平台接口探测 15/15 通过；Bilibili 访客弹幕 WebSocket 认证与通知帧实连通过。
- Android 16 / 120 Hz 真机覆盖安装后连续 5 次冷启动均一次进入，启动耗时 239–274 ms；崩溃缓冲区中 `FATAL`、WorkDatabase 与 `registerTexture` 均为 0。
- 同一真机确认 Bilibili 视频与实时弹幕在竖屏、横屏均显示，本地弹幕输入框可用；系统为应用分配并请求 120 Hz。
- Android 优先构建 `arm64-v8a`，Windows 仅构建 x64。

## 下载说明

- Android 正式包名保持 `com.mystyle.purelive`。
- 使用 `SHA256SUMS.txt` 校验本机构建产物。
