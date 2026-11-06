# live_cache 台账

> 规范：`live_cache` 缓存模块技术设计与开发规范 v1.0（图片缓存为主，API 内存缓存为辅）
> 实施日期：2026-11-06
> 状态：包 + App 接入 + 设置页已完成；运行时观感归用户真机验收

## 1. 范围

替换掉原来「所有图片一个策略」的缓存：`cached_network_image` + `flutter_cache_manager`
（30 天 / 320 个对象 / 无分类 / 无统计）已整体下线，改为新包 `packages/live_cache`。

已解决的四个实际缺陷：

1. 6 处传 `width`/`height` 的调用（聊天头像与表情、音频封面、壁纸）过去被普通
   `CacheManager` 忽略（debug 断言、release 静默失效）——现在按解码框真解码。
2. 「清理图片缓存 / 刷新缩略图」过去扫掉整个 `images/`，连红果转出的 `covers/` 和本地
   生成的 `recording_covers/` 一起删——现在清理范围只在 `live_cache/` 树内，录像帧搬到
   `<cacheRoot>/recording_covers/`。
3. 红果签名 URL 每次列表都变、同一张图反复写文件——现在源图与转出的 PNG 都走稳定业务
   Key（URL 的 path 段）存进 `live_cache`。
4. 图片下载过去不走 `networkFactoryProvider`，切代理后仍用旧路由——现在注入
   `ClientProfile.media` 的 `LiveHttp`，跟随当前代理并进网络日志。

## 2. 包结构

```
packages/live_cache/lib/src/
├── models/     cache_priority, cache_source, cache_failure, cache_entry,
│               cache_statistics, image_cache_config, memory_cache_config, cache_config
├── image/      image_cache_policy, image_cache_policies, image_request, image_result,
│               image_loader, live_cache_memory, live_image_cache, live_cache_image
├── storage/    cache_directory, cache_file, cache_index, cache_storage
├── memory/     memory_cache
└── management/ live_cache_manager
```

- **Key**：显式 `cacheKey` > URL；再拼分类、版本、可选账号作用域，SHA-256；
  文件落在 `images/<category>/<前2位>/<hash>.img`。URL 与 Token 不进文件名和日志。
- **磁盘**：先写 `temporary/*.part`，魔数校验通过后 rename；启动清残留 part；
  索引是 `metadata/index.json`（防抖 5 秒、原子写、丢失时按目录重建），不用数据库。
- **内存**：解码图仍归 Flutter `ImageCache`（规范 §4.1 的分工）；本包只登记
  key→分类，用于按分类驱逐，并把解码预算（默认 128 MB）交给 `ImageCache`；
  单张解码超过 20 MB 的图画完即驱逐，不占预算。
- **过期**：`staleWhileRevalidate`（先显示旧图，后台刷新，静态图原地换新，多帧图换
  codec 重播）/ `refreshBeforeDisplay`（先刷新，失败按 `fallbackToStale` 回退）/
  `cacheOnly`（绝不联网）。有 ETag/Last-Modified 时发条件请求，304 只延长有效期。
- **去重**：`key → Future` 一张表，完成或失败都摘除；后台刷新另一张表。
- **淘汰**：超过 maxStale → 已过期（低优先级、久未访问优先）→ 未过期 → permanent；
  清到上限的 90%。触发点：启动轻量检查（只看索引）、写入后超限、用户手动、
  启动 20 秒后主窗口做一次完整对账（含孤立文件）。
- **预置分类**：规范 11 类 + 实际调用点需要的 4 类（`chat_emote`、`album_cover`、
  `channel_logo`、`wallpaper`）+ 1 个兜底 `general`（调用方没声明分类时用，7 天）。

## 3. 与方案的偏离（都有理由）

1. `ImageCacheConfig` / `MemoryCacheConfig` / `CacheStatistics` 放在 `models/`，不放
   `image/`、`memory/`、`management/`：否则 `image → management → image` 成环。
2. 新增 `general` 兜底分类（方案是 15 类，这里 16 类）：64 处调用全部挂上了具体分类，
   但以后的新调用点不该静默落到「封面 6 小时」。
