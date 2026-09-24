# GoodGame Chat v2 只读接入

当前 GoodGame 适配器此前返回空弹幕，播放页还提示“远端聊天尚待接入”。本批按 [GoodGame 官方 Chat v2 协议](https://github.com/GoodGame/API/blob/master/Chat/protocol2.md)接入游客只读消息，普通播放页与多画面聚焦格共用同一引擎。

## 当前合同与源码变更

- 2026-09-23 官网 `/api/4/streams/2/` 的公开目录返回当前在播频道 `id=15365`、稳定频道 key `Verloin` 等；`GoodGameRoom.streamId` 是聊天协议要用的数字 `channel_id`，收藏身份仍是频道 key，不混用。
- `wss://chat-1.goodgame.ru/chat2/` 实际返回 `welcome(protocolVersion=2)`；游客发送 `join(channel_id)` 后收到 `success_join`。后续一次连接遇到超时，不能把单次握手当作长期稳定证据。
- 引擎仅在 v2 welcome 后加入频道、收到匹配的 join 确认才标记 ready；只呈现当前频道的 `message`，忽略频道历史、私信及其他房间。保留服务端消息 ID、用户 ID 和时间戳，反转义 HTML 文本；停止/换房释放 WebSocket，超时与断线走有限重连。
- 两份语言包移除了过期“聊天尚待接入”提示，保留观看人数口径和成人内容提醒。当前源码能力在[平台兼容性](PLATFORM_COMPATIBILITY.md)登记。

## 验证与待验

确定性测试覆盖频道身份、游客握手、订阅确认、消息解析、跨房间隔离、旧消息排除、非法 ID 与释放。最终 GoodGame + 站点注册 + 录制合同聚焦回归 **11/11**；本批全仓 Analyze 无 error/warning，只有未修改的 PandaTV 测试 1 项 info，记录 `20260923T105906999Z-quality-focused.json`。两份语言包 JSON 与本批键均已核对。本机短时网络探针仅证明 welcome/join，未收到真实用户聊天。当前 Android/Windows 客户端的真实消息呈现、重连、长时播放与录制仍在 3.2.0 集中验收范围。
