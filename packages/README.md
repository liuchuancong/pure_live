# packages/ 公共模块目录(实测)

> 本表由 `pubspec.yaml` 依赖声明与 barrel 导出**实测生成**(2026-10-10),不是计划清单。
> 四 App 的边界与"哪个包应该被谁消费"见
> [docs/architecture/application-portfolio.md](../docs/architecture/application-portfolio.md);
> 本表说的是**现在真实是什么样**,§4 列出与目标的偏差。
>
> 列含义:**公共面** = barrel 实际导出的内容;**消费者** = 在 pubspec 里声明依赖它的包/应用。

## 1. L0 foundation(14)

| 包 | 公共面 | 消费者 | 状态 |
|---|---|---|---|
| `utils` → pure_live_utils | async / collections / conversion / equality / errors / identifiers / math / numbers / result / strings / time / types / validation | logging, network, auth, backup, cache, sync | ✅ 叶子,真在用;新增 8 个模块按实测重复计数立项,**尚无消费者**(utils README 未验证清单) |
| `logging` → pure_live_logging | logger / record | network | ✅ |
| `network` → pure_live_network | client(dio 封装)/ failure 分类 | extension, providers(bilibili/huya/douyu/external_tvbox), foundation/release→已撤(改端口), app | ✅ |
| `storage` → pure_live_storage | file_key_value_store / stores / migration / migration_runner + **preferences(键/codec/信封/命名空间/导入/变更流/旧形状升级)** | extension, permission, identity, services(favorites/history/playlist), app | ✅ 76 测试;偏好机制自 `features/settings` 搬入(台账 §5 决策)。**机制至今零真实消费者**,且与 `FileKeyValueStore` 的串接没跑过 |
| `files` → pure_live_files | atomic_file / file_names / paths | **无** | ⚠️ 零消费者(能力已实现,等消费方) |
| `cache` → pure_live_cache | policy / store / disk_tier(两级缓存) | **无** | ⚠️ 零消费者 |
| `events` → pure_live_events | event_bus | **无**(规则本身禁止用它替代接口) | ✅ 修了每调用一次泄漏一个 controller、`hasListeners` 的类型谎言、sync 投递让一个坏监听者静音整条总线;11 测试 |
| `diagnostics` → pure_live_diagnostics | recording(有界环 / 守护执行 / 计时) | extension | ✅ 环改成真 O(1)、`measure` 换单调钟、reporter 抛异常不再挂死调用方;18 测试;面仍薄(只有一个消费者) |
| `auth` → pure_live_auth | credential_store / ports / session | **无** | ⚠️ 零消费者;白名单里 backup→auth 尚未发生 |
| `backup` → pure_live_backup | engine / manifest / webdav_store | app | ✅ |
| `sync` → pure_live_sync | sync_engine(拉/推 + 墓碑 + 游标 + 冲突策略) | **无** | ✅ 修了「游标回显 → 每次全量重拉」与空闲 push 谎报起点;拒绝行计数;18 测试 |
| `l10n` → pure_live_l10n | locale / translation_bundle | **无** | ⚠️ 零消费者(app 侧本地化未接) |
| `platform_info` → pure_live_platform_info | platform_info(能力矩阵 + 探测) | **无** | ✅ 未识别系统不再借用 web 的乐观答案(新增 `unknown` 全 false 底线);web 输入方式改为显式传入;21 测试 |
| `release` → pure_live_release | version / update_feed (+新 `UpdateFeedTransport` 端口) | app | ✅ 把本包对 `pure_live_network`的隐形依赖换成注入端口(L0 不得依赖 L0,原引用藏在 dev_dependencies 里);feed 读取加 15s 死线与首次测试;28 测试 |

## 2. L0.5 integrations(3)

