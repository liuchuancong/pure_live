import 'dart:ui';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

class RecorderPage extends GetView<RecorderController> {
  const RecorderPage({super.key});

  static const tabs = ["全部", "录制中", "等待开播", "排队中", "重连中", "处理中", "已完成", "失败", "已停止"];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text("录制中心", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: "打开文件夹",
              icon: const Icon(Icons.folder_rounded, size: 22),
              onPressed: controller.openFileDir,
            ),
            IconButton(
              tooltip: "设置",
              icon: const Icon(Icons.settings_suggest_rounded, size: 22),
              onPressed: () => Get.toNamed(RoutePath.kRecordSettings),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(54),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: tabs
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Tab(text: e),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
        body: TabBarView(
          physics: const BouncingScrollPhysics(),
          children: [
            _TaskList(filter: null),
            _TaskList(filter: (e) => e.status == RecordStatus.running),
            _TaskList(filter: (e) => e.status == RecordStatus.waitingLive),
            _TaskList(filter: (e) => e.status == RecordStatus.queued),
            _TaskList(filter: (e) => e.status == RecordStatus.reconnecting),
            _TaskList(filter: (e) => e.status == RecordStatus.processing),
            _TaskList(filter: (e) => e.status == RecordStatus.completed),
            _TaskList(filter: (e) => e.status == RecordStatus.failed),
            _TaskList(filter: (e) => e.status == RecordStatus.stopped),
          ],
        ),
      ),
    );
  }
}

class _TaskList extends GetView<RecorderController> {
  const _TaskList({this.filter});

  final bool Function(LiveRecordTask task)? filter;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      List<LiveRecordTask> list = controller.tasks;

      if (filter != null) {
        list = list.where(filter!).toList();
      }

      if (list.isEmpty) {
        return const _EmptyView();
      }

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: list.length,
        itemBuilder: (_, i) {
          return _TaskCard(key: ValueKey(list[i].taskId), task: list[i]);
        },
      );
    });
  }
}

class _TaskCard extends GetView<RecorderController> {
  const _TaskCard({super.key, required this.task});

  final LiveRecordTask task;

  Color _statusColor() {
    switch (task.status) {
      case RecordStatus.running:
        return Colors.green;

      case RecordStatus.preparing:
        return Colors.amber;

      case RecordStatus.queued:
        return Colors.deepPurple;

      case RecordStatus.waitingLive:
        return Colors.orangeAccent;

      case RecordStatus.reconnecting:
        return Colors.orange;

      case RecordStatus.processing:
        return Colors.cyan;

      case RecordStatus.completed:
        return Colors.blue;

      case RecordStatus.failed:
        return Colors.red;

      case RecordStatus.stopped:
        return Colors.grey;
    }
  }

  String _statusText() {
    switch (task.status) {
      case RecordStatus.running:
        return "录制中";

      case RecordStatus.preparing:
        return "准备中";

      case RecordStatus.queued:
        return "排队中";

      case RecordStatus.waitingLive:
        return "等待开播";

      case RecordStatus.reconnecting:
        return "重连中";

      case RecordStatus.processing:
        return "处理中";

      case RecordStatus.completed:
        return "已完成";

      case RecordStatus.failed:
        return "失败";

      case RecordStatus.stopped:
        return "已停止";
    }
  }

  Color _platformColor() {
    switch (task.platform.toLowerCase()) {
      case 'bilibili':
        return const Color(0xFFFB7299);

      case 'douyu':
        return const Color(0xFFFF7700);

      case 'huya':
        return const Color(0xFFFFB000);

      case 'twitch':
        return const Color(0xFF9146FF);

      default:
        return Get.theme.colorScheme.primary;
    }
  }

  String _formatDuration(int sec) {
    final d = Duration(seconds: sec);

    String two(int n) => n.toString().padLeft(2, '0');

    return "${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}";
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";

    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      return "${(bytes / gb).toStringAsFixed(2)} GB";
    }

    if (bytes >= mb) {
      return "${(bytes / mb).toStringAsFixed(2)} MB";
    }

    if (bytes >= kb) {
      return "${(bytes / kb).toStringAsFixed(1)} KB";
    }

