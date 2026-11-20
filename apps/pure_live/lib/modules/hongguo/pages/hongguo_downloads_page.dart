import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/boot/storage_providers.dart'
    show appPathsProvider, storageFolderOverridesProvider;
import 'package:pure_live/app/providers/settings/storage_folder_provider.dart' show StorageFolder;
import 'package:pure_live/app/routing/router/app_router.dart' show SettingsSectionRoute;
import 'package:pure_live/features/media_preview/media_preview_item.dart' show MediaPreviewItem;
import 'package:pure_live/features/media_preview/media_preview_page.dart' show openMediaPreview;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart'
    show confirmClearFinished, downloadStampOf, openDownloadedPath;
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openModuleItem, openSettingsSection;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_covers.dart' show hongguoCoverImage;
import 'package:pure_live/modules/hongguo/controller/hongguo_downloads.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart' show HongguoQualityChoice;
import 'package:pure_live/shared/shared.dart'
    show
        DownloadDetails,
        DownloadDetailsPane,
        DownloadQueueAction,
        DownloadQueueHeader,
        DownloadRowActions,
        DownloadRowMenuActions,
        DownloadRowPhase,
        DownloadStatusGroup,
        DownloadStatusTab,
        DownloadStatusTabs,
        DownloadTaskCard,
        LiveWindow,
        NavigationItem,
        downloadEtaText,
        downloadFilePresent,
        downloadRowGroupOf,
        formatDownloadBytes,
        showDownloadDetails;
import 'package:pure_live/shared/widgets/app_dialog.dart';

/// Whether a finished episode's file is still on disk where its row says.
///
/// Only a `done` row can be missing: a queued, paused or failed episode keeps
/// its bytes in the `.part` beside the target and renames into place only when
/// the transfer ends, so marking such a row 文件不在了 would say the opposite
/// of the truth. One stat per row build, never a folder scan.
bool _hongguoFileMissing(HongguoDownloadItem task) =>
    task.phase == HongguoDownloadPhase.done && !downloadFilePresent(task.filePath);

