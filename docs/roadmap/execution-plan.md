# v2 执行计划(权威版)

> 本文是唯一的执行顺序基准:模块 → 架构 → 一步一步干什么。
> 依据:ADR 0022(多 App)、application-portfolio.md(四 App 需求边界)、
> technical-architecture.md(技术方案)、packages/README.md(模块目录)、
> spider-runtime-requirements.md(spider 兼容需求)。
> 与旧 W0-W12 波次冲突处,以本文为准。每完成一步打勾并回填提交号。

## 0. 当前基线(2026-10-10)

- 57 包,护栏 0 错,analyze 全绿;foundation 回归 52 测绿。
- apps/pure_live:直播软件可用骨架(媒体链/看门狗换源/媒体会话/连播/历史收藏/三内置源:
  demo 种子 + bilibili vod + huya)。插件系统代码已从壳删除。
- packages 全部实装:features ×10 domain+data;ui ×5(design/adaptive/ui_kit/lyric/player_ui);
  providers music(lx 宿主)/iptv/bilibili 实装。
- 本地领先 origin/v2 多个提交(网络故障未推)——恢复网络后第一件事推送。

## 1. 模块架构(定稿)

```
apps/
  pure_live   直播(native 站点:huya/douyu/bilibili-live + demo 种子)
  pure_bili   B站视频(newBV 协议;bilibili vod 源复用)
  pure_music  音乐(lx 音源脚本 + bmsc 式 B站音源/歌单)
  pure_tvbox  TVBox(导入即运行:JS/Py spider + 单仓多仓/M3U/EPG)
packages/
  foundation ×14   storage/network/cache/files/auth/backup/sync/release/l10n/...
  integrations ×3  media(内核+ingest+mediasession+控制面)/python_runtime/firebase
  ecosystem ×12    capability/extension/permission/task/resolver/identity/platform/
                   plugin_api/plugin_host/js_runtime/external_tvbox(+spider 契约)
  services ×6      favorites/history/playlist/search/feed
  features ×10     四域业务 domain+data(presentation=UI 波)
  providers ×11    music(lx)/iptv/bilibili/live 站点适配 + 空骨架按需填
  ui ×5            design/adaptive/ui_kit/lyric/player_ui
```

约束(护栏强制):App 互不依赖;每 App 自己的组合根;包禁 import App;
providers 同层禁互依(例外表);ui 禁依赖 features/providers。

## 2. 执行步骤(按依赖序;✅=已完成,▶=当前,☐=待做)

### 阶段 A:直播 App 收口(pure_live,最高优先)

- ✅ A1 媒体链:内核接线/看门狗换源/媒体会话/连播/历史/收藏(c8f30b45e 前)
- ✅ A2 huya 站点源(355 行,feed/browse/search/resolve + antiCode)
- ✅ A3 bilibili vod 源(WBI/popular/search/detail/playurl)
- ▶ A4 **bilibili live 源**:bilibili_live_source.dart 已写未验证(API 形态按 newBV+simple_live 盘点);
  需真实数据回归(可本机:纯 Dart 网络代码)
- ☐ A5 douyu 源:getEncryption 签名链纯 Dart 移植(协议已盘点,351 行参考)
- ☐ A6 douyin 源:webid+X-Bogus 签名(**需 JS 沙箱跑签名脚本**——fjs 的第一个真实用途)
- ☐ A7 弹幕能力:先定 DanmakuCapability 契约(§9.2 需求清单),再逐站实现
  (bilibili protobuf-ws / douyu TCP 封包 / huya WS——v1 参考线全有)
- ☐ A8 直播 App 真机构测(Android + Windows Debug):六风格切换/换源/弹幕/历史收藏

### 阶段 B:B站视频 App(pure_bili)

- ☐ B1 建 apps/pure_bili(复用 providers/bilibili vod 源 + features/vod + integrations/media)
- ☐ B2 信息流/详情/剧集/播放接通(reuse 房间页模式)
- ☐ B3 登录(QR 扫码+Cookie)→ 高清画质/收藏/历史/心跳
- ☐ B4 弹幕渲染(只读;seg.so protobuf)
- ☐ B5 字幕/PGC 番剧(按需)

### 阶段 C:音乐 App(pure_music)

- ☐ C1 建 apps/pure_music(复用 providers/music lx 宿主 + features/music 队列)
- ☐ C2 lx 音源脚本导入/校验/启停(不可信输入处理)
- ☐ C3 歌单导入(网易云 ID → 曲目表,bmsc music_provider 参考)
- ☐ C4 歌词同步(LyricsSurface)+ 后台播放(已有媒体会话)

### 阶段 D:TVBox App(pure_tvbox)

- ☐ D1 建 apps/pure_tvbox(复用 external_tvbox 解析 + js/py spider 宿主 + features/iptv)
- ☐ D2 本地 HTTP 代理服务(js2Proxy/localProxy 回调底座;纯 dart:io)
- ☐ D3 spider jar(zip)解包装载
- ☐ D4 fjs 同步桥调研(drpy 同步 req 阻塞项,spider-runtime-requirements §4)
- ☐ D5 插件管理/诊断页迁移到本 App

### 阶段 E:UI 层收口(最后)

- ☐ E1 ui_kit 组件补全 + 各 App presentation 迁入 features presentation
- ☐ E2 六风格变体打磨 + TV 风格条目(dpad/overscan)
- ☐ E3 easy_localization 接线(zh/en JSON 已在资产)

### 阶段 F:发布

- ☐ F1 四 App 分别出 Android/Windows 包(build_local_release 扩展多 App 目标)
- ☐ F2 真机回归矩阵

## 3. 横切纪律(每步都适用)

- 每步:analyze → 护栏 --strict → 受影响回归 → 独立提交(不推送,用户自推)。
- 站点协议一律从参考线移植为新实现,不入上游文件(UPSTREAM_REVIEW_POLICY)。
- 外部输入(配置/脚本/响应)按不可信处理:大小/格式/权限校验先于执行。
- UI 永远最后;domain/data 先行并有测试或真数据验证。
