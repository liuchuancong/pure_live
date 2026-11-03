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

## 队列（一轮一项，从上往下）

- [ ] **N1 信息区密度**：`kHongguoSeriesCardInfoExtent` 82→56，标题 `maxLines` 2→1，内边距改 `fromLTRB(10, 4, 10, 8)`；`_FavoriteBookmark` 从标题行移进右上角（N3 前先留在行尾但不得撑高）；确认 `HongguoShelf`（`:994`）与 `PagedCardGrid`（`aspectRatio`/`listMainAxisExtent` `:690-705`、搜索 `:1737`）在新高度下不撑破、不错行。
- [ ] **N2 角标结构**：右上竖排 4 枚 → 横排一 Row（一枚状态 pill + 收藏按钮 28px ghost，样式抄 `room_card.dart:461-499`）；底部改 Row 两枚（左分类、右热度 `flame`+`numeric`/`playerInk`，抄 `:199-234`）；左上榜单旗标/来源标签收成 28 高、`0xB3000000`、圆角 8 的一枚（抄 `_PlatformMark` `:503-530`）。被挤掉的 `episodes`/`score` 由 `HongguoCardElement` 开关决定，默认关。
- [ ] **N3 卡片包壳**：新建 `modules/hongguo/widgets/hongguo_card_menu.dart`（`HongguoCardMenu`），按裁决 5 实现；首页 shelf、找剧墙、搜索、收藏/历史/预约、详情相关推荐全部包上；历史/预约页用 `items` 追加自己的移除项（对应直播 `✕`）。
- [ ] **N4 列表行同源**：`HongguoSeriesRow`、`HongguoRankRow`、`_SeriesList`、`_ProgressList` 与卡片共用同一套字段与措辞（`hongguoSeriesSubtitle`/`hongguoSeriesMetaLine` 不许再各写一遍），行高按 `kRoomCardListDesignHeight` 量规，密度与直播列表行一致。
- [ ] **N5 设置面同步**：按 N1–N3 的最终元素集合增删 `HongguoCardElement`（含新增 `favorite`、`category`），同步 `hongguo_settings_pane.dart:127-134` 的行名与图标、`interface.hongguoCard` 旧值兼容、`hongguo_*` l10n 串（`cd apps/pure_live && dart run slang`）；每枚开关在卡片上真生效，逐条自查「关掉后封面不空、不跳行」。
- [ ] **N6 窄屏与小窗**：对照关注页的窄窗版式——窄屏只留主 tabbar，排序/筛选/页内搜索进右上角 more（`SettingsPageActionScope` 交给 `DsPaneHeader.actions`）；卡片列数与 `kBrowseCardMinWidth`、`browseCardExtentForWidth` 的取值复核，保证 360/480/600/720 四档无溢出、无半字。
- [ ] **N7 主题与三档视觉复检**：浅色/深色/自定义主题下逐条比对 chip 底色、`playerInk`、`kRoomCoverScrim`、hover 阴影；播放器页（`hongguo_player_page.dart`）的选集条与浮层与卡片同一套圆角与字号；只在有证据时改。

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
