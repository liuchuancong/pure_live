import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/models/recorder_task_ordering.dart';
import 'package:pure_live/recorder/widgets/recorder_bounded_scroll.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

class RecorderPage extends GetView<RecorderController> {
  const RecorderPage({super.key});

  static const tabs = [
    "recorder_tab_all",
    "recorder_tab_recording",
    "recorder_tab_waiting",
    "recorder_tab_queue",
    "recorder_tab_reconnecting",
    "recorder_tab_processing",
    "recorder_tab_completed",
    "recorder_tab_failed",
    "recorder_tab_stopped",
  ];

  @override
  Widget build(BuildContext context) {
    bool showAction = Get.width <= 680;

    final bool canGoBack = Navigator.of(context).canPop();
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(i18n("recorder_title")),
          centerTitle: true,
          leading: canGoBack ? const BackButton() : (showAction ? const MenuButton() : null),

          actions: [
            IconButton(
              tooltip: i18n("recorder_open_folder"),
              icon: const Icon(Remix.folder_video_line, size: 22),
              onPressed: controller.openFileDir,
            ),
            IconButton(
              tooltip: i18n("settings_title"),
              icon: const Icon(Remix.settings_5_line, size: 22),
              onPressed: () => Get.toNamed(RoutePath.kRecordSettings),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            RecorderStatusSelector(labels: tabs.map(i18n).toList(growable: false)),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
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
      final matchingTasks = filter == null ? controller.tasks : controller.tasks.where(filter!);
      final list = RecorderTaskOrdering.forDisplay(matchingTasks, groupByStatus: filter == null);

      if (list.isEmpty) {
        return const _EmptyView();
      }

      return RecorderBoundedTaskList(
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
        return i18n("recorder_status_recording");

      case RecordStatus.preparing:
        return i18n("recorder_status_preparing");

      case RecordStatus.queued:
        return i18n("recorder_status_queue");

      case RecordStatus.waitingLive:
        return i18n("recorder_status_waiting");

      case RecordStatus.reconnecting:
        return i18n("recorder_status_reconnecting");

      case RecordStatus.processing:
        return i18n("recorder_status_processing");

      case RecordStatus.completed:
        return i18n("recorder_status_completed");

      case RecordStatus.failed:
        return i18n("recorder_status_failed");

      case RecordStatus.stopped:
        return i18n("recorder_status_stopped");
    }
  }

  Color _platformColor() {
    switch (task.platform.toLowerCase()) {
      case Sites.bilibiliSite:
        return const Color(0xFFFB7299);

      case Sites.douyuSite:
        return const Color(0xFFFF7700);

      case Sites.huyaSite:
        return const Color(0xFFFFB000);

      case Sites.douyinSite:
        return const Color(0xFF000000);
      case Sites.ccSite:
        return const Color.fromARGB(253, 13, 145, 233);
      case Sites.iptvSite:
        return const Color.fromARGB(255, 204, 71, 9);
      case Sites.twitchSite:
        return const Color(0xFF9146FF);
      case Sites.soopSite:
        return const Color(0xFF0675E8);
      default:
        return const Color.fromARGB(255, 11, 223, 117);
    }
  }

  String _formatDuration(int sec) {
    final d = Duration(seconds: sec);

    String two(int n) => n.toString().padLeft(2, '0');

    return "${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}";
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 ${i18n("unit_b")}";

    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      return "${(bytes / gb).toStringAsFixed(2)} ${i18n("unit_gb")}";
    }

    if (bytes >= mb) {
      return "${(bytes / mb).toStringAsFixed(2)} ${i18n("unit_mb")}";
    }

    if (bytes >= kb) {
      return "${(bytes / kb).toStringAsFixed(1)} ${i18n("unit_kb")}";
    }

    return "$bytes ${i18n("unit_b")}";
  }

  String _formatBitrate(double kilobitsPerSecond) {
    if (!kilobitsPerSecond.isFinite || kilobitsPerSecond <= 0) return '--';
    if (kilobitsPerSecond >= 1000) return '${(kilobitsPerSecond / 1000).toStringAsFixed(1)} Mbps';
    return '${kilobitsPerSecond.toStringAsFixed(0)} kbps';
  }

  String _failureStageText() {
    final stage = task.lastErrorStage;
    if (stage == 'ffmpeg' || stage?.startsWith('ffmpeg.') == true) {
      return i18n('recorder_stage_ffmpeg');
    }
    return switch (stage) {
      'room' => i18n('recorder_stage_room'),
      'quality' => i18n('recorder_stage_quality'),
      'stream' => i18n('recorder_stage_stream'),
      'network' => i18n('recorder_stage_network'),
      'merge' => i18n('recorder_stage_merge'),
      'scheduler' => i18n('recorder_stage_scheduler'),
      'status' => i18n('recorder_stage_status'),
      'background' => i18n('recorder_stage_background'),
      _ => i18n('recorder_stage_unknown'),
    };
  }

  Widget _buildCoverImage(Color statusColor) {
    final coverUrl = normalizeNetworkImageUrl(task.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          SizedBox(
            width: 150,
            height: 90,
            child: coverUrl.isEmpty
                ? const ColoredBox(color: Colors.black12)
                : CachedNetworkImage(
                    imageUrl: coverUrl,
                    cacheKey: coverUrl,
                    cacheManager: CustomImageCacheManager.instance,
                    httpHeaders: networkImageHeaders(coverUrl),
                    fit: BoxFit.cover,

                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    errorWidget: (_, _, _) => const ColoredBox(color: Colors.black12),
                  ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
                  ),
                  child: Text(
                    _statusText(),
                    style: AppTextStyles.t12.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
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
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.t11.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
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
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w600, color: c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final theme = Get.theme;

    final primaryStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      minimumSize: const Size(0, kMinInteractiveDimension),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w700),
    );

    final outlineStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      minimumSize: const Size(0, kMinInteractiveDimension),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      textStyle: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w700),
    );

    final dangerStyle = FilledButton.styleFrom(
      backgroundColor: Colors.redAccent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      minimumSize: const Size(0, kMinInteractiveDimension),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w700),
    );

