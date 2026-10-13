// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// One quality a room offers.
@immutable
final class LivePlayQuality {
  /// Creates a quality.
  const LivePlayQuality({
    required this.quality,
    this.data,
    this.id,
    this.sort = 0,
    this.isPlaybackUnconfirmed = false,
    this.codec,
  });

  /// Label shown to the user.
  final String quality;

  /// Platform data needed to request this quality.
  final Object? data;

  /// Stable platform identifier used to confirm that a requested quality was
  /// applied; kept apart from [data], whose URL lists and request maps are
  /// implementation details.
  final Object? id;

  /// Order among the room's qualities.
  final int sort;

  /// The stream is playing but the platform did not confirm this quality; the
  /// label is shown as unconfirmed rather than renamed.
  final bool isPlaybackUnconfirmed;

  /// The video codec of this quality (`avc`, `hevc`), filled only by platforms
  /// that know it before any URL is resolved. A hint, not part of the identity
  /// ([selectionId]); the codec actually played is the line's. "优先 H.264" uses
  /// it to pass over an HEVC quality when choosing where a room starts.
  final String? codec;

  /// A copy with [isPlaybackUnconfirmed] set to [unconfirmed].
  LivePlayQuality withPlaybackUnconfirmed({required bool unconfirmed}) => unconfirmed == isPlaybackUnconfirmed
      ? this
      : LivePlayQuality(
          quality: quality,
          data: data,
          id: id,
          sort: sort,
          isPlaybackUnconfirmed: unconfirmed,
          codec: codec,
        );

  /// The identity of this option: [id], or the label for adapters without one.
  /// Never derived from [data].
  Object get selectionId => id ?? quality;

  @override
  String toString() => 'LivePlayQuality($quality, $id)';
}
