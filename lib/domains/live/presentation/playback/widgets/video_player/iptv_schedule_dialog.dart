import 'dart:async';

import 'package:remixicon/remixicon.dart';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/iptv/data/local/database.dart' as database;
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/iptv_programme_policy.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/video_controller.dart';

class IptvScheduleDialogContent extends StatefulWidget {
  const IptvScheduleDialogContent({super.key, required this.controller, this.now, this.onClose});

  final VideoController controller;
  final DateTime Function()? now;
  final VoidCallback? onClose;

  @override
  State<IptvScheduleDialogContent> createState() => _IptvScheduleDialogContentState();
}

class _IptvScheduleDialogContentState extends State<IptvScheduleDialogContent> {
  Timer? _clockTimer;

  VideoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.hasScrolledToLive = false;
    if (widget.now == null) {
      _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final dialogWidth = screenSize.width > 600 ? 460.0 : screenSize.width * 0.88;
    final dialogHeight = screenSize.height <= 600 || textScale > 1.5
        ? screenSize.height * 0.92
        : screenSize.height > 800
        ? 550.0
        : screenSize.height * 0.65;

    return Container(
      width: dialogWidth,
      height: dialogHeight,
      decoration: BoxDecoration(color: theme.dialogTheme.backgroundColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _ScheduleHeader(theme: theme, onClose: _close),
          const Divider(height: 1, thickness: 0.5),
          if (controller.room.isCatchUpActive)
            Obx(() {
              final switching = controller.catchUpSwitching.value;
              return _ReturnToLiveAction(
                enabled: !switching,
                switching: switching,
                onPressed: () => unawaited(controller.returnToLive(closeSchedule: _close)),
              );
            }),
          Expanded(child: Obx(() => _buildBody(context, theme))),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    if (controller.scheduleLoading.value) {
      return const Center(child: CircularProgressIndicator(key: ValueKey('iptv-schedule-loading')));
    }
    if (controller.scheduleLoadFailed.value) {
      return _ScheduleStatus(
        icon: Remix.error_warning_line,
        iconColor: theme.colorScheme.error,
        message: i18n('load_failed'),
        action: FilledButton.icon(
          key: const ValueKey('iptv-schedule-retry'),
          onPressed: () => unawaited(controller.loadFullChannelSchedule(controller.room.epgId)),
          icon: const Icon(Remix.refresh_line),
          label: Text(i18n('retry')),
        ),
      );
    }
    if (controller.currentChannelSchedule.isEmpty) {
      return _ScheduleStatus(
        icon: Remix.inbox_line,
        iconColor: theme.hintColor.withValues(alpha: 0.4),
        message: i18n('no_upcoming_programs'),
      );
    }

    final now = widget.now?.call() ?? DateTime.now();
    final playbackTime = controller.room.catchUpStart != null
        ? DateTime.fromMillisecondsSinceEpoch(controller.room.catchUpStart!)
        : now;
    final switching = controller.catchUpSwitching.value;
    final dialogWidth = MediaQuery.sizeOf(context).width > 600 ? 460.0 : MediaQuery.sizeOf(context).width * 0.88;
    final tileWidth = dialogWidth - 32;
    final scaledBody = MediaQuery.textScalerOf(context).scale(14);
    final stacked = tileWidth < 340 || scaledBody > 22;
    final scaledExtent = scaledBody * (stacked ? 8.5 : 5);
    final itemExtent = scaledExtent < (stacked ? 120 : 84) ? (stacked ? 120.0 : 84.0) : scaledExtent;
    final liveIndex = controller.currentChannelSchedule.indexWhere((programme) {
      return classifyIptvProgramme(
            start: programme.start.toLocal(),
            stop: programme.stop.toLocal(),
            now: playbackTime,
          ) ==
          IptvProgrammePhase.live;
    });
    _scheduleInitialScroll(liveIndex, itemExtent);

    return Stack(
      children: [
        ListView.builder(
          controller: controller.scheduleScrollController,
          itemExtent: itemExtent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const PureLiveScrollPhysics(),
          itemCount: controller.currentChannelSchedule.length,
          itemBuilder: (context, index) {
            final programme = controller.currentChannelSchedule[index];
            final phase = classifyIptvProgramme(
              start: programme.start.toLocal(),
              stop: programme.stop.toLocal(),
              now: now,
            );
            final catchupAvailable =
                phase != IptvProgrammePhase.catchup ||
                evaluateIptvCatchupAvailability(
                      programmeStop: programme.stop.toLocal(),
                      now: now,
                      mode: controller.room.catchUpMode,
                      source: controller.room.catchUpSource,
                      days: controller.room.catchUpDays,
                      catchupId: programme.catchupId,
                    ) ==
                    IptvCatchupAvailability.available;
            return _ProgrammeTile(
              key: ValueKey('iptv-programme-$index'),
              programme: programme,
              isCurrent: index == liveIndex,
              phase: phase,
              catchupAvailable: catchupAvailable,
              enabled: !switching && catchupAvailable,
              onTap: () {
                unawaited(controller.onProgrammeTapped(programme, closeSchedule: _close));
              },
            );
          },
        ),
        if (switching)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(key: ValueKey('iptv-catchup-switch-progress'), minHeight: 2),
          ),
      ],
    );
  }

  void _scheduleInitialScroll(int liveIndex, double itemExtent) {
    if (!controller.claimInitialScheduleScroll(liveIndex)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller.status == PlayerStatus.disposed || !controller.scheduleScrollController.hasClients) {
        return;
      }
      final position = controller.scheduleScrollController.position;
      final target = (12 + liveIndex * itemExtent).clamp(0.0, position.maxScrollExtent).toDouble();
      controller.scheduleScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _close() {
    final close = widget.onClose;
    if (close != null) {
      close();
      return;
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }
}

class _ReturnToLiveAction extends StatelessWidget {
  const _ReturnToLiveAction({required this.enabled, required this.switching, required this.onPressed});

  final bool enabled;
  final bool switching;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('iptv-return-to-live'),
          onPressed: enabled ? onPressed : null,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (switching)
                const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Remix.live_line, size: 18),
              Text(i18n('return_to_live'), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({required this.theme, required this.onClose});

  final ThemeData theme;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      i18n('channel_schedule'),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w700, color: theme.textTheme.titleLarge?.color),
    );
    final close = IconButton(
      key: const ValueKey('iptv-schedule-close'),
      onPressed: onClose,
      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      icon: const Icon(Remix.close_line, size: 20),
      color: theme.hintColor,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledTitle = MediaQuery.textScalerOf(context).scale(15);
        if (constraints.maxWidth < 340 && scaledTitle > 24) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerRight, child: close),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: title),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8, left: 20, right: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(Remix.calendar_todo_line, size: 22, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: title),
              ),
              close,
            ],
          ),
        );
      },
    );
  }
}

