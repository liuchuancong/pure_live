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
差距：`pages/vod_settings_pane.dart` 的「界面设置」原先只有一个开关（详情是否显示在画面下方），
没有视频卡的逐元素显隐设置；首页没有分行的片单编排（头图已补，见下方已闭合项——但真正按主题
分行的片单要先有数据：`VodVideo` 不带分区/题材字段，`packages/live_vod` 的目录里也没读进来，
属于「确需数据字段」那一类，单列一轮）。
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
（已闭合：搜索页的常驻条件行。`pages/vod_search_page.dart` 原先在结果上面常驻一排两个下拉
（排序 150 + 时长 160 的 `AdaptiveChoiceField`），并且它那一行结果分类只有 40 高、既不用本模块的
`VodFeedToolbar` 也没有刷新——同模块四个头排三种几何。现在头排统一到同一个 44 与同一个 more：
分类 `DsTopNav` 在头排起点、筛选入口与刷新在终点（窄窗两个都折进右上角 more），条件本体进
`_SearchFilterPanel`（`DsPanel`，排序 5 档 + 时长 5 档两组 `DsChip`，面板内选、`确定` 才发一次请求，
免得走一遍排序就打五次站点），头排下面留一行 muted 的 `排序 · 时长` 摘要（没有已提交的查询时
既不显示摘要、也不显示刷新——空查询上刷一下什么都不做，不摆失效开关）。`widgets/vod_toolbar.dart`
为此长出两个口子：`VodFeedAction`（同一个动作在宽窗是图标按钮、窄窗是 more 里的一项）与
可空的 `onRefresh`；三处既有片单的头排几何与菜单内容不变（版式切换仍在刷新左边）。
`searchFilterTitle` 新 l10n（en/zh）。搜索页仍没有版式切换开关：结果网格只有卡片一种形态，
`showLayout: false`。）
（已闭合：首页缺的那一层头图。`pages/vod_page.dart` 的 推荐/热门 两个 tab 原先整页就是
一个 `PagedCardGrid`——片单从工具栏下面第一条像素开始，页面没有任何第一视觉焦点，而同模块
的影视页至少有 `VodSeasonCard` 墙、参考首页则是「焦点图 → 下面才是片单」。现在 `widgets/vod_widgets.dart`
长出 `VodFeedHero`：封面按站点自己的 16:9 摆在头部起点（宽 = `0.4 × 页宽`，夹在 280–440，
高度由封面自己定，不做整幅 cover 裁切——站点的画是按 16:9 画的，裁成一条横带就切掉了它自己的
上下沿），片名 `heading` 两行、`UP主 · N 播放 · N 弹幕 · mm:ss` 一行 `caption`、眉标读当前 tab
自己的名字（`推荐`/`热门`，不是编出来的「今日推荐」），动作排给写明文字的 `播放`(primary) 与
`收藏`(secondary，读站点的本地收藏 `vodFavouritesProvider`，同一个 bvid 决定字样)。头图是
**从片单里取走**第一项而不是另插一张（`items = videos.sublist(1)`），同一部片不会在页面上出现两次；
只剩一条时不摆头图（它回到格子里当卡片），加载中/失败也不摆（下面已经是骨架/错误面）。
它是常驻 chrome 而不是随片单滚走的层，`PagedCardGrid` 的滚动面由共享层自己拿着、本模块加不了
header slot，所以 <600 的窄窗不给它——一条不肯让位的横幅会把片单推出首屏，正是这几轮删掉常驻
条件墙的同一个理由。开关按仓库范式接到 `vodFeedBannerProvider`（`controller/vod_settings.dart`，
`vod.feed.banner`，默认开），落在设置 → Bilibili 视频 → 界面设置 的第一条；新增 l10n
`showFeedBanner`/`showFeedBannerDesc`（en/zh）并跑 `dart run slang`。
同一轮另一件（用户点名「分P 也移到下方」）：`pages/vod_video_page.dart` 的控制条原先在画面上
挂一枚 `P1` 分P 选择器、点开是浮在picture上的 `PlayerOverlayPanel`，而画面下方本来就有一条
`_PartsSection` 选集架（数字格 + 分组翻页 + 跳转），同一个选择在页面上有两个入口。现在内联
播放器的控制条不再带它——分P 只在画面下方那一条里选；全屏/悬浮（`immersive`）时页面本体不在
屏幕上，控制条那枚是唯一的通路，照旧保留。）
（已闭合：影视详情页的那一层正面。`pages/vod_season_page.dart` 的 `_header` 原先只有「`title` 级片名
+ `已追` 徽章 + 年份 + 本集片名 + 简介截到四行」——从海报墙点进详情，墙上那张 `VodSeasonCard` 摆在
封面角上的**更新状态与评分**在这里全部消失，播放量/弹幕数/地区/题材一个不说，海报自己也不出现
（`VodSeasonDetail.coverUrl` 解析出来却没人画），而页面 AppBar 已经写着同一个片名；那四行简介还是
死路——同模块视频页的 `_description` 有 `TextPainter` 量出来的展开/收起，这一页单独没有。现在补
`widgets/vod_widgets.dart` 的 `VodSeasonHead`：海报 104 宽、按站点自己的 3:4（与墙上同一张画）、
`heading` 片名只写一遍 + `已追` 徽章、本集行（`index` 徽章 + 本集片名，正是参考的「第X集/共N集」那一层）、
`更新状态 · 评分 · 播放 · 弹幕 · 年份` 一行 caption、`地区 + 题材` 徽章排、简介整段带四行折叠。
数字为此进 `packages/live_vod`：`VodSeasonDetail` 长出 `subtitle`/`rating`/`viewCount`/`danmakuCount`/
`area`/`styles`，`seasonDetail` 补读 `stat.views`/`danmakus`、`rating.score`、`areas[].name`、`styles[]`；
更新状态取 `seasons[]` 里属于本季那条的 `new_ep.index_show`（`更新至第1278话`），电影的答案不带
`seasons`，退到答案自己的 `new_ep.desc`（`2023年03月31日上映`）——两条路径都拿真实答案逐条核过。
评分 0 读作「还没人评」而不是「0 分」，`_scoreOf` 同时供海报卡的 `rating` 用，同一个站对一个数字只有
一种写法（卡上的 `"9.0"` 从此折成 `"9"`）。年份只在这条状态串自己没带年份时才写：电影的状态串就是
上映日，同一句话不写两遍。折叠读视频页同一个 `vodPlaybackSettingsProvider.showDetails`（它的说明本来
就是「关闭后隐藏…数据和简介」），不在模块里开第二个同类开关。新增 l10n `score`（en "Rating" /
zh「评分」）并跑 `dart run slang`（生成的三个 `.g.dart` 只带这一个键，无跨 namespace churn）；
`live_vod` 既有的 seasonDetail 用例扩到覆盖这些字段，另加一条电影退路用例。）
（另记两件，留给下一次 vod：① 首页「按主题分行的片单」这轮探过又收回——`x/web-interface/popular` 的
行确实带 `tid`/`tname`（还有 `pid_name_v2`），但第 1 页 20 行数出 14 个不同 `tname`、最多的一档只有
5 条，按 `tname` 分组得到的是一排只有一两张卡的行，不是参考那种一行八张的片单；真要分行只能按
`regionFeed(tid)` 一个频道抓一条横排（本模块已有 `kVodRegionChannels` 的 15 个频道 id），那是「首屏抓
N 份网络」的功能而不是版式修正。② `kVodRegionChannels` 的频道名是硬编码中文（`'动画'`…），是这一
模块里唯一没走 Slang 的用户可见文案。）

### iptv —— `apps/pure_live/lib/modules/iptv/`（领域层在 `packages/live_iptv`，无 UI）

