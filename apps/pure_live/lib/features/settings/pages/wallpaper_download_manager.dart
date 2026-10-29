import 'dart:async' show unawaited;

import 'package:any_image_view/any_image_view.dart' show AnyImageView;
import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart' show OpenFile, ResultType;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/pages/wallpaper_preview_page.dart' show showWallpaperPreview;
import 'package:pure_live/features/settings/surface/settings_preview.dart' show SettingsPreviewTitleBar;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// How many task cards one page of the manager's list carries.
const int _kDownloadsPageSize = 8;

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
            const Expanded(child: WallpaperDownloadsPane()),
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
    final poster = saved != null && saved.isNotEmpty && task.kind != WallpaperDownloadKind.video
        ? saved
        : (task.thumbUrl?.isNotEmpty == true
              ? task.thumbUrl
              : (task.kind == WallpaperDownloadKind.image ? task.url : null));
    final previewItem = WallpaperItem(
      (b) => b
        ..id = task.id
        ..name = task.fileName
        ..url = saved != null && saved.isNotEmpty && task.kind != WallpaperDownloadKind.video
            ? Uri.file(saved).toString()
            : (task.url ?? '')
        ..thumb = poster ?? ''
        ..video = task.kind == WallpaperDownloadKind.video,
    );
    final preview = DsPressable(
      semanticLabel: t.settings.downloadDetailPreview,
      onPressed: poster == null ? null : () => unawaited(showWallpaperPreview(context, [previewItem], 0)),
      builder: (context, states, _) => Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: colors.control,
            child: poster == null
                ? Center(child: DsIcon(DsIcons.image, size: 32, color: colors.textSubtle))
                : AnyImageView(
                    imagePath: poster,
                    fit: BoxFit.contain,
                    placeholderWidget: const ColoredBox(color: Color(0x14000000)),
                    errorWidget: Center(child: DsIcon(DsIcons.image, size: 32, color: colors.textSubtle)),
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

  /// The word the chip and the empty state use.
  String label(Translations t) => switch (this) {
    all => t.settings.downloadFilterAll,
    running => t.settings.downloadStatusRunning,
    done => t.settings.downloadStatusDone,
    failed => t.settings.downloadStatusFailed,
  };

  /// The chip's glyph.
  DsIconData get icon => switch (this) {
    all => DsIcons.layoutGrid,
    running => DsIcons.download,
    done => DsIcons.circleCheck,
    failed => DsIcons.circleAlert,
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

/// The download manager pane, laid out the way the reference draws its
/// download centre: a badge-headed summary with the save folder and its
/// shortcuts, status capsules with counts beside a search field and a kind
/// dropdown, the counting row with the kind's quick chips, task cards in
/// three zones — text, status, actions — and a paging footer.
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
  _DownloadFilter _filter = _DownloadFilter.all;
  _KindFilter _kind = _KindFilter.all;
  int _page = 1;

  /// Whether this build lays the pane out for a narrow window; the cards
  /// read it to pick their own shape.
  bool _compact = false;

  /// The multi-select: task ids the viewer ticked. Selections survive
  /// paging and filtering; only the rows' own departure clears them.
  final Set<String> _selected = {};

  /// The manager's settings: the folder the files land in and the way in.
  /// The pane itself stays about the list — these belong behind one
  /// button, in the panel the button opens.
  Future<void> _openSettings() {
    final t = context.t;
    final directory = ref.read(downloadDirectoryProvider).effectivePath;
    return showDsPanel<void>(
      context: context,
      builder: (panelContext) {
        final theme = DsTheme.of(panelContext);
        return DsPanel(
          title: Text(t.settings.downloadSettings),
          style: DsPanelStyle(background: theme.colors.surface),
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
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final tasks = ref.watch(wallpaperDownloadsProvider);
    final controller = ref.read(wallpaperDownloadsProvider.notifier);
    final byKind = switch (_kind) {
      _KindFilter.all => tasks,
      _KindFilter.image => tasks.where(
        (task) => task.kind == WallpaperDownloadKind.image || task.kind == WallpaperDownloadKind.paint,
      ),
      _KindFilter.video => tasks.where((task) => task.kind == WallpaperDownloadKind.video),
    };
    final counts = <_DownloadFilter, int>{
      for (final filter in _DownloadFilter.values) filter: byKind.where(filter.matches).length,
    };
    final visible = [
      for (final task in byKind)
        if (_filter.matches(task)) task,
    ];
    // The pager follows the filters: narrowing the list never leaves the
    // reader on a page that no longer exists.
    final pageCount = (visible.length / _kDownloadsPageSize).ceil().clamp(1, 1 << 16);
    if (_page > pageCount) _page = pageCount;
    final pageItems = visible.skip((_page - 1) * _kDownloadsPageSize).take(_kDownloadsPageSize).toList();
    final noneAtAll = tasks.isEmpty;
    final Widget content;
    if (pageItems.isEmpty) {
      content = Center(
        child: DsEmptyState(
          icon: DsIcon(_filter.emptyIcon),
          title: Text(noneAtAll ? t.settings.downloadManagerEmpty : t.settings.downloadFilterEmpty),
          description: noneAtAll ? Text(t.settings.downloadManagerEmptyDesc) : null,
        ),
      );
    } else {
      content = CardList<WallpaperDownloadTask>(
        items: pageItems,
        itemBuilder: (context, task) => _TaskCard(
          task: task,
          compact: _compact,
          ticked: _selected.contains(task.id),
          onToggle: () => setState(() {
            if (!_selected.remove(task.id)) _selected.add(task.id);
          }),
          onOpen: () => unawaited(showWallpaperDownloadDetail(context, task.id)),
          onOpenFolder: () => unawaited(openDownloadedPath(context, task.directory)),
          onPause: task.isRunning ? () => unawaited(controller.pause(task.id)) : null,
          onResume: task.phase == WallpaperDownloadPhase.paused ? () => unawaited(controller.resume(task.id)) : null,
          onRetry: task.isRetriable ? () => unawaited(controller.retry(task.id)) : null,
          onRemove: () => unawaited(_remove(task)),
        ),
      );
    }
    final compact = LiveWindow.isCompact(MediaQuery.sizeOf(context).width);
    _compact = compact;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    // Ticks that name rows the list no longer holds no longer count.
    _selected.removeWhere((id) => !tasks.any((task) => task.id == id));
    final allTicked = visible.isNotEmpty && visible.every((task) => _selected.contains(task.id));
    // The filters stack on a narrow window — chips alone on the first row,
    // search and the gear under them — and share one row on a wide one.
    final kindSelect = SizedBox(
      width: 140,
      child: DsSelect<_KindFilter>(
        value: _kind,
        semanticLabel: t.settings.downloadKindFilter,
        options: [
          DsSelectOption(value: _KindFilter.all, label: t.settings.downloadTypeAll),
          DsSelectOption(value: _KindFilter.image, label: t.settings.backgroundImage),
          DsSelectOption(value: _KindFilter.video, label: t.settings.backgroundVideo),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _kind = value);
        },
      ),
    );
    final statusChips = DsChoiceChips<_DownloadFilter>(
      value: _filter,
      onChanged: (value) => setState(() => _filter = value),
      semanticLabel: t.settings.downloadManagerTitle,
      options: [
        for (final filter in _DownloadFilter.values)
          DsChipOption(
            value: filter,
            leading: DsIcon(filter.icon, size: 14),
            label: Text('${filter.label(t)}  ${counts[filter] ?? 0}'),
          ),
      ],
    );
    final settingsButton = DsButton.icon(
      variant: DsButtonVariant.secondary,
      onPressed: () => unawaited(_openSettings()),
      icon: const DsIcon(DsIcons.settings),
      semanticLabel: t.settings.downloadSettings,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s16, inset, 0),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s8,
                  children: [
                    statusChips,
                    Row(
                      spacing: DsSpace.s8,
                      children: [
                        Expanded(child: kindSelect),
                        settingsButton,
                      ],
                    ),
                  ],
                )
              : Row(
                  spacing: DsSpace.s12,
                  children: [
                    Expanded(child: statusChips),
                    kindSelect,
                    settingsButton,
                  ],
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              DsCheckbox(
                value: allTicked,
                semanticLabel: t.settings.downloadSelectAll,
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _selected.addAll([for (final task in visible) task.id]);
                  } else {
                    _selected.clear();
                  }
                }),
              ),
              Text(
                _selected.isEmpty
                    ? t.settings.downloadSelectAll
                    : t.settings.downloadSelectedCount(count: _selected.length),
                style: theme.typography.small.copyWith(color: colors.text),
              ),
              const Spacer(),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.trash2, size: 14),
                onPressed: _selected.isEmpty ? null : () => unawaited(_removeSelected()),
                child: Text(t.settings.downloadDeleteSelected(count: _selected.length)),
              ),
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.trash2, size: 14),
                onPressed: tasks.isEmpty ? null : () => unawaited(_removeAll()),
                child: Text(t.settings.downloadDeleteAll),
              ),
            ],
          ),
        ),
        Expanded(child: content),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.settings.downloadPageSummary(total: visible.length, page: _page, count: pageCount),
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ),
              DsPagination(
                page: _page,
                pageCount: pageCount,
                onChanged: (page) => setState(() => _page = page),
                semanticLabel: t.settings.downloadManagerTitle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One download as the reference's card: on a wide window, three zones —
/// the media's thumbnail beside the text block, the status's fixed-width
/// zone, and the actions that phase offers; on a narrow one, the phone's
/// two-row tile — head (tick, thumbnail, name, size) over the progress and
/// the actions, all leading to the same detail.
final class _TaskCard extends ConsumerWidget {
  const _TaskCard({
    required this.task,
    required this.compact,
    required this.ticked,
    required this.onToggle,
    required this.onOpen,
    required this.onOpenFolder,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onRemove,
  });

  final WallpaperDownloadTask task;

  /// Whether this build lays the card out for a narrow window.
  final bool compact;

  /// Whether the multi-select holds this row.
  final bool ticked;

  /// Adds or drops this row from the multi-select.
  final VoidCallback onToggle;

  /// Opens the row's detail.
  final VoidCallback onOpen;
  final VoidCallback onOpenFolder;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final running = task.isRunning;
    final paused = task.phase == WallpaperDownloadPhase.paused;
    final moving = running || paused;
    final total = task.total;
    final fraction = total > 0 ? (task.received / total).clamp(0.0, 1.0) : null;
    final meta = [
      if (running && total > 0)
        t.settings.downloadProgress(received: _formatBytes(task.received), total: _formatBytes(total))
      else
        _formatBytes(task.received),
      if (running && task.speedBps > 0) '${_formatBytes(task.speedBps)}/s',
      if (task.phase == WallpaperDownloadPhase.done && task.finishedAt != null)
        t.settings.downloadFinishedAt(time: downloadStampOf(task.finishedAt!))
      else
        t.settings.downloadStartedAt(time: downloadStampOf(task.startedAt)),
    ].join(' · ');
    if (compact) {
      final statusWord = switch (task.phase) {
        WallpaperDownloadPhase.running => t.settings.downloadStatusRunning,
        WallpaperDownloadPhase.paused => t.settings.downloadPausedHint,
        WallpaperDownloadPhase.done => t.settings.downloadStatusDone,
        WallpaperDownloadPhase.failed => t.settings.downloadStatusFailed,
      };
      final statusColor = switch (task.phase) {
        WallpaperDownloadPhase.running || WallpaperDownloadPhase.paused => colors.info.text,
        WallpaperDownloadPhase.done => colors.success.text,
        WallpaperDownloadPhase.failed => colors.danger.text,
      };
      return DsCard(
        onPressed: onOpen,
        semanticLabel: task.fileName,
        style: DsCardStyle(
          padding: const EdgeInsets.all(DsSpace.s12),
          borderRadius: BorderRadius.circular(theme.radii.card),
          background: moving ? colors.accentTint : null,
          borderColor: moving ? colors.accent : null,
          borderWidth: moving ? 1 : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Row(
              spacing: DsSpace.s8,
              children: [
                DsCheckbox(value: ticked, semanticLabel: task.fileName, onChanged: (_) => onToggle()),
                _Thumb(task: task, width: 72, height: 48),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s4,
                    children: [
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          Expanded(
                            child: Text(
                              task.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.small.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                            ),
                          ),
                          _KindChip(kind: task.kind),
                        ],
                      ),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (moving)
              Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: DsProgressBar(value: fraction, semanticLabel: task.fileName),
                  ),
                  Text(
                    total > 0 ? '${task.received * 100 ~/ total}%' : '',
                    style: theme.typography.caption.copyWith(fontWeight: FontWeight.w700, color: colors.text),
                  ),
                ],
              ),
            Row(
              spacing: DsSpace.s8,
              children: [
                Text(
                  statusWord,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(fontWeight: FontWeight.w600, color: statusColor),
                ),
                const Spacer(),
                _CompactActions(
                  task: task,
                  onOpenFolder: onOpenFolder,
                  onPause: onPause,
                  onResume: onResume,
                  onRetry: onRetry,
                  onRemove: onRemove,
                ),
              ],
            ),
          ],
        ),
      );
    }
    return DsCard(
      onPressed: onOpen,
      semanticLabel: task.fileName,
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s12),
        borderRadius: BorderRadius.circular(theme.radii.card),
        // A moving transfer is the live one on the page: the reference
        // carries it on the accent's own tint.
        background: moving ? colors.accentTint : null,
        borderColor: moving ? colors.accent : null,
        borderWidth: moving ? 1 : null,
      ),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          DsCheckbox(value: ticked, semanticLabel: task.fileName, onChanged: (_) => onToggle()),
          _Thumb(task: task),
          Expanded(
            child: _TextBlock(task: task, meta: meta),
          ),
          SizedBox(
            width: 216,
            child: _StatusZone(task: task, fraction: fraction),
          ),
          _Actions(
            task: task,
            onOpenFolder: onOpenFolder,
            onPause: onPause,
            onResume: onResume,
            onRetry: onRetry,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }
}

