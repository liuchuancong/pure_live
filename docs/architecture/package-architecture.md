# 包架构

> 工程组织:单仓多包。**实装用 pub workspace**(仓库根 `pubspec.yaml` 的 `workspace:` 列成员,成员写 `resolution: workspace`,共用根 lockfile);melos 可后叠在同一份列表上。每包单一职责、单一 barrel;脚手架 `tool/scaffold_package.ps1` 保证结构零漂移。

## 1. 仓库目录

```text
pure_live/                        # 仓库根 = pub workspace hub(pubspec.yaml 只有成员清单与 dependency_overrides)
├── apps/                         # 一个 App 一个功能;App 之间禁止任何依赖(ADR 0022)
│   ├── pure_live/                # 直播软件:native Dart 源(huya/douyu/bilibili live/demo),不装插件宿主
│   ├── pure_bili/                # B 站视频客户端(参照 newBV)【待建】
│   ├── pure_music/               # 音乐客户端(lx 音源 + bmsc 式 B 站音源/歌单导入)【待建】
│   └── pure_tvbox/               # TVBox 客户端(external_tvbox + js/py spider 宿主,导入即运行)【待建】
├── packages/                     # ×57 共享层(foundation / integrations / ecosystem / services / ui / features / providers)
│   ├── foundation/               # L0:每关切面一包
│   │   ├── utils/ logging/ network/ auth/ storage/ files/ platform_info/
│   │   ├── cache/ events/ diagnostics/
│   │   └── backup/ sync/ release/ l10n/
│   ├── integrations/             # L0.5
│   │   ├── firebase/ media/ python_runtime/
│   ├── ecosystem/                # L1
│   │   ├── platform/             # pure_live_platform:平台契约+模型伞包(纯 Dart,禁 Flutter 依赖)
│   │   ├── plugin_api/ plugin_host/ js_runtime/
│   │   ├── extension/ resolver/ identity/ permission/ task/
│   │   ├── capability/
│   │   ├── external_tvbox/       # spider 契约 + 单仓/多仓/M3U 解析(仅 pure_tvbox 装配)
│   ├── services/                 # L2
│   │   ├── search/ history/ favorites/ playlist/ feed/
│   ├── ui/                       # L3
│   │   ├── design/ ui_kit/ adaptive/ lyric/ player_ui/
│   ├── features/                 # L4
│   │   ├── home/ live/ vod/ music/ iptv/ recorder/ search/ settings/ account/ backup/
│   └── providers/                # L5 源适配层(native Dart 站点 / 音源 / M3U+EPG)
│       ├── bilibili/ douyu/ huya/ demo/ music/ iptv/ …
├── third_party/                  # vendored 上游源码与补丁
├── fixtures/                     # 跨包共享的录制样本(jar / m3u / 站点响应)
├── tool/                         # 仓库级脚本入口(构建 / 质量 / 发布 / 设备)
└── docs/                         # 本文档体系
```

**包的存在性由消费矩阵决定**:"哪个包被哪个 App 消费"见 [application-portfolio.md](application-portfolio.md) §3;
没有 App 消费者的包不重写、不保留。生态层(`plugin_api`/`plugin_host`/`js_runtime`/`extension`/
`permission`/`external_tvbox`)与 `integrations/python_runtime` 是 `pure_tvbox` 的功能面,
其他 App 的组合根里不出现它们。

成员登记在根 `pubspec.yaml` 的 `workspace:` 列表里,由脚手架自动维护;`apps/pure_live` 也是成员。melos 若接入,直接复用这份列表,不再另立 glob。目录形态的决策与迁移后果见 [../adr/0015-monorepo-layout.md](../adr/0015-monorepo-layout.md)。

## 2. 每类包的内部模板

**Foundation 包**:`lib/<包名>.dart`(唯一 barrel)+ `lib/src/<切面>/` + `test/`。
**Feature 包**(repository 与 UI 分包):`lib/src/{data,domain,presentation}/` + `test/`。
**Provider(源插件)包**:`manifest` + `lib/src/{api,site,model,constant}/` + `capability tests` + `contract tests` + `fixtures/`(录制的真实响应)+ `security policy`。
**所有包必备**:`README.md`(职责一句话 + 允许/禁止依赖)、`CHANGELOG.md`、`pubspec.yaml`、`test/`。

