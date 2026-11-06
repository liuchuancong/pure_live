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
    show
        DownloadDetails,
        DownloadDetailsPane,
        DownloadQueueAction,
        DownloadQueueHeader,
        GlyphIcon,
        LiveWindow,
        MusicGlyph,
        downloadFilePresent,
        formatDownloadBytes,
        showDownloadDetails;

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

/// What a task's state says about itself, as the table's state column shows it:
/// the state, and how far a transfer still owed bytes has got. The words come
/// from [_statusLabel], the same list the filter panel ticks through, so one
/// state has one spelling on this page.
Widget _musicPhaseBadge(BuildContext context, audio.MusicDownloadTask task, {required bool missing}) {
  final t = context.t;
  final progress = task.progress;
  // A row whose file the viewer moved or deleted is said here, in the same words
  // its own caption and the facts column use: the record is true of the
  // transfer, not of the disk.
  if (missing) {
    return DsBadge(status: DsStatus.danger, label: Text(t.common.previewFileMissing));
  }
  // A working row counts itself out loud when the engine can say how far it is.
  if (task.status == audio.MusicDownloadStatus.running && progress != null) {
    return DsBadge(status: DsStatus.info, label: Text('${_statusLabel(t, task)} ${(progress * 100).round()}%'));
  }
  return DsBadge(
    status: switch (task.status) {
      audio.MusicDownloadStatus.completed || audio.MusicDownloadStatus.skipped => DsStatus.success,
      audio.MusicDownloadStatus.running || audio.MusicDownloadStatus.processing => DsStatus.info,
      audio.MusicDownloadStatus.paused => DsStatus.warning,
      audio.MusicDownloadStatus.failed || audio.MusicDownloadStatus.cancelled => DsStatus.danger,
      audio.MusicDownloadStatus.queued => DsStatus.neutral,
    },
    label: Text(_statusLabel(t, task)),
  );
}

/// The one verb a task's state allows: pause or carry on a transfer, fetch a
/// failed one again, play the file that landed, or — for a task the engine is
/// still writing tags into, or one the viewer stopped — take it out of the
/// queue.
///
/// The card and the table name the same verb for the same state, so the two
/// shapes cannot drift apart; everything else a row can do sits in
/// [_musicRowMenu].
Widget _musicPhaseVerb(
  BuildContext context,
  WidgetRef ref,
  audio.MusicDownloadTask task, {
  required bool missing,
  required VoidCallback onPlay,
}) {
  final t = context.t;
  final controller = ref.read(musicDownloadsProvider.notifier);
  Widget icon(String label, DsIconData glyph, VoidCallback onPressed) => DsButton.icon(
    variant: DsButtonVariant.secondary,
    size: DsSize.sm,
    semanticLabel: label,
    onPressed: onPressed,
    icon: DsIcon(glyph, size: 16),
  );
  final status = task.status;
  if (_playableTask(task)) {
    // A song whose file is gone has nothing to play: the button keeps its place,
    // names the fact and stays out of reach rather than handing the player a
    // dead path.
    if (missing) {
      return DsButton.icon(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        icon: const DsIcon(DsIcons.fileX, size: 16),
        semanticLabel: t.common.previewFileMissing,
        onPressed: null,
      );
    }
    return icon(t.music.play, DsIcons.play, onPlay);
  }
  return switch (status) {
    audio.MusicDownloadStatus.failed => icon(
      t.music.downloadRetry,
      DsIcons.refreshCw,
      () => unawaited(controller.retry(task.id)),
    ),
    audio.MusicDownloadStatus.paused => icon(
      t.music.downloadResume,
      DsIcons.play,
      () => unawaited(controller.resume(task.id)),
    ),
    audio.MusicDownloadStatus.running || audio.MusicDownloadStatus.queued => icon(
      t.music.downloadPause,
      DsIcons.pause,
      () => unawaited(controller.pause(task.id)),
    ),
    // The engine owes these two nothing more: a task still writing tags can only
    // be stopped, and a cancelled one can only leave the list — which is why its
    // menu drops the same verb it would show twice.
    audio.MusicDownloadStatus.processing => icon(
      t.music.downloadCancel,
      DsIcons.x,
      () => unawaited(controller.cancel(task.id)),
    ),
    _ => icon(t.music.downloadRemove, DsIcons.trash2, () => unawaited(controller.remove(task.id))),
  };
}

