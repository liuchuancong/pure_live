// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_gift.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveGift {

 String get giftId; String get name; String? get iconUrl; LiveGiftKind get kind; int get count; LiveGiftValue get value; LiveGiftCombo get combo; String get recipientName;
/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveGiftCopyWith<LiveGift> get copyWith => _$LiveGiftCopyWithImpl<LiveGift>(this as LiveGift, _$identity);

  /// Serializes this LiveGift to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveGift;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveGift&&(identical(other.giftId, _this.giftId) || other.giftId == _this.giftId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.iconUrl, _this.iconUrl) || other.iconUrl == _this.iconUrl)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.count, _this.count) || other.count == _this.count)&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.combo, _this.combo) || other.combo == _this.combo)&&(identical(other.recipientName, _this.recipientName) || other.recipientName == _this.recipientName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveGift;
  return Object.hash(runtimeType,_this.giftId,_this.name,_this.iconUrl,_this.kind,_this.count,_this.value,_this.combo,_this.recipientName);
}

@override
String toString() {
  final _this = this as LiveGift;
  return 'LiveGift(giftId: ${_this.giftId}, name: ${_this.name}, iconUrl: ${_this.iconUrl}, kind: ${_this.kind}, count: ${_this.count}, value: ${_this.value}, combo: ${_this.combo}, recipientName: ${_this.recipientName})';
}


}

