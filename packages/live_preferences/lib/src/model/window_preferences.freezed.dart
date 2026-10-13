// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'window_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WindowPreferences {

/// Whether leaving the app opens the floating window with the playing
/// room.
 bool get floatOnLeave;/// Whether closing the floating window pauses the room instead of
/// stopping it.
 bool get pauseOnClose;/// Whether the floating window stays above other windows.
 bool get alwaysOnTop;/// The floating window's size as a share of the source video's size,
/// 0.1..1.
 double get scale;
/// Create a copy of WindowPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WindowPreferencesCopyWith<WindowPreferences> get copyWith => _$WindowPreferencesCopyWithImpl<WindowPreferences>(this as WindowPreferences, _$identity);

  /// Serializes this WindowPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WindowPreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WindowPreferences&&(identical(other.floatOnLeave, _this.floatOnLeave) || other.floatOnLeave == _this.floatOnLeave)&&(identical(other.pauseOnClose, _this.pauseOnClose) || other.pauseOnClose == _this.pauseOnClose)&&(identical(other.alwaysOnTop, _this.alwaysOnTop) || other.alwaysOnTop == _this.alwaysOnTop)&&(identical(other.scale, _this.scale) || other.scale == _this.scale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WindowPreferences;
  return Object.hash(runtimeType,_this.floatOnLeave,_this.pauseOnClose,_this.alwaysOnTop,_this.scale);
}

@override
String toString() {
  final _this = this as WindowPreferences;
  return 'WindowPreferences(floatOnLeave: ${_this.floatOnLeave}, pauseOnClose: ${_this.pauseOnClose}, alwaysOnTop: ${_this.alwaysOnTop}, scale: ${_this.scale})';
}


}

/// @nodoc
abstract mixin class $WindowPreferencesCopyWith<$Res>  {
  factory $WindowPreferencesCopyWith(WindowPreferences value, $Res Function(WindowPreferences) _then) = _$WindowPreferencesCopyWithImpl;
@useResult
$Res call({
 bool floatOnLeave, bool pauseOnClose, bool alwaysOnTop, double scale
});




}
/// @nodoc
class _$WindowPreferencesCopyWithImpl<$Res>
    implements $WindowPreferencesCopyWith<$Res> {
  _$WindowPreferencesCopyWithImpl(this._self, this._then);

  final WindowPreferences _self;
  final $Res Function(WindowPreferences) _then;

/// Create a copy of WindowPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? floatOnLeave = null,Object? pauseOnClose = null,Object? alwaysOnTop = null,Object? scale = null,}) {
  return _then(WindowPreferences(
floatOnLeave: null == floatOnLeave ? _self.floatOnLeave : floatOnLeave // ignore: cast_nullable_to_non_nullable
as bool,pauseOnClose: null == pauseOnClose ? _self.pauseOnClose : pauseOnClose // ignore: cast_nullable_to_non_nullable
as bool,alwaysOnTop: null == alwaysOnTop ? _self.alwaysOnTop : alwaysOnTop // ignore: cast_nullable_to_non_nullable
as bool,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [WindowPreferences].
extension WindowPreferencesPatterns on WindowPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WindowPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WindowPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WindowPreferences value)  $default,){
final _that = this;
switch (_that) {
case _WindowPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WindowPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _WindowPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool floatOnLeave,  bool pauseOnClose,  bool alwaysOnTop,  double scale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WindowPreferences() when $default != null:
return $default(_that.floatOnLeave,_that.pauseOnClose,_that.alwaysOnTop,_that.scale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool floatOnLeave,  bool pauseOnClose,  bool alwaysOnTop,  double scale)  $default,) {final _that = this;
switch (_that) {
case _WindowPreferences():
return $default(_that.floatOnLeave,_that.pauseOnClose,_that.alwaysOnTop,_that.scale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool floatOnLeave,  bool pauseOnClose,  bool alwaysOnTop,  double scale)?  $default,) {final _that = this;
switch (_that) {
case _WindowPreferences() when $default != null:
return $default(_that.floatOnLeave,_that.pauseOnClose,_that.alwaysOnTop,_that.scale);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WindowPreferences implements WindowPreferences {
  const _WindowPreferences({this.floatOnLeave = false, this.pauseOnClose = false, this.alwaysOnTop = false, this.scale = 0.4});
  factory _WindowPreferences.fromJson(Map<String, dynamic> json) => _$WindowPreferencesFromJson(json);

/// Whether leaving the app opens the floating window with the playing
/// room.
@override@JsonKey() final  bool floatOnLeave;
/// Whether closing the floating window pauses the room instead of
/// stopping it.
@override@JsonKey() final  bool pauseOnClose;
/// Whether the floating window stays above other windows.
@override@JsonKey() final  bool alwaysOnTop;
/// The floating window's size as a share of the source video's size,
/// 0.1..1.
@override@JsonKey() final  double scale;

/// Create a copy of WindowPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WindowPreferencesCopyWith<_WindowPreferences> get copyWith => __$WindowPreferencesCopyWithImpl<_WindowPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WindowPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WindowPreferences&&(identical(other.floatOnLeave, floatOnLeave) || other.floatOnLeave == floatOnLeave)&&(identical(other.pauseOnClose, pauseOnClose) || other.pauseOnClose == pauseOnClose)&&(identical(other.alwaysOnTop, alwaysOnTop) || other.alwaysOnTop == alwaysOnTop)&&(identical(other.scale, scale) || other.scale == scale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,floatOnLeave,pauseOnClose,alwaysOnTop,scale);
}

@override
String toString() {
    return 'WindowPreferences(floatOnLeave: $floatOnLeave, pauseOnClose: $pauseOnClose, alwaysOnTop: $alwaysOnTop, scale: $scale)';
}


}

/// @nodoc
abstract mixin class _$WindowPreferencesCopyWith<$Res> implements $WindowPreferencesCopyWith<$Res> {
  factory _$WindowPreferencesCopyWith(_WindowPreferences value, $Res Function(_WindowPreferences) _then) = __$WindowPreferencesCopyWithImpl;
@override @useResult
$Res call({
 bool floatOnLeave, bool pauseOnClose, bool alwaysOnTop, double scale
});




}
/// @nodoc
class __$WindowPreferencesCopyWithImpl<$Res>
    implements _$WindowPreferencesCopyWith<$Res> {
  __$WindowPreferencesCopyWithImpl(this._self, this._then);

  final _WindowPreferences _self;
  final $Res Function(_WindowPreferences) _then;

/// Create a copy of WindowPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? floatOnLeave = null,Object? pauseOnClose = null,Object? alwaysOnTop = null,Object? scale = null,}) {
  return _then(_WindowPreferences(
floatOnLeave: null == floatOnLeave ? _self.floatOnLeave : floatOnLeave // ignore: cast_nullable_to_non_nullable
as bool,pauseOnClose: null == pauseOnClose ? _self.pauseOnClose : pauseOnClose // ignore: cast_nullable_to_non_nullable
as bool,alwaysOnTop: null == alwaysOnTop ? _self.alwaysOnTop : alwaysOnTop // ignore: cast_nullable_to_non_nullable
as bool,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
