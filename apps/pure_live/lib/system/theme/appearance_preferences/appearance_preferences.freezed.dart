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

/// The design language registry id; empty means the build's default
/// skin (fluent), which `ui_configuration_mapper.dart` resolves.
 String get designLanguageId;/// Which brightness the app follows.
 AppThemeMode get themeMode;/// The accent colour as a 32-bit ARGB value; null means the design
/// language's own accent.
 int? get accentColor;/// Whether dark surfaces are drawn pure black, for OLED screens.
 bool get pureBlack;/// Whether the accent follows the system's wallpaper colours (Android
/// 12+); other platforms report none and keep their own accent.
 bool get dynamicColor;/// The layout density registry id; empty means the default density.
 String get densityId;/// A global multiplier on every font size (the "enlarge text" control).
 double get fontScale;/// Absolute pixel sizes for the five adjustable text roles; null keeps
/// the design language's own size (the fine-tuning page writes these).
 double? get bodySmallSize; double? get bodySize; double? get subtitleSize; double? get titleSize; double? get headlineSize;/// The global font family: `theme` follows the design language's
/// recommendation (`font_recommendations.dart`), empty is the system
/// default, anything else is a downloaded or imported family id.
 String get fontFamily;/// A multiplier (0..1) on glass/scrim opacity.
 double get transparency;/// Accessibility: force surfaces opaque and disable backdrop blur.
 bool get reduceTransparency;/// Whether motion runs.
 bool get animations;/// Whether focused controls draw a visible outline.
 bool get focusOutline;/// What the wallpaper layer paints behind the pages.
 WallpaperKind get wallpaperKind;/// The solid wallpaper colour as a 32-bit ARGB value; read when
/// [WallpaperKind.solid].
 int? get wallpaperColor;/// The gradient stops as 32-bit ARGB values, in order; two or more when
/// [WallpaperKind.gradient]. Stored as colours rather than a catalog id,
/// so a preset being renamed or removed never breaks a stored choice.
 List<int> get wallpaperGradientColors;/// The gradient direction as a CSS angle (0 points up, clockwise
/// positive); the wallpaper feature converts it to alignments.
 int get wallpaperGradientAngle;/// The gradient stop positions, aligned with
/// [wallpaperGradientColors]; empty spaces them evenly.
 List<double> get wallpaperGradientStops;/// The wallpaper picture's absolute path; read when
/// [WallpaperKind.image]. A path that no longer exists degrades the
/// wallpaper to none at resolve time.
 String get wallpaperImagePath;/// How the wallpaper picture fills the surface, as a `BoxFit` name
