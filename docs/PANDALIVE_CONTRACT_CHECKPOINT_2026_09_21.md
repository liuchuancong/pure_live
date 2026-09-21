# PandaTV 合同检查点（2026-09-21）

## 当前生产合同

PandaTV 官网、公开直播目录和创作者工作台当前活跃。现行 Web 客户端使用：

- `POST https://api.pandalive.co.kr/v1/live/index`：公开直播目录，原生
  `offset`/`limit` 分页与排序；
- `POST https://api.pandalive.co.kr/v1/member/bj`：按稳定频道 ID 读取主播资料、
  当前直播元数据和粉丝数；
- `POST https://api.pandalive.co.kr/v1/live/play`：建立观看会话，返回访问状态、
  当前在线人数与 `PlayList.hls*`；
- AWS IVS HLS 主清单：要求 `https://www.pandalive.co.kr` Origin 与官方直播间
  Referer，token 为短时会话数据。

## 在线媒体证明

本轮从官方公开目录取得一个当前直播频道，以频道 ID 完成资料与观看会话请求。返回身份在
目录、资料和观看响应间一致；主清单请求返回 HTTP 200，Content-Type 为
`application/vnd.apple.mpegurl`，首行为 `#EXTM3U`。

主清单明确列出 1080p60、720p60、480p、360p、160p 五档视频变体。完整 token、
频道样本和媒体地址只用于本地探测，没有写入仓库。

## 源码范围

- 官方目录分页与当前在线人数；
- 精确频道 ID、直播间链接和频道主页链接；
- 开播、下播、成年验证、密码及其他访问条件分类；
- AWS IVS HLS master 的分辨率、帧率和带宽解析；
- Origin/Referer 统一透传；
- 播放、录制与断流恢复时重新建立观看会话，并按稳定质量 ID 找回原档；
- 远端聊天与昵称关键词搜索继续列入后续能力批次。

## 来源

- PandaTV 官方首页：<https://www.pandalive.co.kr/>
- PandaTV 官方直播目录：<https://www.pandalive.co.kr/live>
- PandaTV 官方创作者工作台：<https://studio.pandalive.co.kr/>
- 当前 Web 客户端公开资源：<https://cdn.pandalive.co.kr/next/main/>
- 历史接口对照：<https://github.com/ihmily/DouyinLiveRecorder>
