// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'background_style.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PureBackgroundStyle {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PureBackgroundStyle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PureBackgroundStyle()';
}


}

/// @nodoc
class $PureBackgroundStyleCopyWith<$Res>  {
$PureBackgroundStyleCopyWith(PureBackgroundStyle _, $Res Function(PureBackgroundStyle) __);
}


/// Adds pattern-matching-related methods to [PureBackgroundStyle].
extension PureBackgroundStylePatterns on PureBackgroundStyle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PureSolidBackground value)?  solid,TResult Function( PureGradientBackground value)?  gradient,TResult Function( PureImageBackground value)?  image,TResult Function( PureGlassBackground value)?  glass,TResult Function( PureRaisedBackground value)?  raised,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PureSolidBackground() when solid != null:
return solid(_that);case PureGradientBackground() when gradient != null:
return gradient(_that);case PureImageBackground() when image != null:
return image(_that);case PureGlassBackground() when glass != null:
return glass(_that);case PureRaisedBackground() when raised != null:
return raised(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PureSolidBackground value)  solid,required TResult Function( PureGradientBackground value)  gradient,required TResult Function( PureImageBackground value)  image,required TResult Function( PureGlassBackground value)  glass,required TResult Function( PureRaisedBackground value)  raised,}){
final _that = this;
switch (_that) {
case PureSolidBackground():
return solid(_that);case PureGradientBackground():
return gradient(_that);case PureImageBackground():
return image(_that);case PureGlassBackground():
return glass(_that);case PureRaisedBackground():
return raised(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PureSolidBackground value)?  solid,TResult? Function( PureGradientBackground value)?  gradient,TResult? Function( PureImageBackground value)?  image,TResult? Function( PureGlassBackground value)?  glass,TResult? Function( PureRaisedBackground value)?  raised,}){
final _that = this;
switch (_that) {
case PureSolidBackground() when solid != null:
return solid(_that);case PureGradientBackground() when gradient != null:
return gradient(_that);case PureImageBackground() when image != null:
return image(_that);case PureGlassBackground() when glass != null:
return glass(_that);case PureRaisedBackground() when raised != null:
return raised(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Color color)?  solid,TResult Function( List<Color> colors,  Alignment begin,  Alignment end,  List<double> stops,  Color? scrim,  double scrimStrength)?  gradient,TResult Function( ImageProvider<Object> image,  BoxFit fit,  Color? scrim,  double scrimStrength,  double blurSigma)?  image,TResult Function( Color color,  double sigma,  Color? border)?  glass,TResult Function( Color base,  Color light,  Color dark,  double depth)?  raised,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PureSolidBackground() when solid != null:
return solid(_that.color);case PureGradientBackground() when gradient != null:
return gradient(_that.colors,_that.begin,_that.end,_that.stops,_that.scrim,_that.scrimStrength);case PureImageBackground() when image != null:
return image(_that.image,_that.fit,_that.scrim,_that.scrimStrength,_that.blurSigma);case PureGlassBackground() when glass != null:
return glass(_that.color,_that.sigma,_that.border);case PureRaisedBackground() when raised != null:
return raised(_that.base,_that.light,_that.dark,_that.depth);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Color color)  solid,required TResult Function( List<Color> colors,  Alignment begin,  Alignment end,  List<double> stops,  Color? scrim,  double scrimStrength)  gradient,required TResult Function( ImageProvider<Object> image,  BoxFit fit,  Color? scrim,  double scrimStrength,  double blurSigma)  image,required TResult Function( Color color,  double sigma,  Color? border)  glass,required TResult Function( Color base,  Color light,  Color dark,  double depth)  raised,}) {final _that = this;
switch (_that) {
case PureSolidBackground():
return solid(_that.color);case PureGradientBackground():
return gradient(_that.colors,_that.begin,_that.end,_that.stops,_that.scrim,_that.scrimStrength);case PureImageBackground():
return image(_that.image,_that.fit,_that.scrim,_that.scrimStrength,_that.blurSigma);case PureGlassBackground():
return glass(_that.color,_that.sigma,_that.border);case PureRaisedBackground():
return raised(_that.base,_that.light,_that.dark,_that.depth);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Color color)?  solid,TResult? Function( List<Color> colors,  Alignment begin,  Alignment end,  List<double> stops,  Color? scrim,  double scrimStrength)?  gradient,TResult? Function( ImageProvider<Object> image,  BoxFit fit,  Color? scrim,  double scrimStrength,  double blurSigma)?  image,TResult? Function( Color color,  double sigma,  Color? border)?  glass,TResult? Function( Color base,  Color light,  Color dark,  double depth)?  raised,}) {final _that = this;
switch (_that) {
case PureSolidBackground() when solid != null:
return solid(_that.color);case PureGradientBackground() when gradient != null:
return gradient(_that.colors,_that.begin,_that.end,_that.stops,_that.scrim,_that.scrimStrength);case PureImageBackground() when image != null:
return image(_that.image,_that.fit,_that.scrim,_that.scrimStrength,_that.blurSigma);case PureGlassBackground() when glass != null:
return glass(_that.color,_that.sigma,_that.border);case PureRaisedBackground() when raised != null:
return raised(_that.base,_that.light,_that.dark,_that.depth);case _:
  return null;

}
}

}

