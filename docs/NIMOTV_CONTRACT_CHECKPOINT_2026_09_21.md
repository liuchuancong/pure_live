# NimoTV 合同检查点（2026-09-21）

## 当前公开合同

- 官网 `https://www.nimo.tv/` 当前可见公开直播推荐快照；
- 移动房间页 `https://m.nimo.tv/{channel}` 内嵌 `G_roomBaseInfo`，提供稳定 `roomId`、主播身份、标题、分类、直播状态、`viewerNum` 与 `mStreamPkg`；
- 数字房间规范化为 `/live/{roomId}`，频道别名规范化为 `/{alias}`；精确搜索接受频道号、别名和官方链接；
- 官网通过 `nimojavauif.webHome` 与 `webHotRecommendColumn` WUP/WebSocket 会话渲染推荐卡片。适配器复用官网页面会话，读取稳定数字 `roomId`、标题、主播、标签和卡片当前观看人数；这是有限推荐快照，不宣称覆盖全站；
- 关键词搜索在同一快照内有界过滤，精确频道查询继续以移动房间页为权威详情。

## 媒体与指标

`mStreamPkg` 是十六进制编码的媒体参数包。源码有界解码后提取官方 FLV 域名、流 ID、`appid`、`tp`、`wsSecret` 与 `wsTime`，并按平台 ratio 生成：

| 稳定 ID | 展示档位 |
| --- | --- |
| `flv:6000` | 1080p |
| `flv:2500` | 720p |
| `flv:1000` | 480p |
| `flv:500` | 360p |
| `flv:250` | 240p |

媒体地址固定升级为 HTTPS，主机限制为 NimoTV 官方 FLV 子域。`wsTime` 按十六进制 Unix 秒解析，播放器提前五分钟刷新并在标记到期前十秒判定失效；播放恢复与录制入口重新读取房间页取得新签名，同时保持原 ratio 选择。

官网卡片观看数与房间页 `viewerNum` 分别用于目录和详情的当前观看人数；下播或字段缺失时保持未知，不以其他互动字段补值。首页播放器只提供动态预览而没有稳定海报 URL，目录卡片使用公开主播头像，不拼接虚构封面。远端聊天尚待单独接入。

## 当前生产证据

2026-09-21 重新抓取官网会话，确认首页通过 `nimojavauif.webHome` 和 `webHotRecommendColumn` 返回有限推荐，页面卡片具备稳定数字房间 ID、标题、主播、标签及当前观看数（含 `k` 缩写）。从首页选择当前公开房间后，移动房间页返回直播状态与时效媒体包；按当前 Streamlink 参数规则生成 HTTPS FLV，请求返回 HTTP 200，开头字节为标准 `FLV` 文件头。该证据证明当前目录与样本媒体合同可达，不替代 Android/Windows 原生播放和短录验收。

## 源码与验证边界

适配器、官网浏览器目录、有限快照关键词搜索、链接解析、注册表、设置目录迁移、指标能力、网页链接回流和中英文范围说明已写入源码。目录结果缓存 45 秒，同一解析器合并并发读取，避免列表刷新反复创建网页会话。确定性契约测试与迁移测试已写入 `test/nimotv_site_test.dart`、`test/nimotv_catalog_migration_test.dart` 和 `test/web_search_room_parser_test.dart`；按当前“功能先行、集中验收”批次，测试执行与双端原生验证保留到源码收敛阶段。

## 参考

- NimoTV 官网：<https://www.nimo.tv/>
- NimoTV 官方 Web Player SDK：<https://github.com/NiMO-TV/nimo-player-web>
- Streamlink NimoTV 当前实现：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/nimotv.py>
- Streamlink 2026 变更记录：<https://github.com/streamlink/streamlink/blob/master/CHANGELOG.md>
