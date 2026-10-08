# pure_live v2 架构文档(决策稿 v0.2)

> 状态:**待拍板**。本文只做架构决策材料,未写任何业务代码。
> 分支:`v2`。v0.1 → v0.2 变更:**从"迁移式"改为"重写式"**;模块按域全部细分;新增插件生态设计(内容源插件化 + 主题用户可导入)。
> v1 代码与 TV 端代码在 v2 中的定位:**协议与交互的参考**(接口地址、参数、弹幕协议、页面交互),不是搬运对象。

## 1. 产品愿景与架构原则

**愿景**:不只是"又一个直播聚合播放器",而是一个**生态宿主**——
- 内容源(直播平台 / B 站视频 / 音乐源)像 lx-music 的自定义音源一样**以插件形式导入**;
- 主题由用户**导入**(令牌文件,不执行代码);
- 用户可以高度自定义:装哪些源、用什么主题、哪些模块进入首页。

**架构原则(重写式)**
1. v1/TV 代码只读三样东西:协议细节(API endpoint/参数/加密)、弹幕协议、页面交互流程。代码零搬运。
2. 内核不重写:播放/弹幕/录制引擎复用 media_core(v2 的模块在内核之上做业务与插件化)。
3. 依赖单向、每包单一职责;包粒度按"能独立改名/替换/测试"划分。
4. 一切用户可扩展的东西都是**数据或脚本**,不是编译进 App 的 Dart(保证平台合规与热更新能力)。

## 2. 总体形态:melos 单仓多包(仿 media_core)

```
pure_live(v2)
├── melos.yaml
├── app/                        # 应用壳(见 §4;平台目录 android/ios/... 暂留仓库根,§9-6)
├── packages/
│   ├── foundation/             # 第 0 层:基础设施(无业务语义)
│   ├── ecosystem/              # 第 1 层:插件生态(契约 + 宿主 + 主题引擎)
│   ├── sources/                # 第 2 层:内容源(内置源以"插件"形态实现)
│   ├── ui/                     # 第 3 层:UI 基座(设计令牌/组件库/自适应)
│   └── features/               # 第 4 层:业务域(直播/视频/音乐/IPTV/录制/备份/设置)
```

## 3. 包细分清单(全量)

### 3.1 foundation — 基础设施层(你点名的:网络请求/身份验证/公用方法/文件处理/平台处理/备份)

| 包 | 职责 | 要点 |
|---|---|---|
| `pure_live_utils` | 公用方法:时间/数字/文本(拼音)/校验/编解码(hashlib、crypto、dart_sm、html 解析) | 零 Flutter 依赖可单测 |
| `pure_live_network` | 网络请求底座:dio 组装、拦截器、cookie jar、UA/风控头策略、重试、 talker_dio_logger、charset(gbk) | 统一出口,所有源插件经它发请求(统一日志/代理/风控) |
| `pure_live_auth` | 身份验证:凭据保险箱(secure_storage)、各平台会话/Cookie 生命周期、扫码/账密/Token 登录流程契约、登出清理 | 不含具体平台逻辑;平台登录在 sources 内实现,auth 提供保险箱与流程契约 |
| `pure_live_storage` | 存储聚合:hive_ce(kvp)、drift+drift_flutter(关系型)、缓存管理、secure_storage 封装 | 唯一持久化出口;迁移 v1 数据留接口 |
| `pure_live_files` | 文件处理器:导入/导出(pick/拖拽)、Saf、m3u/json 解析、哈希校验、临时目录管理 | 与 desktop_drop/file_picker 对接 |
| `pure_live_platform` | 平台处理:method channels、窗口/托盘/开机(桌面)、TV 遥控 dpad、深链接(app_links)、分享接入、亮度/音量/电池 | 平台差异在这里消失,上层只见接口 |
| `pure_live_backup` | 备份:设置/收藏/歌单/订阅的导出导入、WebDAV/局域网(bonsoir)同步、版本化合并策略 | 数据格式版本化,向前兼容 |
| `pure_live_logging` | talker 装配、分级日志、诊断导出 | 与 network 的 dio logger 串联 |

### 3.2 ecosystem — 插件生态层(本次新增的核心)

