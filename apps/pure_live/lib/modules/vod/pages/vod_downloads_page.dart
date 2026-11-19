import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/app.dart' show SettingsSectionRoute;
import 'package:pure_live/app/providers/boot/storage_providers.dart'
    show appPathsProvider, storageFolderOverridesProvider;
import 'package:pure_live/app/providers/settings/storage_folder_provider.dart' show StorageFolder;
import 'package:pure_live/features/media_preview/media_preview_item.dart' show MediaPreviewItem;
import 'package:pure_live/features/media_preview/media_preview_page.dart' show openMediaPreview;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart'
    show confirmClearFinished, downloadStampOf, openDownloadedPath;
import 'package:pure_live/features/settings/settings.dart'
    show SettingsChoiceRow, SettingsConfigRow, SettingsSection, openModuleItem, openSettingsSection;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_downloads.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show VodQualityChoice;
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
        NavigationItem,
        avatarInitials,
        cachedImage,
        downloadEtaText,
        downloadFilePresent,
        formatDownloadBytes,
        showDownloadDetails;
import 'package:pure_live/shared/widgets/app_dialog.dart';
import 'package:pure_live/shared/widgets/app_panel.dart';

/// Whether a finished part's file is still on disk where its row says.
///
/// Only a `done` row can be missing: a queued, paused or failed part has no
/// finished file to look for — its bytes are in the `.part` beside the target,
/// and the row is a transfer to carry on, not a file to open. Answering this
/// once per row build (one stat, never a folder scan) is what lets the queue
/// say 文件不在了 instead of offering an 打开文件 that fails.
bool _vodFileMissing(VodDownloadItem task) =>
    task.phase == VodDownloadPhase.done && !downloadFilePresent(task.filePath);

/// Takes one part's record out of the queue; the file, if it is there, stays.
///
/// Reached from the row menu and from the wide workspace's facts column, so a
/// row that only names a file the viewer moved can be cleared from wherever it
/// was noticed. The queue's remove is never silent, because 移除 reads twice —
/// as "off this list" and as "gone" — and only the second would cost bytes.
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
  // The tap can land after the dialog's host is gone (the list rebuilt
  // under it); a dead context must not reach the page's store callback.
  if (!confirmed || !context.mounted) return;
  await ref.read(vodDownloadsProvider.notifier).remove(id);
}

/// Opens the app's own preview on [task], with the queue's other finished parts
/// beside it and the danmaku the download wrote next to the video.
///
/// The row card's play button, its table twin and its menu all come through
/// here, so the run a part joins is one list rather than three that drift.
Future<void> _openVodPreview(BuildContext context, WidgetRef ref, VodDownloadItem task) async {
  final t = context.t;
  final items = _vodPreviewItems(ref.read(vodDownloadsProvider), t);
  final index = items.indexWhere((item) => item.id == task.id);
  if (index < 0) {
    showDsToast(context: context, title: t.vod.previewUnavailable, status: DsStatus.warning);
    return;
  }
  await openMediaPreview(
    context,
    title: t.vod.previewTitle,
    items: items,
    initialIndex: index,
    // A file deleted from the player leaves the row pointing at nothing: the
    // task goes with it (its bytes are already off disk), so the queue cannot
    // offer a part that will only fail to open.
    onDeleted: (item) => ref.read(vodDownloadsProvider.notifier).remove(item.id),
  );
}

/// The one phase a part speaks, as every manager's row says it: the queue's
/// own phases read onto the shared download row's table — a finished part
/// whose file is gone reads as the missing state, not as done.
DownloadRowPhase _vodRowPhase(VodDownloadPhase phase, {required bool missing}) => switch (phase) {
  VodDownloadPhase.running => DownloadRowPhase.running,
  VodDownloadPhase.queued => DownloadRowPhase.queued,
  VodDownloadPhase.paused => DownloadRowPhase.paused,
  VodDownloadPhase.failed => DownloadRowPhase.failed,
  VodDownloadPhase.done => missing ? DownloadRowPhase.missing : DownloadRowPhase.done,
};

