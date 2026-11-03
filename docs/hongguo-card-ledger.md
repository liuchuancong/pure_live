# 红果卡片对齐直播卡片（自动任务台账）

车道：`红果卡片对齐直播卡片`（本地 cron，每 20 分钟一轮）。
用户诉求原话：「现在的红果短剧 UI 不好看，帮我改成和直播一样的卡片一样」。
本文件是这条车道唯一的进度依据；每轮只推进队列最上面一项，做完勾掉并写运行记录。

## 参照物：直播房卡的量规（证据）

| 量规 | 值 | 出处 |
| --- | --- | --- |
| 封面比例 | 16:9（`kRoomCardCoverRatio = 16 / 9`） | `apps/pure_live/lib/features/settings/room/room_card_settings.dart:129` |
| 信息区高度 | 56（`kRoomCardInfoExtent`），`roomCardTileHeight(w) = w / (16/9) + 56` | 同上 `:133,138` |
| 信息区排版 | 头像 `DsAvatar(size: DsSize.md)` + 右侧两行：标题 1 行 `bodyStrong`、主播名 1 行 `caption/textMuted`；内边距 `fromLTRB(10, 4, 10, 8)` | `apps/pure_live/lib/modules/live/popular/room_card.dart:266-304` |
| 封面左上 | 平台徽标一枚：`DsBadge` 高 28、底 `0xB3000000`、圆角 8、`labelStrong`、图标 18 | `room_card.dart:503-530` |
| 封面右上 | 一行（不是竖排）：状态 pill + 28px 纯图标 ghost 按钮（红心 / ✕），`background 0x00000000`、`borderWidth 0`、`iconSize 14`、圆角 pill | `room_card.dart:185-198`、`461-499` |
| 封面底部 | 一行两枚：左=分类 chip（`Expanded` 靠左，最宽 0.55w），右=观众数 chip 带 `DsIcons.flame`、`numeric(caption)`、`playerInk`，两者之间 `s8` | `room_card.dart:199-234` |
| 蒙层 | `kRoomCoverScrim` 渐变盖满封面，`IgnorePointer` | `room_card.dart:171-175` |
| 右键/长按 | `RoomCardMenu` 包壳：`DsTooltip`（全名摘要）+ `DsContextMenuRegion`（打开/分享/复制链接/直链/关注/标签 + 页面自己的项） | `apps/pure_live/lib/modules/live/popular/room_card_menu.dart:23-100` |
| 显隐开关 | `RoomCardElement{title, audience, coverType, avatar, anchorName, platformBadge, status}`，键 `interface.roomCard`；版式写死，只做显隐 | `features/settings/room/room_card_settings.dart` |

## 现状：红果系列卡的量规（证据）

> 下表是开工前（N1 之前）的形态，保留作对照。N1 已把信息区收到 56、标题压成一行；N2 已把右上收成「一枚状态 pill + 收藏红心」的横排、底部改成「分类 + 热度」两枚、左上收成 28 高的一枚 `_CoverMark`，信息区末尾的书签也随之删除。N4 已把两条列表行（`HongguoSeriesRow`/`HongguoRankRow`）换成直播 `_ListRow` 的骨架与 88 量规，并把卡片、行、榜单行、头图与悬浮标签的措辞折进 `hongguoSeriesListingLine` 一枚函数——表里「信息区/右上/底部」各行讲的仍是卡片。末行那份元素集合也已是旧的：终态与每枚开关管到哪一面，看裁决 11。

| 项 | 现状 | 出处 |
| --- | --- | --- |
| 海报比例 | `kHongguoSeriesTileAspect = 0.62`（竖海报），封面 `3/4` 走 `Expanded` 吃掉剩余高度 | `modules/hongguo/widgets/hongguo_widgets.dart:32,169-181` |
| 信息区高度 | `kHongguoSeriesCardInfoExtent = 82`，标题 2 行 + 元信息 1 行，内边距 `fromLTRB(12, 6, 6, 8)` | 同上 `:27,251-285` |
| 封面左上 | 榜单旗标 `_RankFlag`，否则竖排最多 2 枚 `_CoverTag` | 同上 `:189-207` |
| 封面右上 | **竖排 4 枚**：续播位置 / 共 N 集 / 今日 / 评分，无任何动作按钮 | 同上 `:212-237` |
| 封面底部 | 只有左下角一枚热度 chip | 同上 `:238-247` |
| 头像 | 无 | — |
| 右键/长按 | 整个模块无 `DsContextMenuRegion`，卡片无悬浮全名提示 | `grep -r DsContextMenuRegion modules/hongguo` 为空 |
| 显隐开关 | `HongguoCardElement{rank, coverTags, episodes, today, score, hot, meta}`，键 `interface.hongguoCard`；设置面 7 行开关、无预览样张 | `modules/hongguo/controller/hongguo_card_settings.dart:8-30`、`modules/hongguo/pages/hongguo_settings_pane.dart:105-146` |