| 包 | 职责 |
|---|---|
| `pure_live_plugin_api` | **插件契约**:源插件接口(直播/点播/音乐三类 capability)、主题令牌 schema、宿主桥(host bridge)协议、API 版本号 |
| `pure_live_plugin_host` | **插件宿主**:JS 沙箱(flutter_js,仓库已有 AGP9 vendored 补丁)、插件注册表/生命周期(导入-启用-禁用-更新-删除)、权限声明与信任提示、内置插件的加载器 |
| `pure_live_theme` | **主题引擎**:主题 = 令牌数据文件(JSON,不执行代码);导入/导出/分享;由令牌构建 WindThemeData + Material ColorScheme;跟随明暗 |

### 3.3 sources — 内容源层(内置源也以插件形态实现,证明契约)

- **Dart 内置源**(协议复杂、需要原生性能的):每平台一包——`source_bilibili`、`source_douyu`、`source_huya`、`source_douyin`、`source_cc`、`source_kuaishou`……(33 站按平台一包,长尾小站可合并 `source_misc`)。B 站包内含 live + vod 两个 capability。
- **JS 脚本源**(用户可导入的生态源):lx-music 式 `.js` 插件,跑在 plugin_host 的沙箱里。**远期兼容目标:能直接跑 lx-music 的 user-api 音源脚本**(lx 源脚本本就是 JS,只需实现其 API 面的 shim)。
- 契约(设计草图,定稿在 plugin_api 包):

```
SourcePlugin(元数据: id/name/version/类型 live|vod|music/权限声明)
 ├─ LiveCapability:   目录/搜索/清晰度/线路取流 → StreamHandle(media_core 可播)
 ├─ VodCapability:    分类/搜索/详情/选集/取流/弹幕
 ├─ MusicCapability:  搜索/歌单/歌词/播放地址
 └─ 宿主桥: http(走统一 network)/kv 存储/剪贴板/通知(白名单)
```

### 3.4 ui — UI 基座层(你点名的:不同平台的 UI 与组件库)

| 包 | 职责 |
|---|---|
| `pure_live_design` | 设计令牌(颜色/间距/圆角/字重/动效曲线)的唯一权威定义;消费 theme 引擎的令牌文件 |
| `pure_live_ui_kit` | 组件库:语义组件(LiveRoomCard/PlayerControlBar/SettingSection…)、**唯一允许 import fluttersdk_wind 的包**(wind 断供时唯一替换点) |
| `pure_live_adaptive` | 平台自适应:TV(dpad 焦点树)/手机/桌面的布局策略、断点、输入法/键盘行为 |

### 3.5 features — 业务域层(每个域一包,域内 domain/data/presentation 分层)

`feature_live`、`feature_vod`、`feature_music`、`feature_iptv`、`feature_recorder`、`feature_settings`、`feature_backup`(备份的 UI 侧,引擎在 foundation)、`feature_home`(首页编排:用户决定哪些模块上首页——生态定制化的入口)。

## 4. 应用壳(app)

只做四件事:melos 装配 + `ProviderScope` + 路由组装(go_router,按 feature 注册子路由)+ 平台初始化序列。**不含任何业务**;平台目录(android/ios/windows/linux/macos)挂在仓库根,供 `flutter run/build` 使用。

## 5. 插件生态设计(核心章节)

### 5.1 两类插件、一套契约
1. **Dart 内置源**:编译进 App,实现同一套 capability 接口。第一方源用它(协议复杂、性能要求高,如 B 站 protobuf 弹幕)。
2. **JS 脚本插件**:用户导入的 `.js` 文件(本地文件 / URL / 二维码),跑在 flutter_js 沙箱。面向:长尾直播源、音乐音源(lx-music user-api 兼容是远期目标)、点播源。

### 5.2 主题 = 数据,不是代码
主题文件 = 令牌 JSON(颜色/圆角/间距/字重/背景图引用),由 `pure_live_theme` 校验后构建 WindThemeData + Material ColorScheme。用户可导入/导出/分享主题文件;不执行任何代码,无安全面。壁纸/背景跟随主题打包。

### 5.3 信任与权限模型
- 脚本插件声明权限(网络域名白名单、存储配额、是否需要凭据读取),导入时明示。
- 网络必须走宿主桥(统一 dio),插件拿不到裸 socket → 可审计、可缓存、可断网。
- 凭据默认不开放给脚本插件;`pure_live_auth` 对脚本只暴露"当前是否已登录"布尔级信息。

