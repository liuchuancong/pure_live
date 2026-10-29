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
- 🟨 A2 kw 酷我补齐（搜索/歌词/榜单/封面地址已齐，`getMusicInfo` 详情接口未接）：搜索 `http://search.kuwo.cn/r.s?client=kt&all=...`（解析 `N_MINFO`，
  bitrate 4000→flac24bit/2000→flac/320/128）、歌曲信息 `api/www/music/musicInfo?mid=`、
  封面 `artistpicserver.kuwo.cn/pic.web`、榜单 bangid 硬编码表（93 飙升/16 热歌…）。
  LX 参考：`musicSdk/kw/{musicSearch,index,lyric,pic,leaderboard}.js`
- 🟨 A3 kg 酷狗（2026-10-29 搜索/榜单/歌词已接 `music_source_kg.dart`；KRC 逐字解码归 D2，
  现优先选 LRC 候选、取链仅脚本）：搜索 `songsearch.kugou.com/song_search_v2?platform=AndroidFilter`；
  签名 `signatureParams` = MD5(key+排序参数+body+key)，key=`OIlwieks28dk2k092lksi2UIkp`(android)/
  `NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt`(web)；歌词两步（search→download，fmt=krc|lrc）。
  LX 参考：`musicSdk/kg/*`、`kg/util.js`
- 🟨 A4 tx QQ（2026-10-29 搜索/榜单/封面已接 `music_source_tx.dart`，zzcSign SHA1 签名移植；
  QRC 歌词解码归 D2，暂不返回歌词）：POST `u.y.qq.com/cgi-bin/musicu.fcg`（module `music.pf_song_detail_svr`），
  音质从 `file.size_128mp3/320mp3/flac/hires` 推导；封面拼
  `y.gtimg.cn/music/photo_new/T002R500x500M000{albumMid}.jpg`；歌词 qrc:1,trans:1 + QRC 解码。
  LX 参考：`musicSdk/tx/*`、`tx/qrcDecode.js`
- 🟨 A5 wy 网易（2026-10-29 搜索/榜单/歌词已接 `music_source_wy.dart`，`wy_crypto.dart` 移植
  eapi/weapi：AES-128-CBC/ECB(pointycastle PKCS7) + RSA NoPadding（公钥 n/e 已硬编码）；
  yrc 逐字合成归 D2）：eapi/weapi 加密（AES-128-CBC 双层 + RSA / eapi=
  MD5("nobody{url}use{text}md5forencrypt")+AES-128-ECB，key=`e82ckenh8dichen8`，iv=`0102030405060708`）；
  搜索 `/api/search/song/list/page`、详情 `weapi/v3/song/detail`、歌词 `/api/song/lyric/v1`
  （返回 lyric/tlyric/romalrc + yrc 逐字合成 lx 逐字格式）。
  LX 参考：`musicSdk/wy/*`、`wy/utils/crypto.js`
- ⬜ A6 mg 咪咕：搜索 `jadeite.migu.cn/music_search/v3/search/searchAll?...&sid=USS`、
  信息 `c.musicapp.migu.cn/.../resourceinfo.do`（copyrightId 为键）、榜单
  `app.c.nf.migu.cn/pc/bmw/rank/rank-index/v1.0`；MRC 逐字（`mg/utils/mrc.js`）。
- ⬜ A7 换源匹配 `findMusic`：歌名+歌手+专辑归一化（含 `versionChars.ts` 版本后缀处理
  Live/Remix）+ 时长 ±5s 匹配；`meta.toggleMusicInfo` 优先取链、失败回落本源。
  LX 参考：`musicSdk/index.js findMusic`、`core/player/action.ts getMusicPlayUrl`
- ⬜ A8 热搜/搜索建议：各源 `hotSearch.js`、`tipSearch.js`。
- ➖ bd 百度 / xm 虾米：LX 中已注释/排除，不移植。

### B. 自定义源（user api）
- ✅ B1 fjs 脚本运行时：`lx.on('request')/lx.send('inited')/lx.request/lx.utils` 契约已通
  （`controller/lx_script_runtime.dart` + `lx_script_prelude.dart`）。