/// @nodoc
abstract mixin class $LiveGiftCopyWith<$Res>  {
  factory $LiveGiftCopyWith(LiveGift value, $Res Function(LiveGift) _then) = _$LiveGiftCopyWithImpl;
@useResult
$Res call({
 String giftId, String name, String? iconUrl, LiveGiftKind kind, int count, LiveGiftValue value, LiveGiftCombo combo, String recipientName
});


$LiveGiftValueCopyWith<$Res> get value;$LiveGiftComboCopyWith<$Res> get combo;

}
/// @nodoc
class _$LiveGiftCopyWithImpl<$Res>
    implements $LiveGiftCopyWith<$Res> {
  _$LiveGiftCopyWithImpl(this._self, this._then);

  final LiveGift _self;
  final $Res Function(LiveGift) _then;

/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? giftId = null,Object? name = null,Object? iconUrl = freezed,Object? kind = null,Object? count = null,Object? value = null,Object? combo = null,Object? recipientName = null,}) {
  return _then(LiveGift(
giftId: null == giftId ? _self.giftId : giftId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LiveGiftKind,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as LiveGiftValue,combo: null == combo ? _self.combo : combo // ignore: cast_nullable_to_non_nullable
as LiveGiftCombo,recipientName: null == recipientName ? _self.recipientName : recipientName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveGiftValueCopyWith<$Res> get value {
  
  return $LiveGiftValueCopyWith<$Res>(_self.value, (value) {
    return _then(_self.copyWith(value: value));
  });
}/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveGiftComboCopyWith<$Res> get combo {
  
  return $LiveGiftComboCopyWith<$Res>(_self.combo, (value) {
    return _then(_self.copyWith(combo: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveGift].
extension LiveGiftPatterns on LiveGift {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveGift value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveGift() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveGift value)  $default,){
final _that = this;
switch (_that) {
case _LiveGift():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveGift value)?  $default,){
final _that = this;
switch (_that) {
case _LiveGift() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String giftId,  String name,  String? iconUrl,  LiveGiftKind kind,  int count,  LiveGiftValue value,  LiveGiftCombo combo,  String recipientName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveGift() when $default != null:
return $default(_that.giftId,_that.name,_that.iconUrl,_that.kind,_that.count,_that.value,_that.combo,_that.recipientName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String giftId,  String name,  String? iconUrl,  LiveGiftKind kind,  int count,  LiveGiftValue value,  LiveGiftCombo combo,  String recipientName)  $default,) {final _that = this;
switch (_that) {
case _LiveGift():
return $default(_that.giftId,_that.name,_that.iconUrl,_that.kind,_that.count,_that.value,_that.combo,_that.recipientName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String giftId,  String name,  String? iconUrl,  LiveGiftKind kind,  int count,  LiveGiftValue value,  LiveGiftCombo combo,  String recipientName)?  $default,) {final _that = this;
switch (_that) {
case _LiveGift() when $default != null:
return $default(_that.giftId,_that.name,_that.iconUrl,_that.kind,_that.count,_that.value,_that.combo,_that.recipientName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveGift implements LiveGift {
  const _LiveGift({this.giftId = '', this.name = '', this.iconUrl, this.kind = LiveGiftKind.normal, this.count = 1, this.value = const LiveGiftValue(), this.combo = const LiveGiftCombo(), this.recipientName = ''});
  factory _LiveGift.fromJson(Map<String, dynamic> json) => _$LiveGiftFromJson(json);

@override@JsonKey() final  String giftId;
@override@JsonKey() final  String name;
@override final  String? iconUrl;
@override@JsonKey() final  LiveGiftKind kind;
@override@JsonKey() final  int count;
@override@JsonKey() final  LiveGiftValue value;
@override@JsonKey() final  LiveGiftCombo combo;
@override@JsonKey() final  String recipientName;

/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveGiftCopyWith<_LiveGift> get copyWith => __$LiveGiftCopyWithImpl<_LiveGift>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveGiftToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveGift&&(identical(other.giftId, giftId) || other.giftId == giftId)&&(identical(other.name, name) || other.name == name)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.count, count) || other.count == count)&&(identical(other.value, value) || other.value == value)&&(identical(other.combo, combo) || other.combo == combo)&&(identical(other.recipientName, recipientName) || other.recipientName == recipientName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,giftId,name,iconUrl,kind,count,value,combo,recipientName);
}

@override
String toString() {
    return 'LiveGift(giftId: $giftId, name: $name, iconUrl: $iconUrl, kind: $kind, count: $count, value: $value, combo: $combo, recipientName: $recipientName)';
}


}

/// @nodoc
abstract mixin class _$LiveGiftCopyWith<$Res> implements $LiveGiftCopyWith<$Res> {
  factory _$LiveGiftCopyWith(_LiveGift value, $Res Function(_LiveGift) _then) = __$LiveGiftCopyWithImpl;
@override @useResult
$Res call({
 String giftId, String name, String? iconUrl, LiveGiftKind kind, int count, LiveGiftValue value, LiveGiftCombo combo, String recipientName
});


@override $LiveGiftValueCopyWith<$Res> get value;@override $LiveGiftComboCopyWith<$Res> get combo;

}
/// @nodoc
class __$LiveGiftCopyWithImpl<$Res>
    implements _$LiveGiftCopyWith<$Res> {
  __$LiveGiftCopyWithImpl(this._self, this._then);

  final _LiveGift _self;
  final $Res Function(_LiveGift) _then;

/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? giftId = null,Object? name = null,Object? iconUrl = freezed,Object? kind = null,Object? count = null,Object? value = null,Object? combo = null,Object? recipientName = null,}) {
  return _then(_LiveGift(
giftId: null == giftId ? _self.giftId : giftId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LiveGiftKind,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as LiveGiftValue,combo: null == combo ? _self.combo : combo // ignore: cast_nullable_to_non_nullable
as LiveGiftCombo,recipientName: null == recipientName ? _self.recipientName : recipientName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveGiftValueCopyWith<$Res> get value {
  
  return $LiveGiftValueCopyWith<$Res>(_self.value, (value) {
    return _then(_self.copyWith(value: value));
  });
}/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveGiftComboCopyWith<$Res> get combo {
  
  return $LiveGiftComboCopyWith<$Res>(_self.combo, (value) {
    return _then(_self.copyWith(combo: value));
  });
}
}

// dart format on
