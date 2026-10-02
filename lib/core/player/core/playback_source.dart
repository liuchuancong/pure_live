import 'package:pure_live/core/player/core/playback_input_lease.dart';

/// A selected source, distinct from the ephemeral URI opened by a native
/// consumer. Owned recipes must retain neither a route nor a live input.
sealed class PlaybackSource {
  const PlaybackSource();

  /// Only remote sources expose a reusable media URL. Owned inputs are not
  /// exportable as URLs; their local URI exists only inside native dispatch.
  String? get url;
  String get identity;
}

final class UrlPlaybackSource extends PlaybackSource {
  const UrlPlaybackSource(this.url);

  @override
  final String url;
  @override
  String get identity => url;

  @override
  bool operator ==(Object other) => other is UrlPlaybackSource && other.url == url;
  @override
  int get hashCode => url.hashCode;
}

/// Rebuilding the same public identity still creates a distinct source cohort.
/// Object identity prevents a new factory/quality recipe from inheriting the
/// committed metadata of an older recipe that happens to use the same label.
final class OwnedPlaybackSource extends PlaybackSource {
  OwnedPlaybackSource({required this.identity, required this.createInput}) {
    if (identity.trim().isEmpty) throw ArgumentError('Owned source identity is empty');
  }

  @override
  final String identity;
  final PlaybackOwnedInputFactory createInput;
  @override
  String? get url => null;
}
