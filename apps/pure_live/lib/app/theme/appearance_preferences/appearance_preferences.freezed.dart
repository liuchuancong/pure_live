// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'appearance_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppearancePreferences {

/// The design language registry id; empty means the platform's default.
 String get designLanguageId;/// Which brightness the app follows.
 AppThemeMode get themeMode;/// The accent colour as a 32-bit ARGB value; null means the design
/// language's own accent.
 int? get accentColor;/// Whether dark surfaces are drawn pure black, for OLED screens.
 bool get pureBlack;/// The layout density registry id; empty means the default density.
 String get densityId;/// A global multiplier on every font size (the "enlarge text" control).
 double get fontScale;/// A global font family override; null keeps the platform default.
 String? get fontFamily;/// A multiplier (0..1) on glass/scrim opacity.
 double get transparency;/// Accessibility: force surfaces opaque and disable backdrop blur.
 bool get reduceTransparency;/// Whether motion runs.
 bool get animations;/// Whether focused controls draw a visible outline.
 bool get focusOutline;
/// Create a copy of AppearancePreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppearancePreferencesCopyWith<AppearancePreferences> get copyWith => _$AppearancePreferencesCopyWithImpl<AppearancePreferences>(this as AppearancePreferences, _$identity);

  /// Serializes this AppearancePreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AppearancePreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppearancePreferences&&(identical(other.designLanguageId, _this.designLanguageId) || other.designLanguageId == _this.designLanguageId)&&(identical(other.themeMode, _this.themeMode) || other.themeMode == _this.themeMode)&&(identical(other.accentColor, _this.accentColor) || other.accentColor == _this.accentColor)&&(identical(other.pureBlack, _this.pureBlack) || other.pureBlack == _this.pureBlack)&&(identical(other.densityId, _this.densityId) || other.densityId == _this.densityId)&&(identical(other.fontScale, _this.fontScale) || other.fontScale == _this.fontScale)&&(identical(other.fontFamily, _this.fontFamily) || other.fontFamily == _this.fontFamily)&&(identical(other.transparency, _this.transparency) || other.transparency == _this.transparency)&&(identical(other.reduceTransparency, _this.reduceTransparency) || other.reduceTransparency == _this.reduceTransparency)&&(identical(other.animations, _this.animations) || other.animations == _this.animations)&&(identical(other.focusOutline, _this.focusOutline) || other.focusOutline == _this.focusOutline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AppearancePreferences;
  return Object.hash(runtimeType,_this.designLanguageId,_this.themeMode,_this.accentColor,_this.pureBlack,_this.densityId,_this.fontScale,_this.fontFamily,_this.transparency,_this.reduceTransparency,_this.animations,_this.focusOutline);
}

@override
String toString() {
  final _this = this as AppearancePreferences;
  return 'AppearancePreferences(designLanguageId: ${_this.designLanguageId}, themeMode: ${_this.themeMode}, accentColor: ${_this.accentColor}, pureBlack: ${_this.pureBlack}, densityId: ${_this.densityId}, fontScale: ${_this.fontScale}, fontFamily: ${_this.fontFamily}, transparency: ${_this.transparency}, reduceTransparency: ${_this.reduceTransparency}, animations: ${_this.animations}, focusOutline: ${_this.focusOutline})';
}


}

