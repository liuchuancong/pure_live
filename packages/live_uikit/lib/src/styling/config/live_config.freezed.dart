// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UiConfig {

/// The active design language — which widget library renders the controls.
 LiveDesignLanguage get language;/// The light/dark policy.
 UiBrightnessMode get brightness;/// The brand colour; null keeps Ant's `#1677ff` seed primary.
@ColorConverter() Color? get accent;/// Whether dark surfaces collapse to true black.
 bool get pureBlack;/// The layout density.
 UiDensity get density;/// A global font family override; null keeps the platform default.
 String? get fontFamily;/// A multiplier on every font size — the global "enlarge text" control.
 double get fontScale;/// A multiplier (0..1) on glass/scrim opacity; ignored when
/// [reduceTransparency].
 double get transparency;/// Accessibility: force surfaces opaque and disable backdrop blur.
 bool get reduceTransparency;/// Whether motion runs.
 bool get animations;/// Whether focused controls draw a visible outline.
 bool get focusOutline;
/// Create a copy of UiConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiConfigCopyWith<UiConfig> get copyWith => _$UiConfigCopyWithImpl<UiConfig>(this as UiConfig, _$identity);

  /// Serializes this UiConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UiConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiConfig&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.brightness, _this.brightness) || other.brightness == _this.brightness)&&(identical(other.accent, _this.accent) || other.accent == _this.accent)&&(identical(other.pureBlack, _this.pureBlack) || other.pureBlack == _this.pureBlack)&&(identical(other.density, _this.density) || other.density == _this.density)&&(identical(other.fontFamily, _this.fontFamily) || other.fontFamily == _this.fontFamily)&&(identical(other.fontScale, _this.fontScale) || other.fontScale == _this.fontScale)&&(identical(other.transparency, _this.transparency) || other.transparency == _this.transparency)&&(identical(other.reduceTransparency, _this.reduceTransparency) || other.reduceTransparency == _this.reduceTransparency)&&(identical(other.animations, _this.animations) || other.animations == _this.animations)&&(identical(other.focusOutline, _this.focusOutline) || other.focusOutline == _this.focusOutline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UiConfig;
  return Object.hash(runtimeType,_this.language,_this.brightness,_this.accent,_this.pureBlack,_this.density,_this.fontFamily,_this.fontScale,_this.transparency,_this.reduceTransparency,_this.animations,_this.focusOutline);
}

@override
String toString() {
  final _this = this as UiConfig;
  return 'UiConfig(language: ${_this.language}, brightness: ${_this.brightness}, accent: ${_this.accent}, pureBlack: ${_this.pureBlack}, density: ${_this.density}, fontFamily: ${_this.fontFamily}, fontScale: ${_this.fontScale}, transparency: ${_this.transparency}, reduceTransparency: ${_this.reduceTransparency}, animations: ${_this.animations}, focusOutline: ${_this.focusOutline})';
}


}

