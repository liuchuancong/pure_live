# media_core 迁移进度

目标:播放器核心、全屏、画中画、多画面全部改用 `C:\Users\XA-158\projects\flutter\media_core`(workspace 24 包,同作者从 pure_live 抽出的重写版)。

## 已完成

- **依赖接入** (7d3577fc):pubspec 以 path 依赖接入 `media_core`、`media_core_media_kit`、`media_core_ui`、`media_core_pip`、`media_core_fullscreen`、`media_core_multiview`;`dependency_overrides` 增加 floating(内置 AGP9 补丁)、media_kit_video(本地补丁版压过上游 git)、mime ^2.0.0、equatable ^3.0.0(压过 media_core 的 ^1.0.6/^2.1.0 声明)。
- **Kernel 引导** (7d3577fc):`lib/player/media_core/player_kernel_service.dart`,`AppInitializer.initialize` 中 `InitialServices.init()` 后 `unawaited(PlayerKernelService.ensureInitialized())`。注册后端:`const MediaKitAdapterFactory().registration()`(扩展方法在 media_kit 包内)。
- **全屏** (7d3577fc):`WindowService.doEnterWindowFullScreen/doExitWindowFullScreen` 改走 `media_core_fullscreen` 的 `FullscreenDriver` + `PureLiveFullscreenWindow`(保留 Windows 隐藏标题栏防 frameless 守卫的时序);`FullscreenConfig(restorePreviousBounds: false)` 保持旧行为。移动端方向锁/沉浸式仍由 WindowService 自己做(media_core 设计即如此:mobile 全屏是宿主职责)。`enterDesktopFullscreen` 助手保留(test 依赖)。

## 关键 API 速查(已核实)

- `PlayerKernel()..registerBackend(const MediaKitAdapterFactory().registration())`;`kernel.create(source: PlayerSource(id: SourceId('x'), uri: ...), config: const PlayerConfig(autoPlay: true))` → `PlayerHandle`。
- 视频渲染:`MediaPlayerView(handle: handle)`(media_core 包内 renderer);UI 套装 `MediaCorePlayerView`(media_core_ui)。
- 多画面:`MultiviewController(players: KernelPoolPlayerHost(kernel), config, qualityResolver)`;`assignAll(List<MultiviewCellSource>)`、`setVideoFocus/setAudioFocus/muteAll/handOverCell/startPatrol`、`snapshot` + `onChanged` 流;宿主自渲染网格,snapshot.cell 带 status/playerId/qualityLabel/danmaku。
- PiP:`PipSessionController.forKernel(driver:, kernel:, surfaceBuilder:)`;驱动:`FloatingSystemPip`(Android 系统 PiP,floating ^6.0.0)、`WindowManagerPipWindow`(桌面小窗)。
- FullscreenDriver:`apply(PlayerId, PresentationRequest.fullscreen()/windowFullscreen()/normal())`;`FullscreenWindow` 接口 = isFullscreen/captureBounds/setFullscreen。

## 待迁移(下一波)

> media_core 处于开发阶段:下述缺口直接在 media_core 仓库补 API(只加通用能力,业务逻辑不进 media_core)。

1. **多画面(方案已定:引擎换核,编排保留)**:不采用 media_core `MultiviewController` 整体接管——pure_live 的逐格画质/线路切换、签名 URL 租约续期(斗鱼匿名原画 300s 过期)、focus 轨道可见性门控、弹幕会话是纯业务编排,media_core 墙模型没有对应物;直接换墙会丢功能。改法:`multiview_cell_player.dart` 重写为 kernel `PlayerHandle` 句柄(仍实现现有 `MultiviewCellPlayerHandle` 接口,`videoController` 从 adapter 底层 mk.Player/VideoController 取,`handle.player` 已公开),控制器 1423 行零改动,页面 `_MultiviewCellView` 渲染换 `MediaPlayerView(handle:)` 或继续 media_kit Video。
   - media_core 待补:①media_kit adapter 的 `videoFrameProgress` 心跳目前 Windows-only(`_frameProgressSupported`),Android 侧帧看门狗需要它——依赖 pure_live 补丁版 media_kit_video 的 frameRevision,把观察器扩展到 Android。渲染与句柄复用无缺口:`handle.adapter as PlayerVideo` 即视频输出,`(handle.adapter as MediaKitPlayerAdapter).videoController` 已公开底层控制器(已核实)。
2. **Windows 画中画**:方向与原计划相反——pure_live `WindowHelper` 的多显示器/记忆位置/最小尺寸/置顶几何(490 行)比 `WindowManagerPipWindow` 通用实现完整,应把这份几何能力**移植进 media_core_pip**(扩充 `PipWindow`/`WindowManagerPipWindow`:display 感知、bounds 持久化钩子),然后 pure_live `WindowService` 的事务包装(capture/prepare/restore 回滚)保持,host 操作改注入自定义 `PipWindow` 给 `PipDriver`。`PipSessionController` 等 Wave 4 主播放器上 kernel 后再接。
3. **Android 画中画**:`PlayerManager.prepareAppFloating/showAppFloating/closeAppFloating`(flutter_floating 应用内悬浮,~500 行)→ `PipDriver` + `FloatingSystemPip`(系统 PiP)。前置:核对 background_playback_service 与熄屏续播策略在系统 PiP 模式下的行为等价。
4. **播放核心**:`PlayerManager`(5028 行)→ `PlayerKernel`/`PlayerHandle`/`RecoveryLadder`;engine fallback→adapter registry, line fallback→`RecoveryLadder.nextLine`, 后台策略→media_core_native 后台保活。最大的一块,放在 PiP/多画面稳定后。
   - media_core 待补:pure_live 的 `OwnedPlaybackSource`(bigo/fc2/niconico 私有协议输入)在 PlayerSource/adapter 层无表达——需在 media_core 增加 custom-protocol 输入通道(adapter 级注册,业务编解码留在 pure_live)。
