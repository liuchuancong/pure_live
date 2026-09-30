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

1. **多画面(进行中:整体移植到 media_core 墙)**:media_core_multiview 已补齐通用 API(本地提交 f6332a6):`MultiviewCellSource.expiresAt/renew`(签名 URL 由墙在每次(重)打开前续期)、`MultiviewCellStatus.paused`(看门狗跳过)、`pauseCell/resumeCell/setCellVolume/clearCellVolume`(播放/暂停按钮与房间音量记忆)。pure_live 侧重写 `multiview_controller.dart`:
   - 布局映射:pure single/dual/quad → 同名;**pure focus(容量4..9) → 墙 nine(容量9)**,一大多小的视觉/语义由 pure 页面自持,墙的 `setVideoFocus` 只管画质偏好与音质优先格。
   - 镜像填充:pure `cells`(MultiviewCellState)由墙 snapshot + 解析上下文填充;`videoController` 从 `(kernel.get(PlayerId(cell.playerId)).adapter as MediaKitPlayerAdapter).videoController` 取,**页面渲染零改动**(仍用 media_kit Video widget,不碰补丁 API)。
   - 换画质/线路 = 重新 `wall.assign(index, 新源)`(墙温复用播放器);租约 renew 闭包 = pure 侧重解析当前档位/线路。
   - **owned 私有协议源(bigo/fc2/niconico)双路径**:墙不支持自定义输入,这些房间继续走旧 `MultiviewCellPlayer`(文件保留),音频焦点同时驱动墙(setAudioFocus)与旧句柄(setMuted)。media_core 后续补 custom-protocol 输入通道后收敛为单路径。
   - 帧看门狗/multiview_frame_watchdog.dart 删除(墙的进度 tick 看门狗替代,跨平台,不依赖补丁版 media_kit_video)。setVisibleFocusSmallCells 保留为兼容 no-op。
2. **Windows 画中画**:方向与原计划相反——pure_live `WindowHelper` 的多显示器/记忆位置/最小尺寸/置顶几何(490 行)比 `WindowManagerPipWindow` 通用实现完整,应把这份几何能力**移植进 media_core_pip**(扩充 `PipWindow`/`WindowManagerPipWindow`:display 感知、bounds 持久化钩子),然后 pure_live `WindowService` 的事务包装(capture/prepare/restore 回滚)保持,host 操作改注入自定义 `PipWindow` 给 `PipDriver`。`PipSessionController` 等 Wave 4 主播放器上 kernel 后再接。
3. **Android 画中画**:`PlayerManager.prepareAppFloating/showAppFloating/closeAppFloating`(flutter_floating 应用内悬浮,~500 行)→ `PipDriver` + `FloatingSystemPip`(系统 PiP)。前置:核对 background_playback_service 与熄屏续播策略在系统 PiP 模式下的行为等价。
4. **播放核心**:`PlayerManager`(5028 行)→ `PlayerKernel`/`PlayerHandle`/`RecoveryLadder`;engine fallback→adapter registry, line fallback→`RecoveryLadder.nextLine`, 后台策略→media_core_native 后台保活。最大的一块,放在 PiP/多画面稳定后。
   - media_core 待补:pure_live 的 `OwnedPlaybackSource`(bigo/fc2/niconico 私有协议输入)在 PlayerSource/adapter 层无表达——需在 media_core 增加 custom-protocol 输入通道(adapter 级注册,业务编解码留在 pure_live)。
