# W1 重建进度(2026-10-09,从 W1 重新按当前状态重构)

> 触发:使用者判定先前的骨架推进"自己写的一部分感觉不是很好",要求按当前状态从 W1 重新重构,
> 以最快速度拿出一个**可运行的初始版本 + 架构**,不写测试、不跑 CI,每部分独立提交推送。
> 结论先行:骨架本身是绿的(analyze 0 issue、护栏 0 错),真正缺的是**能看见的应用**;本轮没有推倒
> 32 个包,而是清基线 → 收 W1 欠账 → 把空壳应用变成真应用 → 用一个 demo 源打通"注册 → 能力注册表 →
> Feed 聚合 → 首页 UI"整条链。工程规范按 [../DEVELOPMENT_STANDARDS.md](../DEVELOPMENT_STANDARDS.md)。

## 1. 本轮四个提交(全部已推送 origin/v2)

### 1.1 `f4c6ab0d5` 基线清理(最要紧的一个)

- 丢弃本地未推送的 `6230151a2`:133 个文件全是仓库根的 Flutter 再生产物(`android/.gradle`、
  `ios|linux|windows/**/ephemeral`、`GeneratedPluginRegistrant`、`local.properties`,内含 278 MB 的
  `.pdb`)。在 `v2-artifact-commit-backup` 分支留了引用,不丢证据。
- **修复 `.gitignore` 的 `apps/` 全目录忽略**——本轮抓到的最危险的坑:该规则对已跟踪文件无效,但会把
  `apps/pure_live` 下一切**新文件**从 `git status`/`git add` 里静默吞掉(用探针文件实测证实)。规则是
  v1 时代"apps/ 只是构建残留"的遗留,在 v2 里应用壳就住在 `apps/pure_live`,必须删。
- 根级 `/android/ /ios/ /linux/ /macos/ /windows/`、`**/ephemeral/`、`**/.gradle/`、
  `**/GeneratedPluginRegistrant.*`、`**/local.properties` 加入忽略作为防复发安全网。

### 1.2 `0a2f71c66` W1 收尾(w1-progress §3.2 登记欠账的直接清偿)

| 欠账 | 处置 |
|---|---|
| fluttersdk_artisan/dusk 栈(§3.2 第 6 条"未做取舍") | **取舍:移除**。`bin/dispatcher.dart`、`bin/fsa`、两个 `*_g.dart` 生成桶与两个依赖构成封闭死代码,应用入口从未 import,docs 全体系无一处提到它。wind 保留(pubspec 注明是 UI 层选型,等 ui_kit 落地) |
| 应用侧 18 个 media_core git 依赖 + wakelock_plus | **归位**。`packages/integrations/media` 已持有同一 ref 的 `media_core`;引擎链属于集成层而非应用,应用 pubspec 不再重复 pin |
| build.yaml 的 drift 死路径(v1 `lib/core/iptv/...`) | 收敛为只剩 enven 自动构建器禁用(发布工作流仍显式跑 enven CLI) |
| 根目录 v1 残留 | 删 `server.py`(POST 到旧根 assets 路径)、`flutter_01.log`、`pure_live.iml` |
| `.fvmrc` 3.47.5 vs 实际 3.47.6(§3.2 第 5 条,原判"待用户定") | **定:钉 3.47.6**。本分支全部检查实际都跑在 PATH 的 3.47.6 上,依赖静默回退比改钉更危险 |

### 1.3 `4d936076a` 应用壳从调试屏变成真应用

- `MaterialApp.router` + Material 3 亮/暗主题(自带 MiSans 字体);go_router
  `StatefulShellRoute.indexedStack`:手机 `NavigationBar`、≥900px `NavigationRail`(≥1280 展开标签)。
