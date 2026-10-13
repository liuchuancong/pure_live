/// Human-facing identity of what a session is playing.
///
/// This is the part the platform layer (site) knows and the media layer does
/// not: which room, whose stream, what the cover looks like. It travels with
/// the session so the notification, the mini-window title and any surface
/// outside the video widget can name what is playing without re-resolving
/// the room.
final class PlaybackMetadata {
  /// Creates playback metadata.
  const new({this.title, this.streamerName, this.coverUrl});

  /// The room or video title, when the site provides one.
  final String? title;

  /// The streamer's display name, when the site provides one.
  final String? streamerName;

  /// A cover image URL for notifications and placeholders.
  final String? coverUrl;

  /// Empty metadata.
  static const PlaybackMetadata none = PlaybackMetadata();

  /// What to show when only a name is wanted.
  ///
  /// Falls back to the streamer's name because a notification titled
  /// "未知" tells the viewer less than one titled with the person they
  /// followed; an empty string means the caller has nothing at all.
  String get displayName {
    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
      return trimmedTitle;
    }
    final trimmedStreamer = streamerName?.trim();
    if (trimmedStreamer != null && trimmedStreamer.isNotEmpty) {
      return trimmedStreamer;
    }
    return '';
  }

  /// Whether anything is known at all.
  bool get isEmpty => displayName.isEmpty && (coverUrl?.isEmpty ?? true);

  /// A copy with fields replaced.
  PlaybackMetadata copyWith({String? title, String? streamerName, String? coverUrl}) {
    return PlaybackMetadata(
      title: title ?? this.title,
      streamerName: streamerName ?? this.streamerName,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}