需要换成同一张卡片的消费者（`hongguo_page.dart` 除注明外）：首页三条 shelf `:424,466,504` · 找剧墙 `PagedCardGrid` `:690-705` · 搜索 `:1734-1749` · 榜单行 `HongguoRankRow` `:918` · 收藏/历史/预约 `_SeriesList`、`_ProgressList` `:1064,1076,1261,1270,1319,1817,1880,1902` · 详情相关推荐 `pages/hongguo_series_page.dart:432` · 下载页头图 `pages/hongguo_downloads_page.dart:1191-1195`。

## 设计裁决（先定，别每轮重新讨论）

1. **保留竖海报比例 0.62，不把封面裁成 16:9。** 短剧封面是为 3:4 画的竖海报，横裁会掉头和脚。用户要的是「和直播一样的卡片」= 同样的密度、角标结构、动作按钮与右键菜单，不是同一张裁切的图。若用户点名要 16:9，再改 `kHongguoSeriesTileAspect` 与 `PagedCardGrid.aspectRatio`，并在本节追加记录。
2. **信息区照直播收到 56，标题 1 行 + 元信息 1 行。** 直播卡靠「标题一行、副信息一行」拿掉高度；红果的元信息行已存在（`hongguoSeriesMetaLine`），只缺标题压成一行。
3. **右上改成一行，且必须带一枚动作按钮。** 竖排 4 枚 chip 是这张卡最像「不好看」的地方；直播的右上是一行「状态 + 纯图标按钮」。红果的状态只留一枚（优先级：续播位置 > 今日 > 评分 > 共 N 集），按钮用收藏红心（已收藏=红心、点了取消；未收藏=空角标，与直播「红心只表已关注」一致）。
4. **底部改成一行两枚**：左=分类（`Expanded` 靠左，最宽 0.55w），右=热度带 `flame` 与 `numeric/playerInk`，与直播 `:199-234` 同构。被顶部一行装不下的 `episodes`/`score` 归入这里或由设置开关关掉，不得再回到竖排。
5. **`HongguoCardMenu` 包壳，语义对齐 `RoomCardMenu`**：`DsTooltip`（标题全名 + 元信息）+ `DsContextMenuRegion`（打开 / 立即播放 / 收藏或取消 / 下载 / 复制详情页链接 / 页面自己的项在分割线后）。收藏走 `hongguoLibraryProvider`，链接走 `https://hongguoduanju.com/detail?series_id=`。
6. **不改直播模块**（`modules/live/**`）；需要复用件只往 `shared/` 里提，且必须直播侧同步改到不回归。
7. 封面仍是 HEIC + 签名 URL，一律走 `hongguoCoverImage`（`modules/hongguo/controller/hongguo_covers.dart:100`）；不得为了套直播卡片直接喂 `cachedImage(series.cover)`。
8. **N2 落地补充（2026-11-04）**：热度枚的 `maxWidth` 取 `width * 0.55`，不抄直播的 `0.3`——那一档是给纯观众数留的，红果的 `hot` 是「1.2万人在看」这类句子。收藏按裁决 3「未收藏=空角标」，信息区末尾的 `_FavoriteBookmark` 随之删除，所以 **N3 的 `HongguoCardMenu` 必须补上「收藏 / 取消收藏」**，否则卡片上没有收藏入口（只有取消）。新增 `HongguoCardElement.category`（封面底部左枚，设置面已给一行开关），并把 `episodes`/`score` 写进 `HongguoCardVisibility.standard` 的默认隐藏集。
9. **N3 落地补充（2026-11-04）**：
   - 裁决 5 的「下载」按下载队列自己的粒度落实：卡片没有剧集表，所以菜单先读 `hongguoClientProvider.detail()`，取本机断点那一集（没有断点取第一集）交给 `hongguoDownloadsProvider.notifier.download(...)`，三种结果沿用播放页的现成串（`downloadQueued`/`downloadDuplicate`/`downloadFailed`）。不新增下载 API，也不动 `controller/hongguo_downloads*.dart`（那是下载面车道）。
   - 菜单的动词只在「这一行真能打开」时出现：`onOpen == null` 或 `hongguoSeriesOpenable(series)` 为假（预约、未开播的相关作品、管理历史时的勾选行）时只保留悬浮全名，不挂 `DsContextMenuRegion`，也不订阅 `hongguoLibraryProvider`——没有打不开的门。
   - 「立即播放 / 继续观看」的档位与卡片角标、head 的动词读同一个 `hongguoResumeSeconds`，收藏走 `hongguoLibraryProvider`，链接走 `https://hongguoduanju.com/detail?series_id=`（`kHongguoSite`，与播放页的分享同源）。
