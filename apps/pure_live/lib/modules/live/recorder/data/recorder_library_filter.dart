import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/modules/live/recorder/data/recording_library.dart' show RecordingTake;

/// The orders the library can read itself by — the file manager's sort menu.
///
/// It lives beside the filter it is folded into rather than in the page, because
/// the toolbar that offers it and the list that obeys it are two widgets now.
enum RecorderLibrarySort {
  newest,
  oldest,
  name,
  size,
  duration;

  /// The takes in this order. A take without a stamp sorts as the oldest thing
  /// on disk, a file-name order reads case-blind.
  List<RecordingTake> sorted(List<RecordingTake> takes) {
    int byName(RecordingTake a, RecordingTake b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return switch (this) {
      RecorderLibrarySort.newest => takes..sort((a, b) => b.takenAt.compareTo(a.takenAt)),
      RecorderLibrarySort.oldest => takes..sort((a, b) => a.takenAt.compareTo(b.takenAt)),
      RecorderLibrarySort.name => takes..sort(byName),
      RecorderLibrarySort.size => takes..sort((a, b) => b.bytes.compareTo(a.bytes)),
      RecorderLibrarySort.duration =>
        takes..sort((a, b) => (b.duration?.inMilliseconds ?? 0).compareTo(a.duration?.inMilliseconds ?? 0)),
    };
  }
}

/// How the library is read: the order the days are in.
final class RecorderLibraryFilter {
  /// The untouched library: newest first.
  const RecorderLibraryFilter({this.sort = RecorderLibrarySort.newest});

  /// The order the list reads in.
  final RecorderLibrarySort sort;

  /// The filter with the order replaced.
  RecorderLibraryFilter copyWith({RecorderLibrarySort? sort}) => RecorderLibraryFilter(sort: sort ?? this.sort);
}

/// The library's narrowing, shared by the toolbar that edits it and the pane
/// that obeys it.
final class RecorderLibraryFilterController extends Notifier<RecorderLibraryFilter> {
  @override
  RecorderLibraryFilter build() => const RecorderLibraryFilter();

  /// Reorders the list.
  void setSort(RecorderLibrarySort value) => state = state.copyWith(sort: value);

  /// Widens the library back to everything it holds.
  void reset() => state = const RecorderLibraryFilter();
}

/// How the recording library is narrowed right now.
final recorderLibraryFilterProvider = NotifierProvider<RecorderLibraryFilterController, RecorderLibraryFilter>(
  RecorderLibraryFilterController.new,
);

/// The library's cut for one module: the takes whose site is in [platforms]
/// (empty means every site) and not in [excluded].
///
/// [RecordingTake.platformId] falls back to the folder's name for a take whose
/// task row is gone, which is the same string for both sides — so an orphaned
/// channel take still lands on the IPTV side of the cut.
List<RecordingTake> scopeLibraryTakes(
  List<RecordingTake> takes, {
  Set<String> platforms = const {},
  Set<String> excluded = const {},
}) {
  if (platforms.isEmpty && excluded.isEmpty) return takes;
  return [
    for (final take in takes)
      if ((platforms.isEmpty || platforms.contains(take.platformId)) && !excluded.contains(take.platformId)) take,
  ];
}
