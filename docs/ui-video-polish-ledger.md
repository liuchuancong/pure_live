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
差距：没有电视类经典的「分组树 + 频道列表 + 播放器/节目单」三栏形态；窄屏折叠态已定义
（<600 频道行改为堆叠列表，见运行记录 2026-11-02 本轮），但**来源页那张表还是同一个缺陷**：
`views/iptv_sources_view.dart` 的 `DsTable` 仍是 `layout: DsTableLayout.auto()`，
六个列最小合计 240+100+90+150+104+92 = 776px，窄窗要么横向滚动、要么落到 kit 的 card 版式
（一行一「标签 值」且行高只有一个文字行，它的 `_SourceNameCell` 两行会被裁）。
下一个 iptv 轮次应当照本轮同样处理它。
另：分组是 `DsTabs` 横滚条（`_GroupTabs`），真实播放列表常有 50–150 个分组，条子长到不可用；
参考形态是第一列的分组树/列表，属于「三栏」那一块，改动较大，单列一轮。
「正在播出」与进度、收藏、节目单的层级还需对照。

### music —— `apps/pure_live/lib/modules/music/`

页面：`music_page.dart` 根 + `pages/music_player_page.dart`、`music_eq_center_page.dart`、
`music_eq_editor.dart`、`music_album_page.dart`、`music_artist_page.dart`、`music_settings_pane.dart`
（总览/音源/下载/歌词/桌面歌词/EQ/快捷键/同步 8 个 Pane）；歌单卡
`pages/music_playlist_card.dart`（`MusicPlaylistCard`/`MusicPlaylistGrid`，房间卡设计平移，
`kMusicPlaylistCardMaxWidth = 200`、`kMusicPlaylistInfoHeight = 48`）。
差距：`controller/music_ui_settings.dart` 只管播放器装饰（模糊背景、频谱、播放器模式），
歌单卡没有逐元素显隐设置；推荐页的头图（Banner 位）还没有对照。
（已闭合：精选/在线歌单浏览页的条件排。`pages/music_online_playlists_view.dart` 的
`MusicOnlinePlaylistBrowse` 原先把
排序 `DsTopNav` + 分类 `DsTopNav` + 标签 `Wrap` 三排常驻在网格上方，一个 plaza 的热门标签
常有 20–50 个，`Wrap` 会铺成 4–6 行、窄窗里网格被挤到看不见；现在收敛成
`44px 头排（标签/标题 + 打开歌单 + 筛选入口）+ 一行当前条件`，条件本体进
`MusicPlazaFilterPanel`（`DsPanel`，排序/分类/标签三段 `DsChip`）。同一处也顺手对齐了
歌单页 我的/在线 两个 tab 的头排几何（原先在线 tab 的 tab 行没有 `s20` 左右内边距、
也没有 44 高，切 tab 时整条工具栏会横移。）

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
| 下一轮模块 | hongguo（先做旧车道留下的只读接口巡检，再改 UI） |
| 上一次提交 | music · 精选/在线歌单把常驻的三排筛选条件收进头部入口 + `DsPanel`（本轮 HEAD 提交） |
| 连续无改动轮数 | 0 |
| 暂停条件 | 连续 3 轮无改动即停手并在回复里说明需要用户裁决 |

## 运行记录

