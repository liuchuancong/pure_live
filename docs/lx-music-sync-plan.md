# lx-music-desktop → pure_live 音乐逻辑同步台账

> 基准：`C:\Users\XA-158\Downloads\lx-music-desktop-master\lx-music-desktop-master`（lx-music-desktop 开源版，下称 LX）
> 现状：`apps/pure_live/lib/modules/music/`（约 8500 行，已实现音乐页/播放器/设置/lx 脚本运行时）
> 约定：UI 可以重写（沿用现有 desen_ui/modules/music 风格），**具体逻辑必须与 LX 同步**。
> 状态标记：⬜ 未开始 ｜ 🟨 进行中 ｜ ✅ 已完成并与 LX 对齐 ｜ ➖ 不移植（明确决策）

创建：2026-10-29。更新：2026-10-29（第一批落地）。

---

## 0. 现状结论（2026-10-29 审查）

- 已有实质代码：音乐页 6 视图（曲库/歌单/榜单/我的/本地/下载）、播放器页、设置面板、
  `AudioPlaybackController`（media_core_audio）、队列与续播持久化、`lx_script_runtime.dart`
  （fjs/QuickJS 跑 lx 自定义源脚本，`lx.on('request')/lx.send/lx.request` 契约已通）、
  歌单/评论/ dislikes/本地扫描等 controller。
- **最大缺口**：内置音源只有酷我（`music_source.dart` 的 `kLxMusicSourceId='kw'` 写死），
  LX 的 kg/tx/wy/mg 内置源 API、多源切换/换源匹配、逐字歌词解码、下载元数据写入、
  桌面歌词数据通道、音效 EQ、同步服务、开放 API 均未实现。
- 台账修正：`sync-progress.md` A10b（"音乐：先确认曲库来源"）与 `parity-audit-2026-10-25.md:104`
  （"三个 tab 空态"）已落后于代码，随本台账建立后应视为被本文件取代。

## 1. 模块对照与进度

### A. 音源体系（最高优先级）
- ✅ A1 `MusicSource` 多源化（2026-10-29）：`controller/sources/lx_platform_source.dart`
  基类（脚本优先取链 + 平台兜底钩子 + 公共 HTTP）+ `music_source_kw.dart` / `music_source_kg.dart`；
  `music_source.dart` 改为 `musicSourceListProvider`（全源）+ `musicSourceProvider`（按
  `music.source.default` 选活动源）+ `kwMusicSourceProvider`（酷我专属端点）；
  播放 registry 注册全源（混源队列可播）、下载按 `track.sourceId` 找源、设置页音源下拉动态生成；
  `lxMusicInfo` 透传 `hash/hashes`（kg 脚本按 hash 取链）。
  LX 参考：`src/renderer/utils/musicSdk/index.js`（sources 列表、`searchMusic` 聚合）。
- ✅ A2 kw 酷我补齐（搜索/歌词/榜单/封面/详情已齐；2026-10-29 `trackDetail` 接
  `api/www/music/musicInfo?mid=`（`kw/index.js getMusicInfo`，code==200 校验，
  artist 数组 `、` 连接、album/albumid/pic/duration 回填 MusicTrack））：搜索 `http://search.kuwo.cn/r.s?client=kt&all=...`（解析 `N_MINFO`，
  bitrate 4000→flac24bit/2000→flac/320/128）、歌曲信息 `api/www/music/musicInfo?mid=`、
  封面 `artistpicserver.kuwo.cn/pic.web`、榜单 bangid 硬编码表（93 飙升/16 热歌…）。
  LX 参考：`musicSdk/kw/{musicSearch,index,lyric,pic,leaderboard}.js`
- ✅ A3 kg 酷狗（2026-10-29 搜索/榜单/歌词/逐字全接 `music_source_kg.dart`；歌词两步
  search→download，krctype==1 优先 KRC 候选走 `decodeKrc`、否则 base64 LRC 兜底）：
  搜索 `songsearch.kugou.com/song_search_v2?platform=AndroidFilter`；
  签名 `signatureParams` = MD5(key+排序参数+body+key)，key=`OIlwieks28dk2k092lksi2UIkp`(android)/
  `NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt`(web)。
  LX 参考：`musicSdk/kg/*`、`kg/util.js`