    return "$bytes B";
  }

  Widget _buildCoverImage(Color statusColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Container(
            width: 150,
            height: 90,
            decoration: BoxDecoration(
              image: DecorationImage(image: NetworkImage(task.cover), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), // 模糊背景
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    // 背景色稍深，增加对比度
                    color: statusColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
                  ),
                  child: Text(
                    _statusText(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _statItem(ThemeData theme, IconData icon, String label, {Color? color}) {
    final c = color ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final theme = Get.theme;

    final primaryStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      minimumSize: const Size(0, 34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    );

    final outlineStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      minimumSize: const Size(0, 34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    );

    final dangerStyle = FilledButton.styleFrom(
      backgroundColor: Colors.redAccent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      minimumSize: const Size(0, 34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    );

    Widget deleteButton() {
      return TextButton(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: Get.context!,
            builder: (context) {
              return AlertDialog(
                title: const Text("取消监控"),
                content: const Text("确定不再监控该直播间？"),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("取消")),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text("确定"),
                  ),
                ],
              );
            },
          );

          if (ok == true) {
            await controller.unRecorder(task);
          }
        },
        child: const Text("删除", style: TextStyle(color: Colors.red)),
      );
    }

    final isWorking = {RecordStatus.running, RecordStatus.reconnecting, RecordStatus.preparing};

    final canRestart = {
      RecordStatus.failed,
      RecordStatus.stopped,
      RecordStatus.waitingLive,
      RecordStatus.completed,
      RecordStatus.processing,
    };

    if (isWorking.contains(task.status)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          deleteButton(),
          const SizedBox(width: 6),
          FilledButton(style: dangerStyle, onPressed: () => controller.stopTask(task), child: const Text("停止")),
        ],
      );
    }

    if (task.status == RecordStatus.queued) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          deleteButton(),
          const SizedBox(width: 6),
          FilledButton(style: primaryStyle, onPressed: () => controller.forceStartTask(task), child: const Text("启动")),
          const SizedBox(width: 6),
          OutlinedButton(style: outlineStyle, onPressed: () => controller.stopTask(task), child: const Text("取消")),
        ],
      );
    }

    if (canRestart.contains(task.status)) {
      String text = "启动";

      switch (task.status) {
        case RecordStatus.failed:
          text = "重试";
          break;

        case RecordStatus.waitingLive:
          text = "立即检测";
          break;

        case RecordStatus.completed:
          text = "重新录制";
          break;

        default:
          break;
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          deleteButton(),
          const SizedBox(width: 6),
          FilledButton(style: primaryStyle, onPressed: () => controller.forceStartTask(task), child: Text(text)),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = _statusColor();

    final isRecording = [RecordStatus.running, RecordStatus.reconnecting, RecordStatus.preparing].contains(task.status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          AppNavigator.toLiveRoomDetail(
            liveRoom: LiveRoom(
              roomId: task.roomId,
              platform: task.platform,
              title: task.title,
              nick: task.nick,
              avatar: task.avatar,
              cover: task.cover,
              watching: task.watching,
              followers: task.followers,
              liveStatus: task.liveStatus,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCoverImage(color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            height: 1.2,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: task.avatar.isNotEmpty ? NetworkImage(task.avatar) : null,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                task.nick,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            _Tag(text: task.platform.toUpperCase(), icon: Remix.plant_fill, color: _platformColor()),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            _miniInfo(Icons.high_quality_rounded, task.selectedQuality ?? "自动", theme),
                            _miniInfo(Icons.people_alt_rounded, readableCount(task.watching), theme),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isRecording) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          _statItem(theme, Icons.timer_outlined, _formatDuration(task.recordedSeconds)),
                          _statItem(theme, Icons.storage_rounded, _formatFileSize(task.fileSize)),
                          _statItem(theme, Icons.speed_rounded, "${task.recordSpeed.toStringAsFixed(1)}x"),
                          _statItem(theme, Icons.graphic_eq_rounded, "${task.bitrate ~/ 1000}M"),
                          if (task.isStalled)
                            _statItem(theme, Icons.warning_amber_rounded, "流卡住", color: theme.colorScheme.error),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    task.createTime.toString().substring(5, 16),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  _buildActionButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Tag({required this.text, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(Icons.video_collection_outlined, size: 42, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            "暂无录制任务",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text("添加直播间后将在这里显示", style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
