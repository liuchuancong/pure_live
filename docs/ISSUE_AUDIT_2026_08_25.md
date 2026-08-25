# 上游 Issue 审计（2026-08-25）

审计范围：`liuchuancong/pure_live` 当前全部开放 Issue，重点复核 2026-08-25 新建的 #793～#798、此前的 #783、#786、#789、#791，以及仍开放的 Windows 性能问题 #767。审计冻结点为上游 `c22ae2f4`。

## 结论表

| Issue | 类型 | 代码结论 | v3.0.0 处理 |
|---|---|---|---|
| #798 YY 部分直播间不能播放 | 平台接口缺陷 | 当前网页的 HTTP StreamManager 会对部分匿名频道返回 `ErrAuthNotPass`，但 YY 官方移动 HLS 接口仍返回可播放、短时签名的 M3U8；只依赖 StreamManager 会把这类房间误判为无播放地址 | StreamManager 对齐官方 bid 121、SDK 5.23.0-beta.2 和 `text/plain` 合同；失败或空结果时自动切到匿名移动 HLS，按实际视频流去重清晰度，并实读 #798 房间的 M3U8 头 |
| #797 竖屏房间后横屏画面压缩 | 播放器状态缺陷 | 复用原生播放器时，上一房间的 width/height 流会保留到下一房间元数据到达，外层 `FittedBox` 因旧竖屏比例先压缩横屏画面 | 房间身份变化时同步清空宽高和竖屏标志；宽高必须成对有效才采用真实比例，并加入竖屏→横屏确定性回归 |
| #796 斗鱼录制失败 | 录制缺陷 | 播放器能播不代表 FFmpeg 能拉流；旧录制头缺少斗鱼房间 Referer/Origin/DID，且 403/404/I/O 被错误归类为永久失败 | 与 #791 共用播放请求头解析器，签名 URL 正确引用，过期 CDN 重新解析后有界重试，并覆盖命令/请求头/续录策略测试 |
| #795 Android 录制目录难导出 | 存储体验 | 设置页已支持用户选择目录，但需要明确隔离应用文件、验证可写性并避免“清空”误删所选父目录 | 自定义父目录下只管理带所有权标记的 `PureLiveRecords`；录制前实际写入探测，设置页可选择及打开目录，容量清理只遍历应用子目录 |
| #794 Windows 宽屏→画中画→关闭状态错误 | 状态机缺陷 | 进入 PiP 前没有保存全屏/宽屏表达状态，退出时统一重置会丢失宽屏 UI | 保存不可变 presentation snapshot；退出 PiP 后按“全屏优先、否则宽屏、否则普通”恢复，并加入状态优先级测试 |
| #793 Windows 重复启动导致现有窗口卡顿 | 启动性能缺陷 | 第二进程会先创建 Flutter engine、GPU surface、Dart isolate 和插件，随后才被 Dart 单实例插件拦截，短时资源竞争会卡住正在播放的窗口 | 无参数重复启动在 native runner 最前端由会话 mutex 拦截并唤醒已有窗口；分享链接、协议参数和 `--instance` 仍进入 Dart 转发/多窗口流程 |
| #791 Android 录制失败 | 缺陷 | 录制器复制了播放器请求头策略，只覆盖 Bilibili/Huya，斗鱼缺少反盗链头；同时把 `-5` I/O、403/404 一律判为永久错误，签名 URL过期后不会重新解析 | 已修复并加入请求头、命令、路径和重试回归 |
| #792 虎牙未开播房间显示历史弹幕 | 功能请求 | 需要独立的历史消息数据源、时间边界、隐私/屏蔽规则及“直播/回放”状态表达，不属于实时 WebSocket 断线恢复缺陷 | 保留为后续功能；v3.0.0 不把历史消息伪装成实时弹幕 |
| #789 快捷按钮与观看历史策略 | 功能请求 | 当前底部导航可隐藏/排序，但多画面、搜索和工具箱快捷入口仍固定；观看历史上限仍为 50 | 作为独立设置/迁移功能保留在需求清单；不与本轮录制和发布修复混入同一稳定性冻结 |
| #786 Bilibili 热门来源 | 数据源缺陷 | 个性化推荐不能代表平台热度榜，且客户端排序必须使用明确热度字段 | v2.9.6/v2.9.7 已改用 `sort=online` 并执行稳定降序排序；接口门禁持续验证 |
| #783 低透明弹幕描边 | 渲染缺陷 | 多次偏移叠画在白色背景和低透明度下形成模糊块 | v2.9.4 已改为单次轮廓绘制和连续对比度曲线，回归测试保留 |
| #767 Windows 4K/高 DPI GPU | 性能缺陷 | 源分辨率纹理、Flutter 合成面和多进程窗口叠加造成高 3D 负载 | 当前分支已按 viewport/DPR 限制纹理并设上限、防抖与相关测试；原生视频平面属于后续架构级优化 |
| #779 可选应用图标 | 功能请求 | 需要 Android/iOS 平台图标别名、桌面安装器资源和升级迁移共同设计，不是运行时缺陷 | 保留为独立外观功能，避免在稳定版冻结中替换用户现有图标 |
| #708 旧版全屏显示问题 | 历史缺陷报告 | 报告来自 2.0.21，缺少当前版本复现材料；直播页布局、全屏控制和弹幕层此后已多次重构 | 当前全屏/横竖屏测试继续覆盖；需要当前 3.0.0 复现步骤后再映射具体状态路径 |

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
- `lib/core/site/yy/yy_site.dart` / `tool/interface_probe.py`：YY 当前 StreamManager 合同、匿名 HLS 回退和 #798 直播清单实读。
- `lib/player/core/player_manager.dart` / `test/player_audio_mode_transition_test.dart`：跨房间视频几何清理。
- `lib/player/utils/fullscreen.dart` / `test/windows_pip_presentation_test.dart`：Windows PiP 前后显示模式快照与恢复。
- `windows/runner/main.cpp`：无参数重复启动的原生早期互斥与已有窗口激活。

## 验证边界

- Issue 附带日志只记录设备/应用头，没有 FFmpeg完整原始输出；根因结论来自截图中的 I/O 错误与对应源码路径的确定性复现。
- 外部 CDN、登录风控和直播上下播随时间变化；完整门禁通过公开接口探测验证当前合同，运行时继续采用超时、重新解析和有界重试。
- 本轮没有执行 ADB 或手机自动化；设备安装体验作为 Release 后独立验收层。

返回 [文档索引](README.md)。