/// @nodoc


class PureSolidBackground implements PureBackgroundStyle {
  const PureSolidBackground({required this.color});
  

/// The fill colour.
 final  Color color;

/// Create a copy of PureBackgroundStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PureSolidBackgroundCopyWith<PureSolidBackground> get copyWith => _$PureSolidBackgroundCopyWithImpl<PureSolidBackground>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PureSolidBackground&&(identical(other.color, color) || other.color == color));
}


@override
int get hashCode {
    return Object.hash(runtimeType,color);
}

@override
String toString() {
    return 'PureBackgroundStyle.solid(color: $color)';
}


}

/// @nodoc
abstract mixin class $PureSolidBackgroundCopyWith<$Res> implements $PureBackgroundStyleCopyWith<$Res> {
  factory $PureSolidBackgroundCopyWith(PureSolidBackground value, $Res Function(PureSolidBackground) _then) = _$PureSolidBackgroundCopyWithImpl;
@useResult
$Res call({
 Color color
});




}
/// @nodoc
class _$PureSolidBackgroundCopyWithImpl<$Res>
    implements $PureSolidBackgroundCopyWith<$Res> {
  _$PureSolidBackgroundCopyWithImpl(this._self, this._then);

  final PureSolidBackground _self;
  final $Res Function(PureSolidBackground) _then;

/// Create a copy of PureBackgroundStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? color = null,}) {
  return _then(PureSolidBackground(
color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as Color,
  ));
}


}

/// @nodoc


class PureGradientBackground implements PureBackgroundStyle {
  const PureGradientBackground({required  List<Color> colors, this.begin = Alignment.topLeft, this.end = Alignment.bottomRight,  List<double> stops = const <double>[], this.scrim, this.scrimStrength = 0.3}): _colors = colors,_stops = stops;
  

/// The gradient's colours, in order.
 final  List<Color> _colors;
/// The gradient's colours, in order.
 List<Color> get colors {
  if (_colors is EqualUnmodifiableListView) return _colors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_colors);
}

/// Where the gradient starts.
@JsonKey() final  Alignment begin;
/// Where the gradient ends.
@JsonKey() final  Alignment end;
/// Optional stop positions; must match `colors` in length when given.
 final  List<double> _stops;
/// Optional stop positions; must match `colors` in length when given.
@JsonKey() List<double> get stops {
  if (_stops is EqualUnmodifiableListView) return _stops;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stops);
}

/// A translucent colour painted over the gradient; null paints none.
 final  Color? scrim;
/// How strongly `scrim` is applied, 0..1.
@JsonKey() final  double scrimStrength;

/// Create a copy of PureBackgroundStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PureGradientBackgroundCopyWith<PureGradientBackground> get copyWith => _$PureGradientBackgroundCopyWithImpl<PureGradientBackground>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PureGradientBackground&&const DeepCollectionEquality().equals(other.colors, _colors)&&(identical(other.begin, begin) || other.begin == begin)&&(identical(other.end, end) || other.end == end)&&const DeepCollectionEquality().equals(other.stops, _stops)&&(identical(other.scrim, scrim) || other.scrim == scrim)&&(identical(other.scrimStrength, scrimStrength) || other.scrimStrength == scrimStrength));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_colors),begin,end,const DeepCollectionEquality().hash(_stops),scrim,scrimStrength);
}

@override
String toString() {
    return 'PureBackgroundStyle.gradient(colors: $colors, begin: $begin, end: $end, stops: $stops, scrim: $scrim, scrimStrength: $scrimStrength)';
}


}