### 2.1 包内文件规范(参照 `wzgrx/pure_live`,2026-10-11 定)

一个包 = 一个能被独立使用、独立测试、独立讲清楚职责的**完整工程**,不是"几个文件放一起"。参考项目的一个站点是
`<site>_api.dart`(端点/请求头/签名/wire 解析)+ `<site>_site.dart`(能力实现)+ 必要时 `<site>_sign.dart`,
读起来一眼看得出哪层在哪;我们照这个形状定四条:

1. **一个类型一个文件**,文件名 = 类型名的 snake_case:`stream_option.dart` 里只有 `StreamOption`。
   枚举也算类型(`danmaku_kind.dart`)。一个文件里出现第二个公开类型 = 该拆了,不管多小。
2. **barrel 只 export,不定义类型**;`lib/src/**` 之外不得有实现。
3. **目录按职责分,不按体量分**:
   - `lib/src/api/` 端点表、请求头、签名、wire 响应到 DTO 的解析(不实现 capability)
   - `lib/src/site/` capability 实现(`*Capability` 的那些类),一个 capability 面一个类一个文件
   - `lib/src/model/` 只属于本源的 wire/DTO 形状,**不外泄**:跨包要用的类型进 `ecosystem/platform`
   - `lib/src/constant/` 端点常量、UA、source id、超时与体积上限(参考项目的 `lib/constant/` 就是这个用途)
   - `lib/src/internal/` 私有小工具(解析、节流),不给 barrel 出口
   目录形态与本文档不一致时**改文档先说清理由**(§5:偏离 = 先改模板再改包)。
4. **pub.dev 上有的,不自己造**。定下的默认选择:

| 用途 | 依赖 | 取代掉的手写物 |
|---|---|---|
| 值相等 | `equatable: ^3.0.0` | 手写 `operator ==`/`hashCode`。`foundation/utils` 的 `ValueEquality` 只留给不能带这个依赖的 L0 内部;**新代码一律 `Equatable`** |
| HTML 解析与实体还原 | `html: ^0.15.4` | 手撕 `<em>` / `&quot;` 的正则。XML 侧同理优先用已锁定的 `xml`/`yaml` 类库 |
| 关键区互斥 | `synchronized: ^3.3.1` | 自己写"导入并发控制""同一文件读写锁"(参考项目用它控导入并发) |
| AES/RSA/哈希原语 | `pointycastle: ^4.0.0`(+ `crypto`) | `providers/music` 已用;`crypto` 只用于纯 hash |
| 国密 SM2/SM3/SM4 | `dart_sm: ^0.1.5` | 站点签名(克拉克拉/抖音一类的 SM 路径出现时用它,不要手抄实现) |

   选它们是因为参考项目已在生产里跑着同一批平台;真要绕过(比如某平台形状库确实覆盖不到)要在包 README 里
   写清"为什么现成的不够",而不是默默手写。

## 3. 命名与版本

- 包名 `pure_live_<name>`;目录用短名(`foundation/network/` → `pure_live_network`)。
- 包名必须全仓唯一,目录短名与包名一一对应:平台能力探测包因此叫 `platform_info`(`pure_live_platform_info`),
  把 `pure_live_platform` 留给 §1 里的生态伞包(模型与契约)。
- melos lockstep 统一版本;`pure_live_plugin_api` 独立 semver(生态接口)。
- 生成物折中:drift/hive 生成物入库(免 CI build_runner);riverpod/freezed 由 CI 生成。

## 4. L4/L5 的特殊说明

- **Feature repository 与 UI 分包一步到位**:`features/live/` 内含 `repository/` 与 `ui/` 两个包(或目录内双包),TV 壳未来直接复用 repository。
- **Home 不是业务数据源**,只是 Feed 聚合器(见 [../services/feed.md](../services/feed.md))。
- **Provider = Plugin 的实现载体**:`plugins/bilibili/` 一个包可同时实现 Live/VOD/Search/Feed/Auth/Danmaku/Subtitle 多个 capability,共享底层实现但 capability 之间不形成混乱依赖(见 [../sources/live/source-contract.md](../sources/live/source-contract.md))。

## 5. 准入与晋升

新能力先进目录 → 超 ~800 行或出现第二个消费方 → 升独立包(走 [../adr/](../adr/))。脚手架生成的包结构任何人不得私自偏离;偏离 = 先改模板再改包。
