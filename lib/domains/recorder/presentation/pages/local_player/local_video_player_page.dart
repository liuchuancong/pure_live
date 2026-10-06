import 'package:media_core_ui/media_core_ui.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:pure_live/core/player/kernel/player_kernel_service.dart';
import 'package:pure_live/domains/recorder/presentation/pages/local_player/local_video_player_controller.dart';

class LocalVideoPlayerPage extends GetView<LocalVideoPlayerController> {
  const LocalVideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isMobile) return _MobileFeedLayout(controller: controller);
    return _DesktopSplitLayout(controller: controller);
  }
}

// ---------------------------------------------------------------------------
// Mobile: TikTok-style vertical feed
// ---------------------------------------------------------------------------

class _MobileFeedLayout extends StatelessWidget {
  const _MobileFeedLayout({required this.controller});
  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.videoFiles.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Remix.video_line, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                Text(i18n('recorder_local_player_playlist_empty'), style: const TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }
        return Stack(
          children: [
            PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: controller.videoFiles.length,
              controller: PageController(initialPage: controller.currentIndex.value),
              onPageChanged: (i) => controller.showIndex(i),
              itemBuilder: (_, i) => _FeedVideoPage(controller: controller, index: i),
            ),
            SafeArea(child: _MobileTopBar(controller: controller)),
            Positioned(bottom: 0, left: 0, right: 0, child: SafeArea(top: false, child: _MobileBottomBar(controller: controller))),
          ],
        );
      }),
    );
  }
}

class _FeedVideoPage extends StatelessWidget {
  const _FeedVideoPage({required this.controller, required this.index});
  final LocalVideoPlayerController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocalVideoPlayerController>(
      builder: (_) {
        final handle = controller.handle;
        if (handle == null || controller.currentIndex.value != index) {
          return const ColoredBox(color: Colors.black);
        }
        final kernel = PlayerKernelService.instance.kernel;
        return MediaCorePlayerView(
          handle: handle,
          actions: KernelPlayerControlActions(kernel: kernel, playerId: handle.id),
          fit: BoxFit.contain,
          autoHideControls: true,
          keepControlsWhilePaused: true,
        );
      },
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.controller});
  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.roomTitle ?? i18n('recorder_local_player_title'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (controller.roomNick != null)
                  Text(controller.roomNick!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Obx(
            () => Text(
              '${controller.currentIndex.value + 1}/${controller.videoFiles.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Remix.list_unordered, color: Colors.white),
            onPressed: () => _showVideoPicker(context),
            tooltip: i18n('recorder_local_player_title'),
          ),
        ],
      ),
    );
  }

  void _showVideoPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _VideoPickerSheet(controller: controller),
    );
  }
}

class _MobileBottomBar extends StatelessWidget {
  const _MobileBottomBar({required this.controller});
  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => Text(
                controller.currentFileName,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Obx(
            () => GestureDetector(
              onTap: controller.cycleRate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${controller.playbackRate.value}x',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop: video left + playlist right
// ---------------------------------------------------------------------------

class _DesktopSplitLayout extends StatelessWidget {
  const _DesktopSplitLayout({required this.controller});
  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.roomTitle ?? i18n('recorder_local_player_title')),
        actions: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${controller.currentIndex.value + 1}/${controller.videoFiles.length}',
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.videoFiles.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Remix.video_line, size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(i18n('recorder_local_player_playlist_empty'), style: TextStyle(color: theme.colorScheme.outline)),
              ],
            ),
          );
        }
        return Row(
          children: [
            Expanded(child: _DesktopVideoArea(controller: controller)),
            const VerticalDivider(width: 1),
            SizedBox(width: 300, child: _DesktopPlaylist(controller: controller, theme: theme)),
          ],
        );
      }),
    );
  }
}

class _DesktopVideoArea extends StatelessWidget {
  const _DesktopVideoArea({required this.controller});
  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GetBuilder<LocalVideoPlayerController>(
            builder: (_) {
              final handle = controller.handle;
              if (handle == null) return const SizedBox.expand();
              final kernel = PlayerKernelService.instance.kernel;
              return MediaCorePlayerView(
                handle: handle,
                actions: KernelPlayerControlActions(kernel: kernel, playerId: handle.id),
                fit: BoxFit.contain,
                autoHideControls: true,
                keepControlsWhilePaused: true,
                keyboardShortcuts: true,
              );
            },
          ),
        ),
        _DesktopControlBar(controller: controller),
      ],
    );
  }
}

