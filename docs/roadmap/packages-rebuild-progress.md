# packages/ 重写台账(工业级 DoD)

> 判据来自 [../architecture/application-portfolio.md](../architecture/application-portfolio.md) §6 的九条;
> 包的存在性由同文 §3 的消费矩阵决定。本文件记**实测缺口**与**重写队列**,不记计划外的乐观进度。
> 本轮按使用者要求**不写测试**,但公共面按"能被一个确定性测试钉住"的形状设计。

## 1. 基线实测(2026-10-10,`lib/` 下非生成 Dart 代码行数)

| 层 | 包数 | 行数区间 | 判断 |
|---|---:|---|---|
| foundation | 14 | 108 – 764 | 存储/网络/工具/缓存/文件/发布等已成体系;`diagnostics`(121)、`events`(108)、`platform_info`(158)、`sync`(206)偏薄 |
| integrations | 3 | 88 – 941 | `media`(941) 够;`firebase`(88) 只是受保护初始化,够用但无诊断出口 |
| ecosystem | 11 | 328 – 2973 | 契约与运行时面最扎实(`platform` 2973、`external_tvbox` 1395、`extension` 1100);`plugin_host`(328)、`resolver`(343) 待按 DoD 复核 |
| services | 5 | 178 – 480 | `search`(178)、`feed`(212) 只有聚合器骨架,缺分页语义/取消/部分结果策略的完整面 |
| ui | 5 | 79 – 279 | **整层偏薄**:design 81、lyric 79、player_ui 122、ui_kit 226、adaptive 279 —— 与"六风格 + 令牌 + 门面"的承诺差一个量级 |
| features | 10 | 58 – 191 | **最薄的一层**:每个域只有 1-2 个类型,没有 data 层、没有错误模型、没有持久化边界 |
| providers | 6(删 5 后) | 9 – 735 | `huya`(428)、`music`(735)、`bilibili`(407)、`iptv`(312) 有实现;`douyu`(9) 是空壳 |

## 2. 本轮已做

- **删除 5 个无消费者的 provider 空壳**:`providers/community`、`douyin`、`tvbox`、`twitch`、`youtube`
  (每个 9 行 = 只有 barrel)。全仓 grep 确认无任何 import/依赖/文档引用(`platform` 测试里的
  `pure_live_tvbox_runtime` 是运行时 id 字符串,与该包无关)。根 `workspace:` 同步移除,
  `dart pub get --offline` 通过,护栏 `packages=55 errors=0`。
  理由:portfolio §6 第 7 条 —— 空壳包让包数变成误导数字。将来真要接这些站点,按消费者出现时再建包。

## 3. 重写队列(按"缺口 × 消费者数"排序)

| 序 | 包 | 现状缺口(对照 §6) | 重写要点 |
|---|---|---|---|
| 1 | `features/settings` | 只有一个类型化偏好读写 | 键空间与版本、迁移钩子、变更流、平台默认值、导入/导出、失败按域隔离 |
| 2 | `features/search` | 只有历史记录容器 | 查询规范化、跨 App 一致的排序、容量上限与淘汰、与 `services/search` 聚合器的取消语义 |
| 3 | `features/home` `account` `backup` `live` `vod` `music` `iptv` `recorder` | 每包 58–191 行,domain 有形状、data 缺失 | 按 §6 补齐:data 边界 + 具名错误 + 资源释放;presentation 留给 UI 波 |
| 4 | `ui/design` → `ui/ui_kit` → `ui/adaptive` | 令牌只有 spacing/radius,组件 4 个,风格注册表无焦点/密度维度 | 令牌全集(色/距/圆/高/动效/字焦/密度)、`AppNotice`/`AppDialog`/`AppLoading`/空错态门面、D-pad 焦点序与 TV 尺寸 |
| 5 | `ui/lyric` `ui/player_ui` | 单文件适配 | 时间轴同步、句柄所有权、与 `integrations/media` 的状态订阅边界 |
| 6 | `services/search` `services/feed` | 聚合器只有扇出 | 分页模式(§契约三态)、部分结果策略、取消传播、失败记账的可诊断形状 |
| 7 | `foundation/diagnostics` `events` `platform_info` `sync` | 薄 | 结构化事件 + 有界缓冲 + 脱敏;探测能力矩阵;同步游标与冲突策略 |
| 8 | `providers/douyu` | 空 barrel | 按 `providers/huya` 的形状实现 feed/browse/search/resolve |
| 9 | `ecosystem/plugin_host` `resolver` `capability` | 有实现,未过 DoD | 只做复核:错误具名、超时/体积上限、资源释放、README 平台矩阵 |

## 4. 每包完成的定义(逐条核,不合并勾)

1. `dart analyze` 在该包目录 0 issue;`dart run tool/check_architecture.dart --strict` 全仓 0 错;
2. 公共面只在 barrel 暴露,`lib/src/` 私有,公开类型有英文注释说明"为什么";
3. 每类失败有具名类型或错误码,不把底层异常直接抛给调用方;
4. 所有 IO/网络/脚本执行路径有取消、超时与输入输出体积上限,并发有显式上限;
5. 句柄/订阅/定时器有配对释放,进程内单例由组合根注入;
6. 落盘数据带格式版本与迁移路径,损坏时按域隔离;
7. README 写职责、允许/禁止依赖、平台矩阵与"未验证"清单;CHANGELOG 记不兼容点;
8. 无 TODO 占位、无"能编译但不可用"的空实现;
9. 不写测试(本轮约定),但形状必须可被一个确定性测试钉住。

## 5. 未做 / 风险

- **未跑任何 app 侧验证**:`apps/pure_live` 的 `flutter test` 需要 `native-assets/` 预取件
  (BUILD_POLICY §3 的顺序契约),本轮没跑;包重写以 `dart analyze` + 护栏为门。
- **五个被删的 provider 若将来要接**:按 §3 第 8 行的形状重新建包,不要恢复空壳。
- **重写期间可能有并行会话**:每包独立提交,冲突时以消费矩阵与 §4 判据为准,不互相覆盖整文件。
