# Pure Live v2.9.7 Android 观看指标与排行更新

版本：`2.9.7+4086`

源码基线：`liuchuancong/pure_live@974f4c32`

交付平台：Android `arm64-v8a`

## 根因与修复

本轮从接口原始字段、适配器映射、统一模型、卡片显示、排行比较、刷新合并六层重新核对观看数据。

| 平台 | 2026-08-25 实时样本 | 最终口径 |
| --- | --- | --- |
| 斗鱼 | 列表 `ol` 与详情 `room_biz_all.hot` 同量级 | 平台热度；不标为真实在线 |
| 虎牙 | `totalCount`、`userCount` 与 URI 8006 数值均处于同一百万级热度尺度 | 平台热度；公开接口没有独立并发人数 |
| 抖音 | 当前匿名 Feed 在房间顶层返回 `user_count`，嵌套 `stats.total_user` 可为占位 `0` | `user_count` 为在线；正数 `display_value/total_user` 为累计观看，二者分开保存 |
| 快手 | 首页房间返回 `watchingCount`，平台原始顺序并不保证降序 | 当前观看人数；客户端稳定降序排序 |
| 网易 CC | `webcc_visitor/hot_score/visitor/total_visitor` 同值约几十万，`vision_visitor` 约几十至几百 | 前一组为热度；只有 `vision_visitor/online_num` 为在线 |
| Twitch | GraphQL 目录、搜索与频道元数据返回 `viewersCount` | 当前并发观看人数 |
| SOOP | 推荐同时返回 PC、移动端和 `total_view_cnt`，样本 `6372 + 7834 = 14206` | 使用 PC + 移动端总在线；不再只显示 PC 端 `current_view_cnt` |
| YY | 列表与详情 `users` 保持一致，网页未声明独立并发字段 | 平台热度；不改写为真实在线 |

对应修复：

- 抖音推荐、分类、搜索与房间详情统一调用并发/累计两个解析器；顶层 `user_count` 优先进入在线字段，累计占位零被忽略。
- CC `visitor` 从在线候选中移除，并作为 `webcc_visitor/hot_score` 的热度兼容别名。
- SOOP 推荐与搜索使用 `total_view_cnt`；分类使用 `view_cnt`；缺少总数字段时合并 PC/移动端分量；播放器详情不再把缺失值写成 `0`，刷新合并会保留最近可靠快照。
- 热门页所有平台统一使用 `LiveRoom.compareAudienceRanking`。平台热度模式按原生口径降序，真实在线模式按明确并发值降序，相同数值以平台和房间号稳定打破平局。
- 网易 CC 热度接口的服务端顺序与在线口径不同，热门页扩大为 100 个候选后再按所选口径重排；切换全局口径或分平台开关会刷新当前热门页。

## 回归保护

- `test/douyin_audience_metric_test.dart`：顶层在线、累计字段隔离和占位零。
- `test/douyin_parser_test.dart`：当前 Feed 信封映射及在线/累计标签。
- `test/cc_audience_metric_test.dart`：热度别名不得落入在线字段。
- `test/soop_platform_test.dart`：PC + 移动端求和、分类字段、缺失与显式零。
- `test/popular_audience_ranking_test.dart`：热度模式、真实在线模式、未支持平台及稳定降序。
- `tool/interface_probe.py`：40 项既有门禁内增加八个平台观看字段的实时语义检查，避免只验证“接口有响应”。

## 发布验证

发布前按 `BUILD_POLICY.md` 串行执行：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 `
  -Target AndroidArm64 -Configuration Release -FullRegression
```

最终结果：

| 证据层 | 结果 |
| --- | --- |
| Flutter Analyze | 通过，正式门禁耗时 312.0 秒 |
| 自动化测试 | 371 项全部通过 |
| 平台实时接口 | 40/40 通过；覆盖九个平台，其中八个平台的推荐检查包含观看字段语义 |
| Android Release 构建 | 通过；`assembleRelease` 340.6 秒，产出仅含 `arm64-v8a` 的 APK |
| 构建资源 | Gradle 16 workers；峰值 CPU 47.96%；重型进程峰值内存 15,761,190,912 bytes；结束后活动重型进程 0 |
| 正式签名 | GitHub `sign-staged-android` run `32796787943` 通过；V2/V3 签名有效 |
| 证书 SHA-256 | `c0bb95744c81f9c7dd4535a9552775038eb5a59c5922f791d1695f45ac34ceaf` |
| APK SHA-256 | `c6d053370c6d900be376d9dabc1b54708da1d0b8fdcb46fddadb07f71459da0c` |
| 源码提交 | `b74a67c7635ea37b6f68bb6a10d9b106de851fdd`，tag `v2.9.7` |

完整回归第一次执行接口阶段时，新增探测函数误把只做校验、返回 `None` 的 `require_path` 当作路径值，形成七个“空列表”假失败；Analyze 与 371 项测试在该轮均已通过。探测器改为返回已校验节点后，40 项实时接口全部通过；应用源码未变化，Android 阶段依照构建策略复用完整回归证据，仅重跑目标平台构建。

正式 Release：[Pure Live v2.9.7](https://github.com/liuchuancong/pure_live/releases/tag/v2.9.7)。

## 交付边界

- 本轮仅构建 Android `arm64-v8a`，不会并发启动其他平台构建。
- 不执行 ADB、安装或手机 UI 自动化；设备验收由用户独立完成。
- Windows、Linux、macOS 与 iOS 版本元数据继续指向已发布的 v2.9.4 安装包。

返回 [文档索引](README.md)。
