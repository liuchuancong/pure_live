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

1. **多画面**:重写 `lib/modules/multiview/multiview_controller.dart`(现 1423 行)为 media_core `MultiviewController` 包装:保留 pure_live 侧 `resolveStreamForSite` 解析为 `MultiviewCellSource`,状态镜像 snapshot 到现有 Rx(layout/cells/focusedCellIndex/playingFlags/allMuted/danmakuEnabled),页面 `_MultiviewCellView` 从 `MultiviewCellPlayerHandle.videoController` 改为按 playerId 从 `KernelPortablePlayerRegistry(kernel).find()` 取 handle 渲染 `MediaPlayerView`。frame watchdog/解码预算/巡更由 media_core 内建,对应 pure_live 代码删除。页面 1389 行大体保留。
2. **Android 画中画**:`PlayerManager.prepareAppFloating/showAppFloating/closeAppFloating`(flutter_floating 应用内悬浮,~500 行)→ `PipSessionController` + `FloatingSystemPip`(系统 PiP)。注意:悬浮承载"路由退出后持续播放"的会话所有权,切换前须验证后台播放策略(background_playback_service)兼容。
3. **Windows 画中画**:`WindowHelper` 490 行多显示器/记忆位置几何比 `WindowManagerPipWindow` 通用实现更全;建议实现 media_core_pip 的 `PipWindow` 接口包装现有几何逻辑(适配而非替换),接 `PipSessionController`。
4. **播放核心**:`PlayerManager`(5028 行)→ `PlayerKernel`/`PlayerHandle`/`RecoveryLadder`;engine fallback→adapter registry, line fallback→`RecoveryLadder.nextLine`, 后台策略→media_core_native 后台保活。最大的一块,放在 PiP/多画面稳定后。
