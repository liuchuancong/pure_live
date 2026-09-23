# 46 平台搜索能力登记与 Rumble HLS 修订（2026-09-23）

## 用户可见缺口

以当前 `Sites.supportedSiteIds` 与 `LiveSearchCapabilities` 对照，注册适配器 **46** 个，原能力表只登记 **32** 个；缺失的 14 个站点均已有 `searchRoomsCancellable` 实现，却被搜索页的未知平台默认值判成网页搜索，并走通用百度链接。新增登记前的真实回归红灯：Shopee Live 预期 `liveAndOffline`，实际 `webOnly`。快手适配器的原生搜索仍为空，继续保持既有网页入口。

| 能力合同 | 本批补齐的平台 |
| --- | --- |
| 当前快照/目录匹配及精确查询；可能返回未开播、受限或未知状态 | Shopee Live、NimoTV、Rumble、GoodGame、FC2 Live、Steam Broadcasts、京东直播、酷狗直播、六间房直播 |
| 原生搜索及频道/场次定位，保留平台页码或游标 | VK Video Live、Dailymotion |
| 精确场次/房间与有限推荐页匹配 | 淘宝直播、百度直播、LOOK 直播 |

分页布尔值逐个与实现核对：VK、Nimo、Dailymotion、Rumble、GoodGame、FC2、Steam、京东、酷狗支持后续页或有限快照本地页；Shopee、淘宝、百度、六间房、LOOK 不提供搜索后续页。14 项的网页搜索按钮均关闭，避免继续把百度当官方站点搜索。Dailymotion 关键词结果是当前直播，但精确 live-video ID 可返回已结束直播，因此整体覆盖标为可含离线。

## 批量回归发现的相邻缺陷

- Rumble 浏览器返回的 HLS master 是多行文本；此前 `_parseMedia` 调用通用 `_string`，将全部空白折为单个空格，`parseMaster` 因此读不到任何 `#EXT-X-STREAM-INF` 行并报 `mediaUnavailable`。现对 `playlist` 保留原文，仅校验类型，后续解析器自身继续执行 512 KiB 上限、媒体主机与路径验证。既有多档夹具从红灯转绿。
- Dailymotion 没有当前观看数时使用空字符串表示未知，旧断言要求 `null`；修订断言并新增精确已结束 live-video 的离线回归。FC2 的门票房间按适配器合同仍显示为受限卡片，open-chat `type=0` 才排除；旧测试把门票卡片误计为已过滤，现对齐为 3 张卡片并保持受限断言。

## 门禁与边界

搜索能力/Widget 首批 **83/83**，14 站适配器首批 **72 PASS / 4 FAIL**；修订及新增 Dailymotion 离线夹具后，19 文件集中回归 **187/187**，最终定向 Analyze 无诊断。测试证明源码分派、输入合同、关键 UI 动作与确定性平台夹具；各平台当前生产可达、媒体解码和 Android/Windows 原生交互仍按验收矩阵单独闭环，本批未操作设备。