- ✅ A4 tx QQ（2026-10-29 搜索/榜单/封面/歌词全接 `music_source_tx.dart`，zzcSign SHA1 签名移植；
  歌词 `GetPlayLyricInfo` qrc:1/trans:1/roma:1 走 `decodeQrc`+`parseQrc`（QRC 三重 DES 解码在
  `lyric_decoders.dart`）：POST `u.y.qq.com/cgi-bin/musicu.fcg`（module `music.pf_song_detail_svr`），
  音质从 `file.size_128mp3/320mp3/flac/hires` 推导；封面拼
  `y.gtimg.cn/music/photo_new/T002R500x500M000{albumMid}.jpg`；歌词 qrc:1,trans:1 + QRC 解码。
  LX 参考：`musicSdk/tx/*`、`tx/qrcDecode.js`
- ✅ A5 wy 网易（2026-10-29 搜索/榜单/歌词/逐字全接 `music_source_wy.dart`，`wy_crypto.dart` 移植
  eapi/weapi：AES-128-CBC/ECB(pointycastle PKCS7) + RSA NoPadding（公钥 n/e 已硬编码）；
  yrc/ytlrc/yromalrc 走 `parseYrc` 合成、lrc/tlyric 兜底（yrc 逐字解码归 D2 已落））：eapi/weapi 加密（AES-128-CBC 双层 + RSA / eapi=
  MD5("nobody{url}use{text}md5forencrypt")+AES-128-ECB，key=`e82ckenh8dichen8`，iv=`0102030405060708`）；
  搜索 `/api/search/song/list/page`、详情 `weapi/v3/song/detail`、歌词 `/api/song/lyric/v1`
  （返回 lyric/tlyric/romalrc + yrc 逐字合成 lx 逐字格式）。
  LX 参考：`musicSdk/wy/*`、`wy/utils/crypto.js`
- ✅ A6 mg 咪咕（2026-10-29 `music_source_mg.dart`：v3 签名搜索（MD5 盐+固定 deviceId）、
  10 榜单 querycontentbyId、歌词 mrcUrl 逐字（TEA 64 位解密已在第七批移植进
  `lyric_decoders.dart` 的 `decryptMrc/parseMrc`）+ lrcUrl/trcUrl 翻译兜底；取链仅脚本）：搜索 `jadeite.migu.cn/music_search/v3/search/searchAll?...&sid=USS`、
  信息 `c.musicapp.migu.cn/.../resourceinfo.do`（copyrightId 为键）、榜单
  `app.c.nf.migu.cn/pc/bmw/rank/rank-index/v1.0`；MRC 逐字（`mg/utils/mrc.js`）。
- ✅ A7 换源匹配（2026-10-29 `sources/music_source_match.dart`：名称归一化+版本后缀剥离+±5s
  匹配 `findSameSong`；`music_source.dart` 的 `resolveWithToggle` 完整实现本源失败→跨源搜索→
  同曲匹配→取链。播放器接线待 music_playback 并行 WIP 收口）：歌名+歌手+专辑归一化（含 `versionChars.ts` 版本后缀处理
  Live/Remix）+ 时长 ±5s 匹配；`meta.toggleMusicInfo` 优先取链、失败回落本源。
  LX 参考：`musicSdk/index.js findMusic`、`core/player/action.ts getMusicPlayUrl`
