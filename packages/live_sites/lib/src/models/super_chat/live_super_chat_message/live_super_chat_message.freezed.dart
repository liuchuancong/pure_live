// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_super_chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveSuperChatMessage {

 String get messageId; String get userName; String get faceUrl; String get text; SuperChatPrice get price; DateTime? get startTime; DateTime? get endTime; SuperChatDisplay get display;
/// Create a copy of LiveSuperChatMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSuperChatMessageCopyWith<LiveSuperChatMessage> get copyWith => _$LiveSuperChatMessageCopyWithImpl<LiveSuperChatMessage>(this as LiveSuperChatMessage, _$identity);

  /// Serializes this LiveSuperChatMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveSuperChatMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSuperChatMessage&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId)&&(identical(other.userName, _this.userName) || other.userName == _this.userName)&&(identical(other.faceUrl, _this.faceUrl) || other.faceUrl == _this.faceUrl)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.price, _this.price) || other.price == _this.price)&&(identical(other.startTime, _this.startTime) || other.startTime == _this.startTime)&&(identical(other.endTime, _this.endTime) || other.endTime == _this.endTime)&&(identical(other.display, _this.display) || other.display == _this.display));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveSuperChatMessage;
  return Object.hash(runtimeType,_this.messageId,_this.userName,_this.faceUrl,_this.text,_this.price,_this.startTime,_this.endTime,_this.display);
}

@override
String toString() {
  final _this = this as LiveSuperChatMessage;
  return 'LiveSuperChatMessage(messageId: ${_this.messageId}, userName: ${_this.userName}, faceUrl: ${_this.faceUrl}, text: ${_this.text}, price: ${_this.price}, startTime: ${_this.startTime}, endTime: ${_this.endTime}, display: ${_this.display})';
}


}