10. **N4 落地补充（2026-11-04）**：
    - 两条措辞函数（`hongguoSeriesSubtitle`、`hongguoSeriesMetaLine`）折成 `hongguoSeriesListingLine(t, series, {withEpisodeCount, watched, withFigure, withCategory, note})` 一枚：卡片传 `withEpisodeCount: false` 并关掉封面已带的两枚，行传默认全量，榜单行传 `withFigure: false`（热度在标题行右端），悬浮标签与首页头传默认。旧名全部消失；`totalInHot` 这类反语义的开关也不留——它问的其实是「要不要说集数」，改名 `withEpisodeCount`（默认 true）。
    - 行的骨架抄 `room_card.dart` 的 `_ListRow`：`DsCard(padding: EdgeInsets.zero)` + `Align(centerStart)` + `Padding(s16/s8)`，标题 1 行 `bodyStrong`，海报 54×72（`kHongguoSeriesRowPosterHeight = kRoomCardListDesignHeight - 2*s8`）。72+16 正好 88，所以 `ListView.separated` 里自量的行和网格里 `listMainAxisExtent` 给定的行是同一个高度，不必在每个页面重写数字。
    - 行保留第三行 = `series.intro` 压成 1 行，对应直播行给关注标签留的那一行（`_ListRow` 的 `tags`）：量规允许行比卡片多读一行，卡片固定高度装不下。删掉会让搜索与找剧的列表行分不清同名剧，属删元素，不做。
    - `_ProgressList` 不再拿 `hot` 当句子载体（原先自拼「12集/80集 · 1:02:03」），改把真实的 `HongguoWatchProgress` 传 `watched:`、时钟传 `note:`，进度措辞与卡片/行同源。副作用：`hongguo.historyEpisodeProgress` 这条 l10n 串当前无代码读者（`episodeLabel` 仍在用）；本轮不动 l10n（避免 slang 重排他人 lane 的生成物），N5/N7 若仍未复用可清掉。
    - 卡片信息行随统一而变一处：`hot` 空而 `playCount>0` 时写「播放 1.2万」，不再只写数字，与行、悬浮标签一致。
11. **N5 落地补充（2026-11-04）：开关与渲染面的对应关系**。元素集合按 N1–N3 的终态定名为 `rank, coverTags, today, score, episodes, favorite, hot, category, meta`（`favorite` 新增；`episodes` 移到 `score` 之后，与状态 pill 的实际优先级 续播>今日>评分>集数 同序；`category` 是 N2 已加的）。设置面按 `HongguoCardElement.values` 迭代，行名与图标走 `_elementLabel`/`_elementIcon` 两枚穷尽 switch——新增元素没有对应行就编译不过，杜绝「卡片上有、设置里没有」。
    - 两类开关语义不同，且都以卡片现有实现为准，不另立规则：`rank`/`coverTags`/`today`/`score`/`episodes`/`favorite` 是「这块内容画不画」；`hot`/`category` 是「这句说在封面上还是说在信息行里」（关掉后 `withFigure: !showsHot`/`withCategory: !showsCategory` 把它接进信息行，句子不丢）。串名也这么写：`封面热度`/`封面分类`。
    - 行（`HongguoSeriesRow`/`HongguoRankRow`）读同一份 `meta`：同一 feed 在 `PagedCardGrid` 的版式开关下是「卡片或它的行」，`信息行` 关掉两边同时收。封面角标的开关不给行——行没有封面，那些内容本来折进信息行。榜单行的名次/标签/评分是榜单页自己的正文，不是封面角标，同理不受封面开关管。
    - `HongguoFeedHero`（首页头条）与 `hongguoCardMenu` 的悬浮全名不受这批开关管：前者是页级头部、自己成段说数字与简介，后者是详情而非版式元素。
    - `interface.hongguoCard` 无需迁移：元素名从 `cbca5482f` 起一次没改过，存储的是 `hidden` 名单，缺名即显示、未知名跳过，所以旧值保留自己记过的选择、只把新元素交给设计默认（`favorite` 默认开）。`fromJson` 的文档写了这条契约。
    - 本轮修掉一处开关失效：`showsTag` 原先用裸 `rank == null` 判「角标位空着」，关掉 `rank` 后来源标签并不会顶上；改成 `!showsRank`。另把右上那 Row 用 `stateText != null || favored` 兜住，两样都关时不再摆一个空盒。
    - 遗留（未做，等非点名不开工）：设置面没有直播那样的预览样张（`RoomCardPreviewPage` 的对等物），逐枚开关要回红果首页看；`HongguoCardSettingsController.reset()` 至今无读者，直播那侧的还原按钮长在预览页的标题栏上。
