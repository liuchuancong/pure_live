/// Minimal platform-independent metadata used by the shared archive player.
abstract interface class ArchiveVideo {
  /// Stable platform video id; never a signed media URL.
  String get id;

  /// Display title.
  String get title;

  /// Duration, or zero until the player supplies it.
  Duration get duration;
}

/// One server-offered archive rendition.
abstract interface class ArchiveQuality {
  /// Stable rendition id.
  String get id;

  /// Display name.
  String get label;

  /// Only permitted renditions with a URL can be selected.
  bool get playable;
}
