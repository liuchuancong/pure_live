import 'dart:async' show Timer, unawaited;
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart' show OpenFile, ResultType;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/pages/wallpaper_preview_page.dart' show showWallpaperPreview;
import 'package:pure_live/features/settings/surface/settings_preview.dart' show SettingsPreviewTitleBar;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The room the pager takes under the table (its row plus the gap above it),
/// which the page size leaves out of the rows it counts.
const double _kPagerRoom = 48;

/// The room the touch list's footer takes, counted the same way.
const double _kFooterRoom = 36;

/// The table's row: tall enough for the thumbnail plus the cell's padding.
const double _kRowHeight = 52;

/// Opens the download manager as a page over the caller. The preview page
/// lives outside the settings surface, so its entry pushes this page with
/// its own way back; entries inside settings open the pane in place through
/// the section registry instead, and never land here.
Future<void> showWallpaperDownloads(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(builder: (context) => const WallpaperDownloadsPage()));
}

/// Words a hand-over to the queue — queued, or already there — with the
/// manager one tap away on the toast itself. [openManager] decides how the
/// tap opens it: the preview pushes the page, the settings panes switch to
/// the section in place.
void showDownloadHandoverToast(BuildContext context, WallpaperDownloadHandover handover, {VoidCallback? openManager}) {
  final t = context.t;
  final task = handover.task;
  showDsToast(
    context: context,
    title: handover.duplicate
        ? (task.isRunning || task.phase == WallpaperDownloadPhase.paused
              ? t.settings.downloadDuplicateRunning
              : t.settings.downloadDuplicateDone)
        : t.settings.downloadQueued(title: task.title),
    actionLabel: t.settings.downloadManagerView,
    onAction: () {
      if (openManager != null) {
        openManager();
      } else {
        unawaited(showWallpaperDownloads(context));
      }
    },
  );
}

