// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_room_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveRoomStatus {

 ContentRef get ref;/// [LiveRoomState.unknown] is "the source could not tell" and is deliberately not collapsed into
/// [LiveRoomState.ended]: a follow list that reads a timeout as off-air stops watching a live stream.
 LiveRoomState get state;/// Viewer count exactly as the platform worded it. The unit (concurrent viewers, total visits, heat) is
/// the source's own, so this model does not rename it; a surface that shows it carries the platform's label.
@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? get viewers; String? get title; String? get cover; String? get anchorName;/// When the broadcast started, when the source says so.
 DateTime? get startedAt;
/// Create a copy of LiveRoomStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveRoomStatusCopyWith<LiveRoomStatus> get copyWith => _$LiveRoomStatusCopyWithImpl<LiveRoomStatus>(this as LiveRoomStatus, _$identity);

  /// Serializes this LiveRoomStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveRoomStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoomStatus&&(identical(other.ref, _this.ref) || other.ref == _this.ref)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.viewers, _this.viewers) || other.viewers == _this.viewers)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.cover, _this.cover) || other.cover == _this.cover)&&(identical(other.anchorName, _this.anchorName) || other.anchorName == _this.anchorName)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoomStatus;
  return Object.hash(runtimeType,_this.ref,_this.state,_this.viewers,_this.title,_this.cover,_this.anchorName,_this.startedAt);
}

@override
String toString() {
  final _this = this as LiveRoomStatus;
  return 'LiveRoomStatus(ref: ${_this.ref}, state: ${_this.state}, viewers: ${_this.viewers}, title: ${_this.title}, cover: ${_this.cover}, anchorName: ${_this.anchorName}, startedAt: ${_this.startedAt})';
}


}

/// @nodoc
abstract mixin class $LiveRoomStatusCopyWith<$Res>  {
  factory $LiveRoomStatusCopyWith(LiveRoomStatus value, $Res Function(LiveRoomStatus) _then) = _$LiveRoomStatusCopyWithImpl;
@useResult
$Res call({
 ContentRef ref, LiveRoomState state,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? viewers, String? title, String? cover, String? anchorName, DateTime? startedAt
});




}
/// @nodoc
class _$LiveRoomStatusCopyWithImpl<$Res>
    implements $LiveRoomStatusCopyWith<$Res> {
  _$LiveRoomStatusCopyWithImpl(this._self, this._then);

  final LiveRoomStatus _self;
  final $Res Function(LiveRoomStatus) _then;

/// Create a copy of LiveRoomStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ref = null,Object? state = null,Object? viewers = freezed,Object? title = freezed,Object? cover = freezed,Object? anchorName = freezed,Object? startedAt = freezed,}) {
  return _then(LiveRoomStatus(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as ContentRef,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as LiveRoomState,viewers: freezed == viewers ? _self.viewers : viewers // ignore: cast_nullable_to_non_nullable
as int?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,anchorName: freezed == anchorName ? _self.anchorName : anchorName // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveRoomStatus].
extension LiveRoomStatusPatterns on LiveRoomStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveRoomStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveRoomStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveRoomStatus value)  $default,){
final _that = this;
switch (_that) {
case _LiveRoomStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveRoomStatus value)?  $default,){
final _that = this;
switch (_that) {
case _LiveRoomStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ContentRef ref,  LiveRoomState state, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? viewers,  String? title,  String? cover,  String? anchorName,  DateTime? startedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoomStatus() when $default != null:
return $default(_that.ref,_that.state,_that.viewers,_that.title,_that.cover,_that.anchorName,_that.startedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ContentRef ref,  LiveRoomState state, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? viewers,  String? title,  String? cover,  String? anchorName,  DateTime? startedAt)  $default,) {final _that = this;
switch (_that) {
case _LiveRoomStatus():
return $default(_that.ref,_that.state,_that.viewers,_that.title,_that.cover,_that.anchorName,_that.startedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ContentRef ref,  LiveRoomState state, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull)  int? viewers,  String? title,  String? cover,  String? anchorName,  DateTime? startedAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoomStatus() when $default != null:
return $default(_that.ref,_that.state,_that.viewers,_that.title,_that.cover,_that.anchorName,_that.startedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoomStatus extends LiveRoomStatus {
  const _LiveRoomStatus({required this.ref, required this.state, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) this.viewers, this.title, this.cover, this.anchorName, this.startedAt}): super._();
  factory _LiveRoomStatus.fromJson(Map<String, dynamic> json) => _$LiveRoomStatusFromJson(json);

@override final  ContentRef ref;
/// [LiveRoomState.unknown] is "the source could not tell" and is deliberately not collapsed into
/// [LiveRoomState.ended]: a follow list that reads a timeout as off-air stops watching a live stream.
@override final  LiveRoomState state;
/// Viewer count exactly as the platform worded it. The unit (concurrent viewers, total visits, heat) is
/// the source's own, so this model does not rename it; a surface that shows it carries the platform's label.
@override@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) final  int? viewers;
@override final  String? title;
@override final  String? cover;
@override final  String? anchorName;
/// When the broadcast started, when the source says so.
@override final  DateTime? startedAt;

/// Create a copy of LiveRoomStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveRoomStatusCopyWith<_LiveRoomStatus> get copyWith => __$LiveRoomStatusCopyWithImpl<_LiveRoomStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveRoomStatusToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoomStatus&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.state, state) || other.state == state)&&(identical(other.viewers, viewers) || other.viewers == viewers)&&(identical(other.title, title) || other.title == title)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.anchorName, anchorName) || other.anchorName == anchorName)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ref,state,viewers,title,cover,anchorName,startedAt);
}

@override
String toString() {
    return 'LiveRoomStatus(ref: $ref, state: $state, viewers: $viewers, title: $title, cover: $cover, anchorName: $anchorName, startedAt: $startedAt)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomStatusCopyWith<$Res> implements $LiveRoomStatusCopyWith<$Res> {
  factory _$LiveRoomStatusCopyWith(_LiveRoomStatus value, $Res Function(_LiveRoomStatus) _then) = __$LiveRoomStatusCopyWithImpl;
@override @useResult
$Res call({
 ContentRef ref, LiveRoomState state,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? viewers, String? title, String? cover, String? anchorName, DateTime? startedAt
});




}
/// @nodoc
class __$LiveRoomStatusCopyWithImpl<$Res>
    implements _$LiveRoomStatusCopyWith<$Res> {
  __$LiveRoomStatusCopyWithImpl(this._self, this._then);

  final _LiveRoomStatus _self;
  final $Res Function(_LiveRoomStatus) _then;

/// Create a copy of LiveRoomStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ref = null,Object? state = null,Object? viewers = freezed,Object? title = freezed,Object? cover = freezed,Object? anchorName = freezed,Object? startedAt = freezed,}) {
  return _then(_LiveRoomStatus(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as ContentRef,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as LiveRoomState,viewers: freezed == viewers ? _self.viewers : viewers // ignore: cast_nullable_to_non_nullable
as int?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,anchorName: freezed == anchorName ? _self.anchorName : anchorName // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
