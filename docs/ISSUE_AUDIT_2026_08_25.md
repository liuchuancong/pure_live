# 上游 Issue 审计（2026-08-25）

审计范围：`liuchuancong/pure_live` 当前全部开放 Issue，重点复核最近两日新建的 #783、#786、#789、#791，以及仍开放的 Windows 性能问题 #767。

## 结论表

| Issue | 类型 | 代码结论 | v3.0.0 处理 |
|---|---|---|---|
| #791 Android 录制失败 | 缺陷 | 录制器复制了播放器请求头策略，只覆盖 Bilibili/Huya，斗鱼缺少反盗链头；同时把 `-5` I/O、403/404 一律判为永久错误，签名 URL过期后不会重新解析 | 已修复并加入请求头、命令、路径和重试回归 |
| #789 快捷按钮与观看历史策略 | 功能请求 | 当前底部导航可隐藏/排序，但多画面、搜索和工具箱快捷入口仍固定；观看历史上限仍为 50 | 作为独立设置/迁移功能保留在需求清单；不与本轮录制和发布修复混入同一稳定性冻结 |
| #786 Bilibili 热门来源 | 数据源缺陷 | 个性化推荐不能代表平台热度榜，且客户端排序必须使用明确热度字段 | v2.9.6/v2.9.7 已改用 `sort=online` 并执行稳定降序排序；接口门禁持续验证 |
| #783 低透明弹幕描边 | 渲染缺陷 | 多次偏移叠画在白色背景和低透明度下形成模糊块 | v2.9.4 已改为单次轮廓绘制和连续对比度曲线，回归测试保留 |
| #767 Windows 4K/高 DPI GPU | 性能缺陷 | 源分辨率纹理、Flutter 合成面和多进程窗口叠加造成高 3D 负载 | 当前分支已按 viewport/DPR 限制纹理并设上限、防抖与相关测试；原生视频平面属于后续架构级优化 |

## #791 根因链

1. 播放器的 `PlayerController.resolvePlaybackHeaders` 已为斗鱼提供房间 Referer、Origin、UA 与同一 DID Cookie。
2. `FFmpegHeaderFactory` 另有独立 switch，只处理 Bilibili 和虎牙，因此“播放器能播、录制输入 I/O 错误”可同时发生。
3. Bilibili 录制头还把 API host 写成 authority，和实际 CDN host 不一致；YY/IPTV 也没有复用播放器策略。
4. FFmpeg 输入 URL与输出路径没有引用，签名查询串中的 `&` 及带空格目录存在解析风险；强制 `0:v:0`/`0:a:0` 会拒绝短时单轨输入。
5. 控制器把 FFmpeg `-5`、HTTP 403/404 归为永久错误。直播 CDN 地址短期失效后，任务既不重新解析地址，也不进入正常轮询。
6. 每次统计回调都会排序整个任务列表并写 Hive，长时间录制产生额外 UI、CPU 和存储压力。

## 修复落点

- `lib/player/core/playback_header_resolver.dart`：播放器和录制器唯一请求头策略。
- `lib/recorder/services/ffmpeg_header_factory.dart`：透传平台及房间号。
- `lib/recorder/ffmpeg/ffmpeg_command_builder.dart`：引用输入/输出、可选轨道映射。
- `lib/recorder/services/recorder_continuation_policy.dart`：区分可刷新 CDN错误与本地永久错误。
- `lib/recorder/pages/recorder/recorder_controller.dart`：重新解析、写入探测、进度更新和持久化节流。
- `lib/recorder/services/path_helper.dart` / `cache_service.dart`：可移植目录组件与 Windows 保留名保护。
- `test/playback_header_resolver_test.dart`、`ffmpeg_record_command_test.dart`、`recorder_continuation_policy_test.dart`、`recorder_storage_policy_test.dart`：确定性回归。

## 验证边界

- Issue 附带日志只记录设备/应用头，没有 FFmpeg完整原始输出；根因结论来自截图中的 I/O 错误与对应源码路径的确定性复现。
- 外部 CDN、登录风控和直播上下播随时间变化；完整门禁通过公开接口探测验证当前合同，运行时继续采用超时、重新解析和有界重试。
- 本轮没有执行 ADB 或手机自动化；设备安装体验作为 Release 后独立验收层。

返回 [文档索引](README.md)。
