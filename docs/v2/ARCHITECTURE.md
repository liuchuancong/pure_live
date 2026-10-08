# pure_live v2 架构文档(决策稿 v0.6)

> 状态:**推荐定稿(业务架构 + 能力分解)**。v0.5 → v0.6:补上**业务架构**——产品模块、六条关键业务流、以及把直播业务的真实规则(链接到期换链、登录态过期、分享直达、聚合 Feed)落进插件契约与包职责。**83 包 + app**。未写业务代码。
> 分支:`v2`。已定:firebase 保留;背景系统独立;33 站一站一包(B 站拆 live/vod);repository/UI 分包。

## 1. 分解方法

media_core 的 26 包按**能力种类**拆:每引擎一包、每播放能力一包、平台特定一包、横切一包。v2 对整个 App 应用同一方法,并新增一层"业务架构"先行(§2):先画产品模块与业务流,再让每个包在流里领到职责,最后才是目录。**包是业务流的骨架,不是文件柜。**

## 2. 业务架构(先于目录)

### 2.1 产品模块(用户视角)

| 产品模块 | 内容 | 承载包 |
|---|---|---|
| 首页 | 推荐 Feed / 关注 / 直播分类 / 我的入口 | pure_live_home + feed |
| 直播房间 | 播放 + 弹幕 + 清晰度线路 + 表情 + 多画面/小窗 | live + player_ui + danmaku + media |
| 点播(B 站视频) | 目录/详情/选集/连播/评论 | source_bilibili_vod + vod_repository + vod |
| 音乐 | 搜索/歌单/队列/歌词/音源 | source_music_builtin + music_repository + playlist + lyric |
| IPTV | m3u 导入(含拖拽)/EPG/频道管理/udpxy 组播 | iptv_repository + iptv + files |
| 录像 | 录制/分段/本地播放(短视频式) | recorder_repository + recorder |
| 搜索 | 跨源聚合搜索 | search |
| 我的 | 历史/收藏/账号/备份同步/设置/主题/插件 | history/favorites/account/settings/backup_ui/theme/plugin_host |
| 生态入口 | 插件源导入、主题导入、首页模块编排 | plugin_host/theme/home |

### 2.2 六条关键业务流(每条标注涉及包)

1. **冷启动流**:`platform`(深链接/intent 分发)→ `storage`(会话恢复)→ `release`(更新检查)→ `home`(Feed 装配)→ `l10n`/`theme`/`background`(外观就位)。
2. **观看流(核心循环)**:Feed/分类 → 房间页 → `source` 取流 → `media` 起播 → `danmaku` → **到期前预取换链**(见 §3 契约)→ 清晰度/线路切换(记忆)→ 退出写 `history`。
3. **登录流**:`account` → `source.auth`(扫码/cookie 导入)→ `auth` 凭据入库 → 会话保活 → **过期事件** → 静默续期或重登提示 → 登出走清理(参考 v1 斗鱼会话修复)。
4. **分享流**:外部分享链接/短链 → **`links`**(解析出 源+房间/视频)→ 直达对应页;App 内分享出去 → 生成短链。
5. **同步流**:本地变更(收藏/历史/设置)→ `backup`(快照格式)+ `sync`(firebase / WebDAV / LAN)→ 冲突合并。
6. **插件流**:导入 JS 源/主题文件 → `plugin_host` 权限裁决 → 注册 → 目录与主题列表即时出现;首页模块可由用户增删(`home`)。

### 2.3 播放稳定性是第一业务(契约里落地,不是口号)

斗鱼 #35 断流问题的业务本质:**所有站的取流链接都有 TTL**。v2 把它做成契约能力,所有源免费获得:

```
StreamTicket {
  urls: 备选线路列表, expiryAt: DateTime,   // 宿主按 expiryAt 提前调度换链
  quality / line, relink(换链是否需要关键帧接续)
}
LiveCapability.resolveStream(room, quality) → StreamTicket
宿主策略:到期前 T-45s 后台预取 → 关键帧处无缝接续(#35 模式);换链失败回退自动重连
```

其余业务规则落点:清晰度/线路按"平台×房间"记忆(settings_repository);登录态过期事件由 auth 统一广播;IPTV 的 udpxy 组播中继(iptv_repository);录制的分段时钟与磁盘满诊断(recorder_repository);Feed 分页 cursor 约定(plugin_api)。

## 3. 包清单(83 + app,7 层)

### 3.1 foundation(L0,11 包)
utils(公用方法/Result)、logging(talker)、network(dio/拦截器/cookie/UA 池/gbk)、auth(凭据保险箱+会话生命周期+过期事件)、storage(kv/db/secure 三面)、files(文件处理器)、platform(窗口/托盘/深链接/dpad/分享接入/亮度音量电池)、backup(备份引擎)、sync(多设备持续同步)、release(版本检查)、l10n(多语言装配)。

### 3.2 integrations(L0.5,2 包)
firebase(firebase_core/auth/firestore/crashlytics,**保留**)、media(media_core 接线:引擎装配/选择、mpv 调优、wakelock/audio_session/mediasession)。

### 3.3 ecosystem(L1,5 包)
plugin_api(源插件契约+契约测试,独立 semver)、plugin_host(flutter_js 沙箱+注册表/权限/生命周期)、theme(主题引擎:令牌文件导入导出)、background(背景系统:视频/纯色/图片/渐变+画布层级+页面规则+随机壁纸 API,参考 TV features/wallpaper)、danmaku(弹幕层)。

