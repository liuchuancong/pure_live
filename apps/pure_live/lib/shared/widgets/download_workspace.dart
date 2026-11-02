import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/layout/window_breakpoints.dart' show LiveWindow;
import 'package:pure_live/shared/widgets/download_details.dart';

/// Whether the file a finished download names is still on disk.
///
/// A queue row is a record, not the media: the viewer can move, rename or
/// delete the file from outside the app and the row keeps pointing at it, so
/// 打开文件 fails with no explanation and 删除文件 reports success over nothing.
/// One stat per row answers that — never a directory scan, and never for a row
/// still owed bytes: a queued or paused transfer has no finished file to look
/// for (its parts sit beside the target under their own name), so it is not
/// missing, it is unfinished.
bool downloadFilePresent(String path) {
  final file = path.trim();
  if (file.isEmpty) return false;
  try {
    return File(file).existsSync();
  } on Object {
    // An unreadable path (a drive that went away mid-read) reads as absent:
    // the row then says the file is not there, which is what the viewer can act on.
    return false;
  }
}

/// One verb of a download queue's page head: 打开文件夹, 全部暂停, 清除已完成.
///
/// A verb the queue cannot answer for right now is left out rather than greyed:
/// 全部暂停 over an idle queue is a button that only fails, and the head has no
/// room to spend on it.
final class DownloadQueueAction {
  /// The verb [label] with [icon], acting through [onPressed].
  const DownloadQueueAction({required this.label, required this.icon, this.onPressed, this.destructive = false});

  /// What the verb says, in the manager's own words.
  final String label;

  /// The verb's glyph, shared by its button and by its row in the overflow.
  final DsIconData icon;

  /// Runs the verb; null keeps it out of the head.
  final VoidCallback? onPressed;

  /// Whether the verb costs bytes, so its overflow row reads as one.
  final bool destructive;
}

/// The head every download manager's own page wears: what the queue holds and
/// where its files land, the search, one entry to its filters, and the verbs
/// that act on the whole queue.
///
/// The three managers each wrote this line themselves — the same summary, the
/// same four verbs, and a narrow window that simply ran out of room and
/// overflowed. Here the shape is fixed once: a wide head shows the search, the
/// filter entry and the verbs beside each other, a narrow one keeps the search
/// and folds the rest into 更多, as every other page in the app does. The
/// summary and the directory are what the manager can answer and this cannot
/// read, so the page hands them in; [actions] that have nothing to act on are
/// left out by the caller (see [DownloadQueueAction]).
final class DownloadQueueHeader extends StatelessWidget {
  /// The head for [summary] over [directory], searching with [query], filtering
  /// through [onFilter] and acting through [actions].
  const DownloadQueueHeader({
    required this.summary,
    required this.directory,
    required this.searchHint,
    required this.query,
    required this.onQuery,
    required this.filterLabel,
    required this.filterActive,
    required this.onFilter,
    required this.actions,
    this.selectedLabel,
    this.selectionActions = const [],
    super.key,
  });

  /// The queue's own count line: how many tasks, how many moving, how many
  /// bytes, at what speed.
  final String summary;

  /// The folder the files land in — the line 打开文件夹 answers with.
  final String directory;

  /// The search box's own name.
  final String searchHint;

  /// What the search box holds.
  final String query;

  /// Takes the typed search to the queue.
  final ValueChanged<String> onQuery;

  /// The word for the filter entry, and for its row in the overflow.
  final String filterLabel;

  /// Whether a filter other than the search is holding the queue down.
  final bool filterActive;

  /// Opens the queue's filter panel.
  final VoidCallback onFilter;

  /// The verbs that act on the whole queue.
  final List<DownloadQueueAction> actions;

  /// What the ticked rows line says, e.g. 已选 3 项; null hides the line.
  final String? selectedLabel;

  /// The verbs that act on the ticked rows.
  final List<DownloadQueueAction> selectionActions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final compact = LiveWindow.isCompact(MediaQuery.sizeOf(context).width);
    final live = actions.where((action) => action.onPressed != null);
    final selected = selectionActions.where((action) => action.onPressed != null);
    final search = SizedBox(
      width: compact ? 132 : 220,
      child: DsSearchField(initialValue: query, onChanged: onQuery, placeholder: searchHint, semanticLabel: searchHint),
    );
    final filterButton = DsButton.icon(
      variant: filterActive ? DsButtonVariant.tinted : DsButtonVariant.ghost,
      size: DsSize.sm,
      onPressed: onFilter,
      icon: const DsIcon(DsIcons.filter),
      semanticLabel: filterLabel,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s12,
          children: [
            // The page's name belongs to the menu entry that opened it; what
            // only this page answers is how big the queue is and where its
            // files sit.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s3,
                children: [
                  Text(
                    summary,
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
            search,
            if (compact)
              DsMenuAnchor(
                align: DsAlign.end,
                semanticLabel: t.common.more,
                items: [
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.filter),
                    label: Text(filterLabel),
                    trailing: filterActive ? const DsIcon(DsIcons.check, size: 14) : null,
                    onPressed: onFilter,
                  ),
                  for (final action in live)
                    DsMenuItem(
                      leading: DsIcon(action.icon),
                      label: Text(action.label),
                      destructive: action.destructive,
                      onPressed: action.onPressed,
                    ),
                ],
                builder: (context, controller, _) => DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: controller.toggle,
                  icon: const DsIcon(DsIcons.ellipsisVertical),
                  semanticLabel: t.common.more,
                ),
              )
            else ...[
              filterButton,
              // Several verbs and a search box do not fit a 960 window: the
              // verbs give way to a sideways run, keeping the queue's own room.
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    spacing: DsSpace.s8,
                    children: [
                      for (final action in live)
                        DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          leading: DsIcon(action.icon, size: 14),
                          onPressed: action.onPressed,
                          child: Text(action.label),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (selectedLabel != null && selected.isNotEmpty)
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(selectedLabel!, style: theme.typography.small.copyWith(color: colors.textMuted)),
              ),
              for (final action in selected)
                DsButton(
                  variant: action.destructive ? DsButtonVariant.dangerSoft : DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: DsIcon(action.icon, size: 14),
                  onPressed: action.onPressed,
                  child: Text(action.label),
                ),
            ],
          ),
      ],
    );
  }
}

/// A wide download manager's right column: the selected task's facts on the
/// page's own surface. Nothing selected leaves the column empty rather than
/// inventing a task to talk about.
final class DownloadDetailsPane extends StatelessWidget {
  /// The facts [details] states; null keeps the column silent.
  const DownloadDetailsPane({required this.details, super.key});

  /// The selected task's facts, or null when the queue has nothing to show.
  final DownloadDetails? details;

  @override
  Widget build(BuildContext context) {
    final details = this.details;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.s8),
      child: details == null
          ? const SizedBox.shrink()
          : DsSurface(
              decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
              padding: const EdgeInsets.all(DsSpace.s12),
              child: DownloadDetailsBody(details: details),
            ),
    );
  }
}