/// (`cover`, `contain` or `fill`); anything else resolves to cover.
 String get wallpaperFit;/// The Gaussian blur over the wallpaper picture, 0..20.
 double get wallpaperBlur;/// How strongly the wallpaper picture is dimmed for legibility, 0..1.
 double get wallpaperScrim;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppearancePreferences&&(identical(other.designLanguageId, _this.designLanguageId) || other.designLanguageId == _this.designLanguageId)&&(identical(other.themeMode, _this.themeMode) || other.themeMode == _this.themeMode)&&(identical(other.accentColor, _this.accentColor) || other.accentColor == _this.accentColor)&&(identical(other.pureBlack, _this.pureBlack) || other.pureBlack == _this.pureBlack)&&(identical(other.dynamicColor, _this.dynamicColor) || other.dynamicColor == _this.dynamicColor)&&(identical(other.densityId, _this.densityId) || other.densityId == _this.densityId)&&(identical(other.fontScale, _this.fontScale) || other.fontScale == _this.fontScale)&&(identical(other.bodySmallSize, _this.bodySmallSize) || other.bodySmallSize == _this.bodySmallSize)&&(identical(other.bodySize, _this.bodySize) || other.bodySize == _this.bodySize)&&(identical(other.subtitleSize, _this.subtitleSize) || other.subtitleSize == _this.subtitleSize)&&(identical(other.titleSize, _this.titleSize) || other.titleSize == _this.titleSize)&&(identical(other.headlineSize, _this.headlineSize) || other.headlineSize == _this.headlineSize)&&(identical(other.fontFamily, _this.fontFamily) || other.fontFamily == _this.fontFamily)&&(identical(other.transparency, _this.transparency) || other.transparency == _this.transparency)&&(identical(other.reduceTransparency, _this.reduceTransparency) || other.reduceTransparency == _this.reduceTransparency)&&(identical(other.animations, _this.animations) || other.animations == _this.animations)&&(identical(other.focusOutline, _this.focusOutline) || other.focusOutline == _this.focusOutline)&&(identical(other.wallpaperKind, _this.wallpaperKind) || other.wallpaperKind == _this.wallpaperKind)&&(identical(other.wallpaperColor, _this.wallpaperColor) || other.wallpaperColor == _this.wallpaperColor)&&const DeepCollectionEquality().equals(other.wallpaperGradientColors, _this.wallpaperGradientColors)&&(identical(other.wallpaperGradientAngle, _this.wallpaperGradientAngle) || other.wallpaperGradientAngle == _this.wallpaperGradientAngle)&&const DeepCollectionEquality().equals(other.wallpaperGradientStops, _this.wallpaperGradientStops)&&(identical(other.wallpaperImagePath, _this.wallpaperImagePath) || other.wallpaperImagePath == _this.wallpaperImagePath)&&(identical(other.wallpaperFit, _this.wallpaperFit) || other.wallpaperFit == _this.wallpaperFit)&&(identical(other.wallpaperBlur, _this.wallpaperBlur) || other.wallpaperBlur == _this.wallpaperBlur)&&(identical(other.wallpaperScrim, _this.wallpaperScrim) || other.wallpaperScrim == _this.wallpaperScrim));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AppearancePreferences;
  return Object.hashAll([runtimeType,_this.designLanguageId,_this.themeMode,_this.accentColor,_this.pureBlack,_this.dynamicColor,_this.densityId,_this.fontScale,_this.bodySmallSize,_this.bodySize,_this.subtitleSize,_this.titleSize,_this.headlineSize,_this.fontFamily,_this.transparency,_this.reduceTransparency,_this.animations,_this.focusOutline,_this.wallpaperKind,_this.wallpaperColor,const DeepCollectionEquality().hash(_this.wallpaperGradientColors),_this.wallpaperGradientAngle,const DeepCollectionEquality().hash(_this.wallpaperGradientStops),_this.wallpaperImagePath,_this.wallpaperFit,_this.wallpaperBlur,_this.wallpaperScrim]);
}

@override
String toString() {
  final _this = this as AppearancePreferences;
  return 'AppearancePreferences(designLanguageId: ${_this.designLanguageId}, themeMode: ${_this.themeMode}, accentColor: ${_this.accentColor}, pureBlack: ${_this.pureBlack}, dynamicColor: ${_this.dynamicColor}, densityId: ${_this.densityId}, fontScale: ${_this.fontScale}, bodySmallSize: ${_this.bodySmallSize}, bodySize: ${_this.bodySize}, subtitleSize: ${_this.subtitleSize}, titleSize: ${_this.titleSize}, headlineSize: ${_this.headlineSize}, fontFamily: ${_this.fontFamily}, transparency: ${_this.transparency}, reduceTransparency: ${_this.reduceTransparency}, animations: ${_this.animations}, focusOutline: ${_this.focusOutline}, wallpaperKind: ${_this.wallpaperKind}, wallpaperColor: ${_this.wallpaperColor}, wallpaperGradientColors: ${_this.wallpaperGradientColors}, wallpaperGradientAngle: ${_this.wallpaperGradientAngle}, wallpaperGradientStops: ${_this.wallpaperGradientStops}, wallpaperImagePath: ${_this.wallpaperImagePath}, wallpaperFit: ${_this.wallpaperFit}, wallpaperBlur: ${_this.wallpaperBlur}, wallpaperScrim: ${_this.wallpaperScrim})';
}


}