### 3.4 services(L2,10 包)——跨域能力
`pure_live_search`(聚合搜索)、`pure_live_history`(跨域历史)、`pure_live_favorites`(收藏)、`pure_live_playlist`(播放队列)、`pure_live_remote`(LAN 远控 web_remote)、`pure_live_cast`(DLNA 投屏)、`pure_live_fonts`(字体仓库)、`pure_live_emote`(直播表情包)、**`pure_live_links`**(分享链接/短链/深链接 → 源+内容解析与路由)、**`pure_live_feed`**(聚合推荐流:多源 FeedPage 编排/分页/去重)。

### 3.5 ui(L3,5 包)
design(设计令牌权威)、ui_kit(组件库,唯一 import wind)、adaptive(TV/手机/桌面)、lyric(歌词组件)、player_ui(播放器控制层/手势/清晰度线路菜单)。

### 3.6 sources(L5,35 包)——一站一包,B 站双包
source_acfun、source_baidulive、source_bigo、**source_bilibili_live**、**source_bilibili_vod**、source_cc、source_chzzk、source_douyin、source_douyu、source_fc2live、source_huya、source_inke、source_jdlive、source_kilakila、source_kuaishou、source_kugoulive、source_liveme、source_looklive、source_missevan、source_niconico、source_pandalive、source_picarto、source_seventeenlive、source_showroom、source_sixroom、source_soop、source_steambroadcast、source_tiktok、source_twitcasting、source_twitch、source_weibo、source_xiaohongshu、source_youtube、source_yy、source_music_builtin。

### 3.7 features(L4,15 包)——repository / UI 分包
repository:live / vod / music / iptv / recorder / settings(纯 Dart 可单测,TV 壳可复用)。
UI:live、vod、music、iptv、recorder、settings、account、backup_ui、home。

**合计 83 包 + app 壳**(唯一全知层,组合根)。

## 4. 依赖规则(护栏 `tool/check_architecture.dart`)

- 分层单向:L0 无内部依赖(utils/logging 为叶子);integrations→L0;L1→L0;services→L0+plugin_api;ui→L0+theme(ui_kit→design);sources→L0+plugin_api 且同层禁互依;features:repository→L0+plugin_api+services,UI 包→本域 repository+services+ui+ecosystem,同层禁互依;app→全部。
- 每包单一 barrel;业务禁 import wind(仅 ui_kit);禁直接 import 厂商 SDK(仅 integrations)。
- **显式例外清单**:danmaku→media(时钟)、background→media(视频背景)、sync→firebase、backup→auth、player_ui→media、links→platform(深链接入口)、feed→media_core_feed 内核。

## 5. 工程化保障

ADR(`docs/v2/adr/`)、`tool/scaffold_package.ps1` 脚手架、每包 README+CI、契约测试(plugin_api contract_test:内置源与 JS 源同断言集)、**fixtures 快照**(每 source 包录制真实响应,离线断言——33 个站会持续改协议,这是长期维护的生命线)、melos lockstep、生成物折中(drift/hive 入库,riverpod/freezed CI 生成)、DI 仅 app override。

**剧本**:加直播平台 = scaffold → 实现 LiveCapability(协议词典 v1/TV)→ 录 fixtures → 契约测试 → 注册,**零外部包改动**;加内容形态 = plugin_api 加 capability → sources → repository → feature UI → app 挂路由。

## 6. 路线图(waves,按业务优先级:播放稳定性 > 源覆盖 > 扩展域 > 生态)

| 波 | 内容 | 完成标志 |
|---|---|---|
| W0 ✅ | pubspec 现代化 + 本文档 | — |
| W1 | melos 化 + 83 包骨架(脚手架)+ 护栏 + plugin_api 契约 v0(**含 StreamTicket 到期换链语义**) | melos analyze 绿;护栏进 CI |
| W2 | foundation 11 包实做(auth/storage/network 先行) | 单测绿 |
| W3 | integrations + theme/background/danmaku + ui 5 包 + app 壳 | 全平台启动;三类背景;用户主题导入 |
| W4 | plugin_host + JS demo 插件 | 插件全流程 |
| W5 | source_bilibili_live + **media 到期换链宿主策略** + 真机播放 | 第一源跑通,断流防护生效 |
| W6 | 其余 34 源 + live_repository + pure_live_live + feed + history + favorites | 直播域业务闭环 |
| W7 | source_bilibili_vod + vod 域 + links(分享直达) | B 站视频可播;分享链接直达 |
| W8 | music 域(参考 lx-music)+ playlist + lyric | 音乐可播 |
| W9 | iptv / recorder / search / remote / cast / fonts / emote / settings / account / backup_ui / home / release / 迁移器 | 功能齐 |
| W10 | 生态打磨(JS SDK 文档/示例/评估 lx 源兼容);v1 lib 清零 | v2 首版发布 |

## 7. 决策状态

已定:firebase 保留;背景独立包(视频/纯色/图片/渐变);33 站一站一包、B 站拆双包;repository/UI 分包;插件仅 JS;app 壳留仓库根;**StreamTicket 到期换链进契约**。

待确认(2):① theme 文件格式(zip:manifest+令牌+资源引用);② v1 数据迁移器(W9 一次性)。

## 附录 A:v2 pubspec 差异(同 v0.1 §5)
## 附录 B:wind 快速上手(同 v0.1 附录 B)
