# lx-music 功能同步台账（music module）

对照 lx-music-desktop 与 lx-music-mobile 的全量功能清单，逐条判定 v2 音乐模块的引入状态。
本台账是自动任务（每 30 分钟一轮）的工作清单：每轮取最靠前的 🟡/⬜ 项移植，收尾后把状态改 ✅ 并附提交哈希。

## 判定基线

- 参考实现：`E:\study\lx-music-desktop-master\lx-music-desktop-master`（桌面端）、`E:\study\lx-music-mobile-master\lx-music-mobile-master`（移动端）。只抄行为与数据语义；UI 一律用 desen_ui 组件重画，布局对齐本仓直播模块的分类布局（44px 工具行 + DsTopNav + CardGrid，参考 `apps/pure_live/lib/modules/live/popular/` 与 `areas/`）。
- v2 落点：`apps/pure_live/lib/modules/music/`（page=music_page.dart，player=pages/music_player_page.dart，settings=pages/music_settings_pane.dart，controllers=controller/）。
- 应用级能力（主题/语言/更新/备份框架/媒体会话/音频焦点）由 app 层承担，不重复计缺口。
- 状态：✅ 已引入；🟡 部分引入（写明缺什么）；⬜ 未引入。

## A. 导航与页面骨架

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 搜索/歌单/排行榜/我的列表 四主导航 + 设置 | `app/navigation/module_navigation.dart` music 菜单 | ✅ |
| 底部迷你播放栏（封面/标题/进度/上下曲） | `music_page.dart` `_MiniPlayer`（进度条可点拖 seek） | ✅ |
| 播放详情页（封面↔歌词，宽窄双布局） | `pages/music_player_page.dart` `_Stage`+`_SidePanel` | ✅ |
| 我的列表侧栏（试听/收藏/自建列表切换） | 歌单页 `_PlaylistsView`（自建列表）+ 我的页（收藏/最近） | ✅ 语义等价 |
| 在线歌单详情页 | `_OnlinePlaylistDetail`（播放/导入/逐曲菜单） | ✅ |

## B. 搜索域

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 关键词搜索 + 分页 | `music_search.dart` `MusicSearchController` | ✅ |
| 热门搜索（开关 `showHotSearches`） | `musicHotSearchesProvider` + library 空态 | ✅ |
| 历史搜索（清空/单条删） | `musicSearchHistoryProvider` | ✅ |
| 搜索建议（输入下拉 tipSearch） | library 搜索框聚焦且输入词≠已提交词时显示源建议，点行即搜（提交 `ca47d0ab8`） | ✅ |
| 搜索类型：歌曲/歌单 双 tab + 类型切换 | library 搜索框旁分段切换；歌单结果逐页累积、双模滚动、点击跳歌单详情；五频道全实现（wy eapi cloudsearch type 1000 `0cac05b4f`；kg msearchretry special / tx y.qq soso songlist / mg v3 签名 songlist 切片 / kw r.s ft=playlist，提交 `ac52b3c76`） | ✅ |
| 聚合搜索（all 源并发合并分页） | library 源选择行含「全部音源」：五平台同页并发，失败源按空算，合并去重并按 similar(`title artist`) 相似度排序（提交 `2211bfd06`） | ✅ |
| 搜索页音源选择器（页内源 ≠ 全局默认） | library 搜索框下源行（DsTopNav：全部+五平台），页内选择初始取全局默认、此后不再跟随；切源即重搜（提交 `2211bfd06`） | ✅ |
| 音源别名/原名显示（小蜗音乐…） | `sourceNameType` 偏好（alias 默认/real），五内置平台与聚合入口双套措辞照抄参考词表；library 源行/歌曲行/默认音源下拉全走同一映射，自定义源保持真名（提交 `79629cb6f`） | ✅ |

