# Bigo Live 公开推荐快照关键词筛选

2026-09-23，在既有精确 Bigo ID 与官方房间链接查询之外，为当前官网公开推荐快照增加昵称/标题关键词筛选。此功能是有限列表筛选，不是全站主播索引，也不提供结果分页。

## 官方接口核对

- 官网[搜索页](https://www.bigo.tv/search)的[当前页面脚本](https://www.bigo.tv/_nuxt_cdn_/pages/search/_query.916c63.js)调用 `searchUser` 与 `searchRoom`；[共享脚本](https://www.bigo.tv/_nuxt_cdn_/pages/index.pages/search/_query.67e692.js)将它们映射到 `POST https://ta.bigo.tv/official_website_tiebar/search/user` 和 `/search/room`，请求包含 `query/index/size/device-id`。
- 匿名只读请求对普通关键词、主播名和当时目录中真实的 Bigo ID 均返回 HTTP 200、`code: 0`、`data: null`。该观察仅代表本机当时的游客入口，不能据此把空数据当作全站无匹配。
- 既有[公开推荐目录](https://ta.bigo.tv/official_website/OInterfaceWeb/vedioList/72?tabType=00&fetchNum=10&lang=en&countryCode=US)仍返回直播卡片，因此关键词仅筛选适配器取得的有限目录快照。精确 ID/官方房间链接继续走房间详情，可返回未开播或访问受限状态。

## 合同与验证

- `page > 1` 返回空列表；匹配使用昵称/标题不区分大小写，按 Bigo site ID 去重。错误 URL 与控制字符不进入目录筛选；取消令牌贯穿目录请求。目录 `user_count` 才作为当前在线；详情缺字段保持未知，不以空串冒充累计观看。筛选过程不请求媒体。
- 受影响四文件最终聚焦测试 **124/124**；其中 Bigo 专项 **6/6**。只读生产探针 `PURELIVE_BIGO_SNAPSHOT_SEARCH_PROBE=1` 运行 `tool/probes/bigo_snapshot_search_probe_test.dart`：当时公开快照 20 条，动态选取一位当前主播昵称筛选命中 1 条，搜索耗时 3 ms（命中本次目录快照缓存）；未请求媒体，也未进行客户端播放/录制。记录为 `20260923T084139733Z-quality-focused.json` 和 `20260923T083928444Z-quality-focused.json`。
- Android/Windows 当前候选的搜索 GUI、播放、弹幕、短录/长录与全库门禁仍归 3.2.0 集中验收；实时目录的数量和可达性可能变化。
