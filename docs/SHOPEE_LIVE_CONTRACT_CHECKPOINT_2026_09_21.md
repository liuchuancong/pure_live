# Shopee Live 合同检查点（2026-09-21）

## 当前公开合同

首阶段限定 Shopee Indonesia：

- `GET https://shopee.co.id/api/v4/homepage/get_homepage_live_info` 返回官网首页有限推荐快照；
- 目录条目包含 `session_id`、标题、封面、`view_count`、店铺/用户/房间 ID 与直播状态；
- `GET https://live.shopee.co.id/api/v1/session/{session_id}` 返回场次详情与短时 `play_urls`；
- 会话端点现行网页会动态生成浏览器指纹及 SAP 请求头。源码先走普通 HTTP，收到访问校验后在无界面 WebView 中加载官网公开页面，并调用官网已加载的会话模块；
- FLV 请求保留官网 `Origin` / `Referer`，`expire_ts` 分别驱动提前刷新点和最终失效点。

目录 `view_count` 与详情 `viewer_count` 按当前观看人数展示。`member_cnt` 的累计/成员语义与并发口径不同，因此首阶段不写入在线列或累计列。

## 生产探测

2026-09-21 的公开链路验证结果：

1. Indonesia 首页接口返回 HTTP 200、10 条当前直播推荐与 300 秒刷新间隔；
2. 当前推荐场次经官网会话模块返回直播状态、主播/店铺身份、`viewer_count` 及带时效参数的 FLV；
3. 使用官网 Referer 请求该地址返回 HTTP 200、`Content-Type: video/x-flv`；
4. 媒体前 13 字节以 `46 4c 56 01 05 00 00 00 09 00 00 00 00` 开始，符合标准 FLV 文件头；
5. 当前令牌、场次号与完整播放地址仅用于临时探测，没有写入仓库。

## 源码范围

- 有限首页公开目录与明确范围提示；
- 当前快照标题关键词、精确场次 ID、官方分享链接搜索；
- 严格的地区化场次身份 `id:{session_id}`；
- 普通 HTTP 与官网浏览器上下文双路径会话解析；
- 按 URL `resolution` 聚合 FLV 多线路并保留稳定画质 ID；
- 播放、录制及恢复重新获取短时媒体地址，保持用户所选质量；
- 按 `expire_ts` 提前续期并拒绝过期预取地址；
- 当前观看人数单独展示，远端聊天列入后续能力批次。

契约测试和目录迁移测试写入 `test/shopeelive_site_test.dart` 与
`test/shopeelive_catalog_migration_test.dart`。完整 Flutter 测试、Android/Windows 播放与录制验收按当前源码批次在末尾集中执行。

## 参考来源

- Shopee Indonesia 官方首页：<https://shopee.co.id/>
- Shopee Live 官方页面：<https://live.shopee.co.id/guide-download>
- 公开会话调用参考：<https://github.com/classyid/shopee-live-cli>
- 公开目录调用参考：<https://github.com/classyid/shopee-live-watcher>
- 录制器现行 Shopee 解析参考：<https://github.com/ihmily/DouyinLiveRecorder/blob/main/src/spider.py>
