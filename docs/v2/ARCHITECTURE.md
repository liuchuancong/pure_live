# pure_live v2 架构文档(决策稿 v0.3)

> 状态:**推荐定稿**。v0.2 → v0.3:包细分落到"每个包装什么、谁依赖谁、包内长什么样、以后怎么加功能"的最终颗粒度,并给出工程化护栏。未写业务代码。
> 分支:`v2`。生态愿景(内容源插件化 / 主题用户导入 / 首页用户编排)维持 v0.2 不变。

## 1. 发行走过的路:从发行项目提炼的四条铁律

| 经验来源 | 铁律 | 在 v2 的落法 |
|---|---|---|
| flutter/packages(FlutterFire 等 federated 插件) | **契约与实现分离**:先有 platform_interface 契约包,实现各自独立,靠契约测试保兼容 | `pure_live_plugin_api` 就是契约包;内置 Dart 源与 JS 脚本源都只对契约负责,靠同一套契约测试 |
| VGV(Very Good Ventures)大量交付项目 | **repository 与 UI 分包**,域逻辑可脱离 UI 测试、可被第二个消费方复用 | v2 每个域包内部强制 `data/domain/presentation` 分层;**拆出独立 repository 包的触发条件是"出现第二个消费方"**(如 TV 复用),不预拆 |
| dart_simple_live(simple_live_core / simple_live_app / console) | **core 承载全部站点适配,app 只是壳**——同一 core 被手机/TV/CLI 三个壳复用 | 33 站适配全部在 `sources/` 层,`app` 壳与未来 TV 壳都消费同一批包 |
| media_core(自家,26 包) | **每包单一职责 + 单 barrel 导出 + example 集成验证**;melos 统一驱动 | 工程模板照搬;内核直接复用不重写 |

**结构性防腐规则**(写进 CI 护栏,不是口头约定):
- L0 foundation 不得 import 任何内部包;L1 ecosystem 只准 import foundation;L2 sources 只准 import plugin_api+foundation,**不准 import 其他 source**;L3 ui 只准 import foundation+ecosystem;L4 features 只准 import ui+ecosystem+foundation(经 plugin_api 用源);`app` 是唯一全知者。
- 每包只允许一个 barrel(`lib/<包名>.dart`),外部只能 import barrel。
- 业务代码禁止直接 `import 'package:fluttersdk_wind/...'`(只有 `pure_live_ui_kit` 可以)。

## 2. 包细分总表(最终颗粒度)

```
pure_live(v2)
├── melos.yaml
├── app/                                  # 应用壳
├── packages/
│   ├── foundation/                       # L0 基础设施
│   │   ├── pure_live_utils               # 公用方法
│   │   ├── pure_live_network             # 网络请求底座
│   │   ├── pure_live_auth                # 身份验证
│   │   ├── pure_live_storage             # 存储聚合
│   │   ├── pure_live_files               # 文件处理器
│   │   ├── pure_live_platform            # 平台处理
│   │   ├── pure_live_backup              # 备份引擎
│   │   └── pure_live_logging             # 日志
│   ├── ecosystem/                        # L1 插件生态
│   │   ├── pure_live_plugin_api          # 源插件契约(+契约测试套件)
│   │   ├── pure_live_plugin_host         # JS 沙箱宿主 + 注册表/权限
│   │   └── pure_live_theme               # 主题引擎(令牌文件)
│   ├── sources/                          # L2 内容源(一站一包,长尾并包)
│   │   ├── source_bilibili/              # live + vod 双 capability
│   │   ├── source_douyu/  source_huya/  source_douyin/
│   │   ├── source_cc/  source_kuaishou/ …(大站各一包)
│   │   ├── source_music_builtin/         # 内置音乐源(样例音源)
│   │   └── source_misc/                  # 长尾小站并包
│   ├── ui/                               # L3 UI 基座
│   │   ├── pure_live_design              # 设计令牌唯一权威
│   │   ├── pure_live_ui_kit              # 组件库(唯一 import wind 处)
│   │   └── pure_live_adaptive            # TV/手机/桌面自适应
│   └── features/                         # L4 业务域
│       ├── pure_live_live                # 直播域
│       ├── pure_live_vod                 # 点播/B 站视频域
│       ├── pure_live_music               # 音乐域
│       ├── pure_live_iptv                # IPTV 域
│       ├── pure_live_recorder            # 录制域
│       ├── pure_live_settings            # 设置域(含账号管理 UI)
│       ├── pure_live_backup_ui           # 备份/同步的 UI 侧
│       └── pure_live_home                # 首页编排(用户可定制模块)
```