/// The manager as its own page: the same bar the wallpaper previews carry —
/// subject over the way back — above the pane itself.
final class WallpaperDownloadsPage extends StatelessWidget {
  /// The download manager page.
  const WallpaperDownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ColoredBox(
      color: DsTheme.colorsOf(context).canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPreviewTitleBar(
              icon: DsIcons.folderOpen,
              title: t.settings.downloadManagerTitle,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            // The settings surface pads its own panes; this page does not sit
            // in one, so it brings the same inset.
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  LiveWindow.pageInset(MediaQuery.sizeOf(context).width),
                  DsSpace.s16,
                  LiveWindow.pageInset(MediaQuery.sizeOf(context).width),
                  DsSpace.s12,
                ),
                child: const WallpaperDownloadsPane(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens one download's detail: the media in full, its progress and its
/// facts, with the phase's actions under it. A narrow window pushes the
/// page over the caller; a wide one raises it as a dialog, so the manager
/// stays put behind it.
Future<void> showWallpaperDownloadDetail(BuildContext context, String taskId) {
  final compact = LiveWindow.isCompact(MediaQuery.sizeOf(context).width);
  if (compact) {
    return Navigator.of(context, rootNavigator: true).push(
      DsPageRoute<void>(fullscreenDialog: true, builder: (context) => WallpaperDownloadDetailPage(taskId: taskId)),
    );
  }
  return showDsDialog<void>(
    context: context,
    builder: (context) => _WallpaperDownloadDetailDialog(taskId: taskId),
  );
}

/// One download's detail, as the reference's keep-page draws it: the media
/// in full — a picture to zoom, a clip on the player — the name over its
/// kind chip, the moving transfer's percent and bar, and the facts (save
/// path, size, time) with the phase's actions under them.
final class _WallpaperDownloadDetail extends ConsumerWidget {
  const _WallpaperDownloadDetail({required this.taskId, required this.onGone});

  /// The row this detail shows.
  final String taskId;

  /// Runs when the row's own actions remove it, so the host can leave.
  final VoidCallback onGone;

  Future<void> _remove(BuildContext context, WidgetRef ref, WallpaperDownloadTask task) async {
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
    if (!confirmed) return;
    await ref.read(wallpaperDownloadsProvider.notifier).remove(task.id);
    onGone();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final task = ref.watch(wallpaperDownloadsProvider).where((task) => task.id == taskId).firstOrNull;
    if (task == null) {
      return DsEmptyState(icon: const DsIcon(DsIcons.download), title: Text(t.settings.downloadFilterEmpty));
    }
    final controller = ref.read(wallpaperDownloadsProvider.notifier);
    final moving = task.isRunning || task.phase == WallpaperDownloadPhase.paused;
    final total = task.total;
    final fraction = total > 0 ? (task.received / total).clamp(0.0, 1.0) : null;
    final saved = task.filePath;
    // The full walk belongs to the background settings' own preview page:
    // the poster here only leads there, playing the media with the same
    // stage, scrim and apply the gallery's entries get.
    final poster = _posterOf(task);
    final preview = DsPressable(
      semanticLabel: t.settings.downloadDetailPreview,
      onPressed: poster == null ? null : () => openDownloadPreview(context, ref, task.id),
      builder: (context, states, _) => Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: colors.control,
            child: poster == null
                ? Center(child: DsIcon(DsIcons.image, size: 32, color: colors.textSubtle))
                : DsImage(
                    image: _imageOf(poster, width: 1280, height: 720),
                    aspectRatio: 16 / 9,
                    fit: BoxFit.contain,
                    fallback: Center(child: DsIcon(DsIcons.image, size: 32, color: colors.textSubtle)),
                  ),
          ),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: Color(0x8A000000), shape: BoxShape.circle),
              child: const Center(child: DsIcon(DsIcons.play, size: 26, color: Color(0xFFFFFFFF))),
            ),
          ),
        ],
      ),
    );
    final facts = [
      (DsIcons.folderOpen, t.settings.downloadInfoPath, '${task.directory}${task.fileName}'),
      (
        DsIcons.file,
        t.settings.downloadInfoSize,
        total > 0
            ? '${_formatBytes(task.received)} / ${_formatBytes(total)}'
            : (task.received > 0 ? _formatBytes(task.received) : '—'),
      ),
      (
        DsIcons.clock,
        t.settings.downloadInfoTime,
        downloadStampOf(
          task.phase == WallpaperDownloadPhase.done && task.finishedAt != null ? task.finishedAt! : task.startedAt,
        ),
      ),
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.radii.card),
            child: SizedBox(height: 260, child: preview),
          ),
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(
                  task.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
              ),
              _KindChip(kind: task.kind),
            ],
          ),
          if (moving) ...[
            Row(
              spacing: DsSpace.s12,
              children: [
                Expanded(
                  child: DsProgressBar(value: fraction, semanticLabel: task.fileName),
                ),
                Text(
                  total > 0 ? '${task.received * 100 ~/ total}%' : '',
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w700, color: colors.text),
                ),
              ],
            ),
            if (task.isRunning && task.speedBps > 0)
              Text(
                '${_formatBytes(task.speedBps)}/s',
                style: theme.typography.caption.copyWith(color: colors.textSubtle),
              ),
          ],
          if (task.phase == WallpaperDownloadPhase.failed && (task.error ?? '').trim().isNotEmpty)
            Text(task.error!.trim(), style: theme.typography.caption.copyWith(color: colors.danger.text)),
          DsListSection(
            children: [
              for (final (icon, label, value) in facts)
                DsListRow(
                  leading: DsIcon(icon, size: 18, color: colors.textSubtle),
                  title: Text(label),
                  description: DsTooltip(
                    message: value,
                    child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
            ],
          ),
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: switch (task.phase) {
                  WallpaperDownloadPhase.running => DsButton(
                    variant: DsButtonVariant.secondary,
                    leading: const DsIcon(DsIcons.pause),
                    onPressed: () => unawaited(controller.pause(task.id)),
                    child: Text(t.settings.downloadPause),
                  ),
                  WallpaperDownloadPhase.paused => DsButton(
                    leading: const DsIcon(DsIcons.play),
                    onPressed: () => unawaited(controller.resume(task.id)),
                    child: Text(t.settings.downloadResume),
                  ),
                  WallpaperDownloadPhase.failed => DsButton(
                    leading: const DsIcon(DsIcons.rotateCw),
                    onPressed: task.isRetriable ? () => unawaited(controller.retry(task.id)) : null,
                    child: Text(t.common.retry),
                  ),
                  WallpaperDownloadPhase.done => DsButton(
                    leading: const DsIcon(DsIcons.externalLink),
                    onPressed: saved == null ? null : () => unawaited(openDownloadedPath(context, saved)),
                    child: Text(t.settings.downloadOpenFile),
                  ),
                },
              ),
              Expanded(
                child: DsButton(
                  variant: DsButtonVariant.dangerSoft,
                  leading: const DsIcon(DsIcons.trash2),
                  onPressed: () => unawaited(_remove(context, ref, task)),
                  child: Text(t.settings.downloadRemove),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The detail as a page: the file's own name over the way back, the detail
/// under it.
final class WallpaperDownloadDetailPage extends StatelessWidget {
  /// The detail page for [taskId].
  const WallpaperDownloadDetailPage({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ColoredBox(
      color: DsTheme.colorsOf(context).canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPreviewTitleBar(
              icon: DsIcons.download,
              title: t.settings.downloadDetailTitle,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  LiveWindow.pageInset(MediaQuery.sizeOf(context).width),
                  DsSpace.s16,
                  LiveWindow.pageInset(MediaQuery.sizeOf(context).width),
                  DsSpace.s24,
                ),
                child: _WallpaperDownloadDetail(taskId: taskId, onGone: () => Navigator.of(context).maybePop()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The detail as a dialog: the same body, with a close on the bottom.
final class _WallpaperDownloadDetailDialog extends StatelessWidget {
  const _WallpaperDownloadDetailDialog({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsDialog(
      title: Text(t.settings.downloadDetailTitle),
      icon: const DsIcon(DsIcons.download),
      description: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _WallpaperDownloadDetail(taskId: taskId, onGone: () => Navigator.of(context).maybePop()),
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
      style: const DsDialogStyle(width: 560),
    );
  }
}

/// The status the list is filtered by.
enum _DownloadFilter {
  all,
  running,
  done,
  failed;

  /// Whether [task] belongs under this filter. A paused row counts as
  /// still moving.
  bool matches(WallpaperDownloadTask task) => switch (this) {
    all => true,
    running => task.isRunning || task.phase == WallpaperDownloadPhase.paused,
    done => task.phase == WallpaperDownloadPhase.done,
    failed => task.phase == WallpaperDownloadPhase.failed,
  };

  /// The word the segment and the empty state use.
  String label(Translations t) => switch (this) {
    all => t.settings.downloadFilterAll,
    running => t.settings.downloadStatusRunning,
    done => t.settings.downloadStatusDone,
    failed => t.settings.downloadStatusFailed,
  };

  /// The empty state's icon for this filter.
  DsIconData get emptyIcon => switch (this) {
    all || running => DsIcons.download,
    done => DsIcons.circleCheck,
    failed => DsIcons.circleAlert,
  };
}

/// The media kind the list is filtered by; `all` keeps every row. A painted
/// swatch counts as a picture.
enum _KindFilter { all, image, video }

/// The download manager pane, laid out like the font manager: one row of
/// search, the kind and the count with the settings button, the state's
/// segments and counts under it, and a compact table — the file's thumbnail
/// and state, its size and time, the phase's one action — with a row menu
/// holding the rest. A tap opens the media in the background preview.
///
/// The settings surface hosts it for `backgroundDownloads` — in place on
/// the desktop, under its own page header on a touch shell — so the pane
/// owns the content and no way back of its own.
final class WallpaperDownloadsPane extends ConsumerStatefulWidget {
  /// The download manager pane.
  const WallpaperDownloadsPane({super.key});

  @override
  ConsumerState<WallpaperDownloadsPane> createState() => _WallpaperDownloadsPaneState();
}

final class _WallpaperDownloadsPaneState extends ConsumerState<WallpaperDownloadsPane> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _tableScroll = ScrollController();
  String _query = '';
  _DownloadFilter _filter = _DownloadFilter.all;
  _KindFilter _kind = _KindFilter.all;
  DsTableSort? _sort;
  int _page = 1;

  /// The multi-select: task ids the viewer ticked. Selection follows the row
  /// through paging and filtering; only a row's own departure clears it.
  final Set<String> _selected = {};

  // The touch shell's list: how many rows it holds, how many the filters keep
  // and how many one screenful takes, kept from the last layout so the scroll
  // listener knows when to append.
  int _shown = 0;
  int _total = 0;
  int _batch = 0;
  bool _paged = true;
  bool _loadingMore = false;
  Timer? _moreTimer;

  @override
  void initState() {
    super.initState();
    _tableScroll.addListener(_onTableScroll);
  }

  @override
  void dispose() {
    _moreTimer?.cancel();
    _search.dispose();
    _tableScroll.dispose();
    super.dispose();
  }

  /// The touch list's footer: the next batch arrives when the viewer reaches
  /// the table's end, the way the popular feed's blocks do.
  void _onTableScroll() {
    if (_paged || _loadingMore || !_tableScroll.hasClients) return;
    final position = _tableScroll.position;
    if (!position.hasContentDimensions || position.extentAfter > 120) return;
    if (_shown >= _total) return;
    setState(() => _loadingMore = true);
    _moreTimer?.cancel();
    // One beat, so the footer's spinner reads as work rather than a flicker.
    _moreTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _shown = math.min(_shown + math.max(_batch, 1), _total);
        _loadingMore = false;
      });
    });
  }

  /// Back to the first page with the list at its top, after a filter change.
  void _refilter(VoidCallback change) {
    _moreTimer?.cancel();
    setState(() {
      change();
      _page = 1;
      // The touch list starts over from one batch.
      _shown = 0;
      _loadingMore = false;
    });
    _scrollToTop();
  }

  /// Turns the table to [next], the page's head in view again.
  void _goToPage(int next) {
    setState(() => _page = next);
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_tableScroll.hasClients) _tableScroll.jumpTo(0);
  }

  /// Opens a row in the background settings' preview page, walking every row
  /// the manager can show.
  void _openPreview(WallpaperDownloadTask task) => openDownloadPreview(context, ref, task.id);

  /// The rows in the sort the header asked for; the table keeps the order
  /// ([DsTable.sortLocally] is off), because a page is only part of the list.
  List<WallpaperDownloadTask> _sorted(List<WallpaperDownloadTask> tasks) {
    final sort = _sort;
    if (sort == null) return tasks;
    final rows = [...tasks];
    int sizeOf(WallpaperDownloadTask task) => task.total > 0 ? task.total : task.received;
    int stampOf(WallpaperDownloadTask task) => (task.finishedAt ?? task.startedAt).millisecondsSinceEpoch;
    int compare(WallpaperDownloadTask a, WallpaperDownloadTask b) => switch (sort.columnId) {
      'name' => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
      'size' => sizeOf(a).compareTo(sizeOf(b)),
      'time' => stampOf(a).compareTo(stampOf(b)),
      _ => 0,
    };
    rows.sort((a, b) {
      final order = compare(a, b);
      return sort.ascending ? order : -order;
    });
    return rows;
  }

  /// The manager's settings: the folder the files land in, the way in, and
  /// the one housekeeping action. The pane itself stays about the list — these
  /// belong behind one button, in the panel the button opens.
  Future<void> _openSettings() {
    final t = context.t;
    final directory = ref.read(downloadDirectoryProvider).effectivePath;
    return showDsPanel<void>(
      context: context,
      builder: (panelContext) {
        final theme = DsTheme.of(panelContext);
        return DsPanel(
          title: Text(t.settings.downloadSettings),
          child: DsListSection(
            children: [
              DsListRow(
                leading: const DsIcon(DsIcons.folderOpen),
                title: Text(t.settings.downloadManagerOpenFolder),
                description: DsTooltip(
                  message: directory,
                  child: Text(directory, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                onPressed: () {
                  Navigator.of(panelContext).pop();
                  unawaited(openDownloadedPath(context, directory));
                },
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.pencil),
                title: Text(t.settings.downloadDirectoryChange),
                showChevron: true,
                onPressed: () {
                  Navigator.of(panelContext).pop();
                  unawaited(_changeDirectory());
                },
              ),
              DsListRow(
                leading: DsIcon(DsIcons.trash2, color: theme.colors.danger.text),
                title: Text(t.settings.downloadDeleteAll),
                onPressed: () {
                  Navigator.of(panelContext).pop();
                  unawaited(_removeAll());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Hands the folder choice to the viewer; the same flow the settings'
  /// cache section runs, probe included.
  Future<void> _changeDirectory() async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.settings.downloadDirectory);
      if (selected == null || selected.trim().isEmpty) return;
      final saved = await ref.read(downloadDirectoryProvider.notifier).setDirectory(selected);
      if (!mounted) return;
      if (!saved) {
        showDsToast(context: context, title: t.settings.downloadDirectoryPermissionHint, status: DsStatus.danger);
        return;
      }
      showDsToast(context: context, title: t.settings.downloadDirectoryUpdated);
    } on Object {
      if (mounted) {
        showDsToast(context: context, title: t.settings.downloadDirectoryPickFailed, status: DsStatus.danger);
      }
    }
  }

  /// Asks before dropping a row: the record goes, the file stays.
  Future<void> _remove(WallpaperDownloadTask task) async {
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
    if (confirmed) {
      await ref.read(wallpaperDownloadsProvider.notifier).remove(task.id);
      if (mounted) setState(() => _selected.remove(task.id));
    }
  }

  /// Drops the ticked rows after one ask.
  Future<void> _removeSelected() async {
    final t = context.t;
    final count = _selected.length;
    if (count == 0) return;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadDeleteSelected(count: count),
      description: t.settings.downloadRemoveBody,
      confirmLabel: t.settings.downloadRemove,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed) return;
    await ref.read(wallpaperDownloadsProvider.notifier).removeMany(_selected);
    if (mounted) setState(_selected.clear);
  }

  /// Drops the whole list after one ask.
  Future<void> _removeAll() async {
    final t = context.t;
    if (ref.read(wallpaperDownloadsProvider).isEmpty) return;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.downloadDeleteAll,
      description: t.settings.downloadRemoveBody,
      confirmLabel: t.settings.downloadDeleteAll,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed) return;
    await ref.read(wallpaperDownloadsProvider.notifier).removeAll();
    if (mounted) setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tasks = ref.watch(wallpaperDownloadsProvider);
    // Ticks that name rows the list no longer holds no longer count.
    _selected.removeWhere((id) => !tasks.any((task) => task.id == id));
    final query = _query.trim().toLowerCase();
    final byKind = switch (_kind) {
      _KindFilter.all => tasks,
      _KindFilter.image => tasks.where(
        (task) => task.kind == WallpaperDownloadKind.image || task.kind == WallpaperDownloadKind.paint,
      ),
      _KindFilter.video => tasks.where((task) => task.kind == WallpaperDownloadKind.video),
    };
    final searched = [
      for (final task in byKind)
        if (query.isEmpty || task.fileName.toLowerCase().contains(query) || task.title.toLowerCase().contains(query))
          task,
    ];
    final counts = <_DownloadFilter, int>{
      for (final filter in _DownloadFilter.values) filter: searched.where(filter.matches).length,
    };
    final visible = _sorted([
      for (final task in searched)
        if (_filter.matches(task)) task,
    ]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        // A narrow row keeps no multi-select: the tick column would push the
        // name out of the width, and a row can still be dropped from its own
        // menu.
        if (stacked) _selected.clear();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [
            // The search, the kind, the state and the count stay put: only
            // the table under them travels, so a long history never carries
            // the filters away.
            _buildToolbar(context, stacked: stacked, shown: visible.length, counts: counts),
            if (_selected.isNotEmpty) _buildSelectionBar(context),
            Expanded(
              child: LayoutBuilder(
                builder: (context, area) {
                  // The table takes the room the rest of the page leaves. A
                  // wide window pages it — one page is exactly what the room
                  // holds, so the pager stays in sight; a touch shell starts
                  // with one batch and appends the next as the table's own
                  // scroll reaches its end.
                  final paged = !stacked;
                  final reserve = paged ? _kPagerRoom : _kFooterRoom;
                  final pageSize = math.max(1, ((area.maxHeight - reserve) / _kRowHeight).floor());
                  _paged = paged;
                  _total = visible.length;
                  // A row past the fold, so the touch table always has
                  // something to scroll: a first batch that fitted exactly
                  // would leave nothing to reach the end with.
                  _batch = paged ? pageSize : pageSize + 1;
                  _shown = paged
                      ? 0
                      : _shown == 0
                      ? math.min(_batch, visible.length)
                      : math.min(_shown, visible.length);
                  final pageCount = !paged || visible.isEmpty ? 0 : (visible.length / pageSize).ceil();
                  final page = pageCount == 0 ? 1 : _page.clamp(1, pageCount);
                  final pageItems = paged
                      ? visible.skip((page - 1) * pageSize).take(pageSize).toList()
                      : visible.take(_shown).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: DsSpace.s8,
                    children: [
                      Expanded(
                        child: DsTable<WallpaperDownloadTask>(
                          semanticLabel: t.settings.downloadManagerTitle,
                          style: const DsTableStyle(rowHeight: _kRowHeight),
                          columns: _columns(context, narrow: area.maxWidth < 720),
                          rows: pageItems,
                          rowKey: (task) => task.id,
                          scrollController: _tableScroll,
                          sort: _sort,
                          sortLocally: false,
                          onSortChanged: (sort) => _refilter(() => _sort = sort),
                          selected: _selected,
                          onSelectionChanged: stacked
                              ? null
                              : (next) => setState(() {
                                  _selected
                                    ..clear()
                                    ..addAll([
                                      for (final key in next)
                                        if (key is String) key,
                                    ]);
                                }),
                          onRowPressed: _openPreview,
                          showRowMenuButton: true,
                          rowMenuBuilder: _rowMenu,
                          emptyView: DsEmptyState(
                            icon: DsIcon(_filter.emptyIcon),
                            title: Text(
                              tasks.isEmpty ? t.settings.downloadManagerEmpty : t.settings.downloadFilterEmpty,
                            ),
                            description: tasks.isEmpty ? Text(t.settings.downloadManagerEmptyDesc) : null,
                          ),
                        ),
                      ),
                      if (!paged && visible.isNotEmpty) _buildMoreFooter(context),
                      if (pageCount > 1)
                        Align(
                          alignment: AlignmentDirectional.center,
                          child: DsPagination(
                            page: page,
                            pageCount: pageCount,
                            semanticLabel: t.settings.downloadManagerTitle,
                            onChanged: (next) {
                              if (next == page) return;
                              _goToPage(next);
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// The search, the kind of media, the count and the settings button, with
  /// the state and its counts under them.
  Widget _buildToolbar(
    BuildContext context, {
    required bool stacked,
    required int shown,
    required Map<_DownloadFilter, int> counts,
  }) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final search = DsSearchField(
      controller: _search,
      placeholder: t.settings.downloadSearchPlaceholder,
      semanticLabel: t.settings.downloadSearchPlaceholder,
      onChanged: (value) => _refilter(() => _query = value),
    );
    final kind = DsSegmentedControl<_KindFilter>(
      value: _kind,
      semanticLabel: t.settings.downloadKindFilter,
      onChanged: (value) => _refilter(() => _kind = value),
      segments: [
        DsSegment(value: _KindFilter.all, label: Text(t.settings.downloadFilterAll)),
        DsSegment(value: _KindFilter.image, label: Text(t.settings.backgroundImage)),
        DsSegment(value: _KindFilter.video, label: Text(t.settings.backgroundVideo)),
      ],
    );
    final status = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DsSegmentedControl<_DownloadFilter>(
        value: _filter,
        semanticLabel: t.settings.downloadManagerTitle,
        onChanged: (value) => _refilter(() => _filter = value),
        segments: [
          for (final filter in _DownloadFilter.values)
            DsSegment(value: filter, label: Text('${filter.label(t)} ${counts[filter] ?? 0}')),
        ],
      ),
    );
    final count = Text(
      t.settings.downloadSummary(total: '$shown'),
      style: theme.typography.caption.copyWith(color: colors.textMuted),
    );
    final settingsButton = DsButton.icon(
      variant: DsButtonVariant.secondary,
      onPressed: () => unawaited(_openSettings()),
      icon: const DsIcon(DsIcons.settings),
      semanticLabel: t.settings.downloadSettings,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        if (stacked) ...[
          search,
          Row(
            spacing: DsSpace.s8,
            children: [
              Flexible(
                child: Align(alignment: AlignmentDirectional.centerStart, child: kind),
              ),
              count,
              settingsButton,
            ],
          ),
        ] else
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(child: search),
              kind,
              count,
              settingsButton,
            ],
          ),
        status,
      ],
    );
  }

  /// The ticked rows' one action, while there are any.
  Widget _buildSelectionBar(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Row(
      spacing: DsSpace.s8,
      children: [
        Expanded(
          child: Text(
            t.settings.downloadSelectedCount(count: _selected.length),
            style: theme.typography.small.copyWith(color: colors.text),
          ),
        ),
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          leading: const DsIcon(DsIcons.trash2, size: 14),
          onPressed: () => unawaited(_removeSelected()),
          child: Text(t.settings.downloadDeleteSelected(count: _selected.length)),
        ),
      ],
    );
  }

  /// The touch list's footer: a spinner while the next screenful is being
  /// appended, otherwise how much of the history is listed.
  Widget _buildMoreFooter(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final style = theme.typography.caption.copyWith(color: colors.textMuted);
    if (_loadingMore) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: DsSpace.s8,
        children: [
          const SizedBox.square(dimension: 14, child: DsSpinner()),
          Text(t.settings.downloadLoadingMore, style: style),
        ],
      );
    }
    return Center(
      child: Text(
        t.settings.downloadLoadedCount(shown: '$_shown', total: '$_total'),
        style: style,
      ),
    );
  }

  /// The table's columns: the file with its thumbnail and state, then what is
  /// fixed about it (its size and when it ran, dropped on a narrow table so
  /// the row still fits) and the one action of every phase.
  List<DsTableColumn<WallpaperDownloadTask>> _columns(BuildContext context, {required bool narrow}) {
    final t = context.t;
    return [
      DsTableColumn<WallpaperDownloadTask>(
        id: 'name',
        label: t.settings.downloadColumnFile,
        value: (task) => task.fileName,
        text: (task) => task.fileName,
        cell: _nameCell,
        width: const DsTableColumnWidth.flex(3, 160),
        sortable: true,
      ),
      if (!narrow) ...[
        DsTableColumn<WallpaperDownloadTask>(
          id: 'size',
          label: t.settings.downloadColumnSize,
          value: (task) => task.total > 0 ? task.total : task.received,
          text: (task) => _formatBytes(task.total > 0 ? task.total : task.received),
          numeric: true,
          sortable: true,
          width: const DsTableColumnWidth.intrinsic(min: 88),
        ),
        DsTableColumn<WallpaperDownloadTask>(
          id: 'time',
          label: t.settings.downloadColumnTime,
          value: (task) => (task.finishedAt ?? task.startedAt).millisecondsSinceEpoch,
          text: (task) => downloadStampOf(task.finishedAt ?? task.startedAt),
          sortable: true,
          width: const DsTableColumnWidth.intrinsic(min: 92),
        ),
      ],
      DsTableColumn<WallpaperDownloadTask>(
        id: 'actions',
        label: t.settings.downloadColumnActions,
        alignment: DsTableCellAlignment.end,
        cell: (context, task) => _actionButton(context, task, compact: narrow),
        width: DsTableColumnWidth.fixed(narrow ? 48 : 120),
      ),
    ];
  }

  /// The file's row: its thumbnail, the name and the phase badge beside it, so
  /// a narrow table keeps the state without a column of its own.
  Widget _nameCell(BuildContext context, WallpaperDownloadTask task) {
    return Row(
      spacing: DsSpace.s8,
      children: [
        _Thumb(task: task),
        Expanded(child: Text(task.fileName, maxLines: 1, overflow: TextOverflow.ellipsis)),
        _stateBadge(context, task),
      ],
    );
  }

  /// What the manager knows about a row: how far it has gone, that it waits,
  /// that it landed or that it stopped.
  Widget _stateBadge(BuildContext context, WallpaperDownloadTask task) {
    final t = context.t;
    return switch (task.phase) {
      WallpaperDownloadPhase.running => DsBadge(
        status: DsStatus.info,
        label: Text(
          task.total > 0
              ? t.settings.downloadPercent(percent: '${task.received * 100 ~/ task.total}')
              : t.settings.downloadStatusRunning,
        ),
      ),
      WallpaperDownloadPhase.paused => DsBadge(status: DsStatus.warning, label: Text(t.settings.downloadStatusPaused)),
      WallpaperDownloadPhase.done => DsBadge(status: DsStatus.success, label: Text(t.settings.downloadStatusDone)),
      WallpaperDownloadPhase.failed => DsBadge(status: DsStatus.danger, label: Text(t.settings.downloadStatusFailed)),
    };
  }

  /// The row's one button: stop or continue a transfer, fetch a failed one
  /// again, or open the file that landed.
  Widget _actionButton(BuildContext context, WallpaperDownloadTask task, {required bool compact}) {
    final t = context.t;
    final controller = ref.read(wallpaperDownloadsProvider.notifier);
    final saved = task.filePath;
    final (icon, label, onPressed) = switch (task.phase) {
      WallpaperDownloadPhase.running => (
        DsIcons.pause,
        t.settings.downloadPause,
        () => unawaited(controller.pause(task.id)),
      ),
      WallpaperDownloadPhase.paused => (
        DsIcons.play,
        t.settings.downloadResume,
        task.isResumable ? () => unawaited(controller.resume(task.id)) : null,
      ),
      WallpaperDownloadPhase.failed => (
        DsIcons.rotateCw,
        t.common.retry,
        task.isRetriable ? () => unawaited(controller.retry(task.id)) : null,
      ),
      WallpaperDownloadPhase.done => (
        DsIcons.externalLink,
        t.settings.downloadOpenFile,
        saved == null ? null : () => unawaited(openDownloadedPath(context, saved)),
      ),
    };
    final quiet = task.phase == WallpaperDownloadPhase.running || task.phase == WallpaperDownloadPhase.done;
    if (compact) {
      return DsButton.icon(
        variant: quiet ? DsButtonVariant.secondary : DsButtonVariant.primary,
        size: DsSize.sm,
        icon: DsIcon(icon, size: 16),
        semanticLabel: label,
        onPressed: onPressed,
      );
    }
    return DsButton(
      size: DsSize.xs,
      variant: quiet ? DsButtonVariant.secondary : DsButtonVariant.primary,
      leading: DsIcon(icon, size: 14),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  /// The row's context menu: the preview it opens on a tap, the phase's verbs,
  /// its folder and address, the full detail, and its removal.
  List<Widget> _rowMenu(BuildContext context, WallpaperDownloadTask task) {
    final t = context.t;
    final controller = ref.read(wallpaperDownloadsProvider.notifier);
    final saved = task.filePath;
    final moving = task.isRunning || task.phase == WallpaperDownloadPhase.paused;
    return [
      DsMenuItem(
        leading: const DsIcon(DsIcons.eye),
        label: Text(t.settings.backgroundPreviewMedia),
        onPressed: () => _openPreview(task),
      ),
      if (moving)
        DsMenuItem(
          leading: DsIcon(task.isRunning ? DsIcons.pause : DsIcons.play),
          label: Text(task.isRunning ? t.settings.downloadPause : t.settings.downloadResume),
          onPressed: task.isRunning
              ? () => unawaited(controller.pause(task.id))
              : task.isResumable
              ? () => unawaited(controller.resume(task.id))
              : null,
        ),
      if (task.isRetriable)
        DsMenuItem(
          leading: const DsIcon(DsIcons.rotateCw),
          label: Text(t.common.retry),
          onPressed: () => unawaited(controller.retry(task.id)),
        ),
      if (task.phase == WallpaperDownloadPhase.done && saved != null)
        DsMenuItem(
          leading: const DsIcon(DsIcons.externalLink),
          label: Text(t.settings.downloadOpenFile),
          onPressed: () => unawaited(openDownloadedPath(context, saved)),
        ),
      DsMenuItem(
        leading: const DsIcon(DsIcons.folderOpen),
        label: Text(t.settings.downloadManagerOpenFolder),
        onPressed: () => unawaited(openDownloadedPath(context, task.directory)),
      ),
      if ((task.url ?? '').isNotEmpty)
        DsMenuItem(
          leading: const DsIcon(DsIcons.link),
          label: Text(t.settings.backgroundCopyAddress),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: task.url!));
            if (context.mounted) showDsToast(context: context, title: t.common.copied);
          },
        ),
      const DsMenuDivider(),
      DsMenuItem(
        leading: const DsIcon(DsIcons.slidersHorizontal),
        label: Text(t.settings.downloadDetailTitle),
        onPressed: () => unawaited(showWallpaperDownloadDetail(context, task.id)),
      ),
      const DsMenuDivider(),
      DsMenuItem(
        leading: const DsIcon(DsIcons.trash2),
        label: Text(t.settings.downloadRemove),
        destructive: true,
        onPressed: () => unawaited(_remove(task)),
      ),
    ];
  }
}

/// The row's thumbnail: the saved file once it exists, the catalogue's still
/// while it moves or failed, and the kind's glyph on the accent tint when
/// neither is at hand — the row keeps its shape either way.
final class _Thumb extends StatelessWidget {
  const _Thumb({required this.task});

  static const double _width = 48;
  static const double _height = 32;

  final WallpaperDownloadTask task;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final video = task.kind == WallpaperDownloadKind.video;
    final poster = _posterOf(task);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: _width,
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DsImage(
              image: poster == null
                  ? null
                  : _imageOf(poster, width: (_width * 2).round(), height: (_height * 2).round()),
              width: _width,
              height: _height,
              fallback: _glyph(colors),
            ),
            if (video) const Center(child: DsIcon(DsIcons.play, size: 18, color: Color(0xE6FFFFFF))),
          ],
        ),
      ),
    );
  }

  Widget _glyph(DsColors colors) => ColoredBox(
    color: colors.accentTint,
    child: Center(
      child: DsIcon(
        task.kind == WallpaperDownloadKind.video ? DsIcons.video : DsIcons.image,
        size: 20,
        color: colors.accentText,
      ),
    ),
  );
}

/// The still a row shows before its file is here: the saved picture once it
/// exists, else the catalogue's thumbnail, else the picture's own address. A
/// clip shows its still, never the clip file.
String? _posterOf(WallpaperDownloadTask task) {
  final saved = task.filePath;
  if (task.kind != WallpaperDownloadKind.video && saved != null && saved.isNotEmpty) {
    // A `file:` address, so the preview page's own backdrop reads it too.
    return Uri.file(saved).toString();
  }
  // A clip's still, taken when the download landed: the catalogue
  // often sends no cover for a clip, and the file itself cannot be painted.
  final still = task.thumbPath;
  if (still != null && still.isNotEmpty && File(still).existsSync()) return Uri.file(still).toString();
  final url = task.url?.trim() ?? '';
  final thumb = task.thumbUrl?.trim() ?? '';
  // The still the catalogue sent, when it sent a picture of its own: a
  // trail that repeats the clip's address has no frame to show.
  if (thumb.isNotEmpty && thumb != url && !_isClipAddress(thumb)) return thumb;
  if (task.kind == WallpaperDownloadKind.image && url.isNotEmpty) return url;
  return null;
}

/// Whether [address] names a clip rather than a still — a clip cannot be
/// decoded into a thumbnail, so the row shows its glyph instead.
bool _isClipAddress(String address) {
  final path = address.split('?').first.toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.webm') ||
      path.endsWith('.m3u8') ||
      path.endsWith('.mov') ||
      path.endsWith('.m4v');
}

/// [address] as an image source: a `file:` address becomes the file itself,
/// everything else the app's shared network cache — the same pair the
/// background gallery draws its tiles with.
ImageProvider _imageOf(String address, {int? width, int? height}) {
  final uri = Uri.tryParse(address);
  // A `file:` address, a bare path, or a Windows path whose drive letter
  // reads as a one-letter scheme; everything else is the network's.
  final local = switch (uri?.scheme) {
    'file' => uri?.toFilePath(),
    final scheme when scheme != null && scheme.length > 1 => null,
    _ => address,
  };
  if (local != null && local.isNotEmpty) {
    final image = FileImage(File(local));
    return width == null && height == null ? image : ResizeImage(image, width: width, height: height);
  }
  return cachedImage(address, width: width, height: height);
}

/// The download as an entry of the background preview: the saved file once it
/// is here, the source's address before that.
WallpaperItem _previewItemOf(WallpaperDownloadTask task) {
  final saved = task.filePath;
  final local = saved != null && saved.isNotEmpty ? Uri.file(saved).toString() : null;
  return WallpaperItem(
    (b) => b
      ..id = task.id
      ..name = task.fileName
      ..url = local ?? (task.url ?? '')
      ..thumb = _posterOf(task) ?? ''
      ..video = task.kind == WallpaperDownloadKind.video,
  );
}

/// Opens [taskId]'s media in the background preview, walking every row the
/// manager can show: the downloaded pictures and clips sit apart behind the
/// preview's switch, and nothing offers a download — these files are kept.
void openDownloadPreview(BuildContext context, WidgetRef ref, String taskId) {
  final walkable = [
    for (final task in ref.read(wallpaperDownloadsProvider))
      if (_canPreview(task)) task,
  ];
  final at = walkable.indexWhere((task) => task.id == taskId);
  if (at < 0) return;
  unawaited(
    showWallpaperPreview(
      context,
      [for (final task in walkable) _previewItemOf(task)],
      at,
      downloadable: false,
      kindSwitch: true,
    ),
  );
}

/// Whether a row has something the preview can show: its saved file, or the
/// address a transfer reads from.
bool _canPreview(WallpaperDownloadTask task) {
  final saved = task.filePath;
  if (saved != null && saved.isNotEmpty) return true;
  return (task.url ?? '').trim().isNotEmpty;
}

/// The row's category chip: 壁纸 or 视频, the way a download tool names
/// its kinds.
final class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind});

  final WallpaperDownloadKind kind;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final video = kind == WallpaperDownloadKind.video;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
      decoration: BoxDecoration(
        color: video ? colors.info.tint : colors.accentTint,
        borderRadius: BorderRadius.circular(DsSpace.s8),
      ),
      child: Text(
        video ? t.settings.backgroundVideo : t.settings.backgroundImage,
        style: theme.typography.caption.copyWith(color: video ? colors.info.text : colors.accentText),
      ),
    );
  }
}

/// Hands [path] to the system; a file opens in its viewer, a folder in the
/// platform's file manager.
Future<void> openDownloadedPath(BuildContext context, String path) async {
  final result = await OpenFile.open(path);
  if (result.type != ResultType.done && context.mounted) {
    showDsToast(context: context, title: context.t.settings.downloadOpenFailed, status: DsStatus.danger);
  }
}

/// A local moment for a row: the clock on today's entries, a short date
/// with the clock otherwise.
String downloadStampOf(DateTime time) {
  final now = DateTime.now();
  final sameDay = now.year == time.year && now.month == time.month && now.day == time.day;
  final clock = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  return sameDay ? clock : '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} $clock';
}

/// Renders a bytes figure the way a file manager would: the largest unit
/// that stays above one, one decimal from KB on.
String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '${value.round()} B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}
