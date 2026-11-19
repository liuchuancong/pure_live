import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/widgets/download_task_card.dart' show DownloadRowPhase;

/// One status segment of the queue: the state's word and the number of
/// tasks wearing it right now.
final class DownloadStatusTab<T> {
  /// The segment for [value], named [label], holding [count] tasks.
  const DownloadStatusTab(this.value, this.label, this.count);

  /// The state the segment filters to.
  final T value;

  /// The state's word.
  final String label;

  /// How many tasks wear the state.
  final int count;
}

/// The six cuts every queue filters by — all of it, plus the five states a
/// viewer looks for when they open the manager.
enum DownloadStatusGroup { all, running, queued, paused, done, failed }

/// The group a row's phase answers to: a task being finished with counts as
/// running, a finished file gone missing and a task called off count as
/// failed — the tab a viewer looks under when a task is not doing well.
DownloadStatusGroup downloadRowGroupOf(DownloadRowPhase phase) => switch (phase) {
  DownloadRowPhase.running || DownloadRowPhase.processing => DownloadStatusGroup.running,
  DownloadRowPhase.queued => DownloadStatusGroup.queued,
  DownloadRowPhase.paused => DownloadStatusGroup.paused,
  DownloadRowPhase.done => DownloadStatusGroup.done,
  DownloadRowPhase.failed || DownloadRowPhase.cancelled || DownloadRowPhase.missing => DownloadStatusGroup.failed,
};

/// The queue's states as the navigation itself: the reference download
/// managers' tab row with its counts, replacing the settings-flavored
/// panel the pages used to open. The bar lines up with the rows under it
/// and stops at its own width, the way the recorder's task page draws
/// its states.
final class DownloadStatusTabs<T> extends StatelessWidget {
  /// The tab row over [tabs], standing at [value].
  const DownloadStatusTabs({
    required this.tabs,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  /// One segment per state the page can filter to.
  final List<DownloadStatusTab<T>> tabs;

  /// The state the queue is filtered to right now.
  final T value;

  /// Picks a state.
  final ValueChanged<T> onChanged;

  /// The bar's own name, for screen readers.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return DsTabs<T>(
      value: value,
      semanticLabel: semanticLabel,
      style: const DsTabsStyle(padding: EdgeInsets.zero, dividerColor: Color(0x00000000)),
      onChanged: onChanged,
      tabs: [for (final tab in tabs) DsTab(value: tab.value, label: Text(tab.label), count: tab.count)],
    );
  }
}
