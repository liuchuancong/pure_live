// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_room.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveRoom {

/// The room's own ref. Some sites address a room by the anchor (acfun), some by a room id (huya, douyu);
/// this is whichever the source uses, and it is what `resolve` and `liveStatus` must be handed back.
@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef get ref;/// On air, ended, scheduled, or the source could not tell. [LiveRoomState.unknown] is not [LiveRoomState.ended]:
/// a poll that timed out and is stored as "finished" makes a follow list stop watching a live stream.
@JsonKey(fromJson: _state) LiveRoomState get state;/// The title as the room set it, not the anchor's name. Empty is allowed - some rooms have no title, and a
/// surface then shows [anchorName] - but it is never filled in by guessing.
 String get title;@JsonKey(fromJson: _text) String? get anchorName;/// The anchor's own id when the answer carries it separately from the room id (douyu's `owner_id`, huya's
/// `sponsorInfo.uid`). Null means the source did not distinguish them.
@JsonKey(fromJson: _text) String? get anchorId;@JsonKey(fromJson: _text) String? get avatar;@JsonKey(fromJson: _text) String? get cover;/// 分区 / game / category as the source words it. The platform does not rename these or map them onto a
/// shared taxonomy - a viewer searching "电竞" means the site's row, not ours.
/// 分区 / game / category as the source words it, plus its id when the site has one. The platform does not
/// rename these or map them onto a shared taxonomy - a viewer searching "电竞" means the site's row, not ours.
@JsonKey(fromJson: _text) String? get area;@JsonKey(fromJson: _text) String? get areaId;/// The room's web page, as the site builds it (acfun keys it on the anchor, weibo on the live id). A
/// "在浏览器打开" item and a recorder's provenance note both read this instead of guessing a url pattern.
@JsonKey(fromJson: _text) String? get link;/// The pinned notice (公告). Distinct from [introduction]: sites carry both, and users read them as two
/// different things on one page.
@JsonKey(fromJson: _text) String? get notice;/// The audience, with each figure keeping its own meaning. Null means the site stated nothing at all - which
/// is not "0 人看过", and [viewers] keeps that distinction readable by callers.
@JsonKey(fromJson: _audience, toJson: _audienceOut) LiveAudience? get audience;/// Room introduction / announcement text, when the site keeps one apart from the title.
@JsonKey(fromJson: _text) String? get introduction;/// The audience figure exactly as the platform reported it, when it gave a bare number and named its kind.
/// Prefer [audience], which can hold all three figures at once; this is the shorthand the sites that report
/// exactly one number fill in, and it is read back through the getter below rather than stored twice.
@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? get viewers;/// What [viewers] measures. Defaults to [LiveAudienceMetric.unknown] so a heat score cannot be printed as a
/// headcount by omission.
@JsonKey(fromJson: _metric) LiveAudienceMetric get viewersMetric;/// Followers / fan count when the room answer carries it (acfun's `user.fanCountValue` is a *label*, so that
/// one goes in [extra] instead of being parsed into a number nobody asked for).
@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? get followers;/// When the broadcast began, from a field the source stated. A room page's "已直播 2 小时" comes from here and
/// from nowhere else.
@JsonKey(fromJson: _at, toJson: formatUtc) DateTime? get startedAt;/// Why an on-air room cannot be opened. [LiveRestriction.none] is the affirmative "the anonymous path may
/// play this"; null means the site never said either way, which is *not* the same as none.
@JsonKey(fromJson: _restriction, toJson: _restrictionName) LiveRestriction? get restriction;/// The site's raw status value behind [state] (`liveType`, `watch_limit`, `show_status`, `status`). Kept so a
/// code that stops mapping is visible in a stored row instead of having been silently folded into unknown.
@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? get reportedStateCode;/// Whether the finished part of this broadcast is replayable, and how far back.
@JsonKey(fromJson: _catchUp, toJson: _catchUpOut) LiveCatchUp? get catchUp;/// The programme join, when the site publishes one (and for channel-shaped sources, when our EPG has a row to
/// match it against).
@JsonKey(fromJson: _text) String? get epgId;@JsonKey(fromJson: _text) String? get currentProgramme;@JsonKey(fromJson: _text) String? get currentProgrammeDescription;/// The broadcast is scheduled for later as well as not-yet-on-air. Only meaningful with
/// [LiveRoomState.notStarted], and it is what a reminder can be offered on.
 bool get isScheduled;/// The liveId / stream name this answer describes, when the source has one distinct from the room id. It is
