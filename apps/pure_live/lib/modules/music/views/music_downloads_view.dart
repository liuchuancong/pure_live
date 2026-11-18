import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/app/routing/router/app_router.dart' show SettingsSectionRoute;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart'
    show confirmClearFinished, downloadStampOf, openDownloadedPath;
import 'package:pure_live/features/settings/settings.dart' show SettingsSection, openSettingsSection;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/library/music_downloads.dart';
import 'package:pure_live/modules/music/controller/playback/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/playback/music_playback_settings.dart' show musicQualityByScriptName;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart'
    show
        DownloadDetails,
        DownloadDetailsPane,
        DownloadQueueAction,
        DownloadQueueHeader,
        DownloadRowActions,
        DownloadRowMenuActions,
        DownloadRowPhase,
        DownloadTaskCard,
        LiveWindow,
        downloadEtaText,
        downloadFilePresent,
        formatDownloadBytes,
        showDownloadDetails;
import 'package:pure_live/shared/widgets/app_dialog.dart';
import 'package:pure_live/shared/widgets/app_panel.dart';

/// A task whose file is on disk and playable.
bool _playableTask(audio.MusicDownloadTask task) =>
    task.status == audio.MusicDownloadStatus.completed || task.status == audio.MusicDownloadStatus.skipped;

/// Whether a finished download's file is still on disk where its row says.
///
/// Only a playable task can be missing: a queued, running or paused one is
/// still writing (the engine keeps its bytes under a scratch name beside the
/// target), so a missing answer there would call a live transfer a lost file.
/// One stat per row build — never a folder scan.
bool _musicFileMissing(audio.MusicDownloadTask task) => _playableTask(task) && !downloadFilePresent(task.outputPath);

/// The song's own facts, as one line: who sang it, off which record, at which
/// rendition. The row card's first description line and the table's second line
/// both read this, so a song is not described two ways on one page.
String _musicFacts(Translations t, audio.MusicDownloadTask task) => [
  if ((task.request.artist ?? '').isNotEmpty) task.request.artist!,
  if ((task.request.album ?? '').isNotEmpty) task.request.album!,
  ?_qualityOf(t, task),
].join(' · ');

final class MusicDownloadsView extends ConsumerStatefulWidget {
  const MusicDownloadsView({super.key});

  @override
  ConsumerState<MusicDownloadsView> createState() => MusicDownloadsViewState();
}

/// The download page: the queue as a table with its search, its conditions and
/// its batch verbs, the files on disk played in the module's own player, and the
/// folder they land in.
///
/// A window too narrow for a table's columns keeps the row cards the page
/// already drew — a song's artwork, its progress bar and its two fact lines say
/// more there than four ellipsised cells would.
class MusicDownloadsViewState extends ConsumerState<MusicDownloadsView> {
  /// What the search box holds, matched against the song, its people and the
  /// file the engine wrote.
  String _query = '';

  /// The states ticked in the panel; none ticked reads as every state, so an
  /// empty set is the queue's own 全部 rather than a hidden filter.
  final Set<audio.MusicDownloadStatus> _statuses = {};

  /// Whether a row must still name a file the disk holds.
  bool _playableOnly = false;

  /// The ticked rows — the batch verbs' objects.
  final Set<Object> _selected = {};

  /// The row the wide window's facts column speaks about; null lets the first
  /// visible row speak.
  String? _factsId;

  /// Asks the disk again. The queue is a live store rather than a folder read,
  /// so the one thing a refresh can add here is the stat behind 文件不在了:
  /// every finished row is asked once more whether its bytes are where the row
  /// says they are.
  int _recheck = 0;

  /// The missing answers last read, and the queue shape they answer to: the
  /// disk is asked again only when a row's identity, state or path moved —
  /// the queue republishes on every progress tick, and a tick must not stat
  /// a few hundred finished rows per second.
  Map<String, bool> _missingCache = const {};
  String _missingFingerprint = '';