12. **N6 落地补充（2026-11-04）：海报走自己的列档，窄封面只留一枚说法**。
    - 直播的卡档（`kBrowseCardMaxWidth` 340 / `kBrowseCardMinWidth` 220）是给 16:9 封面定的：340 宽只要 191 高。红果的 0.62 瓦片在 340 宽要 548 高，所以套用直播档的结果是「一屏一张海报」——`browseCardExtentForWidth(320)` 给 1 列，首页每条 shelf 也 `take(1)`，手机上整页只剩三张竖图。这既是「不好看」的直接来源，也是 N6 要复核的那件事，故海报改走本模块自己的两枚常数：`kHongguoPosterCardWidth = 176`（对齐分区目录的 170 海报档）与 `kHongguoPosterMinWidth = 140`，列数由 `hongguoPosterColumns` 一枚函数给（ceil 后按 min 退一列，`ceiling` 仍是用户的每行列数）。四档复核（窗宽减 `feedGutter` 的水平边距）：360→2 列×156、480→2 列×216、600→3 列×176、720→4 列×158，不再有半屏高的卡。首页三条 shelf、找剧墙、搜索墙同一个来源；两面墙另包一层 `LayoutBuilder` 把 `cardExtent` 递进去（直播那面靠 `browseCardExtentForWidth` 自查宽度，竖海报必须自己报宽，否则用户设的列数上限会被 `CardGrid` 用 220 的最小档驳回）。
    - 间距与边距接到设置：两面墙补 `crossSpacing`/`mainSpacing` 读 `browseSettingsProvider`（原先吃 `CardGrid` 的 16 默认值，用户的间距设置在红果不生效）；可用宽由 `feedGutter(context).horizontal` 反推，不再自拼 20——`59791db59`/`9cffba7d1` 之后卡网的默认边距就是窗口档，页面再写死一个数会和 16 的页头错开。
    - 窄封面（瓦片 < `kHongguoCoverChipFloor` = 190）不再同时挂两枚说法：续播状态与分类折进信息行（`watched:`/`withCategory:` 走裁决 11 那条「说在封面上还是说在信息行里」的同一机制，句子不丢、开关不落空），封面留名次/来源徽标与热度；右上的状态 pill 由 `0.6w` 收到 `0.5w`，因为徽标、pill 与 28px 红心在 140 宽的角上会互相压字。今日/评分这类短标记仍留在角上——它们本来就是几个字。
    - 三条 shelf 条（首页片种、找剧片种、榜单榜种）按 `LiveWindow.stacksToolbar` 派发：窄屏只留 tab 条 + `HongguoToolbarMore`（`DsMenuAnchor` + 一枚 ghost ellipsis，抄 `PlatformToolbarMore`/`VodFeedToolbar` 的窄臂），榜单另留一枚图标态刷新（`popular_page.dart:198-213` 的形状：条上留 tab 与刷新，其余进 more）。没有可折的动作时不挂 more 按钮（首页「推荐」片种没有条件可设⇒只有 tab）。搜索页的输入框本就占自己一行，不动；收藏/历史/预约的 `DsSegmentedControl` 与 chips 走 `Wrap`，窄屏自己会换行。

13. **N7 落地补充（2026-11-04）：三档视觉复检的逐条结论**。
    - 唯一有证据的偏离是卡片的 hover。直播 `RoomCard` 只交 `DsCardStyle(padding: EdgeInsets.zero)`，hover 由 `DsCard.defaultStyle` 给：`hovered: DsCardStyle(shadows: theme.shadows.surfaceRaised)`（`desen_ui-0.3.3/lib/src/components/card/card.dart:69`）——不填色，只按主题的抬升档抬起。红果的卡片与首页头图原先自绘 `hovered: background: colors.hover` 加 `DsShadow(color: colors.overlay, blur: s24, offset: (0, s8))`：`overlay` 是浮层的**表面色**，两档都不透明（浅色 `white()`、深色 `oN(.335, n)`，`palette.dart:818`、`:1045`），当阴影色用就是在卡片四周糊一圈实心色而不是抬升；`colors.hover` 又只染得到封面底下那 56 高的信息带，海报不动，看着像块灰斑。两处自绘 hover 一并删掉（`hongguo_widgets.dart:230`、`:453`），与直播同一个默认档。未提公共件，直播侧零改动。
    - 逐条核对为同源、不动的：
      - 封面的两枚与右上的状态枚走公共件 `RoomCoverChip`（底 `0x8C000000`、字白），与直播 `_StatePill` 同底色（`room_card.dart:552`）；左上 `_CoverMark` 的 `0xB3000000` / `playerInk` / 圆角 8 与 `_PlatformMark` 逐值相同（`room_card.dart:519,521`）。
      - `kRoomCoverScrim` 两边用的是 `shared/grids/room_cover_chip.dart:59` 同一枚常数，浅色主题下也不变——设计如此，白色 chip 要压住亮封面。
      - `playerInk` 的用法：卡片红心是 `colors.danger.fill`（同直播 `_FollowButton`），封面文字与热度走 `playerInk`；播放器浮层全部 `playerInk*`，与直播播放器一致。
      - 播放器页：图下选集条是 `DsChip` + `theme.sizes`/`title`/`caption`；全屏选集面板走公共的 `PlayerOverlayPanel`（圆角 `theme.radii.card`、底 `0xF2131519`、`caption`），与卡片的圆角档、字号档同源；面板里编号块 `theme.radii.controlCorners(null, sizes.xs)` + `numeric(caption)`，在播那枚的字色 `0xFF131519` 正是面板底色去掉 alpha 的值，不算硬编码偏离。
      - `_panelPill` 的 hover 用 `0x14FFFFFF` 而非 `playerInkHover`（`0x24FFFFFF`），与同面板的编号块和 `PlayerPanelOption` 不同档，这是**故意**的：枚的选中态本身就是 `playerInkHover`，hover 再上到 `0x24`，未选的枚一碰就和已选的同一个色；编号块敢用 `0x24` 是因为它的「在播」档是不透明白。不改。
      - 自定义主题（用户改 accent）下会跟着走的：`_CoverMark` 前三名的 `colors.accent`/`onAccent`、榜单行名次与热度的 `colors.accentText`、进度条 `colors.accent`、标签的 `DsBadge(status: DsStatus.info)`——都是 token，不动。

## 队列（一轮一项，从上往下）

> N1–N7 已全部落地，队列到此为空。下面两条是裁决 11 早就记下的遗留，不是本轮新造的需求，等用户点名才开工。

