# 战旗签名媒体前缀验证检查点（2026-09-21）

## 本轮目标

把“官网返回签名 URL”与“实际媒体可读”拆成两个阶段。只有候选响应通过有界字节验证后，后续 LiveSite 才能向播放器和录制器发布该线路；HTTP 200、Content-Type、目录状态和签名成功均不单独算作媒体证据。

## 官网与参考源码复核

- [战旗官网](https://www.zhanqi.tv/)和[直播目录](https://www.zhanqi.tv/lives)仍可访问，公开目录 API 本次返回 5 行，均为历史赛事或节目回放卡片。
- 首行 `code=11524053`、`roomId=111243`、`videoId=111243_FDfrB`，H5 矩阵仍只启用 CDN 202 的原画 FLV 单元。
- 公开访客接口、multipart 签名接口与 Ali 调度接口均返回成功；直连 HTTP/HTTPS 媒体均为 404 HTML。调度返回的 `*.tbcache.com` 节点在本机 DNS/代理路径仍没有得到可读取的媒体前缀，因此继续保留媒体未通过状态。
- GitHub 上可检索到的[战旗静态 FLV 播放列表](https://github.com/o0i/iptv/blob/master/kllist.m3u8)属于旧快照；其中 `dlhdl-cdn.zhanqi.tv` 当前 DNS 查询无记录，不把历史列表当作现行可播证明。

## 源码增量

`lib/core/site/zhanqi/zhanqi_media_api.dart` 新增独立候选验证阶段：

1. 每次请求只读取最多 4096 B，并发送 `Range: bytes=0-4095`、`Accept-Encoding: identity`；禁止自动重定向。
2. FLV 必须通过 `FLV` 签名、版本、音视频标志位与 data offset 检查；HLS 必须以可选 UTF-8 BOM 后的 `#EXTM3U` 开始。
3. 优先验证官方调度节点，再回退同一 source 的声明域名；每个 source 最多保留一个实际通过的 URI。
4. 默认全局候选预算为 12，上限为现有 64 source 的两倍；调用方取消会结束当前读取。
5. 全部网络读取异常与实际 404/HTML 分开归类，避免把环境连通性问题写成平台媒体下线结论。

新增 `test/zhanqi_media_probe_test.dart`，覆盖路由回退、FLV/HLS 字节识别、HTML 排除、全局预算、错误分类、身份边界和取消传播。

同日继续增加内部 `ZhanqiSite` 与官方链接解析器：目录保留官网分页，搜索只接收精确房间号/官方链接，`online` 按平台热度而非并发人数展示；详情、恢复和录制解析只消费 `ZhanqiValidatedMedia`，每次恢复重新读取房间、签名并验证媒体。该适配器尚未加入 `Sites` 注册表，因此当前用户界面平台数量保持不变。

## 验证与下一步

- 媒体验证与内部站点批次的变更 Dart 文件分别定向 Analyze：无问题。
- `git diff --check`：通过。
- 确定性测试按本轮源码先收敛顺序留到集中门禁。
- 战旗继续保留在未注册列表；内部站点已经只消费 `ZhanqiValidatedMedia`。下一步在新生产样本取得有效媒体前缀后完成 `Sites`、分享回流、收藏迁移、播放请求头与本地互动入口的应用注册。
