# 应用组合与需求边界(多 App monorepo)

> 本文是 [../adr/0022-multi-app-one-feature-each.md](../adr/0022-multi-app-one-feature-each.md) 的执行面:
> 四个 App 各要做什么、不做什么、消费 `packages/` 的哪些包、组合根装配什么。
> 需求与验收以此文为准;分层与依赖方向仍以 [dependency-rules.md](dependency-rules.md) 为准。

## 1. 产品矩阵

| App | 一句话产品 | 主输入形态 | 首要平台 | 明确非目标 |
|---|---|---|---|---|
| `apps/pure_live` | 直播观看器:多站点直播聚合 + 低延迟换源 | native Dart 站点适配器 | Android / Android TV / Windows | 不做 JS/Python 插件宿主、不做 TVBox 导入、不做音乐与长视频业务 |
| `apps/pure_bili` | B 站视频客户端(参照 newBV) | native bilibili vod 适配 | Android / iOS | 不做直播、不做外部源导入、不做弹幕发送(只渲染) |
| `apps/pure_music` | 音乐播放器:lx 音源 + B 站音源/歌单导入 | 音源脚本 + 导入配置 | Android / iOS | 不做视频画面、不做直播、不做 TVBox |
| `apps/pure_tvbox` | TVBox 兼容客户端:导入即运行 | 单仓/多仓/JSON/M3U/EPG + JS/Python spider | Android TV / Android / Windows | 不内置任何 native 站点(壳里不写站点) |

四个 App 共享同一套工程规范([../DEVELOPMENT_STANDARDS.md](../DEVELOPMENT_STANDARDS.md))、同一套设计令牌
与同一份 `packages/`;**彼此之间不得有任何依赖**(含 dev/test 依赖),由护栏机械强制。

## 2. 每个 App 的核心流程(需求最小完备集)

### 2.1 pure_live(直播)

```
启动 → 组合根装配(存储/网络/缓存/任务/能力注册表)→ 注册 native 源
 → 首页:直播分区(Feed 聚合)+ 关注/收藏 + 续看
 → 房间页:resolve 出票 → 播放内核 → 换源状态机(失败自动回滚到上一路)
 → 退出:进度落盘(history.record/finish)
```

必备:分区浏览、搜索(跨源扇出 + 逐源失败隔离)、清晰度/线路选择、D-pad 焦点序、后台任务(EPG/仓库刷新)、
凭据与 Cookie 租约(huya antiCode 一类)、崩溃后可恢复到同一房间。
非目标:导入外部脚本源。

### 2.2 pure_bili(B 站视频)

```
启动 → 注册 bilibili vod 源 → 热门/动态信息流 → 详情(pages 全成剧集)
 → 播放(tourist try_look / 登录后高清)→ 弹幕渲染(只读)
```

必备:登录(扫码/cookie)、历史续播、收藏/稍后再看、清晰度与编码选择、弹幕渲染、竖屏信息流与横屏播放器
两套布局。非目标:多站点聚合、外部源导入。

### 2.3 pure_music(音乐)

```
启动 → 导入 lx 音源脚本 / bmsc 式 B 站音源与歌单 → 歌单与队列
 → 播放(歌词 LRC/YRC/QRC)→ 搜索(跨音源扇出)→ 落盘收藏/历史
```

必备:音源导入与校验(外部输入按不可信处理)、队列与播放模式、歌词同步、跨源同内容身份(同一首歌多源
可比对)、下载/缓存策略。非目标:视频播放面。

### 2.4 pure_tvbox(TVBox 兼容)

```
启动 → 导入单仓/多仓(校验永远先于执行)→ 站点按 api 后缀选运行时(.js→fjs / .py→CPython / 内置)
 → 首页直播区(M3U lives)+ 影视海报区(spider 站点)
 → 分类树 → 详情/剧集 → 房间播放 → 插件管理页(启停/卸载/诊断)
```

必备:spider 契约全方法集、drpy 兼容层、jar/csp/相对路径的逐站点降级与如实记账(pending 不假装能播)、
权限天花板(网络白名单/体积/超时/并发)、卸载只删代码不删用户数据。非目标:内置 native 站点。

## 3. 包 → 消费者矩阵

规则:**一个包至少要有一个 App 消费**;没有消费者的包不进入重写队列(要么并入某 App,要么删除)。
下表是重写的范围依据,`—` 表示该 App 不装配。