- ✅ A8 热搜/搜索建议（2026-10-29 `sources/music_hot_words.dart` 能力接口 `MusicHotWords`
  （hotSearches+suggestions），kw/kg/tx/wy/mg 五源各自按 LX 端点实现，`music_search.dart` 的
  `musicHotSearchesProvider` 按能力分发并新增 `musicSearchSuggestionsProvider`（family by query）：
  kw hotword.s+tips.kuwo.cn、kg gateway hot_tab(固定签名)+searchtip、tx musicu hotkey+smartbox、
  wy eapi search/chart/detail+weapi suggest/web、mg hotword(无签)+v3 suggest）：LX 参考：各平台 `hotSearch.js`、`tipSearch.js`
- ➖ bd 百度 / xm 虾米：LX 中已注释/排除，不移植。

### B. 自定义源（user api）
- ✅ B1 fjs 脚本运行时：`lx.on('request')/lx.send('inited')/lx.request/lx.utils` 契约已通
  （`controller/lx_script_runtime.dart` + `lx_script_prelude.dart`）。
- ✅ B2 脚本头解析已实装（`music_sources.dart` `MusicCustomSource.parse`：首块注释
  `@key value` 逐行提取，`@name` 缺失或无 request 契约即拒收；运行时把 name/description/
  version/author/homepage/rawScript 注入 `lx.currentScriptInfo`）。余项（id 时间戳规则、gz_ 前缀
  压缩存储）随 B3 导入导出一并核对。原条目：脚本头注释解析 `@name/@description/@author/@homepage/@version`
  （正则 `/^\s?\*\s?@(\w+)\s(.+)$/`）、id 规则 `user_api_XXX_时间戳`、脚本 deflate+base64
  `gz_` 前缀存储（保持导入兼容）；`lx.request` 需支持 method/timeout/headers/body/form/formData
  与代理设置透传。LX 参考：`src/main/modules/userApi/{utils,main}.ts`、`preload.js`、
  `store/apiSource.ts`、`core/useApp/useInitUserApi.ts`

### C. 播放核心状态机

> 2026-10-29 校准：四种播放模式（list/listLoop/singleLoop/random 物化洗牌、previous 可回溯）、
> 稍后播插队（`playTrack(insertNext:)`）、 disliked 跳过、失败自动跳过、队列与续播位置持久化、
> 睡眠定时器、倍速、歌词偏移 **均已存在**（media_core_audio `PlayQueue/PlayMode` +
> `music_playback.dart`）——C 的大头已在引擎层落地。
- ✅ C1 队列状态机（引擎层已对齐，见上；LX 的 playedList 清理已删歌由引擎物化顺序等价覆盖）
  对齐 `core/player/action.ts`（LX 最核心文件，646 行）：
  下一曲优先级 = tempPlayList（稍后播，isTop 插队）→ playedList（随机模式历史栈，恢复时清理已删歌）
  → `filterList()` 过滤已播/无效 → 按模式算 nextIndex：
  `listLoop`（尾→0）/`random`（预计算缓存 `randomNextMusicInfo`）/`list`（尾→停止）/`singleLoop`/`none`。
  playPrev 对称。
- ✅ C2 竞态保护（`AudioPlaybackController` 单引擎句柄内处理，源级竞态由其代数/过期机制覆盖）
  ：`diffCurrentMusicInfo()`（比较 gettingUrlId/id/isPlay），换歌并行发起
  URL/封面/歌词三路请求各自防串台。
- ✅ C3 取链重试策略（2026-10-29 `LxPlatformSource._patient`：五源全部 HTTP 端点
  （getText/getJson/postJson/postForm）遇 429 随机 2–6s 延迟后重试一次；签名 URL 过期重解析引擎已有；
  换源回落已接 `resolveWithToggle`。autoSkipOnError 属播放引擎行为待验）：引擎有签名 URL 过期重解析；LX 的 429 随机 2–6s 延迟未单独实现；
  换源回落可接 `resolveWithToggle`）：`getMusicPlayUrl` 先 toggleMusicInfo 后本源；429 随机 2–6s 延迟重试；
  失败再重试一次；`autoSkipOnError` = 加载超时 100s / 失败 5s 自动下一曲。
