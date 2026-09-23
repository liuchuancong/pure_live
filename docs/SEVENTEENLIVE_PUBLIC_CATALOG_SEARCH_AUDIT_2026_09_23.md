# 17LIVE 官网公开推荐与当前直播搜索

## 已核验合同

- 2026-09-23 官网 `https://17.live/` 的公开脚本 `entry-app-9a111e51.41ede3c2025391a94259.js` 直接调用 `sections?count=20&typeTab=2&region=JP&cursor=...` 和 `liveStreams/search?query=...`。后端是 `https://api-dsa.17app.co/api/v1/`。
- 公开推荐第一页返回非空 sections 与非空 opaque cursor；下一页使用该 cursor 后返回新的 section 和空 cursor。section 包含 Banner、归档、非直播和重复卡，只有直播 `stream` 才进入目录。目录摘要的 `userInfo.roomID` 可为空，但 `liveStreamID` 与 `userID`/`userInfo.userID` 必须匹配；打开房间时继续以详情接口严格核验 `roomID`。
- 官网搜索“あ”返回当前直播数组；记录中 `liveStreamID == userInfo.roomID`，并同时提供 `liveViewerCount` 与 `viewerCount`。搜索没有核验到分页游标或未开播档案，因此应用只显示当前返回窗口，不声称全站主播索引；精确房间号/官方链接仍独立查详情，可返回未开播。

## 源码修订

- 17LIVE 接入原生游标推荐，推荐区域固定为官网日本区公开窗口，Banner/归档/VOD、离线、身份冲突和重复卡排除。游标由页面控制器拥有，不使用结果条数推断更多页。
- 搜索接入官网当前直播关键词端点，URL 参数编码、取消与超时沿共享 HTTP 客户端；无效链接不会降级成普通关键词。搜索和推荐只消费元数据，不在目录/搜索阶段取流；房间详情与录制解析保持原有严格身份验证。
- 搜索页能力与中英文范围提示同步更新，当前观看与场次累计观看继续分列。

## 验证边界

定向测试与生产探针合计 **6/6 PASS**：`test/seventeenlive_public_catalog_test.dart`、`tool/probes/seventeenlive_public_catalog_probe_test.dart`（显式环境变量启用，仅读取公开元数据）。2026-09-23 真实注册适配器两次观测公开推荐首批 48、49 个当前直播房间，均保留后续游标；“あ”当前直播搜索均为 9 条，媒体请求为 0。全库 Analyze 本批启动后运行约 21 分钟仍未返回结果，已终止该检查，本批不记为静态门禁通过；候选冻结前须重跑。源码和公网只读检查均不替代 Windows/Android 候选的原生首帧、短录、刷新与退出验收。