- ⬜ B2 对齐 LX 细节：脚本头注释解析 `@name/@description/@author/@homepage/@version`
  （正则 `/^\s?\*\s?@(\w+)\s(.+)$/`）、id 规则 `user_api_XXX_时间戳`、脚本 deflate+base64
  `gz_` 前缀存储（保持导入兼容）；`lx.request` 需支持 method/timeout/headers/body/form/formData
  与代理设置透传。LX 参考：`src/main/modules/userApi/{utils,main}.ts`、`preload.js`、
  `store/apiSource.ts`、`core/useApp/useInitUserApi.ts`

### C. 播放核心状态机
- ⬜ C1 队列状态机对齐 `core/player/action.ts`（LX 最核心文件，646 行）：
  下一曲优先级 = tempPlayList（稍后播，isTop 插队）→ playedList（随机模式历史栈，恢复时清理已删歌）
  → `filterList()` 过滤已播/无效 → 按模式算 nextIndex：
  `listLoop`（尾→0）/`random`（预计算缓存 `randomNextMusicInfo`）/`list`（尾→停止）/`singleLoop`/`none`。
  playPrev 对称。
- ⬜ C2 竞态保护：`diffCurrentMusicInfo()`（比较 gettingUrlId/id/isPlay），换歌并行发起
  URL/封面/歌词三路请求各自防串台。
- ⬜ C3 取链重试策略：`getMusicPlayUrl` 先 toggleMusicInfo 后本源；429 随机 2–6s 延迟重试；
  失败再重试一次；`autoSkipOnError` = 加载超时 100s / 失败 5s 自动下一曲。
- ⬜ C4 进度恢复：`isSavePlayTime` 时恢复到上次位置并暂停待播（现有 `music.playback.positions`
  已有雏形，对齐 LX 的 data store playInfo 结构与暂停语义）。
- ⬜ C5 播放 3s 后预载下一曲 URL（`usePreloadNextMusic.ts`）。
- ⬜ C6 收藏即 LOVE 列表（`LIST_IDS.LOVE='love'`）、`collectMusic/uncollectMusic` 语义。
- ⬜ C7 定时停止 `timeoutStop.ts`（`waitPlayEndStop`）；倍速/`preservesPitch`/媒体设备选择
  （`playbackRate.ts`、`volume.ts`、mediaDeviceId）。

### D. 歌词
- ⬜ D1 歌词门面：缓存（LX 用 SQLite lyric 表；本项目可用 Hive，键含 musicInfo id）→
  未命中在线获取（支持换源）→ 成功写缓存；产出 `{lyric, tlyric, rlyric, lxlyric, rawlrcInfo}`。
  LX 参考：`core/music/{index,online,utils}.ts`、`dbService/modules/lyric`
- ⬜ D2 逐字解码四件套：kg KRC（XOR 密钥 `[0x40,0x47,0x61,0x77,0x5e,0x32,0x74,0x47,0x51,0x36,0x31,0x2d,0xce,0xd2,0x6e,0x69]` + zlib inflate + `[language:base64]` 翻译/音译，`lyricUtils/kg.js`）、
  tx QRC（`qrcDecode.js`）、wy yrc→lx 逐字拼接（`wy/lyric.js`）、mg MRC（`mg/utils/mrc.js`）。
  （media_core_audio 已有 LyricParser LRC/QRC/KRC/YRC 基础，需与 LX 解析行为对齐。）
- ⬜ D3 歌词播放引擎：`lyric-font-player/`（`LinePlayer{offset,rate,onPlay,onSetLyric}`，
  `_findCurLineNum` 增量查找；font-player 逐字版）+ `[offset:]` 标签/手动偏移
  （setOffset/setTempOffset）。
- ⬜ D4 显示开关：isShowLyricTranslation / isShowLyricRoma / isSwapLyricTranslationAndRoma /
  isPlayLxlrc / isS2t 简繁转换。
- ⬜ D5 桌面歌词：LX 用 MessagePort 通道（get_info/set_info/get_status/set_status/
  频谱 analyser 数据）；media_core_audio 已有桌面歌词窗口，对齐数据通道与
  `desktopLyric.*` 设置域（含鼠标穿透 `winLyric/mouseCheckTools.ts`）。

### E. 下载
- ⬜ E1 任务状态机：WAITING/RUNNING/PAUSED/ERROR/COMPLETED + 节流更新（`store/download/action.ts`）。
- ⬜ E2 保存路径与命名：`download.savePath` + 按歌单名分目录开关 + 文件名模板
  （'歌名 - 歌手'|'歌手 - 歌名'|'歌名'）（`store/download/utils.ts buildSavePath`）。
