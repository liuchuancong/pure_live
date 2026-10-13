// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'style.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Style {

/// Inner space, the CSS `padding`.
 EdgeInsetsGeometry? get padding;/// Outer space, the CSS `margin`.
 EdgeInsetsGeometry? get margin;/// The CSS `min-width`.
 double? get minWidth;/// The CSS `min-height`, usually a control's tap-target height.
 double? get minHeight;/// The CSS `max-width`.
 double? get maxWidth;/// The fill colour, the CSS `background-color`.
 Color? get background;/// The content colour, the CSS `color` (text and icons inherit it).
 Color? get foreground;/// The border colour, the CSS `border-color`.
 Color? get borderColor;/// The border width in logical pixels; 0 draws no border.
 double? get borderWidth;/// The corner radii, the CSS `border-radius`.
 BorderRadius? get borderRadius;/// The whole-surface opacity, the CSS `opacity` (0..1).
 double? get opacity;/// The backdrop blur radius in logical pixels; null or 0 draws no blur.
 double? get blur;/// The drop shadow, the CSS `box-shadow`.
 List<BoxShadow>? get shadow;/// The CSS `font-size`, in logical pixels before the global scale.
 double? get fontSize;/// The CSS `font-family`; the global configuration overrides it when set.
 String? get fontFamily;/// The CSS `font-weight`.
 FontWeight? get fontWeight;/// The CSS `letter-spacing`.
 double? get letterSpacing;/// The CSS `line-height`, as a unitless multiple of the font size.
 double? get lineHeight;/// How a non-text child is aligned inside the box, the flex `align-items`.
 AlignmentGeometry? get alignment;/// The CSS `text-align`.
 TextAlign? get textAlign;
/// Create a copy of Style
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StyleCopyWith<Style> get copyWith => _$StyleCopyWithImpl<Style>(this as Style, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Style;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Style&&(identical(other.padding, _this.padding) || other.padding == _this.padding)&&(identical(other.margin, _this.margin) || other.margin == _this.margin)&&(identical(other.minWidth, _this.minWidth) || other.minWidth == _this.minWidth)&&(identical(other.minHeight, _this.minHeight) || other.minHeight == _this.minHeight)&&(identical(other.maxWidth, _this.maxWidth) || other.maxWidth == _this.maxWidth)&&(identical(other.background, _this.background) || other.background == _this.background)&&(identical(other.foreground, _this.foreground) || other.foreground == _this.foreground)&&(identical(other.borderColor, _this.borderColor) || other.borderColor == _this.borderColor)&&(identical(other.borderWidth, _this.borderWidth) || other.borderWidth == _this.borderWidth)&&(identical(other.borderRadius, _this.borderRadius) || other.borderRadius == _this.borderRadius)&&(identical(other.opacity, _this.opacity) || other.opacity == _this.opacity)&&(identical(other.blur, _this.blur) || other.blur == _this.blur)&&const DeepCollectionEquality().equals(other.shadow, _this.shadow)&&(identical(other.fontSize, _this.fontSize) || other.fontSize == _this.fontSize)&&(identical(other.fontFamily, _this.fontFamily) || other.fontFamily == _this.fontFamily)&&(identical(other.fontWeight, _this.fontWeight) || other.fontWeight == _this.fontWeight)&&(identical(other.letterSpacing, _this.letterSpacing) || other.letterSpacing == _this.letterSpacing)&&(identical(other.lineHeight, _this.lineHeight) || other.lineHeight == _this.lineHeight)&&(identical(other.alignment, _this.alignment) || other.alignment == _this.alignment)&&(identical(other.textAlign, _this.textAlign) || other.textAlign == _this.textAlign));
}


@override
int get hashCode {
  final _this = this as Style;
  return Object.hashAll([runtimeType,_this.padding,_this.margin,_this.minWidth,_this.minHeight,_this.maxWidth,_this.background,_this.foreground,_this.borderColor,_this.borderWidth,_this.borderRadius,_this.opacity,_this.blur,const DeepCollectionEquality().hash(_this.shadow),_this.fontSize,_this.fontFamily,_this.fontWeight,_this.letterSpacing,_this.lineHeight,_this.alignment,_this.textAlign]);
}

