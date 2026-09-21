# 六间房直播合同检查点（2026-09-21）

## 当前生产证据

- 官网大厅 `https://v.6.cn/` 正常返回服务端渲染页面；`window.__SMARTY_ALL_VARIABLES__` 中的 `typeList` 本次包含 411 条当前直播。
- 当前快照的 `anchor_area` 实际包含歌区、舞区、脱口秀、星颜和派对；应用增加“全部”入口并对同一快照有界本地分页，不把首页快照描述为独立远端分页接口。
- 官网 `GET /search.php?type=use&key=...` 返回主播 UID、公开房号、昵称和头像，样本同时包含正在直播与未开播主播。搜索页不声明直播状态，应用只在已有大厅证据时合并状态，打开房间后再实时刷新。
- 房间 `https://v.6.cn/8838` 的官方页面把公开房号 `8838` 绑定到主播 UID `56182128`；移动房间接口返回当前场次 `222415076`、主播元数据、`fans_num`、`flvtitle` 及编码器上报的分辨率和码率。
- 当前媒体 `https://wlive.6rooms.com/httpflv/v56182128-222415076.flv` 经官方 302 调度到短时边缘节点，最终响应为 HTTP 200、`video/x-flv`，开头字节为标准 `FLV` 文件头。

## 源码合同

1. 房间身份只接受数字房号、`v.6.cn/{ROOM}`、`m.6.cn/{ROOM}` 和两站的 `/profile/{ROOM}`；搜索、视频、相似域名、用户信息和非 HTTP(S) URL 均不回流。
2. 大厅 JSON 只从完整服务端变量对象读取，保持官方顺序、房号/UID/场次身份、图片和原始分类；重复或结构损坏的条目被过滤。
3. 昵称搜索保持官网最多一页的作者结果，不虚构远端分页，也不把搜索页缺失的直播状态填成未开播。
4. 房间详情先绑定公开房号与主播 UID，再验证移动接口返回的 `roominfo.rid` 和 `roominfo.id`；私密房、黑屏访问条件、下播与结构错误分开处理。
5. 媒体只接受 `https://wlive.6rooms.com/httpflv/v{UID}-{LIVE_ID}[-many].flv`，UID、场次、主机、路径、协议、端口、查询和片段均严格校验。
6. 大厅 `count` 作为平台热度保存；公开合同尚未证明它是唯一并发人数。`fans_num` 独立作为粉丝数，不参与在线人数口径。
7. 播放和录制恢复重新查询同一房号，取得新的当前场次和 FLV 标识；稳定选择 ID 为 `flv:source`。

## 本轮验证

- 六项确定性测试覆盖链接、目录、分类、搜索、开播/下播、UID/场次绑定、媒体白名单、稳定画质、恢复和目录迁移。
- 当前生产适配器探针从源码客户端读取大厅和房间合同通过。
- 独立媒体字节探针取得 HTTP 200、`video/x-flv` 和 `FLV` 前缀。

## 后续集中验收

- Android 与 Windows GUI 中的目录、分类、昵称搜索、精确链接、首帧、停止、恢复和短录。
- 远端聊天协议及不同连麦/多人布局房间的媒体行为继续核验。
- 长时直播切场、官方边缘调度变化及录制文件完整解码纳入 3.2.0 集中门禁。

## 参考

- 六间房直播官网：<https://v.6.cn/>
- 当前样本房间：<https://v.6.cn/8838>
- StreamGet 当前六间房实现：<https://github.com/ihmily/streamget/blob/master/streamget/platforms/sixroom/live_stream.py>
- DouyinLiveRecorder 当前平台调用：<https://github.com/ihmily/DouyinLiveRecorder/blob/main/src/spider.py>
