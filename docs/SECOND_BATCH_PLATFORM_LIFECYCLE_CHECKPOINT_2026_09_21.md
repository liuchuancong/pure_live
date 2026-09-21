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

结论：PandaTV 提升为 C2 首要实现项，按“目录 → 精确频道 → 会话媒体 → 变体画质 →
播放/录制刷新 → 注册”推进。

## 参考来源

- WinkTV 官方迁移页：<https://www.winktv.co.kr/>
- PandaTV 官方首页：<https://www.pandalive.co.kr/>
- PandaTV 官方直播目录：<https://www.pandalive.co.kr/live>
- PandaTV 官方创作者工作台：<https://studio.pandalive.co.kr/>
- 历史接口对照：<https://github.com/ihmily/DouyinLiveRecorder>