| 包 | 公共面 | 消费者 | 状态 |
|---|---|---|---|
| `media` → pure_live_media | media_track_mapping / ticket_source / ticket_policy / ticket_swap / player_kernel_host / watchdog / playback_trace + 转出 `PlayerConfig`、`MediaCorePlayerView`、`MediaSessionBootstrap` | app | ✅ 播放面最完整的一包 |
| `python_runtime` → pure_live_python_runtime | python_spider_host / local_gateway / spider_worker.py | **只有 external_tvbox** | 🔴 随插件栈一起悬空(见 §4) |
| `firebase` → pure_live_firebase | firebase_bootstrap | **无** | ⚠️ 零消费者 |

## 3. L1 ecosystem(11)

| 包 | 公共面 | 消费者 | 状态 |
|---|---|---|---|
| `platform` → pure_live_platform | 18 组模型:ContentRef / Page* / MediaTicket / PluginManifest / Cookie / PermissionGrant / TaskModels / ResolverDescriptor / Error / Diagnostics … | 几乎所有包 + app | ✅ 统一词汇,2973 行 |
| `capability` → pure_live_capability | capabilities(Live/Vod/Music/Search/Feed/Browse/Resolve…)+ capability_registry | external_tvbox, js_runtime, resolver, providers, app | ✅ |
| `permission` → pure_live_permission | policy_permission_manager / extension_network / extension_cookie_store / key_value_permission_store | extension, app | 🟡 app 依赖它属偏差(§4) |
| `task` → pure_live_task | task / task_scheduler / in_memory_task_scheduler / cancellation | extension, app | ✅ |
| `extension` → pure_live_extension | gateway / managed_extension_gateway / context / runtime / source / network_transport_bridge / persistent_context | app | 🟡 网关今天还承载"内置源装载",职责待与插件宿主分离 |
| `resolver` → pure_live_resolver | resolver / resolver_registry / capability_resolver | app | ✅ 补上一直存在却没人抛的解析超时预算(默认 12s,分类成 `resolver.timeout`);35 测试 |
| `identity` → pure_live_identity | identity(加权匹配 + 门槛)/ identity_index | **无** | ⚠️ 零消费者:跨源去重/换源还没接(portfolio §2 W5 卡点) |
| `plugin_api` → pure_live_plugin_api | manifest_validator / lifecycle / plugin_runtime / host_bridge / sandbox | js_runtime, plugin_host | 🔴 悬空(无 App 装配) |
| `plugin_host` → pure_live_plugin_host | plugin_bundle / plugin_store | **无**(栈仍悬空,等宿主 App) | 🟡 修了 id `..` 能让 `uninstall` 递归删到应用数据目录 + 读取加体积上限;5 测试 |
| `js_runtime` → pure_live_js_runtime | fjs_sandbox / js_plugin_runtime / js_prelude | external_tvbox, providers/music | 🔴 悬空(等 pure_tvbox / pure_music) |
| `external_tvbox` → pure_live_external_tvbox | spider_contract / spider_vod_provider / js_spider_handle / js_drpy_spider_handle / tvbox_repository / tvbox_repo_fetcher / data_source_runtime | providers/iptv, python_runtime(互依,已白名单);它自己声明了 plugin_api(沙箱契约,一直只在 import 里存在,现已补声明并进 §4 白名单) | 🔴 悬空,整体归 `pure_tvbox` |

## 3bis. L2 services(5)/ L3 ui(5)

