import 'dart:io';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

class RecorderPage extends GetView<RecorderController> {
  const RecorderPage({super.key});

  static const tabs = ["全部", "录制中", "等待中", "重连中", "已完成", "失败", "已停止"];

  bool get isDesktop => Platform.isWindows || Platform.isMacOS;

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
              tooltip: "历史记录",
              icon: const Icon(Icons.history_rounded, size: 22),
              onPressed: () => Get.toNamed(RoutePath.kRecordHistory),
            ),
            IconButton(
              tooltip: "设置",
              icon: const Icon(Icons.settings_suggest_rounded, size: 22),
              onPressed: () => Get.toNamed(RoutePath.kRecordSettings),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
            tabs: tabs.map((e) => Tab(text: e)).toList(),
          ),
        ),
        body: TabBarView(
          physics: const BouncingScrollPhysics(),
          children: [
            _TaskList(filter: null),
            _TaskList(filter: (e) => e.status == RecordStatus.running),
            _TaskList(
              filter: (e) => [RecordStatus.queued, RecordStatus.preparing, RecordStatus.idle].contains(e.status),
            ),
            _TaskList(filter: (e) => e.status == RecordStatus.reconnecting),
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
      if (filter != null) list = list.where(filter!).toList();
      if (list.isEmpty) return const _EmptyView();

      final isDesktop = Platform.isWindows || Platform.isMacOS;

      return isDesktop
          ? GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 500,
                mainAxisExtent: 300,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => _TaskCard(key: ValueKey(list[i].taskId), task: list[i]),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: list.length,
              key: ValueKey(list.length),
              itemBuilder: (_, i) => _TaskCard(key: ValueKey(list[i].taskId), task: list[i]),
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
      case RecordStatus.reconnecting:
        return Colors.orange;
      case RecordStatus.failed:
        return Colors.red;
      case RecordStatus.completed:
        return Colors.blue;
      case RecordStatus.queued:
        return Colors.deepPurple;
      case RecordStatus.preparing:
        return Colors.amber;
      case RecordStatus.stopped:
        return Colors.grey;
      default:
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
        return "等待中";
      case RecordStatus.reconnecting:
        return "重连中";
      case RecordStatus.completed:
        return "已完成";
      case RecordStatus.failed:
        return "失败";
      case RecordStatus.stopped:
        return "已停止";
      case RecordStatus.processing:
        return "正在合成视频";
      default:
        return "空闲";
    }
  }

  Widget _buildActionButton() {
    final theme = Get.theme;

    switch (task.status) {
      case RecordStatus.running:
      case RecordStatus.reconnecting:
      case RecordStatus.preparing:
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          onPressed: () => controller.stopTask(task),
          child: const Text("停止"),
        );

      case RecordStatus.queued:
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.tertiary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          onPressed: () => controller.stopTask(task),
          child: const Text("取消"),
        );
      case RecordStatus.processing:
      case RecordStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () => Get.toNamed(RoutePath.kRecordHistory), child: const Text("文件")),
            const SizedBox(width: 4),
            FilledButton(
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => controller.startTask(task),
              child: const Text("启动"),
            ),
          ],
        );

      case RecordStatus.failed:
      case RecordStatus.stopped:
      case RecordStatus.idle:
        return FilledButton(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          onPressed: () => controller.startTask(task),
          child: Text(task.status == RecordStatus.failed ? "重试" : "启动"),
        );
    }
  }

  String _formatDuration(int sec) {
    final d = Duration(seconds: sec);
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return "${(bytes / gb).toStringAsFixed(2)} GB";
    if (bytes >= mb) return "${(bytes / mb).toStringAsFixed(2)} MB";
    if (bytes >= kb) return "${(bytes / kb).toStringAsFixed(1)} KB";
    return "$bytes B";
  }

  Widget _buildCoverImage(Color statusColor) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
            ],
            image: DecorationImage(image: NetworkImage(task.cover), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.3), blurRadius: 6)],
            ),
            child: Text(
              _statusText(),
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniInfo(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _statItem(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade700),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color ?? Colors.grey.shade800),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor();

    // 🔥 修复：正确包含所有需要显示实时面板的状态
    final isRecording = [RecordStatus.running, RecordStatus.reconnecting, RecordStatus.preparing].contains(task.status);

    return Container(
      key: ValueKey(task.taskId),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoverImage(color),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundImage: task.avatar.isNotEmpty ? NetworkImage(task.avatar) : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.nick,
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                                ),
                              ),
                              _Tag(text: task.platform.toUpperCase(), small: true, icon: Remix.plant_fill),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _miniInfo(Icons.high_quality_rounded, task.selectedQuality ?? "自动"),
                                const SizedBox(width: 12),
                                _miniInfo(Icons.people_alt_rounded, readableCount(task.watching)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (isRecording) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 18,
                          runSpacing: 8,
                          children: [
                            _statItem(Icons.timer_outlined, _formatDuration(task.recordedSeconds)),
                            _statItem(Icons.storage_rounded, _formatFileSize(task.fileSize)),
                            _statItem(Icons.speed_rounded, "${task.recordSpeed.toStringAsFixed(1)}x"),
                            _statItem(Icons.graphic_eq_rounded, "${task.bitrate ~/ 1000}M"),
                            if (task.isStalled)
                              _statItem(Icons.warning_amber_rounded, "流卡住", color: theme.colorScheme.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Text(
                      task.createTime.toString().substring(5, 16),
                      style: TextStyle(color: theme.hintColor, fontSize: 12),
                    ),
                    const Spacer(),
                    // 按钮自动刷新
                    Builder(builder: (context) => _buildActionButton()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool small;

  const _Tag({required this.text, this.small = false, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(small ? 6 : 8),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 11 : 13, color: primaryColor.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: small ? 10 : 11.5,
              fontWeight: FontWeight.bold,
              color: primaryColor.withValues(alpha: 0.9),
              letterSpacing: 0.2,
            ),
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
          Icon(
            Icons.video_collection_outlined,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 20),
          Text(
            "暂无录制任务",
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
