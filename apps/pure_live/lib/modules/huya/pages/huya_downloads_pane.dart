import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/huya/controller/huya_downloads.dart';
import 'package:pure_live/shared/shared.dart'
    show
        DownloadDetails,
        DownloadRowActions,
        DownloadRowMenuActions,
        DownloadRowPhase,
        DownloadTaskCard,
        formatDownloadBytes;
import 'package:pure_live/shared/widgets/download_details.dart' show showDownloadDetails;

/// 虎牙下载 — the station's video download queue under Settings.
///
/// The pane carries the whole queue as the same rows the station's own 下载
/// 管理 page wears — one shared download card to a video — and the folder the
/// files land in. The player page's own progress pill reaches the same tasks;
/// the full manager lives at the station's own rail page, this pane is the
/// settings' window onto it.
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
              DsListRow(title: Text(t.settings.downloadQueueEmpty), description: Text(t.huya.downloadQueueEmptyDesc))
            else
              for (final task in tasks) huyaTaskCard(context, ref, task, missing: huyaFileMissing(task)),
          ],
        ),
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.folderOpen),
              title: Text(t.settings.downloadDirectory),
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

/// Whether a finished video's file is still on disk where its row says: one
/// stat per row, never a folder walk.
bool huyaFileMissing(HuyaDownloadItem task) =>
    task.phase == HuyaDownloadPhase.done && !File(task.filePath).existsSync();

/// One video's row, as the shared download row draws it — the state as a
/// badge, the transfer's facts under it, the phase's verb and the menu with
/// the rest, the same shape every manager's queue wears.
Widget huyaTaskCard(BuildContext context, WidgetRef ref, HuyaDownloadItem task, {required bool missing}) {
  final t = context.t;
  final notifier = ref.read(huyaDownloadsProvider.notifier);
  final fraction = task.progress;
  final moving = task.phase == HuyaDownloadPhase.running || task.phase == HuyaDownloadPhase.queued;
  final phase = switch (task.phase) {
    HuyaDownloadPhase.running => DownloadRowPhase.running,
    HuyaDownloadPhase.queued => DownloadRowPhase.queued,
    HuyaDownloadPhase.paused => DownloadRowPhase.paused,
    HuyaDownloadPhase.failed => DownloadRowPhase.failed,
    HuyaDownloadPhase.done => missing ? DownloadRowPhase.missing : DownloadRowPhase.done,
  };
  // The badge carries the state; the caption carries the transfer's facts —
  // a failed row its error — so one fact is said once.
  final caption = switch (phase) {
    DownloadRowPhase.running => [
      if (fraction != null) '${(fraction * 100).round()}%',
      if (task.speed > 0) t.common.downloadSpeed(speed: '${formatDownloadBytes(task.speed)}/s'),
    ].join(' · '),
    DownloadRowPhase.done => task.total > 0 ? formatDownloadBytes(task.total) : t.settings.downloadStatusDone,
    DownloadRowPhase.failed => task.error == null ? t.settings.downloadStatusFailed : '${task.error}',
    _ => task.received > 0 ? formatDownloadBytes(task.received) : '',
  };
  return DownloadTaskCard(
    key: ValueKey(task.videoId),
    title: task.title,
    phase: phase,
    caption: caption,
    badgeLabel: task.phase == HuyaDownloadPhase.running && fraction != null
        ? t.settings.downloadPercent(percent: '${(fraction * 100).round()}')
        : null,
    fraction: fraction,
    showProgress: moving && (fraction != null || task.received > 0),
    progressLabel: task.fileName,
    leading: task.cover.isEmpty
        ? null
        : DsAvatar(
            initials: task.title.characters.take(2).toString(),
            image: NetworkImage(task.cover),
            size: DsSize.md,
            semanticLabel: task.title,
          ),
    playable: task.phase == HuyaDownloadPhase.done,
    actions: DownloadRowActions(
      onPause: task.phase == HuyaDownloadPhase.running ? () => unawaited(notifier.pause(task.videoId)) : null,
      onResume: task.phase == HuyaDownloadPhase.queued || task.phase == HuyaDownloadPhase.paused
          ? () => unawaited(notifier.resume(task.videoId))
          : null,
      onRetry: task.phase == HuyaDownloadPhase.failed ? () => unawaited(notifier.resume(task.videoId)) : null,
      onOpenFile: task.phase == HuyaDownloadPhase.done && !missing
          ? () => unawaited(openDownloadedPath(context, task.filePath))
          : null,
    ),
    menu: DownloadRowMenuActions(
      onDetails: () => unawaited(showDownloadDetails(context, huyaDetailsOf(context, ref, task, missing: missing))),
      onRemove: () => unawaited(notifier.remove(task.videoId)),
      missing: missing,
      onOpenFile: task.phase == HuyaDownloadPhase.done && !missing
          ? () => unawaited(openDownloadedPath(context, task.filePath))
          : null,
      onOpenFolder: task.phase == HuyaDownloadPhase.done
          ? () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path))
          : null,
      onDeleteFile: task.phase == HuyaDownloadPhase.done && !missing
          ? () => unawaited(notifier.remove(task.videoId, deleteFile: true))
          : null,
    ),
  );
}

/// The facts the details sheet shows for one video.
DownloadDetails huyaDetailsOf(BuildContext context, WidgetRef ref, HuyaDownloadItem task, {required bool missing}) {
  final t = context.t;
  return DownloadDetails(
    title: task.title,
    coverUrl: task.cover,
    status: switch (task.phase) {
      HuyaDownloadPhase.queued => t.settings.downloadStatusQueued,
      HuyaDownloadPhase.running =>
        task.progress == null ? t.settings.downloadPercentUnknown : t.settings.downloadPercent(percent: '${(task.progress! * 100).round()}'),
      HuyaDownloadPhase.paused => t.settings.downloadStatusPaused,
      HuyaDownloadPhase.failed => task.error == null ? t.settings.downloadStatusFailed : '${task.error}',
      HuyaDownloadPhase.done => missing ? t.common.previewFileMissing : t.settings.downloadStatusDone,
    },
    savePath: task.filePath,
    error: task.error ?? '',
    fileMissing: missing,
    onRemove: () => unawaited(ref.read(huyaDownloadsProvider.notifier).remove(task.videoId)),
  );
}