共 **8 + 3 + (大站数+2) + 3 + 8 ≈ 30+ 包**。粒度原则:一个包 = 一种"可独立替换/独立测试/能一句话说清职责"的能力;拆分预则是**新增能力先做目录,出现第二个消费方或超过 ~800 行再升包**。

## 3. 每个包的内部契约(包内模板)

### 3.1 foundation 包模板
```
packages/foundation/pure_live_network/
├── lib/
│   ├── pure_live_network.dart      # 唯一 barrel:导出公开类型(HttpClient、AuthInterceptor、CookieStore…)
│   └── src/
│       ├── client/                 # dio 组装、超时/重试策略
│       ├── interceptors/           # 风控头、UA、日志(接 logging)
│       └── cookies/                # cookie jar 持久化(接 storage)
├── test/                           # 纯 Dart 单测(无 UI)
└── pubspec.yaml                    # dependencies 只含三方包 + L0 兄弟包(白名单见矩阵)
```
各 foundation 包职责边界(防止"core 变垃圾场"的久经考验做法):

| 包 | 装什么 | 明确不装 |
|---|---|---|
| utils | 时间/数字/文本(拼音/模糊匹配)/编解码/hash | 任何 Flutter Widget、任何 IO |
| network | dio 客户端工厂、拦截器、cookie、UA 池、gbk 转码 | 具体站点的 API 定义 |
| auth | 凭据保险箱(secure_storage)、会话生命周期、登录流程状态机契约 | 任何站点登录的具体实现(在 sources) |
| storage | hive/drift/sqlite3_flutter_libs 装配、kv 接口、缓存目录策略 | 业务表结构(在 features) |
| files | pick/拖拽接入、m3u/json 读写、Saf、哈希校验、临时目录 | 备份语义(在 backup) |
| platform | 窗口/托盘/协议注册/深链接/dpad/亮度音量/电池的**接口 + 各平台实现** | 任何业务调用决策 |
| backup | 备份格式(版本化)、导出导入引擎、WebDAV/LAN 同步 | 备份的 UI |
| logging | talker 装配、分级、诊断导出 | 业务日志埋点(各包自己埋) |

### 3.2 ecosystem 包模板
- `plugin_api`:契约类型(`SourcePlugin`、`LiveCapability/VodCapability/MusicCapability`、`ThemeTokenFile`、`HostBridge`)+ **`contract_test/` 契约测试套件**(内置源与 JS 源都要跑同一套,保证"插件"二字成立)。这是全仓最稳定的包,改它 = 发契约版本。
- `plugin_host`:flutter_js 沙箱桥(仓库已 vendored AGP9 补丁)、插件注册表、生命周期(导入/启用/禁用/更新/删除)、权限裁决、内置源加载器。
- `theme`:令牌文件 schema + 校验、令牌 → WindThemeData / Material ColorScheme 构建、导入导出。主题 = 数据,永不执行代码。