## C. 歌单域（在线歌单）

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 热门标签浏览 + 卡片网格分页 | `_OnlinePlaylistBrowse`（DsChip + MusicPlaylistGrid） | ✅ |
| 歌单分类标签组（TagGroup 分类树） | PlaylistTagTree 能力 + 浏览页分类组 DsTopNav 行（热门为第一组）+ 组内标签 chips：wy catalogue / kg smarty getSpecial / tx all-categories / mg taglist 模板（提交 `16fd63dbe`）/ kw getTagList 树 + getRcmTagList 热门名→`id-digest` 映射（提交 `eb104dd0c`） | ✅ |
| 排序 tab（推荐/最热/最新/热藏/飙升） | MusicPlazaSort 表 + 浏览页第一行 DsTopNav（单 tab 不显示）：kg 五 tab 映射 getSpecial t 码、tx 无标签时排序顶替分类（推荐=feed）、wy/mg 各自仅剩的单 tab、kw 最新/最热双 tab 走 getRcmPlayList order（提交 `28c05034f`；kw `eb104dd0c`） | ✅ |
| 打开歌单（链接或 ID） | 在线歌单 tab 行尾链接按钮 + 对话框（链接/ID）；五源 `playlistDetail` 内按参考 `getListId` 正则归一（wy ?id= 与 /playlist/n/m、tx /playlist/ 与 id=、kg special/single 与 id_ 前缀、mg /playlist/、kw /playlist(_detail)/ 链接 + `digest-<d>__<id>` 复合 id 分发 8/5/13 + 博单 bd-api 链接），裸 ID 直用（提交 `09e12aa10`；kw `eb104dd0c`） | ✅ |
| 歌单搜索（搜索类型=歌单的结果页） | 随 B 项落地：library 歌单类型结果页（`_SonglistResults`，MusicPlaylistGrid 双模滚动，点击进详情） | ✅（0cac05b4f） |
| 收藏歌单（存入我的列表并记 source 供更新） | 导入即 `linkSource` 记 source+sourceListId（模型与持久化本就支持），供后续更新对比（提交 `da26d9b86`） | ✅ |
| 已收藏在线歌单"更新"（拉最新对比替换） | 卡片菜单「更新在线歌单」：按存的 source+sourceListId 重拉广场整表替换（`replaceTracks`，参考 overwriteListMusics）；二次收藏同歌单弹确认改走更新（提交 `b596c3348`） | ✅ |

## D. 排行榜域

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 榜单切换（DsTopNav 分类条）+ 榜单曲目 | `_ChartsView`+`_ChartItems` | ✅ |
| 收藏榜单进我的列表侧栏 | 图表页榜单行尾收藏按钮：建链接列表记 `board__<id>`，二次收藏确认刷新，「更新」按前缀改走 leaderboard 取数（参考 syncSourceList 分流）（提交 `422c85405`） | ✅ |
| 榜单面板选择（弹层列全部榜单） | DsTopNav 滚动条等价 | ✅ |

