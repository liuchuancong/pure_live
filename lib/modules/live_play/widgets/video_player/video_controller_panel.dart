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
import 'package:pure_live/modules/live_play/dialogs/play_other.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/pages/danmaku_settings_page.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/content_first_panel_layout.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/volume_control.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_settings_binding.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_danmaku_style_editor.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';

@visibleForTesting
enum TopActionLeadingSlot { back, datetime, battery }

@visibleForTesting
enum TopActionTrailingSlot { roomHistory, datetime, battery, audioOnly, cast, pip }

/// Resolves the fixed order of the fullscreen leading actions. On Android the
/// clock and battery sit beside Back; PiP moves to the opposite corner so the
/// two groups match the user's visual scanning order.
@visibleForTesting
List<TopActionLeadingSlot> resolveTopActionLeadingSlots({required bool fullscreen, required bool android}) {
  if (!fullscreen) return const <TopActionLeadingSlot>[];
  return <TopActionLeadingSlot>[
    TopActionLeadingSlot.back,
    if (android) TopActionLeadingSlot.datetime,
    if (android) TopActionLeadingSlot.battery,
  ];
}

/// Keeps the three Android playback actions identical in portrait and
/// fullscreen: headphones, casting, then picture-in-picture.
@visibleForTesting
List<TopActionTrailingSlot> resolveTopActionTrailingSlots({
  required bool fullscreen,
  required bool android,
  required bool windows,
}) {
  return <TopActionTrailingSlot>[
    if (fullscreen) TopActionTrailingSlot.roomHistory,
    if (fullscreen && !android) TopActionTrailingSlot.datetime,
    if (fullscreen && !android) TopActionTrailingSlot.battery,
    TopActionTrailingSlot.audioOnly,
    if (android) TopActionTrailingSlot.cast,
    if (android || windows) TopActionTrailingSlot.pip,
  ];
}

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
                Obx(() {
                  final manager = GlobalPlayerService.instance.player;
                  final hideForPortrait =
                      manager.isVerticalVideo.value &&
                      SettingsService.to.player.portraitDanmakuMode == PortraitDanmakuMode.hidden;
                  return Offstage(
                    offstage: controller.hideDanmaku.value || hideForPortrait,
                    child: DanmakuViewer(key: controller.danmuKey, controller: controller),
                  );
                }),
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
                    if (!GlobalPlayerService.instance.player.isPlayingNow) {
                      GlobalPlayerService.instance.player.togglePlayPause();
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
                const PortraitStreamDiagnosticsBadge(),
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
              for (final slot in resolveTopActionLeadingSlots(
                fullscreen: GlobalPlayerState.to.fullscreenUI,
                android: PlatformUtils.isAndroid,
              ))
                switch (slot) {
                  TopActionLeadingSlot.back => BackButton(controller: controller),
                  TopActionLeadingSlot.datetime => const DatetimeInfo(key: ValueKey('fullscreen-leading-time')),
                  TopActionLeadingSlot.battery => BatteryInfo(
                    key: const ValueKey('fullscreen-leading-battery'),
                    controller: controller,
                  ),
                },
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
              for (final slot in resolveTopActionTrailingSlots(
                fullscreen: GlobalPlayerState.to.fullscreenUI,
                android: PlatformUtils.isAndroid,
                windows: PlatformUtils.isWindows,
              ))
                switch (slot) {
                  TopActionTrailingSlot.roomHistory => IconButton(
                    key: const ValueKey('fullscreen-room-history'),
                    icon: const Icon(Icons.swap_horiz_outlined),
                    tooltip: i18n('switch_live_room'),
                    color: Colors.white,
                    onPressed: () {
                      Get.dialog(PlayOther(controller: Get.find<LivePlayController>()));
                    },
                    style: IconButton.styleFrom(backgroundColor: Colors.black26),
                  ),
                  TopActionTrailingSlot.datetime => const DatetimeInfo(),
                  TopActionTrailingSlot.battery => BatteryInfo(controller: controller),
                  TopActionTrailingSlot.audioOnly => AudioOnlyButton(
                    key: const ValueKey('playback-action-audio-only'),
                    controller: controller,
                  ),
                  TopActionTrailingSlot.cast => CastButton(
                    key: const ValueKey('playback-action-cast'),
                    controller: controller,
                  ),
                  TopActionTrailingSlot.pip => PIPButton(
                    key: GlobalPlayerState.to.fullscreenUI
                        ? const ValueKey('fullscreen-pip-shortcut')
                        : const ValueKey('playback-action-pip'),
                    controller: controller,
                  ),
                },
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
        GlobalPlayerService.instance.player.enablePip();
      },
      icon: const Icon(CustomIcons.float_window),
    );
  }
}

