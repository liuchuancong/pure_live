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
（已闭合：影视海报卡的高度量规。`VodSeasonCard` 原先是「3:4 海报 + 两行片名 + 一行更新状态」
的固定内容高度，而三处片单给它的是 `aspectRatio: 0.62` 的比例格——格子里给文字区留的是
`0.28 × 列宽`，列宽低于 ~270px 时片名与更新状态被挤出卡片（叠到下一行上），列宽 300–340 时
又空出一条 20–60px 的死白。现在文字区改成固定 `kVodSeasonCardInfoExtent = 60`（两行片名），
海报用 `Expanded` 吃掉剩余高度，更新状态（`subtitle`）挪上海报右上角、评分仍在右下角；
`0.62` 折成 `kVodSeasonTileAspect` 由三处片单共用。）

### iptv —— `apps/pure_live/lib/modules/iptv/`（领域层在 `packages/live_iptv`，无 UI）

页面：`pages/iptv_page.dart`、`iptv_play_page.dart`、`iptv_guide_page.dart`、`iptv_recent_page.dart`、
`iptv_settings_pane.dart`；视图：`views/iptv_panels.dart`、`iptv_sources_view.dart`、
`iptv_guide_panel.dart`、`iptv_import_dialog.dart`、`iptv_zapper.dart`；浏览设置
`controllers/iptv_browse_settings.dart`。现状是频道表格 + 来源资源表。
差距：没有电视类经典的「分组树 + 频道列表 + 播放器/节目单」三栏形态；窄屏折叠态已定义两处
（<600 频道行改为堆叠列表、来源表 <760 改堆叠行，见运行记录 2026-11-02 两轮）。
另：分组是 `DsTabs` 横滚条（`_GroupTabs`），真实播放列表常有 50–150 个分组，条子长到不可用；
参考形态是第一列的分组树/列表，属于「三栏」那一块，改动较大，单列一轮。
「正在播出」与进度、收藏、节目单的层级还需对照。
（已闭合：来源表在窄窗与中窗的形态。`views/iptv_sources_view.dart` 的 `_SourcesTable` 原先
`layout: DsTableLayout.auto()`，六列最小合计 240+100+90+150+104+92 = 776px，窄窗横滚、
中窗（720–960）也放不下；现在 <760 由本模块自己定义堆叠行（种类图标 + 名称行 + 一行
`类型 · 频道数 · 更新时间` + 地址行 + 自动更新开关与同步/删除），≥760 才是表，且「类型」列
只在 ≥960 出现、中窗把它读进地址行前缀（`M3U8 · https://…`），五种字段的合计落到
200+76+120+96+84+32 = 608px。表与堆叠行共用同一个 `_SourcesActions`，两种形态的字段与动作
不会各说各话。）

### music —— `apps/pure_live/lib/modules/music/`

