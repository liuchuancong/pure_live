# 包架构

> 工程组织:melos 单仓多包;每包单一职责、单一 barrel;脚手架 `tool/scaffold_package.ps1` 保证结构零漂移。

## 1. 仓库目录

```text
pure_live/
├── app/                    # 应用壳(组合根)
├── foundation/             # L0:每关切面一包
│   ├── utils/ logging/ network/ auth/ storage/ files/ platform/
│   ├── cache/ events/ diagnostics/
│   └── backup/ sync/ release/ l10n/
├── integrations/           # L0.5
│   ├── firebase/ media/
├── ecosystem/              # L1
│   ├── plugin_api/ plugin_host/ plugin_registry/
│   ├── extension/ resolver/ identity/ permission/ task/
│   ├── capability/ content/ repository/
│   ├── external/ external_tvbox/ external_lx_music/ external_m3u/ external_xmltv/
│   ├── theme/ background/ danmaku/
├── services/               # L2
│   ├── search/ history/ favorites/ playlist/ links/ feed/
│   ├── download/ remote/ cast/ fonts/ emote/
├── ui/                     # L3
│   ├── design/ ui_kit/ adaptive/ lyric/ player_ui/
├── features/               # L4
│   ├── home/ live/ vod/ music/ iptv/ recorder/ search/ settings/ account/ backup/
├── plugins/                # L5 Providers
│   ├── bilibili/ douyu/ huya/ douyin/ twitch/ youtube/ …(33+ 站)
│   ├── music/ tvbox/ iptv/ community/
├── docs/                   # 本文档体系
└── melos.yaml
```

melos glob:`packages:` 指向上述全部目录(排除 app 与 example)。

## 2. 每类包的内部模板

**Foundation 包**:`lib/<包名>.dart`(唯一 barrel)+ `lib/src/<切面>/` + `test/`。
**Feature 包**(repository 与 UI 分包):`lib/src/{data,domain,presentation}/` + `test/`。
**Provider(源插件)包**:`manifest` + `lib/src/{live|vod|music|auth|models}/` + `capability tests` + `contract tests` + `fixtures/`(录制的真实响应)+ `security policy`。
**所有包必备**:`README.md`(职责一句话 + 允许/禁止依赖)、`CHANGELOG.md`、`pubspec.yaml`、`test/`。

## 3. 命名与版本

- 包名 `pure_live_<name>`;目录用短名(`foundation/network/` → `pure_live_network`)。
- melos lockstep 统一版本;`pure_live_plugin_api` 独立 semver(生态接口)。
- 生成物折中:drift/hive 生成物入库(免 CI build_runner);riverpod/freezed 由 CI 生成。

## 4. L4/L5 的特殊说明

- **Feature repository 与 UI 分包一步到位**:`features/live/` 内含 `repository/` 与 `ui/` 两个包(或目录内双包),TV 壳未来直接复用 repository。
- **Home 不是业务数据源**,只是 Feed 聚合器(见 [../services/feed.md](../services/feed.md))。
- **Provider = Plugin 的实现载体**:`plugins/bilibili/` 一个包可同时实现 Live/VOD/Search/Feed/Auth/Danmaku/Subtitle 多个 capability,共享底层实现但 capability 之间不形成混乱依赖(见 [../sources/live/source-contract.md](../sources/live/source-contract.md))。

## 5. 准入与晋升

新能力先进目录 → 超 ~800 行或出现第二个消费方 → 升独立包(走 [../adr/](../adr/))。脚手架生成的包结构任何人不得私自偏离;偏离 = 先改模板再改包。