/// @nodoc
abstract mixin class $PureGradientBackgroundCopyWith<$Res> implements $PureBackgroundStyleCopyWith<$Res> {
  factory $PureGradientBackgroundCopyWith(PureGradientBackground value, $Res Function(PureGradientBackground) _then) = _$PureGradientBackgroundCopyWithImpl;
@useResult
$Res call({
 List<Color> colors, Alignment begin, Alignment end, List<double> stops, Color? scrim, double scrimStrength
});




}
/// @nodoc
class _$PureGradientBackgroundCopyWithImpl<$Res>
    implements $PureGradientBackgroundCopyWith<$Res> {
  _$PureGradientBackgroundCopyWithImpl(this._self, this._then);

  final PureGradientBackground _self;
  final $Res Function(PureGradientBackground) _then;

/// Create a copy of PureBackgroundStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? colors = null,Object? begin = null,Object? end = null,Object? stops = null,Object? scrim = freezed,Object? scrimStrength = null,}) {
  return _then(PureGradientBackground(
colors: null == colors ? _self._colors : colors // ignore: cast_nullable_to_non_nullable
as List<Color>,begin: null == begin ? _self.begin : begin // ignore: cast_nullable_to_non_nullable
as Alignment,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Alignment,stops: null == stops ? _self._stops : stops // ignore: cast_nullable_to_non_nullable
as List<double>,scrim: freezed == scrim ? _self.scrim : scrim // ignore: cast_nullable_to_non_nullable
as Color?,scrimStrength: null == scrimStrength ? _self.scrimStrength : scrimStrength // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class PureImageBackground implements PureBackgroundStyle {
  const PureImageBackground({required this.image, this.fit = BoxFit.cover, this.scrim, this.scrimStrength = 0.45, this.blurSigma = 0});
  

/// The image to paint.
 final  ImageProvider<Object> image;
/// How the image fills the surface.
@JsonKey() final  BoxFit fit;
/// A translucent colour painted over the image; null paints none.
 final  Color? scrim;
/// How strongly `scrim` is applied, 0..1.
@JsonKey() final  double scrimStrength;
/// The blur radius over the image; 0 keeps it sharp. Ignored when the
/// resolved theme reports a backdrop filter is not affordable.
@JsonKey() final  double blurSigma;

/// Create a copy of PureBackgroundStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PureImageBackgroundCopyWith<PureImageBackground> get copyWith => _$PureImageBackgroundCopyWithImpl<PureImageBackground>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PureImageBackground&&(identical(other.image, image) || other.image == image)&&(identical(other.fit, fit) || other.fit == fit)&&(identical(other.scrim, scrim) || other.scrim == scrim)&&(identical(other.scrimStrength, scrimStrength) || other.scrimStrength == scrimStrength)&&(identical(other.blurSigma, blurSigma) || other.blurSigma == blurSigma));
}


@override
int get hashCode {
    return Object.hash(runtimeType,image,fit,scrim,scrimStrength,blurSigma);
}

@override
String toString() {
    return 'PureBackgroundStyle.image(image: $image, fit: $fit, scrim: $scrim, scrimStrength: $scrimStrength, blurSigma: $blurSigma)';
}


}

/// @nodoc
abstract mixin class $PureImageBackgroundCopyWith<$Res> implements $PureBackgroundStyleCopyWith<$Res> {
  factory $PureImageBackgroundCopyWith(PureImageBackground value, $Res Function(PureImageBackground) _then) = _$PureImageBackgroundCopyWithImpl;
@useResult
$Res call({
 ImageProvider<Object> image, BoxFit fit, Color? scrim, double scrimStrength, double blurSigma
});




}
/// @nodoc
class _$PureImageBackgroundCopyWithImpl<$Res>
    implements $PureImageBackgroundCopyWith<$Res> {
  _$PureImageBackgroundCopyWithImpl(this._self, this._then);

  final PureImageBackground _self;
  final $Res Function(PureImageBackground) _then;

/// Create a copy of PureBackgroundStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? image = null,Object? fit = null,Object? scrim = freezed,Object? scrimStrength = null,Object? blurSigma = null,}) {
  return _then(PureImageBackground(
image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as ImageProvider<Object>,fit: null == fit ? _self.fit : fit // ignore: cast_nullable_to_non_nullable
as BoxFit,scrim: freezed == scrim ? _self.scrim : scrim // ignore: cast_nullable_to_non_nullable
as Color?,scrimStrength: null == scrimStrength ? _self.scrimStrength : scrimStrength // ignore: cast_nullable_to_non_nullable
as double,blurSigma: null == blurSigma ? _self.blurSigma : blurSigma // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class PureGlassBackground implements PureBackgroundStyle {
  const PureGlassBackground({required this.color, this.sigma = 16, this.border});
  

/// The translucent fill colour.
 final  Color color;
/// The backdrop blur radius.
@JsonKey() final  double sigma;
/// An optional hairline border colour.
 final  Color? border;

/// Create a copy of PureBackgroundStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PureGlassBackgroundCopyWith<PureGlassBackground> get copyWith => _$PureGlassBackgroundCopyWithImpl<PureGlassBackground>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PureGlassBackground&&(identical(other.color, color) || other.color == color)&&(identical(other.sigma, sigma) || other.sigma == sigma)&&(identical(other.border, border) || other.border == border));
}


@override
int get hashCode {
    return Object.hash(runtimeType,color,sigma,border);
}

@override
String toString() {
    return 'PureBackgroundStyle.glass(color: $color, sigma: $sigma, border: $border)';
}


}

/// @nodoc
abstract mixin class $PureGlassBackgroundCopyWith<$Res> implements $PureBackgroundStyleCopyWith<$Res> {
  factory $PureGlassBackgroundCopyWith(PureGlassBackground value, $Res Function(PureGlassBackground) _then) = _$PureGlassBackgroundCopyWithImpl;
@useResult
$Res call({
 Color color, double sigma, Color? border
});




}
/// @nodoc
class _$PureGlassBackgroundCopyWithImpl<$Res>
    implements $PureGlassBackgroundCopyWith<$Res> {
  _$PureGlassBackgroundCopyWithImpl(this._self, this._then);

  final PureGlassBackground _self;
  final $Res Function(PureGlassBackground) _then;

/// Create a copy of PureBackgroundStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? color = null,Object? sigma = null,Object? border = freezed,}) {
  return _then(PureGlassBackground(
color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as Color,sigma: null == sigma ? _self.sigma : sigma // ignore: cast_nullable_to_non_nullable
as double,border: freezed == border ? _self.border : border // ignore: cast_nullable_to_non_nullable
as Color?,
  ));
}


}

/// @nodoc


class PureRaisedBackground implements PureBackgroundStyle {
  const PureRaisedBackground({required this.base, required this.light, required this.dark, this.depth = 6});
  

/// The base fill.
 final  Color base;
/// The highlight colour (the light source).
 final  Color light;
/// The shadow colour.
 final  Color dark;
/// How far the surface appears to stand out.
@JsonKey() final  double depth;

/// Create a copy of PureBackgroundStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PureRaisedBackgroundCopyWith<PureRaisedBackground> get copyWith => _$PureRaisedBackgroundCopyWithImpl<PureRaisedBackground>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PureRaisedBackground&&(identical(other.base, base) || other.base == base)&&(identical(other.light, light) || other.light == light)&&(identical(other.dark, dark) || other.dark == dark)&&(identical(other.depth, depth) || other.depth == depth));
}


@override
int get hashCode {
    return Object.hash(runtimeType,base,light,dark,depth);
}

@override
String toString() {
    return 'PureBackgroundStyle.raised(base: $base, light: $light, dark: $dark, depth: $depth)';
}


}

/// @nodoc
abstract mixin class $PureRaisedBackgroundCopyWith<$Res> implements $PureBackgroundStyleCopyWith<$Res> {
  factory $PureRaisedBackgroundCopyWith(PureRaisedBackground value, $Res Function(PureRaisedBackground) _then) = _$PureRaisedBackgroundCopyWithImpl;
@useResult
$Res call({
 Color base, Color light, Color dark, double depth
});




}
/// @nodoc
class _$PureRaisedBackgroundCopyWithImpl<$Res>
    implements $PureRaisedBackgroundCopyWith<$Res> {
  _$PureRaisedBackgroundCopyWithImpl(this._self, this._then);

  final PureRaisedBackground _self;
  final $Res Function(PureRaisedBackground) _then;

/// Create a copy of PureBackgroundStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? base = null,Object? light = null,Object? dark = null,Object? depth = null,}) {
  return _then(PureRaisedBackground(
base: null == base ? _self.base : base // ignore: cast_nullable_to_non_nullable
as Color,light: null == light ? _self.light : light // ignore: cast_nullable_to_non_nullable
as Color,dark: null == dark ? _self.dark : dark // ignore: cast_nullable_to_non_nullable
as Color,depth: null == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