/// per-broadcast: storing it as the ref would orphan the room the moment the anchor goes off air.
@JsonKey(fromJson: _text) String? get streamId;@JsonKey(fromJson: _stringList, toJson: _stringListOut) List<String> get tags;/// The headers the media address needs, per room (a referer pinned to the room page, a session cookie, a
/// device id). The player reads these and nothing else, so this is the only place a source can say "the url
/// alone is not enough".
@JsonKey(fromJson: _stringMap, toJson: _stringMapOut) Map<String, String> get headers;/// The site's own continuation payload for playback (a signed descriptor, a visitor session, a ticket list).
/// Opaque on purpose: the source produced it and only the source can read it. Passing it back is what keeps
/// one room open at one request instead of four - the reference product plays the same trick with `data`.
@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> get sitePayload;/// The same idea for the danmaku socket: the handshake material the play path already obtained (the
/// reference product's `danmakuData`).
@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> get danmakuPayload;/// Whatever this site states that this shape cannot name. The bar for a key here is "the platform said it and
/// we have no field for it" - not "this was convenient".
@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> get extra;
/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveRoomCopyWith<LiveRoom> get copyWith => _$LiveRoomCopyWithImpl<LiveRoom>(this as LiveRoom, _$identity);

  /// Serializes this LiveRoom to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveRoom;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoom&&(identical(other.ref, _this.ref) || other.ref == _this.ref)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.anchorName, _this.anchorName) || other.anchorName == _this.anchorName)&&(identical(other.anchorId, _this.anchorId) || other.anchorId == _this.anchorId)&&(identical(other.avatar, _this.avatar) || other.avatar == _this.avatar)&&(identical(other.cover, _this.cover) || other.cover == _this.cover)&&(identical(other.area, _this.area) || other.area == _this.area)&&(identical(other.areaId, _this.areaId) || other.areaId == _this.areaId)&&(identical(other.link, _this.link) || other.link == _this.link)&&(identical(other.notice, _this.notice) || other.notice == _this.notice)&&(identical(other.audience, _this.audience) || other.audience == _this.audience)&&(identical(other.introduction, _this.introduction) || other.introduction == _this.introduction)&&(identical(other.viewers, _this.viewers) || other.viewers == _this.viewers)&&(identical(other.viewersMetric, _this.viewersMetric) || other.viewersMetric == _this.viewersMetric)&&(identical(other.followers, _this.followers) || other.followers == _this.followers)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.restriction, _this.restriction) || other.restriction == _this.restriction)&&(identical(other.reportedStateCode, _this.reportedStateCode) || other.reportedStateCode == _this.reportedStateCode)&&(identical(other.catchUp, _this.catchUp) || other.catchUp == _this.catchUp)&&(identical(other.epgId, _this.epgId) || other.epgId == _this.epgId)&&(identical(other.currentProgramme, _this.currentProgramme) || other.currentProgramme == _this.currentProgramme)&&(identical(other.currentProgrammeDescription, _this.currentProgrammeDescription) || other.currentProgrammeDescription == _this.currentProgrammeDescription)&&(identical(other.isScheduled, _this.isScheduled) || other.isScheduled == _this.isScheduled)&&(identical(other.streamId, _this.streamId) || other.streamId == _this.streamId)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&const DeepCollectionEquality().equals(other.headers, _this.headers)&&const DeepCollectionEquality().equals(other.sitePayload, _this.sitePayload)&&const DeepCollectionEquality().equals(other.danmakuPayload, _this.danmakuPayload)&&const DeepCollectionEquality().equals(other.extra, _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoom;
  return Object.hashAll([runtimeType,_this.ref,_this.state,_this.title,_this.anchorName,_this.anchorId,_this.avatar,_this.cover,_this.area,_this.areaId,_this.link,_this.notice,_this.audience,_this.introduction,_this.viewers,_this.viewersMetric,_this.followers,_this.startedAt,_this.restriction,_this.reportedStateCode,_this.catchUp,_this.epgId,_this.currentProgramme,_this.currentProgrammeDescription,_this.isScheduled,_this.streamId,const DeepCollectionEquality().hash(_this.tags),const DeepCollectionEquality().hash(_this.headers),const DeepCollectionEquality().hash(_this.sitePayload),const DeepCollectionEquality().hash(_this.danmakuPayload),const DeepCollectionEquality().hash(_this.extra)]);
}

@override
String toString() {
  final _this = this as LiveRoom;
  return 'LiveRoom(ref: ${_this.ref}, state: ${_this.state}, title: ${_this.title}, anchorName: ${_this.anchorName}, anchorId: ${_this.anchorId}, avatar: ${_this.avatar}, cover: ${_this.cover}, area: ${_this.area}, areaId: ${_this.areaId}, link: ${_this.link}, notice: ${_this.notice}, audience: ${_this.audience}, introduction: ${_this.introduction}, viewers: ${_this.viewers}, viewersMetric: ${_this.viewersMetric}, followers: ${_this.followers}, startedAt: ${_this.startedAt}, restriction: ${_this.restriction}, reportedStateCode: ${_this.reportedStateCode}, catchUp: ${_this.catchUp}, epgId: ${_this.epgId}, currentProgramme: ${_this.currentProgramme}, currentProgrammeDescription: ${_this.currentProgrammeDescription}, isScheduled: ${_this.isScheduled}, streamId: ${_this.streamId}, tags: ${_this.tags}, headers: ${_this.headers}, sitePayload: ${_this.sitePayload}, danmakuPayload: ${_this.danmakuPayload}, extra: ${_this.extra})';
}


}