class PortraitOrientationButton extends StatelessWidget {
  const PortraitOrientationButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.player;
      final selected = settings.portraitOverrideForRoom(controller.room);
      final icon = switch (selected) {
        PortraitOrientationOverride.automatic => Icons.screen_rotation_alt_rounded,
        PortraitOrientationOverride.portrait => Icons.stay_current_portrait_rounded,
        PortraitOrientationOverride.landscape => Icons.stay_current_landscape_rounded,
      };
      return IconButton(
        key: const ValueKey('portrait-orientation-override'),
        tooltip: i18n('portrait_room_override'),
        visualDensity: VisualDensity.compact,
        color: selected == PortraitOrientationOverride.automatic ? Colors.white : const Color(0xFFFFD166),
        onPressed: () => _showPicker(context, selected),
        icon: Icon(icon, size: 21),
      );
    });
  }

  Future<void> _showPicker(BuildContext context, PortraitOrientationOverride selected) async {
    controller.isMenuOpen.value = true;
    controller.stopHideController();
    try {
      final settings = SettingsService.to.player;
      final value = await showDialog<PortraitOrientationOverride>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(i18n('portrait_room_override')),
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in PortraitOrientationOverride.values)
                  ListTile(
                    key: ValueKey('portrait-room-override-${item.name}'),
                    dense: true,
                    leading: Icon(
                      item == selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: item == selected ? Theme.of(dialogContext).colorScheme.primary : null,
                    ),
                    title: Text(_overrideLabel(item)),
                    onTap: () => Navigator.of(dialogContext).pop(item),
                  ),
                const Divider(height: 1),
                Obx(
                  () => SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(i18n('portrait_remember_room_override')),
                    value: settings.rememberPortraitRoomOverride.v,
                    onChanged: (value) => settings.rememberPortraitRoomOverride.v = value,
                  ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(i18n('cancel')))],
        ),
      );
      if (value != null) {
        settings.setPortraitOverrideForRoom(controller.room, value, remember: settings.rememberPortraitRoomOverride.v);
        GlobalPlayerService.instance.player.refreshPortraitPresentationPolicy();
      }
    } finally {
      if (controller.status != PlayerStatus.disposed) {
        controller.isMenuOpen.value = false;
        controller.enableController();
      }
    }
  }
}

class PortraitStreamDiagnosticsBadge extends StatelessWidget {
  const PortraitStreamDiagnosticsBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.player;
      if (!settings.showPortraitDiagnostics.v) return const SizedBox.shrink();
      final manager = GlobalPlayerService.instance.player;
      final geometry = manager.videoGeometry.value;
      final roomOverride = settings.portraitOverrideForRoom(manager.currentFloatRoom);
      final orientation = manager.effectiveVideoOrientation;
      final pending = geometry.candidateOrientation != geometry.orientation;
      final ratio = geometry.hasValidDimensions ? geometry.aspectRatio.toStringAsFixed(3) : '--';
      final effectiveRatio = geometry.hasValidDimensions ? geometry.effectiveAspectRatio.toStringAsFixed(3) : '--';
      final evidence = geometry.evidence.name;
      final state = pending ? '${_orientationLabel(geometry.candidateOrientation)}…' : _orientationLabel(orientation);
      final observedAt = geometry.observedAt;
      final observedTime = observedAt == null
          ? '--:--:--'
          : '${observedAt.hour.toString().padLeft(2, '0')}:'
                '${observedAt.minute.toString().padLeft(2, '0')}:'
                '${observedAt.second.toString().padLeft(2, '0')}';
      return Positioned(
        key: const ValueKey('portrait-stream-diagnostics'),
        top: 62,
        left: 12,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Text(
                '${geometry.width > 0 ? geometry.width : '--'}×${geometry.height > 0 ? geometry.height : '--'}  '
                '$ratio→$effectiveRatio  $state  ${_overrideLabel(roomOverride)}\n'
                '$evidence  C${(geometry.confidence * 100).round()}%  S${geometry.stableSampleCount}  $observedTime',
                style: const TextStyle(color: Colors.white, fontSize: 11, decoration: TextDecoration.none),
              ),
            ),
          ),
        ),
      );
    });
  }
}