/// One part's row, as the shared download row draws it — the state as a badge
/// beside the rendition it plays at, the facts under it, the one verb its
/// phase allows and the menu with the rest. Every manager's queue wears this
/// one shape, which is what makes the app's download pages read as one
/// surface; what the station adds is only its part/preview reading.
Widget _vodTaskCard(BuildContext context, WidgetRef ref, VodDownloadItem task, {required bool inBlock}) {
  final t = context.t;
  final controller = ref.read(vodDownloadsProvider.notifier);
  final total = task.total;
  final fraction = total > 0 ? (task.received / total).clamp(0.0, 1.0) : null;
  final moving = task.phase == VodDownloadPhase.running || task.phase == VodDownloadPhase.paused;
  final retryLimit = ref.watch(vodDownloadRetryProvider);
  final retryDelay = ref.watch(vodDownloadRetryDelayProvider);
  final retryPending = controller.hasPendingRetry(task.id);
  // The row states the same facts the details do, built by the same function
  // — including the wait before a pending automatic retry.
  final caption = _detailsOf(
    context,
    task,
    t,
    retryLimit: retryLimit,
    retryDelay: retryDelay,
    retryPending: retryPending,
  ).status;
  final missing = _vodFileMissing(task);
  final phase = _vodRowPhase(task.phase, missing: missing);
  // The row previews the title it downloaded: its own cover where the task
  // kept one, the part it is, and the rendition asked for. Inside a block the
  // archive's name and its cover belong to the header above it, so the row
  // says only which part it is.
  final preview = task.part.isEmpty ? task.title : '${task.title} · ${task.part}';
  final part = task.part.isEmpty ? 'P${task.index}' : 'P${task.index} ${task.part}';
  final quality = VodQualityChoice.values.where((choice) => choice.qn == task.qn).firstOrNull;
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
    title: inBlock ? part : preview,
    phase: phase,
    caption: caption,
    meta: quality?.label(t),
    fraction: fraction,
    showProgress: moving && (fraction != null || task.received > 0),
    progressLabel: task.fileName,
    leading: inBlock
        ? null
        : DsAvatar(
            initials: avatarInitials(task.title),
            image: task.cover.isEmpty ? null : cachedImage(task.cover, policy: ImageCachePolicies.videoCover),
            size: DsSize.md,
            toneIndex: DsAvatar.toneFor(task.id),
            semanticLabel: preview,
          ),
    playable: task.phase == VodDownloadPhase.done,
    actions: DownloadRowActions(
      onPause: task.phase == VodDownloadPhase.running ? () => unawaited(controller.pause(task.id)) : null,
      onResume: task.phase == VodDownloadPhase.queued || task.phase == VodDownloadPhase.paused
          ? () => unawaited(controller.resume(task.id))
          : null,
      onRetry: task.phase == VodDownloadPhase.failed ? () => unawaited(controller.resume(task.id)) : null,
      onPlay: task.phase == VodDownloadPhase.done ? () => unawaited(_openVodPreview(context, ref, task)) : null,
    ),
    menu: DownloadRowMenuActions(
      onDetails: () => unawaited(
        showDownloadDetails(
          context,
          _detailsOf(
            context,
            task,
            t,
            retryLimit: retryLimit,
            retryDelay: retryDelay,
            retryPending: retryPending,
            onRemove: () => unawaited(_removeRecord(context, ref, task.id)),
          ),
        ),
      ),
      onRemove: () => unawaited(_removeRecord(context, ref, task.id)),
      missing: missing,
      onOpenFile: task.phase == VodDownloadPhase.done && !missing
          ? () => unawaited(openDownloadedPath(context, task.filePath))
          : null,
      onOpenFolder: task.phase == VodDownloadPhase.done
          ? () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path))
          : null,
      onDeleteFile: task.phase == VodDownloadPhase.done && !missing ? () => unawaited(deleteFile()) : null,
    ),
  );
}