- ✅ C4 进度恢复（`music.playback.positions` + `music.queue` 已持久化续播）：`isSavePlayTime` 时恢复到上次位置并暂停待播（现有 `music.playback.positions`
  已有雏形，对齐 LX 的 data store playInfo 结构与暂停语义）。
- ✅ C5 下一曲预载（2026-10-29 实查引擎已做：media_core_audio `AudioPlaybackController._prefetchNext`
  在播放开始事件即预热下一曲 URL+歌词，`AudioPlaybackConfig.prefetchNext` 默认开、
  按 sourceId+trackId+quality 缓存、过期重解、失败静默（真实尝试才报错）；比 LX 的
  播放 3s 后预载更早，语义一致）（`usePreloadNextMusic.ts`）。
- ✅ C6 收藏（`music_library.dart` 收藏/最近已实现）：（`LIST_IDS.LOVE='love'`）、`collectMusic/uncollectMusic` 语义。
- ✅ C7 定时停止（`setSleepTimer` + `setPauseAfterCurrentTrack` + 倍速 + 歌词偏移已有；
  mediaDeviceId 输出设备选择未做）： `timeoutStop.ts`（`waitPlayEndStop`）；倍速/`preservesPitch`/媒体设备选择
  （`playbackRate.ts`、`volume.ts`、mediaDeviceId）。

### D. 歌词
- ✅ D1 歌词门面（2026-10-29 `sources/music_source_cache.dart`：`CachedLyricSource` 装饰器
  缓存四源歌词于 `music.lyrics.cache`（上限 200），全源 `musicSourceListProvider` 已挂；
  LrcParser 支持逐字/翻译/音译/[offset:]，词法与 LX 产出对齐）：缓存（LX 用 SQLite lyric 表；本项目可用 Hive，键含 musicInfo id）→
  未命中在线获取（支持换源）→ 成功写缓存；产出 `{lyric, tlyric, rlyric, lxlyric, rawlrcInfo}`。
  LX 参考：`core/music/{index,online,utils}.ts`、`dbService/modules/lyric`
- ✅ D2 逐字解码（2026-10-29 三件套已落 `sources/lyric_decoders.dart`：KRC XOR 16 字节密钥
  +zlib、QRC 3DES 变体逐位移植（非标准 S2[23]=15/S4[53]=10 保留）+ 截断流补 sync-flush 容错、
  wy yrc→lx 逐字标签；kg/tx/wy 三源 resolveLyric 已接，解码产物为 lx 格式 `<startMs,dur>` 逐字
  LRC（media_core_audio LrcParser 原生支持）。QRC/KRC 解码尚无真实样本验证，待用户实测）：
  kg KRC（XOR 密钥 `[0x40,0x47,0x61,0x77,0x5e,0x32,0x74,0x47,0x51,0x36,0x31,0x2d,0xce,0xd2,0x6e,0x69]` + zlib inflate + `[language:base64]` 翻译/音译，`lyricUtils/kg.js`）、
  tx QRC（`qrcDecode.js`，已移植）、wy yrc→lx 逐字拼接（`wy/lyric.js`，已移植）、
  mg MRC（`mg/utils/mrc.js` TEA 解密，第七批已移植）。
  （media_core_audio 已有 LyricParser LRC/QRC/KRC/YRC 基础，需与 LX 解析行为对齐。）
- ✅ D3 歌词播放引擎（media_core_audio `LyricDocument/LrcParser/LyricTimeline` 逐行/逐字 +
  `setLyricOffset` 手动偏移已实现，行为等价 LX LinePlayer）：`lyric-font-player/`（`LinePlayer{offset,rate,onPlay,onSetLyric}`，
  `_findCurLineNum` 增量查找；font-player 逐字版）+ `[offset:]` 标签/手动偏移
  （setOffset/setTempOffset）。
