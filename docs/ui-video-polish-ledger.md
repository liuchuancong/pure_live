# 视频类模块 UI 打磨台账（B 站视频 / IPTV / 音乐 / 红果短剧）

> 本文件是「视频类模块 UI 打磨」定时车道的唯一续跑依据。车道每轮先读本文件，
> 按轮转指针取下一个模块，落一个明确可验证的版式或功能修正，然后回填本文件的
> 「轮转指针」和「运行记录」两节，并连同本轮代码一起提交推送。
> 台账写法参照 `docs/sync-progress.md`（定时任务按表续跑）。

## 车道规格

- 仓库：`D:\flutter\pure_live`，分支 `v2`，远程 `origin`（liuchuancong/pure_live）。
- 节奏：每 20 分钟一轮，一轮只推进一个模块的一个问题，每轮最多一个提交。
- 轮转顺序：`vod` → `iptv` → `music` → `hongguo` → 回到 `vod`。
- 验收门：`dart analyze apps/pure_live/lib` 0 issues（改到 packages 时加跑对应包）。
  不构建、不起 app、不截图、不建临时测试；运行期观感由用户自测。
- 提交：`git add -- <本轮路径>` + `git commit -- <本轮路径>` + `git push origin v2`，
  禁止 `add -A` / `stash` / `reset` / `checkout` / `clean` / `--force`。

## 参考版式基线（爱奇艺 / 腾讯视频 / 电视直播类）

下面是已知的通用版式，**每轮允许用 1–2 次联网检索刷新**，不要长期只照抄本节：

1. 首页：顶部横向频道导航 → 大尺寸 Banner 头图（海报 + 标题 + 简介 + 播放/收藏按钮）→
   按主题分「行」的横向滚动片单，行头带标题与「更多」；片单以竖版海报卡为主。
2. 详情页：标题区（大幅背景 + 海报 + 元信息 + 更新提示 + 播放/追剧按钮）→ 选集条
   （数字格或剧照缩略格）→ 相似推荐网格 → 评论区。播放与选集是主任务，其余为次级。
3. 播放器：悬浮控制条（进度、清晰度、倍速、弹幕、选集侧栏、小窗、投屏），
   竖屏短视频类走右侧动作列（收藏/点赞/评论）+ 底部进度线。
4. 直播/电视类：经典三栏——左频道分组树、中频道列表（含「正在播出」与进度）、
   右播放器或节目单；窄屏折叠成「列表 + 全屏播放」两态。
5. 会员/我的：头像头图 + 会员卡 + 功能入口九宫格。

## 仓库既有规范（车道必须遵守，不得新造）

- 组件一律 desen_ui：先找 `DsCard`/`DsBadge`/`DsListRow`/`DsPanel`/`DsTable`/`DsSwitch`，
  缺件用 style 覆盖，不造新组件。
- 版式写死，每个元素一个显隐开关；不做画布设计器，不做打包预设（`room_card` 与红果海报卡
  就是这个范式：`features/settings/room/room_card_settings.dart`、
  `modules/hongguo/controller/hongguo_card_settings.dart`）。
- 设置页无页头标题与说明小字、同一项只留一个入口；长清单用页内分段（3–5 个短标签），
  不拆二级页；行内选择优先下拉（`SettingsChoiceRow`），连续值给 3–6 个预设档；
  多条件筛选只留头部入口、条件收进 `DsPanel`。
- 「卡片预览」= 设置里的该卡预览页（设置本体即预览，舞台可配色）。
- 颜色设置必须有取色弹窗（HSV 面板/色相条/Hex/实时预览），预设色只作快捷项。
- 窄屏只留主 tabbar，排版/切平台/排序/页内搜索进右上角 more；「右上角」指页头最右端
  （`SettingsPageActionScope` → `DsPaneHeader.actions`）。
- 禁止改动直播模块（`modules/live`）的菜单与设置导航；共享设置区只留公共子集。
- 卡片量规来自 `shared/grids/card_grid.dart`（`kBrowseCardMaxWidth`/`kBrowseCardMinWidth`
  与房间卡尺寸），房卡高度按 `mainAxisExtent` 计算，封面固定 16:9；改尺寸先对齐量规。
- 改到 l10n 就跑 `cd apps/pure_live && dart run slang`；只 `dart format --line-length 120`
  本轮真正编辑的路径，格式器重排到的无关旧行逐 hunk 还原。

## 各模块现状与已知差距（证据）

### vod —— `apps/pure_live/lib/modules/vod/`