| 包 | 公共面 | 消费者 | 状态 |
|---|---|---|---|
| `services/favorites` | favorites / key_value_favorite_repository | app | ✅ |
| `services/history` | history / key_value_history_repository | app | ✅ 但 `record`/`finish`/`flush` 仍无调用方 |
| `services/playlist` | playlist / key_value_playlist_repository | app | ✅ |
| `services/search` | search_aggregator(扇出/超时/失败隔离 + 取消缝) | app | ✅ 16 测试 |
| `services/feed` | feed_aggregator(按源分节 + 跳过记账 + 按源游标与三态校验) | app | ✅ 23 测试;修了「游标贯穿」只做一半;跨源节仍受形状限制(w5 §2) |
| `ui/design` | semantic_roles / scale_tokens / control_metrics / design_tokens(解析器 + AppearanceSettings) | ui_kit, lyric;app | ✅ 令牌全集补齐(色角色/距/圆/字阶+可读下限/动效归零/密度/交互尺寸/焦点视觉),20 测试;纯 Dart 无 Flutter import。ui_kit/adaptive 已接(app 侧传 tokens 待做) |
| `ui/ui_kit` | **app_facade**(Notice/Dialog/Loading)/ tokens_theme(ThemeExtension)/ poster_card / status_views | adaptive;无 App 依赖 | ✅ 组件改读令牌,`PosterCard.width` 之前被忽略已修;门面仍没人用。**只过静态分析** |
| `ui/adaptive` | ui_style(六风格注册,统一 `_applyTokens` 映射)/ app_background | app | ✅ 密度/控件尺寸/字阶下限/焦点/动效改由令牌决定,风格只剩装饰差别;声明了 design+ui_kit 依赖。**只过静态分析,app 还没传 tokens** |
| `ui/lyric` | lyrics_surface | **无**(等 pure_music) | ✅ 修了换曲时「进度与重解析先后」导致的高亮错行 + 首帧无进度。**只过静态分析,flutter_lyric 实际行为未测** |
| `ui/player_ui` | option_sheet / episode_panel | **无**(等房间页重构) | ✅ 修了选项表不可滚动(同包 ep 面板早已 scroll-controlled)、空表开空面板;令牌化 + 语义标签。**只过静态分析** |

## 3ter. L4 features(9)与 L5 providers(6)

| 包 | 公共面 | 消费者 | 状态 |
|---|---|---|---|
| `features/live` | live_session(不可变选流状态机:两轴已提交选择 + 带身份的切换尝试) | **无 App 消费者** | ✅ 重写完成:迟到回调不再能改写选择、按轴独立、未提供的变体具名拒绝;13 测试 |
| `features/vod` | episode_navigator(不可变连播队列)/ watch_progress(双阈值续播) | **无 App 消费者** | ✅ 重写完成:按 (source,id) 匹配修好连播静默失效、含 `/` 的 id 不再撞行、看完不再续到 99%,20 测试 |
| `features/music`(pure_live_music_feature) | music_queue(不可变)/ music_source_bridge(端口)/ lx_music_repository | **无 App 消费者**;`pure_music` 壳还不存在 | ✅ 重写完成:L4→L5 直连 provider 改成端口注入、删歌跳曲与过期 step 修好,23 测试。**端口目前没有实现** |
| `features/iptv`(pure_live_iptv_feature) | zap_channel / channel_zapper(不可变)/ epg_window | **无 App 消费者** | ✅ 重写完成:空 url 条目不再崩、换组不跳台、`visible()` 不再漏内部 list、EPG 向上取整,24 测试 |
| `features/search`(pure_live_search_feature) | search_term / search_history(接口)/ stored_search_history / search_result_order / search_controller | **无 App 消费者**(等拆壳波)| ✅ 重写完成:折叠键统一"同一次搜索"、信封带版本与 v0 迁移、坏档记账不装作没搜过、结果按内容定序、世代栅栏丢弃被取代的答案;22 测试 |
| `features/home` | home_tab / home_layout_repository / home_layout_service / stored_home_layout | **无 App 消费者**(等拆壳波) | ✅ 重写完成:排序与默认可见性分职、按 App 命名信封落盘、坏行记账、18 测试 |
| `features/account` | site_account(视图+接口)/ credential_site_accounts | **无 App 消费者**(等拆壳波) | ✅ 重写完成:假句柄与"按 last 登出"两个真缺陷修掉、状态三分(过期可刷/禁用/无账号)、密钥体积上限,10 测试 |
| `features/backup`(pure_live_backup_feature) | backup_reports / snapshot_remote(端口)/ webdav_snapshot_remote / backup_document / webdav_backup_service | **无 App 消费者**(apps/pure_live 仍自带一份 `{manifest,payload}` 编解码) | ✅ 重写完成:分工写清(端口换 final class 的可测性、报告是数据、快照名守路径逃逸),18 测试 |
| `features/recorder` | recording_task(不可变状态机) | **无 App 消费者**;引擎在录制波次 | ✅ 重写完成:公开可写 state 收回、排队不再报"已录 1 小时"、文件名路径校验、id 不再撞,13 测试 |
| `providers/huya` | huya_source / huya_signing(antiCode) | app | ✅ |
| `providers/bilibili` | bilibili_vod_source / bili_wbi | app | ✅ 只有 vod 面;live 面未做 |
| `providers/demo` | demo_source(离线种子) | app | ✅ |
| `providers/iptv` | iptv_source / xmltv_parser | **无** | ⚠️ 实现了但没装配(pubspec 描述还写着 skeleton) |
| `providers/music` | music_source_host / music_script_crypto / music_script_prelude | **无** | ⚠️ 同上,等 pure_music |
| `providers/douyu` → pure_live_douyu | douyu_source(Feed/Browse/Search/Resolve)/ douyu_sign(描述符 + md5 链)/ douyu_row 三种行形 | **无**(等 `pure_live` 房间页装配) | ✅ 队列第 8 项已实现匿名切片:签名换链带 `expiresAt`,49 测试把 dio 传输换成罐头适配器。**未录到真实响应**,fixtures 仍空(包 README 未验证) |