/// 下载管理 — the station's download settings under Settings → 视频.
///
/// The pane carries the lanes, the download quality, the danmaku sidecar
/// toggle and the folder the files land in, then one line that says how much
/// the queue holds and opens the station's own 下载管理 page ([VodDownloadsPage])
/// for the rest. It used to draw the whole queue here too, which made one
/// thing two entrances: the settings half could not carry the speed, the group
/// verbs or the table, so the same tasks read differently depending on which
/// door the viewer came through.
final class VodDownloadsPane extends ConsumerWidget {
  /// The pane shown under Settings → Videos → 下载.
  const VodDownloadsPane({super.key});

  Future<void> _pickDirectory(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.settings.downloadDirectory);
      if (selected == null || selected.trim().isEmpty) return;
      final saved = await ref.read(storageFolderOverridesProvider.notifier).set(StorageFolder.videos, selected);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final tasks = ref.watch(vodDownloadsProvider);
    final lanes = ref.watch(vodDownloadSettingsProvider);
    final quality = ref.watch(vodDownloadQualityProvider);
    final retry = ref.watch(vodDownloadRetryProvider);
    final retryDelay = ref.watch(vodDownloadRetryDelayProvider);
    final danmaku = ref.watch(vodDownloadDanmakuProvider);
    final directory = ref.watch(appPathsProvider).videos.path;
    final active = tasks
        .where((task) => task.phase == VodDownloadPhase.queued || task.phase == VodDownloadPhase.running)
        .length;
    // What the queue has already put on disk — the line's second half, so the
    // pane says how much there is and not only how many rows.
    final finishedBytes = tasks
        .where((task) => task.phase == VodDownloadPhase.done)
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
              onChanged: (value) => ref.read(vodDownloadSettingsProvider.notifier).select(value),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.refreshCw),
              title: t.common.downloadRetried,
              description: t.common.downloadRetryDesc,
              value: retry,
              options: [
                for (final count in VodDownloadRetryController.choices)
                  DsSelectOption(
                    value: count,
                    label: count == 0 ? t.common.downloadRetryOff : t.common.downloadRetriedTimes(count: count),
                  ),
              ],
              onChanged: (value) => ref.read(vodDownloadRetryProvider.notifier).select(value),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.timer),
              title: t.common.downloadRetryDelay,
              description: t.common.downloadRetryDelayDesc,
              value: retryDelay,
              options: [
                for (final seconds in VodDownloadRetryDelayController.choices)
                  DsSelectOption(value: seconds, label: '${seconds}s'),
              ],
              // A row without a retry to wait between stays visible, greyed:
              // a missing row reads as a missing feature.
              onChanged: retry == 0 ? null : (value) => ref.read(vodDownloadRetryDelayProvider.notifier).select(value),
            ),
            SettingsChoiceRow<VodQualityChoice>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.player.downloadQuality,
              description: t.player.downloadQualityDesc,
              value: quality,
              options: [
                for (final choice in VodQualityChoice.values) DsSelectOption(value: choice, label: choice.label(t)),
              ],
              onChanged: (value) => ref.read(vodDownloadQualityProvider.notifier).select(value),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.captions),
              title: t.player.downloadDanmaku,
              description: t.player.downloadDanmakuDesc,
              control: DsSwitch(
                value: danmaku,
                onChanged: (value) => ref.read(vodDownloadDanmakuProvider.notifier).set(value: value),
              ),
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
              onPressed: () => unawaited(ref.read(storageFolderOverridesProvider.notifier).reset(StorageFolder.videos)),
            ),
          ],
        ),
        // The queue itself is one row and one tap away, on the station's own
        // 下载管理 page: this pane drew the same tasks a second time, with a
        // weaker summary (no speed, no group verbs) and no room for the table,
        // so the same thing had two entrances that did not agree. Settings keeps
        // the choices and the way out; the list lives in one place.
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
              onPressed: () => openModuleItem(context, ref, NavigationItem.vodDownloads),
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
  return t.settings.downloadEta(time: downloadEtaText(Duration(seconds: (total - received) ~/ speed)));
}

