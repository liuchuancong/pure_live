import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openModuleItem;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/huya/controller/huya_downloads.dart';
import 'package:pure_live/modules/huya/pages/huya_downloads_pane.dart'
    show huyaDetailsOf, huyaFileMissing, huyaRowPhaseOf, huyaTaskCard;
import 'package:pure_live/shared/shared.dart'
    show
        DownloadQueueAction,
        DownloadQueueHeader,
        DownloadStatusGroup,
        DownloadStatusTab,
        DownloadStatusTabs,
        LiveWindow,
        NavigationItem,
        downloadRowGroupOf,
        formatDownloadBytes,
        inlineFilterKeeps,
        inlineFilterProvider;
import 'package:pure_live/shared/widgets/app_dialog.dart' show showAppConfirm;
import 'package:pure_live/shared/widgets/download_workspace.dart' show DownloadDetailsPane;
import 'package:pure_live/shared/widgets/inline_filter_bar.dart' show InlineFilterBar;

/// The state tab's word — the shared status words, with 全部 at its head.
String _statusTabLabel(Translations t, DownloadStatusGroup group) => switch (group) {
  DownloadStatusGroup.all => t.settings.downloadFilterAll,
  DownloadStatusGroup.running => t.settings.downloadStatusRunning,
  DownloadStatusGroup.queued => t.settings.downloadStatusQueued,
  DownloadStatusGroup.paused => t.settings.downloadStatusPaused,
  DownloadStatusGroup.done => t.settings.downloadStatusDone,
  DownloadStatusGroup.failed => t.settings.downloadStatusFailed,
};

/// 虎牙视频's download queue as its own page — the station's videos on one
/// surface with the manager's own head: how big the queue is, the search, the
/// states, the folder's row and the queue verbs, all over the same
/// shared download cards every manager wears. Reached from the rail, where
/// the other stations keep their download managers.
final class HuyaDownloadsPage extends ConsumerStatefulWidget {
  /// The page.
  const HuyaDownloadsPage({super.key});

  @override
  ConsumerState<HuyaDownloadsPage> createState() => _HuyaDownloadsPageState();
}

final class _HuyaDownloadsPageState extends ConsumerState<HuyaDownloadsPage> {
  String _query = '';

  /// The state tab the queue is cut to; all reads as every state.
  DownloadStatusGroup _statusGroup = DownloadStatusGroup.all;

  double get _inset => LiveWindow.pageInset(MediaQuery.sizeOf(context).width);

  bool _matches(HuyaDownloadItem task) {
    if (_query.isNotEmpty) {
      final word = _query.toLowerCase();
      final hit = task.title.toLowerCase().contains(word) || task.fileName.toLowerCase().contains(word);
      if (!hit) return false;
    }
    if (_statusGroup == DownloadStatusGroup.all) return true;
    return downloadRowGroupOf(huyaRowPhaseOf(task.phase, missing: huyaFileMissing(task))) == _statusGroup;
  }