## 4. 与目标的偏差(必须修的三组)

1. **整条插件/TVBox 栈悬空**:`plugin_api` / `plugin_host` / `js_runtime` / `external_tvbox` /
   `python_runtime` 没有任何 App 消费者(`c8f30b45e` 把插件系统从壳里撤掉后就这样了)。按 ADR 0022
   它们的归属是 `pure_tvbox`/`pure_music`,**在那些 App 建起来之前不要删** —— 代码是好的,缺的是宿主。
2. **`apps/pure_live` 还在依赖 `permission` + `extension`**:portfolio §3 的矩阵里直播 App 不装配权限网关。
   这是"拆壳"那一步没做完的残留,不是设计。
3. **4 个包名违反 `目录短名 ↔ 包名一一对应`**(package-architecture §3):
   `features/backup`→`pure_live_backup_feature`、`features/search`→`pure_live_search_feature`、
   `features/iptv`→`pure_live_iptv_feature`、`features/music`→`pure_live_music_feature`,
   全是为了躲 `foundation/backup`、`services/search`、`providers/iptv`、`providers/music` 的重名。
   要么改层内短名(如 `features/backup` → `features/webdav_backup`),要么给包名加层前缀 —— 需要一次
   决策,不能各改各的。
4. ~~**pubspec description 失真**~~ **已修(2026-10-10)**:`providers/{iptv,music}`、`ui/{adaptive,lyric,player_ui,ui_kit}`、
   `features/settings`(现已并回 storage)七包原本都还写着 "skeleton",`providers/douyu` 写着空壳。全仓 `grep -l skeleton --include=pubspec.yaml`
   现已为 0。描述是别人判断"这包能不能用"的第一入口,失真等于误导 —— 新描述照各包 barrel 与文件头 Purpose 写。

## 5. 添加 / 删除一个包

- 新建只能走 `tool/scaffold_package.ps1`;**先有消费者再建包**(portfolio §6 第 7 条)。
- 删除要同时改根 `pubspec.yaml` 的 `workspace:` 列表,并清 `packages/<层>/<名>` 下 pub 生成的
  `.dart_tool/` 残留,否则护栏会报 `unregistered-package` 的反向问题。
- 层级方向与 App 边界由 `dart run tool/check_architecture.dart --strict` 强制,白名单在
  [docs/architecture/dependency-rules.md](../docs/architecture/dependency-rules.md) §4。同一把护栏现在还比对
  `lib/` 里的 import 与 pubspec 声明(§4.1 `undeclared-dependency`):workspace 会让未声明的 import 照样解析,
  所以本表的「消费者」列此前系统性少报真实边 —— 现在漏声明会让 CI 变红,列才是可信的。