页面：`pages/iptv_page.dart`、`iptv_play_page.dart`、`iptv_guide_page.dart`、`iptv_recent_page.dart`、
`iptv_settings_pane.dart`；视图：`views/iptv_panels.dart`、`iptv_sources_view.dart`、
`iptv_guide_panel.dart`、`iptv_import_dialog.dart`、`iptv_zapper.dart`；浏览设置
`controllers/iptv_browse_settings.dart`。现状是频道表格 + 来源资源表。
差距：电视类经典的「分组 + 频道列表 + 节目单」三栏现在两处都有了——频道页 ≥960 是「分组列 +
频道表」（播放器是它自己的路由），节目单页 ≥1200 是「分组列 + 选台器 + 一天节目」（见运行记录
2026-11-02 05:55 与本轮那条）；窄屏折叠态定义了四处（<600 频道行改堆叠列表、来源表 <760 改堆叠行、
<960 频道页分组收进一个入口、<1200 节目单页同样）。
另：「正在播出」与进度、收藏、节目单的层级还需对照。
（已闭合：节目单页选台器的分组维度。`pages/iptv_guide_page.dart` 的选台器原先是一条**全库**列表加
名字搜索——100 个分组、几千个台的播放列表只能靠打字到达，而频道页上一轮刚长出的分组列在这一页
没有第二个实例；本轮把频道页的 `_GroupRail`/`_GroupEntry`/`_GroupPickerPanel`/`_GroupList` 从页面里
提成 `views/iptv_group_rail.dart` 的 `IptvGroupsColumn`/`IptvGroupEntry`/`IptvGroupPickerPanel`/
`IptvGroupList`（它们读一个 `IptvGroupFilter` 记录 + 一个 `onSelect`，不再认识频道页的控制器），
频道页原样接回，节目单页接上同一套：≥1200 且分组多于一个走三栏（分组列 200 + 选台器 280 + 节目），
放不下时仍占选台器搜索框上面那一行（一个入口 + `DsPanel`），比频道页的 960 更晚是因为这一页多付一根
固定宽度的选台器。选台器读的是 `library.zapSequence(group:)`（频道页与换台器走的同一条可见序列），
分组数与分组计数因此与下面列出的行同一个数——原先它走 `orderedChannels`，把隐藏的台也算进去。
同一原则推到的两处：选定分组后行内不再逐行重复它（`iptvGroupLabel` 只在跨分组浏览时作 description，
与频道页 `showGroup` 同一个判据），三种空分开说（搜索没中 `没有匹配的频道`、分组里没台
`这个分组没有频道`、库是空的才是 `还没有频道` + 导入邀请；页头那行原先把这三样都写成导入邀请，
现在只报筛选后的台数）。分组的选择由这一页自己拿着（`_group`），不并进频道页控制器的
`selectedGroup`：那一份状态还带着收藏范围与逐页揭示，都不是「读一天节目」要的东西；换组时日子跟着
走到新组里第一个台，免得面板顶着一个已经不在列表里的频道。无新增 l10n
（`groupsLabel`/`tabAll`/`zapperGroups`/`zapperEmptyGroup`/`noChannelMatch`/`channelCount` 都够，
未跑 slang）。
（剩下的缺口：`pages/iptv_recent_page.dart` 仍是一条平铺列表、逐行写分组名而没有分组维度；
`packages/live_iptv` 的 `groupNames` 含未分组空串键，因此「未分组」的台只能靠「全部」看到。）
（已闭合：来源表在窄窗与中窗的形态。`views/iptv_sources_view.dart` 的 `_SourcesTable` 原先
`layout: DsTableLayout.auto()`，六列最小合计 240+100+90+150+104+92 = 776px，窄窗横滚、
中窗（720–960）也放不下；现在 <760 由本模块自己定义堆叠行（种类图标 + 名称行 + 一行
`类型 · 频道数 · 更新时间` + 地址行 + 自动更新开关与同步/删除），≥760 才是表，且「类型」列
只在 ≥960 出现、中窗把它读进地址行前缀（`M3U8 · https://…`），五种字段的合计落到
200+76+120+96+84+32 = 608px。表与堆叠行共用同一个 `_SourcesActions`，两种形态的字段与动作
不会各说各话。）
（已闭合：频道页的分组导航形态。`pages/iptv_page.dart` 原先把分组排成一条 `DsTabs` 横滚条
（`_GroupTabs`）常驻在频道表上面，而一份真实播放列表常有 50–150 个分组：条子横到看不见尽头、
当前分组在窗口外、切一次要滚一遍；参考形态的分组是第一列的竖排列表，不是页面顶部的一条。现在
≥960 走经典两栏——左 `_GroupRail`（`DsCard` + 列头 `频道分组` + `_GroupList`），右频道表面板，
分组行是 `DsListRow`（台名一行 + 末列 `iptvNumber` 频道数、`selected` 走 kit 的选中底），
`ListView.builder(itemExtent: 48)` 懒建，与换台面板 `_Column` 同一套行语言与 48 的量规；
<960 放不下列，就仍占工具栏下面那一行，但只留一个入口 `_GroupEntry`（当前分组名或 `分组`，
≤260 省略号），点开 `_GroupPickerPanel`（`DsPanel` + `scrollable: false` 装同一个 `_GroupList`，
选中即过滤并关面板——它是选择器，不是一组要一起提交的条件）。两种形态共用 `_GroupList`，
字段与计数不会各说各话。分组选定后，频道表不再重复它：`showGroup` 现在要求
`selectedGroup == null`（跨分组浏览时才逐行标分组），窄态堆叠行的那行分组名同理——把同一个
分组名印 60 遍是上一轮红果卡「同一个数字只说一次」的同一处病。`_GroupTabs` 删除，无新增 l10n
（`groupsLabel`/`tabAll`/`zapperGroups`/`ungrouped` 够用）。
（已闭合：节目单页那一天的正面。`pages/iptv_guide_page.dart` 的右侧面板原先直接就是
`_SchedulePanel` 的一天列表——整页说不出「这是哪个台的一天、现在在播什么、这一页能做什么」，
而控制这块内容的日子控件（`_DayStepper`）挂在**页头**最右端，压在左右两栏的分界之上、两边都不属于；
频道名只在左侧 320（窄窗是固定 260）那个列表里以选中底色表示，窄窗里它自己会滚走，滚完这一天的
列表就变成任何频道的一天。这个模块的播放器本来就有这层——`iptv_play_page.dart` 的 `_InfoBar` 是
「频道号 + 频道名 + `HH:mm - HH:mm 节目名` + 进度条」。现在由 `_ScheduleHead` 补上：台标
（`_ChannelLogo`，从 `_ChannelPicker` 内联那枚 `DsAvatar` 提出、两处共用）+ 台名 `title` + 频道号
与分组（读现成的 `browse.showChannelNumber`，不在模块里开第二个同类开关）+ 动作排 `收藏`心
（写 `library.toggleFavorite` 这个所有表面共用的接缝，与频道表同一枚 `IptvIconAction`）与
`播放频道`（这一页此前**没有任何进入直播画面的入口**——`_play` 只被回看行调用，看直播必须先退出
这一页）+ 日子控件搬进这块头层（`isToday` 时`今天`那枚整枚收起，它点上去什么也不做）。
正在播出那行只在**所展示的这一天**是今天时才画：`_slotOf(schedule, now)` 从面板真正列出的那批
节目里取 current/next（不是 `library.programmeSlot` 那条 42 小时的宽窗——昨天的日子会被今天的
节目戴上帽子），`DsBadge(正在播出)` + `HH:mm–HH:mm · 节目名` + `DsProgressBar(slot.progress)`；
没有正在播的就读下一个（`接下来 · HH:mm · 节目名`，clock 图标 + subtle），两样都没有时这行
整行不画——下面那张空状态已经写着`这一天没有节目`，同一句话写两遍不是写得更好。第三处顺手是
同层的诚实：`hasGuide`（`library.guideKeyFor(channel) == null`）现在分开两种空——没有节目单源
的台报`暂无节目单`（原先和「这一天没节目」混用一个 `guideEmpty`，把源的缺失说成台的空闲，
而播放器那块面板 `_IptvGuidePanel` 本来就分得开）；`showProgrammeLine` 那个既有开关同时管住
头层这行，与频道表的「正在播出」列同源。窄/中窗那两根面板改为按视口高度 flex 2/3 分，不再给
选台器一根固定的 260——头层自己也要高度，固定值会把列表压成剩下的那点。无新增 l10n
（`openChannel`/`onAir`/`upNext`/`noGuide`/`guideEmpty`/`favouriteAction`/`ungrouped` 已够用，
未跑 slang）。当时剩下的「分组」维度这一页已经在下一轮补上（见上方选台器那一条与运行记录
2026-11-02 07:56）。

### music —— `apps/pure_live/lib/modules/music/`