  Future<void> _clearFinished(List<HuyaDownloadItem> tasks) async {
    final t = context.t;
    final confirmed = await showAppConfirm(
      context: context,
      title: t.settings.downloadClearFinished,
      description: t.settings.downloadClearFinishedBody,
      confirmLabel: t.settings.downloadClearFinished,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(huyaDownloadsProvider.notifier).clearFinished();
  }

  /// The row the wide window's facts column speaks about; null lets the first
  /// visible row speak.
  String? _factsId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final tasks = ref.watch(huyaDownloadsProvider);
    final directory = ref.watch(appPathsProvider).videos.path;
    final inlineWord = ref.watch(inlineFilterProvider(NavigationItem.huyaDownloads));
    final shown = tasks
        .where(_matches)
        .where((task) => inlineFilterKeeps(inlineWord, [task.title, task.fileName]))
        .toList();
    final moving = tasks
        .where((task) => task.phase == HuyaDownloadPhase.running || task.phase == HuyaDownloadPhase.queued)
        .length;
    final finishedBytes = tasks.fold<int>(
      0,
      (sum, task) => sum + (task.phase == HuyaDownloadPhase.done ? task.total : 0),
    );
    final speed = tasks.fold<int>(0, (sum, task) => sum + task.speed);
    final finishedCount = tasks.where((task) => task.phase == HuyaDownloadPhase.done).length;
    final width = MediaQuery.sizeOf(context).width;
    // The facts column rides beside the queue where the rows keep their
    // reading after 340 pixels are taken from them; the queue speaks about
    // the row on stage.
    final withFacts = width >= LiveWindow.downloadWorkspace;
    final factsTask =
        shown.where((task) => task.videoId == _factsId).firstOrNull ?? (shown.isEmpty ? null : shown.first);
    final counts = <DownloadStatusGroup, int>{
      for (final group in DownloadStatusGroup.values)
        group: group == DownloadStatusGroup.all
            ? tasks.length
            : tasks
                  .where(
                    (task) => downloadRowGroupOf(huyaRowPhaseOf(task.phase, missing: huyaFileMissing(task))) == group,
                  )
                  .length,
    };
    final queue = shown.isEmpty
        ? Expanded(
            child: Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.download),
                title: Text(tasks.isEmpty ? t.settings.downloadQueueEmpty : t.settings.downloadFilterEmpty),
                description: Text(tasks.isEmpty ? t.huya.downloadQueueEmptyDesc : t.settings.downloadFilterEmpty),
                actions: [
                  if (_statusGroup != DownloadStatusGroup.all)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      leading: const DsIcon(DsIcons.filter, size: 14),
                      onPressed: () => setState(() => _statusGroup = DownloadStatusGroup.all),
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
            ),
          )
        : Expanded(
            child: ListView(
              padding: EdgeInsets.only(left: _inset, right: _inset, bottom: DsSpace.s16),
              children: [
                DsListSection(
                  children: [
                    for (final task in shown)
                      DsPressable(
                        semanticLabel: task.title,
                        onPressed: () => setState(() => _factsId = task.videoId),
                        builder: (context, states, child) => child!,
                        child: huyaTaskCard(context, ref, task, missing: huyaFileMissing(task)),
                      ),
                  ],
                ),
              ],
            ),
          );
    return ColoredBox(
      color: colors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inlineWord != null)
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, 0, _inset, DsSpace.s8),
              child: InlineFilterBar(
                word: inlineWord,
                onClear: () => ref.read(inlineFilterProvider(NavigationItem.huyaDownloads).notifier).clear(),
              ),
            ),
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
              actions: [
                DownloadQueueAction(
                  label: t.settings.downloadManagerOpenFolder,
                  icon: DsIcons.folderOpen,
                  onPressed: () => unawaited(openDownloadedPath(context, directory)),
                ),
                if (tasks.any((task) => task.phase == HuyaDownloadPhase.running))
                  DownloadQueueAction(
                    label: t.settings.downloadPauseAll,
                    icon: DsIcons.pause,
                    onPressed: () {
                      final notifier = ref.read(huyaDownloadsProvider.notifier);
                      for (final task in tasks.where((task) => task.phase == HuyaDownloadPhase.running)) {
                        unawaited(notifier.pause(task.videoId));
                      }
                    },
                  ),
                if (tasks.any(
                  (task) => task.phase == HuyaDownloadPhase.paused || task.phase == HuyaDownloadPhase.failed,
                ))
                  DownloadQueueAction(
                    label: t.settings.downloadResumeAll,
                    icon: DsIcons.play,
                    onPressed: () {
                      final notifier = ref.read(huyaDownloadsProvider.notifier);
                      for (final task in tasks.where(
                        (task) => task.phase == HuyaDownloadPhase.paused || task.phase == HuyaDownloadPhase.failed,
                      )) {
                        unawaited(notifier.resume(task.videoId));
                      }
                    },
                  ),
                if (finishedCount > 0)
                  DownloadQueueAction(
                    label: t.settings.downloadClearFinished,
                    icon: DsIcons.trash2,
                    destructive: true,
                    onPressed: () => unawaited(_clearFinished(tasks)),
                  ),
                DownloadQueueAction(
                  label: t.navigation.downloadsCenter,
                  icon: DsIcons.download,
                  onPressed: () => openModuleItem(context, ref, NavigationItem.downloadsCenter),
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
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                queue,
                if (withFacts)
                  SizedBox(
                    width: LiveWindow.downloadDetails,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(0, 0, DsSpace.s20, DsSpace.s24),
                      child: DownloadDetailsPane(
                        details: factsTask == null
                            ? null
                            : huyaDetailsOf(context, ref, factsTask, missing: huyaFileMissing(factsTask)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
