// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_audience_update.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LiveAudienceUpdate {

 LiveAudienceSignalKind get kind; int get value;
/// Create a copy of LiveAudienceUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveAudienceUpdateCopyWith<LiveAudienceUpdate> get copyWith => _$LiveAudienceUpdateCopyWithImpl<LiveAudienceUpdate>(this as LiveAudienceUpdate, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LiveAudienceUpdate;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveAudienceUpdate&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.value, _this.value) || other.value == _this.value));
}


@override
int get hashCode {
  final _this = this as LiveAudienceUpdate;
  return Object.hash(runtimeType,_this.kind,_this.value);
}

@override
String toString() {
  final _this = this as LiveAudienceUpdate;
  return 'LiveAudienceUpdate(kind: ${_this.kind}, value: ${_this.value})';
}


}

/// @nodoc
abstract mixin class $LiveAudienceUpdateCopyWith<$Res>  {
  factory $LiveAudienceUpdateCopyWith(LiveAudienceUpdate value, $Res Function(LiveAudienceUpdate) _then) = _$LiveAudienceUpdateCopyWithImpl;
@useResult
$Res call({
 LiveAudienceSignalKind kind, int value
});




}
/// @nodoc
class _$LiveAudienceUpdateCopyWithImpl<$Res>
    implements $LiveAudienceUpdateCopyWith<$Res> {
  _$LiveAudienceUpdateCopyWithImpl(this._self, this._then);

  final LiveAudienceUpdate _self;
  final $Res Function(LiveAudienceUpdate) _then;

/// Create a copy of LiveAudienceUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? value = null,}) {
  return _then(LiveAudienceUpdate(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LiveAudienceSignalKind,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveAudienceUpdate].
extension LiveAudienceUpdatePatterns on LiveAudienceUpdate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveAudienceUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveAudienceUpdate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveAudienceUpdate value)  $default,){
final _that = this;
switch (_that) {
case _LiveAudienceUpdate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveAudienceUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _LiveAudienceUpdate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveAudienceSignalKind kind,  int value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveAudienceUpdate() when $default != null:
return $default(_that.kind,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveAudienceSignalKind kind,  int value)  $default,) {final _that = this;
switch (_that) {
case _LiveAudienceUpdate():
return $default(_that.kind,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveAudienceSignalKind kind,  int value)?  $default,) {final _that = this;
switch (_that) {
case _LiveAudienceUpdate() when $default != null:
return $default(_that.kind,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _LiveAudienceUpdate implements LiveAudienceUpdate {
  const _LiveAudienceUpdate({required this.kind, required this.value});
  

@override final  LiveAudienceSignalKind kind;
@override final  int value;

/// Create a copy of LiveAudienceUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveAudienceUpdateCopyWith<_LiveAudienceUpdate> get copyWith => __$LiveAudienceUpdateCopyWithImpl<_LiveAudienceUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveAudienceUpdate&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,value);
}

@override
String toString() {
    return 'LiveAudienceUpdate(kind: $kind, value: $value)';
}


}

/// @nodoc
abstract mixin class _$LiveAudienceUpdateCopyWith<$Res> implements $LiveAudienceUpdateCopyWith<$Res> {
  factory _$LiveAudienceUpdateCopyWith(_LiveAudienceUpdate value, $Res Function(_LiveAudienceUpdate) _then) = __$LiveAudienceUpdateCopyWithImpl;
@override @useResult
$Res call({
 LiveAudienceSignalKind kind, int value
});




}
/// @nodoc
class __$LiveAudienceUpdateCopyWithImpl<$Res>
    implements _$LiveAudienceUpdateCopyWith<$Res> {
  __$LiveAudienceUpdateCopyWithImpl(this._self, this._then);

  final _LiveAudienceUpdate _self;
  final $Res Function(_LiveAudienceUpdate) _then;

/// Create a copy of LiveAudienceUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? value = null,}) {
  return _then(_LiveAudienceUpdate(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LiveAudienceSignalKind,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
