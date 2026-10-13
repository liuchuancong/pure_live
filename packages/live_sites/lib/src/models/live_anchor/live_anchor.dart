import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_anchor.freezed.dart';

/// A broadcaster (streamer), independent of whether they are currently live.
///
/// One type serves every role: a `LiveRoom` holds its streamer here (the room's
/// `nick`/`avatar`/`userId`/`followers` are this anchor's `name`/`avatar`/
/// `anchorId`/`followerCount`), an anchor search returns these, and a follow's
/// profile reads them. Identity is the pair (platform, anchorId), so the same
/// anchor keeps it across refreshes even as [isLive] or [followerCount] change;
/// Freezed's generated equality is disabled and [Equatable] expresses identity.
/// `avatar` and `link` are URL strings, never widgets; unreported fields stay
/// null or empty.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@Freezed(equal: false)
abstract class LiveAnchor with _$LiveAnchor, Equatable {
  /// Creates an anchor on [platform] with the platform-specific [anchorId].
  const factory LiveAnchor({
    required String platform,
    required String anchorId,
    @Default('') String name,
    @Default('') String avatar,
    String? link,
    String? description,
    bool? isLive,
    int? followerCount,

    /// When this record was first stored (follow/history), epoch-based UTC.
    DateTime? createdAt,

    /// When this record was last refreshed from the platform.
    DateTime? updatedAt,

    /// The untouched platform payload this anchor was parsed from, for debugging
    /// and re-parsing after a schema change; empty when not kept.
    @Default({}) Map<String, Object?> rawData,
  }) = _LiveAnchor;

  const LiveAnchor._();

  /// The stable identity key, e.g. `bilibili:12345`.
  String get identity => '$platform:$anchorId';

  /// Whether the platform gave a streamer name.
  bool get hasName => name.trim().isNotEmpty;

  /// [name], or [platformName] when it is empty. The platform's display name is
  /// localized by the UI, so the caller passes it in.
  String displayNick(String platformName) => hasName ? name.trim() : platformName;

  /// This anchor with [incoming]'s facts filled in where this one has none: an
  /// empty or null incoming value keeps the stored one, so a sparse refresh
  /// never erases a name, avatar or follower count already known.
  LiveAnchor mergedWith(LiveAnchor incoming) => LiveAnchor(
    platform: platform.isNotEmpty ? platform : incoming.platform,
    anchorId: anchorId.isNotEmpty ? anchorId : incoming.anchorId,
    name: incoming.name.trim().isEmpty ? name : incoming.name,
    avatar: incoming.avatar.trim().isEmpty ? avatar : incoming.avatar,
    link: incoming.link ?? link,
    description: incoming.description ?? description,
    isLive: incoming.isLive ?? isLive,
    followerCount: incoming.followerCount ?? followerCount,
    createdAt: createdAt ?? incoming.createdAt,
    updatedAt: incoming.updatedAt ?? updatedAt,
    rawData: incoming.rawData.isNotEmpty ? incoming.rawData : rawData,
  );

  @override
  List<Object?> get props => [platform, anchorId];
}
