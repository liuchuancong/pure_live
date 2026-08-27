import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

class RecordActionButton extends StatelessWidget {
  const RecordActionButton({
    super.key,
    required this.room,
    required this.recorderController,
    required this.onOpenRecordCenter,
    this.compactHeader = false,
  });

  final dynamic room;
  final RecorderController recorderController;
  final Future<void> Function() onOpenRecordCenter;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    if (room == null) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final task = recorderController.tasks.firstWhereOrNull(
        (t) => t.platform == room.platform && t.roomId == room.roomId,
      );

      final exists = task != null;
      final isRunning = _isTaskRunning(task);
      final theme = Theme.of(context);

      final label = isRunning
          ? i18n("recording")
          : exists
          ? i18n("monitored")
          : i18n("record");

      final icon = isRunning
          ? Remix.record_circle_fill
          : exists
          ? Remix.checkbox_circle_fill
          : Remix.record_circle_line;

      final foregroundColor = isRunning
          ? Colors.redAccent
          : exists
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant;

      final backgroundColor = isRunning
          ? Colors.redAccent.withValues(alpha: 0.12)
          : exists
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : theme.colorScheme.surfaceContainerHighest;

      return Tooltip(
        message: label,
        child: SizedBox(
          width: compactHeader ? 40 : null,
          height: 38,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              padding: compactHeader ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: compactHeader ? const Size(38, 38) : const Size(0, 38),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              _handlePressed(context, task: task, exists: exists, isRunning: isRunning);
            },
            child: compactHeader
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(icon, key: ValueKey(icon), size: 18),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Row(
                      key: ValueKey(label),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
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

  bool _isTaskRunning(dynamic task) {
    if (task == null) {
      return false;
    }

    return task.status == RecordStatus.running ||
        task.status == RecordStatus.reconnecting ||
        task.status == RecordStatus.preparing;
  }

  Future<void> _handlePressed(
    BuildContext context, {
    required dynamic task,
    required bool exists,
    required bool isRunning,
  }) async {
    final action = await _showActionDialog(context, exists: exists, isRunning: isRunning);

    if (action == null) {
      return;
    }

    switch (action) {
      case "start":
        await _startRecording(task: task, exists: exists, isRunning: isRunning);
        break;

      case "monitor":
        await _addMonitor(exists: exists);
        break;

      case "stop":
        _stopRecording(task: task, exists: exists, isRunning: isRunning);
        break;

      case "delete":
        _removeMonitor(task: task, exists: exists, isRunning: isRunning);
        break;

      case "page":
        // Let the dialog reverse transition finish before the native video
        // route starts another transition. Starting both animations in the
        // same frame can race the platform video surface on Windows/Android.
        await onOpenRecordCenter();
        break;
    }
  }

  Future<void> _startRecording({required dynamic task, required bool exists, required bool isRunning}) async {
    if (isRunning) {
      return;
    }

    if (exists && task != null) {
      recorderController.forceStartTask(task);
      return;
    }

    // addTask owns the first transition into the scheduler. Starting it again
    // from the button created two competing intents and made first-attempt
    // failures difficult to classify.
    await recorderController.addTask(room: room, startImmediately: true);
  }

  Future<void> _addMonitor({required bool exists}) async {
    if (exists) {
      return;
    }

    await recorderController.addTask(room: room, startImmediately: false);

    ToastUtil.show(i18n("record_task_added"));
  }

  void _stopRecording({required dynamic task, required bool exists, required bool isRunning}) {
    if (!exists || task == null || !isRunning) {
      return;
    }

    recorderController.stopTask(task);
  }

  void _removeMonitor({required dynamic task, required bool exists, required bool isRunning}) {
    if (!exists || task == null || isRunning) {
      return;
    }

    recorderController.unRecorder(task);
  }

  Future<String?> _showActionDialog(BuildContext context, {required bool exists, required bool isRunning}) {
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          title: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  isRunning
                      ? Remix.record_circle_fill
                      : exists
                      ? Remix.checkbox_circle_fill
                      : Remix.record_circle_line,
                  key: ValueKey(
                    isRunning
                        ? "running"
                        : exists
                        ? "exists"
                        : "empty",
                  ),
                  color: isRunning ? Colors.redAccent : theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isRunning
                      ? i18n("recording")
                      : exists
                      ? i18n("record_task")
                      : i18n("record"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.play_arrow_rounded,
                title: i18n("start_record_now"),
                color: Colors.green,
                enabled: !isRunning,
                onTap: () {
                  Navigator.pop(dialogContext, "start");
                },
              ),
              _ActionTile(
                icon: Icons.video_library_rounded,
                title: i18n("go_record_center"),
                color: theme.colorScheme.primary,
                enabled: true,
                onTap: () {
                  // 貌似Video有问题无法进行页面跳转 否则会崩溃 但是注释掉就可以 待解决
                  Navigator.pop(dialogContext, "page");
                  // Get.toNamed(RoutePath.kRecordPage);
                },
              ),
              _ActionTile(
                icon: Remix.checkbox_circle_line,
                title: i18n("add_monitor"),
                color: theme.colorScheme.primary,
                enabled: !exists,
                onTap: () {
                  Navigator.pop(dialogContext, "monitor");
                },
              ),
              _ActionTile(
                icon: Icons.stop_circle_outlined,
                title: i18n("stop_record"),
                color: Colors.orange,
                enabled: isRunning,
                onTap: () {
                  Navigator.pop(dialogContext, "stop");
                },
              ),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                title: i18n("remove_monitor"),
                color: Colors.redAccent,
                enabled: exists && !isRunning,
                onTap: () {
                  Navigator.pop(dialogContext, "delete");
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final disabledColor = theme.colorScheme.onSurface.withValues(alpha: 0.32);

    final actualColor = enabled ? color : disabledColor;

    final backgroundAlpha = enabled ? 0.10 : 0.045;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1.0 : 0.72,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: actualColor.withValues(alpha: backgroundAlpha),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: actualColor, size: 20),
        ),
        title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(color: actualColor)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        enabled: enabled,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