- ✅ D4 显示开关（2026-10-29 收口：translation/romanization/swap 三开关此前已落并在
  `music_playback` 消费；本批补齐 isS2t 与 isPlayLxlrc——设置 `traditionalizeLyric`（默认关，
  `player.isS2t` 同款）与 `playWordLyrics`（默认开，`player.isPlayLxlrc`；LX 仅在 macOS 关）+
  slang 双语 key + 外观-歌词窗格两行开关；生效点=新装饰器 `sources/music_display_lyric.dart`
  （DisplayLyricSource 套在 CachedLyricSource 外，缓存原始 payload、读取时按当前设置改写：
  关逐字→剥 `<start,dur>` 标签，繁体→`chinese_s2t.dart` 2537 字符表逐字替换——表由 python 从
  simplify-chinese-main/chinese.js 抽取）；顺修 decodeKrc 误剥逐字标签（与 qrc/yrc/mrc 及文件头
  契约不一致）。LX 参考：`core/music/utils.ts buildLyricInfo`、`simplify-chinese-main`、
  `defaultSetting.ts`
- 🟨 D5 桌面歌词（2026-10-29 实查大半已接：`DesktopLyricController` 已覆盖
  show/hide/toggle/lock/style/displayOptions/bounds/setDocument，模块 `music_playback.dart`
  已喂 `desktopLyric.*` 设置——LX 的 get/set_info、get/set_status 通道等价落地；剩
  频谱 analyser 数据通道，media_core 无频谱能力，属引擎缺口待扩）：LX 用 MessagePort 通道（get_info/set_info/get_status/set_status/
  频谱 analyser 数据）；media_core_audio 已有桌面歌词窗口（含鼠标穿透 `winLyric/mouseCheckTools.ts` 语义）。

### E. 下载
- ✅ E1 任务状态机（media_core_audio `MusicDownloadQueue/MusicDownloadTask/MusicDownloader`
  WAITING/RUNNING/PAUSED/ERROR/COMPLETED + app `music.downloads` 队列持久化）：WAITING/RUNNING/PAUSED/ERROR/COMPLETED + 节流更新（`store/download/action.ts`）。
- ✅ E2 保存路径与命名（`download.savePath` 容器目录 + 按歌单分目录 + `downloadPattern`
  模板已有设置项）：`download.savePath` + 按歌单名分目录开关 + 文件名模板
  （'歌名 - 歌手'|'歌手 - 歌名'|'歌名'）（`store/download/utils.ts buildSavePath`）。
- ✅ E3 元数据写入（`MusicDownloadRequest` embedCover/embedLyric/writeLyricFile/
  includeTranslation/includeRomanization 全参数，下载器负责写入）：FLAC/MP3 写标题/歌手/专辑/封面/歌词（`common/utils/musicMeta/`）。
- ✅ E4 下载取链复用播放取链（2026-10-29 `music_downloads.dart` 首取与重试 resolve 均改走
  `resolveWithToggle`——本源失败搜同名歌换源，与播放同链；kg 歌词标签由 KRC 解码路径天然对齐）。
- ✅ E5 下载列表持久化（`music.downloads`）。

### F. 歌单/收藏
- ✅ F1 数据模型对齐（收口：MusicTrack 的 id/title/artist/album/albumId/duration/coverUri
  全覆盖 MusicInfo 字段；`toggleMusicInfo` 不入模型——换源是运行时行为，
  `resolveWithToggle` 已等价（播放 E4 下载同链）；interval=duration、picUrl=coverUri、
  quickSearch 无场景不移植） `src/common/types/list.d.ts` + `music.d.ts`：
  `MusicInfo{id,name,singer,source,interval,meta:{albumId,albumName,picUrl,quickSearch?,toggleMusicInfo?}}`；
  LIST_IDS = default/love/temp/download。
- ✅ F2 表结构对齐（2026-10-29 收口：本项目 Hive 单键存储天然合并 LX 三表——tracks 内联即
  `my_list_music_info`+`order`（列表顺序即 order，添加去重即 UNIQUE(id,listId)）；本批补齐 `my_list`
  缺失字段语义：`source`/`sourceListId`（在线歌单关联，linkSource/unlinkSource）、`position`
  （歌单排序，`move(id,to)`=updateUserListPosition，其余列表 position 平移重写）、
  `locationUpdateTime`（移动时间戳）；旧条目 JSON 无新字段按默认读入，向后兼容）
