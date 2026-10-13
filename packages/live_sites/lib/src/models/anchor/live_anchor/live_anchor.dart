import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_status.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_anchor.freezed.dart';
part 'live_anchor.g.dart';

/// The broadcaster of a room, or a search hit for one.
///
/// `anchorId` is the streamer's platform uid — distinct from a roomId on
/// platforms where the two differ (bilibili, douyin). Storage persists this
/// type.
@freezed
abstract class LiveAnchor with _$LiveAnchor {
  /// The normalized-fields constructor (code generation and copyWith
  /// target); construct through [LiveAnchor.normalized] unless the caller
  /// normalized upstream.
  const factory LiveAnchor({
    @Default('') String platform,
    @Default('') String anchorId,
    @Default('') String name,
    String? avatarUrl,
    String? profileUrl,
    int? followerCount,
    String? introduction,
    bool? isVerified,
    int? anchorLevel,
    LiveStatus? liveStatus,
  }) = _LiveAnchor;

  /// Deserializes a stored JSON record.
  factory LiveAnchor.fromJson(Map<String, Object?> json) => _$LiveAnchorFromJson(json);

  /// Adapter entry point: normalizes identity fields once and delegates.
  factory LiveAnchor.normalized({
    String platform = '',
    String anchorId = '',
    String name = '',
    String? avatarUrl,
    String? profileUrl,
    int? followerCount,
    String? introduction,
    bool? isVerified,
    int? anchorLevel,
    LiveStatus? liveStatus,
  }) => LiveAnchor(
    platform: platform.trim().toLowerCase(),
    anchorId: anchorId.trim(),
    name: name.trim(),
    avatarUrl: avatarUrl?.trim(),
    profileUrl: profileUrl?.trim(),
    introduction: introduction?.trim(),
    followerCount: followerCount,
    isVerified: isVerified,
    anchorLevel: anchorLevel,
    liveStatus: liveStatus,
  );
}
