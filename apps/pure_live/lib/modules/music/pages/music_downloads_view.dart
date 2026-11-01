import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart'
    show confirmClearFinished, downloadStampOf, openDownloadedPath;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_downloads.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playback_settings.dart' show musicQualityByScriptName;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart'
    show DownloadDetails, DownloadFilterOption, DownloadWorkspace, LiveWindow, showDownloadDetails;

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

  /// The row whose facts sit in the wide workspace's right column; null lets
  /// the first visible row speak.
  String? _selectedId;

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
    // The queue's live throughput: every task still working, summed.
    final totalSpeed = pending.fold<int>(0, (sum, task) => sum + task.bytesPerSecond);
    final shown = switch (_filter) {
      _DownloadsFilter.all => tasks,
      _DownloadsFilter.active => tasks.where((task) => !_playableTask(task)).toList(),
      _DownloadsFilter.done => finished,
    };
    // A row whose facts sit at the wide workspace's right; the first visible
    // row speaks until the viewer picks one.
    final selectedTask =
        (_selectedId == null ? null : tasks.where((task) => task.id == _selectedId).firstOrNull) ??
        (shown.isEmpty ? null : shown.first);
    // The download page plays in the module's own player, and it hands the
    // player the list the page is showing: 上一首/下一首, the queue panel and
    // the player page all carry the other finished downloads instead of
    // stopping at the one tapped. A preview page of its own would be a second,
    // weaker audio surface over the one that already owns lyrics, the spectrum
    // and the media session.
    void playFromList(audio.MusicDownloadTask task) {
      final queue = [
        for (final item in shown)
          if (_playableTask(item)) item,
      ];
      final index = queue.indexWhere((item) => item.id == task.id);
      if (index < 0) return;
      unawaited(
        ref.read(musicPlayerProvider.notifier).playAll([
          for (final item in queue) _previewTrack(item, local: true),
        ], index: index),
      );
    }

    Widget queueList({required bool wide}) => shown.isEmpty
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
              DsListSection(
                children: [
                  for (final task in shown)
                    _DownloadRow(
                      key: ValueKey(task.id),
                      task: task,
                      onPlay: () => playFromList(task),
                      selected: wide && task.id == selectedTask?.id,
                      onSelect: wide ? () => setState(() => _selectedId = task.id) : null,
                    ),
                ],
              ),
            ],
          );
    if (tasks.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.download),
          title: Text(t.music.downloadsEmptyTitle),
          description: Text(t.music.downloadsEmptyDescription(directory: directory)),
          actions: [
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.folderOpen, size: 14),
              onPressed: () => unawaited(openDownloadedPath(context, directory)),
              child: Text(t.settings.downloadManagerOpenFolder),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // A manager with room for three panes reads like a workspace: the
        // filters, the queue, and the selected task's facts. A narrower one
        // keeps the list and the sheet the row menu already offers.
        final wide = constraints.maxWidth >= LiveWindow.downloadWorkspace;
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
                        if (totalSpeed > 0)
                          Text(
                            t.common.downloadSpeed(speed: '${_bytesText(totalSpeed)}/s'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(color: colors.textMuted),
                          ),
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
                  // The verbs scroll rather than overflow on a narrow window:
                  // a manager is still a manager at 320px, and the batch
                  // actions must stay reachable there.
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        spacing: DsSpace.s8,
                        children: [
                          // The folder every one of these files lands in, one
                          // click from the page that lists them — the station
                          // managers' own verb.
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
                  ),
                ],
              ),
            ),
            // The queue's own filter, the station managers' grammar: everything,
            // what is still owed a file, and what is already on disk — the wide
            // workspace lists the same three in its rail instead.
            if (!wide)
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
                        for (final filter in _DownloadsFilter.values)
                          DsSegment(value: filter, label: Text(filter.label(t))),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: wide
                  ? DownloadWorkspace<_DownloadsFilter>(
                      padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s16),
                      options: [
                        for (final value in _DownloadsFilter.values)
                          DownloadFilterOption(
                            value: value,
                            icon: switch (value) {
                              _DownloadsFilter.all => DsIcons.list,
                              _DownloadsFilter.active => DsIcons.download,
                              _DownloadsFilter.done => DsIcons.checkCircle,
                            },
                            label: value.label(t),
                            count: switch (value) {
                              _DownloadsFilter.all => tasks.length,
                              _DownloadsFilter.active => tasks.where((task) => !_playableTask(task)).length,
                              _DownloadsFilter.done => finished.length,
                            },
                          ),
                      ],
                      selected: _filter,
                      onSelected: (filter) => setState(() => _filter = filter),
                      list: queueList(wide: true),
                      details: selectedTask == null ? null : _detailsOf(context, selectedTask, t),
                    )
                  : queueList(wide: false),
            ),
          ],
        );
      },
    );
  }
}