## E. 我的列表域

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 新建/重命名/删除/清空列表 | `music_playlists.dart` + `_PlaylistsView` | ✅ |
| 单列表导入/导出（文件） | `importFromFile`/`exportToDirectory` | ✅（LX .lxmc 互通见 L） |
| 排序歌曲（歌名/歌手/专辑/时长/随机） | `sortTracks` 五字段 | ✅ |
| 调整位置（上移/下移菜单） | `moveTrack` 上/下 | ✅ |
| 调整位置（输入位置号直接跳） | 多选工具行「调整位置」：对话框输位置号，选中歌曲保序插入该位（参考 musicsPositionUpdate 算术；文案照抄 music_sort__ 三条）（提交 `d961519ee`） | ✅ |
| 移动到其他列表（批量） | 多选工具行「移动到」：选择器排除源列表（参考 excludeListId），目标去重加入（按 addToTop 定位）后从源列表移除（参考 moveListMusics）（提交 `c830f90b9`） | ✅ |
| 重复歌曲查重去重 | 卡片菜单「重复歌曲」：`duplicateTrackGroups` 按参考 filterDuplicateMusic 归一（去括注变体/标点/空白）分组，对话框逐条播放/移除 + 一键保留每组第一首（提交 `f2ce85222`） | ✅ |
| 列表内搜索 | 详情页头部搜索钮 + 搜索框：`searchPlaylistTrackIndexes` 按参考 searchListMusic 三档全匹配（歌名/歌手/专辑各档保原序）+ 剩余子序列匹配按 similar 降序，点击结果按原索引续播，搜索态禁用上下移（提交 `105f4647e`） | ✅ |
| 歌曲换源（手动，搜其他源替换+缓存） | 解析失败自动跨源匹配（`music_source_match.dart`）；手动换源：歌曲菜单「歌曲换源」对话框（参考 MusicToggleModal：全源并发搜、逐源 tab、行内试听、确认），选择进 `music_source_swaps.dart` 持久缓存表且 `resolveWithToggle` 优先走换源结果，歌单内另以 `replaceTrack` 原位替换（提交 `5261a8190`） | ✅ |
| 本地歌曲编辑标签（元数据编辑） | 歌曲菜单「编辑标签」（本地歌曲）：对话框（参考 MetadataEditModal：读文件标签预填，歌名/艺术家/专辑/LRC 歌词/封面，150 字上限，文件名解析 歌名-艺术家 双序，封面选择/移除/在线匹配，歌词在线匹配带翻译合并）；写入只回写改动部分（`music_tag_writer.dart` 纯 Dart：mp3 重写 ID3v2.3+v1 尾刷新、flac 重写 Vorbis comment+PICTURE 块，其余格式 toast 不支持），保存后重扫本地库（提交 `c6672dbf3`；配套 media_core 修 flac 图片块按规范序解析 `009273d`） | ✅ |
| 多选（区间选择/反选） | 多选工具行加 单选/区间 DsSegmentedControl + 全选↔反选切换：单选点按=勾/去并移锚，区间点按=以锚为界的整段替换（首点=单选该行、点锚=清空、锚不动），全选满员时按钮变反选=清空（参考 mobile MultipleModeBar + List.handleSelect 语义；提交 `550f023a2`） | ✅ |
| 添加本地歌曲（文件进列表） | 歌单卡片菜单「添加本地歌曲」：多选音频文件（引擎 LocalMusicSource 全扩展名过滤），逐文件读标签入列（标签缺失/损坏回退文件名、不丢文件，与本地库扫描同构：id=路径/sourceId=local/专辑+trackNumber+year 元数据齐），`addTracks` 去重按 addToTop 定位，已添加 N 首/都在列表中双 toast（参考 desktop useMenu+addLocalFile、mobile listAction；提交 `67fd41993`） | ✅ |