/// @nodoc
abstract mixin class $LiveRoomCopyWith<$Res>  {
  factory $LiveRoomCopyWith(LiveRoom value, $Res Function(LiveRoom) _then) = _$LiveRoomCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef ref,@JsonKey(fromJson: _state) LiveRoomState state, String title,@JsonKey(fromJson: _text) String? anchorName,@JsonKey(fromJson: _text) String? anchorId,@JsonKey(fromJson: _text) String? avatar,@JsonKey(fromJson: _text) String? cover,@JsonKey(fromJson: _text) String? area,@JsonKey(fromJson: _text) String? areaId,@JsonKey(fromJson: _text) String? link,@JsonKey(fromJson: _text) String? notice,@JsonKey(fromJson: _audience, toJson: _audienceOut) LiveAudience? audience,@JsonKey(fromJson: _text) String? introduction,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? viewers,@JsonKey(fromJson: _metric) LiveAudienceMetric viewersMetric,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? followers,@JsonKey(fromJson: _at, toJson: formatUtc) DateTime? startedAt,@JsonKey(fromJson: _restriction, toJson: _restrictionName) LiveRestriction? restriction,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? reportedStateCode,@JsonKey(fromJson: _catchUp, toJson: _catchUpOut) LiveCatchUp? catchUp,@JsonKey(fromJson: _text) String? epgId,@JsonKey(fromJson: _text) String? currentProgramme,@JsonKey(fromJson: _text) String? currentProgrammeDescription, bool isScheduled,@JsonKey(fromJson: _text) String? streamId,@JsonKey(fromJson: _stringList, toJson: _stringListOut) List<String> tags,@JsonKey(fromJson: _stringMap, toJson: _stringMapOut) Map<String, String> headers,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> sitePayload,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> danmakuPayload,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> extra
});


