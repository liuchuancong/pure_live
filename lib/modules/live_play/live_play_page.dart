import 'dart:io';
import 'dart:async';
import 'widgets/index.dart';
import 'package:get/get.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pure_live/modules/live_play/load_type.dart';
import 'package:pure_live/common/index.dart' hide BackButton;
import 'package:pure_live/modules/live_play/play_other.dart';
import 'package:pure_live/modules/live_play/danmaku_tab.dart';
import 'package:pure_live/player/switchable_global_player.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';

class LivePlayPage extends GetView<LivePlayController> {
  LivePlayPage({super.key});

  final SettingsService settings = Get.find<SettingsService>();

  @override
  Widget build(BuildContext context) {
    if (settings.enableScreenKeepOn.value) {
      WakelockPlus.toggle(enable: settings.enableScreenKeepOn.value);
    }
    return Obx(() {
      if (SwitchableGlobalPlayer().isInPip.value) {
        return SwitchableGlobalPlayer().buildPiPOverlay();
      }
      if (controller.screenMode.value == VideoMode.normal) {
        return buildNormalPlayerView(context);
      } else if (controller.screenMode.value == VideoMode.widescreen) {
        return buildVideoPlayer();
      }
      return buildVideoPlayer();
    });
  }

  Widget buildNormalPlayerView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Obx(
              () => CircleAvatar(
                foregroundImage: controller.detail.value!.avatar == null
                    ? null
                    : NetworkImage(controller.detail.value!.avatar!),
                radius: 13,
                backgroundColor: Theme.of(context).disabledColor,
              ),
            ),
            const SizedBox(width: 8),
            Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 120),
                    child: Text(
                      controller.detail.value == null && controller.detail.value!.nick == null
                          ? ''
                          : controller.detail.value!.nick!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Text(
                    controller.detail.value!.area!.isEmpty
                        ? controller.detail.value!.platform!.toUpperCase()
                        : "${controller.detail.value!.platform!.toUpperCase()} / ${controller.detail.value!.area}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 8),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Obx(() => FavoriteFloatingButton(room: controller.detail.value!)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_outlined),
            tooltip: '切换直播间',
            onPressed: () {
              Get.dialog(PlayOther(controller: controller));
            },
          ),
          PopupMenuButton(
            tooltip: '搜索',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            offset: const Offset(12, 0),
            position: PopupMenuPosition.under,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (int index) {
              if (index == 0) {
                controller.openNaviteAPP();
              } else if (index == 1) {
                showDlnaCastDialog();
              } else if (index == 2) {
                showTimerDialog(context);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 0,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: MenuListTile(leading: Icon(Icons.open_in_new_rounded), text: "打开直播间"),
                ),
                const PopupMenuItem(
                  value: 1,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: MenuListTile(leading: Icon(Icons.live_tv_rounded), text: "投屏"),
                ),
                const PopupMenuItem(
                  value: 2,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: MenuListTile(leading: Icon(Icons.watch_later_outlined), text: "定时关闭"),
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
                          Obx(() {
                            if (controller.success.value == false) {
                              return SizedBox.shrink();
                            }
                            return Expanded(child: DanmakuTabView());
                          }),
                        ],
                      )
                    : Row(
                        children: <Widget>[
                          Expanded(child: buildVideoPlayer()),
                          SizedBox(
                            width: 400,
                            child: Column(
                              children: [
                                const ResolutionsRow(),
                                const Divider(height: 1),
                                Obx(() {
                                  if (controller.success.value == false) {
                                    return SizedBox.shrink();
                                  }
                                  return Expanded(child: DanmakuTabView());
                                }),
                              ],
                            ),
                          ),
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
    Get.dialog(LiveDlnaPage(datasource: controller.playUrls[controller.currentLineIndex.value]));
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
    return Material(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Container(
            color: Colors.black, // 设置你想要的背景色
          ),
          Container(
            color: Colors.black,
            child: const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // title: Text(S.of(context).auto_refresh_time),
        content: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text('定时关闭'),
                contentPadding: EdgeInsets.zero,
                value: controller.closeTimeFlag.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.closeTimeFlag.value = value,
              ),
              Slider(
                min: 0,
                max: 240,
                label: S.of(context).auto_refresh_time,
                value: controller.closeTimes.toDouble(),
                onChanged: (value) => controller.closeTimes.value = value.toInt(),
              ),
              Text(
                '自动关闭时间:'
                ' ${controller.closeTimes}分钟',
              ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.whatshot_rounded, size: 14),
        const SizedBox(width: 4),
        Text(
          controller.detail.value?.watching != null
              ? readableCount(controller.detail.value!.watching!) // 假设 readableCount 已定义
              : '0',
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
        tooltip: "选择清晰度",
        color: Get.theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        offset: const Offset(0.0, 5.0),
        position: PopupMenuPosition.under,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            currentQualityName,
            style: Get.theme.textTheme.labelSmall?.copyWith(
              color: Get.theme.colorScheme.primary, // 高亮当前选项
            ),
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

  // 构建播放线路选择器
  Widget _buildLineSelector() {
    return Obx(() {
      if (!controller.success.value || controller.playUrls.isEmpty) {
        return const SizedBox.shrink();
      }
      final currentIndex = controller.currentLineIndex.value;
      final currentLineName = '线路${currentIndex + 1}';

      return PopupMenuButton<int>(
        tooltip: "选择播放线路/节点",
        color: Get.theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        offset: const Offset(0.0, 5.0),
        position: PopupMenuPosition.under,
        // 按钮显示当前选中的线路名称
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
                '线路${index + 1}',
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
            _buildResolutionSelector(), // 添加清晰度选择器
            _buildLineSelector(), // 添加线路选择器
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
    final settings = Get.find<SettingsService>();
    bool isFavorite = settings.isFavorite(widget.room);
    return isFavorite
        ? FilledButton(
            style: ButtonStyle(
              padding: Platform.isWindows
                  ? WidgetStateProperty.all(EdgeInsets.all(12.0))
                  : WidgetStateProperty.all(EdgeInsets.all(5.0)),
              backgroundColor: WidgetStateProperty.all(Get.theme.colorScheme.primary.withAlpha(125)),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.0), // 圆角半径，可根据需要调整
                ),
              ),
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12.0)),
              minimumSize: WidgetStateProperty.all(Size.zero),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: Text(S.of(context).unfollow),
                  content: Text(S.of(context).unfollow_message(widget.room.nick!)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(Get.context!).pop(false);
                      },
                      child: Text(S.of(context).cancel),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(Get.context!).pop(true);
                      },
                      child: Text(S.of(context).confirm),
                    ),
                  ],
                ),
              ).then((value) {
                if (value) {
                  setState(() => isFavorite = !isFavorite);
                  settings.removeRoom(widget.room);
                  EventBus.instance.emit('changeFavorite', true);
                }
              });
            },
            child: Text('已关注'),
          )
        : FilledButton(
            style: ButtonStyle(
              // 减小内边距，使按钮更小
              padding: Platform.isWindows
                  ? WidgetStateProperty.all(EdgeInsets.all(12.0))
                  : WidgetStateProperty.all(EdgeInsets.all(5.0)),
              // 设置背景色
              backgroundColor: WidgetStateProperty.all(Get.theme.colorScheme.primary),
              // 设置按钮形状，调整圆角半径
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.0), // 圆角半径，可根据需要调整
                ),
              ),
              // 可选：减小文字大小
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12.0)),
              minimumSize: WidgetStateProperty.all(Size.zero), // 移除默认最小尺寸
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              setState(() => isFavorite = !isFavorite);
              settings.addRoom(widget.room);
              EventBus.instance.emit('changeFavorite', true);
            },
            child: const Text('关注'),
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
                if (controller.playerState.isFullscreen || controller.playerState.isWindowFullscreen)
                  GestureDetector(
                    onTap: () {
                      controller.setNormalScreen();
                      controller.playerState.isFullscreen = false;
                      controller.playerState.isWindowFullscreen = false;
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
                      style: const TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none),
                    ),
                  ),
                ),
                if (controller.playerState.isFullscreen || controller.playerState.isWindowFullscreen) ...[
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_outlined),
                    tooltip: '切换直播间',
                    color: Colors.white,
                    onPressed: () {
                      Get.dialog(PlayOther(controller: Get.find<LivePlayController>()));
                    },
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
                    child: Text(
                      S.of(context).play_video_failed,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const Text("该房间未开播或已下播", style: TextStyle(color: Colors.white, fontSize: 14)),
                  const Text("请切换其他直播间进行观看吧", style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
