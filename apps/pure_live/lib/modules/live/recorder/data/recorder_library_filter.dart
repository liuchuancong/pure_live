import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/modules/live/recorder/data/recording_library.dart' show RecordingTake;
import 'package:pure_live/shared/shared.dart' show kAllPlatforms;

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

/// How the library is narrowed: one site, whether a row must hold something
/// playable, and the order the days are read in.
final class RecorderLibraryFilter {
  /// The untouched library: every site, every file, newest first.
  const RecorderLibraryFilter({
    this.platform = kAllPlatforms,
    this.playableOnly = false,
    this.sort = RecorderLibrarySort.newest,
  });

  /// The site the chips inside the panel picked; 'all' is every site.
  final String platform;

  /// Whether a row must hold something a player opens.
  final bool playableOnly;

  /// The order the list reads in.
  final RecorderLibrarySort sort;

  /// Whether anything but the order is holding the library down — what makes
  /// the toolbar's entry read as engaged.
  bool get narrowed => platform != kAllPlatforms || playableOnly;

  /// The filter with the given parts replaced.
  RecorderLibraryFilter copyWith({String? platform, bool? playableOnly, RecorderLibrarySort? sort}) =>
      RecorderLibraryFilter(
        platform: platform ?? this.platform,
        playableOnly: playableOnly ?? this.playableOnly,
        sort: sort ?? this.sort,
      );
}

/// The library's narrowing, shared by the toolbar that edits it and the pane
/// that obeys it.
final class RecorderLibraryFilterController extends Notifier<RecorderLibraryFilter> {
  @override
  RecorderLibraryFilter build() => const RecorderLibraryFilter();

  /// Shows one site's takes.
  void setPlatform(String value) => state = state.copyWith(platform: value);

  /// Requires a row to hold something playable.
  void setPlayableOnly({required bool value}) => state = state.copyWith(playableOnly: value);

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