- 三个分支:首页 / 关注 / 设置,各自保留状态;`/room/:roomId` 独立于 shell(全屏,TV 上导航栏不可达)。
- Riverpod(声明的 v2 状态栈)接入:`runtimeProvider` 在 boot 后以 override 注入,组合根之外不可能
  拼出第二份 runtime;设置页读 runtime 事实(数据目录/内容源数/网关类型)+ 包信息。
- `host.dart`(只渲染装配清单的调试屏)删除;原装配 widget 测试改为对新壳断言。

### 1.4 `62703fb9a` demo 源打通完整内容链

- `packages/providers/demo`(脚手架生成,providers 层第 1 个包):`DemoLiveSource` 实现
  `FeedCapability`,12 个静态房间,**无网络**;第二页返回空且 `hasMore` 恒 false(paging 契约:不能
  假装有下一页让列表空转)。
- 组合根新增 `registerBuiltInSources`:内置源由应用注册是合法的(AGENTS I9 应用是唯一能点名具体源的
  地方);测试走 `PureLiveRuntime.boot()` 不含此调用,fixture 语义不被污染。
- 首页改读 Feed 聚合器:sourceId 分节头、2/3/4 列响应式网格、下拉刷新(按 feed.md 规则重新要第 1 页)、
  卡片 `context.push('/room/:contentId')`;空态/错误态如实呈现。
- 完整链路:注册 → `CapabilityRegistry` → `CapabilityFeedAggregator`(8s/源超时、跳过原因记账)→ UI。

## 2. 验证证据

| 命令 | 结果 |
|---|---|
| `flutterw.ps1 dart analyze .`(每笔提交前) | No issues found |
| `flutterw.ps1 dart run tool/check_architecture.dart --strict` | `packages=33 errors=0`(33 = 32 + demo) |
| `flutterw.ps1 pub get` | 通过(去 media_core 链后 "Changed 35 dependencies!") |
| `flutter test`(apps/pure_live) | **未跑**:ffmpeg 原生资源钩子要求 `native-assets/` 预取件,本地暂存缺失
  (BUILD_POLICY 已记录的前置)。装配测试只改了形状未实跑,属已知未验证项 |
| 推送 | 四笔全部确认出现在 origin/v2(网络间歇失败见 §3) |

## 3. 遇到的问题

1. **网络**:git push 与 pub get 间歇 `SSL_ERROR_SYSCALL`。`git -c http.version=HTTP/1.1 push` + 重试
   可过;本机 127.0.0.1:7897 代理经 curl 验证可用,但**没有**改用户全局 git 配置(未授权)。
   下个会话若再遇,先试 HTTP/1.1 再试 `-c http.proxy=…`。
2. **Riverpod 3 移除 `Override` 导出**:`ProviderScope.overrides` 传参直接写
   `[runtimeProvider.overrideWithValue(runtime)]`,不要写 `List<Override>`。
3. **护栏的 providers 层硬性目录**:`lib/src/models/`、`fixtures/`、`test/` 缺一报 layout-drift——
   我先删了脚手架的 `.gitkeep` 占位被当场抓回。demo 的这三个目录目前都是占位,fixture 按
   provider-contract §1 规则 5 等 W4 真实录制件,不造假。
4. `.gitignore` 的 `apps/` 坑(§1.1)——任何"新文件不出现"的怪象先查它。

## 4. 未做(明确的边界)

- **没有测试、没有碰 `.github/`**:按本次要求跳过;`architecture.yml` 等 CI 的行为只在本地逐命令验证。
- **没有动 W2-W5 已落内容**:契约/权限/任务/网关/收藏/历史/歌单/搜索/Feed 32 包原样保留——它们是绿的,
  推倒是纯损失;重建针对的是"不可见的骨架"而不是"已验证的包"。
- **没有接播放**:房间页是占位面;媒体内核未接线(w3-progress §4)。
- **没有接真实站点**:W4 的两处卡点(录制授权、danmaku/auth 契约定稿)原样未动,demo 源不替代它们。
- 资产清单仍是 v1 全量(2095 个文件),按 w1-progress §3.2 第 7 条留给 UI 波筛。

