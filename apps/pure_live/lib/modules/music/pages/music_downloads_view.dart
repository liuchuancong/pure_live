import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart'
    show confirmClearFinished, openDownloadedPath;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_downloads.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_settings.dart' show musicQualityByScriptName;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';

final class MusicDownloadsView extends ConsumerStatefulWidget {
  const MusicDownloadsView({super.key});

  @override
  ConsumerState<MusicDownloadsView> createState() => MusicDownloadsViewState();
}

/// What the queue filter shows; the same three the VOD and hongguo managers
/// offer, so one gesture reads the same across the station pages.
enum _DownloadsFilter {
  all,

  /// Everything still owed a file: queued, running, paused, processing and the
  /// failed ones.
  active,

  /// The files on disk that can be played.
  done;

  String label(Translations t) => switch (this) {
    _DownloadsFilter.all => t.music.downloadFilterAll,
    _DownloadsFilter.active => t.music.downloadFilterActive,
    _DownloadsFilter.done => t.music.downloadFilterDone,
  };
}

/// A task whose file is on disk and playable.
bool _playableTask(audio.MusicDownloadTask task) =>
    task.status == audio.MusicDownloadStatus.completed || task.status == audio.MusicDownloadStatus.skipped;

final class MusicDownloadsViewState extends ConsumerState<MusicDownloadsView> {
  _DownloadsFilter _filter = _DownloadsFilter.all;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final tasks = ref.watch(musicDownloadsProvider);
    final controller = ref.read(musicDownloadsProvider.notifier);
    final directory = ref.watch(appPathsProvider).music.path;
    final pending = tasks.where((task) => !task.isTerminal).toList();
    final finished = tasks.where(_playableTask).toList();
    // The bytes already on disk: a finished task reports its total, one
    // still running contributes nothing yet.
    final finishedBytes = finished.fold<int>(
      0,
      (sum, task) => sum + (task.bytesTotal > 0 ? task.bytesTotal : task.bytesReceived),
    );
    final shown = switch (_filter) {
      _DownloadsFilter.all => tasks,
      _DownloadsFilter.active => tasks.where((task) => !_playableTask(task)).toList(),
      _DownloadsFilter.done => finished,
    };
    if (tasks.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.download),
          title: Text(t.music.downloadsEmptyTitle),
          description: Text(t.music.downloadsEmptyDescription(directory: directory)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    // What the queue has already put on disk, the reference's
                    // line above the folder: the page is a library of files,
                    // not only a task list.
                    if (finishedBytes > 0)
                      Text(
                        t.music.downloadsSummary(count: finished.length, size: _bytesText(finishedBytes)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    Text(
                      directory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                  ],
                ),
              ),
              // The folder every one of these files lands in, one click from
              // the page that lists them — the station managers' own verb.
              DsButton.icon(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                semanticLabel: t.settings.downloadManagerOpenFolder,
                onPressed: () => unawaited(openDownloadedPath(context, directory)),
                icon: const DsIcon(DsIcons.folderOpen, size: 16),
              ),
              if (pending.isNotEmpty)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(controller.pauseAll()),
                  child: Text(t.music.downloadPauseAll),
                ),
              if (tasks.any((task) => task.isPaused))
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(controller.resumeAll()),
                  child: Text(t.music.downloadResumeAll),
                ),
              if (finished.isNotEmpty)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(
                    confirmClearFinished(
                      context,
                      title: t.music.downloadClearFinished,
                      clear: controller.clearFinished,
                    ),
                  ),
                  child: Text(t.music.downloadClearFinished),
                ),
            ],
          ),
        ),
        // The queue's own filter, the station managers' grammar: everything,
        // what is still owed a file, and what is already on disk.
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DsSegmentedControl<_DownloadsFilter>(
                value: _filter,
                onChanged: (filter) => setState(() => _filter = filter),
                semanticLabel: t.navigation.musicDownloads,
                segments: [
                  for (final filter in _DownloadsFilter.values) DsSegment(value: filter, label: Text(filter.label(t))),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.download),
                    title: Text(t.music.downloadFilterEmpty),
                    actions: [
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: () => setState(() => _filter = _DownloadsFilter.all),
                        child: Text(t.music.downloadFilterAll),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: DsSpace.s16),
                  children: [
                    DsListSection(children: [for (final task in shown) _DownloadRow(task: task)]),
                  ],
                ),
        ),
      ],
    );
  }
}