页面：`music_page.dart` 根 + `pages/music_player_page.dart`、`music_eq_center_page.dart`、
`music_eq_editor.dart`、`music_album_page.dart`、`music_artist_page.dart`、`music_settings_pane.dart`
（总览/音源/下载/歌词/桌面歌词/EQ/快捷键/同步 8 个 Pane）；歌单卡
`pages/music_playlist_card.dart`（`MusicPlaylistCard`/`MusicPlaylistGrid`，房间卡设计平移，
`kMusicPlaylistCardMaxWidth = 200`、`kMusicPlaylistInfoHeight = 48`）。
差距：`controller/music_ui_settings.dart` 只管播放器装饰（模糊背景、频谱、播放器模式），歌单卡没有逐元素显隐设置。
另有一处只记录未改（下一轮 music 的现成目标）：`pages/music_eq_center_page.dart:222` 的 `_Hero`
背景是 `DsImage(image: …, semanticLabel: …)`，既没有 `width`/`height` 也没有 `aspectRatio`，而
desen_ui 0.3.2 的 `DsImage` 构造断言是 `(width != null && height != null) != (aspectRatio != null)`
——三个都空时断言为 false，debug 构建一进 EQ 中心（有封面的歌在播）就抛；release 关掉断言才看不出来。
本模块其余 8 处 `DsImage` 都留了框，只有这一处漏。本轮新写的头图背景走播放页那套
`ClipRect + ImageFiltered + 原生 Image(fit: cover)`，不碰这个坑。
（已闭合：推荐页的头图。`pages/music_recommend_view.dart` 原先把六类内容（歌单横排/继续播放/
最近专辑/最近歌手/热搜词/榜单）排成同一种「行标题 + 内容」的等高行，整页没有任何一个第一视觉
焦点，而视频站首页都是「一张大 Banner 头图 → 再往下才是分行片单」；现在从同一个广场第一页里取
最热的那张歌单铺成头图 `MusicRecommendHero`（封面整块在左 + 名字 heading + `作者 · N 首` caption
+ 广场标签作眉标 + `全部播放`/`打开歌单` 两个写明文字的动词），底图用同一张封面放大模糊垫在
accent→surface 渐变上（沿用本模块 EQ 中心与播放页已有的 hero 语言），并且头图是从横排里
**取走**第一项而不是另插一张——`strip = playlists.skip(1)`，同一张歌单不会在页面上出现两次；
横排在头图吃掉唯一一项时连行标题一起收起。开关按仓库范式接到 `MusicUiElement.recommendBanner`
（`interface.musicUi`），行落在设置 → 音乐 → 界面设置 的第一条。）
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
差距：榜单富信息行的版式；竖屏播放器浮层（右侧动作列、底部选集条与进度线）。
另：本模块每轮 UI 之前仍带旧车道的只读接口巡检职责（榜单/详情/搜索/联想，见运行记录）。
（已闭合：榜单页的条件墙。`_RankView` 原先把整张榜的题材 chips 常驻在头排下面——一张 100
部的快照能数出几十个体裁，`Wrap` 铺成 4–6 行，片单被推到首屏以下；现在收进
`_RankFilterPanel`（复用 `HongguoFilterRowView`），头排只留 `榜单 + 筛选 + 刷新` 与一行当前题材摘要。
（接口巡检 2026-11-02：官网把榜单首页的包装换了形态，见运行记录；详情/搜索/联想三个接口
200 且字段未变，均为匿名只读、无签名无登录，不存在「未探测」项。选集条
`HongguoEpisodeShelf` 经核对已是「数字格 + 分组翻页 + 跳转 + 已看勾选」，符合参考形态，未动。）
（已闭合：海报卡的文字块。`widgets/hongguo_widgets.dart` 的 `HongguoSeriesCard` 与 vod 那张同病——
`pages/hongguo_page.dart` 两处片单给 `aspectRatio: 0.62` 的比例格，卡内却是「`AspectRatio(3:4)` 封面
+ 两行标题 + 一行 meta」的自然高度：格给文字区 `0.28 × 列宽`（220 列宽只有 61.5px，文字块实测要
85px），3 列/4 列的笔记本宽度整段溢出、>300 又留死白。现在照 vod 的解法收成一处量规：
`kHongguoSeriesCardInfoExtent = 82`（两行标题 42/44 + 4 + 一行 meta 17.4/18 + 6/8 内边距，touch 密度也装得下）
+ 封面 `Expanded` + `Stack(fit: StackFit.expand)`，3:4 降为偏好；`0.62` 折成 `kHongguoSeriesTileAspect`
由两处片单共用。片单的横排 `HongguoShelf` 是同一个卡的另一个家，它原先只给宽、让卡自量高度，
`Expanded` 在那里会撞无界高度——现在由它声明 `cardWidth / kHongguoSeriesTileAspect`，
墙上与横排因此拿到同一张卡形，加载骨架也改读这个高度（原先按 `cardWidth × 4/3` 占位，
比真卡矮，内容一到就重排）。文字块用 `spaceBetween`：关掉 meta 时空出的高度落在标题与底边之间，
不顶在 meta 那行上。同一处还去掉一个重复——`hot`（封面脚下的热度 chip）与 `meta`（标题下的
`热度 · 分类`）默认同时开，同一张卡把同一串热度印两遍；现在 `hongguoSeriesMetaLine(series, withFigure:)`
只在封面那枚没出现时才带数字，分类照旧，枚举文档与设置项 wording 已对上（`封面热度`/`列表信息`
两个标签本来就够泛，未新增 l10n）。
（接口巡检 2026-11-02：四条榜单（`/rank/hot-drama`、`hot-real-drama`、`hot-comic-drama`、
`hot-ai-drama`）第 1 页 200、`_rankPayload` 的 `r` 注册表 + `s` 指针两条路都读得到，各 20 行、
totalPages 5，行字段与上轮记录一致（`id/seriesId/title/cover/episodeCount/statusTags/scoreText/
favoriteText/likeText/openEpisodeCount/isPaid/playHref/href/heatText/rank/tags/description/episodeVids`）；
`detail?series_id=`（200，`loaderData.detail_page.seriesDetail` 的 `vid_list`/`episode_cnt` 与
`seriesSocialInfo` 的 `rating/hot_score_data/series_favorite_count/series_like_count` 都在）、
`/api/search/result`（200，`pageNum/totalPages/hasMore/totalCount/searchList`，行仍是
`doc_type/name/video_data/video_list`）、`/incent_resource/suggestion`（200，`suggest_list[].name/display_words`）
字段均未变，四处仍是匿名只读、无签名无登录，无「未探测」项。`?page=1` 照旧被 301 剥掉查询串，落到默认第 1 页，行为不变。）

