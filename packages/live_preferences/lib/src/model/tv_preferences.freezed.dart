// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tv_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TvPreferences {

/// Whether the UI restores the last focused control when a page is
/// entered again, instead of focusing its first control.
 bool get focusMemory;/// How much a focused control grows, as a scale factor; 1 keeps every
/// control at its layout size.
 double get focusScale;/// Whether holding the d-pad's left/right key seeks in the live
/// buffer, instead of moving focus.
 bool get longPressSeek;/// Whether the channel up and down keys are swapped when zapping
/// through a channel line-up.
///
/// Some remote layouts, and some viewers, read "up" as "the previous
/// number" rather than "the next row on screen"; the walk itself keeps
/// its order, only the two keys change places, so a list still reads the
/// same way top to bottom.
 bool get channelReversal;
/// Create a copy of TvPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TvPreferencesCopyWith<TvPreferences> get copyWith => _$TvPreferencesCopyWithImpl<TvPreferences>(this as TvPreferences, _$identity);

  /// Serializes this TvPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TvPreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TvPreferences&&(identical(other.focusMemory, _this.focusMemory) || other.focusMemory == _this.focusMemory)&&(identical(other.focusScale, _this.focusScale) || other.focusScale == _this.focusScale)&&(identical(other.longPressSeek, _this.longPressSeek) || other.longPressSeek == _this.longPressSeek)&&(identical(other.channelReversal, _this.channelReversal) || other.channelReversal == _this.channelReversal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TvPreferences;
  return Object.hash(runtimeType,_this.focusMemory,_this.focusScale,_this.longPressSeek,_this.channelReversal);
}

@override
String toString() {
  final _this = this as TvPreferences;
  return 'TvPreferences(focusMemory: ${_this.focusMemory}, focusScale: ${_this.focusScale}, longPressSeek: ${_this.longPressSeek}, channelReversal: ${_this.channelReversal})';
}


}

/// @nodoc
abstract mixin class $TvPreferencesCopyWith<$Res>  {
  factory $TvPreferencesCopyWith(TvPreferences value, $Res Function(TvPreferences) _then) = _$TvPreferencesCopyWithImpl;
@useResult
$Res call({
 bool focusMemory, double focusScale, bool longPressSeek, bool channelReversal
});




}
/// @nodoc
class _$TvPreferencesCopyWithImpl<$Res>
    implements $TvPreferencesCopyWith<$Res> {
  _$TvPreferencesCopyWithImpl(this._self, this._then);

  final TvPreferences _self;
  final $Res Function(TvPreferences) _then;

/// Create a copy of TvPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? focusMemory = null,Object? focusScale = null,Object? longPressSeek = null,Object? channelReversal = null,}) {
  return _then(TvPreferences(
focusMemory: null == focusMemory ? _self.focusMemory : focusMemory // ignore: cast_nullable_to_non_nullable
as bool,focusScale: null == focusScale ? _self.focusScale : focusScale // ignore: cast_nullable_to_non_nullable
as double,longPressSeek: null == longPressSeek ? _self.longPressSeek : longPressSeek // ignore: cast_nullable_to_non_nullable
as bool,channelReversal: null == channelReversal ? _self.channelReversal : channelReversal // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TvPreferences].
extension TvPreferencesPatterns on TvPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TvPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TvPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TvPreferences value)  $default,){
final _that = this;
switch (_that) {
case _TvPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TvPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _TvPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool focusMemory,  double focusScale,  bool longPressSeek,  bool channelReversal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TvPreferences() when $default != null:
return $default(_that.focusMemory,_that.focusScale,_that.longPressSeek,_that.channelReversal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool focusMemory,  double focusScale,  bool longPressSeek,  bool channelReversal)  $default,) {final _that = this;
switch (_that) {
case _TvPreferences():
return $default(_that.focusMemory,_that.focusScale,_that.longPressSeek,_that.channelReversal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool focusMemory,  double focusScale,  bool longPressSeek,  bool channelReversal)?  $default,) {final _that = this;
switch (_that) {
case _TvPreferences() when $default != null:
return $default(_that.focusMemory,_that.focusScale,_that.longPressSeek,_that.channelReversal);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TvPreferences implements TvPreferences {
  const _TvPreferences({this.focusMemory = true, this.focusScale = 1.08, this.longPressSeek = false, this.channelReversal = false});
  factory _TvPreferences.fromJson(Map<String, dynamic> json) => _$TvPreferencesFromJson(json);

/// Whether the UI restores the last focused control when a page is
/// entered again, instead of focusing its first control.
@override@JsonKey() final  bool focusMemory;
/// How much a focused control grows, as a scale factor; 1 keeps every
/// control at its layout size.
@override@JsonKey() final  double focusScale;
/// Whether holding the d-pad's left/right key seeks in the live
/// buffer, instead of moving focus.
@override@JsonKey() final  bool longPressSeek;
/// Whether the channel up and down keys are swapped when zapping
/// through a channel line-up.
///
/// Some remote layouts, and some viewers, read "up" as "the previous
/// number" rather than "the next row on screen"; the walk itself keeps
/// its order, only the two keys change places, so a list still reads the
/// same way top to bottom.
@override@JsonKey() final  bool channelReversal;

/// Create a copy of TvPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TvPreferencesCopyWith<_TvPreferences> get copyWith => __$TvPreferencesCopyWithImpl<_TvPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TvPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TvPreferences&&(identical(other.focusMemory, focusMemory) || other.focusMemory == focusMemory)&&(identical(other.focusScale, focusScale) || other.focusScale == focusScale)&&(identical(other.longPressSeek, longPressSeek) || other.longPressSeek == longPressSeek)&&(identical(other.channelReversal, channelReversal) || other.channelReversal == channelReversal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,focusMemory,focusScale,longPressSeek,channelReversal);
}

@override
String toString() {
    return 'TvPreferences(focusMemory: $focusMemory, focusScale: $focusScale, longPressSeek: $longPressSeek, channelReversal: $channelReversal)';
}


}

/// @nodoc
abstract mixin class _$TvPreferencesCopyWith<$Res> implements $TvPreferencesCopyWith<$Res> {
  factory _$TvPreferencesCopyWith(_TvPreferences value, $Res Function(_TvPreferences) _then) = __$TvPreferencesCopyWithImpl;
@override @useResult
$Res call({
 bool focusMemory, double focusScale, bool longPressSeek, bool channelReversal
});




}
/// @nodoc
class __$TvPreferencesCopyWithImpl<$Res>
    implements _$TvPreferencesCopyWith<$Res> {
  __$TvPreferencesCopyWithImpl(this._self, this._then);

  final _TvPreferences _self;
  final $Res Function(_TvPreferences) _then;

/// Create a copy of TvPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? focusMemory = null,Object? focusScale = null,Object? longPressSeek = null,Object? channelReversal = null,}) {
  return _then(_TvPreferences(
focusMemory: null == focusMemory ? _self.focusMemory : focusMemory // ignore: cast_nullable_to_non_nullable
as bool,focusScale: null == focusScale ? _self.focusScale : focusScale // ignore: cast_nullable_to_non_nullable
as double,longPressSeek: null == longPressSeek ? _self.longPressSeek : longPressSeek // ignore: cast_nullable_to_non_nullable
as bool,channelReversal: null == channelReversal ? _self.channelReversal : channelReversal // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
