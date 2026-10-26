# 设置中心结构审计与重构方案

依据《PureLive v4 设置中心智能拆分与自动重构规范》产出。本文件记录阶段 A（审计）与阶段 B/C（方案与一致性检查）；
逐项设置的实现状态仍以 [settings-review-checklist.md](settings-review-checklist.md) 为唯一清单，本文件不复制该行级内容，只做结构性结论。

> **2026-10-26 三级拆分落地**：`system > general` 拆为 浏览/窗口/启动与退出，
> `live > sources` 拆为 站点/账号/标签/刷新，`live > danmaku` 拆为 样式/屏蔽/小窗，
> `playback > video` 拆为 画质/音频/画面，`personalization > appearance` 拆为
> 主题/字体，数据与缓存各自成页。搜索目录已重挂到叶子页（含 startup/账号/标签/
> 小窗等补全），遗留的 `_SourcesPane` / `_DataCachePane` 与不可达 part 分支已删除；
> 自动检查更新移入 About。§2.7、§2.8 视为已修复；D1（键清单收敛、备份缺口）与
> D2.4/2.5（pane builder 表、pane 搬出页面文件）仍是后续工作。全量构建期间仍受
> 并发字体功能改动影响。

## 0. 审计范围与方法

- 入口与页面：`apps/pure_live/lib/features/settings/`（20 个文件）、`app/navigation/module_navigation.dart`、`layouts/app_layout.dart`、`layouts/desktop/desktop_layout.dart`、`app/routing/app_router.dart`。
- 设置定义：`app/providers/`、`app/theme/`、`app/background/`、`shared/`、各 `features/*`。
- 持久化：`packages/live_storage`（Drift/SQLite 之上的 `StoragePrefs`、`openStore`、secrets vault、migration runner、window bridge）。
- 业务消费：`app/bootstrap/`、`features/room/`、`packages/live_net`、`packages/live_shell*`、media_core 驱动链。
- 结论均来自实际调用关系，不以页面标题或目录名推断归属。

## 1. 现状结构（阶段 A）

### 1.1 三层解耦的现状