/// Everything one download can be asked for beyond its state's own verb: the
/// facts sheet, and for a file on disk the three ways out — open it, open the
/// folder beside it, delete it with its record — ending in the record's removal.
/// A song whose file went away keeps the folder (what sits beside it is still
/// worth seeing) and loses the two verbs that act on a file that is not there.
List<Widget> _musicRowMenu(BuildContext context, WidgetRef ref, audio.MusicDownloadTask task, {required bool missing}) {
  final t = context.t;
  final controller = ref.read(musicDownloadsProvider.notifier);
  final playable = _playableTask(task);
  // The verb column already IS 移除记录 for a cancelled row; an action gets one
  // place to be pressed, not two.
  final verbIsRemove = task.status == audio.MusicDownloadStatus.cancelled;

  Future<void> deleteFile() async {
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
      await controller.remove(task.id, deleteFile: true);
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.music.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
  }

  return [
    DsMenuItem(
      leading: const DsIcon(DsIcons.info),
      label: Text(t.common.downloadDetails),
      // One construction feeds the menu's sheet and the wide workspace's right
      // column, so the two cannot state different facts.
      onPressed: () => unawaited(
        showDownloadDetails(
          context,
          _detailsOf(context, task, t, onRemove: () => unawaited(controller.remove(task.id))),
        ),
      ),
    ),
    // A transfer still owed a file can be dropped: for 排队中/下载中 that is the
    // pause verb's companion, for 已暂停 the only way out besides carrying on. A
    // task the engine is writing tags into is already cancelled by its own verb,
    // so the menu must not name the same action twice; a terminal one has nothing
    // left to cancel.
    if (!task.isTerminal && task.status != audio.MusicDownloadStatus.processing)
      DsMenuItem(
        leading: const DsIcon(DsIcons.x),
        label: Text(t.music.downloadCancel),
        onPressed: () => unawaited(controller.cancel(task.id)),
      ),
    if (playable) ...[
      const DsMenuDivider(),
      if (!missing)
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
      if (!missing)
        DsMenuItem(
          leading: const DsIcon(DsIcons.trash2),
          label: Text(t.music.downloadDeleteFile),
          destructive: true,
          onPressed: () => unawaited(deleteFile()),
        ),
    ],
    if (!verbIsRemove)
      DsMenuItem(
        leading: const DsIcon(DsIcons.trash2),
        // Over a file that is gone, the row's only verb is leaving the list; the
        // word says that instead of 移除, which reads twice.
        label: Text(missing ? t.common.downloadRemoveFromList : t.music.downloadRemove),
        destructive: true,
        onPressed: () => unawaited(controller.remove(task.id)),
      ),
  ];
}