- [x] **N1 信息区密度**：`kHongguoSeriesCardInfoExtent` 82→56（直接取 `kRoomCardInfoExtent`），标题 `maxLines` 2→1 且用 `bodyStrong`，内边距 `fromLTRB(10, 4, 10, 8)`，信息区结构与直播 `_GridInfo` 同构（Row[Expanded(Column 居中：标题+元信息)]，书签在行末）；`_FavoriteBookmark` 30→28、图标 16→14，不再撑高。`HongguoShelf`（`:994`）与 `PagedCardGrid`（`:693`、`:1737`）的瓦片高都由 `kHongguoSeriesTileAspect` 决定，信息区变矮 26 全部还给封面，不会撑破或错行。
- [x] **N2 角标结构**：右上竖排 4 枚 → 横排一 Row（一枚状态 pill + 收藏按钮 28px ghost，样式抄 `room_card.dart:461-499`）；底部改 Row 两枚（左分类、右热度 `flame`+`numeric`/`playerInk`，抄 `:199-234`）；左上榜单旗标/来源标签收成 28 高、`0xB3000000`、圆角 8 的一枚（抄 `_PlatformMark` `:503-530`）。被挤掉的 `episodes`/`score` 由 `HongguoCardElement` 开关决定，默认关。
- [x] **N3 卡片包壳**：新建 `modules/hongguo/widgets/hongguo_card_menu.dart`（`HongguoCardMenu`），按裁决 5 实现；首页 shelf、找剧墙、搜索、收藏/历史/预约、详情相关推荐全部包上；历史/预约页用 `items` 追加自己的移除项（对应直播 `✕`）。（2026-11-04 落地：11 个消费点全部包上——三条 shelf 的 `cardBuilder`、找剧墙与搜索的 `itemBuilder`/`listItemBuilder`、榜单行、`_SeriesList`、`_ProgressList`（追加移除项）、相关推荐行；相关推荐的行折成 `_RelatedSectionState._relatedWork`，预约的 `openable` 改用 `hongguoSeriesOpenable`。新增 l10n `hongguo.cardOpenSeries`/`cardCopyLink`/`cardNoEpisodes`。）
- [x] **N4 列表行同源**：`HongguoSeriesRow`、`HongguoRankRow`、`_SeriesList`、`_ProgressList` 与卡片共用同一套字段与措辞（`hongguoSeriesSubtitle`/`hongguoSeriesMetaLine` 不许再各写一遍），行高按 `kRoomCardListDesignHeight` 量规，密度与直播列表行一致。（2026-11-04 落地：两条函数折成 `hongguoSeriesListingLine` 一枚，卡片/行/榜单行/首页头/悬浮标签同一来源；`HongguoSeriesRow` 换成 `_ListRow` 的骨架（`EdgeInsets.zero` + `Align` + `s16/s8`、标题 1 行 `bodyStrong`、海报 `kHongguoSeriesRowPosterHeight`）；`HongguoRankRow` 同骨架同三行；`_ProgressList` 不再把句子塞进 `hot`，改传 `watched:` + `note:`；两处 `listMainAxisExtent: 124` → `kHongguoSeriesRowExtent`。详见裁决 10。）
- [x] **N5 设置面同步**：按 N1–N3 的最终元素集合增删 `HongguoCardElement`（含新增 `favorite`、`category`），同步 `hongguo_settings_pane.dart:127-134` 的行名与图标、`interface.hongguoCard` 旧值兼容、`hongguo_*` l10n 串（`cd apps/pure_live && dart run slang`）；每枚开关在卡片上真生效，逐条自查「关掉后封面不空、不跳行」。（2026-11-04 落地：新增 `favorite`、`episodes` 归位到状态优先级、设置面改 `HongguoCardElement.values` 迭代 + 两枚穷尽 switch、卡片角分两段并用现成的 `settings.hongguoCardVisibleContent` 作段头；`hongguoCardMeta` 的中文串从「列表信息」改「信息行」、新增 `hongguoCardFavorite`；`showsTag` 的失效判据与空 Row 一并修；`meta` 接到两条行。逐条自查与边界记在裁决 11。）
- [x] **N6 窄屏与小窗**：对照关注页的窄窗版式——窄屏只留主 tabbar，排序/筛选/页内搜索进右上角 more（`SettingsPageActionScope` 交给 `DsPaneHeader.actions`）；卡片列数与 `kBrowseCardMinWidth`、`browseCardExtentForWidth` 的取值复核，保证 360/480/600/720 四档无溢出、无半字。（2026-11-04 落地：三条 shelf 条（首页片种、找剧片种、榜单榜种）在 `LiveWindow.stacksToolbar` 以下只留 tab 条，筛选收进 `HongguoToolbarMore` 的右上角 more，榜单另留一枚图标态刷新——抄 `popular_page.dart:198-213` 与 `favorites_page.dart:402-429`，搜索页的输入框本就在自己一行、不动。列数见裁决 12：海报改走本模块自己的 176/140 档，首页三条 shelf、找剧墙、搜索墙同一来源，`interface.gridColumns` 与 `browse.crossSpacing/mainSpacing` 一并接到两面。未做运行时验收。）
- [x] **N7 主题与三档视觉复检**：浅色/深色/自定义主题下逐条比对 chip 底色、`playerInk`、`kRoomCoverScrim`、hover 阴影；播放器页（`hongguo_player_page.dart`）的选集条与浮层与卡片同一套圆角与字号；只在有证据时改。（2026-11-04 落地：逐条比对记在裁决 13。改一处有证据的偏离——卡片与首页头图自绘的 hover（`colors.hover` 填充 + `colors.overlay` 的阴影）删掉，回到 `DsCard` 默认的 `theme.shadows.surfaceRaised`，与直播房卡同形；其余各条核对为同源，不动。）