class _DesktopControlBar extends StatelessWidget {
  const _DesktopControlBar({required this.controller});
  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Remix.skip_back_fill),
            iconSize: 22,
            onPressed: controller.hasPrevious ? controller.previous : null,
            tooltip: i18n('recorder_local_player_previous'),
          ),
          IconButton(
            icon: const Icon(Remix.rewind_fill),
            iconSize: 20,
            onPressed: () => controller.seekBy(const Duration(seconds: -10)),
            tooltip: '-10s',
          ),
          Obx(
            () => IconButton(
              icon: Icon(controller.isPlaying.value ? Icons.pause_rounded : Icons.play_arrow_rounded),
              iconSize: 30,
              onPressed: controller.togglePlayPause,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fast_forward_rounded),
            iconSize: 20,
            onPressed: () => controller.seekBy(const Duration(seconds: 10)),
            tooltip: '+10s',
          ),
          IconButton(
            icon: const Icon(Remix.skip_forward_fill),
            iconSize: 22,
            onPressed: controller.hasNext ? controller.next : null,
            tooltip: i18n('recorder_local_player_next'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Obx(
              () => Text(
                controller.currentFileName,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Obx(
            () => PopupMenuButton<double>(
              initialValue: controller.playbackRate.value,
              onSelected: controller.setRate,
              itemBuilder: (_) => LocalVideoPlayerController.defaultRates
                  .map((r) => PopupMenuItem(value: r, child: Text('${r}x')))
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  '${controller.playbackRate.value}x',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Remix.list_unordered),
            onPressed: () => _showVideoPicker(context),
            tooltip: i18n('recorder_local_player_title'),
          ),
        ],
      ),
    );
  }

  void _showVideoPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: SizedBox(width: 420, height: 500, child: _VideoPickerSheet(controller: controller)),
      ),
    );
  }
}

class _DesktopPlaylist extends StatelessWidget {
  const _DesktopPlaylist({required this.controller, required this.theme});
  final LocalVideoPlayerController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            i18n('recorder_local_player_title'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Obx(
            () => ListView.builder(
              itemCount: controller.videoFiles.length,
              itemBuilder: (_, i) {
                final isActive = i == controller.currentIndex.value;
                final file = controller.videoFiles[i];
                final name = file.uri.pathSegments.last;
                return _PlaylistTile(
                  file: file,
                  name: name,
                  index: i,
                  isActive: isActive,
                  controller: controller,
                  theme: theme,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.file,
    required this.name,
    required this.index,
    required this.isActive,
    required this.controller,
    required this.theme,
  });

  final dynamic file;
  final String name;
  final int index;
  final bool isActive;
  final LocalVideoPlayerController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
      child: ListTile(
        dense: true,
        selected: isActive,
        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        leading: Icon(
          isActive ? Icons.play_arrow_rounded : Icons.movie_outlined,
          size: 20,
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface),
        ),
        subtitle: Text(
          '${index + 1}/${controller.videoFiles.length}',
          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
        ),
        onTap: () => controller.showIndex(index),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final relativeRect = RelativeRect.fromRect(
      position & Size.zero,
      Offset.zero & context.size!,
    );
    showMenu<String>(
      context: context,
      position: relativeRect,
      items: [
        PopupMenuItem(value: 'play', child: _menuRow(Icons.play_arrow_rounded, i18n('recorder_play_video'))),
        PopupMenuItem(value: 'open_dir', child: _menuRow(Icons.folder_open_rounded, i18n('recorder_open_task_folder'))),
        PopupMenuItem(value: 'rename', child: _menuRow(Icons.edit_rounded, i18n('local_player_rename'))),
        PopupMenuItem(value: 'delete', child: _menuRow(Icons.delete_outline_rounded, i18n('local_player_delete'))),
      ],
    ).then((action) {
      if (action == null) return;
      switch (action) {
        case 'play':
          controller.showIndex(index);
        case 'open_dir':
          controller.openFileDir();
        case 'rename':
          if (context.mounted) _promptRename(context);
        case 'delete':
          if (context.mounted) _confirmDelete(context);
      }
    });
  }

  Widget _menuRow(IconData icon, String text) => Row(
    children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(text, style: const TextStyle(fontSize: 13))],
  );

  Future<void> _promptRename(BuildContext context) async {
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

  Future<void> _confirmDelete(BuildContext context) async {
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

// ---------------------------------------------------------------------------
// Shared video picker (fullscreen dialog / bottom sheet)
// ---------------------------------------------------------------------------

class _VideoPickerSheet extends StatelessWidget {
  const _VideoPickerSheet({required this.controller});
  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark || PlatformUtils.isMobile;
    final bgColor = PlatformUtils.isMobile ? const Color(0xFF1E1E1E) : theme.colorScheme.surface;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subTextColor = isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant;

    return Container(
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.roomTitle ?? i18n('recorder_local_player_title'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                  ),
                ),
                Obx(
                  () => Text(
                    '${controller.currentIndex.value + 1}/${controller.videoFiles.length}',
                    style: TextStyle(fontSize: 13, color: subTextColor),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(
              () => ListView.builder(
                itemCount: controller.videoFiles.length,
                itemBuilder: (_, i) {
                  final isActive = i == controller.currentIndex.value;
                  final file = controller.videoFiles[i];
                  final name = file.uri.pathSegments.last;
                  final activeColor = isDark ? Colors.white : theme.colorScheme.primary;
                  return ListTile(
                    dense: true,
                    selected: isActive,
                    selectedTileColor: (isDark ? Colors.white : theme.colorScheme.primary).withValues(alpha: 0.1),
                    leading: Icon(
                      isActive ? Icons.play_arrow_rounded : Icons.movie_outlined,
                      size: 20,
                      color: isActive ? activeColor : subTextColor,
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: isActive ? activeColor : textColor),
                    ),
                    subtitle: Text('${i + 1}', style: TextStyle(fontSize: 11, color: subTextColor)),
                    onTap: () {
                      controller.showIndex(i);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
