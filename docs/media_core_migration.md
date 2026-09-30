# media_core 迁移进度

目标:播放器核心、全屏、画中画、多画面全部改用 `C:\Users\XA-158\projects\flutter\media_core`(workspace 24 包,同作者从 pure_live 抽出的重写版)。

## 已完成

- **依赖接入** (7d3577fc):pubspec 以 path 依赖接入 `media_core`、`media_core_media_kit`、`media_core_ui`、`media_core_pip`、`media_core_fullscreen`、`media_core_multiview`;`dependency_overrides` 增加 floating(内置 AGP9 补丁)、media_kit_video(本地补丁版压过上游 git)、mime ^2.0.0、equatable ^3.0.0(压过 media_core 的 ^1.0.6/^2.1.0 声明)。
- **Kernel 引导** (7d3577fc):`lib/player/media_core/player_kernel_service.dart`,`AppInitializer.initialize` 中 `InitialServices.init()` 后 `unawaited(PlayerKernelService.ensureInitialized())`。注册后端:`const MediaKitAdapterFactory().registration()`(扩展方法在 media_kit 包内)。
- **全屏** (7d3577fc):`WindowService.doEnterWindowFullScreen/doExitWindowFullScreen` 改走 `media_core_fullscreen` 的 `FullscreenDriver` + `PureLiveFullscreenWindow`(保留 Windows 隐藏标题栏防 frameless 守卫的时序);`FullscreenConfig(restorePreviousBounds: false)` 保持旧行为。移动端方向锁/沉浸式仍由 WindowService 自己做(media_core 设计即如此:mobile 全屏是宿主职责)。`enterDesktopFullscreen` 助手保留(test 依赖)。

## 依赖与后端注册(e6415249)

- 依赖面已补齐:media_core、media_core_media_kit、media_core_ui、media_core_pip、media_core_fullscreen、media_core_multiview、media_core_presentation、media_core_floating、media_core_ijk_player、media_core_better_player、media_core_fvp;overrides 增加 better_player_plus/flv_lzc 指向内置 AGP9/vendored 插件。
- `PlayerKernelService` 注册四个后端:MediaKit(默认首选)、Ijk(flv_lzc,FLV/H.265 移动端)、BetterPlayer(video_player 生态)、Fvp(priority 80)。引擎选择交给 kernel 的 PlayerAdapterSelector 按协议/格式/直播能力打分。
- **待接线(下一波)**:①应用内小窗兜底(showAppFloating 的 flutter_floating overlay)→ `media_core_floating` 的 FloatingWindowPresenter/FloatingWindowOverlay(纯几何拖拽/吸附),替换后 flutter_floating 可退场;②`media_core_presentation` 的 PresentationDriverChain 把 FullscreenDriver+PipDriver+FloatingDriver 链进 kernel(`kernel_presentation_adapter.dart`),呈现模式统一从 kernel 走;③PlayerManager → PlayerKernel/RecoveryLadder。

## ③波次进度

- **①悬浮窗→media_core_floating(完成,5abe5b38)**:showAppFloating 以 OverlayEntry 挂 `FloatingWindowOverlay`(拖拽/吸附/视频宽高比/自带展开关闭控件),pure_live 只供内容与设置钩子;flutter_floating 插件连同 popup-hide 助手一并退场。
- **②presentation 链入 kernel(完成,4ebc1599)**:`PlayerKernelService` 向 kernel `attachPresentation(PresentationDriverChain)`——fullscreen/windowFullscreen→FullscreenDriver、pip→windows PipDriver、floating→FloatingDriver。呈现请求可经 kernel 下发。
- **③a custom-protocol 通道(media_core 本地 b55e825)**:`PlayerSource.metadata[kMediaKitCustomInputKey]` 携带宿主 recipe,`MediaKitPlayerConfig.customInputOpener` 在已绑定的 player 上打开它;缺 opener 抛错交由 RecoveryLadder 反应。pure_live 的 OwnedPlaybackSource/FFmpeg relay 逻辑留在宿主闭包里。
- **③b PlayerManager 主拆解(待做)**:5028 行 → `PlayerKernel.create`/`PlayerHandle`/`RecoveryLadder`。映射:engine fallback→adapter registry 打分选择(四后端已注册)、line fallback→`RecoveryLadder.nextLine`(候选源列表)、后台保活→`media_core_native`、签名 URL 刷新→RecoveryLadder 的换后端前刷新钩子、owned 源→custom-input recipe。完成后多画面旧引擎双路径(multiview_cell_player)与 lib/player/adapters 旧栈删除。

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
2. **Windows 小窗播放(已完成,逻辑进 media_core)**:media_core_pip 新增 `DisplayAwarePipWindow`(本地 0d69b29)承载全部几何策略——注入式多显示器 work-area 读取、记忆位置(显示器匹配 + 48×48 重叠校验)、尺寸钳制(140×90 下限)、右下角默认位、最小尺寸释放、失败逐步回滚、串行队列;`pipSmallWindowSize/pipResolvePlacement/pipDisplayIdForPosition` 纯函数公开。pure_live 侧 `windows_pip_driver.dart` 只用钩子接设置持久化(rememberPipPosition/windowsPip 偏好),`WindowHelper` 已删除;几何采集(desktop_manager)、PiP 置顶设置页、WindowService host 入口全部改走 driver(0f6156c7 → 7a35c13a)。
3. **Android 悬浮窗→系统 PiP(主路径已完成)**:返回键在播离开直播间改为拦截并 `enablePip()`(系统 PiP,路由驻留显示紧凑 UI),不再弹路由挂 flutter_floating overlay(add28849)。overlay 路径保留为兜底:应用内切换走的 pop、PiP 不可用/关闭时。后续如需彻底删除 overlay,需在根挂载 PiP 紧凑面(现有 `buildPiPOverlay` 未接线)。
4. **播放核心**:`PlayerManager`(5028 行)→ `PlayerKernel`/`PlayerHandle`/`RecoveryLadder`;engine fallback→adapter registry, line fallback→`RecoveryLadder.nextLine`, 后台策略→media_core_native 后台保活。最大的一块。
   - media_core 待补:pure_live 的 `OwnedPlaybackSource`(bigo/fc2/niconico 私有协议输入)在 PlayerSource/adapter 层无表达——需在 media_core 增加 custom-protocol 输入通道(adapter 级注册,业务编解码留在 pure_live)。