$LiveAudienceCopyWith<$Res>? get audience;$LiveCatchUpCopyWith<$Res>? get catchUp;

}
/// @nodoc
class _$LiveRoomCopyWithImpl<$Res>
    implements $LiveRoomCopyWith<$Res> {
  _$LiveRoomCopyWithImpl(this._self, this._then);

  final LiveRoom _self;
  final $Res Function(LiveRoom) _then;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ref = null,Object? state = null,Object? title = null,Object? anchorName = freezed,Object? anchorId = freezed,Object? avatar = freezed,Object? cover = freezed,Object? area = freezed,Object? areaId = freezed,Object? link = freezed,Object? notice = freezed,Object? audience = freezed,Object? introduction = freezed,Object? viewers = freezed,Object? viewersMetric = null,Object? followers = freezed,Object? startedAt = freezed,Object? restriction = freezed,Object? reportedStateCode = freezed,Object? catchUp = freezed,Object? epgId = freezed,Object? currentProgramme = freezed,Object? currentProgrammeDescription = freezed,Object? isScheduled = null,Object? streamId = freezed,Object? tags = null,Object? headers = null,Object? sitePayload = null,Object? danmakuPayload = null,Object? extra = null,}) {
  return _then(LiveRoom(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as ContentRef,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as LiveRoomState,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,anchorName: freezed == anchorName ? _self.anchorName : anchorName // ignore: cast_nullable_to_non_nullable
as String?,anchorId: freezed == anchorId ? _self.anchorId : anchorId // ignore: cast_nullable_to_non_nullable
as String?,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,area: freezed == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as String?,areaId: freezed == areaId ? _self.areaId : areaId // ignore: cast_nullable_to_non_nullable
as String?,link: freezed == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String?,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as String?,audience: freezed == audience ? _self.audience : audience // ignore: cast_nullable_to_non_nullable
as LiveAudience?,introduction: freezed == introduction ? _self.introduction : introduction // ignore: cast_nullable_to_non_nullable
as String?,viewers: freezed == viewers ? _self.viewers : viewers // ignore: cast_nullable_to_non_nullable
as int?,viewersMetric: null == viewersMetric ? _self.viewersMetric : viewersMetric // ignore: cast_nullable_to_non_nullable
as LiveAudienceMetric,followers: freezed == followers ? _self.followers : followers // ignore: cast_nullable_to_non_nullable
as int?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,restriction: freezed == restriction ? _self.restriction : restriction // ignore: cast_nullable_to_non_nullable
as LiveRestriction?,reportedStateCode: freezed == reportedStateCode ? _self.reportedStateCode : reportedStateCode // ignore: cast_nullable_to_non_nullable
as int?,catchUp: freezed == catchUp ? _self.catchUp : catchUp // ignore: cast_nullable_to_non_nullable
as LiveCatchUp?,epgId: freezed == epgId ? _self.epgId : epgId // ignore: cast_nullable_to_non_nullable
as String?,currentProgramme: freezed == currentProgramme ? _self.currentProgramme : currentProgramme // ignore: cast_nullable_to_non_nullable
as String?,currentProgrammeDescription: freezed == currentProgrammeDescription ? _self.currentProgrammeDescription : currentProgrammeDescription // ignore: cast_nullable_to_non_nullable
as String?,isScheduled: null == isScheduled ? _self.isScheduled : isScheduled // ignore: cast_nullable_to_non_nullable
as bool,streamId: freezed == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,sitePayload: null == sitePayload ? _self.sitePayload : sitePayload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,danmakuPayload: null == danmakuPayload ? _self.danmakuPayload : danmakuPayload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}
/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveAudienceCopyWith<$Res>? get audience {
    if (_self.audience == null) {
    return null;
  }

  return $LiveAudienceCopyWith<$Res>(_self.audience!, (value) {
    return _then(_self.copyWith(audience: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveCatchUpCopyWith<$Res>? get catchUp {
    if (_self.catchUp == null) {
    return null;
  }

  return $LiveCatchUpCopyWith<$Res>(_self.catchUp!, (value) {
    return _then(_self.copyWith(catchUp: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveRoom].
extension LiveRoomPatterns on LiveRoom {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveRoom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveRoom value)  $default,){
final _that = this;
switch (_that) {
case _LiveRoom():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveRoom value)?  $default,){
final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef ref, @JsonKey(fromJson: _state)  LiveRoomState state,  String title, @JsonKey(fromJson: _text)  String? anchorName, @JsonKey(fromJson: _text)  String? anchorId, @JsonKey(fromJson: _text)  String? avatar, @JsonKey(fromJson: _text)  String? cover, @JsonKey(fromJson: _text)  String? area, @JsonKey(fromJson: _text)  String? areaId, @JsonKey(fromJson: _text)  String? link, @JsonKey(fromJson: _text)  String? notice, @JsonKey(fromJson: _audience, toJson: _audienceOut)  LiveAudience? audience, @JsonKey(fromJson: _text)  String? introduction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? viewers, @JsonKey(fromJson: _metric)  LiveAudienceMetric viewersMetric, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? followers, @JsonKey(fromJson: _at, toJson: formatUtc)  DateTime? startedAt, @JsonKey(fromJson: _restriction, toJson: _restrictionName)  LiveRestriction? restriction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? reportedStateCode, @JsonKey(fromJson: _catchUp, toJson: _catchUpOut)  LiveCatchUp? catchUp, @JsonKey(fromJson: _text)  String? epgId, @JsonKey(fromJson: _text)  String? currentProgramme, @JsonKey(fromJson: _text)  String? currentProgrammeDescription,  bool isScheduled, @JsonKey(fromJson: _text)  String? streamId, @JsonKey(fromJson: _stringList, toJson: _stringListOut)  List<String> tags, @JsonKey(fromJson: _stringMap, toJson: _stringMapOut)  Map<String, String> headers, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> sitePayload, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> danmakuPayload, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.ref,_that.state,_that.title,_that.anchorName,_that.anchorId,_that.avatar,_that.cover,_that.area,_that.areaId,_that.link,_that.notice,_that.audience,_that.introduction,_that.viewers,_that.viewersMetric,_that.followers,_that.startedAt,_that.restriction,_that.reportedStateCode,_that.catchUp,_that.epgId,_that.currentProgramme,_that.currentProgrammeDescription,_that.isScheduled,_that.streamId,_that.tags,_that.headers,_that.sitePayload,_that.danmakuPayload,_that.extra);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef ref, @JsonKey(fromJson: _state)  LiveRoomState state,  String title, @JsonKey(fromJson: _text)  String? anchorName, @JsonKey(fromJson: _text)  String? anchorId, @JsonKey(fromJson: _text)  String? avatar, @JsonKey(fromJson: _text)  String? cover, @JsonKey(fromJson: _text)  String? area, @JsonKey(fromJson: _text)  String? areaId, @JsonKey(fromJson: _text)  String? link, @JsonKey(fromJson: _text)  String? notice, @JsonKey(fromJson: _audience, toJson: _audienceOut)  LiveAudience? audience, @JsonKey(fromJson: _text)  String? introduction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? viewers, @JsonKey(fromJson: _metric)  LiveAudienceMetric viewersMetric, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? followers, @JsonKey(fromJson: _at, toJson: formatUtc)  DateTime? startedAt, @JsonKey(fromJson: _restriction, toJson: _restrictionName)  LiveRestriction? restriction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? reportedStateCode, @JsonKey(fromJson: _catchUp, toJson: _catchUpOut)  LiveCatchUp? catchUp, @JsonKey(fromJson: _text)  String? epgId, @JsonKey(fromJson: _text)  String? currentProgramme, @JsonKey(fromJson: _text)  String? currentProgrammeDescription,  bool isScheduled, @JsonKey(fromJson: _text)  String? streamId, @JsonKey(fromJson: _stringList, toJson: _stringListOut)  List<String> tags, @JsonKey(fromJson: _stringMap, toJson: _stringMapOut)  Map<String, String> headers, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> sitePayload, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> danmakuPayload, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)  $default,) {final _that = this;
switch (_that) {
case _LiveRoom():
return $default(_that.ref,_that.state,_that.title,_that.anchorName,_that.anchorId,_that.avatar,_that.cover,_that.area,_that.areaId,_that.link,_that.notice,_that.audience,_that.introduction,_that.viewers,_that.viewersMetric,_that.followers,_that.startedAt,_that.restriction,_that.reportedStateCode,_that.catchUp,_that.epgId,_that.currentProgramme,_that.currentProgrammeDescription,_that.isScheduled,_that.streamId,_that.tags,_that.headers,_that.sitePayload,_that.danmakuPayload,_that.extra);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef ref, @JsonKey(fromJson: _state)  LiveRoomState state,  String title, @JsonKey(fromJson: _text)  String? anchorName, @JsonKey(fromJson: _text)  String? anchorId, @JsonKey(fromJson: _text)  String? avatar, @JsonKey(fromJson: _text)  String? cover, @JsonKey(fromJson: _text)  String? area, @JsonKey(fromJson: _text)  String? areaId, @JsonKey(fromJson: _text)  String? link, @JsonKey(fromJson: _text)  String? notice, @JsonKey(fromJson: _audience, toJson: _audienceOut)  LiveAudience? audience, @JsonKey(fromJson: _text)  String? introduction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? viewers, @JsonKey(fromJson: _metric)  LiveAudienceMetric viewersMetric, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? followers, @JsonKey(fromJson: _at, toJson: formatUtc)  DateTime? startedAt, @JsonKey(fromJson: _restriction, toJson: _restrictionName)  LiveRestriction? restriction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? reportedStateCode, @JsonKey(fromJson: _catchUp, toJson: _catchUpOut)  LiveCatchUp? catchUp, @JsonKey(fromJson: _text)  String? epgId, @JsonKey(fromJson: _text)  String? currentProgramme, @JsonKey(fromJson: _text)  String? currentProgrammeDescription,  bool isScheduled, @JsonKey(fromJson: _text)  String? streamId, @JsonKey(fromJson: _stringList, toJson: _stringListOut)  List<String> tags, @JsonKey(fromJson: _stringMap, toJson: _stringMapOut)  Map<String, String> headers, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> sitePayload, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> danmakuPayload, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.ref,_that.state,_that.title,_that.anchorName,_that.anchorId,_that.avatar,_that.cover,_that.area,_that.areaId,_that.link,_that.notice,_that.audience,_that.introduction,_that.viewers,_that.viewersMetric,_that.followers,_that.startedAt,_that.restriction,_that.reportedStateCode,_that.catchUp,_that.epgId,_that.currentProgramme,_that.currentProgrammeDescription,_that.isScheduled,_that.streamId,_that.tags,_that.headers,_that.sitePayload,_that.danmakuPayload,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoom extends LiveRoom {
  const _LiveRoom({@JsonKey(fromJson: refFromJson, toJson: refToJson) required this.ref, @JsonKey(fromJson: _state) required this.state, required this.title, @JsonKey(fromJson: _text) this.anchorName, @JsonKey(fromJson: _text) this.anchorId, @JsonKey(fromJson: _text) this.avatar, @JsonKey(fromJson: _text) this.cover, @JsonKey(fromJson: _text) this.area, @JsonKey(fromJson: _text) this.areaId, @JsonKey(fromJson: _text) this.link, @JsonKey(fromJson: _text) this.notice, @JsonKey(fromJson: _audience, toJson: _audienceOut) this.audience, @JsonKey(fromJson: _text) this.introduction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) this.viewers, @JsonKey(fromJson: _metric) this.viewersMetric = LiveAudienceMetric.unknown, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) this.followers, @JsonKey(fromJson: _at, toJson: formatUtc) this.startedAt, @JsonKey(fromJson: _restriction, toJson: _restrictionName) this.restriction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) this.reportedStateCode, @JsonKey(fromJson: _catchUp, toJson: _catchUpOut) this.catchUp, @JsonKey(fromJson: _text) this.epgId, @JsonKey(fromJson: _text) this.currentProgramme, @JsonKey(fromJson: _text) this.currentProgrammeDescription, this.isScheduled = false, @JsonKey(fromJson: _text) this.streamId, @JsonKey(fromJson: _stringList, toJson: _stringListOut)  List<String> tags = const <String>[], @JsonKey(fromJson: _stringMap, toJson: _stringMapOut)  Map<String, String> headers = const <String, String>{}, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> sitePayload = const <String, Object?>{}, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> danmakuPayload = const <String, Object?>{}, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra = const <String, Object?>{}}): _tags = tags,_headers = headers,_sitePayload = sitePayload,_danmakuPayload = danmakuPayload,_extra = extra,super._();
  factory _LiveRoom.fromJson(Map<String, dynamic> json) => _$LiveRoomFromJson(json);

/// The room's own ref. Some sites address a room by the anchor (acfun), some by a room id (huya, douyu);
/// this is whichever the source uses, and it is what `resolve` and `liveStatus` must be handed back.
@override@JsonKey(fromJson: refFromJson, toJson: refToJson) final  ContentRef ref;
/// On air, ended, scheduled, or the source could not tell. [LiveRoomState.unknown] is not [LiveRoomState.ended]:
/// a poll that timed out and is stored as "finished" makes a follow list stop watching a live stream.
@override@JsonKey(fromJson: _state) final  LiveRoomState state;
/// The title as the room set it, not the anchor's name. Empty is allowed - some rooms have no title, and a
/// surface then shows [anchorName] - but it is never filled in by guessing.
@override final  String title;
@override@JsonKey(fromJson: _text) final  String? anchorName;
/// The anchor's own id when the answer carries it separately from the room id (douyu's `owner_id`, huya's
/// `sponsorInfo.uid`). Null means the source did not distinguish them.
@override@JsonKey(fromJson: _text) final  String? anchorId;
@override@JsonKey(fromJson: _text) final  String? avatar;
@override@JsonKey(fromJson: _text) final  String? cover;
/// 分区 / game / category as the source words it. The platform does not rename these or map them onto a
/// shared taxonomy - a viewer searching "电竞" means the site's row, not ours.
/// 分区 / game / category as the source words it, plus its id when the site has one. The platform does not
/// rename these or map them onto a shared taxonomy - a viewer searching "电竞" means the site's row, not ours.
@override@JsonKey(fromJson: _text) final  String? area;
@override@JsonKey(fromJson: _text) final  String? areaId;
/// The room's web page, as the site builds it (acfun keys it on the anchor, weibo on the live id). A
/// "在浏览器打开" item and a recorder's provenance note both read this instead of guessing a url pattern.
@override@JsonKey(fromJson: _text) final  String? link;
/// The pinned notice (公告). Distinct from [introduction]: sites carry both, and users read them as two
/// different things on one page.
@override@JsonKey(fromJson: _text) final  String? notice;
/// The audience, with each figure keeping its own meaning. Null means the site stated nothing at all - which
/// is not "0 人看过", and [viewers] keeps that distinction readable by callers.
@override@JsonKey(fromJson: _audience, toJson: _audienceOut) final  LiveAudience? audience;
/// Room introduction / announcement text, when the site keeps one apart from the title.
@override@JsonKey(fromJson: _text) final  String? introduction;
/// The audience figure exactly as the platform reported it, when it gave a bare number and named its kind.
/// Prefer [audience], which can hold all three figures at once; this is the shorthand the sites that report
/// exactly one number fill in, and it is read back through the getter below rather than stored twice.
@override@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) final  int? viewers;
/// What [viewers] measures. Defaults to [LiveAudienceMetric.unknown] so a heat score cannot be printed as a
/// headcount by omission.
@override@JsonKey(fromJson: _metric) final  LiveAudienceMetric viewersMetric;
/// Followers / fan count when the room answer carries it (acfun's `user.fanCountValue` is a *label*, so that
/// one goes in [extra] instead of being parsed into a number nobody asked for).
@override@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) final  int? followers;
/// When the broadcast began, from a field the source stated. A room page's "已直播 2 小时" comes from here and
/// from nowhere else.
@override@JsonKey(fromJson: _at, toJson: formatUtc) final  DateTime? startedAt;
/// Why an on-air room cannot be opened. [LiveRestriction.none] is the affirmative "the anonymous path may
/// play this"; null means the site never said either way, which is *not* the same as none.
@override@JsonKey(fromJson: _restriction, toJson: _restrictionName) final  LiveRestriction? restriction;
/// The site's raw status value behind [state] (`liveType`, `watch_limit`, `show_status`, `status`). Kept so a
/// code that stops mapping is visible in a stored row instead of having been silently folded into unknown.
@override@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) final  int? reportedStateCode;
/// Whether the finished part of this broadcast is replayable, and how far back.
@override@JsonKey(fromJson: _catchUp, toJson: _catchUpOut) final  LiveCatchUp? catchUp;
/// The programme join, when the site publishes one (and for channel-shaped sources, when our EPG has a row to
/// match it against).
@override@JsonKey(fromJson: _text) final  String? epgId;
@override@JsonKey(fromJson: _text) final  String? currentProgramme;
@override@JsonKey(fromJson: _text) final  String? currentProgrammeDescription;
/// The broadcast is scheduled for later as well as not-yet-on-air. Only meaningful with
/// [LiveRoomState.notStarted], and it is what a reminder can be offered on.
@override@JsonKey() final  bool isScheduled;
/// The liveId / stream name this answer describes, when the source has one distinct from the room id. It is
/// per-broadcast: storing it as the ref would orphan the room the moment the anchor goes off air.
@override@JsonKey(fromJson: _text) final  String? streamId;
 final  List<String> _tags;
@override@JsonKey(fromJson: _stringList, toJson: _stringListOut) List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// The headers the media address needs, per room (a referer pinned to the room page, a session cookie, a
/// device id). The player reads these and nothing else, so this is the only place a source can say "the url
/// alone is not enough".
 final  Map<String, String> _headers;
/// The headers the media address needs, per room (a referer pinned to the room page, a session cookie, a
/// device id). The player reads these and nothing else, so this is the only place a source can say "the url
/// alone is not enough".
@override@JsonKey(fromJson: _stringMap, toJson: _stringMapOut) Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}

/// The site's own continuation payload for playback (a signed descriptor, a visitor session, a ticket list).
/// Opaque on purpose: the source produced it and only the source can read it. Passing it back is what keeps
/// one room open at one request instead of four - the reference product plays the same trick with `data`.
 final  Map<String, Object?> _sitePayload;
/// The site's own continuation payload for playback (a signed descriptor, a visitor session, a ticket list).
/// Opaque on purpose: the source produced it and only the source can read it. Passing it back is what keeps
/// one room open at one request instead of four - the reference product plays the same trick with `data`.
@override@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> get sitePayload {
  if (_sitePayload is EqualUnmodifiableMapView) return _sitePayload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_sitePayload);
}

/// The same idea for the danmaku socket: the handshake material the play path already obtained (the
/// reference product's `danmakuData`).
 final  Map<String, Object?> _danmakuPayload;
/// The same idea for the danmaku socket: the handshake material the play path already obtained (the
/// reference product's `danmakuData`).
@override@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> get danmakuPayload {
  if (_danmakuPayload is EqualUnmodifiableMapView) return _danmakuPayload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_danmakuPayload);
}

/// Whatever this site states that this shape cannot name. The bar for a key here is "the platform said it and
/// we have no field for it" - not "this was convenient".
 final  Map<String, Object?> _extra;
/// Whatever this site states that this shape cannot name. The bar for a key here is "the platform said it and
/// we have no field for it" - not "this was convenient".
@override@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveRoomCopyWith<_LiveRoom> get copyWith => __$LiveRoomCopyWithImpl<_LiveRoom>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveRoomToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoom&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.state, state) || other.state == state)&&(identical(other.title, title) || other.title == title)&&(identical(other.anchorName, anchorName) || other.anchorName == anchorName)&&(identical(other.anchorId, anchorId) || other.anchorId == anchorId)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.area, area) || other.area == area)&&(identical(other.areaId, areaId) || other.areaId == areaId)&&(identical(other.link, link) || other.link == link)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.audience, audience) || other.audience == audience)&&(identical(other.introduction, introduction) || other.introduction == introduction)&&(identical(other.viewers, viewers) || other.viewers == viewers)&&(identical(other.viewersMetric, viewersMetric) || other.viewersMetric == viewersMetric)&&(identical(other.followers, followers) || other.followers == followers)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.restriction, restriction) || other.restriction == restriction)&&(identical(other.reportedStateCode, reportedStateCode) || other.reportedStateCode == reportedStateCode)&&(identical(other.catchUp, catchUp) || other.catchUp == catchUp)&&(identical(other.epgId, epgId) || other.epgId == epgId)&&(identical(other.currentProgramme, currentProgramme) || other.currentProgramme == currentProgramme)&&(identical(other.currentProgrammeDescription, currentProgrammeDescription) || other.currentProgrammeDescription == currentProgrammeDescription)&&(identical(other.isScheduled, isScheduled) || other.isScheduled == isScheduled)&&(identical(other.streamId, streamId) || other.streamId == streamId)&&const DeepCollectionEquality().equals(other.tags, _tags)&&const DeepCollectionEquality().equals(other.headers, _headers)&&const DeepCollectionEquality().equals(other.sitePayload, _sitePayload)&&const DeepCollectionEquality().equals(other.danmakuPayload, _danmakuPayload)&&const DeepCollectionEquality().equals(other.extra, _extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,ref,state,title,anchorName,anchorId,avatar,cover,area,areaId,link,notice,audience,introduction,viewers,viewersMetric,followers,startedAt,restriction,reportedStateCode,catchUp,epgId,currentProgramme,currentProgrammeDescription,isScheduled,streamId,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_headers),const DeepCollectionEquality().hash(_sitePayload),const DeepCollectionEquality().hash(_danmakuPayload),const DeepCollectionEquality().hash(_extra)]);
}