### 3.3 source 包模板(以 source_bilibili 为例)
```
packages/sources/source_bilibili/
├── lib/src/
│   ├── live/        # 直播 capability:目录/播放/弹幕协议(protobuf)
│   ├── vod/         # 点播 capability:ugc/pgc/详情/选集(协议词典:TV modules/vod)
│   ├── auth/        # 扫码/账密登录(调用 pure_live_auth 保险箱)
│   └── models/      # freezed 模型
└── test/
    └── fixtures/    # 录制的 HTTP 响应快照 → 离线协议测试
```
源测试策略(维护性的关键):**fixtures 快照测试**——把真实 API 响应录制进 `test/fixtures/`,CI 离线跑断言解析正确;协议失效时只需更新快照重录,不依赖外部服务波动。

### 3.4 feature 包模板(VGV 分层的包内化)
```
packages/features/pure_live_live/
├── lib/src/
│   ├── data/         # repository 实现:经 plugin_api 消费源,经 storage 持久化
│   ├── domain/       # 实体/用例(纯 Dart,可单测)
│   └── presentation/ # Riverpod controllers + wind 页面(页面只用 ui_kit 组件)
└── test/             # domain 单测 + controller 测试 + 关键 widget 测试
```
**repository/UI 拆包规则**:域包内部先分层;当第二个消费方出现(如 TV 壳要复用 vod 数据层)→ 把 `data/domain` 升为 `pure_live_vod_repository` 包,presentation 留在原包。不预先拆,避免 30 包膨胀到 45 包。

### 3.5 ui 包模板
- `design`:令牌常量 + 令牌类型 + 明暗两套默认值;**零 widget 依赖**(纯数据),theme 引擎读用户主题文件覆盖它。
- `ui_kit`:语义组件(`LiveRoomCard`、`PlayerControlBar`、`SettingSection`、`EmptyPlaceholder`…),内部用 wind className 实现,对外只暴露 Dart 参数;**不含路由、不含业务 provider**。
- `adaptive`:断点/平台策略(TV 焦点树、桌面 hover/滚轮、手机手势),输出布局决策给 feature 用。

### 3.6 app 壳
只做:ProviderScope 组装(Riverpod overrides 把各包实现接起来 = 组合根)、go_router 装配(各 feature 暴露 `RouteBase` 列表,壳负责挂载)、平台初始化序列。**app 是唯一知道所有包的层**。

## 4. 依赖矩阵(CI 护栏按此机械校验)

