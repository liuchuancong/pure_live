# 3.2.0 Issue 分流中央台账

本台账是 Issue 首轮分流的唯一紧凑索引。它记录“当前源码还需要做什么”，不复制专项审计的完整过程。状态分类遵循 [`MAINTENANCE_POLICY.md`](../MAINTENANCE_POLICY.md)。

| Issue | 报告基线 | 当前映射 | 当前证据 | 处置 / 再开条件 |
| --- | --- | --- | --- | --- |
| [#872 Bilibili 登录后弹幕不显示](https://github.com/liuchuancong/pure_live/issues/872) | 3.1.4 / Windows | `present` → 已在 `master` 修订 | `52db99fb` / `9b4eb33b` 补齐认证队列、ACK 和用户绑定；协议 11/11、直接探针观测到聊天；见[Issue #872 审计](ISSUE_872_BILIBILI_LOGGED_IN_DANMAKU_AUDIT_2026_09_19.md) | 代码调查停止；只在报告者登录态 Windows 仍复现或协议字段再次变化时重开 |
| [#870 直播自动录制未启动](https://github.com/liuchuancong/pure_live/issues/870) | 3.1.4 / Android / HyperOS | `not-reproduced`；3.1.4 后的已知轮询缺陷已修订 | `9549000f` 修复停止任务占用 in-flight、请求超时/所有权、开关恢复与启动并发；当前 `test/recorder_poll_lifecycle_test.dart` **16/16 PASS**；见[录制轮询审计](RECORDER_POLL_OWNERSHIP_AUDIT_2026_09_05.md) | Issue 没有日志，也未说明 13:20–13:51 期间应用是前台、后台还是被系统挂起。先不重复修改当前轮询；有精确前后台时序、当前 `master` 复现或相同时段日志时重开 |

## 写入规则

- 一行必须回答：报告在哪个版本、当前是否还有缺陷、证据在哪里、什么新事实才会重开。
- 已有专项报告时只引用；没有当前代码修改时，不为单条 Issue 新增长报告。
- 只有验收行的证据或状态变化时才编辑验收矩阵；只有总数或主要阻塞变化时才编辑状态快照。
