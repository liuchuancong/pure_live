import 'dart:async';
import 'dart:io';

import 'package:media_core_ui/media_core_ui.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:pure_live/core/player/kernel/player_kernel_service.dart';
import 'package:pure_live/domains/recorder/presentation/pages/local_player/local_video_player_controller.dart';

/// One recording, played.
///
/// The layout is built around what a viewer of a recording actually does:
/// scrub, jump a few seconds, change speed, start the next file, or leave the
/// page and keep watching in the small window. The transport controls are the
/// page's own — the video surface is plain picture — so the same bar serves the
/// phone layout and the desktop one, and the small window button lives on it
/// rather than in a menu.
class LocalVideoPlayerPage extends GetView<LocalVideoPlayerController> {
  const LocalVideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isMobile) return _MobileLayout(controller: controller);
    return _DesktopLayout(controller: controller);
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

String _clock(Duration value) {
  final total = value.inSeconds < 0 ? 0 : value.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

String _sizeOf(File file) {
  try {
    final bytes = file.lengthSync();
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  } catch (_) {
    return '';
  }
}

String _modifiedOf(File file) {
  try {
    final at = file.lastModifiedSync();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  } catch (_) {
    return '';
  }
}

/// The video itself: no built-in bars, the page draws its own.
class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.controller, this.keyboardShortcuts = false});

  final LocalVideoPlayerController controller;
  final bool keyboardShortcuts;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocalVideoPlayerController>(
      builder: (_) {
        final handle = controller.handle;
        if (handle == null) return const ColoredBox(color: Colors.black);
        final kernel = PlayerKernelService.instance.kernel;
        return MediaCorePlayerView(
          handle: handle,
          actions: KernelPlayerControlActions(kernel: kernel, playerId: handle.id),
          fit: BoxFit.contain,
          showControls: false,
          keepControlsWhilePaused: true,
          keyboardShortcuts: keyboardShortcuts,
        );
      },
    );
  }
}

/// Scrub bar with the two clocks on either side.
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final duration = controller.duration.value;
      final position = controller.position.value;
      final max = duration.inMilliseconds.toDouble();
      final value = max <= 0 ? 0.0 : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
      return Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              _clock(position),
              style: const TextStyle(fontSize: 11, color: Colors.white70, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: Theme.of(context).colorScheme.primary,
              ),
              child: Slider(
                value: value,
                max: max <= 0 ? 1 : max,
                onChanged: max <= 0 ? null : (v) => controller.seekTo(Duration(milliseconds: v.round())),
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              _clock(duration),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: Colors.white70, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      );
    });
  }
}

/// Previous / back 10 / play / forward 10 / next, plus speed and the small
/// window. Sizes are thumb-friendly on touch and compact on desktop.
class _TransportButtons extends StatelessWidget {
  const _TransportButtons({required this.controller, this.compact = false});

  final LocalVideoPlayerController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 22.0 : 26.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: iconSize,
          color: Colors.white,
          disabledColor: Colors.white24,
          tooltip: i18n('recorder_local_player_previous'),
          icon: const Icon(Remix.skip_back_fill),
          onPressed: controller.hasPrevious ? () => unawaited(controller.previous()) : null,
        ),
        IconButton(
          iconSize: iconSize - 4,
          color: Colors.white,
          tooltip: i18n('local_player_seek_back'),
          icon: const Icon(Remix.replay_10_fill),
          onPressed: () => unawaited(controller.seekBy(const Duration(seconds: -10))),
        ),
        Obx(
          () => IconButton.filled(
            iconSize: compact ? 30 : 34,
            style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            tooltip: controller.isPlaying.value ? i18n('local_player_pause') : i18n('local_player_play'),
            icon: Icon(controller.isPlaying.value ? Icons.pause_rounded : Icons.play_arrow_rounded),
            onPressed: () => unawaited(controller.togglePlayPause()),
          ),
        ),
        IconButton(
          iconSize: iconSize - 4,
          color: Colors.white,
          tooltip: i18n('local_player_seek_forward'),
          icon: const Icon(Remix.forward_10_fill),
          onPressed: () => unawaited(controller.seekBy(const Duration(seconds: 10))),
        ),
        IconButton(
          iconSize: iconSize,
          color: Colors.white,
          disabledColor: Colors.white24,
          tooltip: i18n('recorder_local_player_next'),
          icon: const Icon(Remix.skip_forward_fill),
          onPressed: controller.hasNext ? () => unawaited(controller.next()) : null,
        ),
      ],
    );
  }
}

