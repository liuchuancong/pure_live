import 'dart:io';
import 'dart:async';
import 'widgets/index.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/modules/live_play/load_type.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/index.dart' hide BackButton;
import 'package:pure_live/modules/live_play/play_other.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/modules/live_play/danmaku_tab.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/utils/share_command_handler.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_keyboard.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';

class LivePlayPage extends GetView<LivePlayController> {
  const LivePlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _updateWakelock();
      final manager = GlobalPlayerService.instance.playerManager;
      final isInPip = manager.isInPip.value;
      final mode = controller.screenMode.value;
      if (controller.videoController.value != null) {
        return VideoKeyboardShortcuts(
          controller: controller.videoController.value!,
          child: Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 50),
              child: _buildConstrainedChild(isInPip, mode, context),
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: <Widget>[...previousChildren, ?currentChild],
                );
              },
            ),
          ),
        );
      }
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          child: _buildConstrainedChild(isInPip, mode, context),
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: <Widget>[...previousChildren, ?currentChild],
            );
          },
        ),
      );
    });
  }

  Widget _buildConstrainedChild(bool isInPip, VideoMode mode, BuildContext context) {
    final manager = GlobalPlayerService.instance.playerManager;
    if (isInPip) {
      return Theme(
        data: ThemeData.dark(),
        child: Container(key: const ValueKey('pip'), color: Colors.transparent, child: manager.buildPiPOverlay()),
      );
    }

    if (mode == VideoMode.normal) {
      return Container(key: const ValueKey('normal'), color: Colors.black, child: buildNormalPlayerView(context));
    }

    return Container(key: const ValueKey('widescreen'), color: Colors.black, child: buildVideoPlayer());
  }

  void _updateWakelock() {
    final shouldKeepOn = SettingsService.to.app.enableScreenKeepOn.v;
    WakelockPlus.enabled.then((isEnabled) {
      if (isEnabled != shouldKeepOn) {
        WakelockPlus.toggle(enable: shouldKeepOn);
      }
    });
  }

  Widget buildNormalPlayerView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Obx(
              () => CircleAvatar(
                foregroundImage: controller.detail.value!.avatar == null || controller.detail.value!.avatar!.isEmpty
                    ? null
                    : CachedNetworkImageProvider(controller.detail.value!.avatar!),
                radius: 16,
                backgroundColor: Theme.of(context).disabledColor,
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final detail = controller.detail.value;
              if (detail == null) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 60),
                    child: Text(
                      detail.nick ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Text(
                    (detail.area == null || detail.area!.isEmpty)
                        ? (detail.platform?.toUpperCase() ?? '')
                        : "${detail.platform?.toUpperCase()} / ${detail.area}",
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              );
            }),
            const SizedBox(width: 8),
            Obx(() => FavoriteFloatingButton(room: controller.detail.value!)),
          ],
        ),
        actions: [
          Obx(() {
            final room = controller.detail.value;
            if (room == null) return const SizedBox.shrink();
            final task = controller.recorderController.tasks.firstWhereOrNull(
              (t) => t.platform == room.platform && t.roomId == room.roomId,
            );
            final bool exists = task != null;
            final bool isRunning =
                task?.status == RecordStatus.running ||
                task?.status == RecordStatus.reconnecting ||
                task?.status == RecordStatus.preparing;
            final theme = Theme.of(Get.context!);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 38,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isRunning
                      ? Colors.redAccent.withValues(alpha: 0.12)
                      : exists
                      ? theme.colorScheme.primary.withValues(alpha: 0.10)
                      : theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: isRunning
                      ? Colors.redAccent
                      : exists
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRunning
                          ? Remix.record_circle_fill
                          : exists
                          ? Remix.checkbox_circle_fill
                          : Remix.add_circle_line,
                      size: 14,
                    ),
                    const SizedBox(width: 4), // 🌟 Tightened inner gap from 8px down to 4px
                    Text(
                      isRunning
                          ? i18n("recording")
                          : exists
                          ? i18n("monitored")
                          : i18n("record"),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
                onPressed: () async {
                  if (!exists) {
                    await controller.recorderController.addTask(room: room);
                    ToastUtil.show(i18n("record_task_added"));
                    return;
                  }
                  final action = await showDialog<String>(
                    context: Get.context!,
                    builder: (context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        title: Row(
                          children: [
                            Icon(
                              isRunning ? Remix.record_circle_fill : Remix.checkbox_circle_fill,
                              color: isRunning ? Colors.redAccent : theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(isRunning ? i18n("recording") : i18n("record_task")),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionTile(
                              icon: Icons.video_library_rounded,
                              title: i18n("go_record_center"),
                              color: theme.colorScheme.primary,
                              onTap: () => Navigator.pop(context, "page"),
                            ),
                            if (!isRunning)
                              _ActionTile(
                                icon: Icons.play_arrow_rounded,
                                title: i18n("start_record_now"),
                                color: Colors.green,
                                onTap: () => Navigator.pop(context, "start"),
                              ),
                            if (isRunning)
                              _ActionTile(
                                icon: Icons.stop_circle_outlined,
                                title: i18n("stop_record"),
                                color: Colors.orange,
                                onTap: () => Navigator.pop(context, "stop"),
                              ),
                            _ActionTile(
                              icon: Icons.delete_outline_rounded,
                              title: i18n("remove_monitor"),
                              color: Colors.redAccent,
                              onTap: () => Navigator.pop(context, "delete"),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  switch (action) {
                    case "page":
                      Get.toNamed(RoutePath.kRecordPage);
                      break;
                    case "start":
                      controller.recorderController.forceStartTask(task);
                      break;
                    case "stop":
                      controller.recorderController.stopTask(task);
                      break;
                    case "delete":
                      controller.recorderController.unRecorder(task);
                      break;
                  }
                },
              ),
            );
          }),
          PopupMenuButton(
            tooltip: i18n("menu"),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            offset: const Offset(12, 0),
            position: PopupMenuPosition.under,
            icon: const Icon(Remix.apps_2_line),
            onOpened: () {
              controller.isMenuOpen = true;
            },
            onCanceled: () {
              controller.isMenuOpen = false;
            },
            onSelected: (int index) {
              if (index == 0) {
                controller.openNaviteAPP();
              } else if (index == 1) {
                Get.dialog(PlayOther(controller: controller));
              } else if (index == 2) {
                showDlnaCastDialog();
              } else if (index == 3) {
                showTimerDialog(context);
              } else if (index == 4) {
                showVolumeSettingsDialog(context);
              } else if (index == 5) {
                if (controller.detail.value != null) {
                  LiveUrlTool.getPlayUrlByRoomId(
                    roomId: controller.detail.value?.roomId ?? '',
                    platform: controller.detail.value?.platform ?? '',
                  );
                }
              } else if (index == 6) {
                ShareCommandHandler.instance.onShareRoomPressed(controller.detail.value!);
              }
              controller.isMenuOpen = false;
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MenuListTile(
                    leading: const Icon(Icons.open_in_new_rounded, size: 16),
                    text: i18n("open_live_room"),
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MenuListTile(
                    leading: Icon(Icons.swap_horiz_outlined, size: 20),
                    text: i18n("switch_live_room"),
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MenuListTile(leading: const Icon(Remix.tv_2_line, size: 20), text: i18n("cast_screen")),
                ),
                PopupMenuItem(
                  value: 3,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MenuListTile(leading: const Icon(Remix.time_line, size: 20), text: i18n("sleep_timer")),
                ),
                PopupMenuItem(
                  value: 4,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MenuListTile(leading: const Icon(Remix.volume_up_line, size: 20), text: i18n("room_volume")),
                ),
                PopupMenuItem(
                  value: 5,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MenuListTile(
                    leading: const Icon(Remix.link_m, size: 20),
                    text: i18n("toolbox_get_direct_link"),
                  ),
                ),
                PopupMenuItem(
                  value: 6, // Make sure to increment the value to avoid duplicate key conflicts
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MenuListTile(
                    leading: const Icon(RemixIcons.share_forward_line, size: 20),
                    text: i18n("share"), // Make sure to add "share" to your i18n file
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Builder(
        builder: (BuildContext context) {
          return LayoutBuilder(
            builder: (context, constraint) {
              final width = Get.width;
              return SafeArea(
                child: width <= 680
                    ? Column(
                        children: <Widget>[
                          buildVideoPlayer(),
                          const ResolutionsRow(),
                          const Divider(height: 1),
                          // ====================== IPTV 优化 ======================
                          Obx(() {
                            if (controller.success.isFalse || controller.site == Sites.iptvSite) {
                              return const SizedBox.shrink();
                            }
                            final state = GlobalPlayerState.to;
                            if (state.isFullscreen.value || state.isWindowFullscreen.value) {
                              return const SizedBox.shrink();
                            }
                            return Expanded(child: DanmakuTabView(key: ValueKey(state.isFullscreen.value)));
                          }),
                        ],
                      )
                    : Row(
                        children: <Widget>[
                          Expanded(child: buildVideoPlayer()),
                          Obx(() {
                            bool isRoomExits = controller.detail.value != null;
                            return isRoomExits
                                ? SizedBox(
                                    width: controller.detail.value!.platform == Sites.iptvSite ? 0 : 400,
                                    child: Column(
                                      children: [
                                        const ResolutionsRow(),
                                        const Divider(height: 1),
                                        Obx(() {
                                          if (controller.success.isFalse ||
                                              controller.detail.value!.platform == Sites.iptvSite) {
                                            return const SizedBox.shrink();
                                          }
                                          final state = GlobalPlayerState.to;
                                          if (state.isFullscreen.value || state.isWindowFullscreen.value) {
                                            return const SizedBox.shrink();
                                          }
                                          return Expanded(
                                            child: DanmakuTabView(key: ValueKey(state.isFullscreen.value)),
                                          );
                                        }),
                                      ],
                                    ),
                                  )
                                : Container();
                          }),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }

  void showDlnaCastDialog() {
    LiveUrlTool.castPlayUrlByRoomId(
      roomId: controller.detail.value?.roomId ?? '',
      platform: controller.detail.value?.platform ?? '',
    );
  }

  Widget buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: Obx(
          () => controller.success.value
              ? VideoPlayer(controller: controller.videoController.value!)
              : controller.isLiving.value
              ? buildLoading()
              : NotLivingVideoWidget(controller: controller, key: UniqueKey()),
        ),
      ),
    );
  }

  Widget buildLoading() {
    return const Material(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ColoredBox(color: Colors.black),
          AppStatusView(type: AppStatusType.loading, title: "", subtitle: "", iconColor: Colors.white),
        ],
      ),
    );
  }

  void showVolumeSettingsDialog(BuildContext context) {
    final RxBool tempMute = SettingsService.to.vol.globalVolumeMute.v.obs;
    final RxDouble tempMobileVol = SettingsService.to.vol.defaultMobileVolume.v.obs;
    final RxDouble tempDesktopVol = SettingsService.to.vol.defaultDesktopVolume.v.obs;

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(i18n("room_volume")),
          content: Container(
            constraints: BoxConstraints(minWidth: PlatformUtils.isMobile ? Get.mediaQuery.size.width * 0.8 : 500),
            child: Obx(
              () => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: Text(i18n("global_mute")),
                      secondary: Icon(
                        tempMute.value ? Icons.volume_off : Icons.volume_up,
                        color: tempMute.value ? theme.colorScheme.error : theme.colorScheme.primary,
                      ),
                      value: tempMute.value,
                      activeThumbColor: theme.colorScheme.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => tempMute.value = val,
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.phone_android, size: 20),
                            const SizedBox(width: 8),
                            Text(i18n("mobile_default_volume")),
                          ],
                        ),
                        Text(
                          "${(tempMobileVol.value * 100).toInt()}%",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: tempMute.value ? theme.disabledColor : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: tempMobileVol.value.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: tempMute.value ? null : (val) => tempMobileVol.value = val,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.computer, size: 20),
                            const SizedBox(width: 8),
                            Text(i18n("desktop_default_volume")),
                          ],
                        ),
                        Text(
                          "${(tempDesktopVol.value * 100).toInt()}%",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: tempMute.value ? theme.disabledColor : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: tempDesktopVol.value.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: tempMute.value ? null : (val) => tempDesktopVol.value = val,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          tempMute.value = false;
                          tempMobileVol.value = 0.5;
                          tempDesktopVol.value = 1.0;
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(i18n("reset_default")),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n("cancel"))),
            FilledButton(
              onPressed: () {
                SettingsService.to.vol.globalVolumeMute.v = tempMute.value;
                SettingsService.to.vol.defaultMobileVolume.v = tempMobileVol.value.clamp(0.0, 1.0);
                SettingsService.to.vol.defaultDesktopVolume.v = tempDesktopVol.value.clamp(0.0, 1.0);
                if (tempMute.value) {
                  controller.videoController.value?.setVolume(0.0);
                } else {
                  if (PlatformUtils.isMobile) {
                    controller.videoController.value?.setVolume(tempMobileVol.value);
                  } else {
                    controller.videoController.value?.setVolume(tempDesktopVol.value);
                  }
                }
                Navigator.pop(context);
              },
              child: Text(i18n("confirm")),
            ),
          ],
        );
      },
    );
  }

  void showTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(i18n("sleep_timer")),
                contentPadding: EdgeInsets.zero,
                value: controller.closeTimeFlag.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.closeTimeFlag.value = value,
              ),
              Slider(
                min: 0,
                max: 240,
                label: i18n("auto_refresh_time"),
                value: controller.closeTimes.toDouble(),
                onChanged: (value) => controller.closeTimes.value = value.toInt(),
              ),
              Text(i18n("auto_close_time", args: {"time": controller.closeTimes.toString()})),
            ],
          ),
        ),
      ),
    );
  }
}

