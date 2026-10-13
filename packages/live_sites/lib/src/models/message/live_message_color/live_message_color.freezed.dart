// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_message_color.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveMessageColor {

 int get r; int get g; int get b;
/// Create a copy of LiveMessageColor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveMessageColorCopyWith<LiveMessageColor> get copyWith => _$LiveMessageColorCopyWithImpl<LiveMessageColor>(this as LiveMessageColor, _$identity);

  /// Serializes this LiveMessageColor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveMessageColor;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveMessageColor&&(identical(other.r, _this.r) || other.r == _this.r)&&(identical(other.g, _this.g) || other.g == _this.g)&&(identical(other.b, _this.b) || other.b == _this.b));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveMessageColor;
  return Object.hash(runtimeType,_this.r,_this.g,_this.b);
}

@override
String toString() {
  final _this = this as LiveMessageColor;
  return 'LiveMessageColor(r: ${_this.r}, g: ${_this.g}, b: ${_this.b})';
}


}

/// @nodoc
abstract mixin class $LiveMessageColorCopyWith<$Res>  {
  factory $LiveMessageColorCopyWith(LiveMessageColor value, $Res Function(LiveMessageColor) _then) = _$LiveMessageColorCopyWithImpl;
@useResult
$Res call({
 int r, int g, int b
});




}
/// @nodoc
class _$LiveMessageColorCopyWithImpl<$Res>
    implements $LiveMessageColorCopyWith<$Res> {
  _$LiveMessageColorCopyWithImpl(this._self, this._then);

  final LiveMessageColor _self;
  final $Res Function(LiveMessageColor) _then;

/// Create a copy of LiveMessageColor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? r = null,Object? g = null,Object? b = null,}) {
  return _then(LiveMessageColor(
null == r ? _self.r : r // ignore: cast_nullable_to_non_nullable
as int,null == g ? _self.g : g // ignore: cast_nullable_to_non_nullable
as int,null == b ? _self.b : b // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveMessageColor].
extension LiveMessageColorPatterns on LiveMessageColor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveMessageColor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveMessageColor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveMessageColor value)  $default,){
final _that = this;
switch (_that) {
case _LiveMessageColor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveMessageColor value)?  $default,){
final _that = this;
switch (_that) {
case _LiveMessageColor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int r,  int g,  int b)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveMessageColor() when $default != null:
return $default(_that.r,_that.g,_that.b);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int r,  int g,  int b)  $default,) {final _that = this;
switch (_that) {
case _LiveMessageColor():
return $default(_that.r,_that.g,_that.b);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int r,  int g,  int b)?  $default,) {final _that = this;
switch (_that) {
case _LiveMessageColor() when $default != null:
return $default(_that.r,_that.g,_that.b);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveMessageColor implements LiveMessageColor {
  const _LiveMessageColor(this.r, this.g, this.b);
  factory _LiveMessageColor.fromJson(Map<String, dynamic> json) => _$LiveMessageColorFromJson(json);

@override final  int r;
@override final  int g;
@override final  int b;

/// Create a copy of LiveMessageColor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveMessageColorCopyWith<_LiveMessageColor> get copyWith => __$LiveMessageColorCopyWithImpl<_LiveMessageColor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveMessageColorToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveMessageColor&&(identical(other.r, r) || other.r == r)&&(identical(other.g, g) || other.g == g)&&(identical(other.b, b) || other.b == b));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,r,g,b);
}

@override
String toString() {
    return 'LiveMessageColor(r: $r, g: $g, b: $b)';
}


}

/// @nodoc
abstract mixin class _$LiveMessageColorCopyWith<$Res> implements $LiveMessageColorCopyWith<$Res> {
  factory _$LiveMessageColorCopyWith(_LiveMessageColor value, $Res Function(_LiveMessageColor) _then) = __$LiveMessageColorCopyWithImpl;
@override @useResult
$Res call({
 int r, int g, int b
});




}
/// @nodoc
class __$LiveMessageColorCopyWithImpl<$Res>
    implements _$LiveMessageColorCopyWith<$Res> {
  __$LiveMessageColorCopyWithImpl(this._self, this._then);

  final _LiveMessageColor _self;
  final $Res Function(_LiveMessageColor) _then;

/// Create a copy of LiveMessageColor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? r = null,Object? g = null,Object? b = null,}) {
  return _then(_LiveMessageColor(
null == r ? _self.r : r // ignore: cast_nullable_to_non_nullable
as int,null == g ? _self.g : g // ignore: cast_nullable_to_non_nullable
as int,null == b ? _self.b : b // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
