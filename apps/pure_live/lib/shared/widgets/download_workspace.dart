import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/layout/window_breakpoints.dart' show LiveWindow;
import 'package:pure_live/shared/widgets/download_details.dart';

/// One view of a download queue as its rail shows it: the value a filter
/// selects, its glyph, its name, and how many tasks it holds.
final class DownloadFilterOption<T> {
  /// One rail line.
  const DownloadFilterOption({required this.value, required this.icon, required this.label, required this.count});

  /// What selecting the line means to the manager.
  final T value;

  /// The line's glyph.
  final DsIconData icon;

  /// The line's name, in the manager's own words.
  final String label;

  /// How many tasks the view holds.
  final int count;
}

/// The wide download manager's left column: the queue's views, the current
/// one lit, each with its count.
final class DownloadFilterRail<T> extends StatelessWidget {
  /// The rail for [options], [selected] talking for the queue.
  const DownloadFilterRail({required this.options, required this.selected, required this.onSelected, super.key});

  /// Every view the manager offers.
  final List<DownloadFilterOption<T>> options;

  /// The view the queue is showing.
  final T selected;

  /// Switches the queue to a view.
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.s8),
      child: DsListSection(
        children: [
          for (final option in options)
            DsListRow(
              leading: DsIcon(option.icon),
              title: Text(option.label),
              detail: Text('${option.count}'),
              selected: option.value == selected,
              onPressed: () => onSelected(option.value),
            ),
        ],
      ),
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

/// The three-pane shape every download manager takes when its window has
/// room: the filters, the queue, and the selected task's facts. The pages
/// still own what each pane says — this only fixes the arrangement, so the
/// three managers cannot drift apart in widths or spacing.
final class DownloadWorkspace<T> extends StatelessWidget {
  /// The workspace for [options], with [list] in the middle and [details] at
  /// the right; [padding] sets it off from the page's edge.
  const DownloadWorkspace({
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.list,
    required this.details,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// Every view the manager offers.
  final List<DownloadFilterOption<T>> options;

  /// The view the queue is showing.
  final T selected;

  /// Switches the queue to a view.
  final ValueChanged<T> onSelected;

  /// The queue itself, built by the manager.
  final Widget list;

  /// The selected task's facts, or null.
  final DownloadDetails? details;

  /// The inset the page keeps from its own edge.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          SizedBox(
            width: LiveWindow.downloadFilters,
            child: DownloadFilterRail<T>(options: options, selected: selected, onSelected: onSelected),
          ),
          Expanded(child: list),
          SizedBox(
            width: LiveWindow.downloadDetails,
            child: DownloadDetailsPane(details: details),
          ),
        ],
      ),
    );
  }
}