## 轮转指针

| 字段 | 值 |
|---|---|
| 下一轮模块 | vod |
| 上一次提交 | hongguo · 海报卡的文字块定高、封面吃剩余，热度不再印两遍 |
| 连续无改动轮数 | 0 |
| 暂停条件 | 连续 3 轮无改动即停手并在回复里说明需要用户裁决 |

## 运行记录

| 日期时间 | 模块 | 改了什么 | 参考依据 | 验证 | 提交 |
|---|---|---|---|---|---|
| 2026-11-02 01:56 | vod | 首页/分区/影视三个浏览页的头排各自为政：首页只有一个刷新按钮，分区页连刷新都没有，而它们读的正是全局 `browseLayoutProvider`——视频站里没有任何入口能切卡片/列表。新增 `widgets/vod_toolbar.dart` 的 `VodFeedToolbar`，照直播热门页那套形态收敛：宽窗 `标签行 + LayoutToggle + 刷新`，窄窗只留标签行、刷新与版式收进右上角 more（`DsMenuAnchor`），行高统一到 44。动态 tab 与影视 poster 墙没有第二种版式 → `showLayout: false`，不留失效开关。 | 爱奇艺客户端首页有「海报模式/列表模式」两种首页形态、默认海报模式，且频道页是「Banner + 分类合集 + 内容宫格 + 右上角筛选」的模块化版式（jianshu 爱奇艺APP产品体验报告、zhidao 爱奇艺怎么切换列表模式）；腾讯视频首页为「顶部操作区 + Banner + 大卡片/双瀑布流」（new.qq.com 5500字拆解腾讯视频app细节设计）。即：视图形态是页面级入口，页面动作落在页头右上角。 | `dart analyze apps/pure_live/lib` 0 issues；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,vod)`） |
| 2026-11-02 02:20 | iptv | 频道浏览页只有一种形态：`_ChannelsTable` 那张 `DsTable` 用 `layout: DsTableLayout.auto()`，五个列的最小合计是 220+120+200+72+64 = 676px（加左右 padding 约 700）。窄窗（<600 的手机）拿到的结果是横向滚动 + 边缘渐隐，收藏心和播放动作被推到视口外，只能靠横滚找到；而 kit 在 <480 给的兜底是 card 版式，一行一个「标签 值」且行高只有一个文字行，本站的 `_ChannelNameCell`（台名+频道号）和 `_NowCell`（节目名+进度条）本来就是两行，会被裁成一行。本轮把窄态定义出来：<600 改为 `ListView.separated` + `DsListRow` 的堆叠行（leading 台标 / title 台名 / detail 频道号 / description 复用 `_NowCell` 的正在播出+进度 / trailing 心+播放），抄的是本模块「最近观看」页已经在用的行语言，分页沿用同一个 scroll controller；≥600 才是表，并且分组列只在 ≥960 的宽窗出现（分组已经由上面 `_GroupTabs` 命名并计数，这一列正是把表撑过中窗的那 120px），台名列最小 220→200，让 600–960 段的合计落到 200+200+72+64+24 ≈ 560px 不再横滚。表格布局改回默认的 `.rows()`，窄态由本模块自己定义，不再交给 kit 的标签堆。 | 电视直播类的主界面是「左侧导航栏 + 右侧内容区」，频道列表 + 节目单是核心模块，EPG 在列表/播放界面按上下键调出（csdn 电视直播软件全攻略 163708420、gitblog_00973 界面详解：中央播放窗口/频道列表区/底部功能栏）；成熟播放器把「正在播出 + 接下来」和节目进度条作为频道列表的行内信息（HDHomeRun：what's on now and what's on next guide data、program progress bar、channel logos；AnyTV IPTV Player：see what's playing now and what's coming next、channel favorites）；窄屏形态是「点屏唤起侧边频道列表 / 长按唤出下方功能栏」的单列叠行（9k9k、pczhi 电视直播TV版）。即：台标 + 台名 + 正在播出与进度是行的必备三要素，分组是导航维度而非每行的固定列。 | `dart analyze apps/pure_live/lib` 0 issues（`dart format --line-length 120` 本轮文件 0 改动）；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,iptv)`） |
| 2026-11-02 02:59 | hongguo | 两件，第一件是硬故障。接口巡检：`/rank/hot-drama`、`/rank/hot-real-drama`、`/rank/hot-ai-drama` 的**第 1 页**把榜单包装换了形态——`mergeLoaderData` 不再内联 JSON（`routerDataFnName: "p"`），而是留一个指向同页 `r` 注册项的指针（`"s"`，参数是 `["\"rank_x\\u002Fpage\"","\"content\""]`），只有第 2 页起和 comic 板还是旧的内联形态；`_rankPayload` 只认 `"p"`，于是三条榜单在页 1 直接落空、榜单页整页报「剧集榜单暂不可用」，而 `websiteRankSnapshot` 的第 1 页就是这次读，四条榜单里三条连读都读不进来。本轮把 `r` 的注册表先收齐、再解析指针（`\/`→`/`），页 1 与页 2+ 两种形态都能读；用抓到的真实页面离线验证四条榜单 + `page=2` 全部解析成功（各 20 行、totalPages 5）。其余接口 200 且字段未变：详情 `_ROUTER_DATA.loaderData.detail_page.seriesDetail`（含 `vid_list`、`episode_cnt`）、`/api/search/result`（`searchList/totalCount/pageNum/totalPages/hasMore`，行是 `doc_type/name/video_data/video_list`）、`/incent_resource/suggestion`（`suggest_list[]` 的 `name/display_words`）；新增行字段 `playHref/statusTags/scoreText/favoriteText/likeText/openEpisodeCount/isPaid`，`_seriesFromRank` 早已读到位。一处只记录未改：`?page=1` 现在被 301 剥掉查询串（落到默认页 1，行为不变）。第二件是版式：`_RankView` 把整张榜的题材 chips 常驻在头排下面（100 部剧数出几十个体裁，`Wrap` 铺成 4–6 行，片单被挤出首屏，而同一时刻只有一个题材有效），收敛成头排 `榜单 + 筛选 + 刷新` + 一行当前题材摘要，条件本体进 `_RankFilterPanel`（`DsPanel` + 现成的 `HongguoFilterRowView`，选中即过滤、名次不变，来源与后台更新说明挪到面板底部）。新增 l10n `rankFilterTitle`（en/zh），`rankKeepsPlaces` 改成能独立成句。 | 榜单页的筛选是头部入口而非常驻条件墙：爱奇艺的榜单是「热播总榜/必看榜/期待榜/飙升榜/免费榜」多榜 + 内容类目作主维度（sohu 鸿蒙版爱奇艺上线问AI功能、ifeng 导航栏升级），榜单排版参照首页那套统一的一行封面图网格、不让条件挤掉内容（知乎《爱奇艺PC站风云榜改版总结》p/54696671）；腾讯视频的"榜"实际是"最热 tab 下的影片筛选"，首页视觉块数被刻意控制以免提高浏览成本（sohu 腾讯视频团宠、ui.cn/知乎《深度拆解腾讯视频APP细节设计》）。即：首屏属于片单，条件收进一个入口。 | `dart analyze apps/pure_live/lib` 0 issues；离线解析验证 4 条榜单 + 翻页全绿（临时脚本与抓取页面在仓外，跑完即删）；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`fix(ui,hongguo)`） |
| 2026-11-02 03:05 | music | 精选/在线歌单（`pages/music_online_playlists_view.dart` 的 `MusicOnlinePlaylistBrowse`，同一个 widget 同时是 精选 页和 歌单 页的在线 tab）把筛选条件常驻在内容上方：排序一行 `DsTopNav` + 分类一行 `DsTopNav` + 标签一整片 `Wrap`。一个 plaza 的热门标签/分组标签常有 20–50 个，`Wrap` 铺成 4–6 行，窄窗里歌单网格被推到看不见，宽窗也要先滚过一整片 chips 才看到内容，而这三个常驻控件在同一时刻只有 3 个值是有效的（当前排序、当前分类、当前标签）。本轮按仓库既有的「条件收进面板」形态（红果 找剧 `_FindView` + `_FindFilterPanel`）收敛：头排统一到 `SizedBox(height: 44)` + `s20` 左右内边距，`Expanded(标签行/标题) + 打开歌单 + 筛选`（筛选是图标入口，条件还没加载出来时 disabled），条件本体进新的 `MusicPlazaFilterPanel`（`DsPanel`，排序/分类/标签三段 `DsChip`，选中即回调进 browse 的 state 并 `_page = 1`），页头下方留一行 muted 摘要写当前 `排序 · 分类 · 标签`。顺手补掉一处对齐断裂：在线 tab 的 tab 行原先既没有 `s20` 左右内边距、也没有 44 高，而 我的 tab 的工具栏两者都有，切 tab 时整条工具栏会横移。新增 l10n 5 个 key（`plazaFilterTitle/Sorts/Groups/Tags/Done`，en + zh-CN）并跑 `dart run slang`；生成的 `.g.dart` 带进了 slang 自身的跨 namespace 重排（`room`/`settings` 的 `_ => null, } ?? switch (path)` 边界移动），不是本轮手改的内容。 | 爱奇艺首页/频道页是「顶部导航 + 筛选 + 轮播图」的头排 + 自上而下的单行模块（每行独立横滑），筛选是头部入口而非常驻条件行（woshipm 爱奇艺APP2023体验优化分析 1178、人人都是产品经理 爱奇艺产品分析报告 5677048）；腾讯视频首页顶栏为「搜索框 + 筛选按钮」，分类/筛选在二级页展示、首屏不放条件墙，内容行「左图右文单行排列、标题+副标题、右侧静态信息」（zcool 流媒体平台首页设计系列——腾讯视频 1180、chinutech 视频平台的会员运营细节 1179）。即：多条件收进一个入口，页面高度留给内容。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 本轮文件 0 追加改动；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,music)`） |
| 2026-11-02 03:23 | vod | 影视海报卡（`VodSeasonCard`，三处片单共用：影视页 poster 墙、搜索结果的番剧/电影、个人页在看）把「比例格」和「固定内容高度」对冲掉了：片单传 `aspectRatio: 0.62`，格子高度 = 列宽 × 1.613，而卡片按「3:4 海报 + 两行片名 + 一行更新状态」排内容，留给文字区的只有 `列宽 × 0.28`；量规把列宽压在 220–340，于是 220–269 段（3 列的 700–840px 窗、4 列的 950–1150px 窗，正是常见笔记本宽度）差 5–14px，片名第二行与更新状态被推出卡片、叠到下一行海报上，300–340 段又反过来空出 20–60px 死白。本轮把卡片改成「名字区定高 + 封面吃剩余」：新增 `kVodSeasonCardInfoExtent = 60`（compact 两行 42 + 6/8 内边距，touch 两行 44 也装得下），片名区 `SizedBox` 定高、海报 `Expanded` + `Stack(fit: StackFit.expand)` 承接高度（3:4 降为偏好，紧约束下按格裁边），更新状态 `subtitle`（`更新至第 N 话` / `全 N 话`）从文字区挪上海报右上角 `RoomCoverChip(compact: true)`、评分保持右下角，`ClipRRect` 从「只圆海报顶角」提到整卡；`0.62` 折成 `kVodSeasonTileAspect` 给三处片单共用，免得下一处再各写各的。 | 爱奇艺的内容卡把运营信息贴在海报四角——左上收藏、右上免费/VIP、左下分类、右下评分，「通过一张海报就能尽量告诉用户尽量多的信息」，海报下面只留片名（csdn 爱奇艺UI赏析—首页推荐 125812485）；卡片元素以 3–5 个为宜，更新日期、集数、评分属贴在视觉块上的提示信息元素，超了会主次不分（woshipm 在电视端卡片设计如何进行 1047767）；内容卡分「图片块 + 内容块」，图片块取 16:9 / 1:1 / 2:3 这类固定形态（developer.android.google.cn TV 卡片指南 cards）。即：状态上封面、名字区定高，一行卡片才对得齐。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 重排到 3 处无关旧行已逐 hunk 还原；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,vod)`） |
| 2026-11-02 04:12 | iptv | 来源页那张表（`views/iptv_sources_view.dart` 的 `_SourcesTable`）与上一轮修掉的频道表是同一个缺陷，但更重：`layout: DsTableLayout.auto()` + 六列最小合计 240+100+90+150+104+92 = 776px。窄窗（手机 390、平板竖屏 600）拿到横滚 + 边缘渐隐，「自动更新」开关和删除被推到视口外；<480 时 kit 的兜底 card 版式一行只有一个文字行，而本站的 `_SourceNameCell` 本来就是两行（名称+徽章 / 地址+复制·打开），会被裁。本轮把窄态与中态都由模块定义：<760 改为堆叠行（`_SourceRow`：种类图标块 40 + 名称行含 网络/本地 与 使用中 徽章 + 一行 `类型 · N 个频道 · 更新时间` + 地址行含复制/打开 + 右列 自动更新开关在上、同步/删除在下），≥760 才是表，且「类型」列只在 ≥960 出现——它是地址的提示（`.m3u8`/`.xml.gz` 就在地址里），中窗把它读进地址行前缀 `M3U8 · https://…` 而不是再占一格，五列合计落到 200+76+120+96+84+32 = 608px；表格布局回到默认 `.rows()`，窄态不再交给 kit 的标签堆。顺带把两种形态共用的东西折成一个 `_SourcesActions`（activeId/频道数/忙碌集/阻塞 + 名称·地址·类型·时间·频道数·是否网络·是否使用中 的逐项读法 + 同步/删除/开关三个动作），表格里散在 `value:`/`cell:` 里的 `item is IptvPlaylist ? … : (item as EpgSource).…` 分支收敛到一处，堆叠行读的是同一套，两种形态不会再各说各话；`_copyAddress`/`_openAddress` 提成 `copySourceAddress`/`openSourceAddress` 供两形态共用。无新增 l10n（`channelCount`/`neverUpdated`/`networkTag` 等已够用）。 | 成熟的直播源管理页是「一行一个源」而不是六列表格：xTeVe 的 Sources 页每行给 Name、Links（该地址能取到的频道数）、Update period（自动更新周期，0 为关）、Enabled 开关与更新按钮，「点击更新按钮后…显示时间同时 Links 栏会有数量」（baijiahao 如何私人定制你的专属IPTV频道）；iptv-checker 管理界面是「左侧导航栏 + 右侧功能区」，EPG 数据源单列（csdn 终极指南：如何快速检测IPTV播放源可用性）；TV 端播放器同样把「名称 + 频道数 + 最后更新」当作列表行的三要素，且列表/图标/标题是可切的排布而非并排的列（isharepc TiviMate+Televizo 评测）。即：来源行 = 名称 + 数量 + 更新时间 + 开关/动作，类型属于地址而不是独立一列；放不下时堆叠行，不是横滚。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 只动本轮文件（第二次跑 0 改动）；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,iptv)`） |
| 2026-11-02 04:47 | music | 推荐页（模块自己的首页 `pages/music_recommend_view.dart`）没有第一视觉焦点：六类内容全排成同一种「行标题 + 内容」的等高行，歌单横排从页面第一条像素就开始，跟爱奇艺/腾讯视频那套「一张大 Banner 头图 → 再往下才是分行片单」的首页层级完全不同。本轮把头图补上，并且是**从既有数据里取**而不是造内容：`MusicRecommendHero` 读广场第一页最热的那一张歌单（`playlists.firstOrNull`），封面整块在左（宽窗 152 / 窄窗 104）、名字走 `heading` 两行、`作者 · N 首` 走 caption、眉标用广场自己的热门标签（不是编的「今日推荐」），底图是同一张封面 `ClipRect + ImageFiltered(blur 28) + Opacity(0.35)` 垫在 `accent(0.24) → surface` 渐变上——沿用本模块 EQ 中心 `_Hero` 与播放页背景已有的 hero 语言；动作是两个写明文字的小按钮 `全部播放` + `打开歌单`（头图整卡可点，播放在此页现取 `musicOnlinePlaylistDetailProvider` 的 tracks 再 `playAll`，取不到就报 `onlineLoadFailed`，不留死按钮）。横排改成读 `strip = playlists.skip(1)`，头图吃掉的那一项不再重复出现，只剩一张歌单时连行标题一起收起（`if (strip.isNotEmpty \|\| waitingForPlaza \|\| plazaFailed)`），失败重试行与加载态不受影响。开关按仓库「版式写死 + 每元素一个显隐开关」的范式接到 `MusicUiElement.recommendBanner`（同一份 `interface.musicUi`，枚举文档从「player's surfaces」放宽到「module's surfaces」），落在设置 → 音乐 → 界面设置 的第一条；新增 l10n `uiRecommendBanner`/`uiRecommendBannerDesc`（en + zh-CN）并跑 `dart run slang`。一处同源缺陷只记录未改：`pages/music_eq_center_page.dart:222` 的背景 `DsImage` 三个框参数全空，撞上 desen_ui 0.3.2 的 `(width!=null&&height!=null)!=(aspectRatio!=null)` 断言（debug 一进 EQ 中心即抛），本模块其余 8 处都有框。 | 首页的版式是「顶部导航/搜索栏 → banner 的滚动，为用户推荐最热的内容 → 往下才是『猜你喜欢』和热播剧推荐」，分区页更是「Banner + 分类合集 + 内容宫格 + 右上角筛选」的模块化结构，Banner 是首屏唯一的大视觉（jianshu 爱奇艺APP产品体验报告 5ddd4b9f3a09）；爱奇艺首页 Banner 的大标题压在左下、轮播点让到右下，「人工推荐的内容占据最醒目的位置」即推荐位是单独一层而不是行里的第一格（csdn 爱奇艺UI赏析—首页推荐 125812485、sohu 这样设计Banner点击率更高 445775567）；腾讯视频首页内容推荐区 = 「Banner 推荐站内热门内容，支持滑动与自动切换」+ 其下的双瀑布流与大卡片，且「卡片形式采用封面/视频+标题+标签」，同屏内容块刻意控制在 6 个以免浏览成本过高（zcool/ui.cn 深度拆解腾讯视频app细节设计 645580）。Banner 的背景色随内容取色衬托、深色表现体现空间感（huke88 UI 场景中的Banner布局样式探索 2519）。即：头图是首屏第一层、单独占一块，片单从它下面才开始；行标题与卡片同层是层级缺失。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 只动本轮 3 个文件（第二次跑 0 改动）；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`feat(ui,music)`） |
| 2026-11-02 05:20 | hongguo | 先做只读接口巡检（四条榜单第 1 页 + 详情 + 搜索 + 联想）：全部 200，`_rankPayload` 的 `r` 注册表与 `s` 指针两条路都还读得到（各 20 行、totalPages 5），行字段与上轮记录一致，`detail_page.seriesDetail`（`vid_list`/`episode_cnt`）、`api/search/result`（`pageNum/totalPages/hasMore/totalCount/searchList`）、`incent_resource/suggestion`（`suggest_list[].name/display_words`）字段均未变，四处仍是匿名只读、无签名无登录，无「未探测」项；`?page=1` 照旧被 301 剥掉查询串（落到默认页 1，行为不变）。版式那一件是海报卡的文字块：`HongguoSeriesCard` 与上一轮 vod 那张同病——`pages/hongguo_page.dart:562/1574` 给 `aspectRatio: 0.62` 的比例格（格高 = 列宽 × 1.613），卡内却是 `AspectRatio(3:4)` 封面 + 两行标题 + 一行 meta 的自然高度，留给文字区的只有列宽 × 0.28（220 列宽给 61.5px，文字块实测要 85px），3/4 列的笔记本宽度整段溢出、叠到下一行海报上，>300 又留死白。本轮照同一解法收成一处量规：`kHongguoSeriesCardInfoExtent = 82`（compact 42 + 4 + 17.4，touch 44 + 4 + 18，加 6/8 内边距都装得下）+ 封面 `Expanded` + `Stack(fit: StackFit.expand)`（3:4 降为偏好，紧约束下按格裁边），`0.62` 折成 `kHongguoSeriesTileAspect` 给两处片单共用。同一张卡还有第二个家：`HongguoShelf` 原先只给宽、让卡自量高度，`Expanded` 在那里会撞无界高度，现在由横排声明 `cardWidth / kHongguoSeriesTileAspect`——墙上与横排因此是同一个卡形，加载骨架也改读这个高度（原先按 `cardWidth × 4/3` 占位，比真卡矮一截，内容一到就重排）。文字块改 `spaceBetween`：关掉 meta 时空出的高度落在标题与底边之间，不顶在 meta 行上。顺手去掉一张卡上的重复墨：`hot`（封面脚下的热度 chip）与 `meta`（标题下的 `热度 · 分类`）默认同开，同一串热度印两遍——`hongguoSeriesMetaLine(series, withFigure:)` 现在只在封面那枚没出现时才带数字，分类照旧，枚举文档同步。无新增 l10n（`封面热度`/`列表信息` 两个标签本来就够泛，而且它们在 settings 命名空间、不在本轮允许路径）。 | 竖版海报卡是「海报一层 + 文字块一层」，文字块只装片名与一行灰字元信息：爱奇艺的瀑布流卡片「内容以影视封面为主，竖版结构…每个卡片所展示的信息内容相对简单，只有影视剧名称和推荐理由及类型」，腾讯视频同层给「影视剧名称，主演及推荐理由」（new.qq.com / sohu 洞察｜爱优腾 瀑布流设计）；海报墙的实现按「海报区 / 标题单行截断 + 右上角状态色标签 / 类型 · 题材 · 年份 灰字元信息行 / 星级 + 评分 / 操作」分层，更新状态记在角标而不是再写一行（harmonyosdev.csdn 海报墙网格：ArkUI 让鸿蒙影音收藏页像流媒体首页）。即：封面与文字块各自定形、行高不随列宽漂移；同一个数字在一张卡上只说一次。 | `dart analyze apps/pure_live/lib` 0 issues；离线解析验证四条榜单全绿（临时脚本与抓取页面在仓外 `AppData/Local/Temp/hgp`，跑完即删）；`dart format --line-length 120` 重排到 `hongguo_page.dart` 一处无关旧行（`_takeHandoff`）已还原；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,hongguo)`） |