/// Takes one episode's record out of the queue; the file, if it is there, stays.
///
/// The row menu and the wide workspace's facts column both reach it, so a row
/// that only names a file the viewer moved can be cleared from wherever the
/// absence was noticed.
Future<void> _removeRecord(BuildContext context, WidgetRef ref, String id) async {
  final t = context.t;
  final confirmed = await showAppConfirm(
    context: context,
    title: t.settings.downloadRemove,
    description: t.settings.downloadRemoveBody,
    confirmLabel: t.settings.downloadRemove,
    cancelLabel: t.common.cancel,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  await ref.read(hongguoDownloadsProvider.notifier).remove(id);
}

/// Opens the app's own preview on [task], with the queue's other finished
/// episodes beside it. Hongguo saves no danmaku file, so the stage's switch
/// says so and stays out of reach.
///
/// The row card's play button, its table twin and its menu all come through
/// here, so the run an episode joins is one list rather than three that drift.
Future<void> _openHongguoPreview(BuildContext context, WidgetRef ref, HongguoDownloadItem task) async {
  final t = context.t;
  final items = _hongguoPreviewItems(ref.read(hongguoDownloadsProvider));
  final index = items.indexWhere((item) => item.id == task.id);
  if (index < 0) {
    showDsToast(context: context, title: t.hongguo.previewUnavailable, status: DsStatus.warning);
    return;
  }
  await openMediaPreview(
    context,
    title: t.hongguo.previewTitle,
    items: items,
    initialIndex: index,
    // The same rule as the video site: an episode deleted in the player has
    // no reason to stay in the queue as a row that opens nothing.
    onDeleted: (item) => ref.read(hongguoDownloadsProvider.notifier).remove(item.id),
  );
}

/// The episode a row names: the platform's own 第N集, with the title the site
/// gave that episode beside it when it differs from the number — the queue
/// stores the generated label when the site named nothing. The card's title and
/// the table's second line both read this, so one episode has one spelling.
String _hongguoEpisodeLabel(Translations t, HongguoDownloadItem task) {
  final label = t.hongguo.episodeLabel(index: task.index);
  return task.part.isEmpty || task.part == label ? label : '$label · ${task.part}';
}

/// One episode's state as the shared rows draw it: a finished file that
/// wandered off reads as missing.
DownloadRowPhase _hongguoRowPhase(HongguoDownloadPhase phase, {required bool missing}) => switch (phase) {
  HongguoDownloadPhase.running => DownloadRowPhase.running,
  HongguoDownloadPhase.queued => DownloadRowPhase.queued,
  HongguoDownloadPhase.paused => DownloadRowPhase.paused,
  HongguoDownloadPhase.failed => DownloadRowPhase.failed,
  HongguoDownloadPhase.done => missing ? DownloadRowPhase.missing : DownloadRowPhase.done,
};

/// The state tab's word — the shared status words, with 全部 at its head.
String _statusTabLabel(Translations t, DownloadStatusGroup group) => switch (group) {
  DownloadStatusGroup.all => t.settings.downloadFilterAll,
  DownloadStatusGroup.running => t.settings.downloadStatusRunning,
  DownloadStatusGroup.queued => t.settings.downloadStatusQueued,
  DownloadStatusGroup.paused => t.settings.downloadStatusPaused,
  DownloadStatusGroup.done => t.settings.downloadStatusDone,
  DownloadStatusGroup.failed => t.settings.downloadStatusFailed,
};

final class HongguoDownloadsPane extends ConsumerStatefulWidget {
  /// The pane shown under Settings → 红果短剧 → 下载.
  const HongguoDownloadsPane({super.key});

  @override
  ConsumerState<HongguoDownloadsPane> createState() => _HongguoDownloadsPaneState();
}

final class _HongguoDownloadsPaneState extends ConsumerState<HongguoDownloadsPane> {
  /// The merge's own progress, or null while nothing is moving. The row has to
  /// say which file it is on and offer a way to stop, so the run needs a place
  /// to live that outlives one build.
  ({int done, int total, String name})? _merging;

  bool _mergeCancelRequested = false;

  /// The stranded rows last read, and the queue fingerprint they answer to:
  /// the disk is asked again only when a done row's file name or the folder
  /// moved — a running download rebuilds this pane on every tick, and each
  /// build must not walk the done list checking the disk.
  List<HongguoDownloadItem> _strandedCache = const [];
  String _strandedFingerprint = '';

  Future<void> _pickDirectory(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.settings.downloadDirectory);
      if (selected == null || selected.trim().isEmpty) return;
      final saved = await ref.read(storageFolderOverridesProvider.notifier).set(StorageFolder.shortDramas, selected);
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: saved ? t.settings.downloadDirectoryUpdated : t.settings.downloadDirectoryFailed,
        status: saved ? DsStatus.success : DsStatus.danger,
      );
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.settings.downloadDirectoryFailed, status: DsStatus.danger);
      }
    }
  }

  /// Brings the episodes the old shared folder still holds into this one.
  ///
  /// The controller renames on one volume and, across volumes, copies, measures
  /// and only then lets go of the source; this only says how many landed and
  /// which did not, and stops between files when asked. A row that did not move
  /// keeps naming where its file is, so an unfinished merge is a place to come
  /// back to rather than a list of dead paths.
  Future<void> _mergeStranded(List<HongguoDownloadItem> stranded) async {
    final t = context.t;
    final confirmed = await showAppConfirm(
      context: context,
      title: t.settings.downloadMergeTitle,
      description: t.settings.downloadMergeBody(count: stranded.length),
      confirmLabel: t.settings.downloadMerge,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _merging = (done: 0, total: stranded.length, name: '');
      _mergeCancelRequested = false;
    });
    final result = await ref
        .read(hongguoDownloadsProvider.notifier)
        .mergeStranded(
          stranded,
          onProgress: (done, total, name) {
            if (mounted) setState(() => _merging = (done: done, total: total, name: name));
          },
          cancelled: () => _mergeCancelRequested,
        )
        .whenComplete(() {
          if (mounted) setState(() => _merging = null);
        });
    if (!mounted) return;
    showDsToast(
      context: context,
      title: result.failed == 0
          ? t.settings.downloadMergeDone(count: result.moved)
          : t.settings.downloadMergePartial(moved: result.moved, failed: result.failed),
      status: result.failed == 0 ? DsStatus.success : DsStatus.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tasks = ref.watch(hongguoDownloadsProvider);
    final lanes = ref.watch(hongguoDownloadSettingsProvider);
    final quality = ref.watch(hongguoDownloadQualityProvider);
    final retry = ref.watch(hongguoDownloadRetryProvider);
    final retryDelay = ref.watch(hongguoDownloadRetryDelayProvider);
    final directory = ref.watch(appPathsProvider).shortDramas.path;
    // What the shared 视频 folder still holds from before dramas got a folder
    // of their own; read after the queue so a new download lands here too —
    // but only when that queue's done rows actually moved, not per tick.
    final fingerprint =
        '$directory|${[for (final task in tasks)
          if (task.phase == HongguoDownloadPhase.done) '${task.id}:${task.filePath}'].join(',')}';
    if (fingerprint != _strandedFingerprint) {
      _strandedFingerprint = fingerprint;
      _strandedCache = ref.read(hongguoDownloadsProvider.notifier).stranded();
    }
    final stranded = _strandedCache;
    final merging = _merging;
    final active = tasks
        .where((task) => task.phase == HongguoDownloadPhase.queued || task.phase == HongguoDownloadPhase.running)
        .length;
    // The bytes already on disk, the counter's second half.
    final finishedBytes = tasks
        .where((task) => task.phase == HongguoDownloadPhase.done)
        .fold<int>(0, (sum, task) => sum + (task.total > 0 ? task.total : task.received));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.downloadSettings),
          children: [
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.download),
              title: t.settings.downloadMaxConcurrent,
              description: t.settings.downloadMaxConcurrentDesc,
              value: lanes,
              options: [for (var count = 1; count <= 5; count++) DsSelectOption(value: count, label: '$count')],
              onChanged: (value) => ref.read(hongguoDownloadSettingsProvider.notifier).select(value),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.refreshCw),
              title: t.common.downloadRetried,
              description: t.common.downloadRetryDesc,
              value: retry,
              options: [
                for (final count in HongguoDownloadRetryController.choices)
                  DsSelectOption(
                    value: count,
                    label: count == 0 ? t.common.downloadRetryOff : t.common.downloadRetriedTimes(count: count),
                  ),
              ],
              onChanged: (value) => ref.read(hongguoDownloadRetryProvider.notifier).select(value),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.timer),
              title: t.common.downloadRetryDelay,
              description: t.common.downloadRetryDelayDesc,
              value: retryDelay,
              options: [
                for (final seconds in HongguoDownloadRetryDelayController.choices)
                  DsSelectOption(value: seconds, label: '${seconds}s'),
              ],
              // A row without a retry to wait between stays visible, greyed:
              // a missing row reads as a missing feature.
              onChanged: retry == 0
                  ? null
                  : (value) => ref.read(hongguoDownloadRetryDelayProvider.notifier).select(value),
            ),
            SettingsChoiceRow<HongguoQualityChoice>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.hongguo.downloadQuality,
              description: t.hongguo.downloadQualityDesc,
              value: quality,
              options: [
                for (final choice in HongguoQualityChoice.values) DsSelectOption(value: choice, label: choice.label(t)),
              ],
              onChanged: (value) => ref.read(hongguoDownloadQualityProvider.notifier).select(value),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.folderOpen),
              title: Text(t.settings.downloadDirectory),
              description: Text(directory, maxLines: 2, overflow: TextOverflow.ellipsis),
              showChevron: true,
              onPressed: () => unawaited(_pickDirectory(context, ref)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.settings.downloadDirectoryDefault),
              description: Text(t.settings.downloadDirectoryDefaultDesc),
              onPressed: () =>
                  unawaited(ref.read(storageFolderOverridesProvider.notifier).reset(StorageFolder.shortDramas)),
            ),
            // Only a queue that actually holds files elsewhere gets this line:
            // a verb with no object has no place to be pressed, and a greyed
            // one would only say louder that nothing is there.
            if (stranded.isNotEmpty || merging != null)
              DsListRow(
                leading: const DsIcon(DsIcons.merge),
                title: Text(t.settings.downloadMerge),
                description: Text(
                  merging == null
                      ? t.settings.downloadMergeDesc(count: stranded.length)
                      : t.settings.downloadMergeRunning(
                          done: merging.done + 1,
                          total: merging.total,
                          name: merging.name,
                        ),
                ),
                trailing: DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  // Running, the same line's one verb turns into the way out;
                  // idle with nothing to move, the row is not drawn at all.
                  onPressed: merging == null
                      ? () => unawaited(_mergeStranded(stranded))
                      : () => setState(() => _mergeCancelRequested = true),
                  child: Text(merging == null ? t.settings.downloadMerge : t.common.cancel),
                ),
              ),
          ],
        ),
        // The queue is one row and one tap away, on the station's own 下载管理
        // page: this pane drew the same episodes a second time, with a weaker
        // summary and no table, so the same tasks read differently depending on
        // which door the viewer came through. Settings keeps the choices, the
        // count and the way out.
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.download),
              title: Text(t.settings.downloadManagerTitle),
              description: Text(
                [
                  t.settings.downloadTaskCount(count: tasks.length, active: active),
                  if (finishedBytes > 0) formatDownloadBytes(finishedBytes),
                  directory,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              showChevron: true,
              onPressed: () => openModuleItem(context, ref, NavigationItem.hongguoDownloads),
            ),
          ],
        ),
      ],
    );
  }
}

