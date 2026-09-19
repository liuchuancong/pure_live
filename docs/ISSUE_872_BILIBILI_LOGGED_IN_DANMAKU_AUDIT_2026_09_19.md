# Issue #872 Bilibili 登录后无弹幕审计（2026-09-19）

## 范围与结论

上游 [#872](https://github.com/liuchuancong/pure_live/issues/872) 报告 Windows 3.1.4 在第三方登录 Bilibili 后，直播间显示弹幕服务器已连接，却没有可见弹幕；其他平台正常。Issue 创建于 2026-09-18，未附日志、截图、录屏或评论，“预期结果”字段也把异常现象写成了预期，因此本轮只把标题、版本、平台和三步复现描述视为报告事实。审查读取上游 Issue 与公开参考实现，以维护仓库 `wzgrx/pure_live` 为实现基线，没有同步上游提交。

`v3.1.4` 到修订前 `52e267e0` 的 Bilibili 站点发现、认证包和消息解析没有协议变化；唯一相关差异是 `80c87c0e` 把暂态重连从最终关闭事件中分离，不足以解释登录后已显示连接却没有聊天。修订前的认证包仍停留在旧字段集合，也没有处理当前队列消息要求的 ACK。

提交 `52db99fb` 与 `9b4eb33b` 对齐当前登录弹幕队列合同：

- 认证 operation 7 明确发送 `support_ack: true`、每次连接独立的 8 位小写十六进制 `queue_uuid` 和 `scene: "room"`，保留既有 `uid`、`roomid`、`protover: 3`、`buvid`、`platform: "web"`、`type: 2` 与 token。
- 收到 `p_is_ack: true` 且 `msg_id`、`cmd`、`p_msg_type` 完整的事件时，以 operation 24 回传三字段 ACK；缺字段时跳过 ACK，但继续把可解析聊天交给上层，避免控制字段异常反向吞掉内容。
- 登录 WebSocket 的 uid 优先从同一份 Cookie 的精确 `DedeUserID` 项解析；Cookie 为空时固定为 0，Cookie 未携带该项时才使用当前已核验的正数 uid。这样备份恢复或账号切换期间不会把旧身份 uid 与新 Cookie 组合发送。
- 生产网络探针增加 `PURELIVE_DANMAKU_REQUIRE_CHAT=1` 严格模式；启用后仅“连接仍存活”不足以通过，至少还需实际解析一条聊天。

## 当前协议参考

- [`qydysky/bili_danmu@6dc50e37` 认证包](https://github.com/qydysky/bili_danmu/blob/6dc50e378fcd9f7fb45f04da5c2f29ed01be2272/F/F.go#L67-L82) 发送 `support_ack`、8 位小写随机 `queue_uuid`、`scene`、平台与类型；同提交的[协议常量](https://github.com/qydysky/bili_danmu/blob/6dc50e378fcd9f7fb45f04da5c2f29ed01be2272/CV/Const.go#L25-L30) 把 `scene` 定义为 `room`。
- [`naaammme/bbspace@93eb904b`](https://github.com/naaammme/bbspace/blob/93eb904b1ee37328d588e190df728149bd54858f/core/live/src/main/java/com/naaammme/bbspace/core/live/LiveRoomMessageRepository.kt#L553-L629) 同样声明 ACK 支持和 room 场景，并在 `p_is_ack` 消息上用 operation 24 回传 `msg_id`、`cmd` 与 `p_msg_type`。

两个独立实现都已超出 Pure Live 3.1.4 的旧认证字段集合。它们支持本轮协议兼容修订，但不构成报告者账号的运行时复现证据。

## 确定性与在线证据

1. **修订前公开会话基线**：生产适配器在 DIRECT、房间 `7734200`、45 秒窗口内 ready 1 次、聊天 27 条、观看更新 12 条、重连/最终关闭均为 0，结束时仍连接。记录：`local-artifacts/diagnostics/bilibili-872-20260919T132042950Z.json`。这证明游客连接、解压和普通聊天解析可用，也说明公开会话成功不等于登录路径已复现。
2. **有效红灯**：在旧行为上先固定当前认证、ACK 与同 Cookie 身份合同，得到 **7 PASS / 3 FAIL**；三个失败分别锁定缺少 `support_ack`、未发送 operation 24，以及 Cookie 已是 `DedeUserID=778899` 时仍使用旧 uid 42。
3. **第一轮相邻回归**：Bilibili 协议、推荐、画质、登录生命周期、账号身份、弹幕会话和 WebSocket 七个文件 **57/57 PASS**。仓库审计 4931 个已跟踪文件，0 error、2 个既有 warning；记录：`local-artifacts/build-records/20260919T142159871Z-quality-focused.json`、`local-artifacts/repository-audits/20260919T140803101Z-focused.json`。该轮 analyze 发现一条构造器初始化风格提示，随后已改用初始化形式并复验。
4. **最终静态门禁**：协议专项 **11/11 PASS**；`flutter analyze` 为 `No issues found`（312.4 秒）。测试覆盖固定/随机 queue UUID、room 场景、完整与缺损 ACK 元数据、聊天继续交付，以及 Cookie/stored uid 的登录、游客和负值边界。
5. **最终公开网络绿灯**：在 `support_ack + queue_uuid + scene=room + operation 24` 最终源码上启用严格聊天要求，DIRECT、房间 `7734200`、45 秒窗口内 ready 1 次、聊天 1 条、观看更新 11 条、重连/最终关闭均为 0，结束时仍连接且 `chatRequirementMet=true`。记录：`local-artifacts/diagnostics/bilibili-872-final-20260919T145953270Z.json`。
6. 两个代码提交均已推送并精确核对 `origin/master`；最终协议提交为 `9b4eb33b8965f35a91c905447164ad22cb73ba7b`。

## 登录与原生边界

本轮没有读取、输出或持久化任何 Bilibili Cookie、token 或账号标识；已有 Android 快照也不含 Bilibili Cookie 或正数 uid，不作为登录路径取证。最终在线探针因此仍是游客会话，只证明协议修订后的公开链路能连接并解析实际聊天。

报告者特定的 Windows 登录态还需在当前累计候选上复验：登录完成后核对 Cookie/uid 身份一致性，进入至少两个活跃房间，记录认证 ACK、队列 ACK、原始聊天计数、上层交付计数及断线恢复。该复验不得记录凭据正文。本批没有构建候选、启动 Windows GUI、调用 ADB 或操作设备，Astra Light 使用 0 次。

A4-01 保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR**，仍有 42 组历史大项未闭环。