/// The phase's own word, said the same way in a row's badge and in the filter
/// panel: one phase, one spelling.
String _vodPhaseLabel(Translations t, VodDownloadPhase phase) => switch (phase) {
  VodDownloadPhase.queued => t.settings.downloadStatusQueued,
  VodDownloadPhase.running => t.settings.downloadStatusRunning,
  VodDownloadPhase.paused => t.settings.downloadStatusPaused,
  VodDownloadPhase.failed => t.settings.downloadStatusFailed,
  VodDownloadPhase.done => t.settings.downloadStatusDone,
};

/// The station's download manager as its own page: the queue as a table with
/// its search, its filters and its batch verbs, the finished parts opened in
/// the app's own preview, and the folder they land in.
///
/// A window too narrow for the table's columns keeps the row cards the station
/// already drew — a part's cover and its progress bar say more there than four
/// ellipsised cells would, and the head folds its verbs into 更多 instead of
/// pushing the queue away.
final class VodDownloadsPage extends ConsumerStatefulWidget {
  /// The download manager, opening on the whole queue.
  const VodDownloadsPage({super.key});

  @override
  ConsumerState<VodDownloadsPage> createState() => _VodDownloadsPageState();
}

final class _VodDownloadsPageState extends ConsumerState<VodDownloadsPage> {
  /// What the search box holds, matched against the archive, its part and the
  /// file the queue wrote.
  String _query = '';

  /// The phases ticked in the panel; none ticked reads as every phase, so an
  /// empty set is the queue's own 全部 rather than a hidden filter.
  final Set<VodDownloadPhase> _phases = {};

  /// Whether a row must still name a file the disk holds.
  bool _playableOnly = false;

  /// The table's sorted column.
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
  List<VodDownloadItem> _visible(List<VodDownloadItem> tasks) {
    final query = _query.trim().toLowerCase();
    return [
      for (final task in tasks)
        if ((_phases.isEmpty || _phases.contains(task.phase)) &&
            (!_playableOnly || (task.phase == VodDownloadPhase.done && downloadFilePresent(task.filePath))) &&
            (query.isEmpty ||
                task.title.toLowerCase().contains(query) ||
                task.part.toLowerCase().contains(query) ||
                task.fileName.toLowerCase().contains(query)))
          task,
    ];
  }

