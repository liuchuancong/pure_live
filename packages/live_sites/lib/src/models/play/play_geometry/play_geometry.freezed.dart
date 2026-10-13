// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'play_geometry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlayGeometry {

 int? get width; int? get height; int? get frameRate; int? get bitrateKbps;
/// Create a copy of PlayGeometry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayGeometryCopyWith<PlayGeometry> get copyWith => _$PlayGeometryCopyWithImpl<PlayGeometry>(this as PlayGeometry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlayGeometry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayGeometry&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.frameRate, _this.frameRate) || other.frameRate == _this.frameRate)&&(identical(other.bitrateKbps, _this.bitrateKbps) || other.bitrateKbps == _this.bitrateKbps));
}


@override
int get hashCode {
  final _this = this as PlayGeometry;
  return Object.hash(runtimeType,_this.width,_this.height,_this.frameRate,_this.bitrateKbps);
}

@override
String toString() {
  final _this = this as PlayGeometry;
  return 'PlayGeometry(width: ${_this.width}, height: ${_this.height}, frameRate: ${_this.frameRate}, bitrateKbps: ${_this.bitrateKbps})';
}


}

/// @nodoc
abstract mixin class $PlayGeometryCopyWith<$Res>  {
  factory $PlayGeometryCopyWith(PlayGeometry value, $Res Function(PlayGeometry) _then) = _$PlayGeometryCopyWithImpl;
@useResult
$Res call({
 int? width, int? height, int? frameRate, int? bitrateKbps
});




}
/// @nodoc
class _$PlayGeometryCopyWithImpl<$Res>
    implements $PlayGeometryCopyWith<$Res> {
  _$PlayGeometryCopyWithImpl(this._self, this._then);

  final PlayGeometry _self;
  final $Res Function(PlayGeometry) _then;

/// Create a copy of PlayGeometry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? width = freezed,Object? height = freezed,Object? frameRate = freezed,Object? bitrateKbps = freezed,}) {
  return _then(PlayGeometry(
width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,frameRate: freezed == frameRate ? _self.frameRate : frameRate // ignore: cast_nullable_to_non_nullable
as int?,bitrateKbps: freezed == bitrateKbps ? _self.bitrateKbps : bitrateKbps // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlayGeometry].
extension PlayGeometryPatterns on PlayGeometry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayGeometry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayGeometry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayGeometry value)  $default,){
final _that = this;
switch (_that) {
case _PlayGeometry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayGeometry value)?  $default,){
final _that = this;
switch (_that) {
case _PlayGeometry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? width,  int? height,  int? frameRate,  int? bitrateKbps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayGeometry() when $default != null:
return $default(_that.width,_that.height,_that.frameRate,_that.bitrateKbps);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? width,  int? height,  int? frameRate,  int? bitrateKbps)  $default,) {final _that = this;
switch (_that) {
case _PlayGeometry():
return $default(_that.width,_that.height,_that.frameRate,_that.bitrateKbps);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? width,  int? height,  int? frameRate,  int? bitrateKbps)?  $default,) {final _that = this;
switch (_that) {
case _PlayGeometry() when $default != null:
return $default(_that.width,_that.height,_that.frameRate,_that.bitrateKbps);case _:
  return null;

}
}

}

/// @nodoc


class _PlayGeometry extends PlayGeometry {
  const _PlayGeometry({this.width, this.height, this.frameRate, this.bitrateKbps}): super._();
  

@override final  int? width;
@override final  int? height;
@override final  int? frameRate;
@override final  int? bitrateKbps;

/// Create a copy of PlayGeometry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayGeometryCopyWith<_PlayGeometry> get copyWith => __$PlayGeometryCopyWithImpl<_PlayGeometry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayGeometry&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.frameRate, frameRate) || other.frameRate == frameRate)&&(identical(other.bitrateKbps, bitrateKbps) || other.bitrateKbps == bitrateKbps));
}


@override
int get hashCode {
    return Object.hash(runtimeType,width,height,frameRate,bitrateKbps);
}

@override
String toString() {
    return 'PlayGeometry(width: $width, height: $height, frameRate: $frameRate, bitrateKbps: $bitrateKbps)';
}


}

/// @nodoc
abstract mixin class _$PlayGeometryCopyWith<$Res> implements $PlayGeometryCopyWith<$Res> {
  factory _$PlayGeometryCopyWith(_PlayGeometry value, $Res Function(_PlayGeometry) _then) = __$PlayGeometryCopyWithImpl;
@override @useResult
$Res call({
 int? width, int? height, int? frameRate, int? bitrateKbps
});




}
/// @nodoc
class __$PlayGeometryCopyWithImpl<$Res>
    implements _$PlayGeometryCopyWith<$Res> {
  __$PlayGeometryCopyWithImpl(this._self, this._then);

  final _PlayGeometry _self;
  final $Res Function(_PlayGeometry) _then;

/// Create a copy of PlayGeometry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = freezed,Object? height = freezed,Object? frameRate = freezed,Object? bitrateKbps = freezed,}) {
  return _then(_PlayGeometry(
width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,frameRate: freezed == frameRate ? _self.frameRate : frameRate // ignore: cast_nullable_to_non_nullable
as int?,bitrateKbps: freezed == bitrateKbps ? _self.bitrateKbps : bitrateKbps // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