final class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({required this.task});

  final audio.MusicDownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(musicDownloadsProvider.notifier);
    final progress = task.progress;
    final title = task.request.title ?? musicFileNameOf(task.outputPath);
    final artist = task.request.artist ?? '';
    final album = task.request.album ?? '';
    final playable =
        task.status == audio.MusicDownloadStatus.completed || task.status == audio.MusicDownloadStatus.skipped;
    // The art of the row: the downloaded file's own cover once it is on disk,
    // the platform's cover before that — the page shows the songs, not their
    // tasks.
    final preview = _previewTrack(task, local: playable);
    final status = _statusLabel(t, task);
    final facts = [if (artist.isNotEmpty) artist, if (album.isNotEmpty) album, ?_qualityOf(t, task)];
    final detail = [
      status,
      if (progress != null && !task.isTerminal) '${(progress * 100).round()}%',
      if (task.bytesPerSecond > 0 && task.status == audio.MusicDownloadStatus.running)
        '${_bytesText(task.bytesPerSecond)}/s',
      if (playable && task.bytesTotal > 0) _bytesText(task.bytesTotal),
    ].join(' · ');
    return DsListRow(
      leading: MusicArtwork(track: preview),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      // A finished file plays in the module's own player — the preview the
      // download page was missing.
      onPressed: playable ? () => _play(ref) : null,
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          if (facts.isNotEmpty)
            Text(facts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.typography.caption),
          Text(
            task.status == audio.MusicDownloadStatus.failed && task.error != null
                ? '${t.music.downloadStatusFailed} · ${task.error}'
                : detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
          if (!task.isTerminal && progress != null)
            DsProgressBar(value: progress, semanticLabel: t.music.downloadProgress),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [..._actions(context, controller, t, ref), if (playable) _menu(context)],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, MusicDownloadsController controller, Translations t, WidgetRef ref) {
    final status = task.status;
    if (status == audio.MusicDownloadStatus.failed) {
      return [
        _icon(t.music.downloadRetry, DsIcons.refreshCw, () => unawaited(controller.retry(task.id))),
        _icon(t.music.downloadRemove, DsIcons.trash2, () => unawaited(controller.remove(task.id))),
      ];
    }
    if (status == audio.MusicDownloadStatus.paused) {
      return [
        _icon(t.music.downloadResume, DsIcons.play, () => unawaited(controller.resume(task.id))),
        _icon(t.music.downloadRemove, DsIcons.trash2, () => unawaited(controller.remove(task.id))),
      ];
    }
    if (!task.isTerminal) {
      return [
        if (status == audio.MusicDownloadStatus.running || status == audio.MusicDownloadStatus.queued)
          _icon(t.music.downloadPause, DsIcons.pause, () => unawaited(controller.pause(task.id))),
        _icon(t.music.downloadCancel, DsIcons.x, () => unawaited(controller.cancel(task.id))),
      ];
    }
    return [
      if (task.status == audio.MusicDownloadStatus.completed || task.status == audio.MusicDownloadStatus.skipped)
        _icon(t.music.play, DsIcons.play, () => _play(ref)),
      _icon(t.music.downloadRemove, DsIcons.trash2, () => unawaited(controller.remove(task.id))),
    ];
  }

  /// Plays the finished file through the module's player: the download
  /// page's preview, without a trip to the folder.
  void _play(WidgetRef ref) {
    final track = _previewTrack(task, local: true);
    unawaited(ref.read(musicPlayerProvider.notifier).playAll([track]));
  }

  /// The finished file's ways out: open it, or open the folder it sits in —
  /// the station managers' two verbs, beside the play the row leads with.
  Widget _menu(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsMenuAnchor(
      semanticLabel: t.common.more,
      align: DsAlign.end,
      builder: (context, controller, child) => DsPressable(
        semanticLabel: t.common.more,
        onPressed: controller.toggle,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Padding(
            padding: const EdgeInsets.all(DsSpace.s4),
            child: DsIcon(
              DsIcons.ellipsisVertical,
              size: theme.sizes.iconSm,
              color: hovered ? colors.text : colors.textSubtle,
            ),
          );
        },
      ),
      items: [
        DsMenuItem(
          leading: const DsIcon(DsIcons.externalLink),
          label: Text(t.settings.downloadOpenFile),
          onPressed: () => unawaited(openDownloadedPath(context, task.outputPath)),
        ),
        DsMenuItem(
          leading: const DsIcon(DsIcons.folderOpen),
          label: Text(t.settings.downloadManagerOpenFolder),
          onPressed: () => unawaited(openDownloadedPath(context, File(task.outputPath).parent.path)),
        ),
      ],
    );
  }

  Widget _icon(String label, DsIconData icon, VoidCallback onPressed) => DsButton.icon(
    variant: DsButtonVariant.secondary,
    size: DsSize.sm,
    semanticLabel: label,
    onPressed: onPressed,
    icon: DsIcon(icon, size: 16),
  );
}

/// The track a download row previews: the platform's cover and names before
/// the file exists, the file itself (path, embedded art, tags) once it does —
/// the shape the player already takes for a device file.
audio.MusicTrack _previewTrack(audio.MusicDownloadTask task, {required bool local}) {
  final request = task.request;
  final cover = request.coverUrl;
  return audio.MusicTrack(
    id: local ? task.outputPath : (request.trackId ?? task.outputPath),
    title: request.title ?? musicFileNameOf(task.outputPath),
    artist: request.artist ?? '',
    album: request.album ?? '',
    duration: request.expectedDuration,
    coverUri: cover == null || cover.isEmpty ? null : Uri.tryParse(cover),
    localPath: local ? task.outputPath : null,
    sourceId: local ? audio.MusicTrack.localSourceId : (request.sourceId ?? ''),
  );
}

/// The rendition a download asks for, in the module's own words; null when the
/// request never named one.
String? _qualityOf(Translations t, audio.MusicDownloadTask task) {
  final id = task.request.qualityId;
  if (id == null || id.isEmpty) return null;
  return musicQualityByScriptName(id)?.label(t) ?? id;
}

/// A byte count as a short human label.
String _bytesText(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// The task's state in words.
String _statusLabel(Translations t, audio.MusicDownloadTask task) => switch (task.status) {
  audio.MusicDownloadStatus.queued => t.music.downloadStatusQueued,
  audio.MusicDownloadStatus.running => t.music.downloadStatusRunning,
  audio.MusicDownloadStatus.paused => t.music.downloadStatusPaused,
  audio.MusicDownloadStatus.processing => t.music.downloadStatusProcessing,
  audio.MusicDownloadStatus.completed => t.music.downloadStatusCompleted,
  audio.MusicDownloadStatus.skipped => t.music.downloadStatusSkipped,
  audio.MusicDownloadStatus.failed => t.music.downloadStatusFailed,
  audio.MusicDownloadStatus.cancelled => t.music.downloadStatusCancelled,
};
