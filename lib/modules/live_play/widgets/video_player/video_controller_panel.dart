import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/utils.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/settings/settings_page.dart';
import 'package:pure_live/plugins/barrage.dart';
import 'package:pure_live/plugins/extension/string_extension.dart';

import '../slide_animation.dart';

class VideoControllerPanel extends StatefulWidget {
  final VideoController controller;

  const VideoControllerPanel({
    super.key,
    required this.controller,
  });

  @override
  State<StatefulWidget> createState() => _VideoControllerPanelState();
}

class _VideoControllerPanelState extends State<VideoControllerPanel> {
  static const barHeight = 56.0;

  // Video controllers
  VideoController get controller => widget.controller;
  double currentVolume = 1.0;
  bool showVolume = true;
  Timer? _hideVolume;

  void restartTimer() {
    _hideVolume?.cancel();
    _hideVolume = Timer(const Duration(seconds: 1), () {
      setState(() => showVolume = true);
    });
    setState(() => showVolume = false);
  }

  @override
  void dispose() {
    _hideVolume?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.enableController();
    });
  }

  void updateVolumn(double? volume) {
    restartTimer();
    setState(() {
      currentVolume = volume!;
    });
  }

  @override
  Widget build(BuildContext context) {
    /// pip 模式不显示控制器
    if (controller.livePlayController.isPiP.value) {
      return Container();
    }
    IconData iconData;
    iconData = currentVolume <= 0
        ? Icons.volume_mute
        : currentVolume < 0.5
            ? Icons.volume_down
            : Icons.volume_up;
    return Material(
      type: MaterialType.transparency,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.mediaPlay): () => controller.videoPlayer.play(),
          const SingleActivator(LogicalKeyboardKey.mediaPause): () => controller.videoPlayer.pause(),
          const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () => controller.videoPlayer.togglePlayPause(),
          const SingleActivator(LogicalKeyboardKey.space): () => controller.videoPlayer.togglePlayPause(),
          const SingleActivator(LogicalKeyboardKey.keyR): () => controller.refresh(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () async {
            double? volume = 1.0;
            volume = await controller.getVolume();
            volume = (volume! + 0.05);
            volume = min(volume, 1.0);
            volume = max(volume, 0.0);
            controller.setVolume(volume);
            updateVolumn(volume);
          },
          const SingleActivator(LogicalKeyboardKey.arrowDown): () async {
            double? volume = 1.0;
            volume = await controller.getVolume();
            volume = (volume! - 0.05);
            volume = min(volume, 1.0);
            volume = max(volume, 0.0);
            controller.setVolume(volume);
            updateVolumn(volume);
          },
          const SingleActivator(LogicalKeyboardKey.escape): () => controller.toggleFullScreen(),
        },
        child: Focus(
            autofocus: true,
            child: StreamBuilder(
                initialData: false,
                stream: controller.videoPlayer.hasError.stream,
                builder: (c, d) {
                  return controller.videoPlayer.hasError.value
                      ? ErrorWidget(controller: controller)
                      : MouseRegion(
                          onHover: (event) => controller.enableController(),
                          onExit: (event) {
                            controller.showControllerTimer?.cancel();
                            controller.showController.toggle();
                          },
                          child: Stack(children: [
                            Container(
                              color: Colors.transparent,
                              alignment: Alignment.center,
                              child: AnimatedOpacity(
                                opacity: !showVolume ? 0.8 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: Card(
                                  color: Colors.black,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(iconData, color: Colors.white),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8, right: 4),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: SizedBox(
                                              width: 100,
                                              height: 20,
                                              child: LinearProgressIndicator(
                                                value: currentVolume,
                                                backgroundColor: Colors.white38,
                                                valueColor: AlwaysStoppedAnimation(
                                                  Theme.of(context).tabBarTheme.indicatorColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            () {
                              CoreLog.d("danmakuController.getWidget ....");
                              return controller.livePlayController.danmakuController.getWidget(key: UniqueKey());
                            }(),
                            GestureDetector(
                                onTap: () {
                                  if (controller.showSettting.value) {
                                    controller.showSettting.toggle();
                                  } else {
                                    controller.videoPlayer.isPlaying.value ? controller.enableController() : controller.togglePlayPause();
                                  }
                                },
                                onDoubleTap: () => controller.videoPlayer.isWindowFullscreen.value ? controller.toggleWindowFullScreen() : controller.toggleFullScreen(),
                                child: BrightnessVolumeDargArea(
                                  controller: controller,
                                )),
                            // SettingsPanel(
                            //   controller: controller,
                            // ),
                            LockButton(controller: controller),
                            TopActionBar(
                              controller: controller,
                              barHeight: barHeight,
                            ),
                            BottomActionBar(
                              controller: controller,
                              barHeight: barHeight,
                            ),
                          ]),
                        );
                })),
      ),
    );
  }
}

class ErrorWidget extends StatelessWidget {
  const ErrorWidget({
    super.key,
    required this.controller,
  });

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              S.current.play_video_failed,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => controller.refresh(),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
            ),
            child: Text(
              S.current.retry,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Top action bar widgets
class TopActionBar extends StatelessWidget {
  const TopActionBar({
    super.key,
    required this.controller,
    required this.barHeight,
  });

  final VideoController controller;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedPositioned(
        top: (!controller.videoPlayer.isPipMode.value && !controller.showSettting.value && controller.showController.value && !controller.showLocked.value) ? 0 : -barHeight,
        left: 0,
        right: 0,
        height: barHeight,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: barHeight,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.transparent, Colors.black45],
            ),
          ),
          child: Row(children: [
            if (controller.videoPlayer.fullscreenUI) BackButton(controller: controller),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  controller.room.title!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none),
                ),
              ),
            ),

            /// 直播中的关注列表
            IconButton(
              onPressed: () {
                // showFavorite(controller);
                showDialogList(controller, Get.find<FavoriteController>().onlineRooms, isReverse: false, title: S.current.favorites_title);
              },
              icon: const Icon(
                Icons.featured_play_list_outlined,
                color: Colors.white,
              ),
            ),

            /// 历史记录
            IconButton(
              onPressed: () {
                // showHistory(controller);
                showDialogList(controller, Get.find<SettingsService>().historyRooms, isReverse: true, title: S.current.history);
              },
              icon: const Icon(
                Icons.history,
                color: Colors.white,
              ),
            ),

            /// 时间，电池电量信息等
            if (controller.videoPlayer.fullscreenUI) ...[
              const DatetimeInfo(),
              BatteryInfo(controller: controller),
            ],

            /// 画中画
            if (!controller.videoPlayer.fullscreenUI && controller.videoPlayer.supportPip) PIPButton(controller: controller),
          ]),
        ),
      ),
    );
  }
}