/// @nodoc
abstract mixin class $LiveSuperChatMessageCopyWith<$Res>  {
  factory $LiveSuperChatMessageCopyWith(LiveSuperChatMessage value, $Res Function(LiveSuperChatMessage) _then) = _$LiveSuperChatMessageCopyWithImpl;
@useResult
$Res call({
 String messageId, String userName, String faceUrl, String text, SuperChatPrice price, DateTime? startTime, DateTime? endTime, SuperChatDisplay display
});


$SuperChatPriceCopyWith<$Res> get price;$SuperChatDisplayCopyWith<$Res> get display;

}
/// @nodoc
class _$LiveSuperChatMessageCopyWithImpl<$Res>
    implements $LiveSuperChatMessageCopyWith<$Res> {
  _$LiveSuperChatMessageCopyWithImpl(this._self, this._then);

  final LiveSuperChatMessage _self;
  final $Res Function(LiveSuperChatMessage) _then;

/// Create a copy of LiveSuperChatMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? userName = null,Object? faceUrl = null,Object? text = null,Object? price = null,Object? startTime = freezed,Object? endTime = freezed,Object? display = null,}) {
  return _then(LiveSuperChatMessage(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as SuperChatPrice,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as DateTime?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as DateTime?,display: null == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as SuperChatDisplay,
  ));
}
/// Create a copy of LiveSuperChatMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SuperChatPriceCopyWith<$Res> get price {
  
  return $SuperChatPriceCopyWith<$Res>(_self.price, (value) {
    return _then(_self.copyWith(price: value));
  });
}/// Create a copy of LiveSuperChatMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SuperChatDisplayCopyWith<$Res> get display {
  
  return $SuperChatDisplayCopyWith<$Res>(_self.display, (value) {
    return _then(_self.copyWith(display: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveSuperChatMessage].
extension LiveSuperChatMessagePatterns on LiveSuperChatMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveSuperChatMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveSuperChatMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveSuperChatMessage value)  $default,){
final _that = this;
switch (_that) {
case _LiveSuperChatMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveSuperChatMessage value)?  $default,){
final _that = this;
switch (_that) {
case _LiveSuperChatMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String userName,  String faceUrl,  String text,  SuperChatPrice price,  DateTime? startTime,  DateTime? endTime,  SuperChatDisplay display)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveSuperChatMessage() when $default != null:
return $default(_that.messageId,_that.userName,_that.faceUrl,_that.text,_that.price,_that.startTime,_that.endTime,_that.display);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String userName,  String faceUrl,  String text,  SuperChatPrice price,  DateTime? startTime,  DateTime? endTime,  SuperChatDisplay display)  $default,) {final _that = this;
switch (_that) {
case _LiveSuperChatMessage():
return $default(_that.messageId,_that.userName,_that.faceUrl,_that.text,_that.price,_that.startTime,_that.endTime,_that.display);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String userName,  String faceUrl,  String text,  SuperChatPrice price,  DateTime? startTime,  DateTime? endTime,  SuperChatDisplay display)?  $default,) {final _that = this;
switch (_that) {
case _LiveSuperChatMessage() when $default != null:
return $default(_that.messageId,_that.userName,_that.faceUrl,_that.text,_that.price,_that.startTime,_that.endTime,_that.display);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveSuperChatMessage implements LiveSuperChatMessage {
  const _LiveSuperChatMessage({this.messageId = '', this.userName = '', this.faceUrl = '', this.text = '', this.price = const SuperChatPrice(), this.startTime, this.endTime, this.display = const SuperChatDisplay()});
  factory _LiveSuperChatMessage.fromJson(Map<String, dynamic> json) => _$LiveSuperChatMessageFromJson(json);

@override@JsonKey() final  String messageId;
@override@JsonKey() final  String userName;
@override@JsonKey() final  String faceUrl;
@override@JsonKey() final  String text;
@override@JsonKey() final  SuperChatPrice price;
@override final  DateTime? startTime;
@override final  DateTime? endTime;
@override@JsonKey() final  SuperChatDisplay display;

/// Create a copy of LiveSuperChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveSuperChatMessageCopyWith<_LiveSuperChatMessage> get copyWith => __$LiveSuperChatMessageCopyWithImpl<_LiveSuperChatMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveSuperChatMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveSuperChatMessage&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.text, text) || other.text == text)&&(identical(other.price, price) || other.price == price)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.display, display) || other.display == display));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,messageId,userName,faceUrl,text,price,startTime,endTime,display);
}

@override
String toString() {
    return 'LiveSuperChatMessage(messageId: $messageId, userName: $userName, faceUrl: $faceUrl, text: $text, price: $price, startTime: $startTime, endTime: $endTime, display: $display)';
}


}

/// @nodoc
abstract mixin class _$LiveSuperChatMessageCopyWith<$Res> implements $LiveSuperChatMessageCopyWith<$Res> {
  factory _$LiveSuperChatMessageCopyWith(_LiveSuperChatMessage value, $Res Function(_LiveSuperChatMessage) _then) = __$LiveSuperChatMessageCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String userName, String faceUrl, String text, SuperChatPrice price, DateTime? startTime, DateTime? endTime, SuperChatDisplay display
});


@override $SuperChatPriceCopyWith<$Res> get price;@override $SuperChatDisplayCopyWith<$Res> get display;

}
/// @nodoc
class __$LiveSuperChatMessageCopyWithImpl<$Res>
    implements _$LiveSuperChatMessageCopyWith<$Res> {
  __$LiveSuperChatMessageCopyWithImpl(this._self, this._then);

  final _LiveSuperChatMessage _self;
  final $Res Function(_LiveSuperChatMessage) _then;

/// Create a copy of LiveSuperChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? userName = null,Object? faceUrl = null,Object? text = null,Object? price = null,Object? startTime = freezed,Object? endTime = freezed,Object? display = null,}) {
  return _then(_LiveSuperChatMessage(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as SuperChatPrice,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as DateTime?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as DateTime?,display: null == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as SuperChatDisplay,
  ));
}

/// Create a copy of LiveSuperChatMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SuperChatPriceCopyWith<$Res> get price {
  
  return $SuperChatPriceCopyWith<$Res>(_self.price, (value) {
    return _then(_self.copyWith(price: value));
  });
}/// Create a copy of LiveSuperChatMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SuperChatDisplayCopyWith<$Res> get display {
  
  return $SuperChatDisplayCopyWith<$Res>(_self.display, (value) {
    return _then(_self.copyWith(display: value));
  });
}
}

// dart format on
