// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_broadcast.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoomBroadcast {

@LiveStatusByNameConverter() LiveStatus? get liveStatus;@EpochMillisConverter() DateTime? get startedAt; LiveRestriction? get restriction; LiveRoomActivity get activity;
/// Create a copy of RoomBroadcast
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomBroadcastCopyWith<RoomBroadcast> get copyWith => _$RoomBroadcastCopyWithImpl<RoomBroadcast>(this as RoomBroadcast, _$identity);

  /// Serializes this RoomBroadcast to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RoomBroadcast;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomBroadcast&&(identical(other.liveStatus, _this.liveStatus) || other.liveStatus == _this.liveStatus)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.restriction, _this.restriction) || other.restriction == _this.restriction)&&(identical(other.activity, _this.activity) || other.activity == _this.activity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomBroadcast;
  return Object.hash(runtimeType,_this.liveStatus,_this.startedAt,_this.restriction,_this.activity);
}

@override
String toString() {
  final _this = this as RoomBroadcast;
  return 'RoomBroadcast(liveStatus: ${_this.liveStatus}, startedAt: ${_this.startedAt}, restriction: ${_this.restriction}, activity: ${_this.activity})';
}


}

/// @nodoc
abstract mixin class $RoomBroadcastCopyWith<$Res>  {
  factory $RoomBroadcastCopyWith(RoomBroadcast value, $Res Function(RoomBroadcast) _then) = _$RoomBroadcastCopyWithImpl;
@useResult
$Res call({
@LiveStatusByNameConverter() LiveStatus? liveStatus,@EpochMillisConverter() DateTime? startedAt, LiveRestriction? restriction, LiveRoomActivity activity
});




}
/// @nodoc
class _$RoomBroadcastCopyWithImpl<$Res>
    implements $RoomBroadcastCopyWith<$Res> {
  _$RoomBroadcastCopyWithImpl(this._self, this._then);

  final RoomBroadcast _self;
  final $Res Function(RoomBroadcast) _then;

/// Create a copy of RoomBroadcast
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? liveStatus = freezed,Object? startedAt = freezed,Object? restriction = freezed,Object? activity = null,}) {
  return _then(RoomBroadcast(
liveStatus: freezed == liveStatus ? _self.liveStatus : liveStatus // ignore: cast_nullable_to_non_nullable
as LiveStatus?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,restriction: freezed == restriction ? _self.restriction : restriction // ignore: cast_nullable_to_non_nullable
as LiveRestriction?,activity: null == activity ? _self.activity : activity // ignore: cast_nullable_to_non_nullable
as LiveRoomActivity,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomBroadcast].
extension RoomBroadcastPatterns on RoomBroadcast {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomBroadcast value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomBroadcast() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomBroadcast value)  $default,){
final _that = this;
switch (_that) {
case _RoomBroadcast():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomBroadcast value)?  $default,){
final _that = this;
switch (_that) {
case _RoomBroadcast() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@LiveStatusByNameConverter()  LiveStatus? liveStatus, @EpochMillisConverter()  DateTime? startedAt,  LiveRestriction? restriction,  LiveRoomActivity activity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomBroadcast() when $default != null:
return $default(_that.liveStatus,_that.startedAt,_that.restriction,_that.activity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@LiveStatusByNameConverter()  LiveStatus? liveStatus, @EpochMillisConverter()  DateTime? startedAt,  LiveRestriction? restriction,  LiveRoomActivity activity)  $default,) {final _that = this;
switch (_that) {
case _RoomBroadcast():
return $default(_that.liveStatus,_that.startedAt,_that.restriction,_that.activity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@LiveStatusByNameConverter()  LiveStatus? liveStatus, @EpochMillisConverter()  DateTime? startedAt,  LiveRestriction? restriction,  LiveRoomActivity activity)?  $default,) {final _that = this;
switch (_that) {
case _RoomBroadcast() when $default != null:
return $default(_that.liveStatus,_that.startedAt,_that.restriction,_that.activity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomBroadcast extends RoomBroadcast {
  const _RoomBroadcast({@LiveStatusByNameConverter() this.liveStatus, @EpochMillisConverter() this.startedAt, this.restriction, this.activity = LiveRoomActivity.none}): super._();
  factory _RoomBroadcast.fromJson(Map<String, dynamic> json) => _$RoomBroadcastFromJson(json);

@override@LiveStatusByNameConverter() final  LiveStatus? liveStatus;
@override@EpochMillisConverter() final  DateTime? startedAt;
@override final  LiveRestriction? restriction;
@override@JsonKey() final  LiveRoomActivity activity;

/// Create a copy of RoomBroadcast
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomBroadcastCopyWith<_RoomBroadcast> get copyWith => __$RoomBroadcastCopyWithImpl<_RoomBroadcast>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomBroadcastToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomBroadcast&&(identical(other.liveStatus, liveStatus) || other.liveStatus == liveStatus)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.restriction, restriction) || other.restriction == restriction)&&(identical(other.activity, activity) || other.activity == activity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,liveStatus,startedAt,restriction,activity);
}

@override
String toString() {
    return 'RoomBroadcast(liveStatus: $liveStatus, startedAt: $startedAt, restriction: $restriction, activity: $activity)';
}


}

/// @nodoc
abstract mixin class _$RoomBroadcastCopyWith<$Res> implements $RoomBroadcastCopyWith<$Res> {
  factory _$RoomBroadcastCopyWith(_RoomBroadcast value, $Res Function(_RoomBroadcast) _then) = __$RoomBroadcastCopyWithImpl;
@override @useResult
$Res call({
@LiveStatusByNameConverter() LiveStatus? liveStatus,@EpochMillisConverter() DateTime? startedAt, LiveRestriction? restriction, LiveRoomActivity activity
});




}
/// @nodoc
class __$RoomBroadcastCopyWithImpl<$Res>
    implements _$RoomBroadcastCopyWith<$Res> {
  __$RoomBroadcastCopyWithImpl(this._self, this._then);

  final _RoomBroadcast _self;
  final $Res Function(_RoomBroadcast) _then;

/// Create a copy of RoomBroadcast
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? liveStatus = freezed,Object? startedAt = freezed,Object? restriction = freezed,Object? activity = null,}) {
  return _then(_RoomBroadcast(
liveStatus: freezed == liveStatus ? _self.liveStatus : liveStatus // ignore: cast_nullable_to_non_nullable
as LiveStatus?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,restriction: freezed == restriction ? _self.restriction : restriction // ignore: cast_nullable_to_non_nullable
as LiveRestriction?,activity: null == activity ? _self.activity : activity // ignore: cast_nullable_to_non_nullable
as LiveRoomActivity,
  ));
}


}

// dart format on