- [ ] **（待用户点名）N8 卡片预览样张**：设置面没有直播 `RoomCardPreviewPage` 的对等物，逐枚开关要回红果首页看（裁决 11 的遗留）。开工前先查入口：直播的预览页挂在 `features/settings/**` 的导航上，那是本车道的禁区——若红果的预览页也要走那条导航，先请用户裁决入口放哪。
- [ ] **（待用户点名）N9 还原到设计默认**：`HongguoCardSettingsController.reset()` 至今无读者；直播那侧的还原按钮长在预览页的标题栏上。与 N8 同一条入口问题，可并成一项做。

## 车道分工边界（2026-11-04 用户裁决：红果的版式面归本车道）

下载面车道 `9a2623b2` 已把红果的版式面摘掉，它在红果只剩两处，本车道**不得改**：
- `pages/hongguo_downloads_page.dart` 与 `controller/hongguo_downloads*.dart`（它的台账 `docs/downloads-ui-ledger.md`）；本文档上文「需要换成同一张卡片的消费者」里的下载页头图一项因此划到边界外，不做。
- 取流/解析层（`controller/**` 除 `hongguo_card_settings.dart`、`official/**`）——「红果短剧无法播放视频」由它修，本车道遇到播放问题只记录不修。

反过来说，`widgets/**`、`pages/hongguo_page.dart`、`pages/hongguo_settings_pane.dart`、`pages/hongguo_series_page.dart`、`pages/hongguo_player_page.dart`、`controller/hongguo_card_settings.dart` 与 `l10n/messages/hongguo/**` 的版式改动都归本车道独占。

## 每轮不变式

1. 开工先读本文档取队列最上面未勾项，并 `git status` 只看不动。
2. 让位规则：`apps/pure_live/lib/modules/hongguo/**` 或本文档里有非本轮产生的未提交/未跟踪改动（并行 lane 正在写；下载面车道 `9a2623b2` 常在此目录），本轮**不改代码**，只在回复里报告被谁占；下一轮再来。
3. 允许改的路径：`apps/pure_live/lib/modules/hongguo/**`、`apps/pure_live/lib/l10n/messages/hongguo/**` 与 `messages/settings/**`（新串）、`shared/**`（仅当把直播卡片件提为公共件且直播侧同步）、本文档。禁止：`modules/live/**` 的页面与设置导航、`features/settings/**` 的导航结构、`tool/`、`scripts/`、`pubspec.yaml`、`pubspec.lock`、`apps/pure_live/{ios,macos,windows}` 的插件注册文件、`modules/music/**`。
4. 组件只用 desen_ui（`DsCard/DsBadge/DsImage/DsAvatar/DsButton/DsTooltip/DsContextMenuRegion/DsListRow/DsPanel`），缺件用 `style` 覆盖，不造新组件；版式写死、每个元素一枚显隐开关，不做预设包。
5. 收尾顺序：改到 l10n 跑 `dart run slang` → `dart format --line-length 120 <本轮路径>`（格式器重排到无关旧行逐 hunk 还原）→ `dart analyze apps/pure_live/lib` 必须 0 issues。不构建、不起 app、不截图、不建临时测试目录；运行期观感由用户自测。
6. 提交：`git add -- <本轮路径>`（新文件必须先 add，pathspec commit 不带未跟踪文件）→ `git commit -- <本轮路径>`，提交信息**英文**主题与正文，`feat(hongguo)/polish(hongguo)/fix(hongguo)` 前缀，一行祈使句说清哪个页面改成什么样 → `git log --oneline -1` 复核主题没贴错 → `git push origin v2`（报 SSL/reset 原样重试 2–3 次，仍失败就报告未推送）。每轮最多一个提交；没改动不提交。
7. 回填台账：勾掉该项，运行记录追加一行（动了哪些文件、analyze 结果、提交号、下一项是什么、被占用而空转的轮次要单独记一行）。
8. 连续 3 轮空转（被占位或拿不出证据）就在本文档标注停手原因并在回复里请用户裁决，不要为了改而改。

## 运行记录