/// `1.25x` chip that cycles through the supported rates.
class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TextButton(
        onPressed: () => unawaited(controller.cycleRate()),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          '${controller.playbackRate.value}x',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// The small-window button: hands this recording to the in-app floating window
/// and leaves the page, which is the whole point of floating it.
class _FloatButton extends StatelessWidget {
  const _FloatButton({required this.controller, this.compact = false});

  final LocalVideoPlayerController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: compact ? 20 : 22,
      color: Colors.white,
      tooltip: i18n('float_window_play'),
      icon: const Icon(Remix.picture_in_picture_2_line),
      onPressed: () => unawaited(controller.enterFloating()),
    );
  }
}

/// File name plus how big it is and when it was written.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.controller,
    required this.index,
    this.dense = false,
    this.onPicked,
  });

  final LocalVideoPlayerController controller;
  final int index;
  final bool dense;
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = controller.videoFiles[index];
    final name = file.uri.pathSegments.last;
    return Obx(() {
      final active = controller.currentIndex.value == index;
      final accent = theme.colorScheme.primary;
      final details = <String>[
        if (_sizeOf(file).isNotEmpty) _sizeOf(file),
        if (_modifiedOf(file).isNotEmpty) _modifiedOf(file),
      ].join(' · ');
      return InkWell(
        onTap: () {
          unawaited(controller.showIndex(index));
          onPicked?.call();
        },
        onLongPress: () => _showMenu(context),
        onSecondaryTap: () => _showMenu(context),
        child: Container(
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.12) : Colors.transparent,
            border: Border(left: BorderSide(color: active ? accent : Colors.transparent, width: 3)),
          ),
          padding: EdgeInsets.fromLTRB(dense ? 10 : 12, 8, 4, 8),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? accent : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: active
                    ? Icon(Icons.graphic_eq_rounded, size: 15, color: theme.colorScheme.onPrimary)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? accent : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (details.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.onSurfaceVariant,
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showMenu(context),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _showMenu(BuildContext context) async {
    final file = controller.videoFiles[index];
    final name = file.uri.pathSegments.last;
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(value: 'play', child: _menuRow(Icons.play_arrow_rounded, i18n('recorder_play_video'))),
        PopupMenuItem(value: 'open_dir', child: _menuRow(Icons.folder_open_rounded, i18n('recorder_open_task_folder'))),
        PopupMenuItem(value: 'rename', child: _menuRow(Icons.edit_rounded, i18n('local_player_rename'))),
        PopupMenuItem(value: 'delete', child: _menuRow(Icons.delete_outline_rounded, i18n('local_player_delete'))),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'play':
        await controller.showIndex(index);
      case 'open_dir':
        await controller.openFileDir();
      case 'rename':
        await _promptRename(context, name);
      case 'delete':
        await _confirmDelete(context, name);
    }
  }

  Widget _menuRow(IconData icon, String text) =>
      Row(children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(text, style: const TextStyle(fontSize: 13))]);

  Future<void> _promptRename(BuildContext context, String name) async {
    final textController = TextEditingController(text: name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n('local_player_rename')),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(hintText: i18n('local_player_rename_hint')),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(i18n('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(textController.text), child: Text(i18n('done'))),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != name) {
      await controller.renameFile(index, newName);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n('local_player_delete')),
        content: Text(i18n('local_player_delete_confirm', args: {'name': name})),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(i18n('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(i18n('local_player_delete')),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteFile(index);
  }
}

/// The recording list, used as the desktop panel and inside the phone sheet.
class _PlaylistPanel extends StatelessWidget {
  const _PlaylistPanel({required this.controller, this.dense = false, this.onPicked});

  final LocalVideoPlayerController controller;
  final bool dense;
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, dense ? 10 : 14, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.roomTitle ?? i18n('recorder_local_player_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                    ),
                    Obx(
                      () => Text(
                        i18n('local_player_files', args: {'count': '${controller.videoFiles.length}'}),
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 18,
                color: theme.colorScheme.onSurfaceVariant,
                tooltip: i18n('recorder_open_task_folder'),
                icon: const Icon(Remix.folder_open_line),
                onPressed: () => unawaited(controller.openFileDir()),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Obx(
            () => ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: controller.videoFiles.length,
              itemBuilder: (_, i) => _FileRow(
                controller: controller,
                index: i,
                dense: dense,
                onPicked: onPicked,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _emptyState(BuildContext context, LocalVideoPlayerController controller, {bool onDark = false}) {
  final color = onDark ? Colors.white54 : Theme.of(context).colorScheme.outline;
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Remix.film_line, size: 56, color: color),
        const SizedBox(height: 14),
        Text(i18n('recorder_local_player_playlist_empty'), style: TextStyle(color: color, fontSize: 13)),
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(controller.openFileDir()),
          icon: const Icon(Remix.folder_open_line, size: 18),
          label: Text(i18n('local_player_folder_empty_action')),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Phone: picture first, controls over it
// ---------------------------------------------------------------------------

class _MobileLayout extends StatefulWidget {
  const _MobileLayout({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  static const Duration _autoHideAfter = Duration(seconds: 4);

  bool _controlsVisible = true;
  Timer? _hideTimer;
  late final PageController _pages = PageController(initialPage: widget.controller.currentIndex.value);

  @override
  void initState() {
    super.initState();
    _restartAutoHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    _restartAutoHide();
  }

  /// Any interaction keeps the bars up for another few seconds.
  void _poke() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _restartAutoHide();
  }

  void _restartAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_autoHideAfter, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showPlaylist() {
    _poke();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: _PlaylistPanel(controller: widget.controller, dense: true, onPicked: () => Navigator.of(context).pop()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.videoFiles.isEmpty) {
          return SafeArea(child: _emptyState(context, controller, onDark: true));
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: controller.videoFiles.length,
              controller: _pages,
              onPageChanged: (i) => unawaited(controller.showIndex(i)),
              itemBuilder: (_, i) => GetBuilder<LocalVideoPlayerController>(
                builder: (_) => controller.currentIndex.value == i
                    ? _VideoSurface(controller: controller)
                    : const ColoredBox(color: Colors.black),
              ),
            ),
            // Tap anywhere to bring the bars back or send them away.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
                onDoubleTap: () => unawaited(controller.togglePlayPause()),
              ),
            ),
            IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Column(
                  children: [
                    _topBar(context, controller),
                    const Spacer(),
                    _bottomBar(context, controller),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _topBar(BuildContext context, LocalVideoPlayerController controller) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
          child: Row(
            children: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Get.back(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.roomTitle ?? i18n('recorder_local_player_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Obx(
                      () => Text(
                        controller.roomNick == null || controller.roomNick!.isEmpty
                            ? i18n('local_player_files', args: {'count': '${controller.videoFiles.length}'})
                            : '${controller.roomNick} · ${controller.currentIndex.value + 1}/${controller.videoFiles.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              _FloatButton(controller: controller, compact: true),
              IconButton(
                color: Colors.white,
                tooltip: i18n('recorder_local_player_title'),
                icon: const Icon(Remix.play_list_line),
                onPressed: _showPlaylist,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, LocalVideoPlayerController controller) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => Text(
                  controller.currentFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              const SizedBox(height: 2),
              _ProgressRow(controller: controller),
              Row(
                children: [
                  const Spacer(),
                  _TransportButtons(controller: controller),
                  const Spacer(),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SpeedChip(controller: controller),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop: picture and list side by side
// ---------------------------------------------------------------------------

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.roomTitle ?? i18n('recorder_local_player_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Text(
                controller.videoFiles.isEmpty
                    ? i18n('recorder_local_player_playlist_empty')
                    : '${controller.currentFileName}   ${controller.currentIndex.value + 1}/${controller.videoFiles.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: i18n('recorder_open_task_folder'),
            icon: const Icon(Remix.folder_open_line),
            onPressed: () => unawaited(controller.openFileDir()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.videoFiles.isEmpty) {
          return _emptyState(context, controller);
        }
        return Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
                      ),
                      child: _VideoSurface(controller: controller, keyboardShortcuts: true),
                    ),
                  ),
                  _desktopControls(context, controller),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 320,
              child: _PlaylistPanel(controller: controller),
            ),
          ],
        );
      }),
    );
  }

  Widget _desktopControls(BuildContext context, LocalVideoPlayerController controller) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: _desktopProgress(controller, theme),
          ),
          Row(
            children: [
              _TransportButtons(controller: controller, compact: true),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(
                  () => Text(
                    controller.currentFileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              _SpeedChip(controller: controller),
              const SizedBox(width: 4),
              IconButton(
                iconSize: 20,
                tooltip: i18n('float_window_play'),
                icon: const Icon(Remix.picture_in_picture_2_line),
                onPressed: () => unawaited(controller.enterFloating()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The desktop bar draws its own clocks next to a theme-coloured track, so it
  /// does not reuse the phone row's white-on-black colours.
  Widget _desktopProgress(LocalVideoPlayerController controller, ThemeData theme) {
    return Obx(() {
      final duration = controller.duration.value;
      final position = controller.position.value;
      final max = duration.inMilliseconds.toDouble();
      final value = max <= 0 ? 0.0 : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
      return Row(
        children: [
          Text(
            _clock(position),
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
          Expanded(
            child: Slider(
              value: value,
              max: max <= 0 ? 1 : max,
              onChanged: max <= 0 ? null : (v) => controller.seekTo(Duration(milliseconds: v.round())),
            ),
          ),
          Text(
            _clock(duration),
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    });
  }
}
