# pure_live v2 架构文档(决策稿 v0.4)

> 状态:**推荐定稿(大型项目颗粒度)**。v0.3 → v0.4:**firebase 保留**并独立成包;**背景系统独立成包**(视频/纯色/图片,参考 pure_live_TV features/wallpaper 与 v1 wallpaper 域);sources 细分到**全部 33 站一站一包**;新增治理机制(ADR / 包脚手架 / 每包 CI)。未写业务代码。
> 分支:`v2`。

## 1. 四条铁律 + 大型项目治理

经验铁律(同 v0.3):federated 契约(flutter/packages)/ 域内 data-domain-presentation 且"第二消费方才拆包"(VGV)/ core 与壳分离可多端复用(simple_live)/ 单一 barrel + example 验证(media_core)。

大型项目治理机制(新增):

1. **ADR(架构决策记录)**:`docs/v2/adr/NNN-<决策名>.md`,每个不可逆/跨包决策一篇(背景格式、插件契约版本策略、存储选型……)。改架构先改 ADR 再改代码。
2. **包脚手架**:`tool/scaffold_package.ps1 <层>/<包名>` —— 从模板生成 pubspec + barrel + 占位 test + CI 片段,保证 63 个包结构零漂移。
3. **每包 CI 矩阵**:melos 按包过滤 analyze/test;护栏脚本 `tool/check_architecture.dart` 按 §4 规则机械报错。
4. **包准入/晋升**:新能力先进目录 → 超 ~800 行或出现第二消费方 → 升包(走 ADR)。

## 2. 包清单(63 包,全枚举)

### 2.1 foundation(L0,10 包)——基础设施,不认识任何业务

| 包 | 职责(装什么) |
|---|---|
| `pure_live_utils` | 公用方法:时间/数字/文本(拼音、模糊匹配)/编解码/hash/Result 类型 |
| `pure_live_logging` | talker 装配、分级、诊断导出 |
| `pure_live_network` | dio 客户端工厂、拦截器(风控头/UA/重试)、cookie 持久化、gbk 转码、dio→talker 日志 |
| `pure_live_auth` | 凭据保险箱(secure_storage)、会话生命周期、登录流程状态机契约;不实现任何站点登录 |
| `pure_live_storage` | 存储三面:kv(hive_ce)/ db(drift+drift_flutter)/ secure(secure_storage)+ 缓存目录策略 |
| `pure_live_files` | 文件处理器:pick/拖拽、m3u/json 读写、Saf、哈希校验、临时目录 |
| `pure_live_platform` | 平台处理:窗口/托盘/协议注册/深链接(app_links)/TV dpad/分享接入/亮度音量电池 |
| `pure_live_backup` | 备份引擎:版本化格式、导出导入、WebDAV/LAN(bonsoir)同步、合并策略 |
| `pure_live_release` | 版本更新:version.json/releases.json 消费、版本比较、更新提示逻辑 |
| `pure_live_l10n` | 多语言装配:easy_localization 初始化、语言包加载、回退策略 |

### 2.2 integrations(L0.5,2 包)——第三方大件集成

| 包 | 职责 |
|---|---|
| `pure_live_firebase` | firebase_core/auth/firestore 装配(**已拍板保留**):登录后端、云同步数据面、crashlytics 崩溃收集;CI Windows 预取继续生效 |
| `pure_live_media` | media_core 接线层:引擎装配与选择、mpv 调优参数、wakelock/audio_session/mediasession 挂接——v1 `core/player/kernel` 的重写位 |

### 2.3 capabilities(L1,5 包)——横切能力

