# Windows 多画面长播原生终止定位（2026-09-24）

## 现象与边界

候选业务源码 `822af302`、Windows x64 Debug `3.1.8+4121`，在虎牙同一直播间的 1+3 主格与右上小格播放。约 28 分钟内两格画面均有变化、没有缓冲或错误遮罩；进程启动约 30 分 43 秒后于 2026-09-23 19:34:40 UTC 终止。Windows Application Error 事件 1000 记录 `pure_live.exe`、PID 74904、`ucrtbase.dll`、`0xc0000409` 和 Report ID `70ed05b3-2509-46ea-bb03-03eca609aab2`。同次 WER 1001 与本机转储 `C:\Users\123\AppData\Local\CrashDumps\pure_live.exe.74904.dmp` 保留在本机，转储不入 Git。

该轮未到 WIN-MULTI-01 的 30 分钟门槛，未执行 2×2；此事件是**进程终止**，不是 #875 所报“音频继续、视频停帧”的复现。可见场景无法单独证明原生 `frameRevision`、GPU 或声音全程正常。

## 第一无效状态

WinDbg `.ecxr; kv` 指向 `ucrtbase!abort+0x4e`，异常子码 `FAST_FAIL_FATAL_APP_EXIT` (7)；返回地址在本包 `libmpv-2.dll` 内。该 DLL 的调用点使用字符串 `Broken API use: mpv_render_context_free() not called.`；[mpv 源码](https://github.com/mpv-player/mpv/blob/master/player/client.c)在销毁核心时若仍有 render context，正是记录该消息并 `abort()`。[render API 合同](https://github.com/mpv-player/mpv/blob/master/include/mpv/render.h)要求先释放 render context 再销毁核心。当前 WinDbg 缺少 libmpv 私有符号，因此这证明终止条件，不提供更细的内部函数归因。

本仓库 Windows 视频插件此前有两段未闭合的异步所有权：

1. `VideoOutputManager.Dispose` 启动 detached worker 后立刻向 Dart 返回 `Success`；Dart `NativeVideoController._dispose` 因而提前结束，而 `NativePlayer.dispose` 会继续销毁 mpv 核心。
2. `VideoOutput::~VideoOutput` 即使已经进入 worker，也只是把 `mpv_render_context_free` 放入线程池，未等待完成；同时提前释放 D3D11 renderer。多格或恢复/换源下的队列延迟可以放大这个窗口。

本批修改使 Dispose 的平台通道响应发生在 worker 删除视频输出之后；析构先停止帧回调、排空已排队的渲染任务，等待 Flutter 纹理注销，再在线程池中同步完成 `mpv_render_context_free`，最后释放 D3D11 renderer。`destroyed_` 改为 atomic；后续静态复核发现回调可能在读取旧标志后、析构排空任务入队之后才提交新的渲染任务，故用同一 `callback_mutex_` 串行化“检查标志＋入队”和“标记销毁＋排空入队”。真实长播是否完全稳定仍由新候选实测决定。

## 采样器旁路缺陷

同次 30 分钟 CPU/GPU 采样器在目标进程结束时抛出 PowerShell StrictMode `Count` 属性错误，旧实现只在整个循环结束后输出 CSV，导致该轮没有性能序列。最小短生命周期进程复现了采样期间退出的路径；修订后每行立即追加 CSV，采样窗口中途退出时标记 `process_exit_observed` 并照常写 summary，同时预先冻结进程文件版本，避免退出后再次读取失效的 `MainModule`。`tool/test_windows_runtime_metrics.ps1` 10/10 通过；短生命周期复验生成了 1 行 CSV 与匹配 summary，退出标记为 true。旧轮缺失的序列不补造。

## 待完成验证

- 首个同步释放修订 Windows Debug 记录 `20260923T200222535Z-build-windowsx64-debug.json`，ZIP SHA-256 `2A601BBE39C9E55084BC54E850E708D7828317F1A6E9BDE845EA237863F35D30`。同一虎牙房间普通播放/返回、1+3 起播/返回/重进均成功，无新 WER；返回完成只落在 `(1.182s, 16.065s]` 的观测区间，关格完成未确认、长播未执行。该候选尚无回调入队互斥，不沿用为最终长播结论。
- 加入回调互斥后的 Windows Debug 编译/链接与打包成功，记录 `local-artifacts/build-records/20260923T204036859Z-build-windowsx64-debug.json`；ZIP 143,800,836 B、SHA-256 `7068873F3784856222582D7E64F5A4FC287050C6A7B3E622DAA6E678602109C9`，`media_kit_video_plugin.dll` SHA-256 `D026CC4A4391BBCB3CF0981FAA81E19D63226F933D5A8ACC067014E5510E13DA`。构建只证明 C++ 编译/链接与打包，最终 GUI 验收另行记录。
- 针对进入/退出、换源和多格恢复做短循环，观察 WER 与进程是否保持。
- 同一新候选重新执行 WIN-MULTI-01：1+3 大/小格与 2×2 分别连续播放至少 30 分钟，使用已修订的持久采样器记录帧 revision、缓冲、媒体错误、CPU/GPU 与退出回落。
- 这批源码与诊断不替代 Android 候选验收，也不构成 3.2.0 发布证据。
