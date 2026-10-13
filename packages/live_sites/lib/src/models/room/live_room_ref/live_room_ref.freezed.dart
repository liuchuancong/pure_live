// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_room_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveRoomRef {

 String get platform; String get roomId;
/// Create a copy of LiveRoomRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveRoomRefCopyWith<LiveRoomRef> get copyWith => _$LiveRoomRefCopyWithImpl<LiveRoomRef>(this as LiveRoomRef, _$identity);

  /// Serializes this LiveRoomRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveRoomRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoomRef&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoomRef;
  return Object.hash(runtimeType,_this.platform,_this.roomId);
}

@override
String toString() {
  final _this = this as LiveRoomRef;
  return 'LiveRoomRef(platform: ${_this.platform}, roomId: ${_this.roomId})';
}


}

/// @nodoc
abstract mixin class $LiveRoomRefCopyWith<$Res>  {
  factory $LiveRoomRefCopyWith(LiveRoomRef value, $Res Function(LiveRoomRef) _then) = _$LiveRoomRefCopyWithImpl;
@useResult
$Res call({
 String platform, String roomId
});




}
/// @nodoc
class _$LiveRoomRefCopyWithImpl<$Res>
    implements $LiveRoomRefCopyWith<$Res> {
  _$LiveRoomRefCopyWithImpl(this._self, this._then);

  final LiveRoomRef _self;
  final $Res Function(LiveRoomRef) _then;

/// Create a copy of LiveRoomRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? platform = null,Object? roomId = null,}) {
  return _then(LiveRoomRef(
platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveRoomRef].
extension LiveRoomRefPatterns on LiveRoomRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveRoomRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveRoomRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveRoomRef value)  $default,){
final _that = this;
switch (_that) {
case _LiveRoomRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveRoomRef value)?  $default,){
final _that = this;
switch (_that) {
case _LiveRoomRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String platform,  String roomId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoomRef() when $default != null:
return $default(_that.platform,_that.roomId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String platform,  String roomId)  $default,) {final _that = this;
switch (_that) {
case _LiveRoomRef():
return $default(_that.platform,_that.roomId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String platform,  String roomId)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoomRef() when $default != null:
return $default(_that.platform,_that.roomId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoomRef implements LiveRoomRef {
  const _LiveRoomRef({required this.platform, required this.roomId});
  factory _LiveRoomRef.fromJson(Map<String, dynamic> json) => _$LiveRoomRefFromJson(json);

@override final  String platform;
@override final  String roomId;

/// Create a copy of LiveRoomRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveRoomRefCopyWith<_LiveRoomRef> get copyWith => __$LiveRoomRefCopyWithImpl<_LiveRoomRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveRoomRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoomRef&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.roomId, roomId) || other.roomId == roomId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,platform,roomId);
}

@override
String toString() {
    return 'LiveRoomRef(platform: $platform, roomId: $roomId)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomRefCopyWith<$Res> implements $LiveRoomRefCopyWith<$Res> {
  factory _$LiveRoomRefCopyWith(_LiveRoomRef value, $Res Function(_LiveRoomRef) _then) = __$LiveRoomRefCopyWithImpl;
@override @useResult
$Res call({
 String platform, String roomId
});




}
/// @nodoc
class __$LiveRoomRefCopyWithImpl<$Res>
    implements _$LiveRoomRefCopyWith<$Res> {
  __$LiveRoomRefCopyWithImpl(this._self, this._then);

  final _LiveRoomRef _self;
  final $Res Function(_LiveRoomRef) _then;

/// Create a copy of LiveRoomRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? platform = null,Object? roomId = null,}) {
  return _then(_LiveRoomRef(
platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