| 包 | 职责 |
|---|---|
| `pure_live_plugin_api` | 源插件契约(Live/Vod/Music capability、HostBridge、ThemeTokenFile)+ 契约测试套件;生态接口,独立 semver |
| `pure_live_plugin_host` | flutter_js 沙箱桥(仓库已 vendored AGP9 补丁)、插件注册表/生命周期/权限裁决、内置源加载器 |
| `pure_live_theme` | 主题引擎:令牌文件 schema/校验、令牌 → WindThemeData + Material ColorScheme、导入导出 |
| `pure_live_background` | **背景系统**:视频/纯色/图片(+模糊/暗化)背景、画布层级、按页面显示规则、随机壁纸 API 源、用户资源导入。协议参考 TV `features/wallpaper`(wallpaper_api_source/display_options/route_observer)与 v1 wallpaper 域 |
| `pure_live_danmaku` | 弹幕层:flame_barrage 接线、弹幕设置(速度/透明度/屏蔽词)、滚动/顶部/底部样式、撤回显示 |

### 2.4 sources(L2,34 包)——全部一站一包

`source_acfun`、`source_baidulive`、`source_bigo`、`source_bilibili`(live+vod 双 capability)、`source_cc`、`source_chzzk`、`source_douyin`、`source_douyu`、`source_fc2live`、`source_huya`、`source_inke`、`source_jdlive`、`source_kilakila`、`source_kuaishou`、`source_kugoulive`、`source_liveme`、`source_looklive`、`source_missevan`、`source_niconico`、`source_pandalive`、`source_picarto`、`source_seventeenlive`、`source_showroom`、`source_sixroom`、`source_soop`、`source_steambroadcast`、`source_tiktok`、`source_twitcasting`、`source_twitch`、`source_weibo`、`source_xiaohongshu`、`source_youtube`、`source_yy`、`source_music_builtin`(内置音乐音源样例)。

每包内容:`lib/src/{live|vod|music|auth|models}` + `test/fixtures/`(录制的 HTTP 快照)。一站一包的成本由脚手架摊平;协议词典是 v1 `lib/shared/platforms` 与 TV `lib/platforms`。

### 2.5 ui(L3,3 包)

| 包 | 职责 |
|---|---|
| `pure_live_design` | 设计令牌唯一权威(纯数据,零 widget);明暗默认两套;消费 theme 令牌覆盖 |
| `pure_live_ui_kit` | 组件库(LiveRoomCard/PlayerControlBar/SettingSection/EmptyPlaceholder…);**唯一 import fluttersdk_wind 处** |
| `pure_live_adaptive` | TV(dpad 焦点树)/手机/桌面( hover/滚轮)布局策略与断点 |

### 2.6 features(L4,9 包)——域内 data/domain/presentation 分层

`pure_live_live`、`pure_live_vod`、`pure_live_music`、`pure_live_iptv`、`pure_live_recorder`、`pure_live_settings`、`pure_live_account`(账号管理 UI:各平台登录态/资料/登出)、`pure_live_backup_ui`、`pure_live_home`(首页模块编排,用户可定制)。

### 2.7 app 壳

`app/`:ProviderScope 组合根(Riverpod overrides 装配各包实现)+ go_router 装配(各 feature 暴露 RouteBase 列表)+ 平台初始化序列。**唯一全知层,零业务**。平台目录(android/ios/windows/linux/macos)留仓库根。

## 3. 包内模板(四类,脚手架按此生成)

见 v0.3 §3,不重复;新增两类:
- **integrations 模板**:`lib/src/<厂商>/` 分厂商目录,barrel 只导出应用侧抽象(如 `AuthBackend`、`MediaKernelFactory`),厂商 SDK 类型不外泄;
- **background 模板**:`lib/src/{types(视频/纯色/图片)/canvas(画布层级)/rules(页面规则)/sources(随机壁纸 API)/import(用户资源)}`。

## 4. 依赖规则(护栏脚本按此校验)

**分层通则**(机械可查):
- L0 互不依赖、不认识 L1+;L1 只依赖 L0;integrations 只依赖 L0;L2 只依赖 L0+`plugin_api`,**同层禁止互依**;L3 只依赖 L0+`theme`;L4 只依赖 L0+L1+L2(仅经 plugin_api 类型)+L3,**同层禁止互依**;`app` 依赖一切。
- 每包单一 barrel;业务代码禁 import wind(只有 ui_kit);业务代码禁直接 import 厂商 SDK(只有 integrations)。