| 包(层/短名) | live | bili | music | tvbox | 备注 |
|---|:--:|:--:|:--:|:--:|---|
| foundation/utils, logging, network, storage, files, cache, events, diagnostics, l10n, platform_info, release | ✓ | ✓ | ✓ | ✓ | 全员叶子底座 |
| foundation/auth | ✓ | ✓ | ✓ | ✓ | 站点凭据 / 登录态 |
| foundation/backup, sync | ✓ | ✓ | ✓ | ✓ | 跨 App 合流只在这里发生 |
| integrations/media | ✓ | ✓ | ✓ | ✓ | 唯一播放内核入口(I2) |
| integrations/firebase | ✓ | ✓ | ✓ | ✓ | 可选分析,未配置=安全降级 |
| integrations/python_runtime | — | — | — | ✓ | 只有 TVBox 需要嵌入式 CPython |
| ecosystem/platform | ✓ | ✓ | ✓ | ✓ | 统一词汇(模型/契约) |
| ecosystem/capability | ✓ | ✓ | ✓ | ✓ | 发现入口 = `CapabilityRegistry` |
| ecosystem/task | ✓ | ✓ | ✓ | ✓ | 后台任务调度 |
| ecosystem/resolver | ✓ | ✓ | ✓ | ✓ | 票据解析链与到期预取 |
| ecosystem/identity | ✓ | ✓ | ✓ | ✓ | 同内容跨源对齐 |
| ecosystem/permission | — | — | — | ✓ | 授权机制服务于不可信代码 |
| ecosystem/extension | — | — | — | ✓ | 插件生命周期网关 |
| ecosystem/plugin_api / plugin_host / js_runtime | — | — | — | ✓ | 插件 ABI / 安装器 / JS 沙箱 |
| ecosystem/external_tvbox | — | — | — | ✓ | spider 契约与源解析 |
| services/favorites, history, search, feed | ✓ | ✓ | ✓ | ✓ | 建在 ContentRef 上,无平台前缀类型 |
| services/playlist | ✓ | ✓ | ✓ | ✓ | 队列/播放列表 |
| ui/design, adaptive, ui_kit | ✓ | ✓ | ✓ | ✓ | 六风格 + 令牌 + 语义组件 |
| ui/player_ui | ✓ | ✓ | ✓ | ✓ | 播放面板 |
| ui/lyric | — | — | ✓ | — | 歌词面 |
| features/home, search, settings, live, vod | ✓ | ✓(vod 为主) | ✓(队列面) | ✓ | 见 §4 装配清单 |
| features/account | ✓ | ✓ | ✓ | — | 站点凭据注册 |
| features/iptv | ✓ | — | — | ✓ | 频道墙 + EPG |
| features/recorder | ✓ | — | — | ✓ | 录制任务 |
| features/music | — | — | ✓ | — | 队列与音源仓库 |
| features/backup | ✓ | ✓ | ✓ | ✓ | WebDAV 构建→推→拉→恢复 |
| providers/huya, douyu, demo | ✓ | — | — | — | native 直播源 |
| providers/bilibili | ✓(live 能力) | ✓(vod 能力) | — | — | 同一个包,各 App 只注册自己要的能力 |
| providers/music | — | — | ✓ | — | lx 兼容音源宿主 |
| providers/iptv | ✓ | — | — | ✓ | M3U + XMLTV |
| providers/tvbox, community, twitch, youtube, douyin | — | — | — | 待定 | 无消费者前不重写(见 §6) |

## 4. 组合根规范(每个 App 的 `lib/app/runtime.dart`)

每个 App 的组合根必须且只能装配自己那一列。共同骨架:

```
main()
 → WidgetsFlutterBinding + 平台目录/日志初始化
 → AppRuntime.boot(dataDirectory, …)         # 每 App 一份,签名可不同
    1. 存储底座:FileKeyValueStore + 各域文件(收藏/历史/歌单/设置各一个文件)
    2. 网络与缓存:NetworkClient → 策略化客户端;CacheHub + DiskCacheTier
    3. 能力注册表:注册本 App 的源(native 或导入)
    4. 服务层:favorites/history/playlist/search/feed 指向本 App 的存储
    5. 媒体内核:MediaKernelHost(进程内唯一 PlayerKernel)
    6. (仅 tvbox)权限管理器 + 插件存储 + JS/Python 运行时 + 扩展网关,并装载已启用插件
 → ProviderScope(overrides: runtimeProvider) → MaterialApp.router
```