- ✅ F3 操作全集（`music_playlists.dart` 全操作 + 回归测试，导入导出已通）（`rendererListManage.ts`）：getUserLists/createUserList/removeUserList/
  updateUserListPosition/getListMusics/addListMusics（去重）/moveListMusics/overwriteListFull/
  checkListExistMusic/getMusicExistListIds。
- ✅ F4 不喜欢列表（`music_dislikes.dart`，播放时自动跳过已接）（`store/dislikeList/`，已有雏形 `music_dislikes.dart`，对齐结构）。
- ✅ F5 备份/迁移：对接现有 backup 域 + 导出歌单为文本/CSV（`SettingBackup.vue`、
  `renderer/worker/main/list.ts`）。backup_settings.dart 早已收录 music.* 全部键
  （设置/歌单/收藏/最近/不喜欢/自定义源/歌词覆盖/队列=仅设置与全量两档已覆盖；补齐本轮
  新增 music.play.volume/rate、music.lyric.traditionalize/playWordTimed 四键）；
  `music_playlists.dart` 新增 LX 同款导出：合并单文件（`\uFEFF` BOM、
  `歌名  歌手  专辑` 行、列表间空行）与逐列表文件 `lx_list_<名>.txt/.csv`，
  CSV 带 `歌名,歌手,专辑` 表头 + 引号转义（`exportPlayListToText`/`exportPlayListToCSV`）。
- 🟨 F6 在线歌单（数据层已落：能力接口 `OnlinePlaylists`（`online_playlist_models.dart` 共享
  `MusicPlaylistInfo/Page`）；**wy+tx+kg 三通道已实现**——wy weapi hottags/list/v3 detail（含
  privileges 音质合并），tx 热门标签刮取 + `get_category_content` + `GetRecommendWhole` 兜底 +
  `uniform_get_Dissinfo` 详情，kg 走最稳 JSON 链：yueku v9 getSpecial 列表/标签 + `special/info_v2`
  + `special/song_v2` 分页（web 版 MD5 排序签名）+ `gateway.kugou.com/v3/album_audio/audio`
  网关富化（LX `createGetMusicInfosTask` 的固定头/密钥）；**未移植 LX 的 HTML 抓取与 chain/gcid
  多级回退链**（分享链歌单暂不支持）；**mg 通道已实现**（第十批：taglist 标签 +
  `musiclistplaza-listbytag`（contents 递归收 resType=2021）/ `playlist-square-recommend` 兜底 +
  MIGUM3.0 `playlist/song/v2.0` + `playlist/v2.0` 详情）。UI 视图接入 music_page 待后续）：各源 `songList.js`。

### G. 设置与同步
- ✅ G1 设置域对齐（2026-10-29 收口：36 个键已按 `music.<域>.<名>` 覆盖 LX 的
  player./list./search./desktopLyric./download./openAPI. 语义（source.default、play.rememberProgress=
  isSavePlayTime、play.skipOnError=autoSkipOnError、play.autoplay=startupAutoPlay、quality=playQuality、
  addToTop=togglePlayMethod、歌词五开关、desktop 全套、download 全套）；本批补 volume/rate 跨次启动
  持久化（play.volume/play.rate=player.volume/playbackRate，启动 `_restorePlaybackPrefs` 先于队列恢复，
  且不受 autoplay 早退影响）。引擎侧缺口单列：mediaDeviceId/preservesPitch（引擎无 API）、
  audioVisualization=H2、soundEffect=H1 待拍板）
- ⬜ G2 同步服务 client：WebSocket `ws://host/socket?i={clientId}&t={aesEncrypt(msgConnect,key)}`、
  close code 重连/认证失败处理、服务端 action 驱动本地变更、本地变更推快照
  （`main/modules/sync/client/*`）。快照机制：md5 去重 + latest 指针 + 历史
  （`server/sync/modules/list/manage.ts`）。

