// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_play_lease.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LivePlayLease {

 DateTime get refreshAt; DateTime? get expiresAt; bool get requiresReconnect;
/// Create a copy of LivePlayLease
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LivePlayLeaseCopyWith<LivePlayLease> get copyWith => _$LivePlayLeaseCopyWithImpl<LivePlayLease>(this as LivePlayLease, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LivePlayLease;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LivePlayLease&&(identical(other.refreshAt, _this.refreshAt) || other.refreshAt == _this.refreshAt)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.requiresReconnect, _this.requiresReconnect) || other.requiresReconnect == _this.requiresReconnect));
}


@override
int get hashCode {
  final _this = this as LivePlayLease;
  return Object.hash(runtimeType,_this.refreshAt,_this.expiresAt,_this.requiresReconnect);
}

@override
String toString() {
  final _this = this as LivePlayLease;
  return 'LivePlayLease(refreshAt: ${_this.refreshAt}, expiresAt: ${_this.expiresAt}, requiresReconnect: ${_this.requiresReconnect})';
}


}

/// @nodoc
abstract mixin class $LivePlayLeaseCopyWith<$Res>  {
  factory $LivePlayLeaseCopyWith(LivePlayLease value, $Res Function(LivePlayLease) _then) = _$LivePlayLeaseCopyWithImpl;
@useResult
$Res call({
 DateTime refreshAt, DateTime? expiresAt, bool requiresReconnect
});




}
/// @nodoc
class _$LivePlayLeaseCopyWithImpl<$Res>
    implements $LivePlayLeaseCopyWith<$Res> {
  _$LivePlayLeaseCopyWithImpl(this._self, this._then);

  final LivePlayLease _self;
  final $Res Function(LivePlayLease) _then;

/// Create a copy of LivePlayLease
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? refreshAt = null,Object? expiresAt = freezed,Object? requiresReconnect = null,}) {
  return _then(LivePlayLease(
refreshAt: null == refreshAt ? _self.refreshAt : refreshAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,requiresReconnect: null == requiresReconnect ? _self.requiresReconnect : requiresReconnect // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LivePlayLease].
extension LivePlayLeasePatterns on LivePlayLease {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LivePlayLease value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LivePlayLease() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LivePlayLease value)  $default,){
final _that = this;
switch (_that) {
case _LivePlayLease():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LivePlayLease value)?  $default,){
final _that = this;
switch (_that) {
case _LivePlayLease() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime refreshAt,  DateTime? expiresAt,  bool requiresReconnect)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LivePlayLease() when $default != null:
return $default(_that.refreshAt,_that.expiresAt,_that.requiresReconnect);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime refreshAt,  DateTime? expiresAt,  bool requiresReconnect)  $default,) {final _that = this;
switch (_that) {
case _LivePlayLease():
return $default(_that.refreshAt,_that.expiresAt,_that.requiresReconnect);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime refreshAt,  DateTime? expiresAt,  bool requiresReconnect)?  $default,) {final _that = this;
switch (_that) {
case _LivePlayLease() when $default != null:
return $default(_that.refreshAt,_that.expiresAt,_that.requiresReconnect);case _:
  return null;

}
}

}

/// @nodoc


class _LivePlayLease implements LivePlayLease {
  const _LivePlayLease({required this.refreshAt, this.expiresAt, this.requiresReconnect = false});
  

@override final  DateTime refreshAt;
@override final  DateTime? expiresAt;
@override@JsonKey() final  bool requiresReconnect;

/// Create a copy of LivePlayLease
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LivePlayLeaseCopyWith<_LivePlayLease> get copyWith => __$LivePlayLeaseCopyWithImpl<_LivePlayLease>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LivePlayLease&&(identical(other.refreshAt, refreshAt) || other.refreshAt == refreshAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.requiresReconnect, requiresReconnect) || other.requiresReconnect == requiresReconnect));
}


@override
int get hashCode {
    return Object.hash(runtimeType,refreshAt,expiresAt,requiresReconnect);
}

@override
String toString() {
    return 'LivePlayLease(refreshAt: $refreshAt, expiresAt: $expiresAt, requiresReconnect: $requiresReconnect)';
}


}

/// @nodoc
abstract mixin class _$LivePlayLeaseCopyWith<$Res> implements $LivePlayLeaseCopyWith<$Res> {
  factory _$LivePlayLeaseCopyWith(_LivePlayLease value, $Res Function(_LivePlayLease) _then) = __$LivePlayLeaseCopyWithImpl;
@override @useResult
$Res call({
 DateTime refreshAt, DateTime? expiresAt, bool requiresReconnect
});




}
/// @nodoc
class __$LivePlayLeaseCopyWithImpl<$Res>
    implements _$LivePlayLeaseCopyWith<$Res> {
  __$LivePlayLeaseCopyWithImpl(this._self, this._then);

  final _LivePlayLease _self;
  final $Res Function(_LivePlayLease) _then;

/// Create a copy of LivePlayLease
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? refreshAt = null,Object? expiresAt = freezed,Object? requiresReconnect = null,}) {
  return _then(_LivePlayLease(
refreshAt: null == refreshAt ? _self.refreshAt : refreshAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,requiresReconnect: null == requiresReconnect ? _self.requiresReconnect : requiresReconnect // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