/// @nodoc
abstract mixin class $AppearancePreferencesCopyWith<$Res>  {
  factory $AppearancePreferencesCopyWith(AppearancePreferences value, $Res Function(AppearancePreferences) _then) = _$AppearancePreferencesCopyWithImpl;
@useResult
$Res call({
 String designLanguageId, AppThemeMode themeMode, int? accentColor, bool pureBlack, String densityId, double fontScale, String? fontFamily, double transparency, bool reduceTransparency, bool animations, bool focusOutline
});




}
/// @nodoc
class _$AppearancePreferencesCopyWithImpl<$Res>
    implements $AppearancePreferencesCopyWith<$Res> {
  _$AppearancePreferencesCopyWithImpl(this._self, this._then);

  final AppearancePreferences _self;
  final $Res Function(AppearancePreferences) _then;

/// Create a copy of AppearancePreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? designLanguageId = null,Object? themeMode = null,Object? accentColor = freezed,Object? pureBlack = null,Object? densityId = null,Object? fontScale = null,Object? fontFamily = freezed,Object? transparency = null,Object? reduceTransparency = null,Object? animations = null,Object? focusOutline = null,}) {
  return _then(AppearancePreferences(
designLanguageId: null == designLanguageId ? _self.designLanguageId : designLanguageId // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,accentColor: freezed == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as int?,pureBlack: null == pureBlack ? _self.pureBlack : pureBlack // ignore: cast_nullable_to_non_nullable
as bool,densityId: null == densityId ? _self.densityId : densityId // ignore: cast_nullable_to_non_nullable
as String,fontScale: null == fontScale ? _self.fontScale : fontScale // ignore: cast_nullable_to_non_nullable
as double,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as double,reduceTransparency: null == reduceTransparency ? _self.reduceTransparency : reduceTransparency // ignore: cast_nullable_to_non_nullable
as bool,animations: null == animations ? _self.animations : animations // ignore: cast_nullable_to_non_nullable
as bool,focusOutline: null == focusOutline ? _self.focusOutline : focusOutline // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppearancePreferences].
extension AppearancePreferencesPatterns on AppearancePreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppearancePreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppearancePreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppearancePreferences value)  $default,){
final _that = this;
switch (_that) {
case _AppearancePreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppearancePreferences value)?  $default,){
final _that = this;
switch (_that) {
case _AppearancePreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String designLanguageId,  AppThemeMode themeMode,  int? accentColor,  bool pureBlack,  String densityId,  double fontScale,  String? fontFamily,  double transparency,  bool reduceTransparency,  bool animations,  bool focusOutline)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppearancePreferences() when $default != null:
return $default(_that.designLanguageId,_that.themeMode,_that.accentColor,_that.pureBlack,_that.densityId,_that.fontScale,_that.fontFamily,_that.transparency,_that.reduceTransparency,_that.animations,_that.focusOutline);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String designLanguageId,  AppThemeMode themeMode,  int? accentColor,  bool pureBlack,  String densityId,  double fontScale,  String? fontFamily,  double transparency,  bool reduceTransparency,  bool animations,  bool focusOutline)  $default,) {final _that = this;
switch (_that) {
case _AppearancePreferences():
return $default(_that.designLanguageId,_that.themeMode,_that.accentColor,_that.pureBlack,_that.densityId,_that.fontScale,_that.fontFamily,_that.transparency,_that.reduceTransparency,_that.animations,_that.focusOutline);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String designLanguageId,  AppThemeMode themeMode,  int? accentColor,  bool pureBlack,  String densityId,  double fontScale,  String? fontFamily,  double transparency,  bool reduceTransparency,  bool animations,  bool focusOutline)?  $default,) {final _that = this;
switch (_that) {
case _AppearancePreferences() when $default != null:
return $default(_that.designLanguageId,_that.themeMode,_that.accentColor,_that.pureBlack,_that.densityId,_that.fontScale,_that.fontFamily,_that.transparency,_that.reduceTransparency,_that.animations,_that.focusOutline);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppearancePreferences implements AppearancePreferences {
  const _AppearancePreferences({this.designLanguageId = '', this.themeMode = AppThemeMode.system, this.accentColor, this.pureBlack = false, this.densityId = '', this.fontScale = 1.0, this.fontFamily, this.transparency = 1.0, this.reduceTransparency = false, this.animations = true, this.focusOutline = true});
  factory _AppearancePreferences.fromJson(Map<String, dynamic> json) => _$AppearancePreferencesFromJson(json);

/// The design language registry id; empty means the platform's default.
@override@JsonKey() final  String designLanguageId;
/// Which brightness the app follows.
@override@JsonKey() final  AppThemeMode themeMode;
/// The accent colour as a 32-bit ARGB value; null means the design
/// language's own accent.
@override final  int? accentColor;
/// Whether dark surfaces are drawn pure black, for OLED screens.
@override@JsonKey() final  bool pureBlack;
/// The layout density registry id; empty means the default density.
@override@JsonKey() final  String densityId;
/// A global multiplier on every font size (the "enlarge text" control).
@override@JsonKey() final  double fontScale;
/// A global font family override; null keeps the platform default.
@override final  String? fontFamily;
/// A multiplier (0..1) on glass/scrim opacity.
@override@JsonKey() final  double transparency;
/// Accessibility: force surfaces opaque and disable backdrop blur.
@override@JsonKey() final  bool reduceTransparency;
/// Whether motion runs.
@override@JsonKey() final  bool animations;
/// Whether focused controls draw a visible outline.
@override@JsonKey() final  bool focusOutline;

/// Create a copy of AppearancePreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppearancePreferencesCopyWith<_AppearancePreferences> get copyWith => __$AppearancePreferencesCopyWithImpl<_AppearancePreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppearancePreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppearancePreferences&&(identical(other.designLanguageId, designLanguageId) || other.designLanguageId == designLanguageId)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.accentColor, accentColor) || other.accentColor == accentColor)&&(identical(other.pureBlack, pureBlack) || other.pureBlack == pureBlack)&&(identical(other.densityId, densityId) || other.densityId == densityId)&&(identical(other.fontScale, fontScale) || other.fontScale == fontScale)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.transparency, transparency) || other.transparency == transparency)&&(identical(other.reduceTransparency, reduceTransparency) || other.reduceTransparency == reduceTransparency)&&(identical(other.animations, animations) || other.animations == animations)&&(identical(other.focusOutline, focusOutline) || other.focusOutline == focusOutline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,designLanguageId,themeMode,accentColor,pureBlack,densityId,fontScale,fontFamily,transparency,reduceTransparency,animations,focusOutline);
}

@override
String toString() {
    return 'AppearancePreferences(designLanguageId: $designLanguageId, themeMode: $themeMode, accentColor: $accentColor, pureBlack: $pureBlack, densityId: $densityId, fontScale: $fontScale, fontFamily: $fontFamily, transparency: $transparency, reduceTransparency: $reduceTransparency, animations: $animations, focusOutline: $focusOutline)';
}


}

/// @nodoc
abstract mixin class _$AppearancePreferencesCopyWith<$Res> implements $AppearancePreferencesCopyWith<$Res> {
  factory _$AppearancePreferencesCopyWith(_AppearancePreferences value, $Res Function(_AppearancePreferences) _then) = __$AppearancePreferencesCopyWithImpl;
@override @useResult
$Res call({
 String designLanguageId, AppThemeMode themeMode, int? accentColor, bool pureBlack, String densityId, double fontScale, String? fontFamily, double transparency, bool reduceTransparency, bool animations, bool focusOutline
});




}
/// @nodoc
class __$AppearancePreferencesCopyWithImpl<$Res>
    implements _$AppearancePreferencesCopyWith<$Res> {
  __$AppearancePreferencesCopyWithImpl(this._self, this._then);

  final _AppearancePreferences _self;
  final $Res Function(_AppearancePreferences) _then;

/// Create a copy of AppearancePreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? designLanguageId = null,Object? themeMode = null,Object? accentColor = freezed,Object? pureBlack = null,Object? densityId = null,Object? fontScale = null,Object? fontFamily = freezed,Object? transparency = null,Object? reduceTransparency = null,Object? animations = null,Object? focusOutline = null,}) {
  return _then(_AppearancePreferences(
designLanguageId: null == designLanguageId ? _self.designLanguageId : designLanguageId // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,accentColor: freezed == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as int?,pureBlack: null == pureBlack ? _self.pureBlack : pureBlack // ignore: cast_nullable_to_non_nullable
as bool,densityId: null == densityId ? _self.densityId : densityId // ignore: cast_nullable_to_non_nullable
as String,fontScale: null == fontScale ? _self.fontScale : fontScale // ignore: cast_nullable_to_non_nullable
as double,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as double,reduceTransparency: null == reduceTransparency ? _self.reduceTransparency : reduceTransparency // ignore: cast_nullable_to_non_nullable
as bool,animations: null == animations ? _self.animations : animations // ignore: cast_nullable_to_non_nullable
as bool,focusOutline: null == focusOutline ? _self.focusOutline : focusOutline // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
