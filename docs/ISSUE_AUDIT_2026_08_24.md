# 上游 Issue 审计（2026-08-24）

审计范围：`liuchuancong/pure_live` 最近 1–2 天新增或仍开放的问题，以及本轮已合并的多画面 PR #781。

## 结论摘要

| Issue | 级别 | 复核结论 | v2.9.4/v2.9.5 处理 |
|---|---|---|---|
| [#778 录制目录清理误删](https://github.com/liuchuancong/pure_live/issues/778) | 严重 | 可由源码直接确认；自定义目录被当作录制根目录递归删除 | 完整修复并增加隔离目录、所有权标记和误删回归 |
| [#779 动态应用图标](https://github.com/liuchuancong/pure_live/issues/779) | 增强 | 涉及 Android/iOS/TV 多套图标、Banner、启动图和平台审核配置 | 记录为独立资源工程，避免在稳定修复版本中只覆盖部分入口 |
| [#780 Linux 斗鱼 QuickJS](https://github.com/liuchuancong/pure_live/issues/780) | 高 | 最新上游已把斗鱼/抖音签名迁移为纯 Dart，平台原生 JS 依赖已退出播放链路 | 合并迁移，修复斗鱼缓存时间单位与并发刷新，增加描述符和签名回归 |
| [#782 快手多数房间无法播放](https://github.com/liuchuancong/pure_live/issues/782) | 高 | 实际响应确认直播/回放数据形状不同；2026-08-24 最新跟进又确认旧 Cookie 触发平台风控，刷新后恢复 | 同时解析直播/录播结构、合并 CDN 线路并支持匹配卡片录播回退；风控场景需更新 Cookie |
| [#783 低透明度弹幕描边发糊](https://github.com/liuchuancong/pure_live/issues/783) | 中 | 原生描边段落又被四个半像素偏移重复绘制，亮色画面下半透明像素叠加成模糊粗边 | 描边恢复单次原生绘制；轮廓透明度使用连续伽马曲线保持低透明度对比度，0 仍保持完全透明 |
| [#784 标签无法切回全部、搜索滚动错位](https://github.com/liuchuancong/pure_live/issues/784) | 高 | 标签选择值只在懒加载 itemBuilder 中读取；搜索栏即使添加物理边界，仍把无对应页面的 TabController 选择动画与内部滚动位置耦合 | 关注标签在响应阶段捕获选择值；搜索平台栏改为独立有界选择器，控制器保留稳定平台快照，并增加真实拖动首尾回归 |
| [#785 Douyu media request failure](https://github.com/liuchuancong/pure_live/issues/785) | High | Signing and CDN bytes are valid; the full playback request path and adapter error handling were incomplete | Add consistent player headers, session DID, forced-refresh retry, defensive response parsing, and a real FLV probe |

## #778：录制目录与自动清理

### 根因

1. `recordSavePath` 直接成为 `CacheService.getRecordDir()` 返回值。
2. “清空缓存”递归枚举并删除该目录全部文件；用户选择“下载”或磁盘根目录时，作用域扩大到用户文件。
3. 自动限额只扫描录制根目录第一层文件，而真实录制文件按平台/主播/日期/时间分层保存。
4. 当总大小超过阈值但根层没有文件时，`enforceLimit()` 会反复计算相同大小并持续调用无效果的删除，形成高 CPU 循环。
5. 未使用的系统临时目录方法还错误取得临时目录的父目录并按名称前缀删除，属于同类扩大作用域风险。

### 修复

- 默认 `RECORDS` 目录继续作为应用专用根；自定义位置只作为父目录，实际写入 `<所选位置>/PureLiveRecords`。
- 专用目录创建 `.pure_live_recording_root`，用户重新选择已有专用目录时通过标记识别，避免重复嵌套。
- 清理只枚举专用目录第一层并保留标记；列表和统计均关闭符号链接跟随。
- 容量治理使用一次递归文件快照，按修改时间从旧到新删除；文件消失或锁定时继续有限快照，空目录直接结束。
- 删除未使用且作用域错误的系统临时目录清理方法。
- 自动化覆盖公共父目录无关文件、未标记同名目录、递归旧文件、空目录和容量上限。

## #780：平台签名与 Linux

- 上游 `7410eb9f` 已将斗鱼、抖音签名迁移为纯 Dart，并删除 `dart_quickjs`、旧脚本和桌面插件注册；Linux 构建不再依赖 QuickJS 链接。
- 复核迁移代码发现斗鱼 `expire_at` 是 Unix 秒，而缓存判断使用了毫秒，导致每次清晰度/线路请求都重新获取加密描述符；现统一用秒并提前 30 秒刷新。
- 同一时间的多次取流共用一个在途刷新 Future；描述符缺字段、过期或迭代次数异常时快速失败，签名表单使用标准查询编码。
- 抖音签名构造复制调用方参数并合并基础 URL 查询，消除重复请求对共享参数 Map 的污染；令牌生成改为单个安全随机源。
- 自动化覆盖缓存时间单位、签名确定性、表单字符编码、迭代上限和抖音参数不可变性；公开接口探测校验斗鱼描述符字段与过期时间。

## #785: Douyu H5 metadata and media request

- The report independently confirmed that signing succeeds and the CDN returns valid FLV bytes. The issue exposed two untested boundaries: H5 response acquisition and the headers used when the player opens the final URL.
- v2.9.5 gives the signing and H5 requests one session DID, matching cookies, Origin, Referer and User-Agent. Encryption descriptors are capped at five minutes and one failed request triggers a forced refresh plus one bounded retry.
- API errors and partial data are validated before optional quality/CDN fields are read. CDN codes and URLs are deduplicated, escaped query strings are decoded, and useful adapter exceptions replace unchecked map failures.
- `PlayerController.resolvePlaybackHeaders` now supplies Douyu Referer, Origin, User-Agent and DID cookies to media_kit, video_player, fijkplayer and the audio-only loader through their existing shared header path.
- The public probe selects a currently live room, signs the H5 request, validates metadata, opens the selected CDN URL with player-equivalent headers, and verifies the FLV signature. This passed from the release network together with all other platform probes.

## #782：快手直播与回放

2026-08-24 直接采样 `live_api/home/list` 和房间页 `window.__INITIAL_STATE__` 得到以下差异：

- 当前直播房间页：`playUrls` 为包含 `h264`/`hevc` 的对象。
- 推荐/回放卡片：`playUrls` 为直接 `adaptationSet` 描述符列表。
- 推荐卡片可能带有效签名播放地址，但对应房间页明确返回 `isLiving=false`；旧逻辑只按直播房间页路径取 `data["h264"]`，也会把所有列表卡片预先标为直播。

v2.9.4 使用一个纯解析器处理两种结构：优先 AVC、缺失时回退 HEVC；相同名称/等级的多 CDN URL 合并为线路并去重。进入房间时先采用房间页权威直播状态，明确下播且当前匹配卡片仍有有效播放描述符时标记为录播。分类列表也携带其播放描述符，房间错误回退只使用“平台 + 房间号”一致的卡片。

Issue 在 2026-08-24 14:24（UTC+8）的最新反馈中确认：三台设备使用旧 Cookie 时均失败，重新获取 Cookie 后播放恢复。因此解析器问题与平台风控被区分处理；前者由确定性解析测试和公开探测覆盖，后者以更新 Cookie 恢复平台会话。

## #783：低透明度弹幕描边

- `TextLayoutSpan` 收到的 `strokeParagraph` 已经由 Flutter Paragraph/Skia 生成完整描边路径，旧实现又在四个半像素方向分别绘制一次；同一边缘最多叠加四层半透明像素，因此越接近亮色背景越容易出现发灰、变粗和糊成一片。
- v2.9.4 改为先单次绘制原生描边、再绘制文字填充，减少 75% 的重复描边绘制工作。
- 轮廓 Alpha 使用 `sqrt(opacity)` 连续映射：低透明度时轮廓比填充保留更多对比度，透明度为 0 时轮廓仍为 0，透明度变化保持单调且没有突变阈值。
- 自动化覆盖越界钳制、0/25%/50%/100% 透明度映射与缓存身份；具体亮色视频观感仍保留为设备显示验收层。

## #784：关注标签与搜索滚动

- `ListView.builder` 的 `itemBuilder` 是懒执行回调。旧代码在回调中读取 `selectedTagId.value`，外层 `Obx` 只稳定观察了标签列表，导致数据已经筛到自定义标签而选中态仍停留在“全部”；再次点击“全部”时 `ChoiceChip` 还会回传取消选择，旧回调直接忽略。
- 新实现把标签列表和当前标签 ID 都在 `Obx` 同步阶段读取，再将不可变快照交给懒列表；所有标签点击统一提交目标 ID，由控制器负责同值去重。Widget 回归完整覆盖“全部 → 自定义 → 全部”以及两个按钮的实时选择态。
- 搜索结果在 Android/iOS 明确使用 `BouncingScrollPhysics + AlwaysScrollableScrollPhysics`，短列表与长列表都能产生受控回弹；桌面继续沿用鼠标滚轮优化策略。
- v2.9.4 首次补上的 `TabAlignment.start + ClampingScrollPhysics` 只约束了物理模型，`TabBar` 自身仍会按选择状态自动调整内部位置，而搜索页没有对应的 `TabBarView`。v2.9.5 将其替换为专用水平选择器：滚动控制器、选中索引和首尾边界均由搜索模块直接持有，屏幕外平台仍可访问，但反复大幅拖动后偏移始终钳制在 `minScrollExtent/maxScrollExtent`。
- 搜索页只建立一次平台/适配器快照，避免重复实例化导致标签、索引、Twitch 游标和网页入口使用不同列表；全平台搜索按完成顺序渐进显示，每个平台最多占用 12 秒 UI 等待时间。
- YY 纳入原生搜索；网页结果解析补齐 Twitch、SOOP、YY，并返回“平台 + 房间号”复合身份。搜索页、分类页和伪装域名不触发直播间弹窗，取消同一目标后也不再被加载开始/历史更新/加载完成事件连续弹出。

## 多画面 PR #781 复核

- 已随上游 `99ef708c` 合并，覆盖独立播放器、弹幕会话、清晰度/线路、音量和聚焦布局。
- 补强两个异常边界：`pause()` 抛错仍执行 `disposePlayer()`；快速音频焦点选择通过最新值串行队列收敛。
- 解码器资源上限按设备分类：移动端 4 路，桌面端 9 路；保留小画面自动降质。

返回 [文档索引](README.md)。
