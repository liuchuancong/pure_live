import 'dart:async';
import 'dart:io';

import 'package:media_core_ui/media_core_ui.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:pure_live/core/player/kernel/player_kernel_service.dart';
import 'package:pure_live/core/player/presentation/danmaku/player_danmaku_actions.dart';
import 'package:pure_live/core/player/presentation/player_ui_controller.dart';
import 'package:pure_live/domains/recorder/presentation/pages/local_player/local_video_player_controller.dart';

/// One recording, played.
///
/// The page carries only what is specific to a *recording*: the file list, the
/// folder actions, the replayed chat. Everything a player surface does is the
/// shared Core one — [PlayerGestureLayer] for brightness/volume/scroll,
/// [PlayerUiController] for the transport, and [MediaCorePlayerView]'s own bar
/// for play/pause, skip, timeline, speed, fullscreen and picture-in-picture. A
/// live room drives exactly the same three; the difference between the two pages
/// is where the media comes from, not how it is watched.
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

/// The video surface: the shared gesture layer over the library's own player.
///
/// The gesture layer sits *above* the picture so a drag anywhere on it means
/// brightness or volume even while the library's bars are on screen, and the
/// replayed chat is drawn between the two. No second transport bar is built
/// here on purpose: the library's bar is the same one every other surface in the
/// app shows.
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
        return PlayerGestureLayer(
          controller: controller,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaCorePlayerView(
                handle: handle,
                actions: KernelPlayerControlActions(kernel: kernel, playerId: handle.id),
                fit: BoxFit.contain,
                // The library's bar carries play/pause, skip, the timeline,
                // speed, fullscreen and picture-in-picture; the page adds only
                // the recording-specific actions on top.
                showControls: true,
                keepControlsWhilePaused: true,
                keyboardShortcuts: keyboardShortcuts,
                onTapVideo: controller.togglePlayPause,
              ),
              // The build is inside the `Obx` on purpose: `buildDanmakuSurface`
              // reads whether the recording carries chat and whether the viewer
              // switched danmaku off, and a builder with no observable at all is
              // an error in GetX rather than a static surface.
              Obx(() => Positioned.fill(child: controller.buildDanmakuSurface(context) ?? const SizedBox.shrink())),
            ],
          ),
        );
      },
    );
  }
}

/// File name plus how big it is and when it was written.
class _FileRow extends StatelessWidget {
  const _FileRow({required this.controller, required this.index, this.dense = false, this.onPicked});

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
                    : Text('${index + 1}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
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

  Widget _menuRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(fontSize: 13)),
    ],
  );

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
///
/// Every reactive read sits inside an `Obx`: `videoFiles` is an observable list,
/// so the builder attaches to it and the list stays live as files are recorded
/// or deleted — a builder with no observable at all is an error in GetX, not an
/// empty list.
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
              itemBuilder: (_, i) => _FileRow(controller: controller, index: i, dense: dense, onPicked: onPicked),
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

/// Puts the recording into the system picture-in-picture window.
///
/// The controller drives the same Core transition the live room uses, so the
/// window is shaped, placed and remembered identically; a platform without a
/// working implementation reports it instead of failing silently.
Future<void> _enterRecordingPip(LocalVideoPlayerController controller) async {
  try {
    await controller.enterPip();
  } catch (_) {
    ToastUtil.show(i18n('pip_enter_failed'));
  }
}

/// The presentation and danmaku actions of the recording page.
///
/// The same widgets the live room's bar uses ([PlayerDanmakuButton],
/// [PlayerDanmakuSettingsButton], [PlayerVideoFitButton]): the viewer gets the
/// same glyphs, the same danmaku panel and the same six fit modes in both
/// players. What is left here is only what a *recording* adds: PiP, the
/// in-app small window and, where there is no panel of its own, the list.
class _RecordingActions extends StatelessWidget {
  const _RecordingActions({required this.controller, required this.onDark, this.includePlaylist = false});

  final LocalVideoPlayerController controller;
  final bool onDark;
  final bool includePlaylist;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant;
    return Obx(() {
      // Danmaku actions only make sense once the chat file has been read.
      final hasChat = controller.hasDanmaku.value;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasChat) ...[
            PlayerDanmakuButton(controller: controller, iconColor: color),
            PlayerDanmakuSettingsButton(controller: controller, iconColor: color),
          ],
          PlayerVideoFitButton(labelColor: color),
          IconButton(
            color: color,
            tooltip: i18n('pip_window_play'),
            icon: const Icon(Remix.picture_in_picture_line),
            onPressed: () => unawaited(_enterRecordingPip(controller)),
          ),
          IconButton(
            color: color,
            tooltip: i18n('float_window_play'),
            icon: const Icon(Remix.picture_in_picture_2_line),
            onPressed: () => unawaited(controller.enterFloating()),
          ),
          if (includePlaylist)
            IconButton(
              color: color,
              tooltip: i18n('recorder_local_player_title'),
              icon: const Icon(Remix.play_list_line),
              onPressed: () => _showPlaylist(context, controller),
            ),
        ],
      );
    });
  }
}

