# 第二批平台生命周期检查点（2026-09-21）

## WinkTV

WinkTV 官方首页当前只展示服务迁移公告：独立服务已结束，并自 2025-06-02 起整合到
PandaTV。旧版参考实现使用的 `/v1/member/bj` 与 `/v1/live/play` 路径当前返回同一迁移公告，
POST 请求返回 405。这组旧合同继续留作历史对照，不创建重复平台入口。

结论：WinkTV 归入生命周期档案，其现存用户入口由 PandaTV 适配器承接。

## PandaTV

PandaTV 官方首页、直播目录和创作者工作台当前均保持活跃。现行 Web 客户端公开以下合同：

- `POST /v1/live/index`：直播目录，参数包含 `offset`、`limit`、`orderBy`；
- `POST /v1/member/bj`：精确频道信息与开播状态；
- `POST /v1/live/play`：观看会话、频道元数据和 `PlayList.hls*`；
- 媒体为带时效 token 的 AWS IVS HLS，主清单要求 PandaTV `Origin` 和 `Referer`。

当前在播样本已完成端到端检查：目录返回真实频道，观看接口返回 AWS IVS 主清单，带官方
请求头读取后响应为 HTTP 200 且首行为 `#EXTM3U`，并列出 1080p60、720p60、480p、
360p 与 160p 变体。样本身份、token 和完整媒体 URL不写入仓库。

结论：PandaTV 已完成“目录 → 精确频道 → 会话媒体 → 变体画质 → 播放/录制刷新 →
应用注册”，实现证据见 [PandaTV 合同检查点](PANDALIVE_CONTRACT_CHECKPOINT_2026_09_21.md)。

## PopkonTV

PopkonTV 官网、公开直播目录与帮助文档当前保持活跃。现行 Next.js Web 客户端公开：

- `POST /api/proxy/broadcast/v3.1/livelist`：热门、最新、新人、热榜四种排序和原生分页；
- `POST /api/proxy/broadcast/v1.1/search/all`：频道 ID 与昵称关键词搜索，同时返回直播和未开播主播；
- `POST /api/proxy/broadcast/v1/castwatchonoffguest`：按频道、合作方和场次建立游客观看会话；
- `castHlsUrl`：带时效参数的 HLS master，要求官网 `Origin` 与直播间 `Referer`。

当前非成年、非密码直播样本已完成端到端检查：目录和搜索身份一致，游客接口返回 HLS，
主清单响应为 HTTP 200、`application/vnd.apple.mpegurl`，首行为 `#EXTM3U` 并包含 1080p
变体。实现证据见 [PopkonTV 合同检查点](POPKONTV_CONTRACT_CHECKPOINT_2026_09_21.md)。

结论：PopkonTV 已完成“目录/搜索 → 精确频道 → 游客会话 → HLS 画质 → 播放/录制刷新 →
应用注册”。成年、密码和服务端访问条件保留为明确状态。

## 参考来源

- WinkTV 官方迁移页：<https://www.winktv.co.kr/>
- PandaTV 官方首页：<https://www.pandalive.co.kr/>
- PandaTV 官方直播目录：<https://www.pandalive.co.kr/live>
- PandaTV 官方创作者工作台：<https://studio.pandalive.co.kr/>
- PopkonTV 官方首页：<https://www.popkontv.com/>
- PopkonTV 官方直播目录：<https://www.popkontv.com/live-more>
- PopkonTV 官方帮助文档：<https://docs.popkontv.com/>
- 历史接口对照：<https://github.com/ihmily/DouyinLiveRecorder>