页面：`music_page.dart` 根 + `pages/music_player_page.dart`、`music_eq_center_page.dart`、
`music_eq_editor.dart`、`music_album_page.dart`、`music_artist_page.dart`、`music_settings_pane.dart`
（总览/音源/下载/歌词/桌面歌词/EQ/快捷键/同步 8 个 Pane）；歌单卡
`pages/music_playlist_card.dart`（`MusicPlaylistCard`/`MusicPlaylistGrid`，房间卡设计平移，
`kMusicPlaylistCardMaxWidth = 200`、`kMusicPlaylistInfoHeight = 48`）。
差距：`controller/music_ui_settings.dart` 只管播放器装饰（模糊背景、频谱、播放器模式），歌单卡没有逐元素显隐设置。
（已闭合：音效中心页 hero 的那张背景图。`pages/music_eq_center_page.dart` 的 `_Hero` 把当前曲目的封面
放大模糊垫在整块头部后面，那枚 `DsImage` 只给了 `image` 与 `semanticLabel`，三个框参数（`width`/`height`/
`aspectRatio`）全空，撞上 desen_ui 0.3.2 的 `(width != null && height != null) != (aspectRatio != null)`
构造断言——debug 一进 设置→音乐→音效中心（或播放页推进来的 `MusicEffectsPage`）就是红屏，hero 整块画不出来。
本模块其余 12 处 `DsImage` 都留了框（逐条核对过），只有这一处漏。修法不是给它编一个框：这块是**满幅出血的
底图**，它的高度就是 hero 自己的高度（由 `Padding + Row` 的内容定），没有可预留的自有尺寸，而 `DsImage`
的契约正是「预留框、加载时布局不跳」。本模块已经有两处同一个形态——播放页背景 `music_player_page.dart:82`
与推荐页头图 `music_recommend_view.dart:419`，都是 `ClipRect` 里 `Transform.scale(1.5)` 包一枚
`Image(fit: BoxFit.cover)`。现在 EQ hero 读同一条：出血底图不是卡片，用封面自己铺满；`ClipRect` 收住放大后
的溢出，1.5 倍让模糊的采样到边仍是实心（不 blur 到透明）；语义也随之让位给前面那枚 72 的 `_HeroCover`
方形（同一张封面在同一块里被读屏念两遍是重复墨）。无新增 l10n、未跑 slang。）
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
（已闭合：排行榜页缺的详情头层。`pages/music_charts_view.dart` 的 `MusicChartsView` 原先只有
一条 `DsTopNav` 榜名 + 最右一枚只有 `semanticLabel`、没有文字的 `DsButton.icon`
（`boardCollect`），底下直接就是
`MusicSongTableHeader` 和编号行——整页没有「这是哪张榜、里面有多少首、加起来多长」这一层，
也**没有全榜的播放动作**：本模块七个歌单/列表表面（`music_online_playlists_view.dart:675`
在线歌单详情、`music_songlists_view.dart:819` 自建歌单、`music_album_page.dart:154` 专辑、
`music_artist_page.dart:229` 歌手、`music_mine_view.dart:127` 收藏、`music_local_view.dart:205`
本地、`music_recommend_view.dart:234` 最近播放）全部给了 `全部播放`，只有榜单页要一首一首点。
现在补成 `MusicChartBoardHead`（榜单自己的封面/名称/规模 + 全榜动作），落在榜名导航行与
表头之间，且与本模块既有的详情头同一套几何：封面 72（EQ 中心、我的列表、在线歌单详情、
自建歌单四处头的封面都是 72）、`ClipRRect(theme.radii.card)` + `DsImage(aspectRatio: 1)`，
榜上没有自己的封面就读**榜首那首歌的封面**（`songs.firstOrNull?.coverUri`，与在线歌单详情
读第一首歌的封面同一个做法），取不到落 `CoverFallback(title: 榜名)`；名称走 `heading` 两行、
`N 首 · 总时长` 走 `caption`（时长由 `musicDurationText` 汇总，为 0 就整段不写）、
`catalog.description` 非空时作第二行 muted。动作是一个 `Wrap`：`全部播放`（primary）+
`随机播放`（secondary，与在线歌单详情同一对动词），歌还没读进来时这两个**整枚收起**而不是
摆一个 disabled 死按钮；`收藏榜单` 从导航行那枚无字图标搬进头层、写明文字，全榜只有一个入口。
无新增 l10n（`playAll`/`modeRandom`/`boardCollect`/`songsCount` 都够，故未跑 slang），
`MusicChartsView` 与头共用同一个 `musicCatalogItemsProvider(catalog)` family 键，不是二次抓取。
一处同源缺陷照旧未改，留给下一轮 music：`pages/music_eq_center_page.dart:222` 的背景
`DsImage(image: …, semanticLabel: …)` 三个框参数全空，撞上 desen_ui 0.3.2 的
`(width!=null&&height!=null)!=(aspectRatio!=null)` 断言（debug 一进 EQ 中心即抛，release 关掉
断言才看不出），本模块其余各处 `DsImage` 都留了框，只有这一处漏——本轮新写的榜头读的是
`aspectRatio: 1` 那条分支，不碰这个坑。）
（已闭合：音乐库/搜索页那张结果表没有头层。`pages/music_library_view.dart`（菜单的 音乐库，也是
`MusicPage` 的默认视图）在 歌曲 答案铺出来时只给一行 `N 首` 的 muted 小字，然后直接是
`MusicSongTableHeader` 与编号行——整页说不出「这一份答案能整体做什么」，而**逐行点**是唯一的通路。
它是本模块最后一个还这样的歌单表面：`全部播放` 已在 在线歌单详情(675)、自建歌单(819)、专辑(154)、
歌手(229)、收藏(127)、本地(278)、最近播放(234) 与上一轮刚补的榜单(229) 八处给齐。本轮把那行小字
折成 `resultsHead()`（`共 N 首` 左、动作 `Wrap` 右，`DsButton(size: sm)` 的
`全部播放`(primary) + `随机播放`(secondary)，与榜单头同一对动词、同一套 sm 尺寸），窄窗滚动追加态与
宽窗翻页态两处读同一个它——两处原先各写一遍同一段 `Padding + Text`。播放的对象是
`state.songs`（已经在手的那一份），与行内 `play(index)` 走的是同一条
`playAll(state.songs, index:)`：点第 7 行本来就是把手里的答案当队列，头层只是把这队列从第一行起放。
只有一首时 `随机播放` 整枚收起（洗一首歌什么也不做，不摆失效开关），而 `全部播放` 不在空/加载/失败里画
（那时 body 本来就不是这张表）。无新增 l10n（`playAll`/`modeRandom`/`songsCount` 已够用），未跑 slang。）
（剩下的缺口（music）：`controller/music_ui_settings.dart` 只管播放器装饰（模糊背景、频谱、播放器模式），
歌单卡 `pages/music_playlist_card.dart` 没有逐元素显隐设置；搜索的 歌单 结果标签（`_SonglistResults`）
仍是一排卡、没有自己的头层。下一轮按轮转是 hongguo。）

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
（已闭合：剧集页的头层。`pages/hongguo_series_page.dart` 原先把一张剧的「正面」拆成两块——上面是
`_playCard`（56×76 封面 + `body w600` 小片名 + 一行观看状态 + 播放/从头播放），下面是 `_info`
（同一个片名再用 `title` 写第二遍 + 更新状态与热度评分追赞首数 + 名次与题材徽章 + 收藏/云端收藏 +
剧情简介）：一个标题写两遍、四种进入播放器的动词散在两张卡上，而参考把「标题 + 集数进度 + 全部
动作」铺成详情级的一层；选集在宽窗还被锁进 320 侧栏、与简介抢主次。现在折成一个 `HongguoSeriesHead`：
封面 88×118（详情级，不再是侧卡）、片名 `heading` 两行只写一遍、`更新状态 · 热度 · 评分 · 追剧 ·
点赞 · N集` 一行 caption、名次与题材徽章、`第X集 · mm:ss` + `HongguoProgressStripe`（进度只有
观看历史页有，剧自己这一页说不出看到哪儿）、动作排收齐 `继续观看/播放`+`从头播放`+`收藏`+
`已加入账户收藏`（未登录不摆这枚）+ 简介（`_intro`）。简介的展开/收起原先是常驻的 `GestureDetector`
+ `DsLink`，三行以内也照样摆一个「展开」——现在按 vod 那处同一个做法用 `TextPainter` 量实际行数，
真的过三行才出现开关。`_play` 改成命名参数（`row:`），头与选集走同一条路径。宽窗那根 320 侧栏去掉，
选集回到主列（头 → 选集 → 相关 → 评论），只剩左右内边距按宽窄分档。`notWatchedYet` 从此无消费者，
l10n 串有意留着未删（删它要跑 slang，会带进跨 namespace churn），本轮未改 l10n、未跑 slang。）

（已闭合：播放页的浮层动作列。`pages/hongguo_player_page.dart` 的 `_actionRail`（38 玻璃圆盘 +
盘下一枚数字的竖屏动作列）原先**不只属于全屏画面**：它的显示条件是 `showBar && handle != null &&
detail != null && _openPanel == null && !_holding`，没有 `immersive`，于是内联播放器（页面本体还在
屏幕上的那一态）也在画面右上角摆一排圆盘——可同一页的画面**下面**本来就有 `_watchHead`，那里写着
`收藏`（同一枚 `library.toggleFavorite`，只是 heart 与 star 两种字形）、`下一集`、`下载`，而
`HongguoCommentPanel` 在这一页是常驻的（宽窗右栏 340、窄窗就在画面下面），圆盘那枚 `评论` 点开的是
同一份列表的 `DsPanel`。同一个动作在一张页面上有两个入口、盘下的追剧数与评论数又和头部那行数字
各说一遍，且圆盘压在画面顶角（正是本仓「一项一个入口」「同一个数字只说一次」的病灶）。现在圆盘列
只在 `immersive` 画：那一份窗口里没有页面本体，收藏/评论/分享只有这一条路，照旧保留；内联时这三件
由头部自己说，头部因此补上 `分享`（原来内联页面上分享**没有任何入口**，只有全屏才有）并把追剧数读进
数字行（`追剧` 在播放这一页此前只有圆盘那枚数字会写）。窄/宽两态的头排几何与选集架未动。）

（接口巡检 2026-11-02（本轮，只读）：四条榜单第 1 页 `/rank/hot-drama`、`hot-real-drama`、
`hot-comic-drama`、`hot-ai-drama` 全 200，`_rankPayload` 的两条路仍在（`r` 注册表 + `s` 指针 /
`p` 内联，第 1 页读到的是已解开的对象），`isSuccess: true`、各 20 行、totalPages 5；翻页第 2–5 页
200，第 6 页 404（与 totalPages 5 一致），行字段 18 项逐条核对无增无减
（`id/seriesId/rank/title/cover/href/playHref/heatText/statusTags/scoreText/favoriteText/likeText/
tags/description/episodeVids/episodeCount/openEpisodeCount/isPaid`）。`detail?series_id=` 200，
`loaderData` = `detail_layout`/`detail_page`，`detail_page` = `req`/`recommendations`/`seriesDetail`/
`seriesSocialInfo`/`isSuccess`，`seriesDetail` 的 `vid_list`(102)/`episode_cnt`/`episode_right_text`
（「全102集」）/`series_name`/`series_cover`/`series_intro`/`tags` 都在，另有**未消费**的
`accessible_episode_cnt`/`pay_type`/`series_episode_info`/`first_visible_time`/`season_info`；
`seriesSocialInfo` = `rating`(9.5)/`series_like_count`/`series_favorite_count`/`rank_label`
（「热播短剧榜第1名」）/`hot_score_data{score,text}` 与未消费的 `rating_count`/`reviews`。
`/api/search/result` 200：顶层 `searchList/totalCount/accessibleEpisodeCnt/pageNum/totalPages/hasMore`
（本例 10 行、20 页、193 条），行仍 `doc_type/name/keyword/video_data/user_info/video_list`，
`video_data` 内可见未消费的 `series_status/pay_type/celebrities/genre/favorite_text/like_text/
hot_score_data/category_list`。`/incent_resource/suggestion` 200：`suggest_list` 8 条，条目字段
`name/display_words` 加未消费的 `keyword/video_data/word_type`。四处仍是匿名只读、无签名无登录，
不存在「未探测」项；解析未坏，本轮不动数据层。）

