// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_gift_combo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveGiftCombo {

 String get comboKey; int? get comboTotal;
/// Create a copy of LiveGiftCombo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveGiftComboCopyWith<LiveGiftCombo> get copyWith => _$LiveGiftComboCopyWithImpl<LiveGiftCombo>(this as LiveGiftCombo, _$identity);

  /// Serializes this LiveGiftCombo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveGiftCombo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveGiftCombo&&(identical(other.comboKey, _this.comboKey) || other.comboKey == _this.comboKey)&&(identical(other.comboTotal, _this.comboTotal) || other.comboTotal == _this.comboTotal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveGiftCombo;
  return Object.hash(runtimeType,_this.comboKey,_this.comboTotal);
}

@override
String toString() {
  final _this = this as LiveGiftCombo;
  return 'LiveGiftCombo(comboKey: ${_this.comboKey}, comboTotal: ${_this.comboTotal})';
}


}

/// @nodoc
abstract mixin class $LiveGiftComboCopyWith<$Res>  {
  factory $LiveGiftComboCopyWith(LiveGiftCombo value, $Res Function(LiveGiftCombo) _then) = _$LiveGiftComboCopyWithImpl;
@useResult
$Res call({
 String comboKey, int? comboTotal
});




}
/// @nodoc
class _$LiveGiftComboCopyWithImpl<$Res>
    implements $LiveGiftComboCopyWith<$Res> {
  _$LiveGiftComboCopyWithImpl(this._self, this._then);

  final LiveGiftCombo _self;
  final $Res Function(LiveGiftCombo) _then;

/// Create a copy of LiveGiftCombo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? comboKey = null,Object? comboTotal = freezed,}) {
  return _then(LiveGiftCombo(
comboKey: null == comboKey ? _self.comboKey : comboKey // ignore: cast_nullable_to_non_nullable
as String,comboTotal: freezed == comboTotal ? _self.comboTotal : comboTotal // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveGiftCombo].
extension LiveGiftComboPatterns on LiveGiftCombo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveGiftCombo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveGiftCombo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveGiftCombo value)  $default,){
final _that = this;
switch (_that) {
case _LiveGiftCombo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveGiftCombo value)?  $default,){
final _that = this;
switch (_that) {
case _LiveGiftCombo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String comboKey,  int? comboTotal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveGiftCombo() when $default != null:
return $default(_that.comboKey,_that.comboTotal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String comboKey,  int? comboTotal)  $default,) {final _that = this;
switch (_that) {
case _LiveGiftCombo():
return $default(_that.comboKey,_that.comboTotal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String comboKey,  int? comboTotal)?  $default,) {final _that = this;
switch (_that) {
case _LiveGiftCombo() when $default != null:
return $default(_that.comboKey,_that.comboTotal);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveGiftCombo implements LiveGiftCombo {
  const _LiveGiftCombo({this.comboKey = '', this.comboTotal});
  factory _LiveGiftCombo.fromJson(Map<String, dynamic> json) => _$LiveGiftComboFromJson(json);

@override@JsonKey() final  String comboKey;
@override final  int? comboTotal;

/// Create a copy of LiveGiftCombo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveGiftComboCopyWith<_LiveGiftCombo> get copyWith => __$LiveGiftComboCopyWithImpl<_LiveGiftCombo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveGiftComboToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveGiftCombo&&(identical(other.comboKey, comboKey) || other.comboKey == comboKey)&&(identical(other.comboTotal, comboTotal) || other.comboTotal == comboTotal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,comboKey,comboTotal);
}

@override
String toString() {
    return 'LiveGiftCombo(comboKey: $comboKey, comboTotal: $comboTotal)';
}


}

/// @nodoc
abstract mixin class _$LiveGiftComboCopyWith<$Res> implements $LiveGiftComboCopyWith<$Res> {
  factory _$LiveGiftComboCopyWith(_LiveGiftCombo value, $Res Function(_LiveGiftCombo) _then) = __$LiveGiftComboCopyWithImpl;
@override @useResult
$Res call({
 String comboKey, int? comboTotal
});




}
/// @nodoc
class __$LiveGiftComboCopyWithImpl<$Res>
    implements _$LiveGiftComboCopyWith<$Res> {
  __$LiveGiftComboCopyWithImpl(this._self, this._then);

  final _LiveGiftCombo _self;
  final $Res Function(_LiveGiftCombo) _then;

/// Create a copy of LiveGiftCombo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? comboKey = null,Object? comboTotal = freezed,}) {
  return _then(_LiveGiftCombo(
comboKey: null == comboKey ? _self.comboKey : comboKey // ignore: cast_nullable_to_non_nullable
as String,comboTotal: freezed == comboTotal ? _self.comboTotal : comboTotal // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