  /// The rows on screen: searched, cut to the ticked states, and to the files
  /// still on disk when that is ticked — in the order the store keeps them, so
  /// the table's own sort is the only thing that reorders the queue.
  List<audio.MusicDownloadTask> _visible(List<audio.MusicDownloadTask> tasks) {
    final query = _query.trim().toLowerCase();
    return [
      for (final task in tasks)
        if ((_statuses.isEmpty || _statuses.contains(task.status)) &&
            (!_playableOnly || !_musicFileMissing(task)) &&
            (query.isEmpty ||
                (task.request.title ?? '').toLowerCase().contains(query) ||
                (task.request.artist ?? '').toLowerCase().contains(query) ||
                (task.request.album ?? '').toLowerCase().contains(query) ||
                musicFileNameOf(task.outputPath).toLowerCase().contains(query)))
          task,
    ];
  }

  /// The ticked rows, in the queue's order.
  List<audio.MusicDownloadTask> _picked(List<audio.MusicDownloadTask> tasks) => [
    for (final task in tasks)
      if (_selected.contains(task.id)) task,
  ];

  /// Runs [verb] over [rows], one after another: the queue answers per task, so
  /// a batch is a run of calls rather than one of its own.
  Future<void> _runOver(
    List<audio.MusicDownloadTask> rows,
    Future<void> Function(MusicDownloadsController controller, String id) verb,
  ) async {
    final controller = ref.read(musicDownloadsProvider.notifier);
    for (final task in rows) {
      await verb(controller, task.id);
    }
  }