## 轮转指针

| 字段 | 值 |
|---|---|
| 下一轮模块 | hongguo |
| 上一次提交 | music · 音乐库/搜索页的结果表没有头层（只一行 `N 首` 小字就进表，逐行点是唯一通路，而本模块八个歌单表面全都有 `全部播放`）：那行小字折成 `resultsHead()`（左 `共 N 首`、右 `全部播放`+`随机播放` 的 `Wrap`，与榜单头同一对动词与 sm 尺寸），窄窗滚动态与宽窗翻页态共用同一个它，只有一首时 `随机播放` 收起 |
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
| 2026-11-02 04:41 | vod | 搜索页（`pages/vod_search_page.dart`）把两个筛选器常驻在结果上面：排序 `AdaptiveChoiceField`（宽 150）+ 时长（宽 160）一排 `Wrap`，加上上面的分类行，用户要在首屏之前先滚过三行 chrome，而这两个控件在同一时刻只各有一个值有效；并且这一页是模块里唯一没接 `VodFeedToolbar` 的浏览页——分类行只有 40 高（其余四页 44）、也没有刷新，窄窗更没有 more。本轮把它折成同一种头排：`VodFeedToolbar(tabs: 分类, showLayout: false, filter: …, onRefresh: …)`，筛选入口与刷新落在头排最右端（窄窗两项一起进右上角 more），条件本体进新的 `_SearchFilterPanel`（`DsPanel` + 排序 5 档 / 时长 5 档两组 `DsChip`），头排下面留一行 muted 的 `排序 · 时长` 摘要。面板的选择**不即时发请求**：`_order`/`_duration` 先在面板里落定，`确定`（`t.common.confirm`）才 `setState` + `_rerun()` 一次——站点搜索是网络动作，走一遍五个排序不该打五次（红果榜单与音乐广场那种即时过滤是本地过滤，形态相同、代价不同）。`onRefresh` 只在已有提交的查询时给出（`vod.query.isNotEmpty`），空查询上刷一下什么都不做，不摆失效开关；`showLayout: false` 是因为搜索结果网格只有卡片一种形态。工具栏为此长出两个口子：`VodFeedAction`（一个动作、宽窗图标按钮与窄窗 more 项两种呈现）与可空的 `onRefresh`；排序/时长的 id 表与文案查表（`kVodSearchSorts`/`kVodSearchDurations`/`vodSearchSortLabel`/`vodSearchDurationLabel`）从内联 options 提成一处，摘要行和面板读同一套。三处既有片单的头排几何与菜单项不变（版式切换仍在刷新左边）。新增 l10n `searchFilterTitle`（en "Filters" / zh「筛选」）并跑 `dart run slang`。 | 视频类 APP 的排序与时长不是常驻行而是**右端入口 + 抽屉/浮层**：「筛选样式同样使用的是抽屉式…这些产品所用的筛选器所在的位置也是位于视觉最薄弱的右端，同时里面的内容都是关于时长和画质的」（站酷《设计筛选页面的小秘密》1033408）；「筛选项维度少时，可以将筛选（与排序一起）放置在搜索栏与结果之间，点击后以下拉菜单的形式出现；若维度丰富，一般使用侧边栏形式」（yrucd《APP和Web搜索功能的终极设计技巧分析》58420）；「排序和筛选的功能一般放置在搜索和结果之间…结果分类一般采用Tab的样式进行归类」（360doc《搜索框的设计》1041368302）；爱奇艺搜索「点击搜索范围，出现下拉选项，有三种筛选纬度」，结果页用 tab 分结果种类（人人都是产品经理《从4款主流产品出发，掌握"搜索"交互》3728115）；《UI系列-筛选页面设计总结》1063948 给的条件是「半浮层显示：从Tab栏底部向下展开，适合筛选纬度较多但不超过一屏」——本站两组共 10 档，正是浮层而不是常驻条件行。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 重排到一处无关旧行（`_takePending` 的 `TextEditingValue`）已还原；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,vod)`） |
| 2026-11-02 05:55 | iptv | 频道页的分组导航是一条常驻的 `DsTabs` 横滚条（`_GroupTabs`）：一份真实播放列表常有 50–150 个分组，条子横向长度远超视口、当前选中的分组常常在窗口之外、换一个分组要先滚完整条；而参考形态的分组是第一列的竖排列表。本轮把它改成第一栏：≥960 走经典两栏——左 `_GroupRail`（`DsCard` + `overline` 列头 `频道分组` + `_GroupList`），右频道表面板，分组行用 `DsListRow`（分组名一行 + 末列 `iptvNumber` 计数 + `selected` 用 kit 的选中底），`ListView.builder(itemExtent: 48)` 懒建、48 是本模块换台面板 `_Column` 已在用的行量规，`width: 200` 折成 `_kGroupRailWidth`（960 窗宽下两栏各留得住：内容 960−40−200−12 = 708 对表的最小 656+24）。<960 放不下列，就仍占工具栏下面那一行、但只留一个入口 `_GroupEntry`（当前分组名或 `分组`，`ConstrainedBox(maxWidth: 260)` 省略号），点开 `_GroupPickerPanel`（`DsPanel` + `scrollable: false` 装同一个 `_GroupList`，选中即过滤并收起——它是选择器，不是一组要一起提交的条件，所以没有「确定」）。两栏共用 `_GroupList`，名称/计数/选中的读法只有一处。第三处顺手是同一个原则推到底：分组选定后不再逐行重复它——`_ChannelsTable` 的 `showGroup` 现在要求 `channels.selectedGroup == null`（跨分组浏览时才逐行标分组），窄态 `_ChannelsList` 那行分组名同理（把同一个分组名印 60 遍，与上一轮红果卡「同一个数字只说一次」是同病）；`_GroupTabs` 删除。无新增 l10n（`groupsLabel`/`tabAll`/`zapperGroups`/`ungrouped` 已够用），故未跑 slang。 | 直播电视类的主界面第一栏就是分组：星河TV「打开以后，左边是频道分组，中间是频道列表，右边直接播放当前节目…央视频道、卫视频道、地方台、影视剧场…都分好了类，每一行都会显示频道号、电视台名称以及当前正在播放的节目」（bilibili 星河TV/畅映TV/超级直播评测 BV1bgak6EE6e）；MyTV Android 的「经典三段界面模式（左侧分组列表+中间频道列表+右侧EPG节目单）」，实现即 `LeanbackClassicPanelScreen.kt` 的横向三栏（csdn 148600990）；IPTVnator「左侧导航栏：播放列表与频道分类；中间区域：视频播放窗口；右侧面板：EPG节目指南」（csdn 153759132）；TiviMate「The menu bar on the left lists your Playlist Categories or "Groups"」且分类视图是「所有播放列表/所有频道/收藏夹」并高亮当前组（troypoint tivimate、37uu TiviMate 评测）；放不下时是弹出而不是常驻——YourTV/电视直播TV版「点击屏幕：弹出组/频道列表，点击选择」「点击左侧屏幕唤起电视频道列表」（pcbeta 2059872、9k9k 94061）。即：分组是竖排的第一栏（窄屏为弹层），不是一条横滚的常驻条。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 只动本轮文件（第二次跑 0 改动）；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,iptv)`） |
| 2026-11-02 05:15 | music | 排行榜页（`pages/music_charts_view.dart`，菜单里的 排行榜 / `MusicView.toplists`，也是 推荐 页那张榜单表点进来的地方）没有详情头层：导航行下面直接就是表头和编号行，整页说不出「这是哪张榜、里面多少首、加起来多长」，而且**全页没有全榜播放动作**——用户只能在三十行里一首一首点。它还是本模块唯一这样的表面：`全部播放` 已在 在线歌单详情(`music_online_playlists_view.dart:675`)、自建歌单(`music_songlists_view.dart:819`)、专辑(`music_album_page.dart:154`)、歌手(`music_artist_page.dart:229`)、收藏(`music_mine_view.dart:127`)、本地(`music_local_view.dart:205`)、最近播放(`music_recommend_view.dart:234`) 七处给齐，第七个列表 surface 单独漏掉就是版式断裂而不是风格选择。第二处断裂在同一行上：`收藏榜单` 挂在榜名导航的最右端，是一枚没有文字的 `DsButton.icon`（只有 `semanticLabel`），而它动作的对象是下面那张榜。本轮补 `MusicChartBoardHead`，插在导航行与表头之间，几何全部抄本模块已有的详情头：封面 72（EQ 中心 310/318、我的列表 91、在线歌单详情 639、自建歌单 783 四处头的封面都是 72）+ `ClipRRect(theme.radii.card)` + `DsImage(aspectRatio: 1)`；`audio.MusicCatalog` 自己不给封面（五家源都只 `MusicCatalog(id: …, name: …)`），就读榜首那首歌的 `coverUri`——与在线歌单详情读第一首歌封面同一个做法，不是编内容——取不到落 `CoverFallback(title: 榜名)`；名称 `heading` 两行、`N 首 · 总时长` 一行 `caption`（时长用现成的 `musicDurationText` 汇总，为 0 就整段不写），`catalog.description` 非空时再补一行 muted。动作排用 `Wrap`：`全部播放`(primary) + `随机播放`(secondary) 与在线歌单详情同一对动词，歌没读进来时两枚**整枚收起**而不是留一个 disabled 的死按钮；`收藏榜单` 搬进头层、写明文字，导航行回到纯榜名切换（`Row` 折成 `SizedBox(height: 44)`），一项一个入口。无新增 l10n（`playAll`/`modeRandom`/`boardCollect`/`songsCount` 够用，未跑 slang）；榜头与下面的列表读同一个 `musicCatalogItemsProvider(catalog)`，family 按 catalog（`==`/`hashCode` 都只认 id）去重，不是二次抓取。一处同源缺陷照旧只记录未改：`music_eq_center_page.dart:222` 的 `DsImage` 三个框参数全空，debug 一进 EQ 中心即抛。 | 音乐榜单/歌单详情这类「一张列表的正面」是「封面 + 名称 + 规模 + 全列表动作」的头层，动作在头部而不是行里：「在歌单详情页，最突出的是全部播放按钮…QQ音乐更注重让用户马上开始听歌」，网易云则在同层给「【收藏歌单】立体按钮 + 浏览歌单介绍」——收藏与介绍都是头层的事，不是导航行上的一枚图标（woshipm 产品分析报告｜网易云音乐 3290160、sohu 365225120、163 news F29KMLFG0511805E）；视频侧同一层级：爱奇艺的榜单是「热播总榜/必看榜/飙升榜/免费榜」多榜并列（pconline 鸿蒙版爱奇艺导航栏升级 21564931），详情页先给标题区再给选集/内容，榜与榜之间用 tab 切而把当前榜自己的信息铺成一块（本台账参考基线第 2 条）。即：列表页 = 一个头层 + 一张表；头部只放切换控件、内容直接从表头开始，是缺了一层。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 本轮文件 0 改动；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`feat(ui,music)`） |
| 2026-11-02 05:41 | hongguo | 先做只读接口巡检：四条榜单第 1 页（`/rank/hot-drama`、`hot-real-drama`、`hot-comic-drama`、`hot-ai-drama`）全 200，`_rankPayload` 的 `r` 注册表与 `s` 指针两条路都读得到（各 `isSuccess: true`、20 行、totalPages 5），行字段与上轮记录逐条一致（`id/seriesId/rank/title/cover/href/playHref/heatText/statusTags/scoreText/favoriteText/likeText/tags/description/episodeVids/episodeCount/openEpisodeCount/isPaid`）；`detail?series_id=` 200（`seriesDetail` 的 `vid_list`(100)/`episode_cnt`/`episode_right_text`/`tags`/`season_info`，`seriesSocialInfo` 的 `rating/series_favorite_count/series_like_count/hot_score_data{score,text}/rank_label` 都在，`rank_label` 现在能读到「热播AI剧榜第1名」这类整句）；`/api/search/result` 200（`searchList/totalCount/pageNum/totalPages/hasMore`，行仍 `doc_type/name/keyword/video_data/user_info/video_list`，`video_data` 里可见未消费的 `series_status/pay_type/celebrities/genre/favorite_text/like_text` 与顶层 `accessibleEpisodeCnt`——字段是**新增**不是改名，解析没坏，本轮不动）；`/incent_resource/suggestion` 200（`suggest_list[].name/display_words`，8 条）。四处仍是匿名只读、无签名无登录，无「未探测」项；`?page=1` 照旧被 301 剥掉查询串（落到默认页 1，行为不变）。版式那一件是剧集页（`pages/hongguo_series_page.dart`）的头层被拆成两块：`_playCard` 是「56×76 小封面 + `body w600` 片名 + 一行观看状态 + 播放/从头播放」，下面的 `_info` 又把**同一个片名**用 `title` 写第二遍，再带更新状态·热度·评分·追剧·点赞·集数、名次与题材徽章、收藏/云端收藏、剧情简介——片名两遍、四种进入播放器的动词散在两张卡上，而「看到第几集」这条进度在剧自己这一页根本说不出（`HongguoProgressStripe` 只在观看历史页用），选集在宽窗还被锁进 320px 侧栏与简介抢主次；简介那处「展开/收起」还是常驻的 `GestureDetector` + `DsLink`，三行以内也照样摆一个开关。本轮折成一个 `HongguoSeriesHead`：封面 88×118（详情级，不是侧卡）、`heading` 片名只写一遍、`更新状态 · 热度 · 评分 · 追剧 · 点赞 · N集` 一行 caption、名次与题材徽章、`第X集 · mm:ss` + `HongguoProgressStripe`、动作排收齐 `继续观看/播放` + `从头播放` + `收藏` + `已加入账户收藏`（未登录不摆这枚）+ 简介。`_intro` 照本仓 vod 那处同一个做法用 `TextPainter` 量实际行数，真的过三行才出现展开开关。`_play` 改命名参数 `row:`，头与选集走同一条路径；宽窗 320 侧栏去掉，选集回到主列（头 → 选集 → 相关 → 评论），只按宽窄分档左右内边距。无新增 l10n（未跑 slang）；`notWatchedYet` 从此无消费者，串有意留着——删它要跑 slang、会带进跨 namespace churn。 | 详情级的第一层是「标题 + 当前集数与总集数 + 状态标签 + 这一部自己的动作」，选集在它下面：点击唤出的信息浮层里「标题以较大字体显示在剧名下方，同时显示当前集数与总集数（如『第12集/共40集』），方便用户确认当前播放进度」，「标题旁边常附带 4K/HDR/粤语 等画质或语言标识」（k.sina 腾讯视频每集标题怎么显示 7879996025/7879996816）；操作不散落：竖屏播放页 =「顶部播放区 + 详情（视频标题、选集、讨论、周边、推荐）+ 底部快捷操作区（在追、下载、投屏、一起看、分享）」，且这套排法明写是为了「把操作集中一处、降低用户寻找高频操作的成本，而不是把功能分散在界面中」（zcool / ui.cn 深度拆解腾讯视频app细节设计 645580）；分集列表就在详情页标题区下面，「下滑至分集区域即可看到完整分集标题」，已看过的集数用灰色或对勾标记（k.sina 7879995960）。即：详情页第一层说清「这是什么剧、看到哪儿、从这里能做什么」；同一个片名写两遍、动作散在两张卡，是缺了一层。 | `dart analyze apps/pure_live/lib` 0 issues；离线解析验证四条榜单 + 详情/搜索/联想全绿（临时脚本与抓取页面在仓外 `D:/hgp_probe`，属本轮自建目录）；`dart format --line-length 120` 本轮 2 个文件（第二次跑 0 改动）；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`feat(ui,hongguo)`） |
| 2026-11-02 06:14 | vod | 站点首页（`pages/vod_page.dart` 的 推荐/热门 两个 tab）整页只有一个 `PagedCardGrid`：工具栏下面第一条像素就是网格，页面没有任何第一视觉焦点，而参考的首页是「焦点图 → 下面才是片单」那一层顺序（本台账基线第 1 条），同模块的影视页也至少有 `VodSeasonCard` 那面墙。本轮补 `widgets/vod_widgets.dart` 的 `VodFeedHero`：封面摆在头部起点、宽度 `0.4 × 页宽` 夹在 280–440，**按站点自己的 16:9 不裁**（站点的画就是按 16:9 画的，铺成整幅横幅会把它的上下沿切成一条横带；这也是本模块 `VodVideoCard` 一贯的封面比例），高度由封面定，文本列在头部终点——眉标读当前 tab 自己的名字（`推荐`/`热门`，不编「今日推荐」）、片名 `heading` 两行只写一遍、`UP主 · N 播放 · N 弹幕 · mm:ss` 一行 `caption`（数字在这里只说一次，不再像卡片那样染回封面上）、动作排 `播放`(primary) + `收藏`(secondary)，收藏读站点自己的本地收藏 `vodFavouritesProvider`（同一个 bvid 决定 `收藏`/`已收藏` 字样，不是摆设）。头图是**从片单里取走**第一项（`items = videos.sublist(1)`），同一部片不在页面出现两次；只剩一条、加载中、失败都不摆头图（那时下面本来就是卡片/骨架/错误面）。它是常驻层不是随片单滚走的层——`PagedCardGrid` 的滚动面归共享层 `shared/grids/paged_card_grid.dart`，本模块没有 header 插槽可塞（本轮不许动 shared），所以 <600 的窄窗不给它：一条不肯让位的横幅会把片单推出首屏，跟这几轮删掉的常驻条件墙是同一条病，窄屏让卡片自己当头部（手机一列的卡片本来就宽）。开关照仓库范式接 `vodFeedBannerProvider`（`controller/vod_settings.dart`，键 `vod.feed.banner`，默认开），落在设置 → Bilibili 视频 → 界面设置 第一条，与「显示视频详情」并排；新增 l10n `showFeedBanner`/`showFeedBannerDesc`（en/zh）并跑 `dart run slang`（生成的三个 `.g.dart` 只带这两个键，无跨 namespace churn）。同一轮第二件是用户点名的「分P 也移到下方」：`pages/vod_video_page.dart` 的控制条在画面上挂一枚 `P1` 分P 选择器、点开是浮在画面上的 `PlayerOverlayPanel`，而画面下方本来就有一条 `_PartsSection` 选集架（数字格 + 每 20 一组翻页 + 跳转框）——同一个选择在同一页两个入口。现在内联播放器的控制条不再带它，分P 只在画面下方那一条里选；`immersive`（全屏/悬窗）时页面本体根本不在屏幕上，那枚是唯一的通路，照旧保留。 | 视频站首页的第一层是焦点图而不是内容行：主流视频 PC 站的首页顶部就是「焦点图」，爱奇艺「焦点图：左右加蒙版」、优酷「焦点图：左右和上面加蒙版」、且选中态从一行文案变两行、大屏显示图标加文案而小屏只显示图标（网易/163《从设计师的角度分析，主流视频网站有何功能亮点》EFDDUNI00511805E）；腾讯视频首页内容推荐区 = 「Banner 推荐站内的热门内容」+ 其下的双瀑布流与大卡片，且同屏内容块刻意控制在 6 个以免浏览成本过高（站酷/ui.cn《深度拆解腾讯视频 app 的细节设计》645580）——即 Banner 是单独一层、片单从它下面才开始，而大卡片的文案是「封面/视频 + 标题 + 标签」三层而不是把数字再印一遍；列表类播放卡的标准形制是「图片 + 主标题 + 副标题 + 图标 + 按钮」且按钮写明「播放」这个动词（HarmonyOS 设计指南 uxdesign-component 卡片/列表类场景-播放）。即：首页 = 一层头图 + 其下的片单；头图给标题、规模与播放动作，数字只说一次。分P 那件无检索依据，是用户点名。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 重排到 `vod_widgets.dart` 两处无关旧行（`_CoverInk` 的两枚 chip 与它的 `copyWith`）已逐 hunk 还原；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`feat(ui,vod)`） |
| 2026-11-02 06:32 | iptv | 节目单页（`pages/iptv_guide_page.dart`，菜单的 节目单 项）右侧那一天的面板没有正面：`_SchedulePanel` 直接以一天的节目列表开始，整页说不出「这是哪个台的一天、现在在播什么、这一页能做什么」；台名只由左侧选台器那行的选中底色表示，而窄窗它自己是个 260 高会滚走的盒子，滚完这张列表就属于任何频道；控制这块内容的日子控件 `_DayStepper` 还挂在**页头**最右端，压在两栏的分界之上、两边都不属于。同模块的播放器本来就有这一层（`iptv_play_page.dart` 的 `_InfoBar`：频道号 + 台名 + `HH:mm - HH:mm 节目名` + 进度条），这一页单独缺就是断裂。本轮补 `_ScheduleHead`：台标 + 台名 `title` + 频道号与分组（读现成的 `browse.showChannelNumber`/`showProgrammeLine`，不在模块里开第二个同类开关）+ `收藏`心（走 `library.toggleFavorite` 这个所有表面共用的接缝，`_toggleFavourite` 后 `setState` 从库重新取回标记）+ `播放频道`，并把日子控件搬进头层——`isToday` 时`今天`那枚整枚收起（点上去什么都不做，不摆失效开关）。`播放频道` 是本模块**第一个**进入直播画面的入口：`_play` 原先只被回看行调用，想看直播必须先离开这一页。正在播出那行只在所展示的这一天是今天时才画，并且 `_slotOf(schedule, now)` 从面板真正列出的那批节目里取 current/next，不用 `library.programmeSlot` 那条 42 小时宽窗——否则昨天的日子会戴上今天节目的帽子；`DsBadge(正在播出)` + `HH:mm–HH:mm · 节目名` + `DsProgressBar(slot.progress)`，没有正在播的就读下一个（`接下来 · HH:mm · 节目名`），两样都没有时整行不画（下面那张空状态已经写着`这一天没有节目`，同一句话写两遍不是写得更好）。同层第二处是 `hasGuide`（`library.guideKeyFor(channel) == null`）把两种空分开：没有节目单源的台现在报`暂无节目单`，原先和「这一天没节目」混用 `guideEmpty`，把**源的缺失说成台的空闲**，而播放器那块 `_IptvGuidePanel` 本来就分得开。选台器那枚内联 `DsAvatar` 提成 `_ChannelLogo`，头层与列表两处同一枚标。窄/中窗的两根面板改按视口高度 flex 2/3 分，不再给选台器一根固定的 260——头层自己也要高度，固定值会把列表压成剩下那点。页头随之只剩 模块名/节目单/频道数（它原先唯一的目的就是放那枚 stepper）。无新增 l10n（`openChannel`/`onAir`/`upNext`/`noGuide`/`guideEmpty`/`favouriteAction`/`ungrouped` 已够用），未跑 slang。 | 直播软件的节目单面板自己就带频道正面：mytv-android 的面板界面（`PanelIptvInfo.kt` + `currentProgrammesProvider`）「展示了当前频道、节目名称、播放进度以及下一个节目的信息」，进度按 `progress()` 画成进度条（csdn mytv-android源码探秘：EPG数据处理与节目进度显示的技术细节 153720057）；电视 UI 的 EPG 横幅「在视觉上依序指示**所选频道**中的当前和下一个节目，具有节目标题和开始时间」，全屏 EPG 同样按「状态栏 + 含频道名称的频道栏 + 节目网格」分层（Google Patents CN111479150A、CN106576194A）；Tvheadend 的 EPG 把「进度条 / 播出时间 / 频道编号和名称」列为条目的必备显示（csdn Tvheadend EPG电子节目指南配置详解 156032591）；播放类 IPTV 客户端的更新说明是「to highlight the current programme and show upcoming programmes more clearly」并把指南收成「One page EPG guide (tabs removed)」（App Store Playlist editor & IPTV Player 1558368509）；而 EPG 需求的 Must have 里明写「Play current live items」——节目单是进入直播画面的路，不只是回看的入口（github jwplayer/ott-web-app issue 24 Electronic Programming Guide）。即：一天节目的第一层 = 频道身份 + 当前节目与进度 + 从这里能进播放器；日子控件属于这块面板，不属于页头。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 重排到一处无关旧行（`_takeHandoff` 的 `TextEditingValue`）已还原；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`feat(ui,iptv)`） |
| 2026-11-02 06:40 | music | 音效中心页（`pages/music_eq_center_page.dart`，设置 → 音乐 → 音效 与播放页推进来的 `MusicEffectsPage` 同一个 body）第一层就画不出来：`_Hero` 把当前曲目的封面放大模糊垫在整块头部后面，那枚 `DsImage` 只给了 `image` 与 `semanticLabel`，`width`/`height`/`aspectRatio` 三个框参数全空，撞上 desen_ui 0.3.2 的 `(width != null && height != null) != (aspectRatio != null)` 构造断言——debug 一进这一页整块 hero 是红屏，页面上「现在生效的是哪个音效 / 总开关」这一层直接消失，只剩下排的预设墙。这一处是台账连记两轮的现成目标，也是本模块 12 处 `DsImage` 里唯一没有框的（逐条核对：`_HeroCover` 72×72、artist 112、album `size`、charts/mine/online/songlists/playlist_card 各给 `aspectRatio: 1`、browse 96×96 与 `aspectRatio: 1`、player `label`、recommend `coverSize`）。修法不是给它编一个框：这块是**满幅出血的底图**，它的高度就是 hero 自己的高度（由 `Padding + Row` 的内容定），没有可预留的自有尺寸，而 `DsImage` 的契约正是「预留框、加载时布局不跳」；本模块两处同一形态早就分开了这两种职责——播放页背景 `music_player_page.dart:82` 与推荐页头图 `music_recommend_view.dart:419` 都是 `ClipRect` 里 `Transform.scale(1.5)` 包一枚 `Image(fit: BoxFit.cover)`。现在 EQ hero 读同一条：`ClipRect` 收住放大后的溢出、1.5 倍让模糊的采样到边仍是实心（不 blur 到透明，播放页那处写明的正是这个理由），语义让位给前面那枚 72 的 `_HeroCover`（同一张封面在同一块里被读屏念两遍，与本仓「同一个数字只说一次」同病）。无新增 l10n、未跑 slang。 | 音效/均衡器这一页的版式是「预设音效按卡片墙陈列，每张给名称 + 适用场景，当前生效项带选中态并可一键应用；均衡器是 10 频段滑块，且**先启用再调节**」（php.cn QQ音乐均衡器设置五种方式：预设模式一键应用、手动调节 10 频段、启用后才能调；zol 音效设置里 Supersound 的每个预设都带「超重低音：适合摇滚、电子乐」这类场景说明）——这一页的正面因此是「当前音效 + 总开关」而不是又一行预设，本页 hero 已有、只是被断言挡住；封面作背景的处理是成熟播放器的通行做法且需**加深/压透**才读得清上层文字：「其背景配色选择了将歌曲封面模糊并放大的方法」「歌词界面的背景 3 款 App 都使用封面的放大并模糊化处理后的图像，网易云把背景色调做了加深处理，方便用户看清歌词文字」（知乎 音乐播放页面体验报告 p/643161685），本仓 `_Hero` 的 `Opacity(0.35)` + `accent(0.30) → surface` 渐变垫层正是这一条。即：出血底图铺满整块并压到可读，且不靠预留框的组件表达；hero 的正面必须是「当前生效的音效 + 开关」。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 本轮文件 0 追加改动；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`fix(ui,music)`） |
| 2026-11-02 06:57 | hongguo | 先做只读接口巡检（四条榜单第 1–5 页 + 详情 + 搜索 + 联想）：全部 200，`_rankPayload` 的两条路仍在，`isSuccess: true`、各 20 行、totalPages 5，第 6 页 404（与之一致），行 18 项字段无增无减；`detail` 的 `seriesDetail.vid_list`(102)/`episode_cnt`/`episode_right_text`（「全102集」）与 `seriesSocialInfo` 的 `rating`(9.5)/`series_favorite_count`/`series_like_count`/`rank_label`（「热播短剧榜第1名」）/`hot_score_data{score,text}` 都在（另有未消费的 `series_episode_info`/`first_visible_time`/`accessible_episode_cnt`/`pay_type`/`rating_count`/`reviews`）；`api/search/result` 本例 10 行 / 20 页 / 193 条，行仍 `doc_type/name/keyword/video_data/user_info/video_list`；`incent_resource/suggestion` 8 条 `name/display_words`。四处仍是匿名只读、无签名无登录，无「未探测」项，解析未坏，故数据层未动。版式那一件是播放页（`pages/hongguo_player_page.dart`）：画面上那排竖屏动作圆盘 `_actionRail`（38 玻璃圆盘 + 盘下一枚数字：`收藏`(star)/`评论`/`分享`）的显示条件是 `showBar && handle != null && detail != null && _openPanel == null && !_holding`，**没有 `immersive`**——页面本体还在屏幕上的内联那一态，画面右上角也摆着这一列；可同一页画面**下面**本来就有 `_watchHead` 的 `收藏`（同一枚 `library.toggleFavorite`，只是字形一枚 star 一枚 heart）、`下一集`、`下载`，而 `HongguoCommentPanel` 在这一页是常驻的（宽窗右栏 340、窄窗排在画面下面），圆盘那枚 `评论` 点开的是同一份列表的 `DsPanel`：同一个动作两个入口，盘下的追剧数与评论数又和头部 `第X集 · 全N集 · mm:ss · N播放 · N评论 · N点赞` 那行各说一遍，圆盘还压在画面顶角。现在这列只在 `immersive` 画（那一份窗口里没有页面本体，收藏/评论/分享只有这条路，照旧保留；`top` 随之只剩顶条下面那一档）；内联的这三件由头部自己说，头部因此补上 `分享`（此前内联画面**没有任何分享入口**，只有全屏才有）并把追剧数读进数字行（此前只有圆盘会写它）。无新增 l10n（`share`/`followers`/`comments` 都已存在），未跑 slang；窄/宽两态的头排几何、选集架与浮层面板未动。 | 竖屏那排圆盘属于**沉浸式播放器**自己的 chrome：「播放器使用竖屏沉浸式布局，并支持滑动切集、倍速、选集和进度控制」，一套完整的短剧播放器需要「点击暂停和继续播放、上下滑动切换上一集或下一集、进度条拖动、倍速播放、选集面板、播放失败后重新加载」（cnblogs 短剧APP开发播放体验优化：从竖屏切集到断点续播 21960386）；实现里右侧按钮栏与画面控件同层——「右侧功能按钮栏 - 点赞、评论、分享、选集」写作 `right-controls` 且 `v-if="showControls"`，其下才是「底部控制栏 - 剧集信息、进度条、倍速控制」（csdn swiper+video 实现微信短剧的视频组件 157378089）；H5 竖屏短剧播放页「左下角显示剧名和当前集数，右侧集中放置连播、点赞、评论、收藏与分享入口」（139y 短剧H5播放器操作）。桌面/网页侧的动作在播放器**下面**而不是压在画面上：腾讯视频网页版「播放页下方发表评价，查看他人评论」「分享：点击“分享”，生成链接/二维码」（china 腾讯视频网页版入口 1699526）；同类产品在全屏态刻意去掉重复按钮——「全屏时的按钮实在太多，自然不会放置两个有同样功能的按钮」（woshipm 4款视频app交互设计浅析 574256）。即：右侧动作列归沉浸式画面的那一份窗口，内联页面里动词归画面下面的头部，一件事一个入口。 | `dart analyze apps/pure_live/lib` 0 issues；离线只读巡检验证四条榜单第 1–5 页 + 详情/搜索/联想全绿（抓取页面与脚本在仓外 `D:/hgp_probe2`，属本轮自建目录）；`dart format --line-length 120` 本轮文件 0 追加改动；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`polish(ui,hongguo)`） |
| 2026-11-02 07:33 | vod | 影视详情页（`pages/vod_season_page.dart`，从 影视 海报墙点进来的那一张剧的页面）没有详情级的第一层：`_header` 只有「`title` 级片名 + `已追` 徽章 + 裸年份 + 本集片名 + 简介截到四行」，而用户是从一张**带封面、带角标更新状态、带评分**的卡片点进来的——`VodSeasonDetail.coverUrl` 解析出来却没有任何地方画它，`更新至第1278话`、`评分 8.8`、`22.1亿播放`、`2324.7万弹幕`、`日本`、`漫画改/推理/悬疑` 这条剧自己说得出的一切在这一页全部消失；片名同时由页面 AppBar 写着（`title: season?.title`），`title` 级小字不是参考里「较大字体的剧名 + 当前集数与总集数」那一层；那四行简介还是死路（同模块视频页的 `_description` 有 `TextPainter` 量出来的展开/收起，这一页单独没有，`evaluate` 全文永远读不到）。本轮补 `widgets/vod_widgets.dart` 的 `VodSeasonHead`：海报 104 宽按站点自己的 3:4（与墙上同一张画、同一个比例偏好）、`heading` 片名只写一遍 + `已追`、本集行（`index` 徽章 + 本集片名，即参考的「第X集/共N集」层）、`更新状态 · 评分 · 播放 · 弹幕 · 年份` 一行 caption、`地区 + 题材` 徽章排、简介整段带四行折叠与展开。数字进数据层（台账记着的「确需数据字段」那一类）：`VodSeasonDetail` 长出 `subtitle`/`rating`/`viewCount`/`danmakuCount`/`area`/`styles`，`seasonDetail` 补读 `stat.views`/`danmakus`、`rating.score`、`areas[].name`、`styles[]`；更新状态取 `seasons[]` 里属于本季那条的 `new_ep.index_show`（`更新至第1278话`），电影的答案不带 `seasons`（实测 44658 的 `seasons` 长度为 0），退到答案自己的 `new_ep.desc`（`2023年03月31日上映`）。`rating.score` 为 0 读作「还没人评」而不是「0 分」，并把这层读法折成 `_scoreOf`，海报卡的 `rating` 同时改读它——同一个站对同一个数字只有一种写法（卡上的 `"9.0"` 从此是 `"9"`，字符串与数字两种拼法都吃）。年份只在这条状态串自己没带年份时才写（电影的状态串就是上映日，同一句话不写两遍）。折叠不新建开关：读视频页同一个 `vodPlaybackSettingsProvider.showDetails`，它的说明本来就是「关闭后隐藏 UP 主、数据和简介」。新增 l10n `score`（en "Rating" / zh「评分」）并跑 `dart run slang`（三个 `.g.dart` 只带这一个键，无跨 namespace churn）；`live_vod` 既有的 seasonDetail 用例扩到覆盖六个新字段（含 `seasons[]` 兄弟项取值那条路径），另加一条电影退路用例。另探一件事并退回：首页「按主题分行的片单」缺的不是 chrome 而是数据——`popular` 的行带 `tname`，但第 1 页 20 行数出 14 个不同 `tname`、最多一档 5 条，分组得到的是 14 行只有一两张卡的行，不是参考一行八张的片单；要分行只能按 `regionFeed(tid)` 一频道一条横排（`kVodRegionChannels` 的 15 个 id 现成），那是「首屏抓 N 份网络」的功能，仍单列一轮。 | 爱奇艺播放页的「视频详情」块把一部剧的正面铺成一行行字段：片名 + `第33集`、`年份：2026`、`时长：01:03`、`状态：40集全`、`更新状态：135集全`、`评分：8.8 分`、`上线时间：2026-9-18`、`类型：言情、古装、奇幻`、`排名：仙侠剧榜第1名`、点赞数/弹幕数/评论数、演职员（导演/主演）、剧情简介（iqiyi.com 繁花落尽时 v_149ytfvt5eg、逍遥 v_j481dre6rg、除恶 v_1xcpum2i3fg、蝉 v_cix2gal5d8 页面正文的「视频详情」段，2026-11 现读）；腾讯视频竖屏播放页 = 顶部播放器 + 详情（视频标题、选集、讨论、周边、推荐）+ 底部快捷操作区，点击唤出的信息浮层里「标题以较大字体显示在剧名下方，同时显示当前集数与总集数（如第12集/共40集），方便用户确认当前播放进度」「标题旁边常附带 4K/HDR/粤语 等标识」（zcool / ui.cn 深度拆解腾讯视频app细节设计 645580、k.sina 腾讯视频每集标题怎么显示 7879996025）；分集列表在详情页标题区下面，「下滑至分集区域即可看到完整分集标题」（k.sina 7879995960）。即：详情页第一层 = 海报 + 片名一次（较大字体）+ 当前集与总集 + 状态/评分/题材/年份 + 简介全文，选集在它下面；卡片角标给得起的信息在详情页单独丢掉，就是断层。 | `dart analyze apps/pure_live/lib` 0 issues；`dart analyze packages/live_vod lib test` 0 issues + `flutter test` 35 绿（含本轮新加的电影退路用例）；离线核对 `pgc/view/web/season` 两条真实答案（番剧 ss33415、电影 ss44658）的 `seasons[].new_ep.index_show`/`new_ep.desc`/`stat`/`rating`/`areas`/`styles` 路径与 `popular` 的 `tname` 分布（抓取件在仓外 `D:/vod_probe`，本轮自建、跑完即删）；`dart format --line-length 120` 重排到 `vod_widgets.dart` 两处无关旧行（`_CoverInk` 的两枚 chip 与它的 `copyWith`）与 `bilibili_vod_client.dart` 两处（`searchUsers`/`searchLiveRooms` 的返回）已逐 hunk 还原，本轮新增块为纯增量；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`feat(ui,vod)`） |
| 2026-11-02 07:56 | iptv | 节目单页（`pages/iptv_guide_page.dart`，菜单的 节目单 项）的选台器没有分组维度：它是一条**全库**列表加一枚名字搜索框，而一份真实播放列表是 100 个分组、几千个台——不打字就到不了任何一个台，上一轮频道页刚长出的分组列在这一页没有第二个实例（页面自己的文档还写着「webtv 把 分组/频道/节目 三栏并排放」，这里只有两栏）。本轮把频道页的四个内联件（`_GroupRail`/`_GroupEntry`/`_GroupPickerPanel`/`_GroupList`）提成 `views/iptv_group_rail.dart` 的 `IptvGroupsColumn`/`IptvGroupEntry`/`IptvGroupPickerPanel`/`IptvGroupList`：它们改读一个 `IptvGroupFilter` 记录（`groups`/`groupCounts`/`totalCount`/`selectedGroup`）与一个 `onSelect`，不再认识频道页的控制器，于是两处画的是同一批行、同一套台数与选中底（48 一行的模块量规、`DsListRow` + 末列 `iptvNumber` 计数、「全部」在第一行）。节目单页接上同一套：分组多于一个且窗宽 ≥1200 走三栏——分组列 200 + 选台器 280（它从 320 让出 40 给自己多出来的那一栏）+ 一天的节目；窄于此仍只占选台器搜索框上面的一行（一枚入口，当前分组名或 `分组`，≤260 省略号）点开 `DsPanel`，选中即过滤并收起。为什么比频道页的 960 更晚：频道页的表是 flex 的，这一页多付一根固定宽度的选台器，日子面板得留下自己的量。第二处是同一个数：选台器原先走 `library.orderedChannels`（隐藏的台也算在内），现在走 `library.zapSequence(group:)` ——频道页的表与遥控换台走的同一条可见序列，分组行末的那个数字因此就是它下面列出的行数，隐藏的台不再从这里被点开。同一原则推到的两处：选定分组后行内不再逐行重复分组名（`iptvGroupLabel` 只作跨分组浏览时的 description，与频道页 `showGroup` 同一个判据——把同一个组名印 60 遍是本仓连记三轮的病）；三种空分开说（搜索没中 `没有匹配的频道`、这个分组里没有台 `这个分组没有频道`、库是空的才是 `还没有频道` + 导入邀请），页头那行原先对三者一律写「导入 M3U/TXT 播放列表后…」（还把筛选后的台数在空列表时换成这句），现在只报台数、原因归有内容的两块面板。分组的选择由这一页自己拿着（`_group`），没有并进频道页控制器的 `selectedGroup`：那一份状态同时带着收藏范围与逐页揭示，都不是「读一天节目」要的东西，并过去会让两个页面互相改写对方的可见范围；换组时日子跟着走到新组里第一个台（`_selectGroup`），否则面板会顶着一个已经不在列表里的频道。重导入把所选分组抹掉时，`_groupFilterOf` 的 `open` 落回「全部」而不是留一张谁也解释不了的白页。`iptv_page.dart` 删掉那四个内联件与本模块页面里的 `_groupLabel`（`_groupOf` 现在转调 `iptvGroupLabel`，一个站对一个未分组只有一种写法），行为不变；`iptv.dart` 补 `export 'views/iptv_group_rail.dart'`。无新增 l10n（`groupsLabel`/`tabAll`/`zapperGroups`/`zapperEmptyGroup`/`noChannelMatch`/`channelCount`/`ungrouped` 都够），未跑 slang。 | 直播电视类的第一栏在**每一个**频道浏览面上都是分组，节目单面也不例外：mytv-android「安装完打开软件，界面非常简洁，左边是频道分组，右边是频道列表」，且「加载 EPG 之后，在频道列表上按上方向键，会弹出节目预告面板」——分组、频道、EPG 是同一套三件（csdn mytv-android 教程 166077418）；TVBox 主界面「出现如直播、央视、卫视、港澳台、电影、电视剧等分类…你会看到按央视、卫视、港澳台、地方台等分组的频道列表」（csdn 家庭电视直播系统搭建 163708394）；TiviMate「Only highlighted groups will now be visible on the left-side menu bar of the home screen」，遥控器上「Back Button: Shows Groups / Return to Guide」——从指南退回的是分组这一层（troypoint TiviMate 评测）；IPTV Smarters「Clicking on 'Live TV' will show a list of channel groups on the left and the channels within that group on the right」（note.com 免费 IPTV 播放列表全指南 5.3）；xTeVe 的 Group Title「配置完成后也可以在 APP 中看到分组信息，方便快速选择频道」（sina/知乎 xTeVe 直播源管理）；纯节目单类应用同样按类目浏览指南——SKY TV GUIDE「Browse the SKY guide in grid view or single channel view」、AusTV「Browse TV guide by channel or category」（App Store 430971650 / 1221253896）。即：分组是频道列表与指南共用的第一维度（宽窗竖排一栏、窄窗一个入口），一条全库列表加搜索框不是指南的选台器。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 重排到 `iptv_guide_page.dart` 一处无关旧行（`_takeHandoff` 的 `TextEditingValue`）已还原；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`feat(ui,iptv)`） |
| 2026-11-02 08:06 | music | 音乐库/搜索页（`pages/music_library_view.dart`，菜单的 音乐库，也是 `MusicPage` 不带参数时的默认视图）那张歌曲答案表没有头层：`N 首` 是一行 muted 小字，紧接着就是 `MusicSongTableHeader` 与编号行，页面说不出「这一份答案能整体做什么」，逐行点（`playAll(state.songs, index:)`）是唯一的通路。它是本模块最后一个还这样的歌单表面——`全部播放` 已在 在线歌单详情 675、自建歌单 819、专辑 154、歌手 229、收藏 127、本地 278、最近播放 234 与上一轮刚补的榜单 229 八处给齐，第七个列表少一层就是版式断裂而不是风格选择；同一页还把它拆成两处各写一遍（窄窗 <768 滚动追加态与宽窗 ≥768 数字翻页态各有一份 `Padding(s20) + Text(N 首)`）。本轮把那行小字折成 `resultsHead()`：左 `共 N 首`（`caption` + `textSubtle`、`maxLines: 1` 省略号）、右一个 `Wrap`（`spacing`/`runSpacing` = s8）装 `全部播放`(primary, `DsSize.sm` + play 16) 与 `随机播放`(secondary + shuffle 16)，与上一轮榜单头同一对动词、同一套 sm 几何，两个分支读同一个它。播放对象是 `state.songs`（已经在手的那一份）而不是编一个「全部结果」：点第 7 行本来就是把手里的答案当队列，头层只是把这队列从第一行起放，宽窗翻页态的计数与队列因此同一个数。`随机播放` 在只有一首时整枚收起（洗一首歌什么也不做，不摆失效开关，与本仓连记几轮的同一条判据），`全部播放` 不在加载/失败/无结果里画（那时 body 本来就不是这张表，不摆 disabled 死按钮）。无新增 l10n（`playAll`/`modeRandom`/`songsCount` 都已存在），未跑 slang。 | 搜索结果这一层要的是「一键把整份答案播起来」而不是逐行点：网易云音乐小程序重设计案例把这一处单独列为一条——「在现有网易云音乐的小程序中，是有单曲播放的引导图标，很好，但是如果我在搜索结果中想一键播放全部歌曲的场景，所以需要保留APP中的『播放全部』功能」（站酷/uisdc 音乐类小程序如何设计：网易云音乐的重设计案例实战 ZMTE0MzY4MA、huke88 4868）；用户的实际抱怨正是缺这一层带来的路径退化——「手机网易云音乐搜索一首歌后会出现很多首歌，但点击其中一首播放后只是放一首，怎么播放全部的搜索内容呢」，答案是先勾选再右键播放（百度贴吧 求教：搜索音乐，怎么全部播放 5351018122）；酷我 WEB 端再设计把「播放全部」当作歌曲列表块上的主按钮、位置放错就误触（站酷 酷我音乐WEB端再设计 ZNDg4OTIw）；QQ音乐/网易云的产品报告同层给「歌单详情页最突出的是全部播放按钮」（百家号 产品分析报告｜网易云音乐 1655037938574647235、sohu 365225120）。即：列表的第一层 = 这份答案的规模 + 整份答案的动词；一行计数加一张表是缺了一层。 | `dart analyze apps/pure_live/lib` 0 issues；`dart format --line-length 120` 本轮文件 0 改动；未构建、未截图，运行期观感待用户自测 | 本轮 HEAD（`feat(ui,music)`） |
