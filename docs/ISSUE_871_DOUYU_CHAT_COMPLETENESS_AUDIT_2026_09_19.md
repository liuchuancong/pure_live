# Issue #871 斗鱼弹幕完整性审计（2026-09-19）

## 范围与结论

上游 [#871](https://github.com/liuchuancong/pure_live/issues/871) 报告 Windows 3.1.4 的斗鱼弹幕明显少于网页，甚至只显示连接状态而没有聊天；它与较早的 [#845](https://github.com/liuchuancong/pure_live/issues/845) 属于同一产品边界。审查只读取上游 Issue 和冻结源码，以维护仓库 `liuchuancong/pure_live` 为实现基线，没有同步上游提交。

3.1.4 的协议层会直接丢弃同时缺少 `dms` 与 `if=1` 的 `chatmsg`。09-04 两次 60 秒原始捕获分别收到 69/43 条聊天，其中 6/5 条会被该门禁排除；这不足以解释每一次“完全没有聊天”，但稳定证明门禁会把平台已经送达的非空房间聊天误判为不可见。此前 `971c2753` 把门禁改成用户开关，却继续默认开启，因此 3.1.4 升级用户在没有该新偏好键时仍继承过滤行为。#871 的重复报告说明“默认保持干净列表”不符合用户对直播弹幕完整性的预期。

提交 `31ee5cd7` 将完整聊天流改为默认合同：

- 非空、房间号匹配的 `chatmsg` 默认进入上层；`dms` / `if` 只作为可选启发式标记，不再承担可见性协议职责。
- “过滤斗鱼疑似自动弹幕”继续保留，但改为明确选择后才启用；开关每条消息实时读取，切换后无需重连。
- 旧设置或备份中显式保存的 `true` / `false` 原样保留；缺少该字段的 3.1.4 配置、旧备份与新安装使用完整流默认值。
- UI 双语说明明确提示启发式过滤也可能隐藏普通聊天；跨房间、空文本、损坏包、用户屏蔽词、屏蔽用户、重复合并和相似文本偏好仍由各自门禁负责。

## 参考实现与迁移判断

当前参考实现 [bililive-go Douyu client](https://github.com/bililive-go/bililive-go/blob/ef71711a7c573b013d82fec01ee8d0609ee36aca/src/recorders/danmaku/douyu/client.go) 与 [biliup Douyu protocol](https://github.com/biliup/biliup/blob/906e0f6fdb104d65989d12b76c9a6f02205384cb/crates/danmaku/src/protocols/douyu.rs) 都按非空 `chatmsg` 向上交付，没有以 `dms` / `if` 作为硬门禁。维护分支因此让完整性优先，噪声抑制保留为可见偏好。

持久化由 `hiveBool` 读取已有键，否则采用控制器默认值。3.1.4 尚未定义 `filterDouyuSuspectedAutomatedMessages`，所以升级时键缺失并自然取得新的 `false`；已经明确启用过滤的开发版用户会保留持久化的 `true`。备份解析同样只对缺失字段使用新默认值，不覆盖显式选择。

## 确定性证据

1. 有效红灯：先把默认协议与旧备份期望改为完整流，旧实现得到 **16 PASS / 2 FAIL**；两个失败分别锁定协议构造器默认过滤和设置缺失字段默认值。记录：`local-artifacts/build-records/20260919T115439089Z-quality-focused.json`。
2. 直接绿灯：协议与设置两文件 **19/19 PASS**，覆盖合帧、跨房间、默认交付、显式启用过滤、开关实时生效、空文本、醒目留言、缺失字段默认值以及显式备份选择。记录：`local-artifacts/build-records/20260919T121138949Z-quality-focused.json`。
3. 最终相邻回归：协议、设置、屏蔽管理 UI、弹幕会话生命周期与相似过滤五文件 **53/53 PASS**；`flutter analyze` 为 `No issues found`（1100.7 秒）。记录：`local-artifacts/build-records/20260919T125210642Z-quality-focused.json`。
4. 同轮仓库审计检查 4930 个已跟踪文件，0 error、2 个既有 warning：`local-artifacts/repository-audits/20260919T121426634Z-focused.json`。

## 原生与在线边界

审查时 `https://www.douyu.com/betard/71415` 返回目标房间 `show_status=2`，因此本轮没有把离线房间冒充为实时网页/App 数量对照。代码修改位于 Android/Windows 共用的协议与设置层；本批没有构建候选、启动 Windows GUI 或操作 Android 设备，Astra Light 使用 0 次。

后续需在目标房间或等价活跃斗鱼房间同时记录网页可见聊天、原始 WebSocket `chatmsg`、应用交付计数及用户侧过滤状态，并覆盖进房、开关切换、断线恢复、多画面和返回直播。A4-01 保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR**，仍有 42 组历史大项未闭环。