/// @nodoc
abstract mixin class $UiConfigCopyWith<$Res>  {
  factory $UiConfigCopyWith(UiConfig value, $Res Function(UiConfig) _then) = _$UiConfigCopyWithImpl;
@useResult
$Res call({
 LiveDesignLanguage language, UiBrightnessMode brightness,@ColorConverter() Color? accent, bool pureBlack, UiDensity density, String? fontFamily, double fontScale, double transparency, bool reduceTransparency, bool animations, bool focusOutline
});




}
/// @nodoc
class _$UiConfigCopyWithImpl<$Res>
    implements $UiConfigCopyWith<$Res> {
  _$UiConfigCopyWithImpl(this._self, this._then);

  final UiConfig _self;
  final $Res Function(UiConfig) _then;

/// Create a copy of UiConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? language = null,Object? brightness = null,Object? accent = freezed,Object? pureBlack = null,Object? density = null,Object? fontFamily = freezed,Object? fontScale = null,Object? transparency = null,Object? reduceTransparency = null,Object? animations = null,Object? focusOutline = null,}) {
  return _then(UiConfig(
language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as LiveDesignLanguage,brightness: null == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as UiBrightnessMode,accent: freezed == accent ? _self.accent : accent // ignore: cast_nullable_to_non_nullable
as Color?,pureBlack: null == pureBlack ? _self.pureBlack : pureBlack // ignore: cast_nullable_to_non_nullable
as bool,density: null == density ? _self.density : density // ignore: cast_nullable_to_non_nullable
as UiDensity,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,fontScale: null == fontScale ? _self.fontScale : fontScale // ignore: cast_nullable_to_non_nullable
as double,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as double,reduceTransparency: null == reduceTransparency ? _self.reduceTransparency : reduceTransparency // ignore: cast_nullable_to_non_nullable
as bool,animations: null == animations ? _self.animations : animations // ignore: cast_nullable_to_non_nullable
as bool,focusOutline: null == focusOutline ? _self.focusOutline : focusOutline // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UiConfig].
extension UiConfigPatterns on UiConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiConfig value)  $default,){
final _that = this;
switch (_that) {
case _UiConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiConfig value)?  $default,){
final _that = this;
switch (_that) {
case _UiConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveDesignLanguage language,  UiBrightnessMode brightness, @ColorConverter()  Color? accent,  bool pureBlack,  UiDensity density,  String? fontFamily,  double fontScale,  double transparency,  bool reduceTransparency,  bool animations,  bool focusOutline)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiConfig() when $default != null:
return $default(_that.language,_that.brightness,_that.accent,_that.pureBlack,_that.density,_that.fontFamily,_that.fontScale,_that.transparency,_that.reduceTransparency,_that.animations,_that.focusOutline);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveDesignLanguage language,  UiBrightnessMode brightness, @ColorConverter()  Color? accent,  bool pureBlack,  UiDensity density,  String? fontFamily,  double fontScale,  double transparency,  bool reduceTransparency,  bool animations,  bool focusOutline)  $default,) {final _that = this;
switch (_that) {
case _UiConfig():
return $default(_that.language,_that.brightness,_that.accent,_that.pureBlack,_that.density,_that.fontFamily,_that.fontScale,_that.transparency,_that.reduceTransparency,_that.animations,_that.focusOutline);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveDesignLanguage language,  UiBrightnessMode brightness, @ColorConverter()  Color? accent,  bool pureBlack,  UiDensity density,  String? fontFamily,  double fontScale,  double transparency,  bool reduceTransparency,  bool animations,  bool focusOutline)?  $default,) {final _that = this;
switch (_that) {
case _UiConfig() when $default != null:
return $default(_that.language,_that.brightness,_that.accent,_that.pureBlack,_that.density,_that.fontFamily,_that.fontScale,_that.transparency,_that.reduceTransparency,_that.animations,_that.focusOutline);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UiConfig extends UiConfig {
  const _UiConfig({this.language = LiveDesignLanguage.material, this.brightness = UiBrightnessMode.system, @ColorConverter() this.accent, this.pureBlack = false, this.density = UiDensity.comfortable, this.fontFamily, this.fontScale = 1.0, this.transparency = 1.0, this.reduceTransparency = false, this.animations = true, this.focusOutline = true}): super._();
  factory _UiConfig.fromJson(Map<String, dynamic> json) => _$UiConfigFromJson(json);

/// The active design language — which widget library renders the controls.
@override@JsonKey() final  LiveDesignLanguage language;
/// The light/dark policy.
@override@JsonKey() final  UiBrightnessMode brightness;
/// The brand colour; null keeps Ant's `#1677ff` seed primary.
@override@ColorConverter() final  Color? accent;
/// Whether dark surfaces collapse to true black.
@override@JsonKey() final  bool pureBlack;
/// The layout density.
@override@JsonKey() final  UiDensity density;
/// A global font family override; null keeps the platform default.
@override final  String? fontFamily;
/// A multiplier on every font size — the global "enlarge text" control.
@override@JsonKey() final  double fontScale;
/// A multiplier (0..1) on glass/scrim opacity; ignored when
/// [reduceTransparency].
@override@JsonKey() final  double transparency;
/// Accessibility: force surfaces opaque and disable backdrop blur.
@override@JsonKey() final  bool reduceTransparency;
/// Whether motion runs.
@override@JsonKey() final  bool animations;
/// Whether focused controls draw a visible outline.
@override@JsonKey() final  bool focusOutline;

/// Create a copy of UiConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiConfigCopyWith<_UiConfig> get copyWith => __$UiConfigCopyWithImpl<_UiConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UiConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiConfig&&(identical(other.language, language) || other.language == language)&&(identical(other.brightness, brightness) || other.brightness == brightness)&&(identical(other.accent, accent) || other.accent == accent)&&(identical(other.pureBlack, pureBlack) || other.pureBlack == pureBlack)&&(identical(other.density, density) || other.density == density)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.fontScale, fontScale) || other.fontScale == fontScale)&&(identical(other.transparency, transparency) || other.transparency == transparency)&&(identical(other.reduceTransparency, reduceTransparency) || other.reduceTransparency == reduceTransparency)&&(identical(other.animations, animations) || other.animations == animations)&&(identical(other.focusOutline, focusOutline) || other.focusOutline == focusOutline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,language,brightness,accent,pureBlack,density,fontFamily,fontScale,transparency,reduceTransparency,animations,focusOutline);
}

@override
String toString() {
    return 'UiConfig(language: $language, brightness: $brightness, accent: $accent, pureBlack: $pureBlack, density: $density, fontFamily: $fontFamily, fontScale: $fontScale, transparency: $transparency, reduceTransparency: $reduceTransparency, animations: $animations, focusOutline: $focusOutline)';
}


}

/// @nodoc
abstract mixin class _$UiConfigCopyWith<$Res> implements $UiConfigCopyWith<$Res> {
  factory _$UiConfigCopyWith(_UiConfig value, $Res Function(_UiConfig) _then) = __$UiConfigCopyWithImpl;
@override @useResult
$Res call({
 LiveDesignLanguage language, UiBrightnessMode brightness,@ColorConverter() Color? accent, bool pureBlack, UiDensity density, String? fontFamily, double fontScale, double transparency, bool reduceTransparency, bool animations, bool focusOutline
});




}
/// @nodoc
class __$UiConfigCopyWithImpl<$Res>
    implements _$UiConfigCopyWith<$Res> {
  __$UiConfigCopyWithImpl(this._self, this._then);

  final _UiConfig _self;
  final $Res Function(_UiConfig) _then;

/// Create a copy of UiConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? language = null,Object? brightness = null,Object? accent = freezed,Object? pureBlack = null,Object? density = null,Object? fontFamily = freezed,Object? fontScale = null,Object? transparency = null,Object? reduceTransparency = null,Object? animations = null,Object? focusOutline = null,}) {
  return _then(_UiConfig(
language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as LiveDesignLanguage,brightness: null == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as UiBrightnessMode,accent: freezed == accent ? _self.accent : accent // ignore: cast_nullable_to_non_nullable
as Color?,pureBlack: null == pureBlack ? _self.pureBlack : pureBlack // ignore: cast_nullable_to_non_nullable
as bool,density: null == density ? _self.density : density // ignore: cast_nullable_to_non_nullable
as UiDensity,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,fontScale: null == fontScale ? _self.fontScale : fontScale // ignore: cast_nullable_to_non_nullable
as double,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as double,reduceTransparency: null == reduceTransparency ? _self.reduceTransparency : reduceTransparency // ignore: cast_nullable_to_non_nullable
as bool,animations: null == animations ? _self.animations : animations // ignore: cast_nullable_to_non_nullable
as bool,focusOutline: null == focusOutline ? _self.focusOutline : focusOutline // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