## F. 播放器域

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 播放模式四态（列表/列表循环/单曲/随机） | `music_playback.dart` PlayMode | ✅ |
| 倍速（滑条+重置，记忆） | `setRate` + `playbackRate` | ✅ |
| 音量（滑条/静音） | `volume` 设置 + 播放器 | ✅ |
| 定时停止（分钟数/等当前曲播完/取消） | sleep timer（`sleepTimerRemaining`、等播完开关） | ✅ |
| 歌词：翻译/罗马音副行、繁体、逐字卡拉OK | `showTranslation/showRomanization/traditionalizeLyric/playWordLyrics` | ✅ |
| 歌词：对齐/字号缩放/当前行缩放/偏移 ± | `lyricAlignment/lyricFontScale/lyricZoomActive/lyricOffsetMs` | ✅ |
| 歌词右键菜单（字号±/偏移±10/100ms/重置） | 播放器菜单子菜单 | ✅ |
| 拖拽歌词调整进度（3 秒回弹） | 歌词设置页「拖拽歌词调整进度」开关（默认关，参考同默认）：用户滚动歌词即暂停跟随（区分自身 animateTo），面板 40% 高度出现划线=所指行时间+跳放按钮（点按 seek 到该行 start），停手 3 秒回弹到当前句（暂停中不回弹，参考 mobile Vertical/Lyric.tsx+PlayLine.tsx 逐语义）；未同步歌词不参与（提交 `7a8d9d178`） | ✅ |
| 频谱可视化（实验性） | 无（内核能力）：media_core 现仅有 EBU R128 响度探针（`emitLoudnessChanged`，af 链滤镜在场才上报），无 PCM/FFT 面；方案已定稿 `docs/media-core-audio-spectrum-architecture.md`——顺序为 阶段A 审计→B PCM Tap 五平台验证→C FFT→D 接入→E UI，**PCM Tap 验证前不得开发 FFT/UI** | ⬜ 待内核 |
| 音效（实验性）：EQ + 混响 + 3D 环绕 + 升降调 | `eq/` 十段均衡+FX 链（bass/vocal/width/loudness 等）+ 预设；混响=aecho 回声叠加（参考为 IR 卷积，mpv 链不带货样文件，取诚实近似，强度→回声衰减）、3D=apulsator 正弦声像环绕（转速按参考 0.72s×speed/圈 换算 hz，强度→摆深 0.1–2，声明仅立体声有效）、升降调=asetrate+atempo 补时长（rate 0.5–1.5 同参考滑条 50–150，1.0 跳过滤芯）（提交 `29f017f3d`） | ✅ |
| 倍速音调补偿 preservesPitch | 倍速菜单尾「音调补偿」勾选项（默认开，参考词表照抄；参考为 player 弹层 checkbox + `audio.preservesPitch`），存 `music.play.preservesPitch`，经 `applyEngineOptions` 下发 mpv `audio-pitch-correction` yes/no（引擎重建自动重放，handle 未就绪挂起待首曲）（提交 `5294fc8da`） | ✅ |
| 音频输出设备选择 | 无（内核能力） | ⬜ 待内核 |
| 播放队列面板 | `_QueuePanel` | ✅ |
| 歌曲评论（热门/最新、楼层、图片） | `music_comments.dart` + `_CommentsDialog` | ✅ |
| 歌曲详情（元数据弹窗） | `MusicSongRow._showDetails` | ✅ |
| 歌词编辑/偏移持久化管理 | `music_lyric_overrides.dart` | ✅ |
| 已播列表去重（随机不重复）/自动清空 | 随机不重复由内核 PlayQueue 每轮置换保证（耗尽即重排一轮，全部重新参与，内核文档注明与 lx-music 同语义）；本轮补参考 `player.isAutoCleanPlayedList`（默认关，词表照抄）：播放设置页开关存 `music.play.autoCleanPlayedList`；同列表点歌（playAll 同内容重放/队列行 play/playAt）在随机模式下重建洗牌、列表内所有歌曲重新参与随机（=参考 clearPlayedList），换列表恒新开一轮，设置关时同列表续播保留去重池（参考 `setting || prevListId != listId` 规则照抄）（提交 `268814b28`） | ✅ |
| 预加载下一首 / URL 过期刷新 | 内核已接全链（实查 `audio_playback_controller.dart`）：每曲起播即 `_prefetchNext` 预热下一曲 URL+歌词（`queue.indexAfter` mode-aware，单曲循环自动跳过），结果入 `_resolved` 且切曲时 `_openTrack` 直接消费未过期条目——比参考"最后 10 秒静音探测、结果不落播放路径"更强；URL 带 `expiresAt`，过期即重解析，加载失败 `refreshSourceOnError` 一次性刷新、起播成功即补预算（`prefetchNext`/`refreshSourceOnError` 默认开，app 构造 `AudioPlaybackConfig` 未覆盖） | ✅ |
| 临时列表（稍后播放入队顶） | `playNext` insertNext | ✅ |
| 通知栏/锁屏控制 + 封面 | 内核媒体会话 | ✅ |

## G. 桌面歌词

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 开关/锁定/拖动/字号/透明度/颜色/对齐 | `music_playback.dart` DesktopLyricController + 设置 pane 七项 | ✅ |
| 行间距/加粗分项 | `music_settings.dart` desktopLyricLineGap(0–25,默认15)/BoldLine/BoldExtended + pane 三行；内核 DesktopLyricStyle 四端渲染器透传（3d421b640 + media_core 65130a9） | ✅ |
| 单行 | 桌面歌词渲染恒单行省略号截断（GDI+ AddString 不换行），即参考 ellipsis:true 的终态 | ✅ |
| 垂直布局 | 内核四端渲染器均无逐列竖排能力 | 🟡 待内核 |