/// 重置直播间
void resetRoomInDialog(VideoController controller, LiveRoom item, {isBottomSheet = false}) {
  // if (isBottomSheet) {
  //   var curContext = Get.context!;
  //   Navigator.pop(curContext);
  // } else {
  //   Utils.hideRightDialog();
  // }

  Navigator.pop(Get.context!);

  if (item.platform.isNullOrEmpty || item.roomId.isNullOrEmpty) {
    return;
  }

  if (item.platform == controller.livePlayController.liveRoomRx.platform.value && item.roomId == controller.livePlayController.liveRoomRx.roomId.value) {
    return;
  }
  controller.exitFull();
  controller.livePlayController.resetRoom(item);
}

/// 显示列表
void showDialogList(VideoController controller, RxList<LiveRoom> rooms, {var isReverse = false, String title = ""}) {
  // var livePlayController = Get.find<LivePlayController>();
  // if (controller.isVertical.value || !livePlayController.isFullscreen.value) {
  //   // controller.showFollowUserSheet();
  //   Utils.showBottomSheet(
  //     title: title,
  //     child: showDialogListBody(rooms, isReverse: isReverse, isBottomSheet: true),
  //   );
  //   return;
  // }
  //
  // Utils.showRightSheet(
  //   title: title,
  //   child: showDialogListBody(rooms, isReverse: isReverse),
  // );
  Utils.showRightOrBottomSheet(
    title: title,
    child: showDialogListBody(controller, rooms, isReverse: isReverse),
  );
}

