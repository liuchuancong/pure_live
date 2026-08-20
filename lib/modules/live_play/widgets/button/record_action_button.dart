import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

class RecordActionButton extends StatelessWidget {
  const RecordActionButton({
    super.key,
    required this.room,
    required this.recorderController,
    this.compactHeader = false,
  });

  final dynamic room;
  final RecorderController recorderController;
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

      final isRunning =
          task?.status == RecordStatus.running ||
          task?.status == RecordStatus.reconnecting ||
          task?.status == RecordStatus.preparing;

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

      return Tooltip(
        message: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: compactHeader ? 40 : null,
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
              padding: compactHeader ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: compactHeader ? const Size(38, 38) : null,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _handlePressed(context, task: task, exists: exists, isRunning: isRunning),
            child: compactHeader
                ? Icon(icon, size: 18)
                : Row(
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
      );
    });
  }

  Future<void> _handlePressed(
    BuildContext context, {
    required dynamic task,
    required bool exists,
    required bool isRunning,
  }) async {
    final action = await _showActionDialog(context, exists: exists, isRunning: isRunning);

    switch (action) {
      case "start":
        if (exists) {
          recorderController.forceStartTask(task);
        } else {
          await recorderController.addTask(room: room);
          final newTask = recorderController.tasks.firstWhereOrNull(
            (t) => t.platform == room.platform && t.roomId == room.roomId,
          );
          if (newTask != null) {
            recorderController.forceStartTask(newTask);
          }
        }
        break;

      case "monitor":
        if (!exists) {
          await recorderController.addTask(room: room);
          ToastUtil.show(i18n("record_task_added"));
        }
        break;

      case "stop":
        if (task != null) {
          recorderController.stopTask(task);
        }
        break;

      case "delete":
        if (task != null) {
          recorderController.unRecorder(task);
        }
        break;

      case "page":
        Get.toNamed(RoutePath.kRecordPage);
        break;
    }
  }

  Future<String?> _showActionDialog(BuildContext context, {required bool exists, required bool isRunning}) {
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(
                isRunning
                    ? Remix.record_circle_fill
                    : exists
                    ? Remix.checkbox_circle_fill
                    : Remix.record_circle_line,
                color: isRunning ? Colors.redAccent : theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isRunning
                    ? i18n("recording")
                    : exists
                    ? i18n("record_task")
                    : i18n("record"),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 未录制时：开始录制放最顶部
              if (!isRunning)
                _ActionTile(
                  icon: Icons.play_arrow_rounded,
                  title: i18n("start_record_now"),
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(dialogContext, "start");
                  },
                ),

              // 进入录制中心
              _ActionTile(
                icon: Icons.video_library_rounded,
                title: i18n("go_record_center"),
                color: theme.colorScheme.primary,
                onTap: () {
                  Navigator.pop(dialogContext, "page");
                },
              ),

              // 没有任务时：添加监控
              if (!exists)
                _ActionTile(
                  icon: Remix.checkbox_circle_line,
                  title: i18n("add_monitor"),
                  color: theme.colorScheme.primary,
                  onTap: () {
                    Navigator.pop(dialogContext, "monitor");
                  },
                ),

              // 正在录制时：停止录制
              if (isRunning)
                _ActionTile(
                  icon: Icons.stop_circle_outlined,
                  title: i18n("stop_record"),
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(dialogContext, "stop");
                  },
                ),

              // 已存在任务时：移除监控
              if (exists)
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: i18n("remove_monitor"),
                  color: Colors.redAccent,
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
  const _ActionTile({required this.icon, required this.title, required this.color, required this.onTap});

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: onTap,
    );
  }
}
