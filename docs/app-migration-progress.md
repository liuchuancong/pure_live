# App 功能迁移台账（E:\study\pure_live → apps/pure_live）

> 自动迁移任务的工作清单。规则见文末；每完成一格：勾选 + 填提交号。
> 模型一律用本仓 `packages/live_sites` 的契约（LiveDiscoveryProvider/LiveAreaProvider/
> LiveSearchProvider/…），页面落在 `features/<域>/`，平台差异只进 `platforms/<形态>/`。

## 已完成

- [x] 组合根/日志/路径（含 debug 隔离）/存储/站点图 — bafe65c5d 等
- [x] 平台壳（mobile/tablet/desktop/tv）+ 桌面窗口/托盘/关闭流 + 单实例握手
- [x] 热门页（每平台推荐 tab）— 83367b0ae 之前
- [x] 首页菜单 + 分区域（分区目录/分区房间）— d120032da
- [x] 搜索（房间/主播/分区三形态）— 9efda024a
- [x] 设置索引 + 外观页 — 83367b0ae

## 待迁移（一个一个来，按序取）

- [x] **房间页 MVP + 播放器接线（✅ 用户已拍板 2026-10-16：播放器用 media_core）** — 9aba9a3fe
      接缝 = packages/live_playback/lib/src/engine/playback_engine.dart（PlaybackEngine：
      events/open(LivePlayLine)/pause/resume/stop/dispose + PlaybackEngineFactory；
      失败以 EngineStopped 事件上报，open 不许抛）。
      实现 = app 侧绑 media_core 的 PlayerKernel（media_core 已是 git 依赖在依赖图，
      源码 C:\Users\XA-158\projects\flutter\media_core）。
      落点 = lib/app/engine/playback_engine.dart（目录架构文档 §app/engine）；
      房间页 = lib/features/room/，路由 /room/:siteId/:roomId，参考 E 盘
      features/live_play 的布局分层但控件用 live_uikit。
- [x] 分区房间页打磨：排序/在线人数徽标/分页页码 — 5d5160017（large 桌面 PagedController 数字翻页条、small/medium 无限滚动、人气/默认排序切换）
- [x] 关于页（package_info_plus + pub_semver + markdown 更新日志）— 863652a42（检查更新走 GitHub releases API via LiveHttp；MarkdownText 轻渲染器；版本历史 bottom sheet；许可页；项目主页 url_launcher）
- [x] 工具箱页（链接解析：LiveLinkResolver capability → 跳房间/取流）— ebcf5567f（逐站顺序解析→规范 URL 末段为 roomId→房间页；剪贴板读取；跨站 fan-out 与取流地址展示留待后续）
- [ ] 关注域（live_library LibraryStore seam + 分组/标签 UI）
- [ ] 历史域（live_library 历史记录 + 清除）
- [ ] IPTV 域（live_iptv：源管理/分组/播放列表）
- [ ] 设置-弹幕屏蔽页（shield 关键词/用户/正则，存储 keyed 家族）
- [ ] 设置-字体管理页（font_manager，_restart_app 联动）
- [ ] 备份/恢复页（archive zip + file_picker/file_selector）
- [ ] 弹幕（live_interaction + live_websocket 加入依赖）
- [ ] 录制域（live_record_core 加入依赖）
- [ ] 多画面（mosaic_grid + 票据复用）

## 规则（每次运行必读）

1. `git -c http.version=HTTP/1.1 pull --rebase origin v2` 先行；工作区有别人的
   WIP（packages/live_sites 未跟踪目录）只绕开不清理。
2. 参考实现在 `E:\study\pure_livepps\pure_live\libeatures/<域>/`，行为照搬；
   数据一律走本仓 `packages/live_sites` 契约，页面不 import dio、不碰 box。
3. 文案 zh/en 双语进 slang（lib/l10n/strings/*.i18n.json → dart run slang），
   路由进 app/routing（路径常量在 route_paths.dart），provider 在 app_providers。
4. 每个功能：`dart format lib` → `flutter analyze` 零问题 → `flutter build windows
   --debug` → 冒烟（起 exe 8 秒存活）→ 一个独立 commit → 推送
   （`git -c http.version=HTTP/1.1 push origin v2`）。
5. 需要用户裁决的（如 per-platform 目录冲突、新依赖、media_core）——在台账标注
   "⛔待裁决 + 原因"，跳过取下一项，不要自行决定。
6. push 被拒：rebase 再推；绝不 force。
7. 开工前若发现 .git/index.lock 存在或纯 live_sites WIP 之外的未提交改动，说明
   上一轮/另一会话还在写：本轮直接结束，等下一轮。
