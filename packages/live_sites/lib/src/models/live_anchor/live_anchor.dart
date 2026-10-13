import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_anchor.freezed.dart';

/// An anchor (streamer) as the shared contract represents it, independent of
/// whether they are currently live.
///
/// Identity is the pair (siteId, id): the same anchor keeps their identity
/// across refreshes even as [isLive] or [followerCount] changes, so Freezed's
/// generated equality is disabled and [Equatable] expresses identity. [avatar]
/// and [uri] are parsed URIs, never widgets; unreported fields stay null.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@Freezed(equal: false)
abstract class LiveAnchor with _$LiveAnchor, Equatable {
  /// Creates an anchor for [siteId] with the platform-specific [id].
  const factory LiveAnchor({
    required String siteId,
    required String id,
    required String name,
    Uri? avatar,
    Uri? uri,
    String? description,
    bool? isLive,
    int? followerCount,
    @Default({}) Map<String, Object?> metadata,
  }) = _LiveAnchor;

  const LiveAnchor._();

  /// The stable identity key, e.g. `bilibili:12345`.
  String get identity => '$siteId:$id';

  @override
  List<Object?> get props => [siteId, id];
}
