# 小红书 HLS 旧缓存标签与录制预取准入（2026-09-24）

## 缺口与修订

[早期小红书真实控制器短录](XIAOHONGSHU_CONTROLLER_NATIVE_AUDIT_2026_09_10.md)的两轮文件通过严格解码，但 `prefetchEnabled=true` 时 `prefetchFeedCount=0`，实际退回普通 relay。早期捕获的 HLS 清单含 `#EXT-X-ALLOW-CACHE:YES`；保留窗口将该旧标签列为未知，因此不会接纳预取。这个历史清单不是当前现网清单，不能据此声称现在的源仍带同一标签。

[RFC 8216 第 7 节](https://www.rfc-editor.org/rfc/rfc8216#section-7)记录 `EXT-X-ALLOW-CACHE` 在协议版本 7 移除；[Apple 的版本说明](https://developer.apple.com/documentation/http-live-streaming/about-the-ext-x-version-tag)也列出移除项。当前解析器只把精确的 `YES` 视为不限制媒体保留的旧声明，保留窗口仍核对序列、片段和所有其他标签；`NO` 或无效值继续拒绝预取并走原始 relay。重复标签直接判清单错误。渲染的本地清单不重放该旧标签。

## 验证与边界

- 确定性解析测试覆盖 `YES` 的片段身份往返、`NO`/无效值的退回，以及重复标签拒绝。
- 实际本地 HTTP relay 测试覆盖 `YES` 进入一条预取 feed、`NO` 保持 0 feed 且返回原始清单；相邻预取集成回归一并执行。
- 聚焦三文件 **41/41** 通过：`20260923T163019994Z-quality-focused.json`。修订后的全仓 Analyze 为 0 error / 0 warning、1 项既有 info：`20260923T163315294Z-quality-focused.json`。首轮测试因把仅适用于未结束清单的 `EXT-X-START` 断言套到结束清单而失败，原记录 `20260923T162905201Z-quality-focused.json` 保留；改为核对实际预取准入及渲染时间线标签后通过。

本批只证明共用 HLS 解析与中继对这种旧标签的行为，尚未重新取得小红书现网清单，也未执行新候选的原生播放、录制或 Android/Windows GUI 验收；先前普通 relay 的两轮成品证据保持原范围。