| 日期时间 | 模块 | 改了什么 | 参考依据 | 验证 | 提交 |
|---|---|---|---|---|---|
| 2026-11-02 01:56 | vod | 首页/分区/影视三个浏览页的头排各自为政：首页只有一个刷新按钮，分区页连刷新都没有，而它们读的正是全局 `browseLayoutProvider`——视频站里没有任何入口能切卡片/列表。新增 `widgets/vod_toolbar.dart` 的 `VodFeedToolbar`，照直播热门页那套形态收敛：宽窗 `标签行 + LayoutToggle + 刷新`，窄窗只留标签行、刷新与版式收进右上角 more（`DsMenuAnchor`），行高统一到 44。动态 tab 与影视 poster 墙没有第二种版式 → `showLayout: false`，不留失效开关。 | 爱奇艺客户端首页有「海报模式/列表模式」两种首页形态、默认海报模式，且频道页是「Banner + 分类合集 + 内容宫格 + 右上角筛选」的模块化版式（jianshu 爱奇艺APP产品体验报告、zhidao 爱奇艺怎么切换列表模式）；腾讯视频首页为「顶部操作区 + Banner + 大卡片/双瀑布流」（new.qq.com 5500字拆解腾讯视频app细节设计）。即：视图形态是页面级入口，页面动作落在页头右上角。 | `dart analyze apps/pure_live/lib` 0 issues；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,vod)`） |
| 2026-11-02 02:20 | iptv | 频道浏览页只有一种形态：`_ChannelsTable` 那张 `DsTable` 用 `layout: DsTableLayout.auto()`，五个列的最小合计是 220+120+200+72+64 = 676px（加左右 padding 约 700）。窄窗（<600 的手机）拿到的结果是横向滚动 + 边缘渐隐，收藏心和播放动作被推到视口外，只能靠横滚找到；而 kit 在 <480 给的兜底是 card 版式，一行一个「标签 值」且行高只有一个文字行，本站的 `_ChannelNameCell`（台名+频道号）和 `_NowCell`（节目名+进度条）本来就是两行，会被裁成一行。本轮把窄态定义出来：<600 改为 `ListView.separated` + `DsListRow` 的堆叠行（leading 台标 / title 台名 / detail 频道号 / description 复用 `_NowCell` 的正在播出+进度 / trailing 心+播放），抄的是本模块「最近观看」页已经在用的行语言，分页沿用同一个 scroll controller；≥600 才是表，并且分组列只在 ≥960 的宽窗出现（分组已经由上面 `_GroupTabs` 命名并计数，这一列正是把表撑过中窗的那 120px），台名列最小 220→200，让 600–960 段的合计落到 200+200+72+64+24 ≈ 560px 不再横滚。表格布局改回默认的 `.rows()`，窄态由本模块自己定义，不再交给 kit 的标签堆。 | 电视直播类的主界面是「左侧导航栏 + 右侧内容区」，频道列表 + 节目单是核心模块，EPG 在列表/播放界面按上下键调出（csdn 电视直播软件全攻略 163708420、gitblog_00973 界面详解：中央播放窗口/频道列表区/底部功能栏）；成熟播放器把「正在播出 + 接下来」和节目进度条作为频道列表的行内信息（HDHomeRun：what's on now and what's on next guide data、program progress bar、channel logos；AnyTV IPTV Player：see what's playing now and what's coming next、channel favorites）；窄屏形态是「点屏唤起侧边频道列表 / 长按唤出下方功能栏」的单列叠行（9k9k、pczhi 电视直播TV版）。即：台标 + 台名 + 正在播出与进度是行的必备三要素，分组是导航维度而非每行的固定列。 | `dart analyze apps/pure_live/lib` 0 issues（`dart format --line-length 120` 本轮文件 0 改动）；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,iptv)`） |
| 2026-11-02 03:05 | music | 精选/在线歌单（`pages/music_online_playlists_view.dart` 的 `MusicOnlinePlaylistBrowse`，同一个 widget 同时是 精选 页和 歌单 页的在线 tab）把筛选条件常驻在内容上方：排序一行 `DsTopNav` + 分类一行 `DsTopNav` + 标签一整片 `Wrap`。一个 plaza 的热门标签/分组标签常有 20–50 个，`Wrap` 铺成 4–6 行，窄窗里歌单网格被推到看不见，宽窗也要先滚过一整片 chips 才看到内容，而这三个常驻控件在同一时刻只有 3 个值是有效的（当前排序、当前分类、当前标签）。本轮按仓库既有的「条件收进面板」形态（红果 找剧 `_FindView` + `_FindFilterPanel`）收敛：头排统一到 `SizedBox(height: 44)` + `s20` 左右内边距，`Expanded(标签行/标题) + 打开歌单 + 筛选`（筛选是图标入口，条件还没加载出来时 disabled），条件本体进新的 `MusicPlazaFilterPanel`（`DsPanel`，排序/分类/标签三段 `DsChip`，选中即回调进 browse 的 state 并 `_page = 1`），页头下方留一行 muted 摘要写当前 `排序 · 分类 · 标签`。顺手补掉一处对齐断裂：在线 tab 的 tab 行原先既没有 `s20` 左右内边距、也没有 44 高，而 我的 tab 的工具栏两者都有，切 tab 时整条工具栏会横移。新增 l10n 5 个 key（`plazaFilterTitle/Sorts/Groups/Tags/Done`，en + zh-CN）并跑 `dart run slang`；生成的 `.g.dart` 带进了 slang 自身的跨 namespace 重排（`room`/`settings` 的 `_ => null, } ?? switch (path)` 边界移动），不是本轮手改的内容。 | 爱奇艺首页/频道页是「顶部导航 + 筛选 + 轮播图」的头排 + 自上而下的单行模块（每行独立横滑），筛选是头部入口而非常驻条件行（woshipm 爱奇艺APP2023体验优化分析 1178、人人都是产品经理 爱奇艺产品分析报告 5677048）；腾讯视频首页顶栏为「搜索框 + 筛选按钮」，分类/筛选在二级页展示、首屏不放条件墙，内容行「左图右文单行排列、标题+副标题、右侧静态信息」（zcool 流媒体平台首页设计系列——腾讯视频 1180、chinutech 视频平台的会员运营细节 1179）。即：多条件收进一个入口，页面高度留给内容。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 本轮文件 0 追加改动；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,music)`） |
