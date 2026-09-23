# Kick 公开聊天只读接入

当前 3.2.0 源码原先让 Kick 返回 `EmptyDanmaku`，播放页虽能打开房间却没有远端评论。本批把公开聊天接到普通播放页和多画面大格；不发送消息，不使用频道 ID 猜测聊天房间 ID。

## 合同与实现

- 当前官网 `GET https://kick.com/api/v2/channels/xqc` 返回频道 `id=676`、独立 `chatroom.id=668`；另一个在播目录频道也返回独立聊天房间 ID。缺字段或频道 slug 不匹配时只报告弹幕错误，不影响视频取流。
- 官网公开 Pusher 端点实测收到 `pusher:connection_established`，订阅 `chatrooms.<id>.v2` 后收到 `pusher_internal:subscription_succeeded`；本次短观察窗口未收到用户聊天，因此此探针只证明握手/订阅，**不证明真实消息展示通过**。
- 客户端仅在订阅确认后报告 ready；处理 Pusher ping/pong、订阅超时及有限 WebSocket 重连。当前与旧形状的聊天消息按房间频道、可选 chatroom ID、文本和用户字段校验，保留消息 ID 与平台时间戳供会话去重。
- 直播间卡片携带稳定频道 slug；弹幕会话启动时再查询当前 chatroom ID，不在收藏中持久化短时 WebSocket 信息。多画面只连接可见聚焦格的现有会话逻辑保持不变。

参考合同：[Kick 官方开发者 API](https://api.kick.com/swagger/index.html)仅提供 OAuth 聊天发送/事件订阅；公开观看聊天采用官网使用的非官方 Pusher 通道。实现细节交叉核对 [kick-api 的 live_chat.rs](https://github.com/Landy-Dev/kick-api/blob/main/src/live_chat.rs)及 [kick-wss](https://github.com/nglmercer/kick-wss)；这些开源实现仅作为协议证据，不作为生产可用性的替代证明。

## 验证边界

确定性测试覆盖频道/聊天房间身份分离、缺失与错配拒绝、订阅前后状态、ping/pong、当前与旧消息形状、跨房间隔离和关闭释放。Kick + 注册表 + 录制合同 **13/13**，记录 `20260923T101859840Z-quality-focused.json`；最后构造器整理后 Kick **6/6**，记录 `20260923T103305889Z-quality-focused.json`。本批全仓 Analyze 无 error/warning，发现的本批两项 info 已消除；最终五个改动 Dart 文件定向 Analyze 为 `No issues found!`，另有 1 项未修改的既有测试 info。当前候选的 Windows/Android 真实消息呈现、后台重连及长时播放仍待集中验收；平台兼容性表只声明源码能力。