硬要求:

1. **组合根之外不得出现"同时看见多层"的代码**(I9 的每 App 版本)。UI 只通过 Riverpod provider 拿服务。
2. **启动不得联网、不得阻塞**:源装载、插件装载、刷新都进 `TaskScheduler`;单个源/插件损坏只记诊断,
   不影响启动(w1-rebuild §5bis 的既有行为,四壳共用这一条)。
3. **dispose 有主**:播放 handle 由页面拥有并关闭;runtime dispose 关内核、关网络、停调度。
4. **数据目录按 App 隔离**:四个 App 各自的 `supportDirectory` 下独立文件,互不读写。跨 App 迁移只经
   `foundation/backup` 的导出/导入,且凭据键两端都拒收。

## 5. 壳层复用规则(避免"四个壳各写一遍")

| 面 | 复用方式 | 不许做 |
|---|---|---|
| 主题/令牌/风格 | `ui/design` + `ui/adaptive`(六风格注册表) | 壳里定义颜色/间距常量 |
| 组件 | `ui/ui_kit`(唯一可 import wind 的包) | 壳直接 `import fluttersdk_wind` |
| 通知/弹窗/加载/空错态 | `ui/ui_kit` 的 `AppNotice`/`AppDialog`/`AppLoading` 门面 | 各自引入第二套 Toast/Dialog 库 |
| 路由 | 壳内 `go_router` 声明,页面在 `features/*` | 跨 App 复制路由表结构 |
| 本地化 | `foundation/l10n` + 各 App 自己的 `assets/translations/*.json` | 硬编码 UI 字符串 |
| 更新 | `foundation/release`(releases.json 源) | 一个更新源服务四个 App |
| 尺寸适配 | 断点 + `LayoutBuilder` 优先;`.sp` 不与自定义缩放叠加 | 用一套比例公式解决所有平台 |

## 6. 重写范围与"工业级"判据

`packages/` 下现有 59 个包按 §3 矩阵逐个重写。**"工业级"的可验收判据**:

1. 公共面稳定:单一 barrel、`lib/src/` 私有、公开类型有 dartdoc 说明"为什么"而不是"是什么";
2. 错误模型显式:每类失败有具名类型/错误码,不把底层异常直接抛给调用方;
3. 可取消、有超时、有界:所有 IO/网络/脚本执行都有取消令牌、超时与输入输出体积上限,并发有显式上限;
4. 资源有主:句柄/订阅/定时器都有配对的释放路径,进程内单例由组合根注入而非全局;
5. 持久化有版本:落盘数据带格式版本与迁移路径,损坏时按域隔离而不是整档报废;
6. 平台矩阵如实:README 写清支持哪些平台、哪些是条件实现,不宣称未验证的能力;
7. 无 demo 痕迹:没有 TODO 占位、没有"能编译但不可用"的空实现;确实未做的能力**不建包**;
8. 安全边界:外部输入(插件脚本、导入配置、站点响应)一律校验后再执行,凭据不落明文日志;
9. 可测但不写测试(本轮):公共面按"能被一个确定性测试钉住"的形状设计,测试由使用者后补。

不满足 1-8 的包不算重写完成。§3 里标"待定/无消费者"的包(`providers/twitch`、`youtube`、`douyin`、
`community`、`tvbox` 适配器骨架)在重写中**默认删除**,除非届时出现真实消费者 —— 保留空壳包会让
"59 个包"这个数字变成误导。

## 7. 迁移步骤(顺序即依赖)

1. **文档与规则**(本文 + ADR 0022 + dependency-rules/AGENTS/package-architecture 同步)。
2. **护栏与脚手架支持多 App**:`tool/check_architecture.dart` 认识 `apps/*` 全部成员并新增
   "App 互不依赖"规则;`tool/scaffold_package.ps1` 支持建 App 包;根 `workspace:` 登记。
3. **拆壳**:`pure_live` 壳去掉插件宿主/JS/Python/TVBox 注册路径(代码不删,留在包层),
   只保留直播所需装配。
4. **建三个新壳**:`pure_bili`、`pure_music`、`pure_tvbox`(先能启动到空白面,再逐面填)。
5. **包重写**:按 L0 → L0.5 → L1 → L2 → L3 → L4 → L5 顺序,每层内按 §3 有消费者的包优先。
6. **发布与 CI 分道**:每 App 一条构建线,产物/版本/更新源独立。