## 5. 重建第二段(2026-10-09 同日续,媒体链与第一个真实 provider)

### 5.1 `626d3ed9e` 媒体链接线(房间页可播)

- `packages/integrations/media` 持有引擎后端 `media_core_media_kit`(vendored 引擎只进集成层),新增
  `MediaKernelHost`(进程内唯一 `PlayerKernel`,注册 media_kit 后端,`open(ticket)` 走既有
  `toCoreSource` 映射)与 `MediaSurface`(渲染 handle;引擎类型显式判别,第二后端出现时在此加分支,
  不做盲 cast)。应用从头到尾只见 ticket → handle → surface,不 import 引擎包。
- demo 源实现 `ResolveCapability`:每个房间出一张公共测试 HLS 流(Mux 资产)的票,**如实记为 vod**,
  永不过期且 `refresh.supported=false`(契约:没有截止时间就不发明一个)。
- 房间页:从入口带 `ContentRef`(首页卡片 `extra`),经能力注册表找到该源的 `ResolveCapability` 出票
  → `runtime.media.open` → `MediaSurface`;裸深度链接(无 ref)保留诚实占位面;失败显示错误 + 重试;
  页面拥有 handle 并在 dispose 时关闭(会话所有权:离开房间即结束播放)。
- runtime 装配 `MediaKernelHost`;入口在 binding 后跑 `ensureInitialized()`;runtime dispose 关内核。

### 5.2 `a72321a9a` 虎牙 provider(第一个真实站点)

- `packages/providers/huya`:feed 读公共网页推荐列表(`cache.php getLiveListByPage`)→
  `ContentSummary`(封面/主播/分区/热度);resolve 走 `mp.huya.com profileRoom`,取第一条 CDN 线路,
  HLS 地址拼装;antiCode 带 `fm` 模板时按 web 签名算法重建 `wsSecret`(保留完整模板、uid 32 位轮转、
  wsTime 租约检查),算法来自 v1 维护线(origin/master `lib/shared/platforms/huya/huya_site.dart`,
  其本身同步自 dart_simple_live)。**按 UPSTREAM_REVIEW_POLICY:这是照协议知识的新实现,没有任何
  上游提交/文件经此进入;处置 = rewrite(契约面全新、实现重写)**。
- 本切片刻意比 v1 线小:无登录 Cookie、无 TARS token 租约、无清晰度/线路选择(匿名 HLS,够打通
  feed→房间→播放);refresh 从票 id 解出房间号重新 resolve(租约以分钟计,不发明死线)。
- 已注册为内置源(与 demo 并列);首页卡片渲染真实封面(加载失败回退占位图标)。

### 5.3 第二段验证与边界

| 项 | 结果 |
|---|---|
| `dart analyze` / 护栏 | 全绿;护栏 `packages=34 errors=0`(新增 huya 后) |
| `pub get` | 通过;**网络持续握手失败时 `pub get --offline` 可用**(全依赖已入缓存,git 依赖也已缓存) |
| 端点/播放实测 | **未做**(本轮无设备授权):虎牙端点与签名逻辑逐行对照 v1 维护线,但真实响应未验;demo 测试流为公共服务,可达性未验 |
| flutter test | 仍未跑(native-assets 前置未补齐,见 §2) |

## 6. 下一步

1. **设备验证**(需用户授权设备会话):虎牙推荐列表/房间取流真机实测;房间页播放(Windows 先行,
   media_kit 桌面链路 v1 已验证)。
2. `native-assets/` 预取件补齐后把装配测试真跑一遍。
3. 虎牙补齐分类浏览(`BrowseCapability`)+ 搜索;清晰度/线路选择进 `SelectionRef` 语义。
4. 媒体看门狗/换源接线(`integrations/media` 的 watchdog/ticket_swap 已有,尚未接进房间页会话)。