String _orientationLabel(VideoSourceOrientation value) => switch (value) {
  VideoSourceOrientation.portrait => i18n('portrait_orientation_portrait'),
  VideoSourceOrientation.landscape => i18n('portrait_orientation_landscape'),
  VideoSourceOrientation.square => i18n('portrait_orientation_square'),
  VideoSourceOrientation.unknown => i18n('portrait_orientation_unknown'),
};

String _overrideLabel(PortraitOrientationOverride value) => switch (value) {
  PortraitOrientationOverride.automatic => i18n('portrait_override_auto'),
  PortraitOrientationOverride.portrait => i18n('portrait_override_portrait'),
  PortraitOrientationOverride.landscape => i18n('portrait_override_landscape'),
};

// Center widgets
class DanmakuViewer extends StatelessWidget {
  const DanmakuViewer({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.danmaku;
      final playerSettings = SettingsService.to.player;
      final portraitSource = GlobalPlayerService.instance.player.isVerticalVideo.value;
      final portraitMode = portraitSource ? playerSettings.portraitDanmakuMode : PortraitDanmakuMode.followGlobal;
      final effectiveArea = switch (portraitMode) {
        PortraitDanmakuMode.upperQuarter => controller.danmakuArea.value.clamp(0.0, 0.25).toDouble(),
        PortraitDanmakuMode.reduced => controller.danmakuArea.value.clamp(0.0, 0.50).toDouble(),
        _ => controller.danmakuArea.value,
      };
      return FlameBarrageWidget(
        controller: controller.danmakuController,
        // Video gestures own the full surface and forward only hits on actual
        // barrage bounds, so volume/brightness/double-tap remain responsive.
        enablePointerEvents: false,
        config: BarrageConfig(
          emitInterval: 0.05,
          fontSize: controller.danmakuFontSize.value,
          topAreaDistance: controller.danmakuTopArea.value,
          area: effectiveArea,
          bottomAreaDistance: controller.danmakuBottomArea.value,
          baseSpeed: controller.danmakuSpeed.value,
          opacity: controller.danmakuOpacity.value,
          fontWeight: FontWeight(controller.danmakuFontWeight.value),
          strokeWidth: controller.danmakuFontBorder.value,
          showStroke: controller.enableDanmakuStroke.value,
          noEmojiMode: controller.noEmojiMode.value,
          fps: settings.danmakuAutoFps.v
              ? settings.resolvedDanmakuFps(refreshRateMode: SettingsService.to.app.refreshRateMode)
              : controller.danmakuFps.value.clamp(30, 240).toInt(),
          maxVisibleCount: 48,
          maxPendingCount: 120,
          maxPendingAge: const Duration(seconds: 5),
          fontFamily: controller.danmakuFontFamilyName.value,
          trackHeight: (controller.danmakuFontSize.value * 1.55).clamp(24.0, 64.0).toDouble(),
          emojiSize: (controller.danmakuFontSize.value * 1.3).clamp(16.0, 48.0).toDouble(),
          pictureCacheMaxSize: 96,
          barragePoolMaxSize: 72,
          textCacheMaxSize: 320,
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

/// Compact fullscreen entry for quality and CDN-line selection. Both controls
/// live in one landscape panel, avoiding two narrow menus competing for the
/// bottom-right safe area.
class FullscreenStreamSelectorButton extends StatelessWidget {
  const FullscreenStreamSelectorButton({super.key, required this.controller});

  final VideoController controller;

  Future<void> _showSelector(BuildContext context) async {
    final layout = resolveContentFirstPanelLayout(MediaQuery.sizeOf(context), ContentFirstPanelKind.streamSelector);
    controller.isMenuOpen.value = true;
    controller.stopHideController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Obx(() {
          final live = controller.livePlayController;
          final state = live.state.value.player;
          final switching = live.playerController.isStreamSwitching.value;
          final panelLayout = resolveStreamSelectorPanelLayout(
            maximumDialogSize: layout.size,
            qualityCount: state.qualites.length,
            lineCount: state.playUrls.length,
            splitContent: layout.splitContent,
          );
          final qualityPane = _StreamChoicePane(
            key: const ValueKey('stream-quality-pane'),
            icon: Icons.high_quality_rounded,
            title: i18n('select_quality'),
            itemCount: state.qualites.length,
            selectedIndex: state.currentQuality,
            labelBuilder: (index) => state.qualites[index].quality,
            onSelected: switching
                ? null
                : (index) async {
                    await live.setResolution(ReloadDataType.changeQuality, index, state.currentLineIndex);
                  },
          );
          final linePane = _StreamChoicePane(
            key: const ValueKey('stream-line-pane'),
            icon: Icons.alt_route_rounded,
            title: i18n('select_line'),
            itemCount: state.playUrls.length,
            selectedIndex: state.currentLineIndex,
            labelBuilder: (index) => i18n('toolbox_line', args: {'index': (index + 1).toString()}),
            onSelected: switching
                ? null
                : (index) async {
                    await live.setResolution(ReloadDataType.changeLine, state.currentQuality, index);
                  },
          );

          return Dialog(
            key: const ValueKey('fullscreen-stream-selector-panel'),
            alignment: Alignment.centerRight,
            insetPadding: layout.insetPadding,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: layout.size.width,
              height: panelLayout.dialogHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: 35,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 9, right: 1),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 17, color: Theme.of(dialogContext).colorScheme.primary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              i18n('fullscreen_stream_settings'),
                              style: Theme.of(dialogContext).textTheme.titleSmall,
                            ),
                          ),
                          IconButton(
                            tooltip: i18n('close'),
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: panelLayout.splitContent
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(height: panelLayout.qualityHeight, child: qualityPane),
                                    ),
                                    SizedBox(width: panelLayout.gap),
                                    Expanded(
                                      child: SizedBox(height: panelLayout.lineHeight, child: linePane),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    SizedBox(
                                      key: const ValueKey('stream-quality-content-sized-slot'),
                                      height: panelLayout.qualityHeight,
                                      child: qualityPane,
                                    ),
                                    SizedBox(height: panelLayout.gap),
                                    SizedBox(height: panelLayout.lineHeight, child: linePane),
                                  ],
                                ),
                        ),
                        if (switching)
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              key: ValueKey('fullscreen-stream-switch-progress'),
                              minHeight: 3,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    } finally {
      if (controller.status != PlayerStatus.disposed) {
        controller.isMenuOpen.value = false;
        controller.enableController();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final live = controller.livePlayController;
      final state = live.state.value.player;
      if (!live.state.value.room.success || state.qualites.isEmpty || state.playUrls.isEmpty) {
        return const SizedBox.shrink();
      }
      final switching = live.playerController.isStreamSwitching.value;
      final label =
          '${state.qualitySafe.quality} · ${i18n('toolbox_line', args: {'index': '${state.currentLineIndex + 1}'})}';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          key: const ValueKey('fullscreen-stream-selector'),
          color: Colors.white.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: switching ? null : () => unawaited(_showSelector(context)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  switching
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.tune_rounded, size: 17, color: Colors.white),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.t13.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _StreamChoicePane extends StatelessWidget {
  const _StreamChoicePane({
    super.key,
    required this.icon,
    required this.title,
    required this.itemCount,
    required this.selectedIndex,
    required this.labelBuilder,
    required this.onSelected,
  });

  final IconData icon;
  final String title;
  final int itemCount;
  final int selectedIndex;
  final String Function(int index) labelBuilder;
  final Future<void> Function(int index)? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
        child: Column(
          children: [
            SizedBox(
              height: 23,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: colors.primary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = resolveStreamChoiceColumns(constraints.maxWidth, itemCount: itemCount);
                  return GridView.builder(
                    primary: false,
                    padding: EdgeInsets.zero,
                    physics: const PureLiveScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 42,
                      mainAxisSpacing: 5,
                      crossAxisSpacing: 5,
                    ),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      final selected = selectedIndex == index;
                      return Material(
                        color: selected
                            ? colors.primaryContainer.withValues(alpha: .78)
                            : colors.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: selected
                                ? colors.primary.withValues(alpha: .62)
                                : colors.outlineVariant.withValues(alpha: .2),
                            width: selected ? 1.2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onSelected == null || selected ? null : () => unawaited(onSelected!(index)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 2),
                                  child: Text(
                                    labelBuilder(index),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
                                  ),
                                ),
                                if (selected)
                                  Positioned(
                                    right: 1,
                                    child: Icon(Icons.check_circle_rounded, size: 16, color: colors.primary),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
              final fullscreen = GlobalPlayerState.to.fullscreenUI;
              final compact = constraints.maxWidth < 760;
              final left = _buildLeftActions(compact: fullscreen && compact);
              final right = _buildRightActions(compact: fullscreen && compact);

              if (fullscreen) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      left,
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: FullscreenLocalDanmakuComposer(controller: controller),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      right,
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const PureLiveScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [left, right]),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Widget _buildLeftActions({required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayPauseButton(controller: controller),
        if (!compact) RefreshButton(controller: controller),
        if (!compact) FavoriteButton(controller: controller),
        if (SettingsService.to.danmaku.enableDanmakuDisplay.v) ...[
          DanmakuButton(controller: controller),
          SettingsButton(controller: controller),
        ],
      ],
    );
  }

  Widget _buildRightActions({required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (GlobalPlayerState.to.isWindowFullscreen.value || GlobalPlayerState.to.isFullscreen.value) ...[
          FullscreenStreamSelectorButton(controller: controller),
        ],
        if (PlatformUtils.isMobile) PortraitOrientationButton(controller: controller),
        if (!compact) VideoFitSetting(controller: controller),
        if (Platform.isWindows) OverlayVolumeControl(controller: controller),
        if (Platform.isWindows && controller.supportWindowFull && !GlobalPlayerState.to.isFullscreen.value)
          ExpandWindowButton(controller: controller),
        if (!GlobalPlayerState.to.isWindowFullscreen.value) ExpandButton(controller: controller),
      ],
    );
  }
}

/// Room-local composer placed between the two fullscreen control groups.
/// Pure Live does not impersonate a platform account here: the submitted line
/// enters the local list and video barrage through the same ordered delivery
/// queue used by portrait mode.
class FullscreenLocalDanmakuComposer extends StatefulWidget {
  const FullscreenLocalDanmakuComposer({super.key, required this.controller});

  final VideoController controller;

  @override
  State<FullscreenLocalDanmakuComposer> createState() => _FullscreenLocalDanmakuComposerState();
}

class _FullscreenLocalDanmakuComposerState extends State<FullscreenLocalDanmakuComposer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  VideoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        controller.stopHideController();
      } else {
        controller.enableController();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textController.text.trim();
    final live = controller.livePlayController;
    final local = live.localInteractionController;
    if (!local.enabled.v || text.isEmpty) return;
    live.emitLocalMessage(
      local.createChat(text, platform: live.site),
      showAsDanmaku: local.showAsDanmaku.v,
      delay: LivePlayController.localChatDeliveryDelay,
    );
    _textController.clear();
    ToastUtil.show(i18n('local_message_queued'));
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final local = controller.livePlayController.localInteractionController;
      if (!local.enabled.v) {
        return Center(
          child: FilledButton.tonalIcon(
            key: const ValueKey('fullscreen-local-danmaku-enable'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.black45,
              foregroundColor: Colors.white,
            ),
            onPressed: () => local.enabled.v = true,
            icon: const Icon(Icons.auto_awesome_rounded, size: 17),
            label: Text(i18n('local_interaction_enable'), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        );
      }

      final localStyle = local.currentDanmakuStyle;
      return SizedBox(
        key: const ValueKey('fullscreen-local-danmaku-composer'),
        height: 38,
        child: TextField(
          controller: _textController,
          focusNode: _focusNode,
          style: TextStyle(
            color: Color(local.danmakuColor.v).withValues(alpha: localStyle.opacity),
            fontSize: 13,
            fontWeight: FontWeight(localStyle.fontWeight),
            fontFamily: localStyle.fontFamily,
            fontStyle: localStyle.italic ? FontStyle.italic : FontStyle.normal,
            letterSpacing: localStyle.letterSpacing,
            shadows: localStyle.showShadow
                ? [
                    Shadow(
                      color: Color(localStyle.shadowColor).withValues(alpha: localStyle.opacity),
                      blurRadius: localStyle.shadowBlur,
                      offset: Offset(localStyle.shadowOffset, localStyle.shadowOffset),
                    ),
                  ]
                : null,
          ),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.black54,
            hintText: i18n('local_message_hint'),
            hintStyle: const TextStyle(color: Colors.white60, fontSize: 13),
            prefixIcon: IconButton(
              key: const ValueKey('fullscreen-local-danmaku-style'),
              tooltip: i18n('local_danmaku_style'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              onPressed: () async {
                controller.isMenuOpen.value = true;
                controller.stopHideController();
                try {
                  await showLocalDanmakuStyleEditor(
                    context,
                    controller: controller.livePlayController.localInteractionController,
                  );
                } finally {
                  if (controller.status != PlayerStatus.disposed) {
                    controller.isMenuOpen.value = false;
                    controller.enableController();
                  }
                }
              },
              icon: Icon(Icons.auto_awesome_rounded, color: Color(local.danmakuColor.v), size: 18),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            suffixIcon: IconButton(
              key: const ValueKey('fullscreen-local-danmaku-send'),
              tooltip: i18n('local_send_message'),
              visualDensity: VisualDensity.compact,
              onPressed: _send,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.3),
            ),
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
    final playerManager = GlobalPlayerService.instance.player;

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

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final room = controller.room;
      final favoriteRooms = SettingsService.to.fav.favoriteRooms.value;
      final isFavorite = favoriteRooms.any((candidate) => candidate.hasSameIdentity(room));
      return GestureDetector(
        onTap: () {
          controller.enableController();
          final changed = isFavorite ? SettingsService.to.fav.removeRoom(room) : SettingsService.to.fav.addRoom(room);
          if (changed) EventBus.instance.emit('changeFavorite', true);
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
              Text(isFavorite ? i18n('followed') : i18n('follow'), style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    });
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final compactLandscape = isLandscape && size.height < 620;
    final targetWidth = isLandscape
        ? (size.width * (compactLandscape ? 0.44 : 0.38)).clamp(340.0, compactLandscape ? 460.0 : 540.0).toDouble()
        : (size.width * 0.92).clamp(300.0, 560.0).toDouble();
    final targetHeight = isLandscape ? size.height - (compactLandscape ? 12 : 24) : size.height * 0.84;
    final panelColor = colorScheme.surface;

    return Dialog(
      alignment: isLandscape ? Alignment.centerRight : Alignment.center,
      backgroundColor: Colors.transparent,
      shadowColor: theme.shadowColor.withValues(alpha: 0.45),
      elevation: 24,
      insetPadding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 12, vertical: isLandscape ? 6 : 12),
      child: Container(
        key: const ValueKey('fullscreen-danmaku-settings-panel'),
        width: targetWidth,
        height: targetHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: isLandscape
              ? const BorderRadius.horizontal(left: Radius.circular(18), right: Radius.circular(8))
              : BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.7), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, compactLandscape ? 6 : 10, 6, compactLandscape ? 6 : 10),
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 18,
                    decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n('settings_danmaku_title'),
                          style: AppTextStyles.t16Bold.copyWith(color: colorScheme.onSurface),
                        ),
                        Text(
                          i18n('danmaku_realtime_hint'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.t12.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('fullscreen-danmaku-settings-close'),
                    tooltip: i18n('close'),
                    color: colorScheme.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.7), height: 1, thickness: 0.8),
            Expanded(
              // PiP has a dedicated settings/preview page. Keeping those
              // controls out of the short landscape sheet leaves the live
              // picture visible and avoids a confusing nested long form.
              child: DanmakuSettingsContent(controller: controller, embedded: true, includePipSettings: false),
            ),
          ],
        ),
      ),
    );
  }
}
