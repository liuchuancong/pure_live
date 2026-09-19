# 3.2.0 Issue 分流中央台账

本台账是 Issue 首轮分流的唯一紧凑索引。它记录“当前源码还需要做什么”，不复制专项审计的完整过程。状态分类遵循 [`MAINTENANCE_POLICY.md`](../MAINTENANCE_POLICY.md)。

| Issue | 报告基线 | 当前映射 | 当前证据 | 处置 / 再开条件 |
| --- | --- | --- | --- | --- |
| [#872 Bilibili 登录后弹幕不显示](https://github.com/liuchuancong/pure_live/issues/872) | 3.1.4 / Windows | `present` → 已在 `master` 修订 | `52db99fb` / `9b4eb33b` 补齐认证队列、ACK 和用户绑定；协议 11/11、直接探针观测到聊天；见[Issue #872 审计](ISSUE_872_BILIBILI_LOGGED_IN_DANMAKU_AUDIT_2026_09_19.md) | 代码调查停止；只在报告者登录态 Windows 仍复现或协议字段再次变化时重开 |
| [#870 直播自动录制未启动](https://github.com/liuchuancong/pure_live/issues/870) | 3.1.4 / Android / HyperOS | `not-reproduced`；3.1.4 后的已知轮询缺陷已修订 | `9549000f` 修复停止任务占用 in-flight、请求超时/所有权、开关恢复与启动并发；当前 `test/recorder_poll_lifecycle_test.dart` **16/16 PASS**；见[录制轮询审计](RECORDER_POLL_OWNERSHIP_AUDIT_2026_09_05.md) | Issue 没有日志，也未说明 13:20–13:51 期间应用是前台、后台还是被系统挂起。先不重复修改当前轮询；有精确前后台时序、当前 `master` 复现或相同时段日志时重开 |
| [#868 Windows 斗鱼网页搜索未跳转](https://github.com/liuchuancong/pure_live/issues/868) | 3.1.4 / Windows 10；称 3.1.2 正常、3.1.3 起异常 | `not-reproduced`；两个报告 tag 的搜索 URL 与跳转代码相同，当前网页搜索生命周期已重写 | `v3.1.2..v3.1.3` 对搜索模块无差异；`947d8a15` 为启动参数、加载/重试、返回、关闭与跳转建立 13/13 专项和 100/100 联合回归；见[网页搜索审计](WEB_SEARCH_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_12.md) | 当前源码没有可继续修补的 3.1.3 差异。仅在当前 `master` 仍复现并提供 WebView2 版本、可见错误或加载日志时重开 Windows 原生路径 |
| [#858 偶发物理音量键失灵](https://github.com/liuchuancong/pure_live/issues/858) | 3.1.2 / Android 16 | `not-reproduced`；可验证的 Activity 媒体流宿主缺口已修订 | `d8de9855` 在每次 `onResume` 建议 `STREAM_MUSIC`，最终五文件 71/71、全库 analyze 和 arm64 Debug 内容门禁通过；累计候选的软件输入证明首页路由到媒体流；见[音量键路由审计](ANDROID_HARDWARE_VOLUME_ROUTING_AUDIT_2026_09_12.md) | 实体按钮、播放中、弹窗、全屏、PiP、外部 Activity、前后台和输出设备矩阵仍属原生验收；有当前候选实体键复现及音频路由/媒体流日志时重开根因调查 |
| [#853 Windows 斗鱼原画运动画面模糊](https://github.com/liuchuancong/pure_live/issues/853) | 3.1.4 / Windows 11 | `not-reproduced`；服务端实际档位证据链已修订 | `03234c7d` 保留服务器确认的 rate 并隔离不同档位线路；适配器与消费层已有 55 项行为 + 2 项 Widget 证据；正常实时样本按请求返回对应档位；见[斗鱼画质确认审计](DOUYU_QUALITY_ACK_AUDIT_2026_09_06.md) | HTTP 档位不等于视觉清晰度。只在当前候选提供房间、请求/确认档位、解码宽高、码率及同时间网页对照时重开 Windows 画质路径 |
| [#846 虎牙未开播收藏只显示数量](https://github.com/liuchuancong/pure_live/issues/846) | 3.1.1 / Android 15 | `already-fixed`；旧版失败混成离线并逐卡提交的路径已替换 | 当前关注刷新保留全部身份、以 unknown 表示待核验、4 路有界并发并整批提交；K90 Pro 等价集合显示 2 个虎牙未开播卡片，推荐页串行/并发各 8/8；见[09-05 Issue 审计](ISSUE_AUDIT_2026_09_05.md) | 不增加任意延时或串行降速；仅在报告者原房间集合或当前 `master` 出现“数量非零但列表为空”并带请求日志时重开 |
| [#836 抖音部分房间无弹幕](https://github.com/liuchuancong/pure_live/issues/836) | 3.0.9 / Android 与 Windows | `present` → 已在 `master` 修订 | `f491afd7` 等修复真实双端点轮换、查询编码、19 位访客 ID、SDK/Referer 与 45 秒静默恢复；确定性 11/11，匿名活跃房间 5 秒收到 51 条消息（47 chat）；见[09-05 Issue 审计](ISSUE_AUDIT_2026_09_05.md) | 代码调查停止；原主播没有稳定房间 ID，只有当前源码在明确房间仍出现静默/重连证据时重开 |

## 写入规则

- 一行必须回答：报告在哪个版本、当前是否还有缺陷、证据在哪里、什么新事实才会重开。
- 已有专项报告时只引用；没有当前代码修改时，不为单条 Issue 新增长报告。
- 只有验收行的证据或状态变化时才编辑验收矩阵；只有总数或主要阻塞变化时才编辑状态快照。