@override
String toString() {
  final _this = this as Style;
  return 'Style(padding: ${_this.padding}, margin: ${_this.margin}, minWidth: ${_this.minWidth}, minHeight: ${_this.minHeight}, maxWidth: ${_this.maxWidth}, background: ${_this.background}, foreground: ${_this.foreground}, borderColor: ${_this.borderColor}, borderWidth: ${_this.borderWidth}, borderRadius: ${_this.borderRadius}, opacity: ${_this.opacity}, blur: ${_this.blur}, shadow: ${_this.shadow}, fontSize: ${_this.fontSize}, fontFamily: ${_this.fontFamily}, fontWeight: ${_this.fontWeight}, letterSpacing: ${_this.letterSpacing}, lineHeight: ${_this.lineHeight}, alignment: ${_this.alignment}, textAlign: ${_this.textAlign})';
}


}

/// @nodoc
abstract mixin class $StyleCopyWith<$Res>  {
  factory $StyleCopyWith(Style value, $Res Function(Style) _then) = _$StyleCopyWithImpl;
@useResult
$Res call({
 EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin, double? minWidth, double? minHeight, double? maxWidth, Color? background, Color? foreground, Color? borderColor, double? borderWidth, BorderRadius? borderRadius, double? opacity, double? blur, List<BoxShadow>? shadow, double? fontSize, String? fontFamily, FontWeight? fontWeight, double? letterSpacing, double? lineHeight, AlignmentGeometry? alignment, TextAlign? textAlign
});




}
/// @nodoc
class _$StyleCopyWithImpl<$Res>
    implements $StyleCopyWith<$Res> {
  _$StyleCopyWithImpl(this._self, this._then);

  final Style _self;
  final $Res Function(Style) _then;

/// Create a copy of Style
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? padding = freezed,Object? margin = freezed,Object? minWidth = freezed,Object? minHeight = freezed,Object? maxWidth = freezed,Object? background = freezed,Object? foreground = freezed,Object? borderColor = freezed,Object? borderWidth = freezed,Object? borderRadius = freezed,Object? opacity = freezed,Object? blur = freezed,Object? shadow = freezed,Object? fontSize = freezed,Object? fontFamily = freezed,Object? fontWeight = freezed,Object? letterSpacing = freezed,Object? lineHeight = freezed,Object? alignment = freezed,Object? textAlign = freezed,}) {
  return _then(Style(
padding: freezed == padding ? _self.padding : padding // ignore: cast_nullable_to_non_nullable
as EdgeInsetsGeometry?,margin: freezed == margin ? _self.margin : margin // ignore: cast_nullable_to_non_nullable
as EdgeInsetsGeometry?,minWidth: freezed == minWidth ? _self.minWidth : minWidth // ignore: cast_nullable_to_non_nullable
as double?,minHeight: freezed == minHeight ? _self.minHeight : minHeight // ignore: cast_nullable_to_non_nullable
as double?,maxWidth: freezed == maxWidth ? _self.maxWidth : maxWidth // ignore: cast_nullable_to_non_nullable
as double?,background: freezed == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as Color?,foreground: freezed == foreground ? _self.foreground : foreground // ignore: cast_nullable_to_non_nullable
as Color?,borderColor: freezed == borderColor ? _self.borderColor : borderColor // ignore: cast_nullable_to_non_nullable
as Color?,borderWidth: freezed == borderWidth ? _self.borderWidth : borderWidth // ignore: cast_nullable_to_non_nullable
as double?,borderRadius: freezed == borderRadius ? _self.borderRadius : borderRadius // ignore: cast_nullable_to_non_nullable
as BorderRadius?,opacity: freezed == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double?,blur: freezed == blur ? _self.blur : blur // ignore: cast_nullable_to_non_nullable
as double?,shadow: freezed == shadow ? _self.shadow : shadow // ignore: cast_nullable_to_non_nullable
as List<BoxShadow>?,fontSize: freezed == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double?,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,fontWeight: freezed == fontWeight ? _self.fontWeight : fontWeight // ignore: cast_nullable_to_non_nullable
as FontWeight?,letterSpacing: freezed == letterSpacing ? _self.letterSpacing : letterSpacing // ignore: cast_nullable_to_non_nullable
as double?,lineHeight: freezed == lineHeight ? _self.lineHeight : lineHeight // ignore: cast_nullable_to_non_nullable
as double?,alignment: freezed == alignment ? _self.alignment : alignment // ignore: cast_nullable_to_non_nullable
as AlignmentGeometry?,textAlign: freezed == textAlign ? _self.textAlign : textAlign // ignore: cast_nullable_to_non_nullable
as TextAlign?,
  ));
}

}