/// The recording list as a phone sheet.
void _showPlaylist(BuildContext context, LocalVideoPlayerController controller) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: _PlaylistPanel(controller: controller, dense: true, onPicked: () => Navigator.of(context).pop()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Phone: short-video shape — the picture on top, the recording's context panel
// below, and the file list in a bottom sheet ("选集")
// ---------------------------------------------------------------------------

class _MobileLayout extends StatefulWidget {
  const _MobileLayout({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  LocalVideoPlayerController get controller => widget.controller;

  /// Landscape flips to the fullscreen shape: the picture owns the screen and
  /// the chrome floats over it, exactly like a live room in fullscreen.
  bool get isLandscape {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.videoFiles.isEmpty) {
          return SafeArea(child: _emptyState(context, controller, onDark: true));
        }
        if (isLandscape) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _VideoSurface(controller: controller, keyboardShortcuts: true),
              _LandscapeTopBar(controller: controller),
            ],
          );
        }
        return SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.black,
                      child: _VideoSurface(controller: controller),
                    ),
                    _PortraitTopBar(controller: controller),
                  ],
                ),
              ),
              _ContextPanel(controller: controller, onOpenPlaylist: () => _showPlaylist(context, controller)),
            ],
          ),
        );
      }),
    );
  }
}

/// Portrait chrome over the picture: back, the title, and the fullscreen pill.
///
/// The transport lives in the library's own bar over the picture; this row is
/// only where you are and how to leave.
class _PortraitTopBar extends StatelessWidget {
  const _PortraitTopBar({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
          child: Row(
            children: [
              IconButton(color: Colors.white, icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Get.back()),
              Expanded(
                child: Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.roomTitle ?? i18n('recorder_local_player_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${controller.currentIndex.value + 1}/${controller.videoFiles.length}  ${controller.currentFileName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              _FullscreenPill(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

/// The fullscreen pill over the picture: the one affordance the short-video
/// layout keeps on the video itself, since the library's bar with the real
/// fullscreen button hides with the rest of the chrome.
class _FullscreenPill extends StatelessWidget {
  const _FullscreenPill({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(controller.enterLandscapeFullscreen()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fullscreen_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 5),
              Text(i18n('fullscreen_watch'), style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The recording's context below the picture, in the short-video arrangement:
/// the title and where you are, a row of actions (danmaku, fit, PiP, small
/// window), a playlist affordance, then a thin progress line that mirrors the
/// library bar's timeline.
class _ContextPanel extends StatelessWidget {
  const _ContextPanel({required this.controller, required this.onOpenPlaylist});

  final LocalVideoPlayerController controller;
  final VoidCallback onOpenPlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.roomTitle ?? i18n('recorder_local_player_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    controller.currentFileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _RecordingActions(controller: controller, onDark: false, includePlaylist: false),
                  ),
                ),
                IconButton(
                  tooltip: i18n('recorder_local_player_title'),
                  color: theme.colorScheme.onSurfaceVariant,
                  icon: const Icon(Remix.play_list_line),
                  onPressed: onOpenPlaylist,
                ),
              ],
            ),
          ),
          // A read-only progress mirror: the real scrubber stays in the
          // library's bar over the picture, this line only says where the
          // recording is while the panel is up.
          Obx(() {
            final durationMs = controller.duration.value.inMilliseconds;
            final positionMs = controller.position.value.inMilliseconds;
            final progress = durationMs <= 0 ? 0.0 : (positionMs / durationMs).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: theme.colorScheme.primary,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Landscape keeps floating chrome: the picture is the screen and the actions
/// sit in the top gradient row.
class _LandscapeTopBar extends StatelessWidget {
  const _LandscapeTopBar({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
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
                  child: Obx(
                    () => Text(
                      '${controller.roomTitle ?? i18n('recorder_local_player_title')}  '
                      '${controller.currentIndex.value + 1}/${controller.videoFiles.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _RecordingActions(controller: controller, onDark: true, includePlaylist: true),
                ),
              ],
            ),
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
          _RecordingActions(controller: controller, onDark: false),
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: Colors.black,
                    child: _VideoSurface(controller: controller, keyboardShortcuts: true),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            SizedBox(width: 320, child: _PlaylistPanel(controller: controller)),
          ],
        );
      }),
    );
  }
}