| 包↓ 依赖→ | utils | network | auth | storage | files | platform | backup | logging | plugin_api | plugin_host | theme | design | ui_kit | adaptive | sources | features |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| utils / logging | — | | | | | | | | | | | | | | | |
| network / storage / files / platform | ✅ | — | | | | | | ✅ | | | | | | | | |
| auth | ✅ | ✅ | — | ✅ | | | | ✅ | | | | | | | | |
| backup | ✅ | ✅ | | ✅ | ✅ | | — | ✅ | | | | | | | | |
| plugin_api | ✅ | | | | | | | ✅ | — | | | | | | | |
| plugin_host / theme | ✅ | ✅ | | ✅ | ✅ | | | ✅ | ✅ | — | | | | | | |
| design | ✅ | | | | | | | | | | | — | | | | |
| ui_kit | ✅ | | | | | | | | | | ✅ | ✅ | — | | | |
| adaptive | ✅ | | | | | ✅ | | | | | ✅ | ✅ | ✅ | — | | |
| sources/* | ✅ | ✅ | ✅ | | | | | ✅ | ✅ | | | | | | 同层禁止 | |
| features/* | ✅ | | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ | ✅ | ✅ | ✅ | 经 api | 同层禁止 |
| app | 全部 | | | | | | | | | | | | | | | 全部 |

护栏工具:`tool/check_architecture.dart`(v2 新写,替代 v1 的 validate_architecture.py)——扫描每包 import,按矩阵报错;W1 交付。

## 5. 工程化保障(确保后续维护与添加功能)

1. **melos 脚本**:`melos run analyze / test / gen / fix`(按包过滤);`melos run gen` = 各包 build_runner(freezed/json/riverpod/drift/hive 生成物一律 `*.g.dart`/`*.freezed.dart` 入 `.gitignore`?**不**——v1 经验:生成物入库可让 CI 免跑 build_runner;但 riverpod/freezed 冲突多 → 折中:drift/hive 生成物入库,riverpod/freezed CI 生成)。
2. **契约测试**:plugin_api 的 `contract_test/` 对每个内置源与 JS 桥执行同一断言集;源契约版本号写入 `SourcePlugin.apiVersion`,宿主按版本降级或拒绝。
3. **fixtures 快照**:每个 source 包录制真实响应,离线断言;网络抖动不影响 CI。
4. **新功能剧本("加一个直播平台")**:复制 source 模板 → 按 v1 协议词典实现 LiveCapability → 录 fixtures → 契约测试绿 → 在宿主注册表登记 → 首页可选模块自动出现。**不碰 app、不碰其他包**。
5. **新域剧本("加一个内容形态")**:plugin_api 增 capability(发契约 minor 版)→ sources 实现 → feature 包 UI → app 挂路由。
6. **DI 约定**:各包只暴露 Riverpod provider;`app/` 用 overrides 组合实现。包之间永不 `Get.put`/手动单例。
7. **版本策略**:melos 统一版本(lockstep),CHANGELOG 按包段落;plugin_api 单独 semver(它是生态接口)。

## 6. 生态设计(承 v0.2,不重复展开)

两类插件一套契约(Dart 内置源 / 用户可导入 JS 脚本源,flutter_js 沙箱)、主题 = 令牌数据文件、权限白名单与凭据隔离、首页模块用户编排、lx-music 音源脚本兼容留接口不承诺——细节见 git 历史版本 v0.2(434ae3f31)与本文 §3.2/§3.3。

## 7. 路线图(waves)

| 波 | 内容 | 完成标志 |
|---|---|---|
| W0 ✅ | pubspec 现代化 + 本文档 | — |
| W1 | melos 化 + 全部空包骨架(按 §2 树)+ `check_architecture.dart` 护栏 + plugin_api 契约 v0 | `melos analyze` 绿;护栏在 CI 跑 |
| W2 | foundation 8 包实做(utils/network/logging 先行) | 单测绿 |
| W3 | design/theme/ui_kit 首批组件 + app 壳 + adaptive | 全平台启动,可切换用户主题 |
| W4 | plugin_host 沙箱 + JS demo 插件 | JS 插件导入/请求/禁用全流程 |
| W5 | source_bilibili(live)契约测试 + 真机播放 | 直播第一个源跑通 |
| W6 | 其余大站源 + live 域 | 直播域可用 |
| W7 | vod 域(协议词典:TV vod) | B 站视频可播 |
| W8 | music 域(参考 lx-music) | 音乐可播 |
| W9 | iptv / recorder / backup / settings / home + v1 数据迁移器 | 功能齐 |
| W10 | 生态打磨:JS SDK 文档、示例插件、(评估)lx 源兼容 | 发布 v2 首版 |

## 8. 剩余决策点(比 v0.2 少了,这轮我直接做了大部分主)

已替你定(有异议再改):长尾小站并 `source_misc`;插件只支持 JS;域包内分层不预拆 repository;`app/` 留仓库根;melos lockstep 版本;drift/hive 生成物入库、riverpod/freezed CI 生成。

仍需你一句话:
1. **firebase 去留**(留 = CI/账号同步不动;弃 = 改 Windows 预取脚本;建议 W9 前保留)
2. **theme 文件格式**(建议 zip:manifest + 令牌 JSON + 壁纸资源)
3. **v1 数据迁移器**做不做(建议 W9 做一次性 hive → 新存储)

## 附录 A:v2 pubspec 差异(同 v0.1 §5)
## 附录 B:wind 快速上手(同 v0.1 附录 B)