/// The states in the order a queue reads: what is moving, what the engine is
/// still finishing, what waits for a lane, what stopped on purpose, what
/// landed, what was already there, what stopped on its own, what was dropped.
int _musicStatusRank(audio.MusicDownloadStatus status) => switch (status) {
  audio.MusicDownloadStatus.running => 0,
  audio.MusicDownloadStatus.processing => 1,
  audio.MusicDownloadStatus.queued => 2,
  audio.MusicDownloadStatus.paused => 3,
  audio.MusicDownloadStatus.completed => 4,
  audio.MusicDownloadStatus.skipped => 5,
  audio.MusicDownloadStatus.failed => 6,
  audio.MusicDownloadStatus.cancelled => 7,
};

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

  /// The table's sorted column.
  DsTableSort? _sort;

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
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadDeleteSelected(count: picked.length),
      description: t.settings.downloadRemoveBody,
      confirmLabel: t.music.downloadRemove,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
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
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadDeleteSelected(count: picked.length),
      description: t.music.downloadDeleteFileBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
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
    await showDsPanel<void>(
      context: context,
      builder: (panelContext) => DsPanel(
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
    // One stat per visible row per read, not one per cell: the same song answers
    // through its badge, its verb and its menu.
    final missing = {for (final task in shown) task.id: _musicFileMissing(task)};
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
        // The table starts where a queue's columns fit; below it the songs keep
        // the row cards, with their artwork and their bar.
        final asTable = width >= LiveWindow.table;
        // The facts column rides beside a table only where the table still
        // keeps its columns after 340 pixels are taken from it.
        final withFacts = width >= LiveWindow.downloadWorkspace;
        // A table says it has nothing through its own slot; the card list needs
        // the page's empty state.
        final queue = asTable
            ? _table(
                t,
                shown,
                narrow: width < 720,
                withFacts: withFacts,
                tasks: tasks,
                directory: directory,
                isMissing: (task) => missing[task.id] ?? false,
              )
            : shown.isEmpty
            ? _empty(t, tasks, directory, filterActive)
            : _cards(shown);
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
                directory: directory,
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
  Widget _cards(List<audio.MusicDownloadTask> shown) => ListView(
    padding: EdgeInsets.only(left: _inset, right: _inset, bottom: DsSpace.s16),
    children: [
      DsListSection(
        children: [
          for (final task in shown)
            _DownloadRow(key: ValueKey(task.id), task: task, onPlay: () => _playFrom(shown, task)),
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
      icon: const GlyphIcon(MusicGlyph.download),
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

  /// The queue as a table: the song and what became of it, then the bytes, the
  /// moment and the one verb its state allows.
  ///
  /// A narrow table drops the two columns a row can do without, and pressing a
  /// row is the facts column's own verb — so a window with no facts column lets
  /// a click do what its checkbox does.
  Widget _table(
    Translations t,
    List<audio.MusicDownloadTask> rows, {
    required bool narrow,
    required bool withFacts,
    required List<audio.MusicDownloadTask> tasks,
    required String directory,
    required bool Function(audio.MusicDownloadTask task) isMissing,
  }) {
    final theme = DsTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, 0, _inset, DsSpace.s12),
      child: DsTable<audio.MusicDownloadTask>(
        semanticLabel: t.navigation.musicDownloads,
        style: const DsTableStyle(rowHeight: 56),
        rowsVersion: _recheck,
        columns: [
          DsTableColumn<audio.MusicDownloadTask>(
            id: 'name',
            label: t.settings.downloadColumnFile,
            value: (task) => task.request.title ?? musicFileNameOf(task.outputPath),
            sortable: true,
            width: const DsTableColumnWidth.flex(3, 160),
            // Two lines, as the station managers' rows do: the song over the
            // artists, the record and the rendition it was asked for.
            cell: (context, task) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.request.title ?? musicFileNameOf(task.outputPath),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _musicFacts(t, task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: theme.colors.textSubtle),
                ),
              ],
            ),
          ),
          DsTableColumn<audio.MusicDownloadTask>(
            id: 'status',
            label: t.common.downloadStatus,
            sortable: true,
            comparator: (a, b) => _musicStatusRank(a.status).compareTo(_musicStatusRank(b.status)),
            width: const DsTableColumnWidth.intrinsic(min: 104),
            cell: (context, task) => _musicPhaseBadge(context, task, missing: isMissing(task)),
          ),
          if (!narrow)
            DsTableColumn<audio.MusicDownloadTask>(
              id: 'size',
              label: t.settings.downloadColumnSize,
              value: (task) => task.bytesTotal > 0 ? task.bytesTotal : task.bytesReceived,
              text: (task) => formatDownloadBytes(task.bytesTotal > 0 ? task.bytesTotal : task.bytesReceived),
              numeric: true,
              sortable: true,
              width: const DsTableColumnWidth.intrinsic(min: 88),
            ),
          if (!narrow)
            DsTableColumn<audio.MusicDownloadTask>(
              id: 'time',
              label: t.settings.downloadColumnTime,
              value: (task) => (task.finishedAt ?? task.startedAt)?.millisecondsSinceEpoch ?? 0,
              text: (task) {
                final at = task.finishedAt ?? task.startedAt;
                return at == null ? '' : downloadStampOf(at);
              },
              sortable: true,
              width: const DsTableColumnWidth.intrinsic(min: 92),
            ),
          DsTableColumn<audio.MusicDownloadTask>(
            id: 'actions',
            label: t.settings.downloadColumnActions,
            alignment: DsTableCellAlignment.end,
            // A builder-only column measures nothing, so it names its width.
            width: const DsTableColumnWidth.fixed(48),
            cell: (context, task) =>
                _musicPhaseVerb(context, ref, task, missing: isMissing(task), onPlay: () => _playFrom(rows, task)),
          ),
        ],
        rows: rows,
        rowKey: (task) => task.id,
        sort: _sort,
        onSortChanged: (sort) => setState(() => _sort = sort),
        selected: _selected,
        onSelectionChanged: (next) => setState(() {
          _selected
            ..clear()
            ..addAll(next);
        }),
        onRowPressed: withFacts
            ? (task) => setState(() {
                _factsId = task.id;
              })
            : null,
        rowMenuBuilder: (context, task) => _musicRowMenu(context, ref, task, missing: isMissing(task)),
        showRowMenuButton: true,
        emptyView: _empty(t, tasks, directory, _statuses.isNotEmpty || _playableOnly),
      ),
    );
  }
}