Widget showDialogListBody(VideoController controller, RxList<LiveRoom> rooms, {isReverse = false, isBottomSheet = false}) {
  return LayoutBuilder(builder: (context, constraint) {
    final width = constraint.maxWidth;
    var dense = true;
    int crossAxisCount = width > 1280 ? 4 : (width > 960 ? 3 : (width > 640 ? 2 : 1));
    if (dense) {
      crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
    }
    return Obx(
      () => rooms.isEmpty
          ? EmptyView(
              icon: Icons.history_rounded,
              title: S.current.empty_history,
              subtitle: '',
              boxConstraints: constraint,
            )
          : SizeCacheWidget(
              estimateCount: 20 * 2,
              child: MasonryGridView.count(
                cacheExtent: 30,
                padding: const EdgeInsets.all(5),
                controller: ScrollController(),
                crossAxisCount: crossAxisCount,
                itemCount: rooms.length,
                itemBuilder: (context, index) => FrameSeparateWidget(
                    index: index,
                    placeHolder: const SizedBox(width: 220.0, height: 200),
                    child: SlideTansWidget(child: RoomCard(
                      room: isReverse ? rooms[rooms.length - 1 - index] : rooms[index],
                      dense: dense,
                      onTap: () {
                        resetRoomInDialog(controller, isReverse ? rooms[rooms.length - 1 - index] : rooms[index], isBottomSheet: isBottomSheet);
                      },
                    )),
              ))),
    );
  });
}

/// 时间信息
class DatetimeInfo extends StatefulWidget {
  const DatetimeInfo({super.key});

  @override
  State<DatetimeInfo> createState() => _DatetimeInfoState();
}

class _DatetimeInfoState extends State<DatetimeInfo> {
  DateTime dateTime = DateTime.now();
  Timer? refreshDateTimer;

  @override
  void initState() {
    super.initState();
    refreshDateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      setState(() => dateTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    super.dispose();
    refreshDateTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    // get system time and format
    var hour = dateTime.hour.toString();
    if (hour.length < 2) hour = '0$hour';
    var minute = dateTime.minute.toString();
    if (minute.length < 2) minute = '0$minute';

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Text(
        '$hour:$minute',
        style: const TextStyle(color: Colors.white, fontSize: 14, decoration: TextDecoration.none),
      ),
    );
  }
}

/// 电池信息
class BatteryInfo extends StatefulWidget {
  const BatteryInfo({super.key, required this.controller});

  final VideoController controller;

  @override
  State<BatteryInfo> createState() => _BatteryInfoState();
}

class _BatteryInfoState extends State<BatteryInfo> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Container(
        width: 35,
        height: 15,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(4),
        ),
        child: /*Center(
          child:*/
            Obx(() => Text(
                  '${widget.controller.batteryLevel.value}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9, decoration: TextDecoration.none),
                )),
        // ),
      ),
    );
  }
}

class BackButton extends StatelessWidget {
  const BackButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.videoPlayer.isWindowFullscreen.value ? controller.toggleWindowFullScreen() : controller.toggleFullScreen(),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
        ),
      ),
    );
  }
}

class PIPButton extends StatelessWidget {
  const PIPButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.enterPipMode(context),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: const Icon(
          CustomIcons.float_window,
          color: Colors.white,
        ),
      ),
    );
  }
}

// Center widgets
// Center widgets
class DanmakuViewer extends StatelessWidget {
  const DanmakuViewer({
    super.key,
    required this.danmakuController,
  });

  final BarrageWallController danmakuController;

  @override
  Widget build(BuildContext context) {
    return Obx(() => Opacity(
        opacity: SettingsService.instance.hideDanmaku.value ? 0 : SettingsService.instance.danmakuOpacity.value,
        child: SettingsService.instance.danmakuArea.value == 0.0
            ? Container()
            : LayoutBuilder(builder: (context, constraint) {
                final width = constraint.maxWidth;
                final height = constraint.maxHeight;
                return BarrageWall(
                  width: width,
                  height: height * SettingsService.instance.danmakuArea.value,
                  controller: danmakuController,
                  speed: SettingsService.instance.danmakuSpeed.value.toInt(),
                  maxBulletHeight: SettingsService.instance.danmakuFontSize * 1.5,
                  massiveMode: false,
                  // disabled by default
                  child: Container(),
                );
              })));
  }
}