class ResolutionsRow extends StatefulWidget {
  const ResolutionsRow({super.key});

  @override
  State<ResolutionsRow> createState() => _ResolutionsRowState();
}

class _ResolutionsRowState extends State<ResolutionsRow> {
  LivePlayController get controller => Get.find<LivePlayController>();

  Widget buildInfoCount() {
    // ====================== IPTV 不显示观看人数 ======================
    if (controller.site == Sites.iptvSite) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.whatshot_rounded, size: 14),
        const SizedBox(width: 4),
        Text(
          controller.detail.value?.watching != null ? readableCount(controller.detail.value!.watching!) : '0',
          style: Get.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildResolutionSelector() {
    return Obx(() {
      if (!controller.success.value || controller.qualites.isEmpty) {
        return const SizedBox.shrink();
      }
      final currentIndex = controller.currentQuality.value;
      final currentQualityName = controller.qualites[currentIndex].quality;

      return PopupMenuButton<int>(
        tooltip: i18n('toolbox_select_quality'),
        color: Get.theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        offset: const Offset(0.0, 5.0),
        position: PopupMenuPosition.under,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            currentQualityName,
            style: Get.theme.textTheme.labelSmall?.copyWith(color: Get.theme.colorScheme.primary),
          ),
        ),
        onSelected: (newQualityIndex) {
          controller.setResolution(ReloadDataType.changeQuality, newQualityIndex, controller.currentLineIndex.value);
        },
        itemBuilder: (context) {
          return List.generate(controller.qualites.length, (index) {
            final qualityRate = controller.qualites[index];
            final isSelected = index == currentIndex;
            return PopupMenuItem<int>(
              value: index,
              child: Text(
                qualityRate.quality,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: isSelected ? Get.theme.colorScheme.primary : null),
              ),
            );
          });
        },
      );
    });
  }

  Widget _buildLineSelector() {
    return Obx(() {
      if (!controller.success.value || controller.playUrls.isEmpty) {
        return const SizedBox.shrink();
      }
      final currentIndex = controller.currentLineIndex.value;
      final currentLineName = i18n("toolbox_line", args: {"index": (currentIndex + 1).toString()});

      return PopupMenuButton<int>(
        tooltip: i18n("select_play_line"),
        color: Get.theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        offset: const Offset(0.0, 5.0),
        position: PopupMenuPosition.under,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            currentLineName,
            style: Get.theme.textTheme.labelSmall?.copyWith(color: Get.theme.colorScheme.primary),
          ),
        ),
        onSelected: (newLineIndex) {
          controller.setResolution(ReloadDataType.changeLine, controller.currentQuality.value, newLineIndex);
        },
        itemBuilder: (context) {
          return List.generate(controller.playUrls.length, (index) {
            final isSelected = index == currentIndex;
            return PopupMenuItem<int>(
              value: index,
              child: Text(
                i18n("toolbox_line", args: {"index": (index + 1).toString()}),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: isSelected ? Get.theme.colorScheme.primary : null),
              ),
            );
          });
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.success.value) {
        return Container(height: 55);
      }
      return Container(
        height: 55,
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            Padding(padding: const EdgeInsets.all(8), child: buildInfoCount()),
            const Spacer(),
            _buildResolutionSelector(),
            _buildLineSelector(),
          ],
        ),
      );
    });
  }
}