3. 多帧图的 SWR 不再自绘帧时钟：静态图用自定义 completer 原地换新，多帧图交给
   Flutter 的 `MultiFrameImageStreamCompleter` 转发，换新时重建动画。自绘帧表在
   completer 被释放时没有 dispose 钩子，会漏 `ui.Image`。
4. `ResizeImage`/`DsCoverImage` 会断言内层 provider 不得传 `getTargetSize`：因此只在
   调用方显式给了解码框时自己解码，否则把回调原样交给外层包装。
   `player_surface.dart` 那处 `ResizeImage(cachedImage(...))` 改成直接传 `width`。
5. 旧 `installWindowImageCache`（房间窗口独立缓存）删除：multiview 单引擎后全仓零调用者。
6. API 内存缓存的第一个消费方是分区目录（`areas_controller`，30 分钟，显式刷新绕过）。

## 4. App 接入点

| 位置 | 变化 |
|---|---|
| `infrastructure/storage/app_paths.dart` | `imageCache`/`covers` → `liveCache = <cacheRoot>/live_cache`；`recordingCovers` 移到 `<cacheRoot>/recording_covers` |
| `app/bootstrap/cache_migration.dart`（新） | 一次性搬迁：录像帧移走，旧 `images/` 与临时目录里的旧缓存删除；失败只记日志 |
| `app/bootstrap/app_bootstrap.dart` | 不再 `installImageCacheRoot`/`prepareImageCache`，改为跑迁移 |
| `app/bootstrap/pure_live_app.dart` | 安装 manager、读一次配置同步 provider、异步 initialize；主窗口 20 秒后对账 |
| `app/providers/cache/`（新） | `liveCacheManagerProvider`、`liveCacheSettingsProvider`、`liveCacheConfigSyncProvider`、`cacheStatisticsProvider`、`LiveCacheSettings`、分类分组 |
| `shared/images/app_image_cache.dart` | 只剩 manager 持有者与 `cachedImage(url, {policy, width, height, cacheKey, version, accountScope, headers})` |
| 43 个文件 / 63 处调用 | 全部挂上分类策略（封面/头像/用户头像/表情/专辑/台标/壁纸/预览/分区/平台图标/背景） |
| `shared/platforms/platform_display.dart` | 远程平台图标从裸 `NetworkImage` 改走缓存（`platform_icon`，30 天） |
| `modules/hongguo/controller/hongguo_covers.dart` | 源 HEIC 与转出 PNG 都进 `live_cache`；`HongguoCoverImage` 支持解码框 |
| `app/providers/browse/thumbnail_refresh_provider.dart` | 「刷新缩略图」只失效 `live_room_cover` 并驱逐其解码副本，不再清空全部 |
| `modules/live/areas/controllers/areas_controller.dart` | 分区目录接 API 内存缓存（30 分钟） |
| `apps/pure_live/pubspec.yaml` | 去掉 `cached_network_image`、`flutter_cache_manager`、`file`（连带 sqflite 一系传递依赖） |

## 5. 设置（数据与缓存页）

四段：缓存占用 / 图片缓存 / 清理 / 缓存目录。

| 键 | 默认 | 控件 |
|---|---|---|
| `cache.images.enabled`（新） | 开 | 开关 |
| `cache.maxMB`（沿用，已在备份清单） | 1024 | 下拉 200/500/1024/2048/4096（MB 或 GB 显示） |
| `cache.images.freshness`（新） | balanced | 下拉 更新优先 ×0.5 / 均衡 ×1 / 省流量 ×2 |
| `cache.images.autoClean`（新） | 开 | 开关 |

- 旧值迁移：0/未设 → 1024，100 → 200，其余归最近档位（规范要求容量必须有上限）。
- 占用段显示：已用/上限 + 进度条、文件数、命中率、接口内存缓存、最后清理时间、
  按类型查看（默认折叠，8 个分组）。
- 清理段：清理过期缓存、刷新缩略图、清理图片缓存、清理全部缓存（后两个二次确认，
  文案说明不动下载/录制/收藏），完成 toast 报释放量或「N 个文件正在使用」。
- 状态：统计加载中显示占位；读取失败行内报错 + 重试；磁盘层不可用给警示行；
  清理中按钮禁用；缓存为空时清理按钮禁用。