/// Adds pattern-matching-related methods to [Style].
extension StylePatterns on Style {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Style value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Style() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Style value)  $default,){
final _that = this;
switch (_that) {
case _Style():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Style value)?  $default,){
final _that = this;
switch (_that) {
case _Style() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( EdgeInsetsGeometry? padding,  EdgeInsetsGeometry? margin,  double? minWidth,  double? minHeight,  double? maxWidth,  Color? background,  Color? foreground,  Color? borderColor,  double? borderWidth,  BorderRadius? borderRadius,  double? opacity,  double? blur,  List<BoxShadow>? shadow,  double? fontSize,  String? fontFamily,  FontWeight? fontWeight,  double? letterSpacing,  double? lineHeight,  AlignmentGeometry? alignment,  TextAlign? textAlign)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Style() when $default != null:
return $default(_that.padding,_that.margin,_that.minWidth,_that.minHeight,_that.maxWidth,_that.background,_that.foreground,_that.borderColor,_that.borderWidth,_that.borderRadius,_that.opacity,_that.blur,_that.shadow,_that.fontSize,_that.fontFamily,_that.fontWeight,_that.letterSpacing,_that.lineHeight,_that.alignment,_that.textAlign);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( EdgeInsetsGeometry? padding,  EdgeInsetsGeometry? margin,  double? minWidth,  double? minHeight,  double? maxWidth,  Color? background,  Color? foreground,  Color? borderColor,  double? borderWidth,  BorderRadius? borderRadius,  double? opacity,  double? blur,  List<BoxShadow>? shadow,  double? fontSize,  String? fontFamily,  FontWeight? fontWeight,  double? letterSpacing,  double? lineHeight,  AlignmentGeometry? alignment,  TextAlign? textAlign)  $default,) {final _that = this;
switch (_that) {
case _Style():
return $default(_that.padding,_that.margin,_that.minWidth,_that.minHeight,_that.maxWidth,_that.background,_that.foreground,_that.borderColor,_that.borderWidth,_that.borderRadius,_that.opacity,_that.blur,_that.shadow,_that.fontSize,_that.fontFamily,_that.fontWeight,_that.letterSpacing,_that.lineHeight,_that.alignment,_that.textAlign);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( EdgeInsetsGeometry? padding,  EdgeInsetsGeometry? margin,  double? minWidth,  double? minHeight,  double? maxWidth,  Color? background,  Color? foreground,  Color? borderColor,  double? borderWidth,  BorderRadius? borderRadius,  double? opacity,  double? blur,  List<BoxShadow>? shadow,  double? fontSize,  String? fontFamily,  FontWeight? fontWeight,  double? letterSpacing,  double? lineHeight,  AlignmentGeometry? alignment,  TextAlign? textAlign)?  $default,) {final _that = this;
switch (_that) {
case _Style() when $default != null:
return $default(_that.padding,_that.margin,_that.minWidth,_that.minHeight,_that.maxWidth,_that.background,_that.foreground,_that.borderColor,_that.borderWidth,_that.borderRadius,_that.opacity,_that.blur,_that.shadow,_that.fontSize,_that.fontFamily,_that.fontWeight,_that.letterSpacing,_that.lineHeight,_that.alignment,_that.textAlign);case _:
  return null;

}
}

}

/// @nodoc


class _Style extends Style {
  const _Style({this.padding, this.margin, this.minWidth, this.minHeight, this.maxWidth, this.background, this.foreground, this.borderColor, this.borderWidth, this.borderRadius, this.opacity, this.blur,  List<BoxShadow>? shadow, this.fontSize, this.fontFamily, this.fontWeight, this.letterSpacing, this.lineHeight, this.alignment, this.textAlign}): _shadow = shadow,super._();
  

/// Inner space, the CSS `padding`.
@override final  EdgeInsetsGeometry? padding;
/// Outer space, the CSS `margin`.
@override final  EdgeInsetsGeometry? margin;
/// The CSS `min-width`.
@override final  double? minWidth;
/// The CSS `min-height`, usually a control's tap-target height.
@override final  double? minHeight;
/// The CSS `max-width`.
@override final  double? maxWidth;
/// The fill colour, the CSS `background-color`.
@override final  Color? background;
/// The content colour, the CSS `color` (text and icons inherit it).
@override final  Color? foreground;
/// The border colour, the CSS `border-color`.
@override final  Color? borderColor;
/// The border width in logical pixels; 0 draws no border.
@override final  double? borderWidth;
/// The corner radii, the CSS `border-radius`.
@override final  BorderRadius? borderRadius;
/// The whole-surface opacity, the CSS `opacity` (0..1).
@override final  double? opacity;
/// The backdrop blur radius in logical pixels; null or 0 draws no blur.
@override final  double? blur;
/// The drop shadow, the CSS `box-shadow`.
 final  List<BoxShadow>? _shadow;
/// The drop shadow, the CSS `box-shadow`.
@override List<BoxShadow>? get shadow {
  final value = _shadow;
  if (value == null) return null;
  if (_shadow is EqualUnmodifiableListView) return _shadow;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// The CSS `font-size`, in logical pixels before the global scale.
@override final  double? fontSize;
/// The CSS `font-family`; the global configuration overrides it when set.
@override final  String? fontFamily;
/// The CSS `font-weight`.
@override final  FontWeight? fontWeight;
/// The CSS `letter-spacing`.
@override final  double? letterSpacing;
/// The CSS `line-height`, as a unitless multiple of the font size.
@override final  double? lineHeight;
/// How a non-text child is aligned inside the box, the flex `align-items`.
@override final  AlignmentGeometry? alignment;
/// The CSS `text-align`.
@override final  TextAlign? textAlign;

/// Create a copy of Style
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StyleCopyWith<_Style> get copyWith => __$StyleCopyWithImpl<_Style>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Style&&(identical(other.padding, padding) || other.padding == padding)&&(identical(other.margin, margin) || other.margin == margin)&&(identical(other.minWidth, minWidth) || other.minWidth == minWidth)&&(identical(other.minHeight, minHeight) || other.minHeight == minHeight)&&(identical(other.maxWidth, maxWidth) || other.maxWidth == maxWidth)&&(identical(other.background, background) || other.background == background)&&(identical(other.foreground, foreground) || other.foreground == foreground)&&(identical(other.borderColor, borderColor) || other.borderColor == borderColor)&&(identical(other.borderWidth, borderWidth) || other.borderWidth == borderWidth)&&(identical(other.borderRadius, borderRadius) || other.borderRadius == borderRadius)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.blur, blur) || other.blur == blur)&&const DeepCollectionEquality().equals(other.shadow, _shadow)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.fontWeight, fontWeight) || other.fontWeight == fontWeight)&&(identical(other.letterSpacing, letterSpacing) || other.letterSpacing == letterSpacing)&&(identical(other.lineHeight, lineHeight) || other.lineHeight == lineHeight)&&(identical(other.alignment, alignment) || other.alignment == alignment)&&(identical(other.textAlign, textAlign) || other.textAlign == textAlign));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,padding,margin,minWidth,minHeight,maxWidth,background,foreground,borderColor,borderWidth,borderRadius,opacity,blur,const DeepCollectionEquality().hash(_shadow),fontSize,fontFamily,fontWeight,letterSpacing,lineHeight,alignment,textAlign]);
}