class FavoriteFloatingButton extends StatefulWidget {
  const FavoriteFloatingButton({super.key, required this.room});

  final LiveRoom room;

  @override
  State<FavoriteFloatingButton> createState() => _FavoriteFloatingButtonState();
}

class _FavoriteFloatingButtonState extends State<FavoriteFloatingButton> {
  StreamSubscription<dynamic>? subscription;

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
    bool isFavorite = SettingsService.to.fav.isFavorite(widget.room);
    return isFavorite
        ? FilledButton(
            style: ButtonStyle(
              padding: Platform.isWindows
                  ? WidgetStateProperty.all(EdgeInsets.all(12.0))
                  : WidgetStateProperty.all(EdgeInsets.all(5.0)),
              backgroundColor: WidgetStateProperty.all(Get.theme.colorScheme.primary.withAlpha(125)),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0))),
              textStyle: WidgetStateProperty.all(AppTextStyles.t12),
              minimumSize: WidgetStateProperty.all(Size.zero),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: Text(i18n("unfollow")),
                  content: Text(i18n("unfollow_message", args: {"name": widget.room.nick!})),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(Get.context!).pop(false), child: Text(i18n("cancel"))),
                    ElevatedButton(onPressed: () => Navigator.of(Get.context!).pop(true), child: Text(i18n("confirm"))),
                  ],
                ),
              ).then((value) {
                if (value ?? false) {
                  setState(() => isFavorite = !isFavorite);
                  SettingsService.to.fav.removeRoom(widget.room);
                  EventBus.instance.emit('changeFavorite', true);
                }
              });
            },
            child: Text(i18n("followed")),
          )
        : FilledButton(
            style: ButtonStyle(
              padding: Platform.isWindows
                  ? WidgetStateProperty.all(EdgeInsets.all(12.0))
                  : WidgetStateProperty.all(EdgeInsets.all(5.0)),
              backgroundColor: WidgetStateProperty.all(Get.theme.colorScheme.primary),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0))),
              textStyle: WidgetStateProperty.all(AppTextStyles.t12),
              minimumSize: WidgetStateProperty.all(Size.zero),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              setState(() => isFavorite = !isFavorite);
              SettingsService.to.fav.addRoom(widget.room);
              EventBus.instance.emit('changeFavorite', true);
            },
            child: Text(i18n("follow")),
          );
  }
}

class NotLivingVideoWidget extends StatelessWidget {
  const NotLivingVideoWidget({super.key, required this.controller});

  final LivePlayController controller;
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 55,
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
                if (GlobalPlayerState.to.fullscreenUI)
                  GestureDetector(
                    onTap: () {
                      controller.setNormalScreen();
                      GlobalPlayerState.to.isFullscreen.value = false;
                      GlobalPlayerState.to.isWindowFullscreen.value = false;
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(12),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      controller.room.title!,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.t14.copyWith(color: Colors.white, decoration: TextDecoration.none),
                    ),
                  ),
                ),
                if (GlobalPlayerState.to.fullscreenUI) ...[
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_outlined),
                    tooltip: i18n('switch_live_room'),
                    color: Colors.white,
                    onPressed: () => Get.dialog(PlayOther(controller: Get.find<LivePlayController>())),
                  ),
                  const DatetimeInfo(),
                ],
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(i18n("play_video_failed"), style: AppTextStyles.t16.copyWith(color: Colors.white)),
                  ),
                  Text(i18n("room_offline"), style: const TextStyle(color: Colors.white)),
                  Text(i18n("switch_other_room_hint"), style: AppTextStyles.t14.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: color),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
