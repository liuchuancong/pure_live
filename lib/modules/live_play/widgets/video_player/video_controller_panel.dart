import 'dart:io';
import 'dart:async';

import 'package:flutter_svg/svg.dart';
import 'package:flutter/gestures.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/widgets/play_other.dart';
import 'package:pure_live/modules/live_play/danmaku_settings_binding.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku_settings_page.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/volume_control.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class VideoControllerPanel extends StatefulWidget {
  final VideoController controller;

  const VideoControllerPanel({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() => _VideoControllerPanelState();
}

class _VideoControllerPanelState extends State<VideoControllerPanel> {
  static const barHeight = 56.0;
  Offset? _lastTapPosition;

  VideoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.enableController();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Focus(
        autofocus: true,
        child: Obx(() {
          final double currentVolume = controller.currentVolume.value;
          final int percentage = (currentVolume * 100).round();

          final IconData iconData = currentVolume <= 0
              ? Icons.volume_mute
              : currentVolume < 0.5
              ? Icons.volume_down
              : Icons.volume_up;

          return MouseRegion(
            onHover: (_) => controller.onMouseHoverPlayer(),
            onExit: (_) => controller.onMouseExitPlayer(),
            cursor: !controller.showController.value ? SystemMouseCursors.none : SystemMouseCursors.basic,
            child: Stack(
              children: [
                Container(
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: AnimatedOpacity(
                    opacity: controller.showVolume.value ? 0.8 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Card(
                      color: Colors.black,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(iconData, color: Colors.white),
                            Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 100,
                                  height: 20,
                                  child: LinearProgressIndicator(
                                    value: currentVolume,
                                    backgroundColor: Colors.white38,
                                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              "$percentage%",
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Obx(
                  () => Offstage(
                    offstage: controller.hideDanmaku.value,
                    child: DanmakuViewer(key: controller.danmuKey, controller: controller),
                  ),
                ),
                GestureDetector(
                  onTapDown: (details) => _lastTapPosition = details.globalPosition,
                  onTap: () {
                    final position = _lastTapPosition;
                    if (position != null && controller.handleDanmakuPointer(position, longPress: false)) return;
                    // A buffering/paused player must not swallow the only way
                    // to reveal its controls. Always expose the action bar; a
                    // tap on a paused surface keeps the historical resume
                    // behavior as well.
                    controller.enableController();
                    if (!GlobalPlayerService.instance.playerManager.isPlayingNow) {
                      GlobalPlayerService.instance.playerManager.togglePlayPause();
                    }
                  },
                  onLongPressStart: (details) {
                    controller.handleDanmakuPointer(details.globalPosition, longPress: true);
                  },
                  onDoubleTap: () {
                    if (!controller.showLocked.value) {
                      GlobalPlayerState.to.isWindowFullscreen.value
                          ? controller.toggleWindowFullScreen()
                          : controller.toggleFullScreen();
                    }
                  },
                  child: BrightnessVolumnDargArea(controller: controller),
                ),
                LockButton(controller: controller),
                TopActionBar(controller: controller, barHeight: barHeight),
                BottomActionBar(controller: controller, barHeight: barHeight),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class ErrorWidget extends StatelessWidget {
  const ErrorWidget({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(i18n("play_video_failed"), style: AppTextStyles.t14.copyWith(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () => controller.refresh(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2)),
            child: Text(i18n("retry"), style: AppTextStyles.t15.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Top action bar widgets
class TopActionBar extends StatelessWidget {
  const TopActionBar({super.key, required this.controller, required this.barHeight});

  final VideoController controller;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedPositioned(
        top: (controller.showController.value && !controller.showLocked.value) ? 0 : -barHeight,
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
          child: Row(
            children: [
              if (GlobalPlayerState.to.fullscreenUI) BackButton(controller: controller),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.room.title!,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.t16.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      if (controller.room.currentProgramme != null && controller.room.currentProgramme!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          "${i18n('now_playing')}: ${controller.room.currentProgramme!}",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (controller.room.platform == Sites.iptvSite)
                IconButton(
                  icon: const Icon(Icons.assignment_outlined), // 节目单账本图标
                  tooltip: i18n('view_schedule'),
                  color: Colors.white,
                  onPressed: () async {
                    Get.dialog(
                      AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: EdgeInsets.zero,
                        content: _buildFullSchedulePanel(),
                      ),
                    );
                  },
                ),
              if (GlobalPlayerState.to.fullscreenUI) ...[
                IconButton(
                  icon: const Icon(Icons.swap_horiz_outlined),
                  tooltip: i18n('switch_live_room'),
                  color: Colors.white,
                  onPressed: () {
                    Get.dialog(PlayOther(controller: Get.find<LivePlayController>()));
                  },
                ),
                const DatetimeInfo(),
                BatteryInfo(controller: controller),
              ],
              AudioOnlyButton(controller: controller),
              if (PlatformUtils.isAndroid) CastButton(controller: controller),
              if (!GlobalPlayerState.to.fullscreenUI && PlatformUtils.isAndroid) PIPButton(controller: controller),
              if (PlatformUtils.isWindows) PIPButton(controller: controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullSchedulePanel() {
    final now = controller.room.catchUpStart != null
        ? DateTime.fromMillisecondsSinceEpoch(controller.room.catchUpStart!)
        : DateTime.now();
    final theme = Theme.of(Get.context!);
    final screenSize = MediaQuery.of(Get.context!).size;

    final double dialogWidth = screenSize.width > 600 ? 460.0 : screenSize.width * 0.88;
    final double dialogHeight = screenSize.height > 800 ? 550.0 : screenSize.height * 0.65;
    controller.hasScrolledToLive = false;
    return Container(
      width: dialogWidth,
      height: dialogHeight,
      decoration: BoxDecoration(color: DialogTheme().backgroundColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 12, left: 24, right: 16),
            child: Row(
              children: [
                Icon(Remix.calendar_todo_line, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    i18n('channel_schedule'),
                    style: AppTextStyles.t15.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(Get.context!).pop(),
                  icon: const Icon(Remix.close_line, size: 20),
                  splashRadius: 20,
                  color: theme.hintColor,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: Obx(() {
              if (controller.currentChannelSchedule.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Remix.inbox_line, size: 40, color: theme.hintColor.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(i18n('no_upcoming_programs'), style: AppTextStyles.t13.copyWith(color: theme.hintColor)),
                    ],
                  ),
                );
              }
              final int liveIndex = controller.currentChannelSchedule.indexWhere((p) {
                final pStart = p.start.toLocal();
                final pStop = p.stop.toLocal();
                return !now.isBefore(pStart) && !now.isAfter(pStop);
              });
              if (liveIndex != -1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 20), () {
                    if (controller.scheduleScrollController.hasClients) {
                      final int totalItems = controller.currentChannelSchedule.length;

                      int targetIndex = liveIndex;
                      if (totalItems < 8) {
                        targetIndex = 0;
                      } else if (liveIndex >= totalItems - 4) {
                        targetIndex = totalItems - 1;
                      } else if (liveIndex >= 3) {
                        targetIndex = liveIndex - 3;
                      }
                      controller.scheduleObserverController.animateTo(
                        index: targetIndex,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  });
                });
              }

              return ListViewObserver(
                controller: controller.scheduleObserverController,
                child: ListView.builder(
                  controller: controller.scheduleScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  physics: const PureLiveScrollPhysics(),
                  itemCount: controller.currentChannelSchedule.length,
                  itemBuilder: (context, index) {
                    final prog = controller.currentChannelSchedule[index];
                    final isCurrent = index == liveIndex; // Optimized matching via index comparison

                    final activePrimary = theme.colorScheme.primary;
                    final unselectedTextColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85);
                    final secondaryTextColor = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        type: MaterialType.card,

                        color: isCurrent ? activePrimary.withValues(alpha: 0.06) : Colors.transparent,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isCurrent ? activePrimary.withValues(alpha: 0.15) : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          dense: true,
                          onTap: () => controller.onProgrammeTapped(prog),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? activePrimary.withValues(alpha: 0.1)
                                  : theme.cardColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${prog.start.hour.toString().padLeft(2, '0')}:${prog.start.minute.toString().padLeft(2, '0')}",
                              style: AppTextStyles.t13.copyWith(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                color: isCurrent ? activePrimary : secondaryTextColor,
                              ),
                            ),
                          ),
                          title: Text(
                            prog.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.t14.copyWith(
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCurrent ? activePrimary : unselectedTextColor,
                            ),
                          ),
                          trailing: isCurrent
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: activePrimary,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: activePrimary.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Remix.live_line, size: 11, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        i18n('live_tag'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _buildHistoryTag(prog, theme),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTag(database.EpgProgramme prog, ThemeData theme) {
    final now = DateTime.now();
    if (prog.stop.isBefore(now)) {
      return Icon(Remix.history_line, size: 16, color: theme.hintColor.withValues(alpha: 0.6));
    }
    return const SizedBox.shrink();
  }
}

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
        style: const TextStyle(color: Colors.white, decoration: TextDecoration.none),
      ),
    );
  }
}

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
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Obx(
            () => Text(
              '${widget.controller.batteryLevel.value}',
              style: const TextStyle(color: Colors.white, fontSize: 9, decoration: TextDecoration.none),
            ),
          ),
        ),
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
      onTap: () => GlobalPlayerState.to.isWindowFullscreen.value
          ? controller.toggleWindowFullScreen()
          : controller.toggleFullScreen(),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
    );
  }
}

class PIPButton extends StatelessWidget {
  const PIPButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: i18n('float_window_play'),
      color: Colors.white,
      onPressed: () {
        GlobalPlayerService.instance.playerManager.enablePip();
      },
      icon: const Icon(CustomIcons.float_window),
    );
  }
}

// Center widgets
class DanmakuViewer extends StatelessWidget {
  const DanmakuViewer({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.danmaku;
      return FlameBarrageWidget(
        controller: controller.danmakuController,
        // Video gestures own the full surface and forward only hits on actual
        // barrage bounds, so volume/brightness/double-tap remain responsive.
        enablePointerEvents: false,
        config: BarrageConfig(
          fontSize: controller.danmakuFontSize.value,
          topAreaDistance: controller.danmakuTopArea.value,
          area: controller.danmakuArea.value,
          bottomAreaDistance: controller.danmakuBottomArea.value,
          baseSpeed: controller.danmakuSpeed.value,
          opacity: controller.danmakuOpacity.value,
          fontWeight: FontWeight.w600,
          strokeWidth: controller.danmakuFontBorder.value,
          showStroke: controller.enableDanmakuStroke.value,
          noEmojiMode: controller.noEmojiMode.value,
          fps: settings.resolvedDanmakuFps(),
          maxPendingCount: 120,
          maxPendingAge: const Duration(seconds: 5),
          fontFamily: controller.danmakuFontFamilyName.value,
          trackHeight: (controller.danmakuFontSize.value * 1.55).clamp(24.0, 64.0).toDouble(),
          emojiSize: (controller.danmakuFontSize.value * 1.3).clamp(16.0, 48.0).toDouble(),
          pictureCacheMaxSize: 600,
          barragePoolMaxSize: 1000,
        ),
        emojiAtlas: EmojiAtlas.instance,
      );
    });
  }
}

class BrightnessVolumnDargArea extends StatefulWidget {
  const BrightnessVolumnDargArea({super.key, required this.controller});

  final VideoController controller;

  @override
  State<BrightnessVolumnDargArea> createState() => BrightnessVolumnDargAreaState();
}

class BrightnessVolumnDargAreaState extends State<BrightnessVolumnDargArea> {
  VideoController get controller => widget.controller;

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

  void updateVolumn(double? volume) {
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

    if (delta.distance < 0.5) return;

    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final dargLeft = (position.dx > (width / 2)) ? false : true;

    if (Platform.isWindows && dargLeft) return;

    if (_hideBVStuff || _isDargLeft != dargLeft) {
      _isDargLeft = dargLeft;
      if (_isDargLeft) {
        if (PlatformUtils.isMobile) {
          double v = await controller.brightness();
          setState(() => _updateDargVarVal = v);
        }
      } else {
        double? v = await controller.volume();
        setState(() => _updateDargVarVal = v ?? 1.0);
      }
    }

    _cancelAndRestartHideBVTimer();

    double sensitivity = 0.25;
    double deltaValue = -(delta.dy / (height / 2)) * sensitivity;

    double dragRange = _updateDargVarVal + deltaValue;

    dragRange = dragRange.clamp(0.0, 1.0);

    if ((dragRange - _updateDargVarVal).abs() > 0.001) {
      if (_isDargLeft) {
        controller.setBrightness(dragRange);
      } else {
        controller.setVolume(dragRange);
      }
      setState(() => _updateDargVarVal = dragRange);
    }
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

    final int percentage = (_updateDargVarVal * 100).round();

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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(iconData, color: Colors.white),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 100,
                          height: 20,
                          child: LinearProgressIndicator(
                            value: _updateDargVarVal,
                            backgroundColor: Colors.white38,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      "$percentage%",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
    return Obx(
      () => AnimatedOpacity(
        opacity: (GlobalPlayerState.to.fullscreenUI && controller.showController.value) ? 0.9 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Align(
          alignment: Alignment.centerRight,
          child: AbsorbPointer(
            absorbing: !controller.showController.value,
            child: Container(
              margin: const EdgeInsets.only(right: 20.0),
              child: IconButton(
                onPressed: () => {controller.showLocked.toggle()},
                icon: Icon(controller.showLocked.value ? Icons.lock_rounded : Icons.lock_open_rounded, size: 28),
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
      ),
    );
  }
}

class LineSelectorButton extends StatelessWidget {
  const LineSelectorButton({super.key, required this.controller});

  final VideoController controller;

  void _showMobileDialog(BuildContext context) {
    controller.isMenuOpen.value = true;
    controller.stopHideController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16.0),
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 10, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(i18n("select_line"), style: Theme.of(context).textTheme.titleMedium),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Obx(
                  () => ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: controller.livePlayController.state.value.player.playUrls.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == controller.livePlayController.state.value.player.currentLineIndex;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Center(
                          child: InkWell(
                            onTap: () {
                              controller.livePlayController.setResolution(
                                ReloadDataType.changeLine,
                                controller.livePlayController.state.value.player.currentQuality,
                                index,
                              );
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                width: double.infinity, // 设定按钮固定宽度
                                height: 38, // 设定按钮高度
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Get.theme.colorScheme.primary
                                      : Get.theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  i18n("toolbox_line", args: {"index": (index + 1).toString()}),
                                  style: AppTextStyles.t15.copyWith(color: isSelected ? Colors.white : null),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('cancel')))],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      controller.isMenuOpen.value = false;
      controller.enableController();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.livePlayController.state.value.player.playUrls.isEmpty) return const SizedBox.shrink();
      final bool isMobile =
          Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS;

      if (isMobile) {
        return GestureDetector(onTap: () => _showMobileDialog(context), child: _buildButtonChild());
      }

      const double itemHeight = 40.0;
      final double totalMenuHeight =
          (controller.livePlayController.state.value.player.playUrls.length * itemHeight) + 32;
      return PopupMenuButton<int>(
        position: PopupMenuPosition.over,
        offset: Offset(30, -totalMenuHeight),
        constraints: const BoxConstraints(minWidth: 110, maxWidth: 110),
        onOpened: () {
          controller.isMenuOpen.value = true;
          controller.stopHideController();
        },
        onSelected: (index) {
          controller.isMenuOpen.value = false;
          controller.livePlayController.setResolution(
            ReloadDataType.changeLine,
            controller.livePlayController.state.value.player.currentQuality,
            index,
          );
          controller.enableController();
        },
        onCanceled: () {
          controller.isMenuOpen.value = false;
          controller.enableController();
        },
        color: Colors.black.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white10),
        ),
        child: _buildButtonChild(),
        itemBuilder: (context) =>
            List.generate(controller.livePlayController.state.value.player.playUrls.length, (index) {
              final isSelected = index == controller.livePlayController.state.value.player.currentLineIndex;
              return PopupMenuItem(
                value: index,
                height: itemHeight,
                child: Center(
                  child: Text(
                    i18n("toolbox_line", args: {"index": (index + 1).toString()}),
                    style: AppTextStyles.t13.copyWith(color: isSelected ? Get.theme.colorScheme.primary : Colors.white),
                  ),
                ),
              );
            }),
      );
    });
  }

  Widget _buildButtonChild() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(
        i18n(
          "toolbox_line",
          args: {"index": (controller.livePlayController.state.value.player.currentLineIndex + 1).toString()},
        ),
        style: AppTextStyles.t13.copyWith(color: Colors.white),
      ),
    );
  }
}

class ResolutionSelectorButton extends StatelessWidget {
  const ResolutionSelectorButton({super.key, required this.controller});

  final VideoController controller;

  void _showMobileDialog(BuildContext context) {
    controller.isMenuOpen.value = true;
    controller.stopHideController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16.0),
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 10, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(i18n("select_quality"), style: Theme.of(context).textTheme.titleMedium),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Obx(
                  () => ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: controller.livePlayController.state.value.player.qualites.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == controller.livePlayController.state.value.player.currentQuality;
                      final qualityName = controller.livePlayController.state.value.player.qualites[index].quality;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Center(
                          child: InkWell(
                            onTap: () {
                              controller.livePlayController.setResolution(
                                ReloadDataType.changeQuality,
                                index,
                                controller.livePlayController.state.value.player.currentLineIndex,
                              );
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                width: double.infinity, // 独占一行宽度
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Get.theme.colorScheme.primary
                                      : Get.theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  qualityName,
                                  style: AppTextStyles.t15.copyWith(color: isSelected ? Colors.white : null),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('cancel')))],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      controller.isMenuOpen.value = false;
      controller.enableController();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.livePlayController.state.value.player.qualites.isEmpty) return const SizedBox.shrink();

      final bool isMobile =
          Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS;

      if (isMobile) {
        return GestureDetector(onTap: () => _showMobileDialog(context), child: _buildButtonChild());
      }

      // Windows 桌面端样式
      final qualityCount = controller.livePlayController.state.value.player.qualites.length;
      const double itemHeight = 40.0;
      final double totalMenuHeight = (qualityCount * itemHeight) + 32;

      return PopupMenuButton<int>(
        tooltip: i18n('toolbox_select_quality'),
        position: PopupMenuPosition.over,
        offset: Offset(15, -totalMenuHeight),
        padding: EdgeInsets.zero,
        onOpened: () {
          controller.isMenuOpen.value = true;
          controller.stopHideController();
        },
        onCanceled: () {
          controller.isMenuOpen.value = false;
          controller.enableController();
        },
        onSelected: (index) {
          controller.isMenuOpen.value = false;
          controller.livePlayController.setResolution(
            ReloadDataType.changeQuality,
            index,
            controller.livePlayController.state.value.player.currentLineIndex,
          );
          controller.enableController();
        },
        color: Colors.black.withValues(alpha: 0.85),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white10),
        ),
        child: _buildButtonChild(),
        itemBuilder: (context) => List.generate(qualityCount, (index) {
          final isSelected = index == controller.livePlayController.state.value.player.currentQuality;
          return PopupMenuItem(
            value: index,
            height: itemHeight,
            child: Center(
              child: Text(
                controller.livePlayController.state.value.player.qualites[index].quality,
                style: AppTextStyles.t13.copyWith(color: isSelected ? Get.theme.colorScheme.primary : Colors.white),
              ),
            ),
          );
        }),
      );
    });
  }

  Widget _buildButtonChild() {
    final currentIndex = controller.livePlayController.state.value.player.currentQuality;
    final qualityName = controller.livePlayController.state.value.player.qualites[currentIndex].quality;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(qualityName, style: AppTextStyles.t13.copyWith(color: Colors.white)),
    );
  }
}

// Bottom action bar widgets
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.controller, required this.barHeight});

  final VideoController controller;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      bool shouldShow =
          (controller.showController.value || controller.isMenuOpen.value) && !controller.showLocked.value;
      return AnimatedPositioned(
        bottom: shouldShow ? 0 : -barHeight,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const PureLiveScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        // 左侧组
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PlayPauseButton(controller: controller),
                            RefreshButton(controller: controller),
                            FavoriteButton(controller: controller),
                            if (SettingsService.to.danmaku.enableDanmakuDisplay.v) ...[
                              DanmakuButton(controller: controller),
                              SettingsButton(controller: controller),
                            ],
                          ],
                        ),

                        Obx(
                          () => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (GlobalPlayerState.to.isWindowFullscreen.value ||
                                  GlobalPlayerState.to.isFullscreen.value) ...[
                                if (!GlobalPlayerService.instance.playerManager.isVerticalVideo.value)
                                  ResolutionSelectorButton(controller: controller),
                                if (!GlobalPlayerService.instance.playerManager.isVerticalVideo.value)
                                  LineSelectorButton(controller: controller),
                              ],
                              VideoFitSetting(controller: controller),
                              if (Platform.isWindows) OverlayVolumeControl(controller: controller),
                              if (Platform.isWindows)
                                Obx(() {
                                  return Row(
                                    children: [
                                      if (controller.supportWindowFull && !GlobalPlayerState.to.isFullscreen.value) ...[
                                        ExpandWindowButton(controller: controller),
                                      ],
                                    ],
                                  );
                                }),
                              if (!GlobalPlayerState.to.isWindowFullscreen.value) ExpandButton(controller: controller),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    final playerManager = GlobalPlayerService.instance.playerManager;

    return GestureDetector(
      onTap: () => playerManager.togglePlayPause(),
      child: StreamBuilder<bool>(
        stream: playerManager.onPlaying.distinct(),
        initialData: playerManager.isPlayingNow,
        builder: (context, snapshot) {
          final isPlaying = snapshot.data ?? playerManager.isPlayingNow;
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(right: 6),
            child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
          );
        },
      ),
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
        padding: const EdgeInsets.only(right: 6),
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }
}

class DanmakuButton extends StatelessWidget {
  const DanmakuButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.hideDanmaku.toggle(),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.only(right: 6, left: 6),
        child: Obx(
          () => controller.hideDanmaku.value
              ? SvgPicture.asset(
                  'assets/images/video/danmu_close.svg',
                  // ignore: deprecated_member_use
                  color: Colors.white,
                )
              : SvgPicture.asset(
                  'assets/images/video/danmu_open.svg',
                  // ignore: deprecated_member_use
                  color: Colors.white,
                ),
        ),
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
      onTap: () async {
        if (controller.isMenuOpen.value) return;
        controller.isMenuOpen.value = true;
        try {
          await Get.dialog<void>(
            SettingsPanel(controller: controller),
            barrierColor: Colors.black.withValues(alpha: 0.58),
            useSafeArea: true,
          );
        } finally {
          controller.isMenuOpen.value = false;
          controller.enableController();
        }
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.only(right: 6, left: 6),
        child: SvgPicture.asset(
          'assets/images/video/danmu_setting.svg',
          // ignore: deprecated_member_use
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
        child: RotatedBox(
          quarterTurns: 1,
          child: Obx(
            () => Icon(
              GlobalPlayerState.to.isWindowFullscreen.value ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
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
        child: Obx(
          () => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(
              GlobalPlayerState.to.isFullscreen.value ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class AudioOnlyButton extends StatelessWidget {
  const AudioOnlyButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    final switching = controller.audioModeSwitching.value;
    return IconButton(
      tooltip: i18n(controller.isAudioOnly ? 'restore_video_mode' : 'switch_audio_only_mode'),
      visualDensity: VisualDensity.compact,
      iconSize: 21,
      color: controller.isAudioOnly ? const Color(0xFFFFD166) : Colors.white,
      onPressed: switching
          ? null
          : () {
              controller.enableController();
              controller.toggleAudioOnly();
            },
      // The headphone always means room-scoped audio-only. A television icon
      // is reserved exclusively for casting so the two actions stay distinct.
      icon: Icon(controller.isAudioOnly ? Remix.headphone_fill : Remix.headphone_line),
    );
  }
}

class CastButton extends StatelessWidget {
  const CastButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: i18n('cast_screen'),
      visualDensity: VisualDensity.compact,
      iconSize: 21,
      color: Colors.white,
      onPressed: () {
        controller.enableController();
        LiveUrlTool.castPlayUrlByRoomId(roomId: controller.room.roomId ?? '', platform: controller.room.platform ?? '');
      },
      icon: const Icon(Remix.tv_2_line),
    );
  }
}

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.controller});

  final VideoController controller;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  StreamSubscription<dynamic>? subscription;
  late bool isFavorite = SettingsService.to.fav.isFavorite(widget.controller.room);

  @override
  void initState() {
    super.initState();
    listenFavorite();
  }

  void listenFavorite() {
    subscription = EventBus.instance.listen('changeFavorite', (data) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.controller.enableController();
        if (isFavorite) {
          SettingsService.to.fav.removeRoom(widget.controller.room);
        } else {
          SettingsService.to.fav.addRoom(widget.controller.room);
        }
        setState(() => isFavorite = !isFavorite);
        EventBus.instance.emit('changeFavorite', true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 2),
        alignment: Alignment.center,
        height: 25,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(isFavorite ? Icons.check_rounded : Icons.close, color: Colors.white, size: 15),
            Text(isFavorite ? i18n('followed') : i18n('follow'), style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// Settings panel widgets

class VideoFitSetting extends StatefulWidget {
  const VideoFitSetting({super.key, required this.controller});
  final VideoController controller;
  @override
  State<VideoFitSetting> createState() => _VideoFitSettingState();
}

class _VideoFitSettingState extends State<VideoFitSetting> {
  VideoController get controller => widget.controller;
  @override
  Widget build(BuildContext context) {
    final descs = AppConsts().videoFitType.map((e) => i18n(e['desc'])).toList();
    final attrs = AppConsts().videoFitList;
    final player = SettingsService.to.player;

    return GestureDetector(
      onTap: () {
        controller.enableController();
        int currentIndex = player.videoFitIndex.v + 1;
        if (currentIndex >= attrs.length) {
          currentIndex = 0;
        }
        player.videoFitIndex.v = currentIndex;
        controller.setVideoFit(currentIndex);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 2),
        alignment: Alignment.center,
        height: 25,
        child: Obx(() => Text(descs[player.videoFitIndex.v], style: AppTextStyles.t15.copyWith(color: Colors.white))),
      ),
    );
  }
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.controller});

  final DanmakuSettingsBinding controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final targetWidth = isLandscape
        ? (size.width * 0.5).clamp(480.0, 640.0).toDouble()
        : (size.width * 0.92).clamp(300.0, 560.0).toDouble();
    final targetHeight = size.height * (isLandscape ? 0.9 : 0.84);
    const panelColor = Color(0xFF1E1E1E);

    return Dialog(
      alignment: isLandscape ? Alignment.centerRight : Alignment.center,
      backgroundColor: Colors.transparent,
      shadowColor: Colors.black54,
      elevation: 24,
      insetPadding: EdgeInsets.symmetric(horizontal: isLandscape ? 24 : 12, vertical: 12),
      child: Container(
        key: const ValueKey('fullscreen-danmaku-settings-panel'),
        width: targetWidth,
        height: targetHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: panelColor.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n('settings_danmaku_title'),
                          style: AppTextStyles.t16Bold.copyWith(color: Colors.white),
                        ),
                        Text(
                          i18n('danmaku_realtime_hint'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.t12.copyWith(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('fullscreen-danmaku-settings-close'),
                    tooltip: i18n('close'),
                    color: Colors.white70,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1, thickness: 0.8),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  scaffoldBackgroundColor: panelColor,
                  colorScheme: Theme.of(context).colorScheme
                      .copyWith(surface: panelColor, onSurface: Colors.white, onSurfaceVariant: Colors.white70),
                ),
                child: DanmakuSettingsContent(controller: controller, embedded: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
