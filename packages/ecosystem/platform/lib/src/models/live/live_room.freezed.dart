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
@JsonKey(fromJson: _text) String? get area;/// Room introduction / announcement text, when the site keeps one apart from the title.
@JsonKey(fromJson: _text) String? get introduction;/// The audience figure exactly as the platform reported it. Null is "it did not say" - which is not zero, and
/// a room page that shows "0 人看过" for an unstated count is putting a number on the site's silence.
@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? get viewers;/// Followers / fan count when the room answer carries it (acfun's `user.fanCountValue` is a *label*, so that
/// one goes in [extra] instead of being parsed into a number nobody asked for).
@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? get followers;/// When the broadcast began, from a field the source stated. A room page's "已直播 2 小时" comes from here and
/// from nowhere else.
@JsonKey(fromJson: _at, toJson: formatUtc) DateTime? get startedAt;/// The stream is behind a paywall, a fan club gate, or an account the anonymous path cannot satisfy. Set it
/// when the source says so: a viewer who pressed play and got a black screen with no explanation blames the
/// player, and this is the field that lets the surface say why instead.
 bool get requiresAuth;/// The broadcast is scheduled for later as well as not-yet-on-air. Only meaningful with
/// [LiveRoomState.notStarted], and it is what a reminder can be offered on.
 bool get isScheduled;/// The liveId / stream name this answer describes, when the source has one distinct from the room id. It is
/// per-broadcast: storing it as the ref would orphan the room the moment the anchor goes off air.
@JsonKey(fromJson: _text) String? get streamId;@JsonKey(fromJson: _stringList, toJson: _stringListOut) List<String> get tags;/// Whatever this site states that this shape cannot name. The bar for a key here is "the platform said it and
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoom&&(identical(other.ref, _this.ref) || other.ref == _this.ref)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.anchorName, _this.anchorName) || other.anchorName == _this.anchorName)&&(identical(other.anchorId, _this.anchorId) || other.anchorId == _this.anchorId)&&(identical(other.avatar, _this.avatar) || other.avatar == _this.avatar)&&(identical(other.cover, _this.cover) || other.cover == _this.cover)&&(identical(other.area, _this.area) || other.area == _this.area)&&(identical(other.introduction, _this.introduction) || other.introduction == _this.introduction)&&(identical(other.viewers, _this.viewers) || other.viewers == _this.viewers)&&(identical(other.followers, _this.followers) || other.followers == _this.followers)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.requiresAuth, _this.requiresAuth) || other.requiresAuth == _this.requiresAuth)&&(identical(other.isScheduled, _this.isScheduled) || other.isScheduled == _this.isScheduled)&&(identical(other.streamId, _this.streamId) || other.streamId == _this.streamId)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&const DeepCollectionEquality().equals(other.extra, _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoom;
  return Object.hash(runtimeType,_this.ref,_this.state,_this.title,_this.anchorName,_this.anchorId,_this.avatar,_this.cover,_this.area,_this.introduction,_this.viewers,_this.followers,_this.startedAt,_this.requiresAuth,_this.isScheduled,_this.streamId,const DeepCollectionEquality().hash(_this.tags),const DeepCollectionEquality().hash(_this.extra));
}

@override
String toString() {
  final _this = this as LiveRoom;
  return 'LiveRoom(ref: ${_this.ref}, state: ${_this.state}, title: ${_this.title}, anchorName: ${_this.anchorName}, anchorId: ${_this.anchorId}, avatar: ${_this.avatar}, cover: ${_this.cover}, area: ${_this.area}, introduction: ${_this.introduction}, viewers: ${_this.viewers}, followers: ${_this.followers}, startedAt: ${_this.startedAt}, requiresAuth: ${_this.requiresAuth}, isScheduled: ${_this.isScheduled}, streamId: ${_this.streamId}, tags: ${_this.tags}, extra: ${_this.extra})';
}


}