B 站视频站（`vod.dart` 自述 "The Bilibili station"）。页面：`pages/vod_page.dart`
（动态/推荐/热门）、`vod_video_page.dart`、`vod_pgc_page.dart`、`vod_search_page.dart`、
`vod_regions_page.dart`、`vod_personal_page.dart`、`vod_live_page.dart`、`vod_downloads_page.dart`；
卡片 `widgets/vod_widgets.dart` 的 `VodVideoCard`（信息区 `kVodCardInfoExtent = 72`）；
网格走 `PagedCardGrid`；数据来自 `packages/live_vod` 的 `BilibiliVodClient`。
差距：`pages/vod_settings_pane.dart` 的「界面设置」只有一个开关（详情是否显示在画面下方），
没有视频卡的逐元素显隐设置；首页没有头图/分行的片单编排；搜索页的两个筛选器常驻在页头，
尚未按「多条件收进 DsPanel」重排。
（已闭合：浏览类页面的工具栏。首页/分区/影视三页的头排现在与直播热门页同形——宽窗
`标签 + 版式切换 + 刷新`，窄窗只留标签行、刷新与版式收进右上角 more；见
`widgets/vod_toolbar.dart` 的 `VodFeedToolbar`。动态 tab 与影视 poster 墙没有第二种版式，
所以传 `showLayout: false`，不摆一个失效的开关。）

### iptv —— `apps/pure_live/lib/modules/iptv/`（领域层在 `packages/live_iptv`，无 UI）

页面：`pages/iptv_page.dart`、`iptv_play_page.dart`、`iptv_guide_page.dart`、`iptv_recent_page.dart`、
`iptv_settings_pane.dart`；视图：`views/iptv_panels.dart`、`iptv_sources_view.dart`、
`iptv_guide_panel.dart`、`iptv_import_dialog.dart`、`iptv_zapper.dart`；浏览设置
`controllers/iptv_browse_settings.dart`。现状是频道表格 + 来源资源表。
差距：没有电视类经典的「分组树 + 频道列表 + 播放器/节目单」三栏形态，窄屏折叠态未定义；
「正在播出」与进度、收藏、节目单的层级还需对照。

### music —— `apps/pure_live/lib/modules/music/`

页面：`music_page.dart` 根 + `pages/music_player_page.dart`、`music_eq_center_page.dart`、
`music_eq_editor.dart`、`music_album_page.dart`、`music_artist_page.dart`、`music_settings_pane.dart`
（总览/音源/下载/歌词/桌面歌词/EQ/快捷键/同步 8 个 Pane）；歌单卡
`pages/music_playlist_card.dart`（`MusicPlaylistCard`/`MusicPlaylistGrid`，房间卡设计平移，
`kMusicPlaylistCardMaxWidth = 200`、`kMusicPlaylistInfoHeight = 48`）。
差距：`controller/music_ui_settings.dart` 只管播放器装饰（模糊背景、频谱、播放器模式），
歌单卡没有逐元素显隐设置；推荐/榜单/歌单页的头图与分行编排尚未按视频站那套对照。

### hongguo —— `apps/pure_live/lib/modules/hongguo/`

页面：`pages/hongguo_page.dart`（两处 `PagedCardGrid`）、`hongguo_player_page.dart`、
`hongguo_series_page.dart`、`hongguo_downloads_page.dart`、`hongguo_settings_pane.dart`；
组件在 `widgets/`（海报卡 `hongguo_widgets.dart`、剧集架、评论面板、弹幕层）；
`official/` 是官网对接。**卡片显隐已达标**（`controller/hongguo_card_settings.dart` 的 7 个元素：
rank/coverTags/episodes/today/score/hot/meta，在 `hongguo_settings_pane.dart` 的「海报卡内容」逐项开关）。
差距：剧集选集条与榜单富信息行的版式；竖屏播放器浮层（右侧动作列、底部选集条与进度线）。
另：本模块每轮 UI 之前仍带旧车道的只读接口巡检职责（榜单/详情/搜索/联想，见运行记录）。

## 轮转指针

| 字段 | 值 |
|---|---|
| 下一轮模块 | iptv |
| 上一次提交 | vod · 视频站浏览页工具栏与成熟页同形（本轮 HEAD 提交） |
| 连续无改动轮数 | 0 |
| 暂停条件 | 连续 3 轮无改动即停手并在回复里说明需要用户裁决 |

## 运行记录

| 日期时间 | 模块 | 改了什么 | 参考依据 | 验证 | 提交 |
|---|---|---|---|---|---|
| 2026-11-02 01:56 | vod | 首页/分区/影视三个浏览页的头排各自为政：首页只有一个刷新按钮，分区页连刷新都没有，而它们读的正是全局 `browseLayoutProvider`——视频站里没有任何入口能切卡片/列表。新增 `widgets/vod_toolbar.dart` 的 `VodFeedToolbar`，照直播热门页那套形态收敛：宽窗 `标签行 + LayoutToggle + 刷新`，窄窗只留标签行、刷新与版式收进右上角 more（`DsMenuAnchor`），行高统一到 44。动态 tab 与影视 poster 墙没有第二种版式 → `showLayout: false`，不留失效开关。 | 爱奇艺客户端首页有「海报模式/列表模式」两种首页形态、默认海报模式，且频道页是「Banner + 分类合集 + 内容宫格 + 右上角筛选」的模块化版式（jianshu 爱奇艺APP产品体验报告、zhidao 爱奇艺怎么切换列表模式）；腾讯视频首页为「顶部操作区 + Banner + 大卡片/双瀑布流」（new.qq.com 5500字拆解腾讯视频app细节设计）。即：视图形态是页面级入口，页面动作落在页头右上角。 | `dart analyze apps/pure_live/lib` 0 issues；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,vod)`） |