/// @nodoc
abstract mixin class $AppearancePreferencesCopyWith<$Res>  {
  factory $AppearancePreferencesCopyWith(AppearancePreferences value, $Res Function(AppearancePreferences) _then) = _$AppearancePreferencesCopyWithImpl;
@useResult
$Res call({
 String designLanguageId, AppThemeMode themeMode, int? accentColor, bool pureBlack, bool dynamicColor, String densityId, double fontScale, double? bodySmallSize, double? bodySize, double? subtitleSize, double? titleSize, double? headlineSize, String fontFamily, double transparency, bool reduceTransparency, bool animations, bool focusOutline, WallpaperKind wallpaperKind, int? wallpaperColor, List<int> wallpaperGradientColors, int wallpaperGradientAngle, List<double> wallpaperGradientStops, String wallpaperImagePath, String wallpaperFit, double wallpaperBlur, double wallpaperScrim
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
@pragma('vm:prefer-inline') @override $Res call({Object? designLanguageId = null,Object? themeMode = null,Object? accentColor = freezed,Object? pureBlack = null,Object? dynamicColor = null,Object? densityId = null,Object? fontScale = null,Object? bodySmallSize = freezed,Object? bodySize = freezed,Object? subtitleSize = freezed,Object? titleSize = freezed,Object? headlineSize = freezed,Object? fontFamily = null,Object? transparency = null,Object? reduceTransparency = null,Object? animations = null,Object? focusOutline = null,Object? wallpaperKind = null,Object? wallpaperColor = freezed,Object? wallpaperGradientColors = null,Object? wallpaperGradientAngle = null,Object? wallpaperGradientStops = null,Object? wallpaperImagePath = null,Object? wallpaperFit = null,Object? wallpaperBlur = null,Object? wallpaperScrim = null,}) {
  return _then(AppearancePreferences(
designLanguageId: null == designLanguageId ? _self.designLanguageId : designLanguageId // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,accentColor: freezed == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as int?,pureBlack: null == pureBlack ? _self.pureBlack : pureBlack // ignore: cast_nullable_to_non_nullable
as bool,dynamicColor: null == dynamicColor ? _self.dynamicColor : dynamicColor // ignore: cast_nullable_to_non_nullable
as bool,densityId: null == densityId ? _self.densityId : densityId // ignore: cast_nullable_to_non_nullable
as String,fontScale: null == fontScale ? _self.fontScale : fontScale // ignore: cast_nullable_to_non_nullable
as double,bodySmallSize: freezed == bodySmallSize ? _self.bodySmallSize : bodySmallSize // ignore: cast_nullable_to_non_nullable
as double?,bodySize: freezed == bodySize ? _self.bodySize : bodySize // ignore: cast_nullable_to_non_nullable
as double?,subtitleSize: freezed == subtitleSize ? _self.subtitleSize : subtitleSize // ignore: cast_nullable_to_non_nullable
as double?,titleSize: freezed == titleSize ? _self.titleSize : titleSize // ignore: cast_nullable_to_non_nullable
as double?,headlineSize: freezed == headlineSize ? _self.headlineSize : headlineSize // ignore: cast_nullable_to_non_nullable
as double?,fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as double,reduceTransparency: null == reduceTransparency ? _self.reduceTransparency : reduceTransparency // ignore: cast_nullable_to_non_nullable
as bool,animations: null == animations ? _self.animations : animations // ignore: cast_nullable_to_non_nullable
as bool,focusOutline: null == focusOutline ? _self.focusOutline : focusOutline // ignore: cast_nullable_to_non_nullable
as bool,wallpaperKind: null == wallpaperKind ? _self.wallpaperKind : wallpaperKind // ignore: cast_nullable_to_non_nullable
as WallpaperKind,wallpaperColor: freezed == wallpaperColor ? _self.wallpaperColor : wallpaperColor // ignore: cast_nullable_to_non_nullable
as int?,wallpaperGradientColors: null == wallpaperGradientColors ? _self.wallpaperGradientColors : wallpaperGradientColors // ignore: cast_nullable_to_non_nullable
as List<int>,wallpaperGradientAngle: null == wallpaperGradientAngle ? _self.wallpaperGradientAngle : wallpaperGradientAngle // ignore: cast_nullable_to_non_nullable
as int,wallpaperGradientStops: null == wallpaperGradientStops ? _self.wallpaperGradientStops : wallpaperGradientStops // ignore: cast_nullable_to_non_nullable
as List<double>,wallpaperImagePath: null == wallpaperImagePath ? _self.wallpaperImagePath : wallpaperImagePath // ignore: cast_nullable_to_non_nullable
as String,wallpaperFit: null == wallpaperFit ? _self.wallpaperFit : wallpaperFit // ignore: cast_nullable_to_non_nullable
as String,wallpaperBlur: null == wallpaperBlur ? _self.wallpaperBlur : wallpaperBlur // ignore: cast_nullable_to_non_nullable
as double,wallpaperScrim: null == wallpaperScrim ? _self.wallpaperScrim : wallpaperScrim // ignore: cast_nullable_to_non_nullable
as double,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String designLanguageId,  AppThemeMode themeMode,  int? accentColor,  bool pureBlack,  bool dynamicColor,  String densityId,  double fontScale,  double? bodySmallSize,  double? bodySize,  double? subtitleSize,  double? titleSize,  double? headlineSize,  String fontFamily,  double transparency,  bool reduceTransparency,  bool animations,  bool focusOutline,  WallpaperKind wallpaperKind,  int? wallpaperColor,  List<int> wallpaperGradientColors,  int wallpaperGradientAngle,  List<double> wallpaperGradientStops,  String wallpaperImagePath,  String wallpaperFit,  double wallpaperBlur,  double wallpaperScrim)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppearancePreferences() when $default != null:
return $default(_that.designLanguageId,_that.themeMode,_that.accentColor,_that.pureBlack,_that.dynamicColor,_that.densityId,_that.fontScale,_that.bodySmallSize,_that.bodySize,_that.subtitleSize,_that.titleSize,_that.headlineSize,_that.fontFamily,_that.transparency,_that.reduceTransparency,_that.animations,_that.focusOutline,_that.wallpaperKind,_that.wallpaperColor,_that.wallpaperGradientColors,_that.wallpaperGradientAngle,_that.wallpaperGradientStops,_that.wallpaperImagePath,_that.wallpaperFit,_that.wallpaperBlur,_that.wallpaperScrim);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String designLanguageId,  AppThemeMode themeMode,  int? accentColor,  bool pureBlack,  bool dynamicColor,  String densityId,  double fontScale,  double? bodySmallSize,  double? bodySize,  double? subtitleSize,  double? titleSize,  double? headlineSize,  String fontFamily,  double transparency,  bool reduceTransparency,  bool animations,  bool focusOutline,  WallpaperKind wallpaperKind,  int? wallpaperColor,  List<int> wallpaperGradientColors,  int wallpaperGradientAngle,  List<double> wallpaperGradientStops,  String wallpaperImagePath,  String wallpaperFit,  double wallpaperBlur,  double wallpaperScrim)  $default,) {final _that = this;
switch (_that) {
case _AppearancePreferences():
return $default(_that.designLanguageId,_that.themeMode,_that.accentColor,_that.pureBlack,_that.dynamicColor,_that.densityId,_that.fontScale,_that.bodySmallSize,_that.bodySize,_that.subtitleSize,_that.titleSize,_that.headlineSize,_that.fontFamily,_that.transparency,_that.reduceTransparency,_that.animations,_that.focusOutline,_that.wallpaperKind,_that.wallpaperColor,_that.wallpaperGradientColors,_that.wallpaperGradientAngle,_that.wallpaperGradientStops,_that.wallpaperImagePath,_that.wallpaperFit,_that.wallpaperBlur,_that.wallpaperScrim);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String designLanguageId,  AppThemeMode themeMode,  int? accentColor,  bool pureBlack,  bool dynamicColor,  String densityId,  double fontScale,  double? bodySmallSize,  double? bodySize,  double? subtitleSize,  double? titleSize,  double? headlineSize,  String fontFamily,  double transparency,  bool reduceTransparency,  bool animations,  bool focusOutline,  WallpaperKind wallpaperKind,  int? wallpaperColor,  List<int> wallpaperGradientColors,  int wallpaperGradientAngle,  List<double> wallpaperGradientStops,  String wallpaperImagePath,  String wallpaperFit,  double wallpaperBlur,  double wallpaperScrim)?  $default,) {final _that = this;
switch (_that) {
case _AppearancePreferences() when $default != null:
return $default(_that.designLanguageId,_that.themeMode,_that.accentColor,_that.pureBlack,_that.dynamicColor,_that.densityId,_that.fontScale,_that.bodySmallSize,_that.bodySize,_that.subtitleSize,_that.titleSize,_that.headlineSize,_that.fontFamily,_that.transparency,_that.reduceTransparency,_that.animations,_that.focusOutline,_that.wallpaperKind,_that.wallpaperColor,_that.wallpaperGradientColors,_that.wallpaperGradientAngle,_that.wallpaperGradientStops,_that.wallpaperImagePath,_that.wallpaperFit,_that.wallpaperBlur,_that.wallpaperScrim);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppearancePreferences implements AppearancePreferences {
  const _AppearancePreferences({this.designLanguageId = '', this.themeMode = AppThemeMode.system, this.accentColor, this.pureBlack = false, this.dynamicColor = false, this.densityId = '', this.fontScale = 1.0, this.bodySmallSize, this.bodySize, this.subtitleSize, this.titleSize, this.headlineSize, this.fontFamily = kThemeFontFamily, this.transparency = 1.0, this.reduceTransparency = false, this.animations = true, this.focusOutline = true, this.wallpaperKind = WallpaperKind.none, this.wallpaperColor,  List<int> wallpaperGradientColors = const <int>[], this.wallpaperGradientAngle = 0,  List<double> wallpaperGradientStops = const <double>[], this.wallpaperImagePath = '', this.wallpaperFit = 'cover', this.wallpaperBlur = 0.0, this.wallpaperScrim = 0.35}): _wallpaperGradientColors = wallpaperGradientColors,_wallpaperGradientStops = wallpaperGradientStops;
  factory _AppearancePreferences.fromJson(Map<String, dynamic> json) => _$AppearancePreferencesFromJson(json);

/// The design language registry id; empty means the build's default
/// skin (fluent), which `ui_configuration_mapper.dart` resolves.
@override@JsonKey() final  String designLanguageId;
/// Which brightness the app follows.
@override@JsonKey() final  AppThemeMode themeMode;
/// The accent colour as a 32-bit ARGB value; null means the design
/// language's own accent.
@override final  int? accentColor;
/// Whether dark surfaces are drawn pure black, for OLED screens.
@override@JsonKey() final  bool pureBlack;
/// Whether the accent follows the system's wallpaper colours (Android
/// 12+); other platforms report none and keep their own accent.
@override@JsonKey() final  bool dynamicColor;
/// The layout density registry id; empty means the default density.
@override@JsonKey() final  String densityId;
/// A global multiplier on every font size (the "enlarge text" control).
@override@JsonKey() final  double fontScale;
/// Absolute pixel sizes for the five adjustable text roles; null keeps
/// the design language's own size (the fine-tuning page writes these).
@override final  double? bodySmallSize;
@override final  double? bodySize;
@override final  double? subtitleSize;
@override final  double? titleSize;
@override final  double? headlineSize;
/// The global font family: `theme` follows the design language's
/// recommendation (`font_recommendations.dart`), empty is the system
/// default, anything else is a downloaded or imported family id.
@override@JsonKey() final  String fontFamily;
/// A multiplier (0..1) on glass/scrim opacity.
@override@JsonKey() final  double transparency;
/// Accessibility: force surfaces opaque and disable backdrop blur.
@override@JsonKey() final  bool reduceTransparency;
/// Whether motion runs.
@override@JsonKey() final  bool animations;
/// Whether focused controls draw a visible outline.
@override@JsonKey() final  bool focusOutline;
/// What the wallpaper layer paints behind the pages.
@override@JsonKey() final  WallpaperKind wallpaperKind;
/// The solid wallpaper colour as a 32-bit ARGB value; read when
/// [WallpaperKind.solid].
@override final  int? wallpaperColor;
/// The gradient stops as 32-bit ARGB values, in order; two or more when
/// [WallpaperKind.gradient]. Stored as colours rather than a catalog id,
/// so a preset being renamed or removed never breaks a stored choice.
 final  List<int> _wallpaperGradientColors;
/// The gradient stops as 32-bit ARGB values, in order; two or more when
/// [WallpaperKind.gradient]. Stored as colours rather than a catalog id,
/// so a preset being renamed or removed never breaks a stored choice.
@override@JsonKey() List<int> get wallpaperGradientColors {
  if (_wallpaperGradientColors is EqualUnmodifiableListView) return _wallpaperGradientColors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_wallpaperGradientColors);
}

/// The gradient direction as a CSS angle (0 points up, clockwise
/// positive); the wallpaper feature converts it to alignments.
@override@JsonKey() final  int wallpaperGradientAngle;
/// The gradient stop positions, aligned with
/// [wallpaperGradientColors]; empty spaces them evenly.
 final  List<double> _wallpaperGradientStops;
/// The gradient stop positions, aligned with
/// [wallpaperGradientColors]; empty spaces them evenly.
@override@JsonKey() List<double> get wallpaperGradientStops {
  if (_wallpaperGradientStops is EqualUnmodifiableListView) return _wallpaperGradientStops;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_wallpaperGradientStops);
}

/// The wallpaper picture's absolute path; read when
/// [WallpaperKind.image]. A path that no longer exists degrades the
/// wallpaper to none at resolve time.
@override@JsonKey() final  String wallpaperImagePath;
/// How the wallpaper picture fills the surface, as a `BoxFit` name
/// (`cover`, `contain` or `fill`); anything else resolves to cover.
@override@JsonKey() final  String wallpaperFit;
/// The Gaussian blur over the wallpaper picture, 0..20.
@override@JsonKey() final  double wallpaperBlur;
/// How strongly the wallpaper picture is dimmed for legibility, 0..1.
@override@JsonKey() final  double wallpaperScrim;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppearancePreferences&&(identical(other.designLanguageId, designLanguageId) || other.designLanguageId == designLanguageId)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.accentColor, accentColor) || other.accentColor == accentColor)&&(identical(other.pureBlack, pureBlack) || other.pureBlack == pureBlack)&&(identical(other.dynamicColor, dynamicColor) || other.dynamicColor == dynamicColor)&&(identical(other.densityId, densityId) || other.densityId == densityId)&&(identical(other.fontScale, fontScale) || other.fontScale == fontScale)&&(identical(other.bodySmallSize, bodySmallSize) || other.bodySmallSize == bodySmallSize)&&(identical(other.bodySize, bodySize) || other.bodySize == bodySize)&&(identical(other.subtitleSize, subtitleSize) || other.subtitleSize == subtitleSize)&&(identical(other.titleSize, titleSize) || other.titleSize == titleSize)&&(identical(other.headlineSize, headlineSize) || other.headlineSize == headlineSize)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.transparency, transparency) || other.transparency == transparency)&&(identical(other.reduceTransparency, reduceTransparency) || other.reduceTransparency == reduceTransparency)&&(identical(other.animations, animations) || other.animations == animations)&&(identical(other.focusOutline, focusOutline) || other.focusOutline == focusOutline)&&(identical(other.wallpaperKind, wallpaperKind) || other.wallpaperKind == wallpaperKind)&&(identical(other.wallpaperColor, wallpaperColor) || other.wallpaperColor == wallpaperColor)&&const DeepCollectionEquality().equals(other.wallpaperGradientColors, _wallpaperGradientColors)&&(identical(other.wallpaperGradientAngle, wallpaperGradientAngle) || other.wallpaperGradientAngle == wallpaperGradientAngle)&&const DeepCollectionEquality().equals(other.wallpaperGradientStops, _wallpaperGradientStops)&&(identical(other.wallpaperImagePath, wallpaperImagePath) || other.wallpaperImagePath == wallpaperImagePath)&&(identical(other.wallpaperFit, wallpaperFit) || other.wallpaperFit == wallpaperFit)&&(identical(other.wallpaperBlur, wallpaperBlur) || other.wallpaperBlur == wallpaperBlur)&&(identical(other.wallpaperScrim, wallpaperScrim) || other.wallpaperScrim == wallpaperScrim));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,designLanguageId,themeMode,accentColor,pureBlack,dynamicColor,densityId,fontScale,bodySmallSize,bodySize,subtitleSize,titleSize,headlineSize,fontFamily,transparency,reduceTransparency,animations,focusOutline,wallpaperKind,wallpaperColor,const DeepCollectionEquality().hash(_wallpaperGradientColors),wallpaperGradientAngle,const DeepCollectionEquality().hash(_wallpaperGradientStops),wallpaperImagePath,wallpaperFit,wallpaperBlur,wallpaperScrim]);
}

