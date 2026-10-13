// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_runtime.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RoomRuntime {

 Object? get streamHandle; Object? get danmakuHandle;
/// Create a copy of RoomRuntime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomRuntimeCopyWith<RoomRuntime> get copyWith => _$RoomRuntimeCopyWithImpl<RoomRuntime>(this as RoomRuntime, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RoomRuntime;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomRuntime&&const DeepCollectionEquality().equals(other.streamHandle, _this.streamHandle)&&const DeepCollectionEquality().equals(other.danmakuHandle, _this.danmakuHandle));
}


@override
int get hashCode {
  final _this = this as RoomRuntime;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.streamHandle),const DeepCollectionEquality().hash(_this.danmakuHandle));
}

@override
String toString() {
  final _this = this as RoomRuntime;
  return 'RoomRuntime(streamHandle: ${_this.streamHandle}, danmakuHandle: ${_this.danmakuHandle})';
}


}

/// @nodoc
abstract mixin class $RoomRuntimeCopyWith<$Res>  {
  factory $RoomRuntimeCopyWith(RoomRuntime value, $Res Function(RoomRuntime) _then) = _$RoomRuntimeCopyWithImpl;
@useResult
$Res call({
 Object? streamHandle, Object? danmakuHandle
});




}
/// @nodoc
class _$RoomRuntimeCopyWithImpl<$Res>
    implements $RoomRuntimeCopyWith<$Res> {
  _$RoomRuntimeCopyWithImpl(this._self, this._then);

  final RoomRuntime _self;
  final $Res Function(RoomRuntime) _then;

/// Create a copy of RoomRuntime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? streamHandle = freezed,Object? danmakuHandle = freezed,}) {
  return _then(RoomRuntime(
streamHandle: freezed == streamHandle ? _self.streamHandle : streamHandle ,danmakuHandle: freezed == danmakuHandle ? _self.danmakuHandle : danmakuHandle ,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomRuntime].
extension RoomRuntimePatterns on RoomRuntime {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomRuntime value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomRuntime() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomRuntime value)  $default,){
final _that = this;
switch (_that) {
case _RoomRuntime():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomRuntime value)?  $default,){
final _that = this;
switch (_that) {
case _RoomRuntime() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Object? streamHandle,  Object? danmakuHandle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomRuntime() when $default != null:
return $default(_that.streamHandle,_that.danmakuHandle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Object? streamHandle,  Object? danmakuHandle)  $default,) {final _that = this;
switch (_that) {
case _RoomRuntime():
return $default(_that.streamHandle,_that.danmakuHandle);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Object? streamHandle,  Object? danmakuHandle)?  $default,) {final _that = this;
switch (_that) {
case _RoomRuntime() when $default != null:
return $default(_that.streamHandle,_that.danmakuHandle);case _:
  return null;

}
}

}

/// @nodoc


class _RoomRuntime implements RoomRuntime {
  const _RoomRuntime({this.streamHandle, this.danmakuHandle});
  

@override final  Object? streamHandle;
@override final  Object? danmakuHandle;

/// Create a copy of RoomRuntime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomRuntimeCopyWith<_RoomRuntime> get copyWith => __$RoomRuntimeCopyWithImpl<_RoomRuntime>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomRuntime&&const DeepCollectionEquality().equals(other.streamHandle, streamHandle)&&const DeepCollectionEquality().equals(other.danmakuHandle, danmakuHandle));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(streamHandle),const DeepCollectionEquality().hash(danmakuHandle));
}

@override
String toString() {
    return 'RoomRuntime(streamHandle: $streamHandle, danmakuHandle: $danmakuHandle)';
}


}

/// @nodoc
abstract mixin class _$RoomRuntimeCopyWith<$Res> implements $RoomRuntimeCopyWith<$Res> {
  factory _$RoomRuntimeCopyWith(_RoomRuntime value, $Res Function(_RoomRuntime) _then) = __$RoomRuntimeCopyWithImpl;
@override @useResult
$Res call({
 Object? streamHandle, Object? danmakuHandle
});




}
/// @nodoc
class __$RoomRuntimeCopyWithImpl<$Res>
    implements _$RoomRuntimeCopyWith<$Res> {
  __$RoomRuntimeCopyWithImpl(this._self, this._then);

  final _RoomRuntime _self;
  final $Res Function(_RoomRuntime) _then;

/// Create a copy of RoomRuntime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? streamHandle = freezed,Object? danmakuHandle = freezed,}) {
  return _then(_RoomRuntime(
streamHandle: freezed == streamHandle ? _self.streamHandle : streamHandle ,danmakuHandle: freezed == danmakuHandle ? _self.danmakuHandle : danmakuHandle ,
  ));
}


}

// dart format on