/// The card's text block: the name over its category chip, the size and
/// time line, and the file's path where the folder will land it.
final class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.task, required this.meta});

  final WallpaperDownloadTask task;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final failure = task.phase == WallpaperDownloadPhase.failed ? (task.error ?? '').trim() : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s3,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(
                task.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
              ),
            ),
            _KindChip(kind: task.kind),
          ],
        ),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.caption.copyWith(color: colors.textMuted),
        ),
        Text(
          failure.isNotEmpty ? failure : '${task.directory}${task.fileName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.caption.copyWith(color: failure.isNotEmpty ? colors.danger.text : colors.textSubtle),
        ),
      ],
    );
  }
}

/// The card's fixed status zone. A moving transfer shows its bar with the
/// bold percent beside it and the time left under it; the terminal states
/// show their own mark and word, the way the reference's list does.
final class _StatusZone extends StatelessWidget {
  const _StatusZone({required this.task, required this.fraction});

  final WallpaperDownloadTask task;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    if (task.isRunning || task.phase == WallpaperDownloadPhase.paused) {
      final percent = task.total > 0 ? '${task.received * 100 ~/ task.total}%' : '';
      final eta = task.etaSeconds;
      final remaining = switch (task.phase) {
        WallpaperDownloadPhase.paused => t.settings.downloadPausedHint,
        _ when eta == null => t.settings.downloadStatusRunning,
        _ when eta >= 3600 => t.settings.downloadEtaHours(hours: eta ~/ 3600),
        _ when eta >= 60 => t.settings.downloadEtaMinutes(minutes: eta ~/ 60),
        _ => t.settings.downloadEtaSeconds(seconds: eta),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s3,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsProgressBar(value: fraction, semanticLabel: task.fileName),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  percent,
                  textAlign: TextAlign.end,
                  style: theme.typography.caption.copyWith(fontWeight: FontWeight.w700, color: colors.text),
                ),
              ),
            ],
          ),
          Text(
            remaining,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
        ],
      );
    }
    final done = task.phase == WallpaperDownloadPhase.done;
    return Row(
      spacing: DsSpace.s8,
      children: [
        DsIcon(
          done ? DsIcons.circleCheck : DsIcons.circleX,
          size: 20,
          color: done ? colors.success.text : colors.danger.text,
        ),
        Expanded(
          child: Text(
            done ? t.settings.downloadStatusDone : t.settings.downloadStatusFailed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: done ? colors.success.text : colors.danger.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// The card's thumbnail: the saved file once it exists, the catalogue's
/// still while it moves or failed, and the kind's glyph on the accent tint
/// when neither is at hand — the row keeps its shape either way.
final class _Thumb extends StatelessWidget {
  const _Thumb({required this.task, this.width = 96.0, this.height = 64.0});

  final WallpaperDownloadTask task;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final video = task.kind == WallpaperDownloadKind.video;
    final saved = task.filePath;
    final String? source;
    if (!video && saved != null && saved.isNotEmpty) {
      // The file itself, once it is there.
      source = saved;
    } else if (task.thumbUrl != null && task.thumbUrl!.isNotEmpty) {
      source = task.thumbUrl;
    } else if (!video && task.url != null && task.url!.isNotEmpty) {
      // A picture whose source sent no separate thumbnail still shows
      // itself.
      source = task.url;
    } else {
      source = null;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (source != null)
              AnyImageView(
                imagePath: source,
                fit: BoxFit.cover,
                placeholderWidget: ColoredBox(color: colors.control),
                errorWidget: _glyph(colors),
              )
            else
              _glyph(colors),
            if (task.kind == WallpaperDownloadKind.video)
              const Center(child: DsIcon(DsIcons.play, size: 20, color: Color(0xE6FFFFFF))),
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
        size: 24,
        color: colors.accentText,
      ),
    ),
  );
}

/// The narrow card's action row: icon-only buttons, one per thing the
/// phase can still do — the same verbs the wide card words.
final class _CompactActions extends StatelessWidget {
  const _CompactActions({
    required this.task,
    required this.onOpenFolder,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onRemove,
  });

  final WallpaperDownloadTask task;
  final VoidCallback onOpenFolder;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final lead = switch (task.phase) {
      WallpaperDownloadPhase.running => (const DsIcon(DsIcons.pause, size: 16), t.settings.downloadPause, onPause),
      WallpaperDownloadPhase.paused => (const DsIcon(DsIcons.play, size: 16), t.settings.downloadResume, onResume),
      WallpaperDownloadPhase.failed => (const DsIcon(DsIcons.rotateCw, size: 16), t.common.retry, onRetry),
      WallpaperDownloadPhase.done => (const DsIcon(DsIcons.externalLink, size: 16), t.settings.downloadOpenFile, null),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s4,
      children: [
        DsButton.icon(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          icon: lead.$1,
          semanticLabel: lead.$2,
          onPressed: lead.$3,
        ),
        DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          icon: const DsIcon(DsIcons.folderOpen, size: 16),
          semanticLabel: t.settings.downloadManagerOpenFolder,
          onPressed: onOpenFolder,
        ),
        DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          icon: const DsIcon(DsIcons.trash2, size: 16),
          semanticLabel: t.settings.downloadRemove,
          onPressed: onRemove,
        ),
      ],
    );
  }
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

