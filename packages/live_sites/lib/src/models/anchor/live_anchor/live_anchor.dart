// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_anchor.g.dart';

/// The broadcaster of a room, or a search hit for one.
///
/// `anchorId` is the streamer's platform uid — distinct from a roomId on
/// platforms where the two differ (bilibili, douyin). Storage persists this
/// type.
abstract class LiveAnchor implements Built<LiveAnchor, LiveAnchorBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveAnchor([void Function(LiveAnchorBuilder)? updates]) = _$LiveAnchor;

  /// The normalized-fields constructor; construct through
  /// [LiveAnchor.normalized] unless the caller normalized upstream.
  /// The normalized-fields constructor; construct through
  /// [LiveAnchor.normalized] unless the caller normalized upstream.
  factory LiveAnchor.of({
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
    (b) => b
      ..platform = platform
      ..anchorId = anchorId
      ..name = name
      ..avatarUrl = avatarUrl
      ..profileUrl = profileUrl
      ..followerCount = followerCount
      ..introduction = introduction
      ..isVerified = isVerified
      ..anchorLevel = anchorLevel
      ..liveStatus = liveStatus,
  );

  LiveAnchor._();

  /// Deserializes a stored JSON record.
  factory LiveAnchor.fromJson(Map<String, Object?> json) => serializers.deserializeWith(LiveAnchor.serializer, json)!;

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
  }) => LiveAnchor.of(
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

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveAnchorBuilder b) => b
    ..platform = ''
    ..anchorId = ''
    ..name = '';

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveAnchor> get serializer => _$liveAnchorSerializer;

  /// The platform the anchor broadcasts on, normalized lowercase.
  String get platform;

  /// The streamer's platform uid.
  String get anchorId;

  /// The streamer's display name.
  String get name;

  /// The streamer's avatar.
  String? get avatarUrl;

  /// The streamer's profile page.
  String? get profileUrl;

  /// The streamer's follower count, when the platform exposes it.
  int? get followerCount;

  /// The streamer's self description.
  String? get introduction;

  /// Whether the platform marks the streamer verified.
  bool? get isVerified;

  /// The streamer's platform level.
  int? get anchorLevel;

  /// The streamer's live status, when the search result carries it.
  LiveStatus? get liveStatus;
}
