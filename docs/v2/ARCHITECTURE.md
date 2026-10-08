# pure_live v2 架构文档(决策稿 v0.1)

> 状态:**待拍板**。本文只做架构决策材料,未写任何业务代码。
> 分支:`v2`(自 master `e3bb4142f` 分出)。当前分支已落地:pubspec 现代化 + 依赖解析通过;旧 `lib/` 原样保留,删除时机见 §8。
> 参考项目:`pure_live_TV`(B 站视频模块)、`lx-music-mobile/desktop`(音乐域逻辑)、`media_core/packages`(模块化模板)。

## 1. 目标与非目标

**目标**
- 全平台:Android / Android TV / iOS / macOS / Windows / Linux(web 暂不承诺)。
- 模块化:一个能力一个包(仿 media_core),整理与修改代码只需面对单个包。
- UI 换新:fluttersdk_wind 为样式层,Material 3 保留为底座。
- 内容域扩展:直播(v1 全量)+ 点播/B 站视频(参考 TV 的 vod 模块)+ 音乐(参考 lx-music 逻辑)。

**非目标**
- 不移植 lx-music 的 JS 代码(只借鉴结构与逻辑,Flutter 重写)。
- v1 功能不做 100% 一次性平移,按域分批(waves)。

## 2. 总体形态:melos 单仓多包(仿 media_core)

media_core 的做法:`melos.yaml` 工作区 + `packages/<能力>`(26 个包),每个包 `lib/src/` + 单一 barrel 导出,依赖单向声明,`example/` 做集成验证。v2 直接沿用这个形态:

```
pure_live(v2)
├── melos.yaml
├── apps/pure_live/            # 应用壳:main、路由组装、DI、平台目录(android/ios/...留在仓库根或 apps 下,见 §8-7)
├── packages/
│   ├── pure_live_ui/          # UI 基座:wind 主题桥、设计令牌、通用 W 组件封装(唯一允许 import wind 的包)
│   ├── pure_live_core/        # 配置/存储(secure_storage+hive)/网络(dio+talker)/日志底座
│   ├── pure_live_platforms/   # 33 站适配器(v1 lib/shared/platforms 迁移;后续可按站拆)
│   ├── pure_live_live/        # 直播域:目录/播放/收藏/多画面
│   ├── pure_live_vod/         # B 站视频域(参考 TV modules/vod)
│   ├── pure_live_music/       # 音乐域(参考 lx-music)
│   ├── pure_live_recorder/    # 录制域
│   ├── pure_live_iptv/        # IPTV 域
│   └── pure_live_settings/    # 设置/账号/同步/壁纸(可再拆)
```

**与 v1 分层的关系**:v1 是"单包内目录分层"(`lib/{app,core,shared,domains,features}` + `validate_architecture.py` 脚本校验);v2 把"域"升级为包,层间约束由**包依赖图天然保证**,不再依赖脚本。域内继续保留 `domain/data/presentation` 分层(v1 与 TV 的 vod 都是这个形状,见 §6.1)。

**播放/弹幕/录制内核不重写**:直接复用 media_core 的包(`media_core_live/ingest/danmaku/presentation/...`,git 依赖已在 pubspec),v2 的模块只在它们之上做业务。

## 3. UI 架构选型(决策材料)

### 3.1 已实测的 wind 事实(读了 1.8.1 源码,非文档转述)

- 接入方式:`WindTheme(data: WindThemeData(brightness: ...))` 包住 `MaterialApp`;W 组件在无 WindTheme 时会取默认主题。
- 组件:29 个 W 前缀组件(`WDiv/WText/WButton/WCard/WIcon/WInput/WSelect/WPopover/WTabs/WSwitch/WRadio/WBadge/WDatePicker/WSvg/WImage/WSpacer/WBreakpoint` + Form 系列 + 布局辅助),全部吃 `className` 字符串。
- 变体:`dark:` / 断点 `sm:–2xl:` / 交互态 `hover:/focus:/disabled:/loading:/selected:` / 平台 `ios:/android:/web:/mobile:/macos:/windows:/linux:`。
- 主题:`WindThemeData` 24 字段(颜色/间距/字体/阴影/断点/动画),`brightness` 是它的一个字段 → **暗色 = 按 themeMode 切换两份 WindThemeData**(适配层放 `pure_live_ui`,页面无感)。
- 明确不做:transforms、filters、group/peer、容器查询、`@apply`。