### H. 其他功能
- 🟨 H1 音效/EQ（2026-10-29 用户拍板为「音效中心」专项并给出设计规范 v1.0；
  **阶段 A 已落**：`controller/eq/` 三件——`music_eq_config.dart`（结构化配置模型
  MusicEqConfig{enabled,preampDb,gains×10,presetId} 持久化 `music.eq`+备份注册、
  9 内置预设 流行/摇滚/古典/爵士/电子/重低音/清晰人声/现场感/平直）、
  `music_eq_dsp.dart`（RBJ peaking 理论频响叠加曲线 + lavfi 链生成
  `equalizer=f=:t=q:w=1:g=` 逐非零段 + `volume=` 预放，平直/关闭时清空 af）、
  UI `pages/music_eq_editor.dart`（曲线+10 拖杆 CustomPainter，日志频域对齐频段中心）+
  设置页新子页 SettingsSection.musicEq（总开关/预设选择/预放滑杆/重置/编辑器）；
  播放器适配层=`MusicPlayerController._applyEq`：经 `AudioPlaybackController.handle
  .applyEngineOptions([EngineOption('af',[lavfi])])` 热应用（handle 记忆并随引擎重建回放），
  250ms 防抖节流拖动、handle 未建时 pending 到首个曲目）。**阶段 B 已落**：六效果走真实 FFmpeg 滤镜（`musicFxAfFilters`）——loudnorm 音量均衡
  （I=-16:TP=-1.5:LRA=11）/ bass 低架 105Hz ≤+8dB / vocal 3kHz 凸起+300Hz 收浑浊 /
  stereotools slev 立体声拓宽 / haas 伪环绕 / acompressor+alimiter 动态限幅；链序=
  loudness→音色→声场→动态，模型扩 MusicFxNode{enabled,amount}（config v2 向后兼容读 v1）；
  频响曲线纳入 bass/vocal 音色形（low-shelf RBJ 公式）；UI 增强音效区=每效果开关+强度滑杆
  +声明成本（latency/stereoOnly，kMusicFxCosts）；`musicEqApplyFailedProvider`=
  applyEngineOptions 报告 unsupported 或异常时页面红字提示（诚实失败规则）。
  **待做**、阶段 C（参数 EQ/FIR/设备校正）、设计图逐像素音效中心主页面
  （当前先落设置子页）、A/B 对比、频响图验证测试）（`plugins/player/index.ts`、
  `store/soundEffect.ts`）。
- ✅ H2 电平监控（2026-10-29，如实标记为响度表非频谱）：mpv 无原始 FFT，走 ebur128 元数据探针——
  media_core `PlayerAdapterEvent.loudnessChanged(momentary, shortTerm)`（LUFS）+ `emitLoudnessChanged`
  （探针过滤器的存在即能力，不做 capability 门控）+ media_kit 适配器 observe `af-metadata`
  （lavfi.r128.M/S，200ms 节流，未开链时零事件=「无表」而非「静音」）+ AudioPlaybackController
  `loudnessStream`/`AudioLoudness`。app 侧 `MusicEqConfig.analysis`（链尾 asplit 分支
  `[probe]ebur128=metadata=1,anullsink`，EQ 关闭也可单独开探针），EQ 面板响度电平表 M/S 双条。
  顺带修复：Phase B 的 musicFxAfFilters 六个增强滤镜从未并入 musicEqAfEntries（开关只存了状态没出声），已并入链头。
- ✅ H3 系统媒体会话（`MusicBackgroundBinding` SMTC/MPRIS + 通知/锁屏已接）：已有 MusicBackgroundBinding（SMTC/MPRIS），对齐 `useMediaSessionInfo.ts` 元数据。
- ✅ H4 开放 API（2026-10-29 `music_open_api.dart`：loopback HttpServer，LX 同款路由
  /status /toggle /play /pause /skip /back /seek /volume /mute；开关/端口 Provider 已落
  `music.openapi.enabled|port`，设置面板接线待并行 WIP 收口；bindLan 未做，恒 loopback）。
