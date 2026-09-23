import 'dart:async';

import 'record_action_content.dart';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

class RecordActionButton extends StatefulWidget {
  const RecordActionButton({
    super.key,
    required this.room,
    required this.recorderController,
    required this.onOpenRecordCenter,
    this.compactHeader = false,
  });

  final LiveRoom? room;
  final RecorderController recorderController;
  final Future<void> Function() onOpenRecordCenter;
  final bool compactHeader;

  @override
  State<RecordActionButton> createState() => _RecordActionButtonState();
}

class _RecordActionButtonState extends State<RecordActionButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    if (room == null) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final task = widget.recorderController.tasks.firstWhereOrNull(
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
          width: widget.compactHeader ? kMinInteractiveDimension : null,
          height: kMinInteractiveDimension,
          child: FilledButton(
            key: const ValueKey('record-action-button'),
            style: FilledButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              padding: widget.compactHeader ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(kMinInteractiveDimension, kMinInteractiveDimension),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _busy ? null : () => unawaited(_handlePressed(context, room)),
            child: RecordActionContent(compactHeader: widget.compactHeader, label: label, icon: icon),
          ),
        ),
      );
    });
  }

  bool _isTaskRunning(LiveRecordTask? task) {
    if (task == null) {
      return false;
    }

    return task.status == RecordStatus.running ||
        task.status == RecordStatus.reconnecting ||
        task.status == RecordStatus.preparing;
  }

  Future<void> _handlePressed(BuildContext context, LiveRoom room) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final initialTask = _findTask(room);
      final action = await _showActionDialog(
        context,
        exists: initialTask != null,
        isRunning: _isTaskRunning(initialTask),
      );

      if (!mounted || action == null) return;
      final task = _findTask(room);
      final exists = task != null;
      final isRunning = _isTaskRunning(task);

      switch (action) {
        case "start":
          await _startRecording(room: room, task: task, exists: exists, isRunning: isRunning);
          break;

        case "monitor":
          await _addMonitor(room: room, exists: exists);
          break;

        case "stop":
          await _stopRecording(task: task, exists: exists, isRunning: isRunning);
          break;

        case "delete":
          await _removeMonitor(task: task, exists: exists, isRunning: isRunning);
          break;

        case "page":
          await widget.onOpenRecordCenter();
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  LiveRecordTask? _findTask(LiveRoom room) => widget.recorderController.tasks.firstWhereOrNull(
    (task) => task.platform == room.platform && task.roomId == room.roomId,
  );

  Future<void> _startRecording({
    required LiveRoom room,
    required LiveRecordTask? task,
    required bool exists,
    required bool isRunning,
  }) async {
    if (isRunning) {
      return;
    }

    if (exists && task != null) {
      await widget.recorderController.forceStartTask(task);
      return;
    }

    // addTask owns the first transition into the scheduler. Starting it again
    // from the button created two competing intents and made first-attempt
    // failures difficult to classify.
    await widget.recorderController.addTask(room: room, startImmediately: true);
  }

  Future<void> _addMonitor({required LiveRoom room, required bool exists}) async {
    if (exists) {
      return;
    }

    final task = await widget.recorderController.addTask(room: room, startImmediately: false);
    if (task != null) ToastUtil.show(i18n("record_task_added"));
  }

  Future<void> _stopRecording({required LiveRecordTask? task, required bool exists, required bool isRunning}) async {
    if (!exists || task == null || !isRunning) {
      return;
    }

    await widget.recorderController.stopTask(task);
  }

  Future<void> _removeMonitor({required LiveRecordTask? task, required bool exists, required bool isRunning}) async {
    if (!exists || task == null || isRunning) {
      return;
    }

    await widget.recorderController.unRecorder(task);
  }

  Future<String?> _showActionDialog(BuildContext context, {required bool exists, required bool isRunning}) {
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final mediaQuery = MediaQuery.of(dialogContext);
        final availableHeight =
            mediaQuery.size.height - mediaQuery.padding.vertical - mediaQuery.viewInsets.vertical - 32;
        final stackTitle = mediaQuery.size.width < 360 || mediaQuery.textScaler.scale(22) > 40;
        final titleIcon = AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
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
        );
        final titleText = Text(
          isRunning
              ? i18n("recording")
              : exists
              ? i18n("record_task")
              : i18n("record"),
          style: theme.textTheme.headlineSmall,
        );
        return Dialog(
          key: const ValueKey('record-action-dialog'),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: availableHeight > 0 ? availableHeight : mediaQuery.size.height,
            ),
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    key: const ValueKey('record-action-title'),
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                    child: stackTitle
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [titleIcon, const SizedBox(height: 8), titleText],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleIcon,
                              const SizedBox(width: 10),
                              Expanded(child: titleText),
                            ],
                          ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      key: const ValueKey('record-action-scroll'),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionTile(
                            icon: Icons.play_arrow_rounded,
                            title: i18n("start_record_now"),
                            color: Colors.green,
                            enabled: !isRunning,
                            onTap: () => Navigator.pop(dialogContext, "start"),
                          ),
                          _ActionTile(
                            icon: Icons.video_library_rounded,
                            title: i18n("go_record_center"),
                            color: theme.colorScheme.primary,
                            enabled: true,
                            onTap: () => Navigator.pop(dialogContext, "page"),
                          ),
                          _ActionTile(
                            icon: Remix.checkbox_circle_line,
                            title: i18n("add_monitor"),
                            color: theme.colorScheme.primary,
                            enabled: !exists,
                            onTap: () => Navigator.pop(dialogContext, "monitor"),
                          ),
                          _ActionTile(
                            icon: Icons.stop_circle_outlined,
                            title: i18n("stop_record"),
                            color: Colors.orange,
                            enabled: isRunning,
                            onTap: () => Navigator.pop(dialogContext, "stop"),
                          ),
                          _ActionTile(
                            icon: Icons.delete_outline_rounded,
                            title: i18n("remove_monitor"),
                            color: Colors.redAccent,
                            enabled: exists && !isRunning,
                            onTap: () => Navigator.pop(dialogContext, "delete"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  SafeArea(
                    key: const ValueKey('record-action-footer'),
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          key: const ValueKey('record-action-cancel'),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(i18n('cancel')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