### 3.2 建议的 UI 分层(风险缓释)

wind 是 16 小时前发版的 1.x(29 likes),为避免全项目被它绑死:

1. **只有 `pure_live_ui` 允许 `import fluttersdk_wind`**,其余包/页面只 import `pure_live_ui`。
2. 复杂/高频样式收敛为 `pure_live_ui` 里的语义组件(如 `AppCard`、`LiveRoomCard`),页面不裸写长 className。
3. `MaterialApp` 的 `theme/darkTheme`(Material ThemeData)继续存在:对话框、smart_dialog、平台插件仍走 Material;wind 只接管页面布局样式。
4. 若 wind 断供,替换点唯一(pure_live_ui 内部重实现,签名不变)。

### 3.3 备选(供对比,均不推荐为主线)

| 方案 | 结论 |
|---|---|
| 纯 Material 3 深耕 | 最稳,但已由 §5 的主题诊断确认投入大、观感上限受组件库约束 |
| fluent_ui | Windows 观感,放 Android/iOS 错位,不取 |
| TDesign Flutter | 成熟度可,但桌面弱、风格与 TV 端不一致,不取 |
| shadcn_flutter / forui | 0.x 青年期,同 wind 风险且生态更小,不取 |

## 4. 新包评审(fluttersdk_dusk / artisan / telescope / magic_deeplink)

| 包 | 版本/发布日 | 定位(官方描述) | 结论 |
|---|---|---|---|
| fluttersdk_dusk | 0.0.18 / 10-07 | LLM 代理与 CI 的 E2E 驱动器:41 个 CLI 命令 + 39 个 MCP 工具经 VM Service 驱动运行中的 App | **暂不加**。属 AI 开发工具链;等 v2 跑起来后可作为 `dev_dependency` 试点(AI 驱动 E2E 对本项目开发方式有真实价值),0.0.x 不进运行时 |
| fluttersdk_artisan | 0.0.18 / 10-05 | Dart CLI 框架 + stdio MCP server:脚手架/代码生成/插件安装/热重载/REPL | **暂不加**。同上,纯开发期工具,0.0.x |
| fluttersdk_telescope | 0.0.9 / 09-29 | 被动运行时检查器:抓 HTTP/日志/异常/DB 查询,CLI tail + MCP | **暂不加**。观测能力强但仍是 0.0.x dev 工具;爬虫调试短期用 talker_dio_logger 覆盖 |
| magic_deeplink | 0.1.5 / 09-29 | Magic Framework 的深链接(Universal/App Links) | **不加**。依赖未验证的自家 `magic` 框架,与已在 pubspec 的成熟 `app_links ^7.2.1` 功能重复 |

共同风险:四个包同属 fluttersdk 生态、发布 1-2 周内、0.0.x,API 无稳定性承诺。dusk/telescope 列入"观察名单",稳定后(≥0.1 且有真实使用者)再议。

## 5. 依赖现代化(已并入 v2 pubspec,解析通过)

**新增(运行时)**

| 包 | 版本 | 用途 |
|---|---|---|
| flutter_secure_storage | ^11.2.0 | 登录凭据/Cookie 安全存储(替代 hive 明文;全平台) |
| talker_flutter / talker_dio_logger | ^5.1.20 | 日志套件 + dio 请求日志(33 站爬虫调试核心) |
| audio_session | ^0.2.2 | 音频焦点/中断(拔耳机暂停、来电让路) |
| desktop_drop | ^0.6.0 | 桌面拖拽导入(m3u 等) |
| drift_flutter | ^0.3.1 | drift 平台自适应数据库构建 |
| shimmer | ^3.0.0 | 骨架屏 |