@override
String toString() {
    return 'Style(padding: $padding, margin: $margin, minWidth: $minWidth, minHeight: $minHeight, maxWidth: $maxWidth, background: $background, foreground: $foreground, borderColor: $borderColor, borderWidth: $borderWidth, borderRadius: $borderRadius, opacity: $opacity, blur: $blur, shadow: $shadow, fontSize: $fontSize, fontFamily: $fontFamily, fontWeight: $fontWeight, letterSpacing: $letterSpacing, lineHeight: $lineHeight, alignment: $alignment, textAlign: $textAlign)';
}


}

/// @nodoc
abstract mixin class _$StyleCopyWith<$Res> implements $StyleCopyWith<$Res> {
  factory _$StyleCopyWith(_Style value, $Res Function(_Style) _then) = __$StyleCopyWithImpl;
@override @useResult
$Res call({
 EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin, double? minWidth, double? minHeight, double? maxWidth, Color? background, Color? foreground, Color? borderColor, double? borderWidth, BorderRadius? borderRadius, double? opacity, double? blur, List<BoxShadow>? shadow, double? fontSize, String? fontFamily, FontWeight? fontWeight, double? letterSpacing, double? lineHeight, AlignmentGeometry? alignment, TextAlign? textAlign
});




}
/// @nodoc
class __$StyleCopyWithImpl<$Res>
    implements _$StyleCopyWith<$Res> {
  __$StyleCopyWithImpl(this._self, this._then);

  final _Style _self;
  final $Res Function(_Style) _then;

/// Create a copy of Style
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? padding = freezed,Object? margin = freezed,Object? minWidth = freezed,Object? minHeight = freezed,Object? maxWidth = freezed,Object? background = freezed,Object? foreground = freezed,Object? borderColor = freezed,Object? borderWidth = freezed,Object? borderRadius = freezed,Object? opacity = freezed,Object? blur = freezed,Object? shadow = freezed,Object? fontSize = freezed,Object? fontFamily = freezed,Object? fontWeight = freezed,Object? letterSpacing = freezed,Object? lineHeight = freezed,Object? alignment = freezed,Object? textAlign = freezed,}) {
  return _then(_Style(
padding: freezed == padding ? _self.padding : padding // ignore: cast_nullable_to_non_nullable
as EdgeInsetsGeometry?,margin: freezed == margin ? _self.margin : margin // ignore: cast_nullable_to_non_nullable
as EdgeInsetsGeometry?,minWidth: freezed == minWidth ? _self.minWidth : minWidth // ignore: cast_nullable_to_non_nullable
as double?,minHeight: freezed == minHeight ? _self.minHeight : minHeight // ignore: cast_nullable_to_non_nullable
as double?,maxWidth: freezed == maxWidth ? _self.maxWidth : maxWidth // ignore: cast_nullable_to_non_nullable
as double?,background: freezed == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as Color?,foreground: freezed == foreground ? _self.foreground : foreground // ignore: cast_nullable_to_non_nullable
as Color?,borderColor: freezed == borderColor ? _self.borderColor : borderColor // ignore: cast_nullable_to_non_nullable
as Color?,borderWidth: freezed == borderWidth ? _self.borderWidth : borderWidth // ignore: cast_nullable_to_non_nullable
as double?,borderRadius: freezed == borderRadius ? _self.borderRadius : borderRadius // ignore: cast_nullable_to_non_nullable
as BorderRadius?,opacity: freezed == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double?,blur: freezed == blur ? _self.blur : blur // ignore: cast_nullable_to_non_nullable
as double?,shadow: freezed == shadow ? _self._shadow : shadow // ignore: cast_nullable_to_non_nullable
as List<BoxShadow>?,fontSize: freezed == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double?,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,fontWeight: freezed == fontWeight ? _self.fontWeight : fontWeight // ignore: cast_nullable_to_non_nullable
as FontWeight?,letterSpacing: freezed == letterSpacing ? _self.letterSpacing : letterSpacing // ignore: cast_nullable_to_non_nullable
as double?,lineHeight: freezed == lineHeight ? _self.lineHeight : lineHeight // ignore: cast_nullable_to_non_nullable
as double?,alignment: freezed == alignment ? _self.alignment : alignment // ignore: cast_nullable_to_non_nullable
as AlignmentGeometry?,textAlign: freezed == textAlign ? _self.textAlign : textAlign // ignore: cast_nullable_to_non_nullable
as TextAlign?,
  ));
}


}

// dart format on