- 登记：`kBackedUpPrefs`（3 个新键）、`kSettingsProviders`（`liveCacheSettingsProvider`）、
  设置搜索目录（新增 11 条命中，IA 门禁 415 hits 通过）。

## 6. 验证

- `packages/live_cache`：`flutter test` 25 通过（内存/磁盘/网络三种命中、过期与 SWR、
  304 续期、刷新失败保留旧图、cacheOnly 不联网、并发去重、版本与稳定 Key、损坏重取、
  超限与非图片拒写、索引丢失重建、part 清理、清理不出根目录、优先级淘汰、
  派生文件存取、分类清理与失效、命中率除零、解码预算）。
- `flutter analyze packages/live_cache apps/pure_live/lib`：No issues found。
- `dart format --line-length 120`：包 29 文件 0 changed；App 侧只格式化本轮改过的文件。
- `apps/pure_live` `flutter test`：347 通过 / 3 失败，三处与本改动无关且改动前就红
  （`xiaohongshu_guest_test` 访客代理、`recording_schedule_test` 录制排期、
  `music_pages_providers_test` 缺 `storagePathsProvider` override）——都属并行 lane 的文件。
- 门禁：`validate_packages` 通过（19 条目）、`check_architecture` 通过、
  `check_settings_ia` 通过（81 sections / 415 hits）、`check_responsive` 通过、
  `audit_settings_disposition` exit 0；`check_prefs_manifest` 仍红 10 条，全部是别人的键
  （`browse.phoneColumns`、`recorder.autoStartOnBoot`、`recorder.pollingEnabled`、
  `search.target`、`vod.app.*`、`vod.playback.apiType` 与两条 invalidation），
  缓存的 4 个键无一条在内。

## 7. 回归修复：封面与头像全都不显示（2026-11-06 当天）

**现象**：接入后直播间封面与主播头像一律画不出来（只剩占位）。

**根因**：`_CacheImageCompleter.isClosed` 写成 `_closed || !hasListeners`，而
`ImageProvider.loadImage` 是在 widget 挂上监听器**之前**被调用的（`ImageCache.putIfAbsent`
→ `loadImage` → 之后才 `stream.setCompleter` 转交监听器）。于是异步取到字节回来时
`hasListeners` 还是 false，首帧被当成「流已关闭」直接丢掉，`setImage` 从未执行。
所有走 `LiveCacheImage` 的图都中招，与分类、策略、网络无关。

**修法**：按框架自己的 `OneFrameImageStreamCompleter` 语义——出帧不等监听器
（加载期间 `ImageCache` 持有 keep-alive，不会先释放）；`hasListeners` 只用来决定
多帧动画要不要挂着转发监听器（没人看就摘下，动画暂停而不是空转）。另外给
`emitStatic` 兜了一层：SWR 后台刷新若真的晚于流释放，框架会从 assert 抛
`StateError`，此时把这张没人等的图 dispose 掉，不冒泡。

**守卫**：`packages/live_cache/test/live_cache_test.dart` 的 `image provider` 组新增
4 条，直接驱动 `ImageStream`（`_firstFrame` 帮手）断言监听器真拿到首帧——裸 provider、
`ResizeImage` 包装、带解码框、二次解析走磁盘。包测试 25 → **29 全绿**。

**教训**：widget 测试的 fake clock 不驱动真实文件 I/O，`testWidgets` 里 `pumpWidget`
之后图片永远加载不完；要验出帧就直接 `resolve` + `addListener` + 真实异步，别用
`pumpAndSettle` 猜。

## 8. 未验证 / 遗留

- 没有构建、没有起 app：封面命中与 SWR 原地换新的观感、设置页四段在窄窗/TV 的排布、
  清理 toast 与进度条的实际样子、切代理后图片是否真走新路由，都归用户真机。
- Android / iOS / macOS / Linux / TV / Windows 便携模式没有实机；便携模式的缓存目录由
  `live_platform_path_provider` 的既有解析决定，本轮没有单独验证。
- 账号作用域（`accountScope`）已实现但没有消费方：当前没有「同 URL 不同账号不同图」的
  调用点，等出现私有图再接。
- 元数据丢失后的重建走的是「按目录扫描」，会丢掉 ETag/Last-Modified 与真实创建时间
  （用 mtime + 分类 TTL 推），这是规范允许的降级。
