import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/boot/storage_providers.dart'
    show appPathsProvider, storageFolderOverridesProvider;
import 'package:pure_live/app/providers/settings/storage_folder_provider.dart' show StorageFolder;
import 'package:pure_live/features/media_preview/media_preview_item.dart' show MediaPreviewItem;
import 'package:pure_live/features/media_preview/media_preview_page.dart' show openMediaPreview;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart'
    show confirmClearFinished, downloadStampOf, openDownloadedPath;
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openModuleItem;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_downloads.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart' show HongguoQualityChoice;
import 'package:pure_live/shared/shared.dart'
    show
        DownloadDetails,
        DownloadDetailsPane,
        DownloadQueueAction,
        DownloadQueueHeader,
        LiveWindow,
        NavigationItem,
        cachedImage,
        downloadFilePresent,
        formatDownloadBytes,
        showDownloadDetails;

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
  final confirmed = await showDsConfirm(
    context: context,
    title: t.settings.downloadRemove,
    description: t.settings.downloadRemoveBody,
    confirmLabel: t.settings.downloadRemove,
    cancelLabel: t.common.cancel,
    destructive: true,
    icon: const DsIcon(DsIcons.trash2),
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

/// The phase's own word, said the same way in a row's badge and in the filter
/// panel: one phase, one spelling.
String _hongguoPhaseLabel(Translations t, HongguoDownloadPhase phase) => switch (phase) {
  HongguoDownloadPhase.queued => t.hongguo.downloadPhaseQueued,
  HongguoDownloadPhase.running => t.hongguo.downloadingUnknown,
  HongguoDownloadPhase.paused => t.hongguo.downloadPhasePaused,
  HongguoDownloadPhase.failed => t.hongguo.downloadPhaseFailed,
  HongguoDownloadPhase.done => t.hongguo.downloadPhaseDone,
};

/// The phases in the order a queue reads: what is moving, what waits for a
/// lane, what stopped on purpose, what stopped on its own, what landed.
int _hongguoPhaseRank(HongguoDownloadPhase phase) => switch (phase) {
  HongguoDownloadPhase.running => 0,
  HongguoDownloadPhase.queued => 1,
  HongguoDownloadPhase.paused => 2,
  HongguoDownloadPhase.failed => 3,
  HongguoDownloadPhase.done => 4,
};

/// What a row's phase says about itself, as the table's state column shows it:
/// the phase, and how far a transfer still owed bytes has got. The phase's name
/// comes from [_hongguoPhaseLabel], the same words the filter panel lists it by,
/// so one phase is not said two ways on one page.
Widget _hongguoPhaseBadge(BuildContext context, HongguoDownloadItem task, {required bool missing}) {
  final t = context.t;
  // A finished row whose file the viewer moved or deleted is said here, in the
  // same words the row's own caption and the facts column use: the record is
  // true of the transfer, not of the disk.
  if (task.phase == HongguoDownloadPhase.done && missing) {
    return DsBadge(status: DsStatus.danger, label: Text(t.common.previewFileMissing));
  }
  // An episode that never got its total only says it is moving.
  if (task.phase == HongguoDownloadPhase.running && task.total > 0) {
    return DsBadge(
      status: DsStatus.info,
      label: Text(t.hongguo.downloading(percent: '${task.received * 100 ~/ task.total}')),
    );
  }
  return DsBadge(
    status: switch (task.phase) {
      HongguoDownloadPhase.done => DsStatus.success,
      HongguoDownloadPhase.running => DsStatus.info,
      HongguoDownloadPhase.paused => DsStatus.warning,
      HongguoDownloadPhase.failed => DsStatus.danger,
      HongguoDownloadPhase.queued => DsStatus.neutral,
    },
    label: Text(_hongguoPhaseLabel(t, task.phase)),
  );
}

/// The one verb an episode's phase allows: stop a transfer, carry a waiting or
/// stopped one on, fetch a failed one again, or watch the episode that landed.
///
/// The card and the table name the same verb for the same phase and say it the
/// same way, so the two shapes cannot drift apart; everything else a row can do
/// sits in [_hongguoRowMenu].
Widget _hongguoPhaseVerb(BuildContext context, WidgetRef ref, HongguoDownloadItem task, {required bool missing}) {
  final t = context.t;
  final controller = ref.read(hongguoDownloadsProvider.notifier);
  return switch (task.phase) {
    HongguoDownloadPhase.running => DsButton.icon(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      icon: const DsIcon(DsIcons.pause),
      semanticLabel: t.settings.downloadPause,
      onPressed: () => unawaited(controller.pause(task.id)),
    ),
    HongguoDownloadPhase.queued || HongguoDownloadPhase.paused => DsButton.icon(
      size: DsSize.sm,
      icon: const DsIcon(DsIcons.play),
      semanticLabel: t.settings.downloadResume,
      onPressed: () => unawaited(controller.resume(task.id)),
    ),
    HongguoDownloadPhase.failed => DsButton.icon(
      size: DsSize.sm,
      icon: const DsIcon(DsIcons.rotateCw),
      semanticLabel: t.common.retry,
      onPressed: () => unawaited(controller.resume(task.id)),
    ),
    // An episode whose file is gone has nothing to preview: the button keeps
    // its place, shows what happened and stays out of reach, so the row cannot
    // promise an opening that only fails.
    HongguoDownloadPhase.done => DsButton.icon(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      icon: DsIcon(missing ? DsIcons.fileX : DsIcons.play),
      semanticLabel: missing ? t.common.previewFileMissing : t.settings.backgroundPreviewMedia,
      onPressed: missing ? null : () => unawaited(_openHongguoPreview(context, ref, task)),
    ),
  };
}

/// Everything one episode can be asked for beyond its phase's own verb.
///
/// The card's trailing menu and the table's row menu read the same list: 详情,
/// and for a finished episode the file's own ways out — open it, open the
/// folder beside it, delete it — ending in the record's removal. An episode
/// whose file went away keeps the folder (what is left beside it is still worth
/// seeing) and drops the two verbs that act on a file that is not there.
List<Widget> _hongguoRowMenu(BuildContext context, WidgetRef ref, HongguoDownloadItem task, {required bool missing}) {
  final t = context.t;
  final controller = ref.read(hongguoDownloadsProvider.notifier);
  Future<void> deleteFile() async {
    final confirmed = await showDsConfirm(
      context: context,
      title: t.hongguo.downloadDeleteFile,
      description: t.hongguo.downloadDeleteFileBody,
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
        showDsToast(context: context, title: t.hongguo.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
  }

  return [
    DsMenuItem(
      leading: const DsIcon(DsIcons.info),
      label: Text(t.common.downloadDetails),
      onPressed: () => unawaited(
        showDownloadDetails(
          context,
          _detailsOf(
            context,
            task,
            t,
            retryLimit: ref.read(hongguoDownloadRetryProvider),
            retryDelay: ref.read(hongguoDownloadRetryDelayProvider),
            retryPending: controller.hasPendingRetry(task.id),
            onRemove: () => unawaited(_removeRecord(context, ref, task.id)),
          ),
        ),
      ),
    ),
    const DsMenuDivider(),
    if (task.phase == HongguoDownloadPhase.done) ...[
      if (!missing)
        DsMenuItem(
          leading: const DsIcon(DsIcons.externalLink),
          label: Text(t.settings.downloadOpenFile),
          onPressed: () => unawaited(openDownloadedPath(context, task.filePath)),
        ),
      DsMenuItem(
        leading: const DsIcon(DsIcons.folderOpen),
        label: Text(t.settings.downloadManagerOpenFolder),
        onPressed: () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path)),
      ),
      if (!missing) ...[
        DsMenuItem(
          leading: const DsIcon(DsIcons.trash2),
          label: Text(t.hongguo.downloadDeleteFile),
          destructive: true,
          onPressed: () => unawaited(deleteFile()),
        ),
        const DsMenuDivider(),
      ],
    ],
    DsMenuItem(
      leading: const DsIcon(DsIcons.trash2),
      // Over a file that is not there, 移除记录 is the whole answer: the row is
      // the only thing left of the download.
      label: Text(missing ? t.common.downloadRemoveFromList : t.settings.downloadRemove),
      destructive: true,
      onPressed: () => unawaited(_removeRecord(context, ref, task.id)),
    ),
  ];
}

/// 下载管理 — the station's download settings under Settings → 红果短剧.
///
/// The pane carries the lanes, the retry budget, the download tier and the
/// folder the files land in, the one verb that brings what the shared 视频 folder
/// still holds into this folder, and one line that says how much the queue
/// holds and opens the station's own 下载管理 page ([HongguoDownloadsPage]).
/// Drawing the queue here as well made one thing two entrances, and the settings
/// half was the weaker: no speed, no table, no batch verbs.
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

  Future<void> _pickDirectory(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.hongguo.downloadDirectory);
      if (selected == null || selected.trim().isEmpty) return;
      final saved = await ref.read(storageFolderOverridesProvider.notifier).set(StorageFolder.shortDramas, selected);
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: saved ? t.hongguo.downloadDirectoryUpdated : t.hongguo.downloadDirectoryFailed,
        status: saved ? DsStatus.success : DsStatus.danger,
      );
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.hongguo.downloadDirectoryFailed, status: DsStatus.danger);
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
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadMergeTitle,
      description: t.settings.downloadMergeBody(count: stranded.length),
      confirmLabel: t.settings.downloadMerge,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.merge),
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
    // of their own; read after the queue so a new download lands here too.
    final stranded = ref.read(hongguoDownloadsProvider.notifier).stranded();
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
          header: Text(t.hongguo.downloadSettingsTitle),
          children: [
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.download),
              title: t.hongguo.downloadMaxConcurrent,
              description: t.hongguo.downloadMaxConcurrentDesc,
              value: lanes,
              options: [for (var count = 1; count <= 5; count++) DsSelectOption(value: count, label: '$count')],
              onChanged: (value) => ref.read(hongguoDownloadSettingsProvider.notifier).select(value),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.refreshCw),
              title: t.hongguo.downloadRetry,
              description: t.hongguo.downloadRetryDesc,
              value: retry,
              options: [
                for (final count in HongguoDownloadRetryController.choices)
                  DsSelectOption(
                    value: count,
                    label: count == 0 ? t.hongguo.downloadRetryOff : t.hongguo.downloadRetryTimes(count: count),
                  ),
              ],
              onChanged: (value) => ref.read(hongguoDownloadRetryProvider.notifier).select(value),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.timer),
              title: t.hongguo.downloadRetryDelay,
              description: t.hongguo.downloadRetryDelayDesc,
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
              title: Text(t.hongguo.downloadDirectory),
              description: Text(directory, maxLines: 2, overflow: TextOverflow.ellipsis),
              showChevron: true,
              onPressed: () => unawaited(_pickDirectory(context, ref)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.hongguo.downloadDirectoryDefault),
              description: Text(t.hongguo.downloadDirectoryDefaultDesc),
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
              title: Text(t.hongguo.downloadManagerTitle),
              description: Text(
                [
                  t.hongguo.downloadTaskCount(count: tasks.length, active: active),
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
/// rather than guessed.
String? _etaOf(Translations t, {required int speed, required int total, required int received}) {
  if (speed <= 0 || received >= total) return null;
  final seconds = (total - received) ~/ speed;
  final hours = seconds ~/ 3600;
  final mm = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final ss = (seconds % 60).toString().padLeft(2, '0');
  return t.hongguo.downloadEta(time: hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss');
}

/// The station's download manager as its own page: the queue as a table with
/// its search, its filters and its batch verbs, the finished episodes opened in
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

  /// The phases ticked in the panel; none ticked reads as every phase, so an
  /// empty set is the queue's own 全部 rather than a hidden filter.
  final Set<HongguoDownloadPhase> _phases = {};

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

  /// The rows on screen: searched, cut to the ticked phases, and to the files
  /// still on disk when that is ticked — in the order the store keeps them, so
  /// the table's own sort is the only thing that reorders a queue.
  List<HongguoDownloadItem> _visible(List<HongguoDownloadItem> tasks) {
    final query = _query.trim().toLowerCase();
    return [
      for (final task in tasks)
        if ((_phases.isEmpty || _phases.contains(task.phase)) &&
            (!_playableOnly || (task.phase == HongguoDownloadPhase.done && downloadFilePresent(task.filePath))) &&
            (query.isEmpty ||
                task.title.toLowerCase().contains(query) ||
                task.part.toLowerCase().contains(query) ||
                task.fileName.toLowerCase().contains(query)))
          task,
    ];
  }

  /// The ticked rows, in the queue's order.
  List<HongguoDownloadItem> _picked(List<HongguoDownloadItem> tasks) => [
    for (final task in tasks)
      if (_selected.contains(task.id)) task,
  ];

  /// Runs [verb] over [rows], one after another: the store writes per task, so
  /// a batch is a run of writes rather than a call of its own.
  Future<void> _runOver(
    List<HongguoDownloadItem> rows,
    Future<void> Function(HongguoDownloadsController controller, String id) verb,
  ) async {
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    for (final task in rows) {
      await verb(controller, task.id);
    }
  }

  /// Drops the ticked records after one ask; the files they name stay on disk,
  /// which is what the body says rather than leaves to be guessed.
  Future<void> _removePicked(List<HongguoDownloadItem> picked) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadDeleteSelected(count: picked.length),
      description: t.settings.downloadRemoveBody,
      confirmLabel: t.settings.downloadRemove,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    await _runOver(picked, (controller, id) => controller.remove(id));
    if (mounted) setState(_selected.clear);
  }

  /// Deletes the ticked episodes' files and records after one ask. The store's
  /// own remove answers for a file that already went away, and each failure is
  /// said rather than swallowed, so a batch that names more than the disk holds
  /// does not read as a clean run.
  Future<void> _deletePicked(List<HongguoDownloadItem> picked) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadDeleteSelected(count: picked.length),
      description: t.hongguo.downloadDeleteFileBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    for (final task in picked) {
      try {
        await controller.remove(task.id, deleteFile: true);
      } on Object {
        if (mounted) showDsToast(context: context, title: t.hongguo.downloadDeleteFailed, status: DsStatus.danger);
      }
    }
    if (mounted) setState(_selected.clear);
  }

  /// The queue's conditions, behind the head's one entry: which phases show and
  /// whether a row must still name a file the disk holds. Nothing else about a
  /// queue is a condition — where it lands is a setting, and its size is what
  /// the head already says.
  Future<void> _openFilter(List<HongguoDownloadItem> tasks) async {
    final t = context.t;
    final picked = {..._phases};
    var playable = _playableOnly;
    void apply() => setState(() {
      _phases
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
            for (final phase in HongguoDownloadPhase.values)
              DsListRow(
                title: Text(_hongguoPhaseLabel(t, phase)),
                detail: Text('${tasks.where((task) => task.phase == phase).length}'),
                trailing: DsCheckbox(
                  value: picked.contains(phase),
                  onChanged: (value) {
                    if (value == true) {
                      picked.add(phase);
                    } else {
                      picked.remove(phase);
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
    final tasks = ref.watch(hongguoDownloadsProvider);
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    final directory = ref.watch(appPathsProvider).shortDramas.path;
    // The facts column states a failed row's retry wait, so the page follows
    // the two settings that decide it.
    final retry = ref.watch(hongguoDownloadRetryProvider);
    final retryDelay = ref.watch(hongguoDownloadRetryDelayProvider);
    // A tick on a row the queue no longer holds no longer counts, and the batch
    // bar would otherwise promise an action on nothing.
    _selected.removeWhere((id) => !tasks.any((task) => task.id == id));
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
    final picked = _picked(tasks);
    final pausable = picked
        .where((task) => task.phase == HongguoDownloadPhase.running || task.phase == HongguoDownloadPhase.queued)
        .toList();
    final resumable = picked
        .where((task) => task.phase == HongguoDownloadPhase.paused || task.phase == HongguoDownloadPhase.failed)
        .toList();
    final factsTask = shown.where((task) => task.id == _factsId).firstOrNull ?? (shown.isEmpty ? null : shown.first);
    final filterActive = _phases.isNotEmpty || _playableOnly;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // The table starts where a queue's columns fit; below it the episodes
        // keep the row cards, with their caption and their bar.
        final asTable = width >= LiveWindow.table;
        // The facts column rides beside a table only where the table still
        // keeps its columns after 340 pixels are taken from it.
        final withFacts = width >= LiveWindow.downloadWorkspace;
        // A table says it has nothing through its own slot; the card list
        // needs the page's empty state, because a head over no rows is not a
        // queue at all.
        final queue = asTable
            ? _table(
                t,
                shown,
                narrow: width < 720,
                withFacts: withFacts,
                filterActive: filterActive,
                tasks: tasks,
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
                  t.hongguo.downloadTaskCount(count: tasks.length, active: moving),
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
                  if (moving > 0)
                    DownloadQueueAction(
                      label: t.hongguo.downloadPauseAll,
                      icon: DsIcons.pause,
                      onPressed: () => unawaited(controller.pauseAll()),
                    ),
                  if (stopped)
                    DownloadQueueAction(
                      label: t.hongguo.downloadResumeAll,
                      icon: DsIcons.play,
                      onPressed: () => unawaited(controller.resumeAll()),
                    ),
                  if (finished.isNotEmpty)
                    DownloadQueueAction(
                      label: t.hongguo.downloadClearFinished,
                      icon: DsIcons.trash2,
                      destructive: true,
                      onPressed: () => unawaited(
                        confirmClearFinished(
                          context,
                          title: t.hongguo.downloadClearFinished,
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
                      label: t.settings.downloadPause,
                      icon: DsIcons.pause,
                      onPressed: () => unawaited(_runOver(pausable, (controller, id) => controller.pause(id))),
                    ),
                  if (resumable.isNotEmpty)
                    DownloadQueueAction(
                      label: t.settings.downloadResume,
                      icon: DsIcons.play,
                      onPressed: () => unawaited(_runOver(resumable, (controller, id) => controller.resume(id))),
                    ),
                  DownloadQueueAction(
                    label: t.settings.downloadRemove,
                    icon: DsIcons.trash2,
                    destructive: true,
                    onPressed: () => unawaited(_removePicked(picked)),
                  ),
                  if (picked.any((task) => task.phase == HongguoDownloadPhase.done))
                    DownloadQueueAction(
                      label: t.hongguo.downloadDeleteFile,
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
                                retryLimit: retry,
                                retryDelay: retryDelay,
                                retryPending: controller.hasPendingRetry(factsTask.id),
                                onRemove: () => unawaited(_removeRecord(context, ref, factsTask.id)),
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
  Widget _cards(List<HongguoDownloadItem> shown) => ListView(
    padding: EdgeInsets.only(left: _inset, right: _inset, bottom: DsSpace.s16),
    children: [
      for (final group in _hongguoDownloadGroups(shown)) ...[
        _HongguoSeriesHead(group: group),
        DsListSection(
          children: [for (final task in group.tasks) _HongguoTaskRow(key: ValueKey(task.id), task: task)],
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
      title: Text(tasks.isEmpty ? t.hongguo.downloadEmpty : t.hongguo.downloadFilterEmpty),
      description: Text(tasks.isEmpty ? t.hongguo.downloadEmptyDesc : t.hongguo.downloadFilterEmptyDesc),
      actions: [
        if (filterActive)
          DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.filter, size: 14),
            onPressed: () => setState(() {
              _phases.clear();
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

  /// The queue as a table: the episode and what became of it, then the bytes,
  /// the moment and the one verb its phase allows.
  ///
  /// A narrow table drops the two columns a row can do without, and pressing a
  /// row is the facts column's own verb — so a window with no facts column lets
  /// a click do what its checkbox does.
  Widget _table(
    Translations t,
    List<HongguoDownloadItem> rows, {
    required bool narrow,
    required bool withFacts,
    required bool filterActive,
    required List<HongguoDownloadItem> tasks,
    required bool Function(HongguoDownloadItem task) isMissing,
  }) {
    final theme = DsTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, 0, _inset, DsSpace.s12),
      child: DsTable<HongguoDownloadItem>(
        semanticLabel: t.hongguo.downloadManagerTitle,
        style: const DsTableStyle(rowHeight: 56),
        rowsVersion: _recheck,
        columns: [
          DsTableColumn<HongguoDownloadItem>(
            id: 'name',
            label: t.settings.downloadColumnFile,
            value: (task) => task.title,
            sortable: true,
            width: const DsTableColumnWidth.flex(3, 160),
            // Two lines, as the library's rows do: the drama the episode
            // belongs to over the episode itself, which is the half a queue of
            // thirty rows actually differs on. A table has no block heads, so
            // the drama has to be said by the row.
            cell: (context, task) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  _hongguoEpisodeLabel(t, task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: theme.colors.textSubtle),
                ),
              ],
            ),
          ),
          DsTableColumn<HongguoDownloadItem>(
            id: 'status',
            label: t.common.downloadStatus,
            sortable: true,
            comparator: (a, b) => _hongguoPhaseRank(a.phase).compareTo(_hongguoPhaseRank(b.phase)),
            width: const DsTableColumnWidth.intrinsic(min: 104),
            cell: (context, task) => _hongguoPhaseBadge(context, task, missing: isMissing(task)),
          ),
          if (!narrow)
            DsTableColumn<HongguoDownloadItem>(
              id: 'size',
              label: t.settings.downloadColumnSize,
              value: (task) => task.total > 0 ? task.total : task.received,
              text: (task) => formatDownloadBytes(task.total > 0 ? task.total : task.received),
              numeric: true,
              sortable: true,
              width: const DsTableColumnWidth.intrinsic(min: 88),
            ),
          if (!narrow)
            DsTableColumn<HongguoDownloadItem>(
              id: 'time',
              label: t.settings.downloadColumnTime,
              value: (task) => task.stamp,
              text: (task) => downloadStampOf(DateTime.fromMillisecondsSinceEpoch(task.stamp)),
              sortable: true,
              width: const DsTableColumnWidth.intrinsic(min: 92),
            ),
          DsTableColumn<HongguoDownloadItem>(
            id: 'actions',
            label: t.settings.downloadColumnActions,
            alignment: DsTableCellAlignment.end,
            // A builder-only column measures nothing, so it names its width.
            width: const DsTableColumnWidth.fixed(48),
            cell: (context, task) => _hongguoPhaseVerb(context, ref, task, missing: isMissing(task)),
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
        rowMenuBuilder: (context, task) => _hongguoRowMenu(context, ref, task, missing: isMissing(task)),
        showRowMenuButton: true,
        emptyView: _empty(t, tasks, ref.read(appPathsProvider).shortDramas.path, filterActive),
      ),
    );
  }
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
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadRemove,
      // Which drama, and how many of its tasks: the row's own body says 这条
      // 记录, and a block would be answering for thirty of them.
      description: '${group.title} · ${t.hongguo.downloadTaskCount(count: ids.length, active: phases.pausable.length)}',
      confirmLabel: t.settings.downloadRemove,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
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
                  image: cachedImage(group.cover),
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
      ? t.hongguo.downloadPhaseFailed
      : '${t.hongguo.downloadPhaseFailed} · ${task.error!.trim()}';
  final retryWait = retryPending && retryLimit > 0
      ? ' · ${t.common.downloadRetryPending(delay: retryDelay, left: (retryLimit - task.attempts).clamp(0, 1 << 20))}'
      : '';
  final caption = switch (task.phase) {
    HongguoDownloadPhase.queued => t.hongguo.downloadPhaseQueued,
    HongguoDownloadPhase.running when total > 0 => [
      t.hongguo.downloading(percent: task.received * 100 ~/ total),
      '${formatDownloadBytes(task.speed)}/s',
      '${formatDownloadBytes(task.received)} / ${formatDownloadBytes(total)}',
      ?_etaOf(t, speed: task.speed, total: total, received: task.received),
    ].join(' · '),
    HongguoDownloadPhase.running => t.hongguo.downloadingUnknown,
    HongguoDownloadPhase.paused when total > 0 =>
      '${t.hongguo.downloadPhasePaused} · ${task.received * 100 ~/ total}% · ${formatDownloadBytes(task.received)} / ${formatDownloadBytes(total)}',
    HongguoDownloadPhase.paused => t.hongguo.downloadPhasePaused,
    HongguoDownloadPhase.failed => '$failedBase$retryWait',
    // The record says the transfer finished; only the disk says whether the
    // file is still there. A row whose episode was moved or deleted says so in
    // the same place its 已完成 used to stand alone.
    HongguoDownloadPhase.done =>
      '${missing ? t.common.previewFileMissing : t.hongguo.downloadPhaseDone} · '
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

/// One episode's row, as the window too narrow for a table shows it: the
/// episode's name over its phase's caption and bar, with the actions that phase
/// allows at the end. The table shape reads the same phase, verb and menu
/// through [_hongguoPhaseBadge], [_hongguoPhaseVerb] and [_hongguoRowMenu], so the
/// two shapes cannot say two different things about one row.
final class _HongguoTaskRow extends ConsumerWidget {
  const _HongguoTaskRow({required this.task, super.key});

  final HongguoDownloadItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(hongguoDownloadsProvider.notifier);
    final total = task.total;
    final fraction = total > 0 ? (task.received / total).clamp(0.0, 1.0) : null;
    final moving = task.phase == HongguoDownloadPhase.running || task.phase == HongguoDownloadPhase.paused;
    // The row states the same facts the details do, built by the same
    // function — including the wait before a pending automatic retry.
    final caption = _detailsOf(
      context,
      task,
      t,
      retryLimit: ref.watch(hongguoDownloadRetryProvider),
      retryDelay: ref.watch(hongguoDownloadRetryDelayProvider),
      retryPending: controller.hasPendingRetry(task.id),
    ).status;
    // The row is one episode of the block its header just named: the drama's
    // name and its poster belong to that header, not to every one of the thirty
    // rows under it, so the row says which episode it is — in the same words the
    // table's second line uses.
    final episode = _hongguoEpisodeLabel(t, task);
    // Asked once per row, never by walking the folder: a finished episode the
    // viewer moved elsewhere still plays no part.
    final missing = _hongguoFileMissing(task);
    return DsListRow(
      title: Text(episode, maxLines: 1, overflow: TextOverflow.ellipsis),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          Text(
            task.qualityLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          ),
          // Two lines: a failed row carries its error and the retry wait, and
          // a narrow window must not ellipsise the second half away.
          Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (moving && (fraction != null || task.received > 0))
            DsProgressBar(value: fraction, semanticLabel: task.fileName),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _hongguoPhaseVerb(context, ref, task, missing: missing),
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
            items: _hongguoRowMenu(context, ref, task, missing: missing),
          ),
        ],
      ),
    );
  }
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