class BrightnessVolumeDargArea extends StatefulWidget {
  const BrightnessVolumeDargArea({
    super.key,
    required this.controller,
  });

  final VideoController controller;

  @override
  State<BrightnessVolumeDargArea> createState() => BrightnessVolumeDargAreaState();
}

class BrightnessVolumeDargAreaState extends State<BrightnessVolumeDargArea> {
  VideoController get controller => widget.controller;

  // Darg bv ui control
  Timer? _hideBVTimer;
  bool _hideBVStuff = true;
  bool _isDargLeft = true;
  double _updateDargVarVal = 1.0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _hideBVTimer?.cancel();
    super.dispose();
  }

  void updateVolume(double? volume) {
    _isDargLeft = false;
    _cancelAndRestartHideBVTimer();
    setState(() {
      _updateDargVarVal = volume!;
    });
  }

  void _cancelAndRestartHideBVTimer() {
    _hideBVTimer?.cancel();
    _hideBVTimer = Timer(const Duration(seconds: 1), () {
      setState(() => _hideBVStuff = true);
    });
    setState(() => _hideBVStuff = false);
  }

  void _onVerticalDragUpdate(Offset position, Offset delta) async {
    if (controller.showLocked.value) return;
    if (delta.distance < 0.2) return;

    // fix darg left change to switch bug
    final width = MediaQuery.of(context).size.width;
    final dargLeft = (position.dx > (width / 2)) ? false : true;
    // disable linux brightness
    if ((Platform.isWindows || Platform.isLinux || Platform.isFuchsia) && dargLeft) return;
    if (_hideBVStuff || _isDargLeft != dargLeft) {
      _isDargLeft = dargLeft;
      if (_isDargLeft) {
        await controller.brightness().then((double v) {
          setState(() => _updateDargVarVal = v);
        });
      } else {
        await controller.getVolume().then((double? v) {
          setState(() => _updateDargVarVal = v!);
        });
      }
    }
    _cancelAndRestartHideBVTimer();

    double dragRange = (delta.direction < 0 || delta.direction > pi) ? _updateDargVarVal + 0.01 : _updateDargVarVal - 0.01;
    // 是否溢出
    dragRange = min(dragRange, 1.0);
    dragRange = max(dragRange, 0.0);
    // 亮度 & 音量
    if (_isDargLeft) {
      controller.setBrightness(dragRange);
    } else {
      controller.setVolume(dragRange);
    }
    setState(() => _updateDargVarVal = dragRange);
  }

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    if (_isDargLeft) {
      iconData = _updateDargVarVal <= 0
          ? Icons.brightness_low
          : _updateDargVarVal < 0.5
              ? Icons.brightness_medium
              : Icons.brightness_high;
    } else {
      iconData = _updateDargVarVal <= 0
          ? Icons.volume_mute
          : _updateDargVarVal < 0.5
              ? Icons.volume_down
              : Icons.volume_up;
    }

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _onVerticalDragUpdate(event.localPosition, event.scrollDelta);
        }
      },
      child: GestureDetector(
        onVerticalDragUpdate: (details) => _onVerticalDragUpdate(details.localPosition, details.delta),
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: AnimatedOpacity(
            opacity: !_hideBVStuff ? 0.8 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Card(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(iconData, textDirection: TextDirection.ltr, color: Colors.white),
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 100,
                          height: 20,
                          child: LinearProgressIndicator(
                            value: _updateDargVarVal,
                            backgroundColor: Colors.white38,
                            valueColor: AlwaysStoppedAnimation(
                              Theme.of(context).tabBarTheme.indicatorColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LockButton extends StatelessWidget {
  const LockButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() => AnimatedOpacity(
          opacity: (!controller.videoPlayer.isPipMode.value && !controller.showSettting.value && controller.videoPlayer.fullscreenUI && controller.showController.value) ? 0.9 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Align(
            alignment: Alignment.centerRight,
            child: AbsorbPointer(
              absorbing: !controller.showController.value,
              child: Container(
                margin: const EdgeInsets.only(right: 20.0),
                child: IconButton(
                  onPressed: () => {
                    controller.showLocked.toggle(),
                    if (Platform.isAndroid)
                      {
                        if (controller.showLocked.value) {controller.videoPlayer.disableRotation()} else {controller.videoPlayer.enableRotation()}
                      }
                  },
                  icon: Icon(
                    controller.showLocked.value ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 28,
                  ),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black38,
                    shape: const StadiumBorder(),
                    minimumSize: const Size(50, 50),
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}

// Bottom action bar widgets
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.controller,
    required this.barHeight,
  });

  final VideoController controller;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    return Obx(() => AnimatedPositioned(
          bottom: (!controller.videoPlayer.isPipMode.value && !controller.showSettting.value && controller.showController.value && !controller.showLocked.value) ? 0 : -barHeight,
          left: 0,
          right: 0,
          height: barHeight,
          duration: const Duration(milliseconds: 300),
          child: Container(
            height: barHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black45],
              ),
            ),
            child: Row(
              children: <Widget>[
                PlayPauseButton(controller: controller),
                RefreshButton(controller: controller),
                DanmakuButton(controller: controller),
                FavoriteButton(controller: controller),
                // if (controller.videoPlayer.isFullscreen.value)
                SettingsButton(controller: controller),
                const Spacer(),
                if (controller.videoPlayer.supportWindowFull && !controller.videoPlayer.isFullscreen.value) ExpandWindowButton(controller: controller),
                if (!controller.videoPlayer.isWindowFullscreen.value) ExpandButton(controller: controller),
              ],
            ),
          ),
        ));
  }
}

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.togglePlayPause(),
      child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: Obx(
            () => Icon(
              controller.videoPlayer.isPlaying.value ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
          )),
    );
  }
}

