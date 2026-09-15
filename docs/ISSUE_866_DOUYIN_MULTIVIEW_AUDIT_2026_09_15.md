# Issue #866 抖音多画面黑屏源码审计（2026-09-15）

## 结论

[上游 Issue #866](https://github.com/liuchuancong/pure_live/issues/866) 报告的是
Pure Live **3.1.3**。其中“多画面中的抖音直播黑屏”在该标签源码上存在一条可确定复现的
视频源选择缺陷：抖音响应可同时发布视频清晰度和内部 `ao` 纯音频 rendition，3.1.3 会把
`ao` 暴露成最后一个清晰度；多画面的小格降质路径又明确选择列表末项，最终可把只有音轨的
`only_audio=1` 地址当作视频源打开。

当前维护分支已在 `56cd4d971dcfbc434171f98760c6cc35630c53ae` 过滤这类纯音频
rendition。`09a716e62fb4f25671d093d389d12f723dc78f7d` 进一步加入真实抖音解析器到
多画面解析入口的跨层回归，证明最低档仍为视频源，同时保留严格房间解析和
User-Agent / Origin / Referer / Cookie 请求头。该子问题归类为
**fixed-in-current-source / native-recheck-pending**。

Issue 同时提到普通播放偶发失败、平板横屏启动偶发失败和 Windows 播放卡顿；报告没有日志、
截图、房间身份、是否有声音、清晰度/线路、网络时序或性能采样，且没有评论。现有证据不把这
三个现象归并到 `ao` 根因，也不据此宣称整条 Issue 已闭环。

## 3.1.3 稳定复现

- 标签：`v3.1.3`，提交 `41b75c28d8e131fab632aeffeb458245a979b0ab`。
- `DouyinSite.parseStreamQualities` 会保留 `origin / md / ao`；`ao` 的 URL 含
  `only_audio=1`。
- 同版本 `MultiviewController` 的合同是 `preferLowest == true` 时取
  `qualities.length - 1`，因此上述响应会选择 `ao`。
- 在独立的 3.1.3 worktree 运行确定性夹具，实际结果为
  `['origin', 'md', 'ao']`，预期视频清晰度集合 `['origin', 'md']`，结果
  **0 PASS / 1 FAIL**。日志与摘要：
  `local-artifacts/diagnostics/issue866-v313-regression/`。

该复现证明的是“响应含纯音频 rendition + 多画面最低档选择”的源码链，不把它外推为所有
房间、所有布局或 Issue 的其他三个现象。

## 当前源码合同

1. `DouyinSite._isAudioOnlyVariant` 同时识别规范化后的
   `ao / audio / audio_only` 标识，以及所有 URL 均声明 `only_audio=1/true` 的未知项。
2. `DouyinSite.parseStreamQualities` 在排序和去重前排除这些项目，最低档只能落到仍有视频轨
   的 rendition。
3. `MultiviewController.resolveStreamForSite` 对抖音走
   `LiveSiteRecordRoomResolver` 严格详情路径，再按最低档解析实际 URL。
4. 多画面源携带 `PlaybackHeaderResolver` 产生的 User-Agent、Origin、房间 Referer 与
   Cookie；新回归精确断言 `md` 视频 URL 和四类请求头。
5. 历史 K90 cycle 46 已在含 `56cd4d97` 的 Debug 候选上确认普通直播页画质菜单没有纯音频
   项、五个视频档和两条线路可见，短录成品同时含 H.264 与 AAC；证据为
   `local-artifacts/diagnostics/android-recording-smoke-20260901T232058196/summary.json`。
   这是普通播放/录制证据，不替代当前源码的多画面原生复验。

## 验证

| 层级 | 结果 |
|---|---|
| 3.1.3 历史夹具 | **0 PASS / 1 FAIL**；保留 `ao`，与最低档视频合同冲突 |
| 当前 `multiview_test.dart` + `douyin_playback_parser_test.dart` | **59/59 PASS** |
| 当前静态分析 | **No issues found**，本批一次 analyze |
| 最终质量记录 | `local-artifacts/build-records/20260915T103240776Z-quality-focused.json` |
| 仓库审计 | `local-artifacts/repository-audits/20260915T103118284Z-focused.json`，0 error / 2 warning |

本批没有修改产品运行时代码、构建新候选、启动 Windows GUI、连接 ADB、操作设备或发布；
Astra Light 使用 **0 次**。

## 后续原生边界

- 在包含当前源码的 Android/Windows 累计候选上分别验证 focus 大格、小格降质开/关、
  quad/dual、晋升、换清晰度、换线路、刷新、退出再进，并记录首帧、音视频轨和错误提示。
- Android 补手机/平板横竖屏冷启动、旋转期间选台、前后台返回和同房间普通页对照。
- Windows 对相同抖音房间采集窗口尺寸、DPR、选中源、首帧时间、buffering、CPU、GPU 3D、
  Video Decode、工作集及 2～10 分钟帧连续性，以事实区分源、渲染目标和机器负载。
- A3-06、A3-08 与 W3-03 保持 `RUN`；宏观账本仍为
  **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