/// The card's own action column, per phase: a moving transfer pauses or
/// continues, a failed one retries, and every row can reach its folder and
/// drop its record. The actions sit on the card itself — the reference
/// keeps no menu between the viewer and them.
final class _Actions extends StatelessWidget {
  const _Actions({
    required this.task,
    required this.onOpenFolder,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onRemove,
  });

  final WallpaperDownloadTask task;
  final VoidCallback onOpenFolder;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final folder = DsButton.icon(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      icon: const DsIcon(DsIcons.folderOpen, size: 16),
      semanticLabel: t.settings.downloadManagerOpenFolder,
      onPressed: onOpenFolder,
    );
    final remove = DsButton.icon(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      icon: const DsIcon(DsIcons.trash2, size: 16),
      semanticLabel: t.settings.downloadRemove,
      onPressed: onRemove,
    );
    return switch (task.phase) {
      WallpaperDownloadPhase.running => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          DsButton.icon(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            icon: const DsIcon(DsIcons.pause, size: 16),
            semanticLabel: t.settings.downloadPause,
            onPressed: onPause,
          ),
          folder,
          remove,
        ],
      ),
      WallpaperDownloadPhase.paused => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          DsButton.icon(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            icon: const DsIcon(DsIcons.play, size: 16),
            semanticLabel: t.settings.downloadResume,
            onPressed: onResume,
          ),
          folder,
          remove,
        ],
      ),
      WallpaperDownloadPhase.done => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [folder, remove],
      ),
      WallpaperDownloadPhase.failed => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: DsIcon(DsIcons.rotateCw, size: 14, color: colors.accentText),
            onPressed: onRetry,
            child: Text(t.common.retry, style: theme.typography.small.copyWith(color: colors.accentText)),
          ),
          folder,
          remove,
        ],
      ),
    };
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