### 5.4 生态冷启动
- 首发即以"全部内置源 = 插件"验证契约(防止契约只对第三方成立)。
- 插件分发:先本地导入 + URL;插件市场(索引 JSON)后置。

## 6. UI 选型(维持 v0.1 结论,补充插件相关)

- Material 3 底座 + wind 样式层;**只允许 `pure_live_ui_kit` import wind**(单一替换点)。
- 暗色:`WindThemeData(brightness:)` 按 themeMode 切换,由 theme 引擎构建。
- 主题令牌文件 schema 与 `pure_live_design` 的令牌一一对应,用户主题即令牌覆盖表。
- wind 1.8.1 风险照旧(16h 新库),由 ui_kit 单点隔离。

## 7. 依赖(已解析通过,见 v0.1 §5,不重复)

版本坑与新增包清单同 v0.1 §5;本轮无新增运行时依赖(dusk/artisan/telescope/magic_deeplink 均不引入,结论同前)。

## 8. 参考项目的新定位(重写式)

| 参考 | v2 中怎么用 |
|---|---|
| pure_live_TV `modules/vod` | **协议参考**:bilibili ugc/pgc/弹幕/音乐 API 的端点、参数、模型字段;交互流程参考。代码不搬 |
| lx-music mobile/desktop | **生态范式参考**:音源脚本机制(apiSource/userApi)、歌单/收藏/同步的数据模型;远期兼容其音源脚本 |
| media_core/packages | **工程模板**:melos、每包单 barrel、example 验证;同时是内核依赖 |
| v1 pure_live | **协议词典**:33 站适配器的 endpoint/风控头/弹幕协议;迁移时照着重写,不复制文件 |

## 9. 路线图(重写式 waves)

| 波 | 内容 | 完成标志 |
|---|---|---|
| W0(已完成) | pubspec 现代化 + 本文档 | — |
| W1 | melos 化 + foundation 8 包骨架 + 契约 v0(plugin_api) | 包可解析、契约评审通过 |
| W2 | UI 基座:design 令牌 + theme 引擎(令牌 JSON 导入导出)+ ui_kit 首批组件 + 应用壳 | 全平台启动见可切换主题的壳 |
| W3 | 插件宿主:flutter_js 沙箱 + 注册表/权限 + 第一个 JS demo 插件 | JS 插件可导入并发请求 |
| W4 | 首个 Dart 内置源(bilibili:live capability)打通播放 | 真机看 B 站直播 |
| W5 | live 其余平台源(协议照 v1 词典重写)+ live 域完成 | 直播域可用 |
| W6 | vod 域(B 站协议参考 TV) | B 站视频可播 |
| W7 | music 域(参考 lx-music;内置音源先行) | 音乐可播 |
| W8 | iptv/recorder/backup/settings + v1 数据迁移接口 | 功能齐 |
| W9 | 生态打磨:JS 源 SDK 文档/示例、lx 音源兼容评估、插件分享 | — |

## 10. 待拍板问题(第 2 轮)

1. **长尾小站归并**:`source_misc` 一包兜底 vs 严格一站一包?(建议:大站一站一包,长尾并包)
2. **JS 插件的语言边界**:只支持 JS,还是契约层预留 Lua/其他?(建议:只 JS,flutter_js 现成)
3. **lx 音源兼容**:作为 W9 目标还是直接砍掉?(建议:留接口不承诺)
4. **`feature_*` 命名**:保留 `feature_` 前缀还是直接 `live/vod/music`?(建议:直接能力名,更干净)
5. **app 壳位置**:仓库根(app/ + 平台目录)还是 `apps/pure_live/`?(建议:根,理由同前:CI/签名路径成本)
6. **数据迁移**:v1 的收藏/配置要不要官方迁移器?(建议:W8 做 hive→新存储 的一次性迁移器)
7. **theme 文件格式**:纯 JSON 令牌覆盖表,还是带 manifest 的 zip(含壁纸资源)?(建议:zip 包,清单+资源)

## 附录 A:v2 pubspec 差异(同 v0.1 §5,未变)
## 附录 B:wind 快速上手(同 v0.1 附录 B,未变)
