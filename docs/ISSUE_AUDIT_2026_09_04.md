# 2026-09-04 Issue 与弹幕传输审计

本轮以维护分支当前代码为基线，不合并上游提交。审计时维护仓库
`wzgrx/pure_live` 没有未关闭 Issue；原仓库有 8 条未关闭 Issue，按日期、
严重度和能否稳定复现优先核对最新的 #846、#845 与 #836。

## 审计结论

| Issue | 分类与首个错误状态 | 当前维护分支结论 | 处置与剩余证据 |
|---|---|---|---|
| [#846 虎牙未开播收藏只显示数量](https://github.com/liuchuancong/pure_live/issues/846) | `environment-or-data` 与旧版并发刷新缺陷的组合；连续房间请求失败时，旧实现会把失败混同于离线并逐卡提交 | 当前 `FavoriteController` 已先发布保留卡片身份的 unknown 预览，使用有界并发请求，并在全部请求结束后一次性提交平台快照；传输失败不再删除“未开播”卡片。`favorite_startup_policy_test.dart`、`favorite_pull_refresh_test.dart` 与 `sites_test.dart` 覆盖 unknown、短列表刷新及失败传播 | 代码路径已经针对报告根因改写，不重复加入任意延时或无限重试。仍需带报告者同一组虎牙收藏数据做一次 Android 运行抽样，因 Issue 没有房间号与请求日志 |
| [#845 斗鱼 71415 大量弹幕缺失](https://github.com/liuchuancong/pure_live/issues/845) | 原版 WebSocket 单帧只解一个包会漏掉合并包；维护分支已修复。剩余差异来自隐藏的平台消息过滤和默认启用的全平台相似文本过滤 | 对 71415 做两次独立 60 秒原始捕获：分别收到 436/426 个协议包、69/43 条 `chatmsg`；旧解析器接受 63/38 条，只排除 6/5 条同时缺少 `dms` 和 `if` 的消息。被排除样本具有连续 UID、生成式昵称及共同 CID 前缀，符合疑似自动消息特征；但当前 bililive-go、biliup 都按非空 `chatmsg` 接收，并未把 `dms`/`if` 当作可见性协议 | 09-04 当时把疑似自动消息过滤改为默认开启的用户可见开关，并关闭全平台模糊相似过滤；09-19 的重复报告 #871 证明该默认值仍会制造可见缺失，当前 `31ee5cd7` 已改为完整聊天默认、启发式过滤显式选择，详见 [#871 订正审计](ISSUE_871_DOUYU_CHAT_COMPLETENESS_AUDIT_2026_09_19.md) |
| [#836 抖音部分房间没有弹幕](https://github.com/liuchuancong/pure_live/issues/836) | `external-drift` 加维护分支实现缺陷。主地址已经是 `webcast100`，但旧“备用地址”只替换不存在的 `webcast3` 文本，实际仍只有一个端点；签名直接拼接会让 `+` 被部分查询解析器当成空格；12 位随机访客 ID 与当前 Web 端 19 位格式不符；握手缺 Referer，SDK 仍是旧 beta | 改为 `webcast100-ws-web-lq`/`webcast100-ws-web-hl` 两端点轮换；使用 `Uri.queryParameters` 编码签名；补 `Referer`、`need_persist_msg_count=15`、45 秒静默恢复；SDK 更新为 `1.0.15`；匿名访客 ID 使用并复用 `7[3-9]` 开头的 19 位 Web 格式；日志中的 Cookie 始终脱敏，获取匿名 Cookie 失败时不再出现 String 类型异常 | 确定性回归 11/11 通过。另对 2026-09-04 实时推荐房间 `136396047381` 做匿名连接：5 秒收到 51 条消息（47 chat、4 online），0 次失败。该实时样本证明当前生产建连链路；Issue 中“足球中国/中冠联赛”当时未提供稳定房间 ID，主播不在播时不把其他房间的结果冒充为原样本验证 |

## 抖音根因证据

2026 年的浏览器抓包与活跃开源实现共同显示当前 Webcast 节点主要为
`webcast100-ws-web-hl.douyin.com` 和 `webcast100-ws-web-lq.douyin.com`，
握手需要浏览器头、完整查询参数、`need_persist_msg_count=15`，当前 SDK 版本为
`1.0.15`：

- [biliLive-tools #369 的浏览器抓包对照](https://github.com/renmu123/biliLive-tools/issues/369)
- [biliLive-tools 当前 DouYinDanma 实现](https://github.com/renmu123/biliLive-tools/blob/master/packages/DouYinDanma/src/index.ts)
- [dy-comment-cast 的端点、心跳和静默超时说明](https://github.com/adseng/dy-comment-cast)

本次没有引入第三方签名服务，也没有记录登录 Cookie、签名 URL 或用户账号。
实时探针只保存房间公开 ID、消息类型计数和失败计数。

## 验证记录

- 确定性测试：`test/douyin_danmaku_protocol_test.dart` 与
  `test/web_socket_util_test.dart`，11/11 通过；覆盖跨房间消息拒绝、元数据、
  签名保真、双端点唯一性、握手头、Cookie 脱敏、19 位访客 ID、静默半开恢复、
  代理路由和远端关闭诊断。记录为
  `local-artifacts/build-records/20260904T115027433Z-quality-focused.json`。
- 实时 Webcast：`local-artifacts/build-records/20260904T114811428Z-quality-focused.json`；
  建连成功，5 秒 51 条消息，47 chat、4 online、0 failure。
- 斗鱼 71415 原始捕获：
  `local-artifacts/diagnostics/issues/douyu-71415-live-capture-20260904.json` 与
  `douyu-71415-live-capture-samples-20260904.json`。

## 其余未关闭 Issue

- #819 小红书、#792 虎牙历史弹幕、#779 图标属于功能请求，不混入本轮弹幕
  传输修复；小红书还有独立项目在共享手机轮转中验证。
- #767 Windows 4K/高 DPI GPU 占用仍需要报告环境相同的物理 4K/150% 显示器
  做呈现链路采样。`tool/sample_windows_runtime.ps1 -IncludeGpu` 已补齐进程 3D、
  Video Decode、Video Processing、Copy、总引擎及独显/共享显存采样，并记录显卡
  驱动、当前分辨率与刷新率；本机 3840×2400@200Hz 的短时空闲样本已验证采样链路。
  当前维护分支已有 viewport 限制、刷新率策略和 Windows 空闲资源回落证据，但尚无
  150% 缩放下真实播放、滚动和退出回落的等价采样，因此这些证据仍不足以宣布该
  Issue 完成。
- #708 为旧版本全屏报告；继续由横竖屏、返回链和系统小窗验收矩阵覆盖，不根据
  “未发现新日志”直接关闭。