@override
String toString() {
    return 'AppearancePreferences(designLanguageId: $designLanguageId, themeMode: $themeMode, accentColor: $accentColor, pureBlack: $pureBlack, dynamicColor: $dynamicColor, densityId: $densityId, fontScale: $fontScale, bodySmallSize: $bodySmallSize, bodySize: $bodySize, subtitleSize: $subtitleSize, titleSize: $titleSize, headlineSize: $headlineSize, fontFamily: $fontFamily, transparency: $transparency, reduceTransparency: $reduceTransparency, animations: $animations, focusOutline: $focusOutline, wallpaperKind: $wallpaperKind, wallpaperColor: $wallpaperColor, wallpaperGradientColors: $wallpaperGradientColors, wallpaperGradientAngle: $wallpaperGradientAngle, wallpaperGradientStops: $wallpaperGradientStops, wallpaperImagePath: $wallpaperImagePath, wallpaperFit: $wallpaperFit, wallpaperBlur: $wallpaperBlur, wallpaperScrim: $wallpaperScrim)';
}


}

/// @nodoc
abstract mixin class _$AppearancePreferencesCopyWith<$Res> implements $AppearancePreferencesCopyWith<$Res> {
  factory _$AppearancePreferencesCopyWith(_AppearancePreferences value, $Res Function(_AppearancePreferences) _then) = __$AppearancePreferencesCopyWithImpl;
@override @useResult
$Res call({
 String designLanguageId, AppThemeMode themeMode, int? accentColor, bool pureBlack, bool dynamicColor, String densityId, double fontScale, double? bodySmallSize, double? bodySize, double? subtitleSize, double? titleSize, double? headlineSize, String fontFamily, double transparency, bool reduceTransparency, bool animations, bool focusOutline, WallpaperKind wallpaperKind, int? wallpaperColor, List<int> wallpaperGradientColors, int wallpaperGradientAngle, List<double> wallpaperGradientStops, String wallpaperImagePath, String wallpaperFit, double wallpaperBlur, double wallpaperScrim
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
@override @pragma('vm:prefer-inline') $Res call({Object? designLanguageId = null,Object? themeMode = null,Object? accentColor = freezed,Object? pureBlack = null,Object? dynamicColor = null,Object? densityId = null,Object? fontScale = null,Object? bodySmallSize = freezed,Object? bodySize = freezed,Object? subtitleSize = freezed,Object? titleSize = freezed,Object? headlineSize = freezed,Object? fontFamily = null,Object? transparency = null,Object? reduceTransparency = null,Object? animations = null,Object? focusOutline = null,Object? wallpaperKind = null,Object? wallpaperColor = freezed,Object? wallpaperGradientColors = null,Object? wallpaperGradientAngle = null,Object? wallpaperGradientStops = null,Object? wallpaperImagePath = null,Object? wallpaperFit = null,Object? wallpaperBlur = null,Object? wallpaperScrim = null,}) {
  return _then(_AppearancePreferences(
designLanguageId: null == designLanguageId ? _self.designLanguageId : designLanguageId // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,accentColor: freezed == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as int?,pureBlack: null == pureBlack ? _self.pureBlack : pureBlack // ignore: cast_nullable_to_non_nullable
as bool,dynamicColor: null == dynamicColor ? _self.dynamicColor : dynamicColor // ignore: cast_nullable_to_non_nullable
as bool,densityId: null == densityId ? _self.densityId : densityId // ignore: cast_nullable_to_non_nullable
as String,fontScale: null == fontScale ? _self.fontScale : fontScale // ignore: cast_nullable_to_non_nullable
as double,bodySmallSize: freezed == bodySmallSize ? _self.bodySmallSize : bodySmallSize // ignore: cast_nullable_to_non_nullable
as double?,bodySize: freezed == bodySize ? _self.bodySize : bodySize // ignore: cast_nullable_to_non_nullable
as double?,subtitleSize: freezed == subtitleSize ? _self.subtitleSize : subtitleSize // ignore: cast_nullable_to_non_nullable
as double?,titleSize: freezed == titleSize ? _self.titleSize : titleSize // ignore: cast_nullable_to_non_nullable
as double?,headlineSize: freezed == headlineSize ? _self.headlineSize : headlineSize // ignore: cast_nullable_to_non_nullable
as double?,fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as double,reduceTransparency: null == reduceTransparency ? _self.reduceTransparency : reduceTransparency // ignore: cast_nullable_to_non_nullable
as bool,animations: null == animations ? _self.animations : animations // ignore: cast_nullable_to_non_nullable
as bool,focusOutline: null == focusOutline ? _self.focusOutline : focusOutline // ignore: cast_nullable_to_non_nullable
as bool,wallpaperKind: null == wallpaperKind ? _self.wallpaperKind : wallpaperKind // ignore: cast_nullable_to_non_nullable
as WallpaperKind,wallpaperColor: freezed == wallpaperColor ? _self.wallpaperColor : wallpaperColor // ignore: cast_nullable_to_non_nullable
as int?,wallpaperGradientColors: null == wallpaperGradientColors ? _self._wallpaperGradientColors : wallpaperGradientColors // ignore: cast_nullable_to_non_nullable
as List<int>,wallpaperGradientAngle: null == wallpaperGradientAngle ? _self.wallpaperGradientAngle : wallpaperGradientAngle // ignore: cast_nullable_to_non_nullable
as int,wallpaperGradientStops: null == wallpaperGradientStops ? _self._wallpaperGradientStops : wallpaperGradientStops // ignore: cast_nullable_to_non_nullable
as List<double>,wallpaperImagePath: null == wallpaperImagePath ? _self.wallpaperImagePath : wallpaperImagePath // ignore: cast_nullable_to_non_nullable
as String,wallpaperFit: null == wallpaperFit ? _self.wallpaperFit : wallpaperFit // ignore: cast_nullable_to_non_nullable
as String,wallpaperBlur: null == wallpaperBlur ? _self.wallpaperBlur : wallpaperBlur // ignore: cast_nullable_to_non_nullable
as double,wallpaperScrim: null == wallpaperScrim ? _self.wallpaperScrim : wallpaperScrim // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