    Widget deleteButton() {
      return _RemoveMonitorButton(task: task, controller: controller);
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
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 6,
        runSpacing: 4,
        children: [
          deleteButton(),
          FilledButton(
            style: dangerStyle,
            onPressed: () => controller.stopTask(task),
            child: Text(i18n("recorder_stop")),
          ),
        ],
      );
    }

    if (task.status == RecordStatus.queued) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 6,
        runSpacing: 4,
        children: [
          deleteButton(),
          FilledButton(
            style: primaryStyle,
            onPressed: () => controller.forceStartTask(task),
            child: Text(i18n("recorder_start")),
          ),
          OutlinedButton(style: outlineStyle, onPressed: () => controller.stopTask(task), child: Text(i18n("cancel"))),
        ],
      );
    }

    if (canRestart.contains(task.status)) {
      String text = i18n("recorder_start");

      switch (task.status) {
        case RecordStatus.failed:
          text = i18n("retry");
          break;

        case RecordStatus.waitingLive:
          text = i18n("recorder_check_now");
          break;

        case RecordStatus.completed:
          text = i18n("recorder_restart_record");
          break;

        default:
          break;
      }

      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 6,
        runSpacing: 4,
        children: [
          deleteButton(),
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
    final audienceLabelKey = switch (task.audienceMetricType) {
      AudienceMetricType.popularity => 'audience_popularity',
      AudienceMetricType.onlineViewers => 'audience_online',
      AudienceMetricType.totalViewers => 'audience_total',
      AudienceMetricType.followers => 'audience_followers',
      AudienceMetricType.unknown => 'audience_count',
    };
    final audienceIcon = switch (task.audienceMetricType) {
      AudienceMetricType.popularity => Icons.whatshot_rounded,
      AudienceMetricType.onlineViewers => Icons.people_alt_rounded,
      AudienceMetricType.totalViewers => Icons.visibility_rounded,
      AudienceMetricType.followers => Icons.favorite_rounded,
      AudienceMetricType.unknown => Icons.people_alt_rounded,
    };
    final audienceText = '${i18n(audienceLabelKey)} ${readableCount(task.watching)}';

    final showRecordingStats =
        const <RecordStatus>{
          RecordStatus.running,
          RecordStatus.reconnecting,
          RecordStatus.processing,
          RecordStatus.preparing,
        }.contains(task.status) ||
        task.recordedSeconds > 0 ||
        task.fileSize > 0;
    final isTransitioning = {RecordStatus.reconnecting, RecordStatus.preparing}.contains(task.status);

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
              audienceMetricType: task.audienceMetricType,
              liveStatus: task.liveStatus,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.1),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: normalizeNetworkImageUrl(task.avatar).isNotEmpty
                                ? NetworkImage(normalizeNetworkImageUrl(task.avatar))
                                : null,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              task.nick,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.t14.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _Tag(text: task.platform.toUpperCase(), icon: Remix.plant_fill, color: _platformColor()),
                          _miniInfo(Icons.high_quality_rounded, task.selectedQuality ?? i18n("recorder_auto"), theme),
                          if (task.selectedLine?.isNotEmpty == true)
                            _miniInfo(Icons.alt_route_rounded, task.selectedLine!, theme),
                          _miniInfo(audienceIcon, audienceText, theme),
                        ],
                      ),
                    ],
                  );
                  // Keep metadata readable instead of squeezing it beside a
                  // fixed-width cover on phones or with enlarged text.
                  final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
                  if (constraints.maxWidth < 480 * textScale) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_buildCoverImage(color), const SizedBox(height: 12), details],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCoverImage(color),
                      const SizedBox(width: 14),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
              if (showRecordingStats) ...[
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
                          _statItem(theme, Icons.graphic_eq_rounded, _formatBitrate(task.bitrate)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isTransitioning) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.14)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync_rounded, size: 17, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusText(),
                          style: AppTextStyles.t12.copyWith(color: color, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (task.inputTailDiscarded || task.inputCoverageIncomplete) ...[
                const SizedBox(height: 12),
                Container(
                  key: ValueKey(
                    task.inputCoverageIncomplete ? 'recorder-input-coverage-warning' : 'recorder-input-tail-warning',
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 17, color: theme.colorScheme.onTertiaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            if (task.inputCoverageIncomplete) i18n('recorder_input_coverage_incomplete'),
                            if (task.inputTailDiscarded) i18n('recorder_input_tail_discarded'),
                          ].join('\n'),
                          style: AppTextStyles.t12.copyWith(color: theme.colorScheme.onTertiaryContainer, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (task.lastError?.isNotEmpty == true && task.status != RecordStatus.running) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 17, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          i18n('recorder_last_error', args: {'stage': _failureStageText(), 'error': task.lastError!}),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.t12.copyWith(color: theme.colorScheme.onErrorContainer, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _miniInfo(Icons.schedule_rounded, task.displayStartTime.toString().substring(5, 16), theme),
                    _buildActionButton(),
                  ],
                ),
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
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.t11.copyWith(fontWeight: FontWeight.bold, color: color, letterSpacing: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoveMonitorButton extends StatefulWidget {
  const _RemoveMonitorButton({required this.task, required this.controller});

  final LiveRecordTask task;
  final RecorderController controller;

  @override
  State<_RemoveMonitorButton> createState() => _RemoveMonitorButtonState();
}

class _RemoveMonitorButtonState extends State<_RemoveMonitorButton> {
  bool _busy = false;

  String _displayName(LiveRecordTask task) {
    for (final value in [task.title, task.nick, task.roomId]) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '--';
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);
    final target = widget.task;
    try {
      final ok = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: Text(i18n('recorder_cancel_monitor')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(i18n('recorder_cancel_monitor_confirm_named', args: {'name': _displayName(target)})),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(i18n('cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(i18n('confirm')),
            ),
          ],
        ),
      );
      if (ok == true) await widget.controller.unRecorder(target);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _busy ? null : _remove,
      child: Text(i18n('remove'), style: AppTextStyles.t15.copyWith(color: _busy ? null : Colors.red)),
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
            i18n("recorder_empty_title"),
            style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            i18n("recorder_empty_subtitle"),
            style: AppTextStyles.t13.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