/// One download's row, as the window too narrow for a table shows it: the song's
/// artwork and names over its state's caption and bar, with the actions that
/// state allows at the end. The table shape reads the same state, verb and menu
/// through [_musicPhaseBadge], [_musicPhaseVerb] and [_musicRowMenu], so the two
/// shapes cannot say two different things about one song.
final class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({required this.task, required this.onPlay, super.key});

  final audio.MusicDownloadTask task;

  /// Plays this row inside the list the page is showing, queued in the module's
  /// own player.
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final progress = task.progress;
    final title = task.request.title ?? musicFileNameOf(task.outputPath);
    final playable = _playableTask(task);
    // The file the row claims, asked once: a song the viewer moved out of the
    // download folder still shows as 已完成 unless someone looks.
    final missing = _musicFileMissing(task);
    // The art of the row: the downloaded file's own cover once it is on disk,
    // the platform's cover before that — the page shows the songs, not their
    // tasks.
    final preview = _previewTrack(task, local: playable);
    final facts = _musicFacts(t, task);
    final caption = missing ? t.common.previewFileMissing : _statusLabel(t, task);
    final detail = [
      caption,
      if (!task.isTerminal && progress != null) '${(progress * 100).round()}%',
      if (task.status == audio.MusicDownloadStatus.running && task.bytesPerSecond > 0)
        '${formatDownloadBytes(task.bytesPerSecond)}/s',
      ?_etaOf(t, task),
      if (playable && !missing && task.bytesTotal > 0) formatDownloadBytes(task.bytesTotal),
    ].join(' · ');
    return DsListRow(
      leading: MusicArtwork(track: preview),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          if (facts.isNotEmpty)
            Text(facts, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.typography.caption),
          // Two lines: a failed row carries its error as well as its state, and
          // a narrow window must not ellipsise the second half away.
          Text(
            task.status == audio.MusicDownloadStatus.failed && task.error != null
                ? '${_statusLabel(t, task)} · ${task.error}'
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
        children: [
          _musicPhaseVerb(context, ref, task, missing: missing, onPlay: onPlay),
          DsMenuAnchor(
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
            items: _musicRowMenu(context, ref, task, missing: missing),
          ),
        ],
      ),
    );
  }
}

/// The facts the row's 详情 sheet and the wide workspace's right column show
/// — one construction, so the two cannot drift.
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
  return t.music.downloadEta(time: musicDurationText(left));
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