/// @nodoc
abstract mixin class $LiveRoomCopyWith<$Res>  {
  factory $LiveRoomCopyWith(LiveRoom value, $Res Function(LiveRoom) _then) = _$LiveRoomCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef ref,@JsonKey(fromJson: _state) LiveRoomState state, String title,@JsonKey(fromJson: _text) String? anchorName,@JsonKey(fromJson: _text) String? anchorId,@JsonKey(fromJson: _text) String? avatar,@JsonKey(fromJson: _text) String? cover,@JsonKey(fromJson: _text) String? area,@JsonKey(fromJson: _text) String? introduction,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? viewers,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? followers,@JsonKey(fromJson: _at, toJson: formatUtc) DateTime? startedAt, bool requiresAuth, bool isScheduled,@JsonKey(fromJson: _text) String? streamId,@JsonKey(fromJson: _stringList, toJson: _stringListOut) List<String> tags,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> extra
});




}
/// @nodoc
class _$LiveRoomCopyWithImpl<$Res>
    implements $LiveRoomCopyWith<$Res> {
  _$LiveRoomCopyWithImpl(this._self, this._then);

  final LiveRoom _self;
  final $Res Function(LiveRoom) _then;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ref = null,Object? state = null,Object? title = null,Object? anchorName = freezed,Object? anchorId = freezed,Object? avatar = freezed,Object? cover = freezed,Object? area = freezed,Object? introduction = freezed,Object? viewers = freezed,Object? followers = freezed,Object? startedAt = freezed,Object? requiresAuth = null,Object? isScheduled = null,Object? streamId = freezed,Object? tags = null,Object? extra = null,}) {
  return _then(LiveRoom(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as ContentRef,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as LiveRoomState,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,anchorName: freezed == anchorName ? _self.anchorName : anchorName // ignore: cast_nullable_to_non_nullable
as String?,anchorId: freezed == anchorId ? _self.anchorId : anchorId // ignore: cast_nullable_to_non_nullable
as String?,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,area: freezed == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as String?,introduction: freezed == introduction ? _self.introduction : introduction // ignore: cast_nullable_to_non_nullable
as String?,viewers: freezed == viewers ? _self.viewers : viewers // ignore: cast_nullable_to_non_nullable
as int?,followers: freezed == followers ? _self.followers : followers // ignore: cast_nullable_to_non_nullable
as int?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,requiresAuth: null == requiresAuth ? _self.requiresAuth : requiresAuth // ignore: cast_nullable_to_non_nullable
as bool,isScheduled: null == isScheduled ? _self.isScheduled : isScheduled // ignore: cast_nullable_to_non_nullable
as bool,streamId: freezed == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef ref, @JsonKey(fromJson: _state)  LiveRoomState state,  String title, @JsonKey(fromJson: _text)  String? anchorName, @JsonKey(fromJson: _text)  String? anchorId, @JsonKey(fromJson: _text)  String? avatar, @JsonKey(fromJson: _text)  String? cover, @JsonKey(fromJson: _text)  String? area, @JsonKey(fromJson: _text)  String? introduction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? viewers, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? followers, @JsonKey(fromJson: _at, toJson: formatUtc)  DateTime? startedAt,  bool requiresAuth,  bool isScheduled, @JsonKey(fromJson: _text)  String? streamId, @JsonKey(fromJson: _stringList, toJson: _stringListOut)  List<String> tags, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.ref,_that.state,_that.title,_that.anchorName,_that.anchorId,_that.avatar,_that.cover,_that.area,_that.introduction,_that.viewers,_that.followers,_that.startedAt,_that.requiresAuth,_that.isScheduled,_that.streamId,_that.tags,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef ref, @JsonKey(fromJson: _state)  LiveRoomState state,  String title, @JsonKey(fromJson: _text)  String? anchorName, @JsonKey(fromJson: _text)  String? anchorId, @JsonKey(fromJson: _text)  String? avatar, @JsonKey(fromJson: _text)  String? cover, @JsonKey(fromJson: _text)  String? area, @JsonKey(fromJson: _text)  String? introduction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? viewers, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? followers, @JsonKey(fromJson: _at, toJson: formatUtc)  DateTime? startedAt,  bool requiresAuth,  bool isScheduled, @JsonKey(fromJson: _text)  String? streamId, @JsonKey(fromJson: _stringList, toJson: _stringListOut)  List<String> tags, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)  $default,) {final _that = this;
switch (_that) {
case _LiveRoom():
return $default(_that.ref,_that.state,_that.title,_that.anchorName,_that.anchorId,_that.avatar,_that.cover,_that.area,_that.introduction,_that.viewers,_that.followers,_that.startedAt,_that.requiresAuth,_that.isScheduled,_that.streamId,_that.tags,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef ref, @JsonKey(fromJson: _state)  LiveRoomState state,  String title, @JsonKey(fromJson: _text)  String? anchorName, @JsonKey(fromJson: _text)  String? anchorId, @JsonKey(fromJson: _text)  String? avatar, @JsonKey(fromJson: _text)  String? cover, @JsonKey(fromJson: _text)  String? area, @JsonKey(fromJson: _text)  String? introduction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? viewers, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? followers, @JsonKey(fromJson: _at, toJson: formatUtc)  DateTime? startedAt,  bool requiresAuth,  bool isScheduled, @JsonKey(fromJson: _text)  String? streamId, @JsonKey(fromJson: _stringList, toJson: _stringListOut)  List<String> tags, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.ref,_that.state,_that.title,_that.anchorName,_that.anchorId,_that.avatar,_that.cover,_that.area,_that.introduction,_that.viewers,_that.followers,_that.startedAt,_that.requiresAuth,_that.isScheduled,_that.streamId,_that.tags,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoom extends LiveRoom {
  const _LiveRoom({@JsonKey(fromJson: refFromJson, toJson: refToJson) required this.ref, @JsonKey(fromJson: _state) required this.state, required this.title, @JsonKey(fromJson: _text) this.anchorName, @JsonKey(fromJson: _text) this.anchorId, @JsonKey(fromJson: _text) this.avatar, @JsonKey(fromJson: _text) this.cover, @JsonKey(fromJson: _text) this.area, @JsonKey(fromJson: _text) this.introduction, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) this.viewers, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) this.followers, @JsonKey(fromJson: _at, toJson: formatUtc) this.startedAt, this.requiresAuth = false, this.isScheduled = false, @JsonKey(fromJson: _text) this.streamId, @JsonKey(fromJson: _stringList, toJson: _stringListOut)  List<String> tags = const <String>[], @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra = const <String, Object?>{}}): _tags = tags,_extra = extra,super._();
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
@override@JsonKey(fromJson: _text) final  String? area;
/// Room introduction / announcement text, when the site keeps one apart from the title.
@override@JsonKey(fromJson: _text) final  String? introduction;
/// The audience figure exactly as the platform reported it. Null is "it did not say" - which is not zero, and
/// a room page that shows "0 人看过" for an unstated count is putting a number on the site's silence.
@override@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) final  int? viewers;
/// Followers / fan count when the room answer carries it (acfun's `user.fanCountValue` is a *label*, so that
/// one goes in [extra] instead of being parsed into a number nobody asked for).
@override@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) final  int? followers;
/// When the broadcast began, from a field the source stated. A room page's "已直播 2 小时" comes from here and
/// from nowhere else.
@override@JsonKey(fromJson: _at, toJson: formatUtc) final  DateTime? startedAt;
/// The stream is behind a paywall, a fan club gate, or an account the anonymous path cannot satisfy. Set it
/// when the source says so: a viewer who pressed play and got a black screen with no explanation blames the
/// player, and this is the field that lets the surface say why instead.
@override@JsonKey() final  bool requiresAuth;
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoom&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.state, state) || other.state == state)&&(identical(other.title, title) || other.title == title)&&(identical(other.anchorName, anchorName) || other.anchorName == anchorName)&&(identical(other.anchorId, anchorId) || other.anchorId == anchorId)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.area, area) || other.area == area)&&(identical(other.introduction, introduction) || other.introduction == introduction)&&(identical(other.viewers, viewers) || other.viewers == viewers)&&(identical(other.followers, followers) || other.followers == followers)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.requiresAuth, requiresAuth) || other.requiresAuth == requiresAuth)&&(identical(other.isScheduled, isScheduled) || other.isScheduled == isScheduled)&&(identical(other.streamId, streamId) || other.streamId == streamId)&&const DeepCollectionEquality().equals(other.tags, _tags)&&const DeepCollectionEquality().equals(other.extra, _extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ref,state,title,anchorName,anchorId,avatar,cover,area,introduction,viewers,followers,startedAt,requiresAuth,isScheduled,streamId,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'LiveRoom(ref: $ref, state: $state, title: $title, anchorName: $anchorName, anchorId: $anchorId, avatar: $avatar, cover: $cover, area: $area, introduction: $introduction, viewers: $viewers, followers: $followers, startedAt: $startedAt, requiresAuth: $requiresAuth, isScheduled: $isScheduled, streamId: $streamId, tags: $tags, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomCopyWith<$Res> implements $LiveRoomCopyWith<$Res> {
  factory _$LiveRoomCopyWith(_LiveRoom value, $Res Function(_LiveRoom) _then) = __$LiveRoomCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef ref,@JsonKey(fromJson: _state) LiveRoomState state, String title,@JsonKey(fromJson: _text) String? anchorName,@JsonKey(fromJson: _text) String? anchorId,@JsonKey(fromJson: _text) String? avatar,@JsonKey(fromJson: _text) String? cover,@JsonKey(fromJson: _text) String? area,@JsonKey(fromJson: _text) String? introduction,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? viewers,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? followers,@JsonKey(fromJson: _at, toJson: formatUtc) DateTime? startedAt, bool requiresAuth, bool isScheduled,@JsonKey(fromJson: _text) String? streamId,@JsonKey(fromJson: _stringList, toJson: _stringListOut) List<String> tags,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> extra
});




}
/// @nodoc
class __$LiveRoomCopyWithImpl<$Res>
    implements _$LiveRoomCopyWith<$Res> {
  __$LiveRoomCopyWithImpl(this._self, this._then);

  final _LiveRoom _self;
  final $Res Function(_LiveRoom) _then;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ref = null,Object? state = null,Object? title = null,Object? anchorName = freezed,Object? anchorId = freezed,Object? avatar = freezed,Object? cover = freezed,Object? area = freezed,Object? introduction = freezed,Object? viewers = freezed,Object? followers = freezed,Object? startedAt = freezed,Object? requiresAuth = null,Object? isScheduled = null,Object? streamId = freezed,Object? tags = null,Object? extra = null,}) {
  return _then(_LiveRoom(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as ContentRef,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as LiveRoomState,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,anchorName: freezed == anchorName ? _self.anchorName : anchorName // ignore: cast_nullable_to_non_nullable
as String?,anchorId: freezed == anchorId ? _self.anchorId : anchorId // ignore: cast_nullable_to_non_nullable
as String?,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,area: freezed == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as String?,introduction: freezed == introduction ? _self.introduction : introduction // ignore: cast_nullable_to_non_nullable
as String?,viewers: freezed == viewers ? _self.viewers : viewers // ignore: cast_nullable_to_non_nullable
as int?,followers: freezed == followers ? _self.followers : followers // ignore: cast_nullable_to_non_nullable
as int?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,requiresAuth: null == requiresAuth ? _self.requiresAuth : requiresAuth // ignore: cast_nullable_to_non_nullable
as bool,isScheduled: null == isScheduled ? _self.isScheduled : isScheduled // ignore: cast_nullable_to_non_nullable
as bool,streamId: freezed == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

// dart format on