**新增(开发)**:riverpod_generator ^4.0.4、riverpod_lint ^3.1.9、freezed ^4.0.2、json_serializable ^6.14.0、go_router_builder ^4.5.0、hive_ce_generator ^1.11.2、flutter_native_splash ^2.4.6

**解析时踩到的版本坑(记录,避免回退)**
- talker 4.x 最高支持 share_plus ^11 → 必须 talker 5.x(我们 share_plus ^13)。
- drift_flutter 0.2.x 要求 sqlite3 ^2,与 drift_dev ≥2.32(sqlite3 ^3)冲突 → 0.3.1。
- riverpod_lint 不存在 4.x,当前线是 3.1.9(配 custom_lint 插件,analysis_options 需启用)。
- flutter_secure_storage 9.x 锁 win32 ^5,与本项目 win32 ^6 冲突 → 11.x。

**旧依赖观察名单**(v1 迁移时逐个评估替换):`date_format`(intl 已覆盖)、`pinyindart 0.0.1`、`move_to_desktop 0.0.2`、`dlna_dart 0.1.0`、`syncfusion_flutter_sliders`(wind/Material Slider 可替)。

**保留决策点**:firebase 三件套仍在 pubspec(参考稿删了它)。留 = CI Windows Firebase 预取与账号同步功能继续可用;弃 = 需同步改 `tool/prefetch_windows_native.ps1` 与 workflow。见 §8-3。

## 6. 参考项目映射

### 6.1 pure_live_TV → vod(B 站视频)与工程组织

TV 端结构:`lib/{app, core, domains, features, modules, platforms, player, services}`,其中 `modules/{live, music, video, vod}`。
**`modules/vod`(88 个 dart 文件)= v2 `pure_live_vod` 的直接母本**:

```
vod/
├── api/        bilibili_api_client / ugc_api / pgc_api / danmaku_api / music_api / lyric_api
├── domain/     providers + repositories
├── models/     comment_item / dynamic_video / fav_folder / history_item / hotword
│               music_archive / music_track / music_play_urls / music_stream_option ...
├── controllers/
├── pages/  └── widgets/
```

迁移动作:整目录抬入 `packages/pure_live_vod`,GET/状态层替换为 Riverpod,freezed/json 模型直接复用(TV 已用 freezed+json 生成)。B 站播放内核走 media_core,不引 TV 的播放器实现。

### 6.2 lx-music → music 域的逻辑参考

- mobile `src/core/`:`apiSource`(自定义音源)、`music/`、`player/`、`search/`、`lyric/`、`leaderboard/`、`songlist/`、`list`(歌单)、`sync`、`userApi`、`dislikeList`、`hotSearch`。
- desktop `src/main/modules/`:Electron 主进程按模块拆分。

映射到 `packages/pure_live_music`:
- **音源 = 适配器抽象**(与 platforms 同构):`MusicSource` 接口 + 内置源;lx 的"自定义源/userApi"机制是否做进 v2 见 §8-5。
- 歌单/收藏/最近播放/同步 → domain 层(repositories),存储走 hive_ce/drift。
- 播放走 media_core(音乐流播 = media_core 已有能力);歌词滚动可评估 `flutter_lyric`。
- 只学结构、协议与交互,**不移植 JS**。

### 6.3 media_core → 工程模板

- `melos.yaml` + 26 包 + 每"能力"一包 + 单 barrel + example 集成验证。
- v2 复用其基础设施(直播/弹幕/录制/PIP/展示层),v2 的包只做业务编排,不重复造内核。

## 7. 路线图(waves,每波可独立提交验证)