/// The remaining time the caption carries when it can be computed at all:
/// a known speed and bytes still owed — otherwise the fact is left out
/// rather than guessed. The spelling is the app's one download eta, so
/// every manager's queue reads the same.
String? _etaOf(Translations t, {required int speed, required int total, required int received}) {
  if (speed <= 0 || received >= total) return null;
  return t.settings.downloadEta(time: downloadEtaText(Duration(seconds: (total - received) ~/ speed)));
}

/// The station's download manager as its own page: the queue as a table with
/// its search, its states and its batch verbs, the finished episodes opened in
/// the app's own preview, and the folder they land in.
///
/// A window too narrow for a table's columns keeps the row cards the station
/// already drew: an episode's caption, its progress bar and the drama its head
/// names say more there than four ellipsised cells would.
final class HongguoDownloadsPage extends ConsumerStatefulWidget {
  /// The download manager, opening on the whole queue.
  const HongguoDownloadsPage({super.key});

  @override
  ConsumerState<HongguoDownloadsPage> createState() => _HongguoDownloadsPageState();
}

final class _HongguoDownloadsPageState extends ConsumerState<HongguoDownloadsPage> {
  /// What the search box holds, matched against the drama, the episode and the
  /// file the queue wrote.
  String _query = '';

  /// The state tab the queue is cut to; all reads as every state.
  DownloadStatusGroup _statusGroup = DownloadStatusGroup.all;