## H. 快捷键

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 软件内快捷键（播放/上下曲/音量/收藏…可录制） | `music_hotkeys.dart` + 快捷键 pane | ✅ |
| 系统全局快捷键（OS 注册，Windows） | 快捷键 pane 全局开关把同一张表注册进系统，窗口未聚焦也生效；media_core 7a01775 RegisterHotKey+WM_HOTKEY（a664f4fbc） | ✅ |
| 系统全局快捷键（Linux/macOS） | 内核 transport 已留位（isSupported 降级），原生注册未实现 | 🟡 待内核 |

## I. 数据同步

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 客户端同步（地址/连接码/状态） | `music_sync*.dart` + 同步 pane | ✅ |
| 同步内容=列表+不喜欢（合并/覆盖模式） | `kMusicSyncModes` | ✅ |
| 服务端模式（desktop 作服务器） | 仅客户端 | ⬜ |
| 连接历史地址列表 | 同步 pane 历史行+连接历史弹窗（点击选用/行内删除/空态）；连接时记入，去重、最新在前、上限 20（f880b4515） | ✅ |

## J. 开放 API

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 本地 HTTP API（开关+端口+局域网） | `music_open_api.dart` gate+port | ✅ |
| /status /play /pause /skip /seek /volume /mute | 已实现 | ✅ |
| /lyric /lyric-all /collect /uncollect、SSE 状态订阅 | 无 | 🟡 补端点 |

## K. 缓存与日志

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| 源脚本缓存/歌词缓存/URL 缓存 | `music_source_cache.dart`（带 TTL） | ✅ |
| 缓存清理 UI（按类统计+清理） | app 缓存页管封面/头像；音乐三类缓存清理无入口 | 🟡 |
| 错误日志查看/清空 | live_log 控制台（无音乐专用页） | 🟡 |

## L. 导入协议与文件

| LX 功能 | v2 落点 | 状态 |
|---|---|---|
| lxmusic:// deeplink（搜索/播放/歌单/player 命令） | `music_deeplink.dart` | ✅ |
| lx 源脚本导入（内置目录+自定义） | `music_source_catalog.dart` + 自定义源 pane | ✅ |
| 列表备份文件互通（.lxmc/桌面版列表 json） | 自有 json；LX 列表数据形状经 `music_sync_data.dart` 支持读 | 🟡 导入 .lxmc |
| 音频文件拖入播放 | 本地音乐文件夹扫描 | ✅ 语义等价 |

## M. 设置项对齐

设置树已直列 8 页（播放/歌词/桌面歌词/下载/音源/快捷键/同步/音效）。逐项对照 LX：

- 播放页：音源/音质/跳过错误/自动播放/记住进度/自动清空已播列表/列表行为（addToTop/showSource/热搜）——✅；**音频焦点/缓存上限** 由 app/内核承担。
- 歌词页：翻译/罗马音/换位/繁体/逐字/字号/对齐/当前行缩放/进度显示/偏移——✅。
- 桌面歌词页：见 G。
- 下载页：类型/命名模板/嵌入封面歌词/翻译罗马音/写歌词文件/跳过同名/按列表分目录/并发数——✅；**自动换源下载** ⬜。
- 音源页：导入/启停/删除/内置目录一键导入——✅；**别名命名体系** 🟡（随 B）。
- 同步/快捷键/音效：见 I/H/F。

## 自动任务的轮次规则

1. `git status --porcelain` + `git log --oneline -3`：有 index.lock 或并行会话未提交 WIP 挡路 → 跳过本轮，一句话回报。
2. 台账全 ✅（🟡⬜ 计数为 0）且 HEAD 未变 → 一两句话回报，不跑 analyze/test、不改码、不提交。
3. 取最靠前的 🟡/⬜，按其 v2 落点实现一批（一次一批）；l10n 两语言 json 同步加键后在 `apps/pure_live` 目录跑 `dart run slang`（先 grep 新键）；收尾 `dart analyze` 零问题 + `flutter test test/music` 全过。
4. 只 stage 本轮自己改的文件；提交（英文小写 conventional）→ `git push origin v2` → 台账该条改 ✅ 附哈希。UI 不写测试。
5. 参考行为拿不准时先读对应参考文件（判定基线给出的路径），不凭记忆写。