| 轮次 | 项 | 动作 | analyze | 提交 | 备注 |
| --- | --- | --- | --- | --- | --- |
| — | — | — | — | — | 台账建立，队列为空转起点 |
| 1 | N1 | `hongguo_widgets.dart`：信息区 82→56（取 `kRoomCardInfoExtent`）、标题 1 行 `bodyStrong`、内边距 `fromLTRB(10,4,10,8)`、行末书签 30→28/图标 14 | `dart analyze apps/pure_live/lib` 0 issues | 本轮单个提交（`polish(hongguo)` 代码+本台账；hash 见 `git log -1`） | 封面比例 0.62 未动；`PagedCardGrid`/`HongguoShelf` 的瓦片高与封面高复核通过（高度来自 aspect，不来自信息区）。未做运行时验收，观感由用户自测。下一项 N2 角标结构。 |
| 2 | N2 | `widgets/hongguo_widgets.dart`：右上竖排 4 枚 → 一 Row（状态 pill 按 续播>今日>评分>集数 只出一枚 + 28px ghost 红心，抄 `_CornerButton`）；底部 → Row 两枚（左分类 `Expanded`/`0.55w`，右热度 `flame`+`numeric`/`playerInk`，`0.55w`）；左上 `_RankFlag`/`_CoverTag` 合成一枚 28 高 `0xB3000000`/圆角 8 的 `_CoverMark`（前 3 名保留 accent 底）；`_FavoriteBookmark` 删除，卡片包上 `LayoutBuilder` 取宽；`hongguoSeriesMetaLine` 增 `withCategory`，分类/热度上封面后信息行不再重复。`controller/hongguo_card_settings.dart`：新增 `category`，`standard` 默认隐藏 `episodes`/`score`。`pages/hongguo_settings_pane.dart`：加一行分类开关（`DsIcons.tag`，`coverTags` 图标改 `badge`）。l10n `settings/{zh-CN,en}` 加 `hongguoCardCategory` + `dart run slang` | `dart analyze apps/pure_live/lib` 0 issues | 本轮单个提交（`polish(hongguo)`；hash 见 `git log -1`） | 封面比例 0.62 未动；未构建、未起 app、未截图——观感由用户自测。已知缺口：卡片上只能取消收藏，加收藏要等 N3 的右键菜单（见裁决 8）。下一项 N3 卡片包壳。 |
| 3 | N3 | 新建 `widgets/hongguo_card_menu.dart`（`HongguoCardMenu` = `DsTooltip` 全名 + `DsContextMenuRegion`：打开剧集页 / 播放或继续观看 / 收藏或取消 / 下载 / 复制详情页链接，页面自己的项在分割线后；`hongguoSeriesOpenable` 同源判据）。包上 11 个消费点：`pages/hongguo_page.dart` 三条 shelf 的 `cardBuilder`、找剧墙与搜索的 `itemBuilder`+`listItemBuilder`、榜单行、`_SeriesList`、`_ProgressList`（追加 `trash2` 移除项，管理态不给菜单）、`pages/hongguo_series_page.dart` 相关推荐（行折成 `_relatedWork`）；预约的 `openable` 改用 `hongguoSeriesOpenable`。`hongguo.dart` barrel 加一行导出。l10n `hongguo/{zh-CN,en}` 加 `cardOpenSeries`/`cardCopyLink`/`cardNoEpisodes` + `dart run slang` | `dart analyze apps/pure_live/lib` 0 issues | 本轮单个提交（`feat(hongguo)`；hash 见 `git log -1`） | 裁决 9 记录了「下载」的粒度与「打不开就不挂菜单」两条落地裁决。未构建、未起 app、未截图——右键菜单的真机手感与悬浮标签由用户自测。下一项 N4 列表行同源。 |
| 4 | N4 | `widgets/hongguo_widgets.dart`：`hongguoSeriesSubtitle` + `hongguoSeriesMetaLine` 合并为 `hongguoSeriesListingLine`（`withEpisodeCount`/`withFigure`/`withCategory`/`note`），新增 `kHongguoSeriesRowExtent`(=`kRoomCardListDesignHeight`)、`kHongguoSeriesRowPosterHeight` 与 `_RowPoster`；`HongguoSeriesRow` 与 `HongguoRankRow` 换成直播 `_ListRow` 骨架（`EdgeInsets.zero`+`Align`+`s16/s8`，标题 1 行 `bodyStrong`，榜单行的热度用 `_RankFigure(color:)` 走 accent，收藏/点赞/标签/评分/今日折进一行 marks，去掉自拼的 `[category, allEpisodesCount]` 与 `hovered` 覆写）。`widgets/hongguo_card_menu.dart` 跟改名。`pages/hongguo_page.dart`：两处 `listMainAxisExtent: 124`→`kHongguoSeriesRowExtent`，`_SeriesList.totalInHot`→`withEpisodeCount`（默认改为 true，本地收藏那处显式 false），`_ProgressList` 去掉塞进 `hot` 的自拼句子、改传 `watched: row` + `note: _clock(...)` | `dart analyze apps/pure_live/lib` 0 issues（`dart format --line-length 120` 只重排本轮 3 个文件） | 本轮单个提交（`polish(hongguo)`；hash 见 `git log -1`） | 未动 l10n（复用现成串），未构建、未起 app、未截图——行的实际密度与文字截断由用户自测。遗留：`hongguo.historyEpisodeProgress` 当前无读者（裁决 10）。下一项 N5 设置面同步。 |
| 5 | N5 | `controller/hongguo_card_settings.dart`：新增 `favorite`、把 `episodes` 移到 `score` 之后（与状态 pill 的优先级同序）、`fromJson` 写明旧值契约（元素名从未改过⇒缺名即显示、未知名跳过，无需迁移）。`widgets/hongguo_widgets.dart`：`showsTag` 从裸 `rank == null` 改成 `!showsRank`（关掉榜单排名后来源标签才真顶得上）、`favored` 受 `favorite` 管、右上的 Row 用 `stateText != null || favored` 兜住不再摆空盒、`HongguoSeriesRow`/`HongguoRankRow` 换 `ConsumerWidget` 让 `meta` 关掉时卡片与行同时收行。`pages/hongguo_settings_pane.dart`：元组清单换成 `HongguoCardElement.values` 迭代 + `_elementIcon`/`_elementLabel` 两枚穷尽 switch，卡片元素自立一段并用现成却一直无读者的 `settings.hongguoCardVisibleContent` 作段头（页级头图开关留在上一段），`episodes` 图标 `listMusic`→`listVideo`、新增 `favorite`→`heart`，开关补 `semanticLabel`。l10n `settings/{zh-CN,en}`：加 `hongguoCardFavorite`、`hongguoCardMeta` 中文「列表信息」→「信息行」+ `dart run slang` | `dart analyze apps/pure_live/lib` 0 issues（`dart format --line-length 120` 只重排本轮 3 个 dart 文件） | 本轮单个提交（`polish(hongguo)`；hash 见 `git log -1`） | slang 把 `vod.followingEmptyDescription` 在两张 `rawString` 表之间挪了一个 hunk（纯生成物重排，文案未变），不是手改。未构建、未起 app、未截图——逐枚开关的观感由用户自测。遗留见裁决 11（无预览样张、`reset()` 无读者）。下一项 N6 窄屏与小窗。 |
| 6 | N6 | `widgets/hongguo_widgets.dart`：新增 `kHongguoPosterCardWidth`(176)/`kHongguoPosterMinWidth`(140)/`kHongguoCoverChipFloor`(190) 与 `hongguoPosterColumns`/`hongguoPosterExtentForWidth`（海报不再吃直播的 340/220 档——手机上「一条 shelf 一张竖图」就是这么来的）；`HongguoShelf` 的列数改走新函数；新增 `HongguoToolbarMore`（`DsMenuAnchor` + ghost ellipsis）；卡片把宽度读进自己的 `LayoutBuilder`，窄封面（<190）把续播状态与分类折进信息行、状态 pill 由 `0.6w` 收到 `0.5w`。`pages/hongguo_page.dart`：首页/找剧/榜单三条 shelf 条按 `LiveWindow.stacksToolbar` 派发窄臂（窄屏只留 tab + more，榜单另留图标态刷新；首页「推荐」无可折项⇒不挂空按钮）；找剧墙与搜索墙各包一层 `LayoutBuilder` 报 `cardExtent`、补 `crossSpacing`/`mainSpacing`、水平边距改由 `feedGutter` 反推 | `dart analyze apps/pure_live/lib` 0 issues（`dart format --line-length 120` 只重排本轮 2 个 dart 文件） | 本轮单个提交（`polish(hongguo)`；hash 见 `git log -1`） | 未动 l10n（`common.more`/`hongguo.filter`/`hongguo.refresh` 都是现成串），未构建、未起 app、未截图——360/480/600/720 四档的实际观感、more 菜单手感与窄封面折句由用户自测。裁决 12 记了列档取数、接设置的两处与折句规则。下一项 N7 主题与三档视觉复检。 |
| 7 | N7 | `widgets/hongguo_widgets.dart`：删掉 `HongguoSeriesCard`（`:230`）与 `HongguoFeedHero`（`:453`）自绘的 `hovered: DsCardStyle`（`colors.hover` 填充 + `DsShadow(color: colors.overlay, blur: s24, offset: (0, s8))`），改回 `const DsCardStyle(padding: EdgeInsets.zero)`，hover 由 `DsCard.defaultStyle` 给 `theme.shadows.surfaceRaised`——与直播 `RoomCard` 同一个档。逐条复检的结论与「核到但不动」的几处（含 `_panelPill` 的 `0x14FFFFFF` 为何不并到 `playerInkHover`）写在裁决 13 | `dart analyze apps/pure_live/lib` 0 issues（`dart format --line-length 120` 对 `hongguo_widgets.dart` 零重排） | 本轮单个提交（`polish(hongguo)`；hash 见 `git log -1`） | 未动 l10n、未提公共件、直播侧零改动；未构建、未起 app、未截图——浅色/深色/自定义主题下的 hover 观感由用户自测。队列已空（N1–N7 全部落地），剩 N8/N9 两条待用户点名。 |
| 8 | — | 空转：队列 N1–N7 已全部勾掉，`git status` 里 `modules/hongguo/**` 与本台账干净（占用者是 `music/**`、`pubspec*`、三端插件注册文件，都不在本车道路径内）。本轮未改任何代码 | — | — | 第 1 次空转。剩两项都要用户点名才开工，且共用同一个卡点：N8 的入口若走 `features/settings/**` 的导航，那是本车道禁区。请用户裁决：(a) 预览样张 + 还原按钮放哪（红果设置页内的子页 / 复用直播预览页的导航位 / 不做）；(b) 是否要 16:9 封面（裁决 1 目前是钉死 0.62）。下一轮若仍无名点，继续空转并计数。 |