**例外清单**(显式登记,护栏白名单):
- `pure_live_danmaku` → `pure_live_media`(弹幕时间轴跟播放器时钟);
- `pure_live_background` → `pure_live_media`(视频背景用播放器);
- `pure_live_backup` → `pure_live_auth`(同步凭据)、`pure_live_firebase`(云同步面)。

## 5. 背景系统专项(你点名的,独立成节)

- **类型**:`video`(循环/静音/跟随播放)/`image`(在线或本地)/`solid`(纯色)/`gradient`;叠加暗化/模糊/饱和度调节保证前景可读。
- **画布层级**:背景层在 navigator 之下(继承 v1 的 AppBackgroundLayer 画布机制);页面通过"透明画布区域"局部透出。
- **页面规则**:按路由声明背景策略(直播页纯色低干扰 / 设置页图片 / 全局默认),规则可被用户主题覆盖。
- **资源来源**:打包内置(`assets/images/video/`、`assets/images/`)、随机壁纸 API 源(参考 TV `wallpaper_api_source`)、**用户导入**(走 files 包,进 storage 管理)。
- **与主题的关系**:主题文件引用背景资源 id;背景系统负责把 id 解析成实际画布。
- **性能红线**:视频背景在低性能设备自动降级为图片/纯色(adaptive 提供策略)。

## 6. 工程化保障

承 v0.3 §5(契约测试、fixtures、melos lockstep、生成物折中:drift/hive 入库、riverpod/freezed CI 生成、DI 仅 app 可 override),新增:
- ADR 机制(§1);
- `tool/scaffold_package.ps1` 脚手架(63 包零漂移);
- 每包 README(职责一句话 + 允许依赖 + 不允许依赖);
- `melos run gen/analyze/test/fix` + 按包过滤。

## 7. 路线图(waves)

| 波 | 内容 | 完成标志 |
|---|---|---|
| W0 ✅ | pubspec 现代化 + 本文档 | — |
| W1 | melos 化 + **63 包骨架**(脚手架生成)+ check_architecture 护栏 + plugin_api 契约 v0 | melos analyze 绿;护栏进 CI |
| W2 | foundation 10 包实做(utils/network/logging/auth/storage 先行) | 单测绿 |
| W3 | integrations(media/firebase)+ capabilities(design/theme/background/danmaku)+ ui_kit 首批 + app 壳 | 全平台启动;视频/纯色/图片背景可切;用户主题可导入 |
| W4 | plugin_host 沙箱 + JS demo 插件 | 插件导入/请求/禁用全流程 |
| W5 | source_bilibili(live)契约测试 + 真机播放 | 第一个源跑通 |
| W6 | 其余 32 站源(脚手架批量)+ live 域 | 直播域可用 |
| W7 | vod 域(协议词典:TV modules/vod) | B 站视频可播 |
| W8 | music 域(source_music_builtin + 域,参考 lx-music) | 音乐可播 |
| W9 | iptv / recorder / backup / settings / account / home + release + v1 数据迁移器 | 功能齐 |
| W10 | 生态打磨:JS SDK 文档、示例插件、(评估)lx 源兼容;v1 lib 清零 | v2 首版发布 |

## 8. 决策状态

已定:firebase **保留**(§2.2);背景系统独立成包、三类背景(§5);33 站一站一包;域包内分层不预拆 repository;插件只支持 JS;app 壳留仓库根。

仍待你确认(2 项):
1. **theme 文件格式**:zip(manifest + 令牌 JSON + 壁纸/背景资源引用)——建议就这么定;
2. **v1 数据迁移器**:W9 做一次性迁移(hive → 新存储),老用户收藏/配置不丢——建议做。

## 附录 A:v2 pubspec 差异(同 v0.1 §5)
## 附录 B:wind 快速上手(同 v0.1 附录 B)