  /// The queue's conditions, behind the head's one entry: which phases show and
  /// whether a row must still name a file the disk holds. Nothing else about a
  /// queue is a condition — where it lands is a setting, and its size is what
  /// the head already says.
  Future<void> _openFilter(List<VodDownloadItem> tasks) async {
    final t = context.t;
    final picked = {..._phases};
    var playable = _playableOnly;
    void apply() => setState(() {
      _phases
        ..clear()
        ..addAll(picked);
      _playableOnly = playable;
    });
    await showAppPanel<void>(
      context: context,
      builder: (panelContext) => AppPanel(
        title: Text(t.settings.downloadFilterTitle),
        child: DsListSection(
          children: [
            for (final phase in VodDownloadPhase.values)
              DsListRow(
                title: Text(_vodPhaseLabel(t, phase)),
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
    final tasks = ref.watch(vodDownloadsProvider);
    final controller = ref.read(vodDownloadsProvider.notifier);
    final directory = ref.watch(appPathsProvider).videos.path;
    // The facts column states a failed row's retry wait, so the page follows
    // the two settings that decide it.
    final retry = ref.watch(vodDownloadRetryProvider);
    final retryDelay = ref.watch(vodDownloadRetryDelayProvider);
    final shown = _visible(tasks);
    final moving = tasks
        .where((task) => task.phase == VodDownloadPhase.queued || task.phase == VodDownloadPhase.running)
        .length;
    final stopped = tasks.any((task) => task.phase == VodDownloadPhase.paused || task.phase == VodDownloadPhase.failed);
    final finished = tasks.where((task) => task.phase == VodDownloadPhase.done).toList();
    // What the queue has already put on disk, the summary's second half.
    final finishedBytes = finished.fold<int>(0, (sum, task) => sum + (task.total > 0 ? task.total : task.received));
    // What it is pulling right now, its third half: the lanes' own total, so a
    // running row's speed is not asked of every row to be read once.
    final speed = tasks.fold<int>(0, (sum, task) => sum + task.speed);
    final factsTask = shown.where((task) => task.id == _factsId).firstOrNull ?? (shown.isEmpty ? null : shown.first);
    final filterActive = _phases.isNotEmpty || _playableOnly;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // The facts column rides beside the shelf only where the shelf still
        // keeps its rows after 340 pixels are taken from it.
        final withFacts = width >= LiveWindow.downloadWorkspace;
        // One shelf at every width — the queue reads as cards, the way the
        // recording centre's task list does; a table of columns is the one
        // form this page never grew back.
        final queue = shown.isEmpty ? _empty(t, tasks, directory, filterActive) : _cards(shown);
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
                searchHint: t.settings.downloadSearchPlaceholder,
                query: _query,
                onQuery: (value) => setState(() => _query = value),
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
                    onPressed: () => setState(() => _recheck++),
                  ),
                ],
                settingsLabel: t.settings.downloadSettings,
                onSettings: () {
                  openSettingsSection(ref, SettingsSection.vodDownload);
                  unawaited(context.push(SettingsSectionRoute(section: SettingsSection.vodDownload.name).location));
                },
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

  /// The queue as the row cards: one block per archive, its head carrying the
  /// verbs for the parts it holds.
  Widget _cards(List<VodDownloadItem> shown) => ListView(
    padding: EdgeInsets.only(left: _inset, right: _inset, bottom: DsSpace.s16),
    children: _vodQueueBlocks(
      shown,
      rowOf: (task, {required inBlock}) => _vodTaskCard(context, ref, task, inBlock: inBlock),
    ),
  );

  /// Where the page keeps its own margin: the head and the queue read the same
  /// number, so their left edges line up.
  double get _inset => LiveWindow.pageInset(MediaQuery.sizeOf(context).width);

  /// Nothing on screen: what the queue holds in total answers better than an
  /// empty table would, because a filtered-out task is still a task the viewer
  /// has to un-tick to see — and the un-ticking is offered here rather than
  /// left for the filter panel, the way the music queue's empty page does it.
  Widget _empty(Translations t, List<VodDownloadItem> tasks, String directory, bool filterActive) => Center(
    child: DsEmptyState(
      icon: const DsIcon(DsIcons.download),
      title: Text(tasks.isEmpty ? t.vod.downloadEmpty : t.settings.downloadFilterEmpty),
      description: Text(tasks.isEmpty ? t.vod.downloadEmptyDesc : t.vod.downloadFilterEmptyDesc),
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
}

/// The preview page's list for the station's queue: every part that finished,
/// in the queue's own order. A part whose file was cleaned out of the folder
/// stays in the list — the page greys it and says the file is gone, which is
/// what a viewer who just deleted it needs to hear — while a part that never
/// finished has nothing to show and stays out.
List<MediaPreviewItem> _vodPreviewItems(List<VodDownloadItem> tasks, Translations t) {
  final items = <MediaPreviewItem>[];
  for (final task in tasks) {
    if (task.phase != VodDownloadPhase.done) continue;
    final quality = VodQualityChoice.values.where((choice) => choice.qn == task.qn).firstOrNull;
    items.add(
      MediaPreviewItem(
        id: task.id,
        title: task.part.isEmpty ? task.title : '${task.title} · ${task.part}',
        path: task.filePath,
        subtitle: [
          if (quality != null) quality.label(t),
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

/// One archive's block of the queue: its name, its cover where the queue kept
/// one, how many parts it has, and the parts this list holds of it.
final class _VodDownloadGroup {
  _VodDownloadGroup({required this.title, required this.cover, required this.parts, required this.tasks});

  /// The archive's title, written once for the block.
  final String title;

  /// The archive's cover; the first task in the block that carries one.
  String cover;

  /// How many parts the archive lists.
  final int parts;

  /// The parts, in the queue's own order.
  final List<VodDownloadItem> tasks;
}

/// The queue read by archive: one block per title, in the order the list first
/// names one, the parts inside a block kept as the list has them. A viewer who
/// queued a whole multi-P upload got one row per part, each repeating the same
/// archive title and pasting the same cover thirty times — the file's part is
/// what differs between them, so that is what the row says.
List<_VodDownloadGroup> _vodDownloadGroups(Iterable<VodDownloadItem> tasks) {
  final order = <String>[];
  final blocks = <String, _VodDownloadGroup>{};
  for (final task in tasks) {
    final key = task.bvid.isNotEmpty ? task.bvid : (task.epId > 0 ? 'ep${task.epId}' : task.title);
    final block = blocks[key];
    if (block == null) {
      blocks[key] = _VodDownloadGroup(title: task.title, cover: task.cover, parts: task.parts, tasks: [task]);
      order.add(key);
    } else {
      block.tasks.add(task);
      // A task queued before the queue kept covers still names its archive;
      // the first picture the block holds is the block's.
      if (block.cover.isEmpty) block.cover = task.cover;
    }
  }
  return [for (final key in order) blocks[key]!];
}

/// The line over one archive's parts: its cover where the queue has one, its
/// name once for the block, how many parts the archive runs to, and the verbs
/// that act on the whole block. A ten-part upload whose every action sits on
/// the row is ten taps, and a queue that counts tasks for the whole list and
/// for none of its blocks is a flat list wearing group headers.
final class _VodArchiveHead extends ConsumerWidget {
  const _VodArchiveHead({required this.group});

  /// The block being introduced.
  final _VodDownloadGroup group;

  /// Runs [verb] over every id it was handed. The store writes per task, so
  /// the ids go one after another rather than all at once.
  Future<void> _apply(
    WidgetRef ref,
    List<String> ids,
    Future<void> Function(VodDownloadsController controller, String id) verb,
  ) async {
    final controller = ref.read(vodDownloadsProvider.notifier);
    for (final id in ids) {
      await verb(controller, id);
    }
  }

  /// The block's own phases, read when the action is asked for rather than when
  /// the line was painted: a task that finished in between is no longer
  /// something to pause.
  ({List<String> pausable, List<String> resumable}) _phases() => (
    pausable: [
      for (final task in group.tasks)
        if (task.phase == VodDownloadPhase.running || task.phase == VodDownloadPhase.queued) task.id,
    ],
    resumable: [
      for (final task in group.tasks)
        if (task.phase == VodDownloadPhase.paused || task.phase == VodDownloadPhase.failed) task.id,
    ],
  );

  Future<void> _removeBlock(BuildContext context, WidgetRef ref, Translations t) async {
    final ids = [for (final task in group.tasks) task.id];
    final confirmed = await showAppConfirm(
      context: context,
      title: t.settings.downloadRemove,
      // Which upload, and how many of its parts: the row's own body says 这条
      // 记录, and a block would be answering for ten of them.
      description: '${group.title} · ${t.settings.downloadTaskCount(count: ids.length, active: _phases().pausable.length)}',
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
                  image: cachedImage(group.cover, policy: ImageCachePolicies.videoCover),
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
          // The shelf's own reading for the same fact, beside the rows it counts.
          Text('${t.vod.parts} · ${group.parts}', style: theme.typography.caption.copyWith(color: colors.textMuted)),
          // A head is only built for a block of several parts, so every verb here
          // already has more than one object; a part standing alone is served by
          // its own row and gets no second place to be pressed.
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
                  onPressed: () => unawaited(_apply(ref, phases.resumable, (controller, id) => controller.resume(id))),
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

/// The queue as blocks of the same archive: an archive whose several parts are
/// all here gets one head and its parts under it; a task standing alone keeps
/// the row it already was, because a layer naming one file names nothing.
/// [rowOf] builds the row so a page can hand its own selection through.
List<Widget> _vodQueueBlocks(
  List<VodDownloadItem> tasks, {
  required Widget Function(VodDownloadItem task, {required bool inBlock}) rowOf,
}) {
  final blocks = <Widget>[];
  for (final group in _vodDownloadGroups(tasks)) {
    final grouped = group.tasks.length > 1;
    if (grouped) blocks.add(_VodArchiveHead(group: group));
    blocks.add(
      Padding(
        padding: const EdgeInsets.only(bottom: DsSpace.s8),
        child: DsListSection(children: [for (final task in group.tasks) rowOf(task, inBlock: grouped)]),
      ),
    );
  }
  return blocks;
}

/// The facts the right column, the 详情 sheet and the row's own caption show
/// for [task] — one construction, so the three cannot drift. [retryLimit] and
/// [retryDelay] let a failed row say when the queue will come back for it
/// instead of leaving the wait silent.
DownloadDetails _detailsOf(
  BuildContext context,
  VodDownloadItem task,
  Translations t, {
  int retryLimit = 0,
  int retryDelay = 0,
  bool retryPending = false,
  VoidCallback? onRemove,
}) {
  final total = task.total;
  // One stat, only for a row that claims a finished file.
  final missing = _vodFileMissing(task);
  // A failed row says what went wrong and, when the queue still owes it an
  // automatic retry, how long the wait is.
  final failedBase = (task.error ?? '').trim().isEmpty
      ? t.settings.downloadStatusFailed
      : '${t.settings.downloadStatusFailed} · ${task.error!.trim()}';
  final retryWait = retryPending && retryLimit > 0
      ? ' · ${t.common.downloadRetryPending(delay: retryDelay, left: (retryLimit - task.attempts).clamp(0, 1 << 20))}'
      : '';
  final caption = switch (task.phase) {
    VodDownloadPhase.queued => t.settings.downloadStatusQueued,
    VodDownloadPhase.running when total > 0 => [
      t.settings.downloadPercent(percent: '${task.received * 100 ~/ total}'),
      '${formatDownloadBytes(task.speed)}/s',
      '${formatDownloadBytes(task.received)} / ${formatDownloadBytes(total)}',
      ?_etaOf(t, speed: task.speed, total: total, received: task.received),
    ].join(' · '),
    VodDownloadPhase.running => t.settings.downloadPercentUnknown,
    VodDownloadPhase.paused when total > 0 =>
      '${t.settings.downloadStatusPaused} · ${task.received * 100 ~/ total}% · ${formatDownloadBytes(task.received)} / ${formatDownloadBytes(total)}',
    VodDownloadPhase.paused => t.settings.downloadStatusPaused,
    VodDownloadPhase.failed => '$failedBase$retryWait',
    // A finished row whose file the viewer moved or deleted says so here: the
    // record is true of the transfer, not of the disk, and the queue must not
    // go on offering 打开文件 over a path that answers nothing.
    VodDownloadPhase.done =>
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
    onOpenFile: task.phase == VodDownloadPhase.done && !missing
        ? () => unawaited(openDownloadedPath(context, task.filePath))
        : null,
    onOpenFolder: () => unawaited(openDownloadedPath(context, File(task.filePath).parent.path)),
    onRemove: onRemove,
  );
}
