# PandaTV 官网 LIVE 与 BJ 搜索接入

## 官方合同与本机只读核验

- 官网 `https://www.pandalive.co.kr/search/live?text=...` 与 `/search/bj?text=...` 对应的当前前端脚本 `https://cdn.pandalive.co.kr/next/main/c57bbf9/pp/_next/static/chunks/07vaw1px667ng.js` 分别调用 `POST /v1/live/index` 和 `POST /v1/live/bj_list`；LIVE 搜索使用 `orderBy=user`、`searchVal`、`offset`、`limit`，BJ 搜索使用 `searchVal`、`offset`、`limit`。网站输入框要求至少 2 个字符。
- 2026-09-23 本机向官网公共接口只读查询“가온”：LIVE 返回 4 条、`page.total=4`；BJ 返回首批 10 条、`page.total=12`，包括带当前 `media` 的主播和无 `media` 的未开播主播。BJ 条目还出现官网社交登录身份 `1506087545@ka`，官方 `/v1/member/bj` 能用该 ID 返回同一账号。
- LIVE 卡的 `user` 是当前观看；BJ 无 `media` 的资料不生成 0 在线值，`scoreWeek`/`scoreMonth`/`rank` 不当作观看人数。搜索卡只读取元数据，不请求播放 token 或媒体列表。

## 源码路径

- 搜索在同一结果页合并 LIVE 和 BJ 两个官方数据源，按用户请求的页容量拆分，分别保持原生 offset/limit，依稳定 `userId` 去重。先查 BJ 再查 LIVE，避免本机 Clash 路径上同时请求时 BJ 超时、离线主播被漏掉。官方房间/频道链接仍走精确详情；普通英文精确 ID 存在时优先返回同一账号，缺失时继续官网关键词搜索。
- BJ 条目的嵌套 `media.userId/userIdx` 与外层账号必须一致。离线资料保留离线状态和头像，不虚构当前观看。特殊 `@` 账号只允许有限字母数字后缀，并保持官网稳定频道 URL。
- 搜索能力登记为“直播和未开播 + 原生分页”，目录范围提示与平台能力表同步更新；无已核验的累计观看时保持未知。

## 验证与剩余范围

定向测试：`test/pandalive_native_search_test.dart`、`test/pandalive_site_test.dart` 及搜索页/生命周期测试，合计 **92/92** 通过；回归测试还验证 LIVE/BJ 请求不并发。只读注册适配器探针：`tool/probes/pandalive_native_search_probe_test.dart`，由 `PURELIVE_PANDA_SEARCH_PROBE=1` 显式启用，海外访问可设置本机 `PURELIVE_PANDA_PROXY=http://127.0.0.1:7897`。2026-09-23 官方实时接口探针查到 LIVE 4 条、BJ 10 条（其中未开播 9 条），注册适配器合并后 13 条（未开播 9 条），无播放/录制请求。PandaTV 弹幕、双端候选首帧、短录、断流恢复及完整发布验收仍按 3.2.0 验收矩阵收口。