@override
String toString() {
    return 'LiveRoom(ref: $ref, state: $state, title: $title, anchorName: $anchorName, anchorId: $anchorId, avatar: $avatar, cover: $cover, area: $area, areaId: $areaId, link: $link, notice: $notice, audience: $audience, introduction: $introduction, viewers: $viewers, viewersMetric: $viewersMetric, followers: $followers, startedAt: $startedAt, restriction: $restriction, reportedStateCode: $reportedStateCode, catchUp: $catchUp, epgId: $epgId, currentProgramme: $currentProgramme, currentProgrammeDescription: $currentProgrammeDescription, isScheduled: $isScheduled, streamId: $streamId, tags: $tags, headers: $headers, sitePayload: $sitePayload, danmakuPayload: $danmakuPayload, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomCopyWith<$Res> implements $LiveRoomCopyWith<$Res> {
  factory _$LiveRoomCopyWith(_LiveRoom value, $Res Function(_LiveRoom) _then) = __$LiveRoomCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef ref,@JsonKey(fromJson: _state) LiveRoomState state, String title,@JsonKey(fromJson: _text) String? anchorName,@JsonKey(fromJson: _text) String? anchorId,@JsonKey(fromJson: _text) String? avatar,@JsonKey(fromJson: _text) String? cover,@JsonKey(fromJson: _text) String? area,@JsonKey(fromJson: _text) String? areaId,@JsonKey(fromJson: _text) String? link,@JsonKey(fromJson: _text) String? notice,@JsonKey(fromJson: _audience, toJson: _audienceOut) LiveAudience? audience,@JsonKey(fromJson: _text) String? introduction,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? viewers,@JsonKey(fromJson: _metric) LiveAudienceMetric viewersMetric,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? followers,@JsonKey(fromJson: _at, toJson: formatUtc) DateTime? startedAt,@JsonKey(fromJson: _restriction, toJson: _restrictionName) LiveRestriction? restriction,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? reportedStateCode,@JsonKey(fromJson: _catchUp, toJson: _catchUpOut) LiveCatchUp? catchUp,@JsonKey(fromJson: _text) String? epgId,@JsonKey(fromJson: _text) String? currentProgramme,@JsonKey(fromJson: _text) String? currentProgrammeDescription, bool isScheduled,@JsonKey(fromJson: _text) String? streamId,@JsonKey(fromJson: _stringList, toJson: _stringListOut) List<String> tags,@JsonKey(fromJson: _stringMap, toJson: _stringMapOut) Map<String, String> headers,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> sitePayload,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> danmakuPayload,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> extra
});