final class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({required this.task, required this.onPlay, this.selected = false, this.onSelect, super.key});

  final audio.MusicDownloadTask task;

  /// Plays this row inside the list the page is showing, queued in the
  /// module's own player.
  final VoidCallback onPlay;

  /// Whether the wide workspace shows this row's facts at the right.
  final bool selected;

  /// Marks this row as the one the workspace speaks about.
  final VoidCallback? onSelect;

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
      ?_etaOf(t, task),
      if (playable && task.bytesTotal > 0) _bytesText(task.bytesTotal),
    ].join(' · ');
    return DsListRow(
      selected: selected,
      leading: MusicArtwork(track: preview),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      // A finished file plays in the module's own player — the preview the
      // download page was missing. In the wide workspace the row's press
      // selects it for the right column instead; its play button still plays.
      onPressed: onSelect ?? (playable ? onPlay : null),
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
        children: [..._actions(context, controller, t, ref), _menu(context, ref)],
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
        _icon(t.music.play, DsIcons.play, onPlay),
      _icon(t.music.downloadRemove, DsIcons.trash2, () => unawaited(controller.remove(task.id))),
    ];
  }

  /// The row's menu: the details every task answers with, then — once the
  /// file is on disk — the two ways out (open it, open its folder) and the
  /// destructive third the plain remove button must not be: the record and
  /// its file going together, behind a confirm. A task still moving keeps
  /// the details but never an action on a file that is not there yet.
  Widget _menu(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final playable = _playableTask(task);
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
          leading: const DsIcon(DsIcons.info),
          label: Text(t.common.downloadDetails),
          // One construction feeds the menu's sheet and the wide workspace's
          // right column, so the two cannot state different facts.
          onPressed: () => unawaited(showDownloadDetails(context, _detailsOf(context, task, t))),
        ),
        if (playable) ...[
          const DsMenuDivider(),
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
          DsMenuItem(
            leading: const DsIcon(DsIcons.trash2),
            label: Text(t.music.downloadDeleteFile),
            destructive: true,
            onPressed: () => unawaited(_deleteFile(context, ref)),
          ),
        ],
      ],
    );
  }

  /// The confirm-guarded file deletion: removing the row silently keeps the
  /// file, so the delete that takes both is its own ask — the VOD page's
  /// verb, worded for audio.
  Future<void> _deleteFile(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.music.downloadDeleteFile,
      description: t.music.downloadDeleteFileBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(musicDownloadsProvider.notifier).remove(task.id, deleteFile: true);
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.music.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
  }

  Widget _icon(String label, DsIconData icon, VoidCallback onPressed) => DsButton.icon(
    variant: DsButtonVariant.secondary,
    size: DsSize.sm,
    semanticLabel: label,
    onPressed: onPressed,
    icon: DsIcon(icon, size: 16),
  );
}

/// The facts the row's 详情 sheet and the wide workspace's right column show
/// — one construction, so the two cannot drift.
DownloadDetails _detailsOf(BuildContext context, audio.MusicDownloadTask task, Translations t) {
  final request = task.request;
  final facts = [
    if ((request.artist ?? '').isNotEmpty) request.artist!,
    if ((request.album ?? '').isNotEmpty) request.album!,
  ];
  return DownloadDetails(
    title: request.title ?? musicFileNameOf(task.outputPath),
    part: facts.join(' · '),
    coverUrl: request.coverUrl ?? '',
    status: _statusLabel(t, task),
    savePath: task.outputPath,
    queuedAt: task.startedAt == null ? '' : downloadStampOf(task.startedAt!),
    // The task's attempt is 1-based; a first run is no retry.
    retries: (task.attempt - 1).clamp(0, 1 << 20),
    error: task.error ?? '',
    onOpenFile: _playableTask(task) ? () => unawaited(openDownloadedPath(context, task.outputPath)) : null,
    onOpenFolder: () => unawaited(openDownloadedPath(context, File(task.outputPath).parent.path)),
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

/// The remaining time while the engine can compute one — bytes owed over a
/// known speed; left out of the row rather than guessed.
String? _etaOf(Translations t, audio.MusicDownloadTask task) {
  if (task.status != audio.MusicDownloadStatus.running) return null;
  final left = task.remaining;
  if (left == null) return null;
  return t.music.downloadEta(time: musicDurationText(left));
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