class _ScheduleStatus extends StatelessWidget {
  const _ScheduleStatus({required this.icon, required this.iconColor, required this.message, this.action});

  final IconData icon;
  final Color iconColor;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.t13.copyWith(color: Theme.of(context).hintColor),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _ProgrammeTile extends StatelessWidget {
  const _ProgrammeTile({
    super.key,
    required this.programme,
    required this.isCurrent,
    required this.phase,
    required this.catchupAvailable,
    required this.enabled,
    required this.onTap,
  });

  final database.EpgProgramme programme;
  final bool isCurrent;
  final IptvProgrammePhase phase;
  final bool catchupAvailable;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final time = programme.start.toLocal();
    final timeChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent ? primary.withValues(alpha: 0.1) : theme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        style: AppTextStyles.t13.copyWith(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          color: isCurrent ? primary : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.65),
        ),
      ),
    );
    final title = Text(
      programme.title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.t14.copyWith(
        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        color: isCurrent ? primary : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
      ),
    );
    final status = switch (phase) {
      IptvProgrammePhase.live => _LiveTag(color: primary),
      IptvProgrammePhase.catchup when !catchupAvailable => Tooltip(
        message: i18n('catchup_unavailable'),
        child: Icon(Remix.history_line, size: 16, color: theme.disabledColor),
      ),
      IptvProgrammePhase.catchup => Icon(Remix.history_line, size: 16, color: theme.hintColor.withValues(alpha: 0.6)),
      IptvProgrammePhase.scheduled => const SizedBox.shrink(),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isCurrent ? primary.withValues(alpha: 0.06) : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isCurrent ? primary.withValues(alpha: 0.15) : Colors.transparent),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaledBody = MediaQuery.textScalerOf(context).scale(14);
              final stacked = constraints.maxWidth < 340 || scaledBody > 22;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [timeChip, status],
                          ),
                          const SizedBox(height: 8),
                          title,
                        ],
                      )
                    : Row(
                        children: [
                          timeChip,
                          const SizedBox(width: 12),
                          Expanded(child: title),
                          const SizedBox(width: 8),
                          status,
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LiveTag extends StatelessWidget {
  const _LiveTag({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Remix.live_line, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            i18n('live_tag'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