@override $LiveAudienceCopyWith<$Res>? get audience;@override $LiveCatchUpCopyWith<$Res>? get catchUp;

}
/// @nodoc
class __$LiveRoomCopyWithImpl<$Res>
    implements _$LiveRoomCopyWith<$Res> {
  __$LiveRoomCopyWithImpl(this._self, this._then);

  final _LiveRoom _self;
  final $Res Function(_LiveRoom) _then;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ref = null,Object? state = null,Object? title = null,Object? anchorName = freezed,Object? anchorId = freezed,Object? avatar = freezed,Object? cover = freezed,Object? area = freezed,Object? areaId = freezed,Object? link = freezed,Object? notice = freezed,Object? audience = freezed,Object? introduction = freezed,Object? viewers = freezed,Object? viewersMetric = null,Object? followers = freezed,Object? startedAt = freezed,Object? restriction = freezed,Object? reportedStateCode = freezed,Object? catchUp = freezed,Object? epgId = freezed,Object? currentProgramme = freezed,Object? currentProgrammeDescription = freezed,Object? isScheduled = null,Object? streamId = freezed,Object? tags = null,Object? headers = null,Object? sitePayload = null,Object? danmakuPayload = null,Object? extra = null,}) {
  return _then(_LiveRoom(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as ContentRef,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as LiveRoomState,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,anchorName: freezed == anchorName ? _self.anchorName : anchorName // ignore: cast_nullable_to_non_nullable
as String?,anchorId: freezed == anchorId ? _self.anchorId : anchorId // ignore: cast_nullable_to_non_nullable
as String?,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,area: freezed == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as String?,areaId: freezed == areaId ? _self.areaId : areaId // ignore: cast_nullable_to_non_nullable
as String?,link: freezed == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String?,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as String?,audience: freezed == audience ? _self.audience : audience // ignore: cast_nullable_to_non_nullable
as LiveAudience?,introduction: freezed == introduction ? _self.introduction : introduction // ignore: cast_nullable_to_non_nullable
as String?,viewers: freezed == viewers ? _self.viewers : viewers // ignore: cast_nullable_to_non_nullable
as int?,viewersMetric: null == viewersMetric ? _self.viewersMetric : viewersMetric // ignore: cast_nullable_to_non_nullable
as LiveAudienceMetric,followers: freezed == followers ? _self.followers : followers // ignore: cast_nullable_to_non_nullable
as int?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,restriction: freezed == restriction ? _self.restriction : restriction // ignore: cast_nullable_to_non_nullable
as LiveRestriction?,reportedStateCode: freezed == reportedStateCode ? _self.reportedStateCode : reportedStateCode // ignore: cast_nullable_to_non_nullable
as int?,catchUp: freezed == catchUp ? _self.catchUp : catchUp // ignore: cast_nullable_to_non_nullable
as LiveCatchUp?,epgId: freezed == epgId ? _self.epgId : epgId // ignore: cast_nullable_to_non_nullable
as String?,currentProgramme: freezed == currentProgramme ? _self.currentProgramme : currentProgramme // ignore: cast_nullable_to_non_nullable
as String?,currentProgrammeDescription: freezed == currentProgrammeDescription ? _self.currentProgrammeDescription : currentProgrammeDescription // ignore: cast_nullable_to_non_nullable
as String?,isScheduled: null == isScheduled ? _self.isScheduled : isScheduled // ignore: cast_nullable_to_non_nullable
as bool,streamId: freezed == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,sitePayload: null == sitePayload ? _self._sitePayload : sitePayload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,danmakuPayload: null == danmakuPayload ? _self._danmakuPayload : danmakuPayload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveAudienceCopyWith<$Res>? get audience {
    if (_self.audience == null) {
    return null;
  }

  return $LiveAudienceCopyWith<$Res>(_self.audience!, (value) {
    return _then(_self.copyWith(audience: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveCatchUpCopyWith<$Res>? get catchUp {
    if (_self.catchUp == null) {
    return null;
  }

  return $LiveCatchUpCopyWith<$Res>(_self.catchUp!, (value) {
    return _then(_self.copyWith(catchUp: value));
  });
}
}

// dart format on