  /// Drops the ticked records after one ask; the files they name stay on disk,
  /// which is what the body says rather than leaves to be guessed.
  Future<void> _removePicked(List<audio.MusicDownloadTask> picked) async {
    final t = context.t;
    final confirmed = await showAppConfirm(
      context: context,
      title: t.settings.downloadDeleteSelected(count: picked.length),
      description: t.settings.downloadRemoveBody,
      confirmLabel: t.music.downloadRemove,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _runOver(picked, (controller, id) => controller.remove(id));
    if (mounted) setState(_selected.clear);
  }

  /// Deletes the ticked songs' files and records after one ask. Each failure is
  /// said rather than swallowed, so a batch that names more than the disk holds
  /// does not read as a clean run.
  Future<void> _deletePicked(List<audio.MusicDownloadTask> picked) async {
    final t = context.t;
    final confirmed = await showAppConfirm(
      context: context,
      title: t.settings.downloadDeleteSelected(count: picked.length),
      description: t.music.downloadDeleteFileBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final controller = ref.read(musicDownloadsProvider.notifier);
    for (final task in picked) {
      try {
        await controller.remove(task.id, deleteFile: true);
      } on Object {
        if (mounted) showDsToast(context: context, title: t.music.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
    if (mounted) setState(_selected.clear);
  }

  /// Plays [task] inside the list the page is showing, in the module's own
  /// player: 上一首/下一首, the queue panel and the player page all carry the
  /// other finished downloads rather than stopping at the one tapped. A preview
  /// page of its own would be a second, weaker audio surface over the one that
  /// already owns lyrics, the spectrum and the media session.
  void _playFrom(List<audio.MusicDownloadTask> shown, audio.MusicDownloadTask task) {
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

  /// The queue's conditions, behind the head's one entry: which states show and
  /// whether a row must still name a file the disk holds. Nothing else about a
  /// queue is a condition — where it lands is a setting, and its size is what
  /// the head already says.
  Future<void> _openFilter(List<audio.MusicDownloadTask> tasks) async {
    final t = context.t;
    final picked = {..._statuses};
    var playable = _playableOnly;
    void apply() => setState(() {
      _statuses
        ..clear()
        ..addAll(picked);
      _playableOnly = playable;
      _selected.clear();
    });
    await showAppPanel<void>(
      context: context,
      builder: (panelContext) => AppPanel(
        title: Text(t.settings.downloadFilterTitle),
        child: DsListSection(
          children: [
            for (final status in audio.MusicDownloadStatus.values)
              DsListRow(
                title: Text(_musicStatusLabel(t, status)),
                detail: Text('${tasks.where((task) => task.status == status).length}'),
                trailing: DsCheckbox(
                  value: picked.contains(status),
                  onChanged: (value) {
                    if (value == true) {
                      picked.add(status);
                    } else {
                      picked.remove(status);
                    }
                    apply();
                  },
                ),
              ),
            DsListRow(
              title: Text(t.settings.downloadFilterPlayable),
              trailing: DsSwitch(
                value: playable,
                onChanged: (value) {
                  playable = value;
                  apply();
                },
              ),
            ),
            DsListRow(
              title: Text(t.settings.downloadFilterReset),
              onPressed: () {
                picked.clear();
                playable = false;
                apply();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tasks = ref.watch(musicDownloadsProvider);
    final controller = ref.read(musicDownloadsProvider.notifier);
    final directory = ref.watch(appPathsProvider).music.path;
    // A tick on a row the queue no longer holds no longer counts, and the batch
    // bar would otherwise promise an action on nothing.
    _selected.removeWhere((id) => !tasks.any((task) => task.id == id));
    final shown = _visible(tasks);
    // One stat per row per queue shape, not one per tick: the same song answers
    // through its badge, its verb and its menu.
    final fingerprint =
        '\$directory|\$_recheck|${[for (final task in tasks) '${task.id}:${task.status.index}:${task.outputPath}'].join(',')}';
    if (fingerprint != _missingFingerprint) {
      _missingFingerprint = fingerprint;
      _missingCache = {for (final task in shown) task.id: _musicFileMissing(task)};
    }
    final missing = _missingCache;
    final working = tasks.where((task) => !task.isTerminal).toList();
    final pending = working.length;
    final playableCount = tasks.where(_playableTask).length;
    // What the queue has already put on disk, the summary's second half: a task
    // still running contributes nothing yet.
    final finishedBytes = tasks
        .where(_playableTask)
        .fold<int>(0, (sum, task) => sum + (task.bytesTotal > 0 ? task.bytesTotal : task.bytesReceived));
    // What it is pulling right now, its third half: the lanes' own total.
    final speed = working.fold<int>(0, (sum, task) => sum + task.bytesPerSecond);
    final picked = _picked(tasks);
    final pausable = picked
        .where(
          (task) => task.status == audio.MusicDownloadStatus.running || task.status == audio.MusicDownloadStatus.queued,
        )
        .toList();
    final resumable = picked.where((task) => task.isPaused || task.status == audio.MusicDownloadStatus.failed).toList();
    final factsTask = shown.where((task) => task.id == _factsId).firstOrNull ?? (shown.isEmpty ? null : shown.first);
    final filterActive = _statuses.isNotEmpty || _playableOnly;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // The facts column rides beside the queue where the rows keep their
        // reading after 340 pixels are taken from them.
        final withFacts = width >= LiveWindow.downloadWorkspace;
        final queue = shown.isEmpty ? _empty(t, tasks, directory, filterActive) : _cards(shown, missing);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, DsSpace.s12, _inset, DsSpace.s8),
              child: DownloadQueueHeader(
                summary: [
                  t.settings.downloadSummaryMoving(total: '${tasks.length}', running: '$pending'),
                  if (finishedBytes > 0) formatDownloadBytes(finishedBytes),
                  if (speed > 0) t.common.downloadSpeed(speed: '${formatDownloadBytes(speed)}/s'),
                ].join(' · '),
                settingsLabel: t.settings.downloadSettings,
                onSettings: () {
                  openSettingsSection(ref, SettingsSection.musicDownload);
                  unawaited(context.push(SettingsSectionRoute(section: SettingsSection.musicDownload.name).location));
                },
                searchHint: t.settings.downloadSearchPlaceholder,
                query: _query,
                onQuery: (value) => setState(() {
                  _query = value;
                  _selected.clear();
                }),
                filterLabel: t.settings.downloadFilterLabel,
                filterActive: filterActive,
                onFilter: () => unawaited(_openFilter(tasks)),
                actions: [
                  DownloadQueueAction(
                    label: t.settings.downloadManagerOpenFolder,
                    icon: DsIcons.folderOpen,
                    onPressed: () => unawaited(openDownloadedPath(context, directory)),
                  ),
                  if (pending > 0)
                    DownloadQueueAction(
                      label: t.music.downloadPauseAll,
                      icon: DsIcons.pause,
                      onPressed: () => unawaited(controller.pauseAll()),
                    ),
                  if (tasks.any((task) => task.isPaused))
                    DownloadQueueAction(
                      label: t.music.downloadResumeAll,
                      icon: DsIcons.play,
                      onPressed: () => unawaited(controller.resumeAll()),
                    ),
                  if (playableCount > 0)
                    DownloadQueueAction(
                      label: t.music.downloadClearFinished,
                      icon: DsIcons.trash2,
                      destructive: true,
                      onPressed: () => unawaited(
                        confirmClearFinished(
                          context,
                          title: t.music.downloadClearFinished,
                          clear: controller.clearFinished,
                        ),
                      ),
                    ),
                  DownloadQueueAction(
                    label: t.settings.downloadRecheck,
                    icon: DsIcons.refresh,
                    onPressed: () => setState(() => _recheck++),
                  ),
                ],
                selectedLabel: picked.isEmpty ? null : t.settings.downloadSelectedCount(count: picked.length),
                selectionActions: [
                  if (pausable.isNotEmpty)
                    DownloadQueueAction(
                      label: t.music.downloadPause,
                      icon: DsIcons.pause,
                      onPressed: () => unawaited(_runOver(pausable, (controller, id) => controller.pause(id))),
                    ),
                  if (resumable.isNotEmpty)
                    DownloadQueueAction(
                      label: t.music.downloadResume,
                      icon: DsIcons.play,
                      onPressed: () => unawaited(_runOver(resumable, (controller, id) => controller.resume(id))),
                    ),
                  DownloadQueueAction(
                    label: t.music.downloadRemove,
                    icon: DsIcons.trash2,
                    destructive: true,
                    onPressed: () => unawaited(_removePicked(picked)),
                  ),
                  if (picked.any(_playableTask))
                    DownloadQueueAction(
                      label: t.music.downloadDeleteFile,
                      icon: DsIcons.fileX,
                      destructive: true,
                      onPressed: () => unawaited(_deletePicked(picked)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s16,
                children: [
                  Expanded(child: queue),
                  if (withFacts)
                    SizedBox(
                      width: LiveWindow.downloadDetails,
                      child: DownloadDetailsPane(
                        details: factsTask == null
                            ? null
                            : _detailsOf(
                                context,
                                factsTask,
                                t,
                                onRemove: () => unawaited(controller.remove(factsTask.id)),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The queue as the row cards: one section of songs, each with its artwork,
  /// its state and its own verbs.
  Widget _cards(List<audio.MusicDownloadTask> shown, Map<String, bool> missing) => ListView(
    padding: EdgeInsets.only(left: _inset, right: _inset, bottom: DsSpace.s16),
    children: [
      DsListSection(
        children: [
          for (final task in shown)
            _musicTaskCard(
              context,
              ref,
              task,
              missing: missing[task.id] ?? false,
              onPlay: () => _playFrom(shown, task),
            ),
        ],
      ),
    ],
  );

  /// Where the page keeps its own margin: the head and the queue read the same
  /// number, so their left edges line up.
  double get _inset => LiveWindow.pageInset(MediaQuery.sizeOf(context).width);

  /// Nothing on screen: a filtered queue still holds tasks the viewer has to
  /// un-tick to see, so the empty page says which of the two it is — the same
  /// pair the station's and the drama queue give: the line that names it, and
  /// the verb below that undoes it.
  Widget _empty(Translations t, List<audio.MusicDownloadTask> tasks, String directory, bool filterActive) => Center(
    child: DsEmptyState(
      icon: const DsIcon(DsIcons.download),
      title: Text(tasks.isEmpty ? t.music.downloadsEmptyTitle : t.music.downloadFilterEmpty),
      description: Text(tasks.isEmpty ? t.music.downloadsEmptyDescription : t.music.downloadFilterEmptyDesc),
      actions: [
        if (filterActive)
          DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.filter, size: 14),
            onPressed: () => setState(() {
              _statuses.clear();
              _playableOnly = false;
            }),
            child: Text(t.settings.downloadFilterReset),
          ),
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

/// One song's row, as the shared download row draws it — the state as a badge
/// beside the song's facts, the transfer's numbers under it, the one verb its
/// state allows and the menu with the rest. The page keeps nothing of its own
/// row shape: the same card the station's and the drama's queues wear is the
/// reason their pages read as one surface.
Widget _musicTaskCard(
  BuildContext context,
  WidgetRef ref,
  audio.MusicDownloadTask task, {
  required bool missing,
  required VoidCallback onPlay,
}) {
  final t = context.t;
  final controller = ref.read(musicDownloadsProvider.notifier);
  final progress = task.progress;
  final playable = _playableTask(task);
  final status = task.status;
  final phase = switch (status) {
    audio.MusicDownloadStatus.running => DownloadRowPhase.running,
    audio.MusicDownloadStatus.queued => DownloadRowPhase.queued,
    audio.MusicDownloadStatus.paused => DownloadRowPhase.paused,
    audio.MusicDownloadStatus.processing => DownloadRowPhase.processing,
    audio.MusicDownloadStatus.failed => DownloadRowPhase.failed,
    audio.MusicDownloadStatus.cancelled => DownloadRowPhase.cancelled,
    audio.MusicDownloadStatus.completed ||
    audio.MusicDownloadStatus.skipped => missing ? DownloadRowPhase.missing : DownloadRowPhase.done,
  };
  final moving = status == audio.MusicDownloadStatus.running || status == audio.MusicDownloadStatus.paused;
  // The badge carries the state; the caption carries the transfer's numbers —
  // a failed row its error — so one fact is said once.
  final caption = switch (phase) {
    DownloadRowPhase.failed => task.error ?? t.settings.downloadStatusFailed,
    DownloadRowPhase.missing => t.common.previewFileMissing,
    DownloadRowPhase.done => task.bytesTotal > 0 ? formatDownloadBytes(task.bytesTotal) : t.settings.downloadStatusDone,
    _ => [
      if (!task.isTerminal && progress != null) '${(progress * 100).round()}%',
      if (status == audio.MusicDownloadStatus.running && task.bytesPerSecond > 0)
        '${formatDownloadBytes(task.bytesPerSecond)}/s',
      ?_etaOf(t, task),
    ].join(' · '),
  };
  final title = task.request.title ?? musicFileNameOf(task.outputPath);
  // The art of the row: the downloaded file's own cover once it is on disk,
  // the platform's cover before that — the page shows the songs, not their
  // tasks.
  final preview = _previewTrack(task, local: playable);
  Future<void> deleteFile() async {
    final confirmed = await showAppConfirm(
      context: context,
      title: t.music.downloadDeleteFile,
      description: t.music.downloadDeleteFileBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await controller.remove(task.id, deleteFile: true);
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.music.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
  }

  return DownloadTaskCard(
    key: ValueKey(task.id),
    title: title,
    phase: phase,
    caption: caption,
    badgeLabel: status == audio.MusicDownloadStatus.running && progress != null
        ? '${t.settings.downloadStatusRunning} ${(progress * 100).round()}%'
        : null,
    meta: _musicFacts(t, task),
    fraction: progress,
    showProgress: moving && progress != null,
    progressLabel: t.music.downloadProgress,
    leading: MusicArtwork(track: preview),
    playable: playable,
    actions: DownloadRowActions(
      // A waiting row holds its place in the lane — the queue's resume answers
      // only a held row, so the waiting one offers the pause that takes it out
      // of the lane.
      onPause: status == audio.MusicDownloadStatus.running || status == audio.MusicDownloadStatus.queued
          ? () => unawaited(controller.pause(task.id))
          : null,
      onResume: status == audio.MusicDownloadStatus.paused ? () => unawaited(controller.resume(task.id)) : null,
      onRetry: status == audio.MusicDownloadStatus.failed ? () => unawaited(controller.retry(task.id)) : null,
      onPlay: playable ? onPlay : null,
      onCancel: status == audio.MusicDownloadStatus.processing ? () => unawaited(controller.cancel(task.id)) : null,
      onRemove: status == audio.MusicDownloadStatus.cancelled ? () => unawaited(controller.remove(task.id)) : null,
    ),
    menu: DownloadRowMenuActions(
      onDetails: () => unawaited(
        showDownloadDetails(
          context,
          _detailsOf(context, task, t, onRemove: () => unawaited(controller.remove(task.id))),
        ),
      ),
      onRemove: () => unawaited(controller.remove(task.id)),
      missing: missing,
      onMenuCancel: !task.isTerminal && status != audio.MusicDownloadStatus.processing
          ? () => unawaited(controller.cancel(task.id))
          : null,
      onOpenFile: playable && !missing ? () => unawaited(openDownloadedPath(context, task.outputPath)) : null,
      onOpenFolder: playable ? () => unawaited(openDownloadedPath(context, File(task.outputPath).parent.path)) : null,
      onDeleteFile: playable && !missing ? () => unawaited(deleteFile()) : null,
    ),
  );
}

DownloadDetails _detailsOf(
  BuildContext context,
  audio.MusicDownloadTask task,
  Translations t, {
  VoidCallback? onRemove,
}) {
  final request = task.request;
  final missing = _musicFileMissing(task);
  final facts = [
    if ((request.artist ?? '').isNotEmpty) request.artist!,
    if ((request.album ?? '').isNotEmpty) request.album!,
  ];
  return DownloadDetails(
    title: request.title ?? musicFileNameOf(task.outputPath),
    part: facts.join(' · '),
    coverUrl: request.coverUrl ?? '',
    status: missing ? '${t.music.downloadStatusCompleted} · ${t.common.previewFileMissing}' : _statusLabel(t, task),
    savePath: task.outputPath,
    queuedAt: task.startedAt == null ? '' : downloadStampOf(task.startedAt!),
    // The task's attempt is 1-based; a first run is no retry.
    retries: (task.attempt - 1).clamp(0, 1 << 20),
    error: task.error ?? '',
    fileMissing: missing,
    onOpenFile: _playableTask(task) && !missing ? () => unawaited(openDownloadedPath(context, task.outputPath)) : null,
    onOpenFolder: () => unawaited(openDownloadedPath(context, File(task.outputPath).parent.path)),
    onRemove: onRemove,
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
  return t.settings.downloadEta(time: downloadEtaText(left));
}

/// One state's word. The row's caption, the table's badge and the filter panel's
/// tick list all read this, so one state is not named three ways on one page.
String _musicStatusLabel(Translations t, audio.MusicDownloadStatus status) => switch (status) {
  audio.MusicDownloadStatus.queued => t.music.downloadStatusQueued,
  audio.MusicDownloadStatus.running => t.music.downloadStatusRunning,
  audio.MusicDownloadStatus.paused => t.music.downloadStatusPaused,
  audio.MusicDownloadStatus.processing => t.music.downloadStatusProcessing,
  audio.MusicDownloadStatus.completed => t.music.downloadStatusCompleted,
  audio.MusicDownloadStatus.skipped => t.music.downloadStatusSkipped,
  audio.MusicDownloadStatus.failed => t.music.downloadStatusFailed,
  audio.MusicDownloadStatus.cancelled => t.music.downloadStatusCancelled,
};

/// The task's state in words.
String _statusLabel(Translations t, audio.MusicDownloadTask task) => _musicStatusLabel(t, task.status);