| 层 | 现状 | 位置 |
| --- | --- | --- |
| 分类骨架 | `enum SettingsSection`（43 个值）自带 `parentSection` / `settingsChildrenOf`，最深 4 级 | [settings_sections.dart:19](file:///F:/projects/pure_live/apps/pure_live/lib/features/settings/settings_sections.dart#L19) |
| 模块注册 | `kModuleNavigation` 只注册**分类 ID 与分组标签**，每个模块 4 个侧栏行（live/iptv/vod/music 各带自己的业务分类） | [module_navigation.dart:88](file:///F:/projects/pure_live/apps/pure_live/lib/app/navigation/module_navigation.dart#L88) |
| Pane 派发 | `SettingsSectionPane` 内一个硬编码 `switch`，是全仓唯一的 section→widget 映射 | [settings_page.dart:432](file:///F:/projects/pure_live/apps/pure_live/lib/features/settings/settings_page.dart#L432) |
| 配置定义 | `StoragePrefs`（Drift 的 `settings` 命名空间）承载全部标量项；Layer B 为按命名空间的文档库；Layer C 为 secrets | `packages/live_storage/lib/src/prefs/storage_prefs.dart` |
| 会话态 | `settingsSectionProvider`（桌面侧栏选中）+ `/settings/:section` 深链（触屏 push） | [settings_section_provider.dart](file:///F:/projects/pure_live/apps/pure_live/lib/app/providers/settings_section_provider.dart) |

层级实测：`personalization → appearance → theme`、`system → general → browsing`、`live → sources → sites` 为三级；`personalization → background → backgroundImages` 为四级。触屏每级都是一次 push，桌面为单窗格切换 + 顶部面包屑，两种形态已兼容。

### 1.2 关键事实

- **包层零设置所有权**：`packages/*` 无 riverpod 依赖，不定义也不读写 `StoragePrefs`；`live_net` 的代理、`live_shell` 的 chrome 模式都由 app 层注入。语义全部属于 app，机制全部属于 `live_storage`。
- **`kSettingsProviders`（44 项）与 `kBackedUpPrefs`（107 键）是两份手维护清单**，需要与 `kShieldPrefKeys` 一起手工保持同步，无单一真值源。
- **平台门控 100% 在 widget 行级**：注册表与 `SettingsSection` 无任何平台字段，因此整页永不按平台隐藏，只隐藏行。
- **搜索索引为手维护目录**（约 140 条 `_hit` 字面量）：可打开的 section 集合来自注册表（正确），但命中目标仍指向拆分前的父分类（见 §2.7）。

## 2. 问题清单（每项含证据）

| # | 类别 | 问题 | 证据 |
| --- | --- | --- | --- |
| 2.1 | 重复定义 | `proxy.enabled/host/port`（全局）与 `player.proxy`（mpv 专用 JSON）语义同名不同形，用户无法区分 | `app/providers/network_providers.dart`、`features/settings/player_tuning.dart:477` |
| 2.2 | 孤儿键 | `recorder.saveDir` 只读从不写；`recorder.maxSizeGb` 与 `recorder.maxSizeMb` 并存靠数值猜测单位 | `features/recorder/recording_settings.dart:139,188-198` |
| 2.3 | 重复读取 | `shell.closeAction` / `shell.dontAskExit` 在 provider 之外被 `app_bootstrap.dart` 独立解析一份 | `app/bootstrap/app_bootstrap.dart:394,408` |
| 2.4 | 定义散落（无 Riverpod 归属） | `iptv.sources.order` 写在 view 文件、`window.chrome` 写在静态类、`cache.maxMB` 写在图片缓存、`vod.progress.<bvid>` 写在页面、PiP 几何为自由函数 | `features/iptv/iptv_sources_view.dart:26`、`app/window_chrome.dart:45`、`shared/images/app_image_cache.dart`、`features/vod/vod_video_page.dart:421`、`app/providers/pip_geometry.dart` |
| 2.5 | 备份类型错误 | `theme.autoClash` 存 bool、备份声明 `BackupPrefKind.string`，恢复时被静默跳过 | `features/backup/backup_settings.dart:91` |
| 2.6 | 备份白名单缺口 | `ui.splash`、`log.level`、`log.file`、`window.chrome`、`vod.quality.qn`、`backup.dir`、`backup.webdav.url/user` 不在 `kBackedUpPrefs`；`multiview`、`recordings` 文档库完全不在备份内 | `features/backup/backup_settings.dart` |
| 2.7 | 搜索归属错位 | theme/typography 命中指向 `appearance`；window/startup/refreshRate/closeAction 指向 `general`；账号行指向 `sources`；shield/danmakuStyle/miniDanmaku 指向 `danmaku`；quality/audio/picture 指向 `video`；data/cache 指向 `dataCache` — 点搜索结果落在总览页而非目标页 | `features/settings/settings_search.dart` |
| 2.8 | 死代码 | 合并后遗留的 `_SourcesPane`、`_DataCachePane` 已无实例化；`_DanmakuPart.shield/.mini` 分支不可达；「legacy 页已并入合并页」的注释对 data/cache/danmaku 已失真 | `settings_page.dart:1923+`（现位置随编辑漂移） |
| 2.9 | 展示层过载 | `settings_page.dart` ≈2534 行，同时承担 shell（搜索/菜单/派发）与约 20 个 pane 实现，违反规范 §6 的职责边界 | `settings_page.dart` |
| 2.10 | 无界键 | `vod.progress.<bvid>` 键空间无上限、不清理、不备份 | `features/vod/vod_video_page.dart:421` |
| 2.11 | 无全局恢复默认 | 只有 `danmakuStyleProvider.reset()`、`playerTuningProvider.reset()`、`sitesOrderProvider.resetOrder()` 等分片重置 | 各 provider |
| 2.12 | 迁移机制未落地 | `StorageMigration` 只有接口与 runner；旧 Hive 数据一次性导入器不存在；现存兼容全靠读时 ad-hoc 回退 | `packages/live_storage/lib/src/migration/storage_migration.dart`、`docs/multi-window-storage-architecture.md` |
| 2.13 | 并发编辑风险 | 工作树正处于三级拆分（quality/audio/picture、theme/typography、browsing/window/startup、sites/accounts/followTags/refresh）的落地过程中，`flutter analyze` 在此期间出现临时语法错误；同一文件被另一会话实时写入 | 2026-10-26 00:26 实测 |

## 3. 结构性结论（哪些该保留、哪些该改）

### 3.1 保留：当前分类骨架无需重设计

4 个一级分类（个性化 / 直播 / 播放 / 系统）+ about，配 43 个 section，粒度一致且以用户任务为边界：
`外观`（主题·字体·背景）是一个任务、`来源`（站点·账号·标签·刷新）是一个任务、`画质/音频/画面` 拆三级是三个可独立调整的任务。
**没有发现「按文件复制」或「按 Provider 拆分类」的反模式**，也没有杂项页。规范 §4.3 的禁止项均未被触发，因此本项判定为：结构正确，继续把已定义的三级页做完即可，不再新增分类、不再改层级。

`background` 的 5 个子页（图片/随机/视频/颜色/设备导入）共享同一个用户任务（设置窗口背景），但各自对象集合大且交互不同，属于规范 §4.2 的「多个可独立管理的复杂对象」——保留拆分。

### 3.2 需要改的三类（按风险从低到高）

**D1 身份与真值源（低风险，不改语义）**
1. 把 §2.4 的 5 个「无 Riverpod 归属」配置提为与其他项同构的定义，键名与默认值**逐字不变**，不改数据。
2. `kSettingsProviders` / `kBackedUpPrefs` / `kShieldPrefKeys` 收敛为一份按 key 分组的定义清单（每个配置一个条目：key、类型、默认值、备份策略、窗口桥接策略），三处从它派生。
3. 修 §2.5 的 `theme.autoClash` 类型；把 §2.6 缺口按键补进同一清单。补录属**新增覆盖**，不改变任何现有值。

**D2 派发与文件边界（中风险，纯搬移）**
4. `SettingsSectionPane` 的 switch 迁移为与注册表同构的 pane builder 表（`Map<SettingsSection, Widget Function()>`），放在分类定义一侧而不是页面文件里；`settings_page.dart` 只留 shell。
5. 每个业务域的 pane 移到其 feature 目录（`theme/`、`playback/`、`window/`、`sources/` …），与 `background_panes.dart`、`player_kernel_pane.dart` 已确立的外部 pane 模式一致。仅移动文件与私有类命名，不改行级逻辑。
6. 删 §2.8 死代码（`_SourcesPane`、`_DataCachePane`、不可达的 `_DanmakuPart` 分支），并把 §2.8 的失真注释改正确。

**D3 语义决策（需确认，不得擅改行为）**
7. §2.1 `proxy.*` 与 `player.proxy`：两者可被用户分别理解（全局网络代理 vs. 播放器内核代理），但当前文案与位置都未表达这层区别。**保持两份存储不变**（合并会改变已有用户配置的语义），仅在 UI 与说明上把作用域写清；是否需要统一为一份配置属产品决策，提交确认。
8. §2.2 `recorder.saveDir` 孤儿读取与 `maxSizeGb` 单位猜测：**保留读回退**（老用户数据仍需生效），但补一条真正的 `StorageMigration` 写入而非永久回退，使回退可在下一版本移除。
9. §2.10 `vod.progress.<bvid>`：改为独立文档命名空间（与 `history` 同构）或加清理上限 + 纳入备份；属数据格式变更，单独评估兼容性。
10. §2.7 搜索目标重挂：把每条命中的 `section` 改为实际承载该行的叶子页，并把 43 个 section 的覆盖补全。这是行为修正（点开结果应到目标行），不需要产品决策。
11. §2.11 全局恢复默认：规范 §6 要求状态层负责恢复默认，当前缺失。新增需谨慎定义作用域（是否含账号 cookie、是否含来源数据），提交确认后再实现。

### 3.3 不做的事

- 不引入新的设置框架/抽象层（规范 §7 明令禁止）。
- 不改动任何设置的默认值、有效范围或业务含义。
不删除任何功能，不做任何用户配置的重置或丢弃。
- 不因某项设置只在单平台生效而为其单独建页（`window.chrome`、`windowsPipAlwaysOnTop` 保持行级门控）。

## 4. 阶段 C 一致性检查结论

- 职责重复分类：无（4 个一级分类互斥）。
- 层级过深：最深 4 级仅出现在 `background` 子树，触屏已有面包屑与逐级 push；判定为可接受，不再加深。
- 无关配置同页：`_VideoPane` 拆分前存在此问题，当前三级拆分正在修正。
- 拆分过度：无；`theme/typography` 等三级页各自内容量足够成页。
- 遗漏设置项：以 checklist 263 行为准，本次未发现被结构性遗漏的项；缺口表现为 §2.6 的备份覆盖遗漏，而非页面缺项。
- 平台可见性：注册表级平台字段暂不引入——现有行级门控已能表达「同页不同平台不同行」，整页级门控只在出现整页不适用平台时才需要；当前无此情形。

## 5. 验证方法（阶段 E，待实施时执行）

1. `flutter analyze`（app + 受影响 packages）零 error。
2. `dart run build_runner build`（slang / riverpod / built_value 生成）通过，检查 `settings_en/zh-CN.i18n.json` 键对称。
3. 键唯一性与完整性脚本：枚举 `StoragePrefs` 全部读写点，与收敛后的单一清单比对，输出未被清单覆盖的键（应为空）。
4. 每个 section 的入口可达性：`SettingsSection.of(name)` 与 pane builder 表键集合相等（编译期穷尽 switch 保证）。
5. 备份往返：写入全部键 → 导出 → 清空 → 恢复 → 逐键比对，覆盖新增补录键。
6. 真机/真窗口验证：Windows 主窗与克隆窗设置项跨窗同步、`window.chrome` 克隆跟随、触屏三级 push 与面包屑回退。
7. 搜索：每条命中 open 后落在含该行的页面（断言 section 与承载 pane 一致）。

## 6. 当前阻塞

`settings_page.dart` 与 `settings_sections.dart` 正被并发会话实时编辑（三级拆分落地中，`flutter analyze` 出现临时语法错误）。
按项目既有约定：**等待其完成，不抢先修复同一文件**。D1/D2 的动手时机以工作树恢复可编译、且无进行中的编辑为前置条件。
# 规范版本说明（2026-10-26）

原《PureLive v4 设置中心重构规范》（本文档旧§一–§四，含「阶段一展示后必须停等确认」条款）已被
《PureLive v4 设置中心智能拆分与自动重构规范》取代，规范全文见
[settings-center-refactor-spec.md](settings-center-refactor-spec.md)。新规范 §9 明确授权编码代理
自主决定分类与子页面数量、拆分与合并方案、设置项迁移；仅「删除功能、改默认值、重置用户配置、
改变配置语义、引入冲突框架、无依据改变跨平台行为」仍属不得擅自决定项，另加 §4.4「无法从代码
确定的产品决策应保留行为并提交确认」。下文「阶段一交付」方案仍须先通过新规范 §8 阶段 C 的
一致性检查（见文末「阶段 C 复核」）后才进入实施。

---

# 阶段一交付：设置中心信息架构重设计（2026-10-26 01:15，等待确认）

依据规范 §2.1–2.3。本阶段只读，未改任何代码/配置/生成文件。所有数字来自实测脚本
（`.tmp/prefs-audit*.mjs`、`.tmp/ia-density.mjs`、`.tmp/row-inventory.mjs`），非估计。

## 一、现状问题分析（带证据）

实测：`SettingsSection` 43 个值、派发 43 个 case、叶子页 32 个、搜索命中 165 条、页面内设置行合计约 150。

| # | 问题 | 证据 | 为什么是问题 |
| --- | --- | --- | --- |
| P1 | 必经的纯索引页：9 个页面一个设置项都不承载，只是子页链接列表 | `_SettingsCategoryPane` 服务于 live/playback/system/general/appearance/sources/danmaku/video/dataCache；`_PersonalizationPane` 仅 3 行（navBackground/navAppearance/navNavigation） | 用户为了「找到一行设置」必须多点一次，这是层级深的直接原因。规范 §4.1：内容过少、独立存在无价值 |
| P2 | 最深 4 级（设置 → 个性化 → 背景 → 图片库）；6 个域是 3 级 | `settingsChildrenOf`：personalization→background→5 子页、appearance→theme、sources→sites、danmaku→danmakuStyle、video→quality、general→browsing。触屏每级一次 push | 用户本轮明确提出的症状 |
| P3 | 一级只有 4 个分类，导致二级超载 | 侧栏行 = live/personalization/playback/system(+about)，5 行摊下 32 个叶子页 | 一级过少，中间就必须长出一层收纳层 |
| P4 | 粒度极不均：1 行页与 19 行页同级并列 | 实测行/页：kernel 24、backup 19、typography 段 19 行（_AppearancePane 合计）、recording ~15；对照 quality 2、network 2、startup 2、miniDanmaku 1、nodes 1、vod 1、shield 2 | 1 行页配独立导航项是层级浪费；24 行页又确实要再分。两种极端落在同一层 |
| P5 | 按 switch 假拆页：三个 pane 用一个 part 枚举扮演 2–3 个页面 | `_AppearancePane(part:)`、`_VideoPane(part:)`、`_DanmakuPane(part:)`，文件与 widget 都没分离 | 规范 §4.3：按代码边界拆页不等于按用户任务拆页 |
| P6 | 同类任务被分类边界切开 | 卡片宽度/每页数量/紧凑/观众指标在 system>general>browsing；字号字体在 personalization>appearance>typography；语言在 typography 段内；小窗弹幕(1 行)与弹幕样式分属两级 | 用户任务是「界面观感」和「弹幕」，被现有分类拆散 |
| P7 | 遗留 section 与现役 section 并存 | refresh/miniDanmaku/data/cache 既挂在 `parentSection` 里，又各自有 pane；「legacy 页已并入合并页」的注释对 data/cache 已失真 | 规范 §7：配置身份不应依赖页面文件；重复注册会让搜索与深链出现两套真相 |
| P8 | `settings_page.dart` 2570 行 / 111 KB 同时承担 shell 与约 20 个 pane | 实测；7 个 pane 已在外部文件（background/account/shield/kernel/nodes/backup/iptv/vod） | 外部 pane 模式已确立，页内部分是历史遗留（属实施细节，非本轮主目标） |

## 二、完整导航树（新）

设计规则（按规范 §4、§5 自主推导，不是套模板）：

- 组标题不可点击（桌面侧栏已有 `_SettingsGroupHeading` 这一角色），行 = 真实页面。取消全部纯索引页。
- 从设置入口算起：一级页 1 次点击，子页 2 次点击（今天是 2/3/4 次）。
- 一个页面承载 6–12 行；1–2 行的域合并进语义近邻页，超过 14 行的域垂直切成「常用页 + 高级子页」，不横向铺同级页。
- 模块专属设置仍归模块自己（延续既有 module-scoped 约定），不借用他模块页面。

```
【个性化】
  外观与主题      主题模式/种子色/动态取色/对比度/圆角/密度/选中样式/加载样式+颜色/列间距/行间距/语言  (11 行)
  字体与字号      字体族(管理器)/文本缩放/正文小中大/标题中大 共 5 档                          (6 行)
  背景与壁纸      背景类型/适配/遮罩/模糊 + 5 个子页入口                                        (4 行)
    ├ 壁纸图库
    ├ 随机壁纸
    ├ 动态视频壁纸
    ├ 纯色与渐变
    └ 从设备导入
  导航与菜单      菜单项显示/工具顺序/多视图可见/需重启提示                                      (7 行)
  浏览布局        卡片宽度/每页数量+档位/页码选择器/跳页/回顶/紧凑关注/观众指标                    (8 行)

【直播】(仅 live 模块)
  直播源与平台     站点显示/全部显示/仅保留一个/偏好平台/顺序重置/显示不可播                       (7 行)
    └ 平台账号      账号列表/扫码/Cookie/登出
  关注与刷新      关注自动刷新/回前台刷新/间隔/并发上限/封面定时刷新/封面刷新间隔                   (6 行)
    └ 关注分组      分组标签管理
  弹幕           弹幕显示/小窗弹幕/字号/速度/区域/透明度/描边/重置                               (8 行)
    └ 屏蔽名单      关键词与用户屏蔽/添加/清除
  节目录制        目录/命名/大小上限/容器/分段/读写超时/队列/重试/退避/停滞/水位/并发/偏好最佳流…   (15 行)

【播放】
  画质与声音      默认画质/蜂窝画质/默认静音/全局静音/音量/后台播放/ASM 定时/保持屏幕常亮            (8 行)
  画面与小窗      画面填充/悬浮小窗/离开自动小窗/Win 置顶/记住位置/小窗基准尺寸/最小宽度              (7 行)
  播放器内核      引擎/硬件解码/解码器/强制销毁/独占音频/超分/插帧                                 (8 行)
    └ 内核高级参数   视频输出/音频输出/自定义输出/视频同步/去交错/scale kernel/mpv 代理/重置/文档

【系统】
  启动与退出      开机启动/闪屏动画/关闭窗口行为/不再询问退出/定时自动关闭                          (5 行)
  窗口           窗口尺寸/独立房间窗口/标题栏样式/屏幕刷新率                                       (5 行)
  网络与代理      代理开关/主机/端口 + 指向内核代理的说明行                                        (3 行)
    └ 平台节点
  数据与缓存      历史上限/清除历史/导出关注/导入关注 + 缓存占用/清理/上限                          (9 行)
  备份与恢复      导出摘要/本地备份/恢复/备份文件列表 + WebDAV 摘要与入口                            (11 行)
    └ WebDAV 同步   地址/用户/口令/浏览/测试/上传/下载
  日志           级别/写文件/查看

【关于】
  关于           版本/检查更新/自动检查更新/发布历史/配置预览/项目/许可证                            (7 行)

【IPTV】(仅 iptv 模块)
  IPTV 节目单与来源  更新间隔/自动更新/同步全部/自定义 User-Agent                                   (4 行)

【Bilibili 视频】(仅 vod 模块)
  视频站          起点画质/账号入口                                                                (2 行)
```

live 模块侧栏 = 5 个组标题 + 13 个一级行；iptv = 5 标题 + 11 行；music = 4 标题 + 10 行。

## 三、分类职责与边界

| 一级分类 | 管什么 | 与谁的边界 |
| --- | --- | --- |
| 外观与主题 | 颜色、形状、加载动画、语言 =「界面看起来怎样」 | 不含文字尺寸（归字体与字号），不含窗口形态（归窗口） |
| 字体与字号 | 字形与文字尺寸 =「读起来怎样」 | 与外观同属排版但任务不同：一个是配色，一个是可读性 |
| 背景与壁纸 | 窗口背景这一对象集合的管理 | 只有 4 个全局参数留主页，素材库各自成子页（规范 §4.2 多个可独立管理的复杂对象） |
| 导航与菜单 | 侧栏里有什么、什么顺序 | 与浏览布局边界：菜单=去哪，布局=内容怎么排 |
| 浏览布局 | 内容网格的尺寸/分页/密度 | 不含菜单可见性 |
| 直播源与平台 | 平台集合与默认平台 | 账号是另一任务（登录态生命周期），故为子页 |
| 关注与刷新 | 拉取时机与并发 | 数据来源属直播源，拉取节奏属本页 |
| 弹幕 | 弹幕渲染 + 小窗弹幕 | 屏蔽是名单管理，故为子页 |
| 节目录制 | 录制引擎的 15 个参数 | 独立业务对象 |
| 画质与声音 | 播出来是什么、多大声、后台是否继续 | 与内核边界：这是用户可感结果，那是引擎机制 |
| 画面与小窗 | 画面几何与 PiP 行为 | 小窗弹幕属弹幕域，此处只管视频几何 |
| 播放器内核 | 引擎/解码/超分等实现选择 | 高级参数垂直下沉一级，常用 8 行不被 24 行淹没 |
| 启动与退出 | 应用生命周期的两端 | 与窗口边界：窗口=形态，启动退出=进程存活 |
| 窗口 | 尺寸/标题栏/房间独立窗/刷新率 | — |
| 网络与代理 | 进程级出网 | 播放器代理留在内核（见 §五 D5） |
| 数据与缓存 | 本机数据（历史/关注 JSON）+ 图片缓存 | 备份属跨机可移植数据，不在此页 |
| 备份与恢复 | 配置的可移植副本 | WebDAV 是传输通道，故为子页 |
| 日志 / 关于 | 诊断 / 版本与更新 | 自动检查更新只服务版本任务，留在关于 |

## 四、设置迁移映射（现有 43 个 section 逐项，无占位）

| 现有 section | 去向 | 层级变化 |
| --- | --- | --- |
| personalization | 删除索引页；主题预览卡并入「外观与主题」页首，其余 2 行由组标题【个性化】承担 | −1 级 |
| appearance | 删除索引；子页 theme/typography 升为一级行 | −1 级 |
| theme | 外观与主题（一级页，含原 appearance 的主题预览） | 3 级 → 1 级 |
| typography | 字体与字号（一级页；`_AppearancePart.typography` 假拆页结束，独立 widget） | 3 级 → 1 级 |
| background | 背景与壁纸（一级页，保留 4 个全局参数行） | 2 级 → 1 级 |
| backgroundImages / backgroundRandom / backgroundVideos / backgroundColors / backgroundDevice | 背景与壁纸的 5 个子页（身份不变） | 4 级 → 2 级 |
| nav | 导航与菜单（一级行，从个性化下提出） | 2 级 → 1 级 |
| general | 删除索引页 | −1 级 |
| browsing | 浏览布局（一级行） | 3 级 → 1 级 |
| window | 一分为二：closeAction/dontAskExit/定时关机 → 启动与退出；windowChrome/roomWindows/窗口尺寸/刷新率 → 窗口 | 3 级 → 1 级 |
| startup | 并入「启动与退出」（与关闭行为同属进程存活任务） | 3 级 → 1 级 |
| sources | 删除索引页 | −1 级 |
| sites | 直播源与平台（一级行） | 3 级 → 1 级 |
| accounts | 平台账号（子页，登录流程独立） | 3 级 → 2 级 |
| followTags | 关注分组（「关注与刷新」的子页） | 3 级 → 2 级 |
| refresh | 关注与刷新（一级行；旧深链别名保留） | 3 级 → 1 级 |
| danmaku | 删除索引页 | −1 级 |
| danmakuStyle | 弹幕（一级行） | 3 级 → 1 级 |
| miniDanmaku | 合并进「弹幕」页（1 行不配独立页） | 3 级 → 1 级 |
| shield | 屏蔽名单（子页） | 3 级 → 2 级 |
| recording | 节目录制（一级行，`RecordingSettingsPane` 保持外部文件） | 2 级 → 1 级 |
| video | 删除索引页 | −1 级 |
| quality + audio | 画质与声音（一级行，合并 2+6 行；`_VideoPart` 枚举删除） | 3 级 → 1 级 |
| picture | 画面与小窗（一级行） | 3 级 → 1 级 |
| kernel | 播放器内核（一级行）+ 内核高级参数（子页，把 24 行垂直切开） | 2 级 → 1/2 级 |
| network | 网络与代理（一级行） | 2 级 → 1 级 |
| nodes | 平台节点（子页） | 2 级 → 2 级 |
| logs | 日志（一级行） | 2 级 → 1 级 |
| dataCache | 删除索引页 | −1 级 |
| data + cache | 数据与缓存（一级行，9 行；`_CachePane` 并入同一实现） | 3 级 → 1 级 |
| backup | 备份与恢复（一级行）+ WebDAV 同步（子页，从 19 行切出 8 行） | 2 级 → 1/2 级 |
| about | 关于（一级行，保持现状） | 1 级 → 1 级 |
| iptv | IPTV 节目单与来源（模块组一级行，内容不变） | 1 级 → 1 级 |
| vod | 视频站（模块组一级行，增加账号入口指针） | 1 级 → 1 级 |
| 历史别名 refresh/miniDanmaku/data/cache | 保留为深链别名，指向新归属页；不再是可导航行 | 兼容 |

覆盖率：43 个 section 全部有明确归宿，0 项进入「其他/杂项」；约 150 个设置行逐条随其 pane 迁移，
没有一行被删除或改变语义。

## 五、关键设计决策

- D1 取消索引页，而不是减少分类。P1 与 P3 同源：索引页是为容纳 4 个大类而加的收纳层。把大类的
  「子页清单」换成「组标题 + 一级行」，索引层即刻消失。桌面侧栏的组标题渲染已存在，改动集中在数据模型。
- D2 一级从 4 增到「5 组 / 13 行」。用户本轮许可增加导航项；6–12 行/页的粒度决定一级行数约等于 150/12。
- D3 大页垂直切分而非横向切页。kernel 24 行、backup 19 行切成「常用页 + 高级子页」，
  而不是按技术分组铺成同级多页（规范 §4.2「高级参数干扰常用设置」）。
- D4 小页按任务合并。miniDanmaku(1)、quality(2)、network(3)、startup(2)、cache(3) 并入语义近邻；
  合并前已核对同一用户任务、无相互冲突、不混入无关功能（规范 §4.1）。
- D5 `proxy.*` 与 `player.proxy` 继续分存两份。前者是进程级出网，后者只进 mpv 内核，语义与生效面不同，
  分属「网络与代理」与「内核高级参数」。不改存储结构（合并会改变既有用户配置的语义，规范 §9 禁止），
  只在两页文案把作用域写清。
- D6 window 页一分为二。关闭行为/退出确认/定时关机与窗口尺寸/标题栏不是同一任务；
  这是本轮唯一的「同页内容重新分组」，键与行为都不变。
- D7 背景素材 5 页保持同级。它们共享一个用户任务（设置窗口背景）但各为独立对象集合（规范 §4.2），
  本轮只把层级从 4 降到 2。
- D8 不改任何配置键、默认值、持久化或 provider 归属。本轮是纯信息架构改动，
  规范 §9 的禁止项（删功能、改默认、重置配置、换语义、引新框架）均不适用。

## 六、搜索与导航方案

- 搜索：165 条 `_hit` 全部重挂到新 section id；命中即打开真正承载该行的页面。
  今天 theme/typography/browsing/window/startup 已是叶子优先，重构后继续保持该不变式；
  新增的「内核高级参数」「WebDAV 同步」子页各自补目录项。
- 组标题不参与跳转，但参与搜索匹配：命中组名时列出该组下全部一级行。
- 路由：`/settings/:section` 形态不变；`SettingsSection.of()` 仍解析全部旧 id
  （9 个索引 id + 4 个历史别名映射到新页面），已存深链与收藏不会 404。别名不进搜索目录，避免重复真相。
- 桌面：侧栏 = 组标题 + 一级行；点击切换窗格；顶部面包屑 `设置 › 页面`，子页时 `设置 › 父页 › 子页`，
  最多 3 段（今天最多 4 段）。
- 触屏/窄窗：入口页为按组分段的列表，一次点击进一级页，子页再点一次；
  返回栈天然浅一级，每页仍是独立路由（沿用现有 `mobile_layout` 行为）。
- 折叠侧栏与 TV：组标题在折叠态退化为分隔线（现逻辑不变）；TV 保持键盘焦点列，一级行增多不改焦点模型。
- 平台门控仍在行级（`window.chrome`、`windowsPipAlwaysOnTop` 等），本轮不引入整页门控。

## 七、实施计划（确认后按序执行，风险从低到高）

| 步 | 动作 | 主要文件 | 依赖 |
| --- | --- | --- | --- |
| 1 | 分类模型：新增组标题枚举 + 重定义 `SettingsSection`（13 个一级行 + 10 个子页 + 别名表），`parentSection`/`settingsChildrenOf` 改为最多一层 | `features/settings/settings_sections.dart` | 无 |
| 2 | 注册表：各模块 `settingsGroups` 改挂一级行 id | `app/navigation/module_navigation.dart` | 步 1 |
| 3 | 派发：`SettingsSectionPane` 的 switch 迁为 builder 表；删除 9 个索引 pane | `features/settings/settings_page.dart` | 步 1–2 |
| 4 | 页面内容搬移：按 §四 逐行移动控件（`_AppearancePane` 拆两个 widget、`_VideoPane` 拆两个、`_DanmakuPane` 合并 mini、window 一分为二、data+cache 合并、kernel/backup 切高级子页），pane 落到各 feature 目录 | `settings_page.dart` → `features/{theme,playback,window,...}/*_pane.dart` | 步 3 |
| 5 | 搜索目录重挂 + 新子页补目录项 | `features/settings/settings_search.dart` | 步 3–4 |
| 6 | 布局：侧栏一级行与组标题、面包屑上限 3 段、移动路由表与返回栈 | `layouts/app_layout.dart`、`layouts/desktop/desktop_layout.dart`、`layouts/mobile/mobile_layout.dart`、`app/routing/app_router.dart`、`app/providers/settings_section_provider.dart` | 步 1–5 |
| 7 | 文案：新组标题/页面标题与描述键（slang，en/zh-CN 对称）+ `build_runner` | `lib/l10n/messages/settings/*.i18n.json` | 步 1 |
| 8 | 删除已确认无用的旧分类与遗留分支（含 P7 的失真注释） | `settings_sections.dart`、`settings_page.dart` | 步 3–6 通过后 |

## 八、风险与兼容性

- 持久化零变更：不重命名、不删除、不改类型任何 pref 键；134 个在用键与 126 条备份项本轮不动。
  D1 的清单收敛属后续工作，不与本轮混做，避免一次改动同时触碰导航与数据。
- 深链兼容：删除的 9 个索引 id 保留为解析别名，例如 `/settings/personalization` 落到新「外观与主题」。
  风险：别名与真实行同存可能让搜索重复 → 别名只在 `of()` 内映射，不进目录。
- 模块可见性：直播专属页（源/账号/关注/弹幕/录制）不进 iptv/vod/music 侧栏，沿用现有注册表；
  本轮只改分组形态，不改模块归属规则，因此无跨平台行为变化。
- 平台门控保持行级；「窗口」页在触屏上可能只剩 2–3 行，属可接受（内容随平台变，页面职责不变）。
- 主要风险 = 并发编辑：`settings_page.dart` 在 01:02 仍被另一会话写入，`dart analyze lib` 当前有 3 个
  error（`app/theme/fonts/font_library.dart:167`、`features/settings/font_manager_dialog.dart:211`），
  属字体功能未完成，与设置中心无关。步 3–4 触碰同一文件，必须等该会话让开且树可编译后再开始，
  且不得为重构方便回滚他人改动（规范 §四 执行约束）。
- 回滚单位：步 1–2 是纯数据模型，可单独回退；步 4 按页搬移、按页提交，任一页可独立还原。
- 验收（阶段二末尾执行并逐条报真实结果）：`dart analyze lib` 零 error；`build_runner` 通过；
  en/zh-CN 键对称；迁移前后设置行总数守恒（脚本比对 pane 清单，不少一行）；每个一级页与子页可达
  且面包屑 ≤3 段；每条搜索命中打开的页面确实渲染该行；`flutter build bundle` 与 Windows 构建；
  跨窗同步、备份恢复、恢复默认行为不变。

## 九、需要你确认的 3 件事

1. 一级数量：接受「5 个组标题 + 13 个可点一级行」吗？若要更少，建议合并【导航与菜单】+【浏览布局】、
   【启动与退出】+【窗口】，代价是页面回到 10–13 行且任务混合。
2. 「平台账号」是否保持直播模块专属（VOD 模块经「视频站」页入口访问同一账号存储）？
3. 「内核高级参数」「WebDAV 同步」作为子页，是否接受它们在搜索里可被直接命中（无需先展开父页）。

---

# 阶段 C 复核与三问裁定（2026-10-26，依新规范 §8-C / §9）

规范全文已存为 [settings-center-refactor-spec.md](settings-center-refactor-spec.md)。按其 §9，
上述 3 个待确认问题全部落在编码代理的自主权限内，裁定如下：

1. **一级数量**：接受「5 个组标题 + 一级行」形态。规范 §9 明示「分类和子页面的数量」「页面拆分
   与合并方案」可自主决定；§5 要求「页面层级尽可能浅」「同一层级粒度一致」，13–19 个一级行、
   6–12 行/页正满足粒度一致。不采用「更少一级行」的合并替代案（会把两个不同用户任务重新混页，
   触发 §4.1 合并前提检查失败）。
2. **平台账号归属**：保留现状行为——账号页仍挂 live 模块侧栏，VOD 经「视频站」页入口访问同一
   账号存储。规范 §9 禁止「在缺乏依据时改变跨平台/跨模块行为」，且模块专属设置归模块是本项目
   既有约定（module-scoped settings）。
3. **子页直接可搜**：采纳。「命中即打开真正承载该行的页面」是 §2.7 修复的延续，展开父页再命中
   会重新制造索引跳转。

阶段 C 逐项检查（新规范 §8-C 清单）：

- 职责重复的分类：无——5 个组标题互斥；「外观与主题」与「字体与字号」边界（配色 vs 可读性）、
  「画质与声音」与「播放器内核」边界（可感结果 vs 引擎机制）已在§三中定义。
- 层级过深：新树最深 2 级（组标题→一级行→子页），面包屑 ≤3 段；满足 §10.5「页面不应太长，
  过多可加二级路由」且不超过之。kernel(24)/backup(19) 已垂直切出高级子页。
- 无关配置同页：P6 所列「界面观感/排版」跨类割裂已由「浏览布局」「导航与菜单」归位解决；
  新页面内各行均属同一用户任务（§4.1 合并前提逐一核对过：miniDanmaku→弹幕、quality+audio→
  画质与声音、startup+关闭行为→启动与退出、data+cache→数据与缓存）。
- 拆分过度：1 行页已全部合并；保留的 10 个子页各自承载 ≥2 行或独立对象集合（accounts、
  followTags、shield、nodes 是流程/名单管理页，background 5 页是对象集合）。
- 遗漏设置项：§四迁移映射覆盖 43 个 section 全部；约 150 行随 pane 整迁，行数为验收守恒指标。
- 配置语义：D8——不改任何键、默认值、范围或业务含义；纯 IA 变更。
- 平台可见性：维持行级门控（§3.5：单平台生效不独立成页），不引入整页门控。
- 既有配置数据：零迁移；9 个索引 id + 4 个历史别名保留为 `of()` 解析别名，深链不 404。

结论：方案与新规范一致，无需修订；§八「主要风险=并发编辑」已解除（`dart analyze lib` 于
实施前实测 No issues found）。按 §8 阶段 D 风险从低到高的顺序开始实施。


---

# 阶段 D/E 实施记录（2026-10-26 02:35，已落地）

按上文方案实施完毕。改动全部为信息架构层；未触碰任何 pref 键、默认值、provider 存储或业务逻辑。

## 实际落地的结构

- 模型（`settings_sections.dart`）：一级行 21 个（含 about/iptv/vod）、子页 11 个、深链别名 13 个
  （personalization/appearance→theme、live/sources→sites、playback/video/audio→quality、
  system→startup、general→browsing、danmakuStyle/miniDanmaku→danmaku、data/cache→dataCache）。
  `of()` 直接解析为规范页；`aliasTarget/canonical` 为唯一别名表。
- 注册表（`module_navigation.dart`）：4 个共享组 + 模块自有组，行=真实页面；
  `settingsGroups` 即侧栏形态（组标题不可点）。`settingsSections` 展平含子页，模块切换的
  `ensureWithin` 因此不会把子页选择误清掉。
- 页面：`_ThemePane`（含主题预览卡+语言行）/`_TypographyPane`（去语言）；`_QualityAudioPane`
  （画质+音频两节）/`_PicturePane`；`_DanmakuPane`（显示+样式+小窗弹幕+屏蔽入口）;
  `_StartupPane`（启动+关闭与退出+定时关机）/`_WindowPane`（去关闭行为）;`_DataCachePane`
  （数据+缓存两节）；内核主页面新增 `PlayerKernelAdvancedPane` 子页（mpv 代理行随 advanced
  下沉）；备份页拆出 `features/backup/webdav_pane.dart::WebDavSyncPane`；
  sites/refresh/network/danmaku/kernel/backup 各页尾部加 `SettingsChildEntry` 子页入口。
  删除 `_PersonalizationPane`、`_SettingsCategoryPane`（9 个索引页全部消失）。
- 搜索：165 条命中全部重挂到规范页；去重 1 条重复的 showUnplayable 命中；标签三条命中改挂
  followTags；语言命中改挂 theme。
- l10n：新键 qualityAudioTitle/Description、kernelAdvancedTitle/Description、webdavSyncTitle/
  Description、closeExitGroup；navTypography/typographyPageDescription/themePageDescription/
  startupPageDescription 值随内容变化更新；en/zh 各 671 键对称。

## 与方案的偏差（均已核对语义不变）

1. 插帧、独占音频两行留在「内核高级参数」子页内（与其余 mpv 行同源同门禁），未上移主页面；
   主页面因此为 引擎/硬解/解码器/强制销毁 + 预设 + 超分 + 高级入口。
2. live 模块侧栏实为 5 标题 + 19 一级行（方案 §一.3 的「13 行」与其自己的导航树矛盾，按树实施）。
3. `_DataPane`/`_CachePane` 未合并成单一 widget，而是由 `_DataCachePane` 原样组合两节，搬移零逻辑改动。
4. `_MiniDanmakuPane` 作为小节 widget 保留（被弹幕页直接引用），未内联删类。

## 阶段 E 验收真实结果

- `dart analyze lib`：**No issues found**（含并行会话中途引入又自行修复的 shield_pane 临时错误窗口）。
- `dart run slang` + `dart run build_runner build -d`：通过。注意既有怪癖：build_runner 每次清掉
  committed 的 `lib/l10n/translations.g.dart`，需再跑 `dart run slang` 重建（本次已重建，
  `flutter build bundle`/`flutter build windows --debug` 均在其后通过）。
- IA 审计（一次性 `flutter test`，已删除）：21 行/11 子页/13 别名，无未归属枚举值、无
  行/别名重叠、每行无父级、每子页父级在册、全部枚举名 `of()` 解析规范、各模块展平闭包。
- 行守恒抽查：close/dontAskExit→startup 页、language→theme 页、audio 六行→quality 页、
  mpv 高级 12 行→kernelAdvanced、webdav 7 行→webdavSync、data/cache 7 行→dataCache 页，
  控件构造原样搬移。
- `flutter build bundle`：exit 0。`flutter build windows --debug`：152.4s，产出 pure_live.exe。
- 未执行（如实记录）：真窗口运行走查（触屏三级 push、面包屑、克隆窗同步、备份往返）未做；
  release Windows 构建未做；设置改动的运行时业务效果未在真机验证。

## 后续（非本轮）

- D1 键清单收敛、D2 pane builder 表（本轮把 switch 改为 45 值穷尽映射，仍是 switch）按原计划保留。
- 真窗口走查 + release 构建待用户或下一轮执行。

---

# D1 收口：配置身份与真值源（2026-10-26 03:10）

规范 §8 阶段 D「风险从低到高」的第一档：只补身份与清单，不改任何键名、默认值、范围或业务含义。

## 实测基线（脚本重跑，非估计）

`tool/check_prefs_manifest.ps1`（本轮新增）重derive 出的事实：155 个 prefs 键、154 个备份项、
52 条失效项；计算键只剩两族需要人看：`window.pip.<orientation>`（`pip_geometry.dart`）与
`vod.progress.<bvid>`（`vod_video_page.dart`）。§2.6 的缺口实测为 10 个键，§2.5 的类型错误 1 处。

## 落地的修正

- **§2.5 备份类型**：`theme.autoClash` 由 `BackupPrefKind.string` 改为 `boolean`。此前
  `captureSettingsSnapshot()` 用 `getString` 读它，永远返回 null —— 该设置既不进备份也不被恢复；
  现在两侧都走 `getBool/setBool`，与 `app/theme/theme_persistence.dart:156,165` 一致。
- **§2.6 备份缺口补录**（键、类型逐字照调用点）：`shell.roomWindows`、`window.chrome`、`ui.splash`、
  `vod.quality.qn`、`log.level`、`log.file`、`backup.dir`、`backup.webdav.url`、`backup.webdav.user`。
  WebDAV 口令仍在 secrets 层，不进文档。`recorder.saveDir` 明确**不**补：它是 `recorder.dir` 的
  只读回退、从不写入，现行值已按 `recorder.dir` 备份（该豁免连同理由写在脚本的 `unbackedAllowed` 表里）。
- **§2.11 相关的恢复失效缺口**：`kSettingsProviders` 补 `autoShutdownProvider`（定时关机倒计时在恢复后
  会重排）、`searchHistoryProvider`、`webdavSettingsProvider`、`iptvEpgProvider`。
  `windowSizeProvider` 保持不补并由注释说明理由：它的控制器是本窗口的尺寸跟踪器，开机 armed 一次，
  恢复的 `window.width/height` 应在下次启动生效，而不是中途改窗口大小。导航态控制器（模块/站点选择）
  继续按原约定各窗口独立。
- **§2.3 重复解析**：`shell.closeAction` / `shell.dontAskExit` 的解析收进
  `app/providers/shell_settings_provider.dart` 的 `storedCloseAction()` / `storedDontAskExit()` +
  `kCloseActionPref` / `kDontAskExitPref`；`app_bootstrap.dart` 删掉自己那一份 switch 改为导入。
  两份实现的默认值与作用域完全一致，行为不变（启动期无 ref 的读取点仍是直读 facade）。
- **§1.2 清单漂移**：新增 `tool/check_prefs_manifest.ps1`，把三份手维护清单（`kBackedUpPrefs`、
  `kSettingsProviders`、调用点）变成互相校验：未备份的键、类型不符的备份项、已无人使用的备份项、
  读了 prefs 却不在失效表里的 NotifierProvider、以及包层直接持有 prefs 键，都会让门失败。
  豁免以「键 → 一句理由」的表形式写在脚本里。`tool/README.md` 记录了它的解析口径
  （字面量、文件内 `const`（同名多处按声明位置就近取，因此 `prefsKey` 这类复用名可正确解析）、
  以及 `String key` 形参的本地辅助函数）。

## 阶段 C 复核（本轮）

- 未新增抽象框架：没有引入新的清单类型或运行时注册表，仍是一份既有清单 + 一道静态检查（规范 §7）。
- 未改配置语义：没有任何键被重命名、删除、改类型或改默认值；唯一的行为变化是「原本静默丢失的
  `theme.autoClash` 与 9 个键现在真的进备份并可恢复」，属缺陷修复而非语义变更。
- 既有数据兼容：恢复只写文档携带的键，旧备份不会重置新项。

## 阶段 E（本档增量）真实结果

- `dart analyze lib`：No issues found（03:07，含并发会话 03:03 的 `audience_settings_pane.dart` 一轮）。
- `powershell -File tool/check_prefs_manifest.ps1`：passed（155/154/52）。
- 定向分析本轮 4 个改动文件：0 issues。

## 仍开着的项

- **D2（pane 搬出 `settings_page.dart`、派发表）**：`settings_page.dart` 现为 2784 行，仍是全仓最长的
  Dart 文件，规范 §6 展示层与 §10.5「页面不应太长」直接指向它。它是 10 分钟自动任务的每轮写入点，
  整文件重写会静默丢掉对方在途的行级改动，因此需要与自动任务错峰（暂停一轮，或在独立分支做完再并回）。
  派发表保持编译期穷尽的 switch 形态（不是 `Map<SettingsSection, ...>`），搬迁到注册表一侧的独立文件，
  这一取舍的理由记在这里：穷尽性比可注入性更值钱，且规范 §7 禁止为拆分引入新框架。
- **D3 语义项**（§2.1 代理两份定义的作用域文案、§2.2 `recorder.saveDir` 的真正迁移写入、
  §2.10 `vod.progress.<bvid>` 的无界键空间、§2.11 全量恢复默认的作用域）：属规范 §4.4/§9 的
  「无法从代码确定的产品决策」，保持行为不变并等确认。
- 真窗口走查与 release 构建仍未执行。

---

# 阶段 E 静态验收（2026-10-26 04:10）

规范 §8-E 中可静态执行的部分全部实跑，结果均为实测数字，非推断。运行时项（真窗口走查、备份往返、
release 构建）本轮仍未执行，已在文末单列。

## 实测结果

- `dart analyze lib`：No issues found（04:08 前后各一次，工作树含并发会话未提交改动）。
- `tool/check_prefs_manifest.ps1`：passed — 155 键 / 154 备份项 / 52 失效项；计算键仍只有
  `window.pip.<orientation>` 与 `vod.progress.<bvid>` 两族待人工审阅。
- `tool/check_settings_ia.ps1`（本轮新增，见下）：passed — 47 个 section（34 真实页 / 13 深链别名）、
  21 条侧栏一级行、13 个子页、47 条派发分支、188 条搜索命中。
- `lib/l10n/messages/*`：21 个命名空间、1684 个键，en / zh-CN **零**非对称。

## 配置身份对 HEAD 的差集（规范 §7、§8-E 第 3 条）

以重构前的 HEAD（`b484220a4`，00:17）为基线，逐文件比对 `apps/pure_live/lib` 与 `packages` 的 prefs 字面量：

- 基线 310 个键、现在 314 个，**消失 0 个**；新增 4 个：`window.pip.landscape`、`window.pip.portrait`
  （PiP 几何分方向）、`playback.background`（VID-06 后台播放）、`danmaku.filter.similarity`（VID-22）。
  即 IA 重构与 D1 没有丢掉任何一个既有配置身份，也没有隐式改名。
- 逐键读取点比对：**默认值分歧 0 处**（同一键在不同调用点不会各写各的 fallback）；类型分歧仅
  `get*/remove` 组合（清除键的正常形态）。脚本报出的 8 个「只读键」是误报，已核：`theme.*` 与
  `app.locale` 的写入走 `theme_persistence.dart` 的 `_store(key, value)` 助手，门脚本的形参解析已覆盖。

## 新增门禁：`tool/check_settings_ia.ps1`

结构事实被写在四处（`SettingsSection` 注册表、`kModuleNavigation` 菜单、`settings_page.dart` 的 pane
switch、`settings_search.dart` 目录），自动任务每轮都可能只改其中一处。门禁重解析这四份并校验：

- 每个 section 恰属于「一级行 / 子页 / 别名」之一；别名不成链、不指向别名、不兼作行；
- `parentSection` 与 `settingsChildrenOf` 互逆；子页的父级必须是菜单里的一级行；子页不再嵌套子页
  （即最多两级页面、面包屑最多三段）；
- 每个 section 都有 pane 分支；别名分支渲染的必须正是其 canonical 页的 pane；
- 每个子页确实由其父页 pane 打开（`SettingsChildEntry` / `openSettingsChild` / `settingsChildrenOf`）；
- 搜索命中必须指向真实页且是该模块菜单能打开的页；每个真实页至少有一条命中；
- 命中的文案键必须出现在该 pane 可达的文件里。

反向验证（在 `.tmp/negtree` 副本上注入 4 类漂移后跑门禁，副本已删除）。注入与结果：

| 注入的漂移 | 门禁是否报错 |
| --- | --- |
| 命中改挂到深链别名（`browsing`→`general`） | ✅ 报「指向别名」，并连带报该别名不在任何模块菜单里 |
| 子页入口从父页 pane 摘掉（`nodes`） | ✅ 报「子页从未被父页 pane 打开」 |
| 删除一个 pane 分支（`webdavSync`） | ✅ 报「`webdavSync` has no pane case」 |
| 命中改挂到另一个**真实**页（`audience`→`typography`） | ❌ 不报错 |

**最后一类当前检不出来**，原因写在脚本头部注释里：私有 pane 都在 `settings_page.dart`，而它导入整个
设置表面，可达集因此覆盖全部文案键。这条检查要等 D2 把 pane 拆到各自文件后才变成真正的归属门。
严格口径（只看 pane 自己的定义文件）实测在真树上有 27 处误报（`_RecordingPane` 只是
`recorder_page.dart` 的外壳；导航/竖屏等页级命中的标题键是页名而非行名），所以本轮不收紧，
避免把门禁做成一堆豁免表。


# 规范变更（2026-10-26 08:51）：§10.10「不写测试，不build运行」

用户重发规范，与仓库副本逐条对照后只有一处新增：§10 增加第 10 条。已按原文同步进
`docs/settings-center-refactor-spec.md`，其余文本未动。

**这条改变阶段 E 的口径。**§8-E 的清单末项「静态分析、相关测试及必要的平台构建」与 §10.10 冲突时，
以 §10「最终完成标准」为准。因此本项目设置中心的验收方式是：

- 跑：`dart analyze lib`（§8-E 的「静态分析」仍然必须真跑）；
- 跑：`tool/check_prefs_manifest.ps1`（配置身份：键数 / 备份 / 失效 / 包级归属）；
- 跑：`tool/check_settings_ia.ps1`（四处结构事实一致：注册表 / 菜单 / pane switch / 搜索目录）；
- 不新增测试，不 `flutter build`，不做 GUI 运行期点击。§8-E 里「真实业务效果」「导入导出往返」
  「既有用户数据兼容性」这几条因此只能靠代码链路审计与门禁覆盖，凡未经运行期证实的都在交付里标注。

先前各轮（含 04:10 那份静态验收）记录的 `flutter build bundle` 结果保留为历史事实，但不再是本线的门禁。

## 本轮在现树上的复验（数字来自实际重跑）

| 检查 | 结果 |
| --- | --- |
| `tool/check_settings_ia.ps1` | 通过：47 sections（34 真实页 = 21 一级行 + 13 子页，13 深链别名）、47 个 pane 分支、202 条搜索命中 |
| `tool/check_prefs_manifest.ps1` | 通过：167 个键、166 条备份、54 项失效；5 处计算键调用点仅提示（`pip_geometry.dart` 的每窗几何、`vod_video_page.dart` 的 `vod.progress.<bvid>`，属 §2.10 待确认项，不是新增漂移） |
| `dart analyze lib`（apps/pure_live） | No issues found |

§10 逐条对照：1–4、6–9 由阶段 A/B/C/D 的记录与本表支撑（每项设置的处置见上文 D1 清单与
`docs/settings-review-checklist.md`）；**第 5 条仍有一处未闭合**——`settings_page.dart` 已长到 3003 行 /
127 KB，47 个 pane 挤在展示层单文件里，违反「页面不应太长」与 §6 的展示层职责边界。这就是 D2。

## D2 因为这条变更而变难，不是变易

没有构建/运行期兜底后，把 ~18 个 pane 从单文件里搬出去只能靠 `dart analyze` + 门禁自证。因此 D2 开工前
必须先做两件事，否则拆完等于没验：

1. `check_settings_ia.ps1` 的 pane 归属检查目前「明知无牙」（私有 pane 全在 `settings_page.dart`，
   可达集覆盖全部文案键）。拆分要让「命中指向真实页」变成真门，脚本就得跟着改成按 pane 自己的文件解析，
   并同时把已知 27 处误报（页级标题键、`_RecordingPane` 这类外壳）用带说明的豁免表钉住，而不是靠可达集放过。
2. 自动任务每轮（今日 08:05 起 8 轮）几乎都在写 `settings_page.dart`。拆分要与它串行，不能抢写。

# 阶段 A 键侧证据补全（2026-10-26 10:15）：`tool/audit_settings_disposition.ps1`

规范 §10.3 要求「每项现有设置都有明确的处理结果」。此前只有两份侧面清单：
`docs/settings-review-checklist.md` 从参考端逐行描述（键名多为参考端旧名），
`docs/settings-sync-inventory.md` 是页级摘要。工作区自己的键侧清单没有，故补一个只读工具与一份生成文档：

- `tool/audit_settings_disposition.ps1` —— 解析全部 `StoragePrefs` 调用点（沿用门禁的键解析规则：
  字面量 / 同文件常量按声明位置 / 全局唯一常量 / 以 key 为形参的本地助手），并给出每个键的
  类型、是否进 `kBackedUpPrefs`、是否在评审清单文本里出现、持键文件、设置面引用、业务面引用。
- `docs/settings-key-disposition.md` —— 生成物，177 个键逐条一行，含口径与局限。

## 实测（本轮真跑）

| 项 | 结果 |
| --- | --- |
| 键数对齐 | 本工具 177 个键，`check_prefs_manifest.ps1` 亦 177（176 条备份 + `recorder.saveDir` 豁免）；两侧键集**差集为 0** |
| 未进备份 | 仅 `recorder.saveDir`（§2.2 已裁定：机器相关路径，不随备份走） |
| 计算键 | 5 处（`pip_geometry` 每窗几何、`vod_video_page` 的 `vod.progress.<bvid>`），仍属 §2.10 待确认 |
| 清单未点名 | 62 个键的字面键名不出现在评审清单里 |
| IA 门 | 通过：48 sections（35 页 = 21 行 + 14 子页，13 别名）、48 个 pane 分支、223 条命中 |
| `dart analyze lib` | No issues found |

08:51 那组数字（167 键 / 47 sections）与本轮不同，是同一小时内自动任务又落了行，不是解析分歧。

## 「62 个未点名」的成分，已抽样核实

不是 62 个缺失项，而是两类：① 同一行用参考端键名描述（REC 组写 `use_pinyin_folder` 而不写
`recorder.*`，而代码侧 16 个 `recorder.*` 键早于 REC 组的勾选状态就实现了）；② 低频内部状态本就
不配行（`browse.module`、`search.history`、`iptv.guide.active` 一类当前态）。要把这一列收敛到 0，
需要的是「参考端键名 ↔ 本工作区键名」的显式映射列，归评审清单那边补，不改代码语义。

## 本轮同时证实：文件粒度做不了这条门

先按传递 import 闭包算「设置面」，得 212/221 个文件——任何「某键是否出现在设置面里」的判定都变成恒真；
改成一跳直接 import（105 个文件）后 `ROW`/`APPLIED` 双双 177/177，同样恒真。结论与 IA 门那条「明知无牙」
是同一件事的两面：**文件粒度证明不了「某个控件绑到某个键」**，只能出清单，不能出门。真正能出门的粒度
要等 D2 把 pane 拆成每页一文件（`_RecordingPane` 这类外壳页现在是主要混淆源）。因此本轮明确不把
disposition 脚本升级成第三道门禁，它只做证据；这也把 D2 的必要性从「代码整洁」提升成「§10.3 能否被自动验收」。

# 行级归属尝试与否定结果（2026-10-26 11:12）

规范 §5「设置项有且只有一个规范的配置定义」与 §10.3「每项设置都有明确处理结果」，理想上希望按**页**列出
它承载哪些键，并据此判 §10.5 的密度。本轮做了这件事，做完判定不可交付，工具与文档已删除。否定结果记下来，
免得下一次再走一遍：

1. **按文件归属：恒真。** `features/settings/` 的传递 import 闭包覆盖 app 侧 221 个 dart 文件里的 212 个；
   收窄到一跳直接 import 是 105–109 个文件，此时「键是否被设置面引用」177/177、「是否被面外应用」177/177。
   任何判定在这个粒度都失去区分力。
2. **按 pane 类边界 + 键所绑定的成员归属：误报可证。** 分派 switch 能可靠解析（49 个 section、13 个别名
   归一到真实页），但成员名与 UI 词汇撞名：`playback.background` 之类被算进 `nav` 页，是因为导航页里
   `colors.background` 这种画笔属性与设置成员同名；实测 `_NavPane`（1121–1326 行）内既无 `muted` 也无
   `globalMute` 字样，而全局静音行真正出现在 2752 行起的 `_QualityAudioPane`。收紧成「必须是 `.成员` 属性
   访问」仍不足以排除这类同名。结论：**行级绑定不落在文件里就查不准**，D2 拆页是这条证据的前置条件，
   不是可选项。这也把 IA 门那条「命中改挂到另一个真实页检不出来」的无牙案例解释清楚了：同一个原因。
3. **顺带证实门禁有效。** 收尾复跑 `tool/check_prefs_manifest.ps1` 报失败 6 项 + 1 项缺失效登记，全部来自
   `features/settings/portrait_fullscreen_settings.dart`（11:09 写入，账本 11:10 有条目，且账本自述
   「POR-05 正由并发会话」）——那是并发会话的**在途状态**，不是已落账的缺陷。本轮没有替它补两份清单，
   也没碰该文件；下一次复跑若仍失败才需要提出来。

键侧清单刷新（`docs/settings-key-disposition.md`，工具同一套解析规则）：217 键 / 未进备份 6（即上面那批
在途键）/ 清单未点名 53 / 计算键 5 处。IA 门 49 sections（36 页 = 22 行 + 14 子页 + 13 别名）、49 个 pane
分支、237 条命中，通过。

复跑 `dart analyze lib`（11:14）不再是 0：9 error + 1 warning，全部落在 `features/room/player_surface.dart`
（`Undefined name 'widget'`）与 `features/room/room_page.dart`（`modeFor` 未定义、`GeometrySnapshot.width/
height`、`double Function(double)` 传成 `double`），同一条并发会话的竖屏/PiP 在途改动；设置面自身的文件
没有报错，本轮我只改了 docs 与 tool。按既有约定不替别人补完、也不回滚别人的文件，故本轮验收如实记为
「门禁与静态分析在非我方的在途改动上未收口」。

# 执行侧摘要已独立成文（2026-10-26 11:55）

后续任务不必读这份不断变长的裁定史：当前判据、新增设置的完成定义、验收命令（§10.10 口径）、
无法自动验收的两块与待确认项，都在 `docs/settings-center-governance.md`。本文件继续承担历史与逐条裁定。

11:51 复跑（那条并发会话已收口）：`dart analyze lib` No issues found；prefs 门 222 键 / 221 备份 / 64 失效
通过（唯一豁免仍是 `recorder.saveDir`，`backup_settings.dart` 已写明理由）；IA 门通过，
49 sections（36 页 = 22 行 + 14 子页 + 13 别名）、49 个 pane 分支、242 条命中。工作区 155 个未提交文件。

# §10.5 移动端兼容审计（2026-10-26 12:0x，只读，未改代码）

§10.5 的后半句「需要兼容移动端显示」此前从未单独审过（历轮只看结构与键）。本轮按可判定的四条查：

| 判据 | 实测 | 结论 |
| --- | --- | --- |
| 子页在触屏是否真的走独立路由 | `openSettingsChild`（settings_page.dart:133）：`!deviceProfile.isDesktop && width < kSettingsCompactWidth` 时 `push(SettingsSectionRoute(...))`，桌面就地切 pane | ✅ 与设计一致 |
| 每个页/子页是否可寻址 | 路由 `/settings/:section`（route_names.dart:59）经 `SettingsSection.of()` 解析，别名也解析 | ✅ 14 个子页与 13 个别名都能直达 |
| 长页是否可滚 | 三处 `SingleChildScrollView`：搜索结果（293）、触屏菜单（434）、pane 本体（503，`SettingsSectionPane`） | ✅ 桌面外壳与 push 屏共用可滚 pane |
| 选择控件是否守住自适应约定 | 设置面 44 处选择行**全部**走 `SettingsChoiceRow`（桌面下拉 / 触屏整行对话框），裸 `DsSelect(` 命中 0；含本轮新落的 `local_interaction_pane.dart`、`room_card_pane.dart` | ✅ 约定没被新行绕过 |
| 悬浮依赖 | 设置面 `MouseRegion`/`onHover` 命中 0 | ✅ 没有 hover-only 入口 |

**一条排除掉的假警报**（值得记，因为看起来很像缺陷）：设置面 14 个对话框写死 `DsDialogStyle(width: 420–640)`。
读依赖源码后确认这不是问题——`DsDialog` 自己说明「takes its preferred width and shrinks on narrow windows」，
外层 `ConstrainedBox(viewInsets + 16)` 会把宽度收到视口内（desen_ui-0.3.2
`lib/src/components/dialog/dialog.dart:21`、`:128`）。按文件名字面量数「固定宽度 = 溢出」会误报 14 处。

**一条真实发现（未改，属产品决策）**：`app_router.dart:244` 是
`SettingsSection.of(section) ?? SettingsSection.theme` ——未知段名不报错也不回落错误页，而是**静默显示主题页**。
注册表注释里「stored links never 404」的本意是兼容 13 个别名，但这个写法把「别名兼容」和「链接写错」混成同一
行为：手滑的深链会被当成主题页，违反规范 §8-E 的「页面入口有效性」可观察性。可选处置有三种，代价不同：
①未知段名保留回落但在页顶给一条「该设置已移动」提示；②未知段名进现有的 not-found；③维持现状，只在门禁里
要求段名必须能解析。规范 §9 禁止我无依据改变既有行为，故留待裁定。

**仍未覆盖**：§10.10 不许 build/运行，所以真机 360dp + 大字阶下的实际溢出、触屏对话框高度、
键盘弹起时的滚动都未验证；本表只证明**代码路径**与约定，不证明像素。