- ⬜ E3 元数据写入：FLAC/MP3 写标题/歌手/专辑/封面/歌词（`common/utils/musicMeta/`）。
- ⬜ E4 下载取链复用播放取链（含换源）；kg 歌词时间标签修复 `fixKgLyric`。
- ⬜ E5 下载列表持久化（LX: dbService/download 表）。

### F. 歌单/收藏
- ⬜ F1 数据模型对齐 `src/common/types/list.d.ts` + `music.d.ts`：
  `MusicInfo{id,name,singer,source,interval,meta:{albumId,albumName,picUrl,quickSearch?,toggleMusicInfo?}}`；
  LIST_IDS = default/love/temp/download。
- ⬜ F2 表结构对齐 `dbService/tables.ts`：`my_list{id,name,source,sourceListId,position,locationUpdateTime}`、
  `my_list_music_info{...UNIQUE(id,listId)}`、`my_list_music_info_order{listId,musicInfoId,order}`。
  本项目按 Hive 惯例落地但字段语义一致。
- ⬜ F3 操作全集（`rendererListManage.ts`）：getUserLists/createUserList/removeUserList/
  updateUserListPosition/getListMusics/addListMusics（去重）/moveListMusics/overwriteListFull/
  checkListExistMusic/getMusicExistListIds。
- ⬜ F4 不喜欢列表（`store/dislikeList/`，已有雏形 `music_dislikes.dart`，对齐结构）。
- ⬜ F5 备份/迁移：部分歌单/仅设置/全量三档导出导入；导出歌单为文本/CSV
  （`SettingBackup.vue`、`migrateSetting.ts`）。对接现有 backup 域。
- ⬜ F6 在线歌单（收藏夹）导入：各源 `songList.js`。

### G. 设置与同步
- ⬜ G1 设置域对齐 `app_setting.d.ts` 的 key 前缀语义：common./player./desktopLyric./download./
  list./network./odc./openAPI./playDetail./search./sync./theme./tray.；重点 player 键：
  startupAutoPlay/togglePlayMethod/playQuality/volume/playbackRate/preservesPitch/mediaDeviceId/
  歌词五开关/isSavePlayTime/audioVisualization/waitPlayEndStop/autoSkipOnError/soundEffect.*。
  本项目走 `StoragePrefs`（`music_settings.dart` 已有基础）。
- ⬜ G2 同步服务 client：WebSocket `ws://host/socket?i={clientId}&t={aesEncrypt(msgConnect,key)}`、
  close code 重连/认证失败处理、服务端 action 驱动本地变更、本地变更推快照
  （`main/modules/sync/client/*`）。快照机制：md5 去重 + latest 指针 + 历史
  （`server/sync/modules/list/manage.ts`）。

### H. 其他功能
- ⬜ H1 音效/EQ：WebAudio 链 source→analyser→10 段 biquadFilter(31~16000Hz)→pitchShifter→
  (convolver&sourceGain→DynamicsCompressor)→panner(环绕)→gain；预设存 sound_effect store
  （`plugins/player/index.ts`、`store/soundEffect.ts`）。Flutter 侧落地方式待定
  （media_core_audio/mpv 能力评估）。
- ⬜ H2 频谱可视化（AnalyserNode getByteFrequencyData 等价物；桌面歌词共享频谱）。
- ⬜ H3 系统媒体会话：已有 MusicBackgroundBinding（SMTC/MPRIS），对齐 `useMediaSessionInfo.ts` 元数据。
- ⬜ H4 开放 API：本地 HTTP 控制播放（`main/modules/openApi/index.ts`，port/bindLan 设置）。
- ⬜ H5 Deeplink：`lxmusic://` 播放/歌单动作（`useDeeplink/`）。
- ⬜ H6 歌曲评论：各源 `comment.js`（已有 `music_comments.dart`，扩多源）。
- ⬜ H7 托盘/最小化/快捷键：全局快捷键注册持久化（`main/modules/hotKey/`、tray.ts）。
- ➖ MV / 自动更新：LX 无 MV 模块；自动更新走 pure_live 自身体系。

## 2. 移植落地约定

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