class RefreshButton extends StatelessWidget {
  const RefreshButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.refresh(),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: const Icon(
          Icons.refresh_rounded,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ScreenToggleButton extends StatelessWidget {
  const ScreenToggleButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => controller.isVertical.value ? controller.setLandscapeOrientation() : controller.setPortraitOrientation(),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: Obx(
            () => Icon(
              controller.isVertical.value ? Icons.crop_landscape : Icons.crop_portrait,
              color: Colors.white,
            ),
          ),
        ));
  }
}

class DanmakuButton extends StatelessWidget {
  const DanmakuButton({
    super.key,
    required this.controller,
  });

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => SettingsService.instance.hideDanmaku.toggle(),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Obx(() => Icon(
              SettingsService.instance.hideDanmaku.value ? CustomIcons.danmaku_close : CustomIcons.danmaku_open,
              color: Colors.white,
            )),
      ),
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        controller.showSettting.toggle();
        SettingsPage.showDanmuSetDialog(isFull: false);
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: const Icon(
          CustomIcons.danmaku_setting,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ExpandWindowButton extends StatelessWidget {
  const ExpandWindowButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.toggleWindowFullScreen(),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: RotatedBox(
          quarterTurns: 1,
          child: Obx(() => Icon(
                controller.videoPlayer.isWindowFullscreen.value ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                color: Colors.white,
                size: 26,
              )),
        ),
      ),
    );
  }
}

class ExpandButton extends StatelessWidget {
  const ExpandButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.toggleFullScreen(),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Obx(() => Icon(
              controller.videoPlayer.isFullscreen.value ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              color: Colors.white,
              size: 26,
            )),
      ),
    );
  }
}

class FavoriteButton extends StatelessWidget {
  FavoriteButton({
    super.key,
    required this.controller,
  }) {
    isFavorite = controller.livePlayController.isFavorite;
  }

  final VideoController controller;
  final settings = SettingsService.instance;
  late final RxBool isFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          if (isFavorite.value) {
            settings.removeRoom(controller.room);
          } else {
            settings.addRoom(controller.room);
          }
          isFavorite.toggle();
          // setState(() => isFavorite.toggle);
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: Obx(
            () => Icon(
              !isFavorite.value ? Icons.favorite_outline_outlined : Icons.favorite_rounded,
              color: Colors.white,
            ),
          ),
        ));
  }
}
