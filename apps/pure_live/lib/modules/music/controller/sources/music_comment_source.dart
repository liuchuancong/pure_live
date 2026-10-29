import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_comments.dart' show MusicComment;

/// One fetched page of a song's comments.
typedef MusicCommentsPage = ({List<MusicComment> comments, bool hasMore});

/// A song's comments a platform can answer beside the source contract —
/// lx-music's `comment.js` per platform, its hot and newest tabs.
abstract interface class MusicCommentsSource {
  /// One page of [track]'s comments; [hot] picks the platform's hot tab over
  /// the newest one.
  Future<MusicCommentsPage> comments(audio.MusicTrack track, {required bool hot, required int page, int pageSize});
}

/// Builds a comment from raw rows, dropping rows with no text.
List<MusicComment> commentsOf(Iterable<Object?> rows, MusicComment? Function(Map<String, Object?>) parse) => [
  for (final row in rows)
    if (row is Map) ?parse(row.cast<String, Object?>()),
];

/// Reads a seconds-or-millis timestamp the platforms hand over in both units.
DateTime? commentTimeOf(Object? raw, {bool seconds = true}) {
  final value = int.tryParse('$raw');
  if (value == null || value <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds ? value * 1000 : value);
}

/// Reads an optional text field, empty strings included in the null.
String? commentTextOf(Object? value) {
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}
