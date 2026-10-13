// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'danmaku_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DanmakuPreferences {

/// Whether the danmaku overlay is on.
 bool get enabled;/// The overlay opacity, 0..1.
 double get opacity;/// The font size scale, 0.5..2.
 double get fontScale;/// The share of the picture's height the danmaku may use (rows are
/// laid out from the top within this band), 0.1..1.
 double get area;
/// Create a copy of DanmakuPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DanmakuPreferencesCopyWith<DanmakuPreferences> get copyWith => _$DanmakuPreferencesCopyWithImpl<DanmakuPreferences>(this as DanmakuPreferences, _$identity);

  /// Serializes this DanmakuPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DanmakuPreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DanmakuPreferences&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.opacity, _this.opacity) || other.opacity == _this.opacity)&&(identical(other.fontScale, _this.fontScale) || other.fontScale == _this.fontScale)&&(identical(other.area, _this.area) || other.area == _this.area));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DanmakuPreferences;
  return Object.hash(runtimeType,_this.enabled,_this.opacity,_this.fontScale,_this.area);
}

@override
String toString() {
  final _this = this as DanmakuPreferences;
  return 'DanmakuPreferences(enabled: ${_this.enabled}, opacity: ${_this.opacity}, fontScale: ${_this.fontScale}, area: ${_this.area})';
}


}

/// @nodoc
abstract mixin class $DanmakuPreferencesCopyWith<$Res>  {
  factory $DanmakuPreferencesCopyWith(DanmakuPreferences value, $Res Function(DanmakuPreferences) _then) = _$DanmakuPreferencesCopyWithImpl;
@useResult
$Res call({
 bool enabled, double opacity, double fontScale, double area
});




}
/// @nodoc
class _$DanmakuPreferencesCopyWithImpl<$Res>
    implements $DanmakuPreferencesCopyWith<$Res> {
  _$DanmakuPreferencesCopyWithImpl(this._self, this._then);

  final DanmakuPreferences _self;
  final $Res Function(DanmakuPreferences) _then;

/// Create a copy of DanmakuPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? opacity = null,Object? fontScale = null,Object? area = null,}) {
  return _then(DanmakuPreferences(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,fontScale: null == fontScale ? _self.fontScale : fontScale // ignore: cast_nullable_to_non_nullable
as double,area: null == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [DanmakuPreferences].
extension DanmakuPreferencesPatterns on DanmakuPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DanmakuPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DanmakuPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DanmakuPreferences value)  $default,){
final _that = this;
switch (_that) {
case _DanmakuPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DanmakuPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _DanmakuPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  double opacity,  double fontScale,  double area)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DanmakuPreferences() when $default != null:
return $default(_that.enabled,_that.opacity,_that.fontScale,_that.area);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  double opacity,  double fontScale,  double area)  $default,) {final _that = this;
switch (_that) {
case _DanmakuPreferences():
return $default(_that.enabled,_that.opacity,_that.fontScale,_that.area);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  double opacity,  double fontScale,  double area)?  $default,) {final _that = this;
switch (_that) {
case _DanmakuPreferences() when $default != null:
return $default(_that.enabled,_that.opacity,_that.fontScale,_that.area);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DanmakuPreferences implements DanmakuPreferences {
  const _DanmakuPreferences({this.enabled = true, this.opacity = 1, this.fontScale = 1, this.area = 1});
  factory _DanmakuPreferences.fromJson(Map<String, dynamic> json) => _$DanmakuPreferencesFromJson(json);

/// Whether the danmaku overlay is on.
@override@JsonKey() final  bool enabled;
/// The overlay opacity, 0..1.
@override@JsonKey() final  double opacity;
/// The font size scale, 0.5..2.
@override@JsonKey() final  double fontScale;
/// The share of the picture's height the danmaku may use (rows are
/// laid out from the top within this band), 0.1..1.
@override@JsonKey() final  double area;

/// Create a copy of DanmakuPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DanmakuPreferencesCopyWith<_DanmakuPreferences> get copyWith => __$DanmakuPreferencesCopyWithImpl<_DanmakuPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DanmakuPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DanmakuPreferences&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.fontScale, fontScale) || other.fontScale == fontScale)&&(identical(other.area, area) || other.area == area));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,enabled,opacity,fontScale,area);
}

@override
String toString() {
    return 'DanmakuPreferences(enabled: $enabled, opacity: $opacity, fontScale: $fontScale, area: $area)';
}


}

/// @nodoc
abstract mixin class _$DanmakuPreferencesCopyWith<$Res> implements $DanmakuPreferencesCopyWith<$Res> {
  factory _$DanmakuPreferencesCopyWith(_DanmakuPreferences value, $Res Function(_DanmakuPreferences) _then) = __$DanmakuPreferencesCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, double opacity, double fontScale, double area
});




}
/// @nodoc
class __$DanmakuPreferencesCopyWithImpl<$Res>
    implements _$DanmakuPreferencesCopyWith<$Res> {
  __$DanmakuPreferencesCopyWithImpl(this._self, this._then);

  final _DanmakuPreferences _self;
  final $Res Function(_DanmakuPreferences) _then;

/// Create a copy of DanmakuPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? opacity = null,Object? fontScale = null,Object? area = null,}) {
  return _then(_DanmakuPreferences(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,fontScale: null == fontScale ? _self.fontScale : fontScale // ignore: cast_nullable_to_non_nullable
as double,area: null == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
