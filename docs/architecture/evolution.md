# 演进策略

> 架构如何在不推翻核心的前提下长大。

## 1. 扩展维度与不变核

| 维度 | 扩展方式 | 核心是否改动 |
|---|---|---|
| 新内容源 | 新 Provider 插件(Native/JS/Data) | 否 |
| 新内容形态(Podcast/Radio/…) | ContentKind 扩展 + 新 Capability | 否(枚举追加) |
| 新播放引擎 | media_core 新 PlayerAdapter | 否 |
| 新主题/字体/Emote | 数据插件(令牌文件/资源包) | 否 |
| 新跨域服务 | services 层新包 | 否 |
| 新宿主(TV/Web 壳) | 新 Experience 层,复用全部 repository | 否 |

核心稳定的前提:capability 契约、ContentRef、MediaTicket 三者保持向后兼容演进。

## 2. 契约演进规则

- `plugin_api` 独立 semver;capability 接口只增不改(新增方法带默认实现或拆 v2 接口)。
- 插件 Manifest 声明 `apiVersion`;Runtime 按 `minimumVersion/maximumVersion` 判定兼容(见 [../plugin/plugin-manifest.md](../plugin/plugin-manifest.md))。
- ContentKind/RefreshReason/Permission 等枚举:只追加,不复用旧名,不重排。
- 破坏性变更 → 新契约版本 + 双版本过渡期 + 迁移器。

## 3. 数据演进

- 备份格式版本化(Backup v1/v2/v3),Export/Import/Migration/Validation/Rollback 全支持(见 [../migration/v1-to-v2.md](../migration/v1-to-v2.md))。
- 业务数据(历史/收藏/播放列表)建在 ContentRef 上,源增删不影响数据可读性——源消失时内容降级显示,数据不删。

## 4. 演进的护栏

- 每个跨包/不可逆决策先写 [../adr/](../adr/),ADR 不可变(推翻 = 新 ADR 取代)。
- 架构护栏脚本 + 契约测试是演进的回归网:重构前先让测试绿。
- 演进节奏遵循 [../roadmap/v2-roadmap.md](../roadmap/v2-roadmap.md):W4 用 Bilibili 单插件打通全链,再横向铺量(W8 33+ 直播站)。

## 5. 反模式(演进时禁止)

- 在 Core 里加"某个源的特判"(I10)。
- 用 EventBus 绕过接口依赖。
- 平台前缀业务类型(BilibiliHistory)——一律 ContentRef 统一模型。
- 为单个插件在 Manifest 之外开特权后门(I8)。
