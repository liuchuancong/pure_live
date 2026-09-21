# PopkonTV 合同检查点（2026-09-21）

## 当前 Web 合同

PopkonTV 官网与公开直播目录当前活跃。现行 Web 客户端通过同源 `/api/proxy` 访问：

- `POST /broadcast/v3.1/livelist`：`pageNum`、`pageSize` 原生分页；`sortType` 支持
  最新（0）、热门（2）、新人（3）、热榜（4）；
- `POST /broadcast/v1.1/search/all`：按频道 ID 或昵称关键词返回 `broadCastList` 与
  `liveList`，因此同一结果集可覆盖开播和未开播主播；
- `POST /broadcast/v1/castwatchonoffguest`：由 `castSignId`、`castPartnerCode`、
  `castStartDateCode` 与 `castType` 建立游客观看会话；
- `castHlsUrl`：带时效参数的 HLS master，读取时保留官网 `Origin` 与直播间 `Referer`。

公开卡片字段按平台语义分列：`watchCnt` 为当前观看，`totalWatchCnt` 为本场累计观看，
`bookmark` / `bookmarkCnt` 为收藏或关注。`isAdult`、`isPrivate` 与会话状态码保持为访问
状态，不把受限房间伪装成下播或空媒体。

## 生产探测

2026-09-21 从官网目录取得当前非成年、非密码直播样本：

1. 目录请求返回 HTTP 200、`S2000`、原生页码/总页数和当前直播字段；
2. 频道 ID 与昵称分别请求搜索接口，均返回同一主播资料和直播条目；
3. 游客观看接口返回 `L0000` 与带时效参数的 `castHlsUrl`；
4. 使用官网 `Origin` / `Referer` 请求该 HLS，返回 HTTP 200、
   `application/vnd.apple.mpegurl`，首行为 `#EXTM3U`；
5. 当前主清单样本给出 `1920x1080` 变体。样本频道、时效参数和完整媒体地址仅保留在本机探测产物。

## 源码范围

- 官网直播目录四种排序与原生分页；
- 频道 ID、昵称关键词、当前/旧版官方房间链接识别；
- 开播/未开播、成年、密码及其他访问状态；
- 游客观看会话、HLS master 解析与稳定分辨率质量 ID；
- 播放、录制和恢复均重新建立时效会话，并保持用户所选质量；
- `watchCnt`、`totalWatchCnt`、收藏/关注字段分列；
- 远端聊天处于后续能力批次，本地互动入口已注册。

契约测试和目录迁移测试已写入 `test/popkontv_site_test.dart` 与
`test/popkontv_catalog_migration_test.dart`；完整 Flutter 测试、双端播放与录制验收按当前
源码批次在末尾集中执行。

## 参考来源

- PopkonTV 官方首页：<https://www.popkontv.com/>
- PopkonTV 官方直播目录：<https://www.popkontv.com/live-more>
- PopkonTV 官方帮助文档：<https://docs.popkontv.com/>
- 现行参考实现：<https://github.com/ihmily/DouyinLiveRecorder>
