// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_super_chat_display.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SuperChatDisplay {

 String get backgroundColor; String get backgroundBottomColor;
/// Create a copy of SuperChatDisplay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SuperChatDisplayCopyWith<SuperChatDisplay> get copyWith => _$SuperChatDisplayCopyWithImpl<SuperChatDisplay>(this as SuperChatDisplay, _$identity);

  /// Serializes this SuperChatDisplay to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SuperChatDisplay;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SuperChatDisplay&&(identical(other.backgroundColor, _this.backgroundColor) || other.backgroundColor == _this.backgroundColor)&&(identical(other.backgroundBottomColor, _this.backgroundBottomColor) || other.backgroundBottomColor == _this.backgroundBottomColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SuperChatDisplay;
  return Object.hash(runtimeType,_this.backgroundColor,_this.backgroundBottomColor);
}

@override
String toString() {
  final _this = this as SuperChatDisplay;
  return 'SuperChatDisplay(backgroundColor: ${_this.backgroundColor}, backgroundBottomColor: ${_this.backgroundBottomColor})';
}


}

/// @nodoc
abstract mixin class $SuperChatDisplayCopyWith<$Res>  {
  factory $SuperChatDisplayCopyWith(SuperChatDisplay value, $Res Function(SuperChatDisplay) _then) = _$SuperChatDisplayCopyWithImpl;
@useResult
$Res call({
 String backgroundColor, String backgroundBottomColor
});




}
/// @nodoc
class _$SuperChatDisplayCopyWithImpl<$Res>
    implements $SuperChatDisplayCopyWith<$Res> {
  _$SuperChatDisplayCopyWithImpl(this._self, this._then);

  final SuperChatDisplay _self;
  final $Res Function(SuperChatDisplay) _then;

/// Create a copy of SuperChatDisplay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? backgroundColor = null,Object? backgroundBottomColor = null,}) {
  return _then(SuperChatDisplay(
backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as String,backgroundBottomColor: null == backgroundBottomColor ? _self.backgroundBottomColor : backgroundBottomColor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SuperChatDisplay].
extension SuperChatDisplayPatterns on SuperChatDisplay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SuperChatDisplay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SuperChatDisplay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SuperChatDisplay value)  $default,){
final _that = this;
switch (_that) {
case _SuperChatDisplay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SuperChatDisplay value)?  $default,){
final _that = this;
switch (_that) {
case _SuperChatDisplay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String backgroundColor,  String backgroundBottomColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SuperChatDisplay() when $default != null:
return $default(_that.backgroundColor,_that.backgroundBottomColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String backgroundColor,  String backgroundBottomColor)  $default,) {final _that = this;
switch (_that) {
case _SuperChatDisplay():
return $default(_that.backgroundColor,_that.backgroundBottomColor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String backgroundColor,  String backgroundBottomColor)?  $default,) {final _that = this;
switch (_that) {
case _SuperChatDisplay() when $default != null:
return $default(_that.backgroundColor,_that.backgroundBottomColor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SuperChatDisplay implements SuperChatDisplay {
  const _SuperChatDisplay({this.backgroundColor = '', this.backgroundBottomColor = ''});
  factory _SuperChatDisplay.fromJson(Map<String, dynamic> json) => _$SuperChatDisplayFromJson(json);

@override@JsonKey() final  String backgroundColor;
@override@JsonKey() final  String backgroundBottomColor;

/// Create a copy of SuperChatDisplay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SuperChatDisplayCopyWith<_SuperChatDisplay> get copyWith => __$SuperChatDisplayCopyWithImpl<_SuperChatDisplay>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SuperChatDisplayToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SuperChatDisplay&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.backgroundBottomColor, backgroundBottomColor) || other.backgroundBottomColor == backgroundBottomColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,backgroundColor,backgroundBottomColor);
}

@override
String toString() {
    return 'SuperChatDisplay(backgroundColor: $backgroundColor, backgroundBottomColor: $backgroundBottomColor)';
}


}

/// @nodoc
abstract mixin class _$SuperChatDisplayCopyWith<$Res> implements $SuperChatDisplayCopyWith<$Res> {
  factory _$SuperChatDisplayCopyWith(_SuperChatDisplay value, $Res Function(_SuperChatDisplay) _then) = __$SuperChatDisplayCopyWithImpl;
@override @useResult
$Res call({
 String backgroundColor, String backgroundBottomColor
});




}
/// @nodoc
class __$SuperChatDisplayCopyWithImpl<$Res>
    implements _$SuperChatDisplayCopyWith<$Res> {
  __$SuperChatDisplayCopyWithImpl(this._self, this._then);

  final _SuperChatDisplay _self;
  final $Res Function(_SuperChatDisplay) _then;

/// Create a copy of SuperChatDisplay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? backgroundColor = null,Object? backgroundBottomColor = null,}) {
  return _then(_SuperChatDisplay(
backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as String,backgroundBottomColor: null == backgroundBottomColor ? _self.backgroundBottomColor : backgroundBottomColor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
