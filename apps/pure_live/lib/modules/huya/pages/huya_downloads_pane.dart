import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/huya/controller/huya_downloads.dart';
import 'package:pure_live/shared/shared.dart' show formatDownloadBytes;

/// 虎牙下载 — the station's video download queue under Settings.
///
/// The pane carries the whole queue: one row per video, the phase's verb on
/// its end (pause a run, resume a paused or failed one, open a finished
/// file), the ⋯ beside it for the rest, and the folder the files land in.
/// The player page's own progress pill reaches the same tasks; this pane is
/// where a viewer manages them after leaving the video.
final class HuyaDownloadsPane extends ConsumerWidget {
  /// The pane shown under Settings.
  const HuyaDownloadsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final tasks = ref.watch(huyaDownloadsProvider);
    final directory = ref.watch(appPathsProvider).videos.path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.huyaDownloadTitle),
          children: [
            if (tasks.isEmpty)
              DsListRow(title: Text(t.vod.downloadEmpty), description: Text(t.vod.downloadEmptyDesc))
            else
              for (final task in tasks) _HuyaTaskRow(task: task),
          ],
        ),
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.folderOpen),
              title: Text(t.vod.downloadDirectory),
              description: Text(directory, maxLines: 2, overflow: TextOverflow.ellipsis),
              showChevron: true,
              onPressed: () => unawaited(openDownloadedPath(context, directory)),
            ),
          ],
        ),
      ],
    );
  }
}

/// One video's row: its name, the phase's caption over the bar it moves, and
/// the phase's verb beside the ⋯ that carries the rest.
final class _HuyaTaskRow extends ConsumerWidget {
  const _HuyaTaskRow({required this.task});

  final HuyaDownloadItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final fraction = task.progress;
    final moving = task.phase == HuyaDownloadPhase.running || task.phase == HuyaDownloadPhase.queued;
    // Asked once per row, never by walking the folder: a finished video the
    // viewer moved elsewhere still plays no part.
    final missing = task.phase == HuyaDownloadPhase.done && !File(task.filePath).existsSync();
    final caption = switch (task.phase) {
      HuyaDownloadPhase.queued => t.vod.downloadPhaseQueued,
      HuyaDownloadPhase.running => switch (fraction) {
        final progress? =>
          '${t.vod.downloading(percent: (progress * 100).round())}'
              ' · ${t.common.downloadSpeed(speed: '${formatDownloadBytes(task.speed)}/s')}',
        null => t.vod.downloadingUnknown,
      },
      HuyaDownloadPhase.paused => t.vod.downloadPhasePaused,
      HuyaDownloadPhase.done => t.vod.downloadPhaseDone,
      HuyaDownloadPhase.failed =>
        task.error == null ? t.vod.downloadPhaseFailed : '${t.vod.downloadPhaseFailed} · ${task.error}',
    };
    return DsListRow(
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          // A failed row carries its error, and a narrow window must not
          // ellipsise the second half away.
          Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (moving && (fraction != null || task.received > 0))
            DsProgressBar(value: fraction, semanticLabel: task.fileName),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _phaseVerb(context, ref, task, missing: missing),
          DsMenuAnchor(
            semanticLabel: t.common.more,
            align: DsAlign.end,
            builder: (context, controller, child) => DsPressable(
              semanticLabel: t.common.more,
              onPressed: controller.toggle,
              builder: (context, states, _) {
                final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                return Padding(
                  padding: const EdgeInsets.all(DsSpace.s4),
                  child: DsIcon(
                    DsIcons.ellipsisVertical,
                    size: theme.sizes.iconSm,
                    color: lit ? colors.text : colors.textSubtle,
                  ),
                );
              },
            ),
            items: _rowMenu(context, ref, task, missing: missing),
          ),
        ],
      ),
    );
  }

  /// The phase's one verb: a run pauses, a stopped one carries on, a
  /// finished one opens.
  Widget _phaseVerb(BuildContext context, WidgetRef ref, HuyaDownloadItem task, {required bool missing}) {
    final t = context.t;
    final notifier = ref.read(huyaDownloadsProvider.notifier);
    return switch (task.phase) {
      HuyaDownloadPhase.running || HuyaDownloadPhase.queued => DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        onPressed: () => unawaited(notifier.pause(task.videoId)),
        child: Text(t.vod.downloadPause),
      ),
      HuyaDownloadPhase.paused => DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        onPressed: () => unawaited(notifier.resume(task.videoId)),
        child: Text(t.vod.downloadResume),
      ),
      HuyaDownloadPhase.failed => DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        onPressed: () => unawaited(notifier.resume(task.videoId)),
        child: Text(t.vod.downloadRetry),
      ),
      HuyaDownloadPhase.done => DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        onPressed: () =>
            unawaited(openDownloadedPath(context, missing ? File(task.filePath).parent.path : task.filePath)),
        child: Text(missing ? t.settings.downloadManagerOpenFolder : t.settings.downloadOpenFile),
      ),
    };
  }

  /// The row's menu: what a finished file can still do (open, delete), and
  /// the removal every row has — the record goes, and a removal that also
  /// deletes the file says so.
  List<Widget> _rowMenu(BuildContext context, WidgetRef ref, HuyaDownloadItem task, {required bool missing}) {
    final t = context.t;
    final notifier = ref.read(huyaDownloadsProvider.notifier);
    return [
      if (task.phase == HuyaDownloadPhase.done && !missing)
        DsMenuItem(
          leading: const DsIcon(DsIcons.externalLink),
          label: Text(t.settings.downloadOpenFile),
          onPressed: () => unawaited(openDownloadedPath(context, task.filePath)),
        ),
      if (task.phase == HuyaDownloadPhase.done)
        DsMenuItem(
          leading: const DsIcon(DsIcons.folderOpen),
          label: Text(t.settings.downloadManagerOpenFolder),
          onPressed: () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path)),
        ),
      if (task.phase == HuyaDownloadPhase.done)
        DsMenuItem(
          leading: const DsIcon(DsIcons.trash2),
          label: Text(missing ? t.common.downloadRemoveFromList : t.vod.downloadDeleteFile),
          destructive: true,
          onPressed: () => unawaited(notifier.remove(task.videoId, deleteFile: !missing)),
        )
      else
        DsMenuItem(
          leading: const DsIcon(DsIcons.trash2),
          label: Text(t.settings.downloadRemove),
          destructive: true,
          onPressed: () => unawaited(notifier.remove(task.videoId)),
        ),
    ];
  }
}