  /// Whether a row must still name a file the disk holds.
  bool _playableOnly = false;

  /// The row the wide window's facts column speaks about; null lets the first
  /// visible row speak.
  String? _factsId;

  /// The rows on screen: searched, cut to the ticked phases, and to the files
  /// still on disk when that is ticked — in the order the store keeps them, so
  /// the table's own sort is the only thing that reorders a queue.
  List<HongguoDownloadItem> _visible(List<HongguoDownloadItem> tasks) {
    final query = _query.trim().toLowerCase();
    return [
      for (final task in tasks)
        if ((_statusGroup == DownloadStatusGroup.all ||
                downloadRowGroupOf(_hongguoRowPhase(task.phase, missing: _hongguoFileMissing(task))) == _statusGroup) &&
            (!_playableOnly || (task.phase == HongguoDownloadPhase.done && downloadFilePresent(task.filePath))) &&
            (query.isEmpty ||
                task.title.toLowerCase().contains(query) ||
                task.part.toLowerCase().contains(query) ||
                task.fileName.toLowerCase().contains(query)))
          task,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tasks = ref.watch(hongguoDownloadsProvider);
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    final directory = ref.watch(appPathsProvider).shortDramas.path;
    // The facts column states a failed row's retry wait, so the page follows
    // the two settings that decide it.
    final retry = ref.watch(hongguoDownloadRetryProvider);
    final retryDelay = ref.watch(hongguoDownloadRetryDelayProvider);
    final shown = _visible(tasks);
    // One stat per visible row per read, not one per cell: the same episode
    // answers through its badge, its verb and its menu, and asking the disk
    // three times for one row is how a queue of thirty episodes starts to cost
    // a frame.
    final missing = {for (final task in shown) task.id: _hongguoFileMissing(task)};
    final moving = tasks
        .where((task) => task.phase == HongguoDownloadPhase.queued || task.phase == HongguoDownloadPhase.running)
        .length;
    final stopped = tasks.any(
      (task) => task.phase == HongguoDownloadPhase.paused || task.phase == HongguoDownloadPhase.failed,
    );
    final finished = tasks.where((task) => task.phase == HongguoDownloadPhase.done).toList();
    // What the queue has already put on disk, the summary's second half.
    final finishedBytes = finished.fold<int>(0, (sum, task) => sum + (task.total > 0 ? task.total : task.received));
    // What it is pulling right now, its third half: the lanes' own total, so a
    // running row's speed is not asked of every row to be read once.
    final speed = tasks.fold<int>(0, (sum, task) => sum + task.speed);
    final factsTask = shown.where((task) => task.id == _factsId).firstOrNull ?? (shown.isEmpty ? null : shown.first);
    final filterActive = _statusGroup != DownloadStatusGroup.all || _playableOnly;
    final counts = <DownloadStatusGroup, int>{
      for (final group in DownloadStatusGroup.values)
        group: group == DownloadStatusGroup.all
            ? tasks.length
            : tasks
                  .where(
                    (task) =>
                        downloadRowGroupOf(_hongguoRowPhase(task.phase, missing: _hongguoFileMissing(task))) == group,
                  )
                  .length,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // The facts column rides beside the queue where the rows keep their
        // reading after 340 pixels are taken from them.
        final withFacts = width >= LiveWindow.downloadWorkspace;
        // A head over no rows is not a queue at all, so the empty state stays
        // the card list's own.
        final queue = shown.isEmpty ? _empty(t, tasks, directory, filterActive) : _cards(shown, missing);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, DsSpace.s12, _inset, DsSpace.s8),
              child: DownloadQueueHeader(
                summary: [
                  t.settings.downloadTaskCount(count: tasks.length, active: moving),
                  if (finishedBytes > 0) formatDownloadBytes(finishedBytes),
                  if (speed > 0) t.common.downloadSpeed(speed: '${formatDownloadBytes(speed)}/s'),
                ].join(' · '),
                settingsLabel: t.settings.downloadSettings,
                onSettings: () {
                  openSettingsSection(ref, SettingsSection.hongguoDownload);
                  unawaited(context.push(SettingsSectionRoute(section: SettingsSection.hongguoDownload.name).location));
                },
                searchHint: t.settings.downloadSearchPlaceholder,
                query: _query,
                onQuery: (value) => setState(() => _query = value),
                actions: [
                  DownloadQueueAction(
                    label: t.settings.downloadManagerOpenFolder,
                    icon: DsIcons.folderOpen,
                    onPressed: () => unawaited(openDownloadedPath(context, directory)),
                  ),
                  if (moving > 0)
                    DownloadQueueAction(
                      label: t.settings.downloadPauseAll,
                      icon: DsIcons.pause,
                      onPressed: () => unawaited(controller.pauseAll()),
                    ),
                  if (stopped)
                    DownloadQueueAction(
                      label: t.settings.downloadResumeAll,
                      icon: DsIcons.play,
                      onPressed: () => unawaited(controller.resumeAll()),
                    ),
                  if (finished.isNotEmpty)
                    DownloadQueueAction(
                      label: t.settings.downloadClearFinished,
                      icon: DsIcons.trash2,
                      destructive: true,
                      onPressed: () => unawaited(
                        confirmClearFinished(
                          context,
                          title: t.settings.downloadClearFinished,
                          clear: controller.clearFinished,
                        ),
                      ),
                    ),
                  DownloadQueueAction(
                    label: t.settings.downloadRecheck,
                    icon: DsIcons.refresh,
                    // The recheck is the rebuild itself: the live store's
                    // stat is asked once more as the rows re-render.
                    onPressed: () => setState(() {}),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, 0, _inset, DsSpace.s8),
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: DownloadStatusTabs<DownloadStatusGroup>(
                      value: _statusGroup,
                      semanticLabel: t.settings.downloadFilterLabel,
                      onChanged: (group) => setState(() => _statusGroup = group),
                      tabs: [
                        for (final group in DownloadStatusGroup.values)
                          DownloadStatusTab(group, _statusTabLabel(t, group), counts[group] ?? 0),
                      ],
                    ),
                  ),
                  DsChip(
                    label: Text(t.settings.downloadFilterPlayable),
                    selected: _playableOnly,
                    onChanged: (on) => setState(() => _playableOnly = on),
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
                      // The twin manager's facts pane keeps a right and
                      // bottom gutter so the card's shadow has somewhere to
                      // fall; this one sat flush to the window's edge.
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(0, 0, DsSpace.s20, DsSpace.s24),
                        child: DownloadDetailsPane(
                          details: factsTask == null
                              ? null
                              : _detailsOf(
                                  context,
                                  factsTask,
                                  t,
                                  retryLimit: retry,
                                  retryDelay: retryDelay,
                                  retryPending: controller.hasPendingRetry(factsTask.id),
                                  onRemove: () => unawaited(_removeRecord(context, ref, factsTask.id)),
                                ),
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

  /// The queue as the row cards: one block per drama, its head naming the drama
  /// and carrying the verbs for the episodes it holds.
  Widget _cards(List<HongguoDownloadItem> shown, Map<String, bool> missing) => ListView(
    padding: EdgeInsets.only(left: _inset, right: _inset, bottom: DsSpace.s16),
    children: [
      for (final group in _hongguoDownloadGroups(shown)) ...[
        _HongguoSeriesHead(group: group),
        DsListSection(
          children: [
            for (final task in group.tasks) _hongguoTaskCard(context, ref, task, missing: missing[task.id] ?? false),
          ],
        ),
      ],
    ],
  );

  /// Where the page keeps its own margin: the head and the queue read the same
  /// number, so their left edges line up.
  double get _inset => LiveWindow.pageInset(MediaQuery.sizeOf(context).width);

  /// Nothing on screen: what the queue holds in total answers better than an
  /// empty table would, because a filtered-out task is still a task the viewer
  /// has to un-tick to see — and the un-ticking is offered here rather than
  /// left for the filter panel, the way the music queue's empty page does it.
  Widget _empty(Translations t, List<HongguoDownloadItem> tasks, String directory, bool filterActive) => Center(
    child: DsEmptyState(
      icon: const DsIcon(DsIcons.download),
      title: Text(tasks.isEmpty ? t.hongguo.downloadEmpty : t.settings.downloadFilterEmpty),
      description: Text(tasks.isEmpty ? t.hongguo.downloadEmptyDesc : t.hongguo.downloadFilterEmptyDesc),
      actions: [
        if (filterActive)
          DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.filter, size: 14),
            onPressed: () => setState(() {
              _statusGroup = DownloadStatusGroup.all;
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

/// The preview page's list for the hongguo queue: every episode that finished,
/// in the queue's own order — the same grammar the station's downloads and the
/// recording centre hand the page, with no danmaku beside it because the
/// platform has none to save. An episode whose file was cleaned out stays in
/// the list; the page greys it and says the file is gone.
List<MediaPreviewItem> _hongguoPreviewItems(List<HongguoDownloadItem> tasks) {
  final items = <MediaPreviewItem>[];
  for (final task in tasks) {
    if (task.phase != HongguoDownloadPhase.done) continue;
    items.add(
      MediaPreviewItem(
        id: task.id,
        title: task.part.isEmpty ? task.title : '${task.title} · ${task.part}',
        path: task.filePath,
        subtitle: [
          task.qualityLabel,
          if (task.total > 0) formatDownloadBytes(task.total),
          downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp)),
        ].join(' · '),
        cover: task.cover,
        // The list groups by the show this part belongs to, so thirty episodes
        // of two series read as two blocks with their own folder action rather
        // than as one numbered run the viewer has to count by hand.
        groupPath: p.dirname(task.filePath),
        groupLabel: task.title,
      ),
    );
  }
  return items;
}

/// One drama's block of the queue: its name, its poster where the queue kept
/// one, and the episodes this list holds of it.
final class _HongguoDownloadGroup {
  _HongguoDownloadGroup({required this.title, required this.cover, required this.parts, required this.tasks});

  /// The series' name, written once for the block.
  final String title;

  /// The series' poster; the first task in the block that carries one.
  String cover;

  /// How many episodes the series lists — the queue keeps it per task, and a
  /// block reads as a part of a whole only when the whole is more than one.
  final int parts;

  /// The episodes, in the queue's own order.
  final List<HongguoDownloadItem> tasks;
}

/// The queue read by series: one block per drama, in the order the list first
/// names one, the episodes inside a block kept as the list has them. The
/// station's own 我的下载 lists dramas and opens a drama's episodes from there;
/// a flat list of episodes writes the same drama's name once per row — thirty
/// times for one take — and gives no line to read the take from.
List<_HongguoDownloadGroup> _hongguoDownloadGroups(Iterable<HongguoDownloadItem> tasks) {
  final order = <String>[];
  final blocks = <String, _HongguoDownloadGroup>{};
  for (final task in tasks) {
    final key = task.seriesId.isEmpty ? task.title : task.seriesId;
    final block = blocks[key];
    if (block == null) {
      blocks[key] = _HongguoDownloadGroup(title: task.title, cover: task.cover, parts: task.parts, tasks: [task]);
      order.add(key);
    } else {
      block.tasks.add(task);
      // A task queued before the queue kept posters still names its drama;
      // the first picture the block holds is the block's.
      if (block.cover.isEmpty) block.cover = task.cover;
    }
  }
  return [for (final key in order) blocks[key]!];
}

/// The line over one drama's episodes: its poster where the queue has one, its
/// name once for the block, how many of the drama this block holds, and the
/// verbs that act on the whole block. A thirty-episode take whose every action
/// sits on the row is thirty taps, and a page that counts tasks for the whole
/// queue and for none of its parts is a flat list wearing group headers.
final class _HongguoSeriesHead extends ConsumerWidget {
  const _HongguoSeriesHead({required this.group});

  /// The block being introduced.
  final _HongguoDownloadGroup group;

  /// Runs [verb] over every id it was handed. The store writes per task, so
  /// the ids go one after another rather than all at once.
  Future<void> _apply(
    WidgetRef ref,
    List<String> ids,
    Future<void> Function(HongguoDownloadsController controller, String id) verb,
  ) async {
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    for (final id in ids) {
      await verb(controller, id);
    }
  }

  /// The block's own phases, read when the action is asked for rather than
  /// when the line was painted: a task that finished in between is no longer
  /// something to pause.
  ({List<String> pausable, List<String> resumable}) _phases() => (
    pausable: [
      for (final task in group.tasks)
        if (task.phase == HongguoDownloadPhase.running || task.phase == HongguoDownloadPhase.queued) task.id,
    ],
    resumable: [
      for (final task in group.tasks)
        if (task.phase == HongguoDownloadPhase.paused || task.phase == HongguoDownloadPhase.failed) task.id,
    ],
  );

  Future<void> _removeBlock(BuildContext context, WidgetRef ref, Translations t) async {
    final ids = [for (final task in group.tasks) task.id];
    final phases = _phases();
    final confirmed = await showAppConfirm(
      context: context,
      title: t.settings.downloadRemove,
      // Which drama, and how many of its tasks: the row's own body says 这条
      // 记录, and a block would be answering for thirty of them.
      description:
          '${group.title} · ${t.settings.downloadTaskCount(count: ids.length, active: phases.pausable.length)}',
      confirmLabel: t.settings.downloadRemove,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    // The tap can land after the dialog's host is gone (the queue rebuilt
    // under it); a dead context must not reach the page's store.
    if (!confirmed || !context.mounted) return;
    await _apply(ref, ids, (controller, id) => controller.remove(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final phases = _phases();
    // How far this block reaches into its drama, read three ways: a partial
    // block counts itself against the whole (「12集/60集」), a whole block keeps
    // its plain 全60集 — that block *is* the drama, no ratio to read — and a
    // stored total left behind by a serial that grew since the first task was
    // queued says only the bare count. A one-episode drama has nothing to be a
    // part of, and says nothing at all.
    final scale = switch ((group.tasks.length, group.parts)) {
      (final _, final total) when total <= 1 => null,
      (final held, final total) when held == total => t.hongguo.allEpisodesCount(count: total),
      (final held, final total) when held < total => t.hongguo.downloadHeldOfTotal(held: held, total: total),
      (final held, final _) => t.hongguo.episodesCount(count: held),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, DsSpace.s12, 0, DsSpace.s4),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          if (group.cover.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.control(28)),
              child: SizedBox(
                width: 28,
                height: 28,
                child: DsImage(
                  image: hongguoCoverImage(group.cover, width: 56, height: 56),
                  aspectRatio: 1,
                  semanticLabel: group.title,
                  fallback: ColoredBox(color: colors.control),
                ),
              ),
            ),
          Expanded(
            child: Text(
              group.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
            ),
          ),
          // The block's own reach into its drama, decided above: a head that
          // names only the drama's scale makes two blocks of one drama look
          // identical.
          if (scale case final text?) Text(text, style: theme.typography.caption.copyWith(color: colors.textMuted)),
          // One episode in the block is the row's own business; a verb with a
          // single object does not need a second place to be pressed, and a
          // head that greyed out an inapplicable switch would only say so
          // louder than the row already does.
          if (group.tasks.length > 1)
            DsMenuAnchor(
              semanticLabel: group.title,
              align: DsAlign.end,
              items: [
                if (phases.pausable.isNotEmpty)
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.pause),
                    label: Text(t.settings.downloadPause),
                    onPressed: () => unawaited(_apply(ref, phases.pausable, (controller, id) => controller.pause(id))),
                  ),
                if (phases.resumable.isNotEmpty)
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.play),
                    label: Text(t.settings.downloadResume),
                    onPressed: () =>
                        unawaited(_apply(ref, phases.resumable, (controller, id) => controller.resume(id))),
                  ),
                if (phases.pausable.isNotEmpty || phases.resumable.isNotEmpty) const DsMenuDivider(),
                DsMenuItem(
                  leading: const DsIcon(DsIcons.trash2),
                  label: Text(t.settings.downloadRemove),
                  destructive: true,
                  onPressed: () => unawaited(_removeBlock(context, ref, t)),
                ),
              ],
              builder: (context, anchor, _) => DsButton.icon(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                semanticLabel: group.title,
                onPressed: anchor.toggle,
                icon: const DsIcon(DsIcons.ellipsisVertical, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

/// The facts the right column, the 详情 sheet and the row's own caption show
/// for [task] — one construction, so the three cannot drift. [retryLimit] and
/// [retryDelay] let a failed row say when the queue will come back for it
/// instead of leaving the wait silent.
DownloadDetails _detailsOf(
  BuildContext context,
  HongguoDownloadItem task,
  Translations t, {
  int retryLimit = 0,
  int retryDelay = 0,
  bool retryPending = false,
  VoidCallback? onRemove,
}) {
  final total = task.total;
  // One stat, and only for a row that claims a finished file.
  final missing = _hongguoFileMissing(task);
  // A failed row says what went wrong and, when the queue still owes it an
  // automatic retry, how long the wait is.
  final failedBase = (task.error ?? '').trim().isEmpty
      ? t.settings.downloadStatusFailed
      : '${t.settings.downloadStatusFailed} · ${task.error!.trim()}';
  final retryWait = retryPending && retryLimit > 0
      ? ' · ${t.common.downloadRetryPending(delay: retryDelay, left: (retryLimit - task.attempts).clamp(0, 1 << 20))}'
      : '';
  final caption = switch (task.phase) {
    HongguoDownloadPhase.queued => t.settings.downloadStatusQueued,
    HongguoDownloadPhase.running when total > 0 => [
      t.settings.downloadPercent(percent: '${task.received * 100 ~/ total}'),
      '${formatDownloadBytes(task.speed)}/s',
      '${formatDownloadBytes(task.received)} / ${formatDownloadBytes(total)}',
      ?_etaOf(t, speed: task.speed, total: total, received: task.received),
    ].join(' · '),
    HongguoDownloadPhase.running => t.settings.downloadPercentUnknown,
    HongguoDownloadPhase.paused when total > 0 =>
      '${t.settings.downloadStatusPaused} · ${task.received * 100 ~/ total}% · ${formatDownloadBytes(task.received)} / ${formatDownloadBytes(total)}',
    HongguoDownloadPhase.paused => t.settings.downloadStatusPaused,
    HongguoDownloadPhase.failed => '$failedBase$retryWait',
    // The record says the transfer finished; only the disk says whether the
    // file is still there. A row whose episode was moved or deleted says so in
    // the same place its 已完成 used to stand alone.
    HongguoDownloadPhase.done =>
      '${missing ? t.common.previewFileMissing : t.settings.downloadStatusDone} · '
          '${formatDownloadBytes(total > 0 ? total : task.received)}'
          ' · ${downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp))}',
  };
  return DownloadDetails(
    title: task.title,
    part: task.part,
    coverUrl: task.cover,
    status: caption,
    savePath: task.filePath,
    queuedAt: downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp)),
    retries: task.attempts,
    error: task.error ?? '',
    fileMissing: missing,
    onOpenFile: task.phase == HongguoDownloadPhase.done && !missing
        ? () => unawaited(openDownloadedPath(context, task.filePath))
        : null,
    onOpenFolder: () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path)),
    onRemove: onRemove,
  );
}

/// One episode's row, as the shared download row draws it — the state as a
/// badge beside the rendition that came down, the facts under it, the one
/// verb its phase allows and the menu with the rest. The poster belongs to
/// the block header above, so the row carries no picture of its own.
Widget _hongguoTaskCard(BuildContext context, WidgetRef ref, HongguoDownloadItem task, {required bool missing}) {
  final t = context.t;
  final controller = ref.read(hongguoDownloadsProvider.notifier);
  final total = task.total;
  final fraction = total > 0 ? (task.received / total).clamp(0.0, 1.0) : null;
  final moving = task.phase == HongguoDownloadPhase.running || task.phase == HongguoDownloadPhase.paused;
  final caption = '${_detailsOf(context, task, t).status} · ${task.qualityLabel}';
  final phase = _hongguoRowPhase(task.phase, missing: missing);
  final label = _hongguoEpisodeLabel(t, task);
  Future<void> deleteFile() async {
    final confirmed = await showAppConfirm(
      context: context,
      title: t.settings.downloadDeleteFile,
      description: t.settings.downloadDeleteFileBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await controller.remove(task.id, deleteFile: true);
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.settings.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
  }

  return DownloadTaskCard(
    key: ValueKey(task.id),
    title: label,
    phase: phase,
    caption: caption,
    fraction: fraction,
    showProgress: moving && (fraction != null || task.received > 0),
    progressLabel: task.fileName,
    playable: task.phase == HongguoDownloadPhase.done,
    actions: DownloadRowActions(
      onPause: task.phase == HongguoDownloadPhase.running ? () => unawaited(controller.pause(task.id)) : null,
      onResume: task.phase == HongguoDownloadPhase.queued || task.phase == HongguoDownloadPhase.paused
          ? () => unawaited(controller.resume(task.id))
          : null,
      onRetry: task.phase == HongguoDownloadPhase.failed ? () => unawaited(controller.resume(task.id)) : null,
      onPlay: task.phase == HongguoDownloadPhase.done ? () => unawaited(_openHongguoPreview(context, ref, task)) : null,
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
      onOpenFile: task.phase == HongguoDownloadPhase.done && !missing
          ? () => unawaited(openDownloadedPath(context, task.filePath))
          : null,
      onOpenFolder: task.phase == HongguoDownloadPhase.done
          ? () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path))
          : null,
      onDeleteFile: task.phase == HongguoDownloadPhase.done && !missing ? () => unawaited(deleteFile()) : null,
    ),
  );
}

/// The tier a row names: the height that actually came down once the run
/// picked one, the requested ceiling until then.
///
/// The two are not the same thing — an anonymous session is served the
/// website's own 360 copy no matter which ceiling the viewer chose, and a
/// finished row that kept printing the ceiling would claim a picture it never
/// downloaded.
extension on HongguoDownloadItem {
  String get qualityLabel => '${servedHeight > 0 ? servedHeight : maxHeight}P';
}
