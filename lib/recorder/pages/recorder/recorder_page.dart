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
              icon: const Icon(Icons.history_rounded, size: 22),
              onPressed: () {
                controller.openFileDir();
              },
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

            /// 录制中
            _TaskList(filter: (e) => e.status == RecordStatus.running),

            /// 等待开播
            _TaskList(filter: (e) => e.status == RecordStatus.waitingLive),

            /// 排队中
            _TaskList(filter: (e) => e.status == RecordStatus.queued),

            /// 重连中
            _TaskList(filter: (e) => e.status == RecordStatus.reconnecting),

            /// 处理中
            _TaskList(filter: (e) => e.status == RecordStatus.processing),

            /// 已完成
            _TaskList(filter: (e) => e.status == RecordStatus.completed),

            /// 失败
            _TaskList(filter: (e) => e.status == RecordStatus.failed),

            /// 已停止
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

      // 无论桌面还是移动端，统一使用灵活适配的垂直列表
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: list.length,
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
        return "视频处理中";

      case RecordStatus.completed:
        return "已完成";

      case RecordStatus.failed:
        return "失败";

      case RecordStatus.stopped:
        return "已停止";
    }
  }

  Widget _buildActionButton() {
    final theme = Get.theme;

    final smallButtonStyle = FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );

    final deleteButtonStyle = OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.8)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );

    /// 正在运行中的状态
    final isWorking = {RecordStatus.running, RecordStatus.reconnecting, RecordStatus.preparing};

    /// 可重新启动的状态
    final canRestart = {
      RecordStatus.failed,
      RecordStatus.stopped,
      RecordStatus.waitingLive,
      RecordStatus.completed,
      RecordStatus.processing,
    };

    /// 删除按钮
    Widget deleteButton() {
      return OutlinedButton(
        style: deleteButtonStyle,
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: Get.context!,
            builder: (context) => AlertDialog(
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
            ),
          );

          if (ok == true) {
            await controller.unRecorder(task);
          }
        },
        child: const Text("删除"),
      );
    }

    /// 正在录制
    if (isWorking.contains(task.status)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          deleteButton(),
          const SizedBox(width: 6),

          FilledButton(
            style: smallButtonStyle.copyWith(backgroundColor: WidgetStateProperty.all(Colors.redAccent)),
            onPressed: () => controller.stopTask(task),
            child: const Text("停止"),
          ),
        ],
      );
    }

    /// 排队中
    if (task.status == RecordStatus.queued) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          deleteButton(),
          const SizedBox(width: 6),

          FilledButton(
            style: smallButtonStyle.copyWith(backgroundColor: WidgetStateProperty.all(theme.colorScheme.tertiary)),
            onPressed: () => controller.stopTask(task),
            child: const Text("取消"),
          ),
        ],
      );
    }

    /// 可重新启动
    if (canRestart.contains(task.status)) {
      String text;

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
          text = "启动";
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          deleteButton(),
          const SizedBox(width: 6),
          FilledButton(style: smallButtonStyle, onPressed: () => controller.startTask(task), child: Text(text)),
        ],
      );
    }

    return const SizedBox.shrink();
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
    if (bytes >= gb) return "${(bytes / gb).toStringAsFixed(2)} GB";
    if (bytes >= mb) return "${(bytes / mb).toStringAsFixed(2)} MB";
    if (bytes >= kb) return "${(bytes / kb).toStringAsFixed(1)} KB";
    return "$bytes B";
  }

  // 更紧凑的封面图（尺寸缩小，与迅雷下载项类似）
  Widget _buildCoverImage(Color statusColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72, // 缩小宽度
        height: 44, // 缩小高度
        decoration: BoxDecoration(
          image: DecorationImage(image: NetworkImage(task.cover), fit: BoxFit.cover),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusText(),
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _statItem(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? Colors.grey.shade700),
        const SizedBox(width: 3),
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
    final isRecording = [RecordStatus.running, RecordStatus.reconnecting, RecordStatus.preparing].contains(task.status);

    return Container(
      key: ValueKey(task.taskId),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：封面 + 标题/主播/状态标签
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCoverImage(color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundImage: task.avatar.isNotEmpty ? NetworkImage(task.avatar) : null,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                task.nick,
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                              ),
                            ),
                            _Tag(text: task.platform.toUpperCase(), small: true, icon: Remix.plant_fill),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _miniInfo(Icons.high_quality_rounded, task.selectedQuality ?? "自动"),
                            const SizedBox(width: 12),
                            _miniInfo(Icons.people_alt_rounded, readableCount(task.watching)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 录制中面板（进度条+统计）
              if (isRecording) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          color: Colors.green, // 迅雷绿
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
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

              const SizedBox(height: 10),

              // 底部：时间 + 操作按钮
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(
                    task.createTime.toString().substring(5, 16),
                    style: TextStyle(color: theme.hintColor, fontSize: 11),
                  ),
                  const Spacer(),
                  Builder(builder: (context) => _buildActionButton()),
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
  final bool small;

  const _Tag({required this.text, this.small = false, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 7, vertical: small ? 1 : 3),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(small ? 6 : 8),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 10 : 12, color: primaryColor.withValues(alpha: 0.8)),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: small ? 9 : 11,
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