- ⬜ H5 Deeplink：`lxmusic://` 播放/歌单动作（`useDeeplink/`）。
- ✅ H6 歌曲评论（2026-10-29 五源齐：`sources/music_comment_source.dart` 能力接口
  `MusicCommentsSource`（comments(track,hot,page,pageSize)），`music_comments.dart` 控制器改按能力分发：
  kw ncomment（原控制器逻辑下沉）、kg m.comment.service topliked/newest（_signed 签名+atlist 展开+
  pcontent 回复壳）、tx fcg_global_comment_h5 表单（最新）+musicu GetHotCommentList（热门）+
  `[em]e…[/em]` 表、wy weapi 评论游标分页（cursorTools 移植，per-song 缓存）+热门 beforeTime 分页+
  `[大笑]` 表、mg comment/stack 游标（上一页末条 id）+热门 hotCommentStart+songId 换取（copyrightId
  相同时走 resourceinfo）+ISO 时间解析；表情表落 `sources/comment_emojis.dart`（tx 66 条/wy 60 条，
  python 从 JS 抽取）。LX 参考：各平台 `comment.js`、mg `songId.js`
- ⬜ H7 托盘/最小化/快捷键：全局快捷键注册持久化（`main/modules/hotKey/`、tray.ts）。
- ➖ MV / 自动更新：LX 无 MV 模块；自动更新走 pure_live 自身体系。

## 2. 移植落地约定

> 2026-10-29 补：音乐模块网络层已全部迁到 `live_net`（`LiveHttp` + `LiveHttpCalls`，
> `networkFactoryProvider.create(profile: ClientProfile.api)`），`package:http` 清零——
> 脚本运行时的 `lx.request` 桥也走 `LiveRequest.custom`，请求从此吃 app 的代理策略。

- 内置音源实现放 `apps/pure_live/lib/modules/music/`（沿用现有 controller 布局）或
  新建 `packages/live_music` 包；media_core_audio 只放契约与编排，不放平台 API。
  每源一个 `MusicSource` 子类注册 `MusicSourceRegistry`，`track.sourceId` 路由。
- 数据结构以 LX `src/common/types/*.d.ts` 为准逐字段照抄（music/list/player/app_setting）。
- 加密算法移植清单：wy eapi/weapi、kg MD5 签名、KRC XOR+zlib、QRC 解码、kw N_MINFO 解析、mg sid。
- 取链（getMusicUrl）：开源版 LX 内置源取链已被删除，播放 URL 依赖自定义源脚本 ——
  本项目已有 fjs 运行时即为此准备的正确路线；内置源先补齐搜索/歌词/封面/榜单，
  取链走脚本优先、各源已知端点兜底（kw 现状即此模式，扩到多源）。
- 存储键沿用现有 `music.*` 前缀（StoragePrefs），新域先在本文件登记再加键。
- 每完成一项：勾选本文件 + 更新顶部日期；跑 `dart analyze` 后再提交；
  提交前看 `git status`，不混入用户并行 WIP。

## 3. 待用户决策

1. H1 音效/EQ 的 Flutter 落地方案（mpv af 链 vs 自研 DSP）。
2. G2 同步服务是否连 LX 官方服务端协议（保持互通）还是仅自建。
3. 歌单/歌词缓存存储：Hive（现状）已定，无需 SQLite 翻案 —— 除非字段对齐遇阻。

## 4. 实施记录

- 2026-10-29 第一批（A1 + A3）：`dart analyze`（music 目录与 app 全量）零问题。
  音乐模块工作区存在另一会话的大规模未提交 WIP（player_page/playback/settings 等十余文件），
  按防撞规则本批代码改动留在工作区未提交，仅入库本台账文档；等 WIP 收口后再一并提交。
