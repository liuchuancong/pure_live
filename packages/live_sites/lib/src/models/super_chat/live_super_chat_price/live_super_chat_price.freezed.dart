// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_super_chat_price.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SuperChatPrice {

 int? get amount; String? get currency; String get displayText;
/// Create a copy of SuperChatPrice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SuperChatPriceCopyWith<SuperChatPrice> get copyWith => _$SuperChatPriceCopyWithImpl<SuperChatPrice>(this as SuperChatPrice, _$identity);

  /// Serializes this SuperChatPrice to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SuperChatPrice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SuperChatPrice&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&(identical(other.currency, _this.currency) || other.currency == _this.currency)&&(identical(other.displayText, _this.displayText) || other.displayText == _this.displayText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SuperChatPrice;
  return Object.hash(runtimeType,_this.amount,_this.currency,_this.displayText);
}

@override
String toString() {
  final _this = this as SuperChatPrice;
  return 'SuperChatPrice(amount: ${_this.amount}, currency: ${_this.currency}, displayText: ${_this.displayText})';
}


}

/// @nodoc
abstract mixin class $SuperChatPriceCopyWith<$Res>  {
  factory $SuperChatPriceCopyWith(SuperChatPrice value, $Res Function(SuperChatPrice) _then) = _$SuperChatPriceCopyWithImpl;
@useResult
$Res call({
 int? amount, String? currency, String displayText
});




}
/// @nodoc
class _$SuperChatPriceCopyWithImpl<$Res>
    implements $SuperChatPriceCopyWith<$Res> {
  _$SuperChatPriceCopyWithImpl(this._self, this._then);

  final SuperChatPrice _self;
  final $Res Function(SuperChatPrice) _then;

/// Create a copy of SuperChatPrice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? amount = freezed,Object? currency = freezed,Object? displayText = null,}) {
  return _then(SuperChatPrice(
amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int?,currency: freezed == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String?,displayText: null == displayText ? _self.displayText : displayText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SuperChatPrice].
extension SuperChatPricePatterns on SuperChatPrice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SuperChatPrice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SuperChatPrice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SuperChatPrice value)  $default,){
final _that = this;
switch (_that) {
case _SuperChatPrice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SuperChatPrice value)?  $default,){
final _that = this;
switch (_that) {
case _SuperChatPrice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? amount,  String? currency,  String displayText)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SuperChatPrice() when $default != null:
return $default(_that.amount,_that.currency,_that.displayText);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? amount,  String? currency,  String displayText)  $default,) {final _that = this;
switch (_that) {
case _SuperChatPrice():
return $default(_that.amount,_that.currency,_that.displayText);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? amount,  String? currency,  String displayText)?  $default,) {final _that = this;
switch (_that) {
case _SuperChatPrice() when $default != null:
return $default(_that.amount,_that.currency,_that.displayText);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SuperChatPrice implements SuperChatPrice {
  const _SuperChatPrice({this.amount, this.currency, this.displayText = ''});
  factory _SuperChatPrice.fromJson(Map<String, dynamic> json) => _$SuperChatPriceFromJson(json);

@override final  int? amount;
@override final  String? currency;
@override@JsonKey() final  String displayText;

/// Create a copy of SuperChatPrice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SuperChatPriceCopyWith<_SuperChatPrice> get copyWith => __$SuperChatPriceCopyWithImpl<_SuperChatPrice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SuperChatPriceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SuperChatPrice&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.displayText, displayText) || other.displayText == displayText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,amount,currency,displayText);
}

@override
String toString() {
    return 'SuperChatPrice(amount: $amount, currency: $currency, displayText: $displayText)';
}


}

/// @nodoc
abstract mixin class _$SuperChatPriceCopyWith<$Res> implements $SuperChatPriceCopyWith<$Res> {
  factory _$SuperChatPriceCopyWith(_SuperChatPrice value, $Res Function(_SuperChatPrice) _then) = __$SuperChatPriceCopyWithImpl;
@override @useResult
$Res call({
 int? amount, String? currency, String displayText
});




}
/// @nodoc
class __$SuperChatPriceCopyWithImpl<$Res>
    implements _$SuperChatPriceCopyWith<$Res> {
  __$SuperChatPriceCopyWithImpl(this._self, this._then);

  final _SuperChatPrice _self;
  final $Res Function(_SuperChatPrice) _then;

/// Create a copy of SuperChatPrice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? amount = freezed,Object? currency = freezed,Object? displayText = null,}) {
  return _then(_SuperChatPrice(
amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int?,currency: freezed == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String?,displayText: null == displayText ? _self.displayText : displayText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
