// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_gift_value.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveGiftValue {

 LiveGiftUnit get unit; double? get unitPrice; double? get totalValue;
/// Create a copy of LiveGiftValue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveGiftValueCopyWith<LiveGiftValue> get copyWith => _$LiveGiftValueCopyWithImpl<LiveGiftValue>(this as LiveGiftValue, _$identity);

  /// Serializes this LiveGiftValue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveGiftValue;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveGiftValue&&(identical(other.unit, _this.unit) || other.unit == _this.unit)&&(identical(other.unitPrice, _this.unitPrice) || other.unitPrice == _this.unitPrice)&&(identical(other.totalValue, _this.totalValue) || other.totalValue == _this.totalValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveGiftValue;
  return Object.hash(runtimeType,_this.unit,_this.unitPrice,_this.totalValue);
}

@override
String toString() {
  final _this = this as LiveGiftValue;
  return 'LiveGiftValue(unit: ${_this.unit}, unitPrice: ${_this.unitPrice}, totalValue: ${_this.totalValue})';
}


}

/// @nodoc
abstract mixin class $LiveGiftValueCopyWith<$Res>  {
  factory $LiveGiftValueCopyWith(LiveGiftValue value, $Res Function(LiveGiftValue) _then) = _$LiveGiftValueCopyWithImpl;
@useResult
$Res call({
 LiveGiftUnit unit, double? unitPrice, double? totalValue
});




}
/// @nodoc
class _$LiveGiftValueCopyWithImpl<$Res>
    implements $LiveGiftValueCopyWith<$Res> {
  _$LiveGiftValueCopyWithImpl(this._self, this._then);

  final LiveGiftValue _self;
  final $Res Function(LiveGiftValue) _then;

/// Create a copy of LiveGiftValue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? unit = null,Object? unitPrice = freezed,Object? totalValue = freezed,}) {
  return _then(LiveGiftValue(
unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as LiveGiftUnit,unitPrice: freezed == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as double?,totalValue: freezed == totalValue ? _self.totalValue : totalValue // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveGiftValue].
extension LiveGiftValuePatterns on LiveGiftValue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveGiftValue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveGiftValue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveGiftValue value)  $default,){
final _that = this;
switch (_that) {
case _LiveGiftValue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveGiftValue value)?  $default,){
final _that = this;
switch (_that) {
case _LiveGiftValue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveGiftUnit unit,  double? unitPrice,  double? totalValue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveGiftValue() when $default != null:
return $default(_that.unit,_that.unitPrice,_that.totalValue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveGiftUnit unit,  double? unitPrice,  double? totalValue)  $default,) {final _that = this;
switch (_that) {
case _LiveGiftValue():
return $default(_that.unit,_that.unitPrice,_that.totalValue);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveGiftUnit unit,  double? unitPrice,  double? totalValue)?  $default,) {final _that = this;
switch (_that) {
case _LiveGiftValue() when $default != null:
return $default(_that.unit,_that.unitPrice,_that.totalValue);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveGiftValue implements LiveGiftValue {
  const _LiveGiftValue({this.unit = LiveGiftUnit.other, this.unitPrice, this.totalValue});
  factory _LiveGiftValue.fromJson(Map<String, dynamic> json) => _$LiveGiftValueFromJson(json);

@override@JsonKey() final  LiveGiftUnit unit;
@override final  double? unitPrice;
@override final  double? totalValue;

/// Create a copy of LiveGiftValue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveGiftValueCopyWith<_LiveGiftValue> get copyWith => __$LiveGiftValueCopyWithImpl<_LiveGiftValue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveGiftValueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveGiftValue&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.totalValue, totalValue) || other.totalValue == totalValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,unit,unitPrice,totalValue);
}

@override
String toString() {
    return 'LiveGiftValue(unit: $unit, unitPrice: $unitPrice, totalValue: $totalValue)';
}


}

/// @nodoc
abstract mixin class _$LiveGiftValueCopyWith<$Res> implements $LiveGiftValueCopyWith<$Res> {
  factory _$LiveGiftValueCopyWith(_LiveGiftValue value, $Res Function(_LiveGiftValue) _then) = __$LiveGiftValueCopyWithImpl;
@override @useResult
$Res call({
 LiveGiftUnit unit, double? unitPrice, double? totalValue
});




}
/// @nodoc
class __$LiveGiftValueCopyWithImpl<$Res>
    implements _$LiveGiftValueCopyWith<$Res> {
  __$LiveGiftValueCopyWithImpl(this._self, this._then);

  final _LiveGiftValue _self;
  final $Res Function(_LiveGiftValue) _then;

/// Create a copy of LiveGiftValue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? unit = null,Object? unitPrice = freezed,Object? totalValue = freezed,}) {
  return _then(_LiveGiftValue(
unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as LiveGiftUnit,unitPrice: freezed == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as double?,totalValue: freezed == totalValue ? _self.totalValue : totalValue // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