| 波 | 内容 | 完成标志 |
|---|---|---|
| W0(已完成) | pubspec 现代化 + 依赖解析通过 | 本文档 + pubspec 在 v2 分支 |
| W1 | melos 化 + 包骨架(pure_live_ui/core/platforms 空包)+ 应用壳跑通全平台启动 | 各平台 `flutter run` 见 wind 首页 |
| W2 | platforms 迁移(33 站,去 GetX 化,cookie/凭据迁 secure_storage) | 平台适配器测试绿 |
| W3 | live 域打通播放(media_core 接线) | 真机看直播 |
| W4 | vod 域(从 TV modules/vod 抬入改造) | B 站视频可播 |
| W5 | music 域(参考 lx-music) | 音乐可播 |
| W6 | recorder / iptv / wallpaper / settings / account 迁移 | — |
| W7 | 删除 v1 lib、CI 切换、首个 v2 发布 | release 绿 |

## 8. 待拍板问题(需要你逐条给方向)

1. **包粒度**:每个域一包(上表 9 包)够吗?还是域内再拆 `*_data`/`*_domain`?(建议:先每域一包,域内保留 data/domain/presentation 目录,像 TV 的 vod 那样)
2. **core 拆分**:单包 `pure_live_core` 还是 `core_config/core_storage/core_network` 三包?(建议:先单包,内部目录分层)
3. **firebase 去留**:v2 保留还是移除?(移除需同步改 Windows 预取脚本;建议 v2 先保留,W6 迁移账号时再定)
4. **wind 触达策略**:严格"只经 pure_live_ui"(替换成本最低)还是允许页面直接用 W 组件(写起来快)?(建议:严格,先苦后甜)
5. **music 自定义音源**:做不做 lx 式 user-api 自定义源机制?(做 = 灵活但多一套插件协议;建议 v2 先内置源,协议留接口)
6. **v1 lib 何时删**:建议 W2 开始"迁完一个域删一个域",W7 清零;还是现在立刻删、逼自己只走新架构?(建议前者,老代码是最好的迁移素材库)
7. **平台目录位置**:android/ios/... 留在仓库根(现状,迁移成本低)还是移到 `apps/pure_live/` 下(形态更纯,但 CI/签名/脚本全要改路径)?(建议:留在根,只改名字层面)
8. **命名**:`packages/pure_live_*` 还是 `packages/<能力名>`(如 packages/live)?(建议带 pure_live_ 前缀,pub 名称冲突少)

## 附录 A:v2 pubspec 与 v1 的完整差异

- 新增依赖见 §5;移除 dev 依赖:`intl_utils`(l10n 改 easy_localization 体系)、`change_app_package_name`。
- 其余(v1 的 dio/drift/hive/firebase/桌面栈/media_core git 依赖 18 包/inappwebview fork/mobile_scanner 与 flutter_exit_app 本地补丁/全部 overrides)自 master 原样继承——它们是今天刚发过 v3.1.18 的已验证组合。
- 参考稿两处修正:`F:/media_core` 路径依赖改回 git 依赖(v1 已证明路径依赖会让 CI/换机装不起来);`android_tv_text_field` 本地补丁目录不存在,延后到 TV 输入 wave。

## 附录 B:wind 快速上手(API 实测)

```dart
import 'package:fluttersdk_wind/fluttersdk_wind.dart';

WindTheme(
  data: WindThemeData(brightness: Brightness.light),
  child: MaterialApp(
    home: WDiv(
      className: 'flex flex-col gap-4 p-6 bg-gray-100 min-h-screen',
      children: [
        WText('标题', className: 'text-3xl font-bold text-blue-600'),
        WCard(
          className: 'bg-white rounded-xl shadow-lg p-6 hover:shadow-xl',
          child: WText('内容', className: 'text-gray-600'),
        ),
        WButton(
          onTap: () {},
          className: 'bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg',
          child: Text('开始'),
        ),
      ],
    ),
  ),
)
```
