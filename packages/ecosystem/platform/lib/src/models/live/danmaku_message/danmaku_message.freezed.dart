// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'danmaku_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DanmakuMessage {

@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef get room;@JsonKey(fromJson: _kind, toJson: _kindName) DanmakuKind get kind;/// The text to show. For a gift this is the sentence ("送了火箭"), not the item name - the item is [itemName].
@JsonKey(fromJson: _text) String get text;/// When the source said it happened, in UTC. A wire row with no timestamp is stamped on receipt by the
/// provider, so a surface that scrolls by [at] treats rows from a provider that had to guess as arriving in
/// order rather than comparable across rooms.
@JsonKey(fromJson: _at, toJson: formatUtc) DateTime get at;@JsonKey(fromJson: _optionalText, includeIfNull: false) String? get senderId;@JsonKey(fromJson: _optionalText, includeIfNull: false) String? get senderName;@JsonKey(fromJson: _optionalText, includeIfNull: false) String? get avatar;/// Gift/superchat paid amount in the platform's own unit. The unit is deliberately *not* normalised: showing
/// it as money needs the platform's currency, and inventing a common one here would be a conversion nobody
/// asked for.
@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? get amount;/// The gifted item's name/id, when [kind] is a gift.
@JsonKey(fromJson: _optionalText, includeIfNull: false) String? get itemName;@JsonKey(fromJson: _optionalText, includeIfNull: false) String? get itemId;/// The sender's chosen colour as the source encoded it (0xRRGGBB), when it carries one.
@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? get color;/// The viewer's own message echoed back. A surface must not double-print it, and the only way to know is
/// that the source said so.
 bool get isSelf;/// Whatever the platform carries that this shape cannot name (see danmaku_kind.dart's note on `system`).
@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> get extra;
/// Create a copy of DanmakuMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DanmakuMessageCopyWith<DanmakuMessage> get copyWith => _$DanmakuMessageCopyWithImpl<DanmakuMessage>(this as DanmakuMessage, _$identity);

  /// Serializes this DanmakuMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DanmakuMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DanmakuMessage&&(identical(other.room, _this.room) || other.room == _this.room)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.senderId, _this.senderId) || other.senderId == _this.senderId)&&(identical(other.senderName, _this.senderName) || other.senderName == _this.senderName)&&(identical(other.avatar, _this.avatar) || other.avatar == _this.avatar)&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&(identical(other.itemName, _this.itemName) || other.itemName == _this.itemName)&&(identical(other.itemId, _this.itemId) || other.itemId == _this.itemId)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.isSelf, _this.isSelf) || other.isSelf == _this.isSelf)&&const DeepCollectionEquality().equals(other.extra, _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DanmakuMessage;
  return Object.hash(runtimeType,_this.room,_this.kind,_this.text,_this.at,_this.senderId,_this.senderName,_this.avatar,_this.amount,_this.itemName,_this.itemId,_this.color,_this.isSelf,const DeepCollectionEquality().hash(_this.extra));
}



}

/// @nodoc
abstract mixin class $DanmakuMessageCopyWith<$Res>  {
  factory $DanmakuMessageCopyWith(DanmakuMessage value, $Res Function(DanmakuMessage) _then) = _$DanmakuMessageCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef room,@JsonKey(fromJson: _kind, toJson: _kindName) DanmakuKind kind,@JsonKey(fromJson: _text) String text,@JsonKey(fromJson: _at, toJson: formatUtc) DateTime at,@JsonKey(fromJson: _optionalText, includeIfNull: false) String? senderId,@JsonKey(fromJson: _optionalText, includeIfNull: false) String? senderName,@JsonKey(fromJson: _optionalText, includeIfNull: false) String? avatar,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? amount,@JsonKey(fromJson: _optionalText, includeIfNull: false) String? itemName,@JsonKey(fromJson: _optionalText, includeIfNull: false) String? itemId,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? color, bool isSelf,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> extra
});




}
/// @nodoc
class _$DanmakuMessageCopyWithImpl<$Res>
    implements $DanmakuMessageCopyWith<$Res> {
  _$DanmakuMessageCopyWithImpl(this._self, this._then);

  final DanmakuMessage _self;
  final $Res Function(DanmakuMessage) _then;

/// Create a copy of DanmakuMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? room = null,Object? kind = null,Object? text = null,Object? at = null,Object? senderId = freezed,Object? senderName = freezed,Object? avatar = freezed,Object? amount = freezed,Object? itemName = freezed,Object? itemId = freezed,Object? color = freezed,Object? isSelf = null,Object? extra = null,}) {
  return _then(DanmakuMessage(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as ContentRef,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as DanmakuKind,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int?,itemName: freezed == itemName ? _self.itemName : itemName // ignore: cast_nullable_to_non_nullable
as String?,itemId: freezed == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String?,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int?,isSelf: null == isSelf ? _self.isSelf : isSelf // ignore: cast_nullable_to_non_nullable
as bool,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [DanmakuMessage].
extension DanmakuMessagePatterns on DanmakuMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DanmakuMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DanmakuMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DanmakuMessage value)  $default,){
final _that = this;
switch (_that) {
case _DanmakuMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DanmakuMessage value)?  $default,){
final _that = this;
switch (_that) {
case _DanmakuMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef room, @JsonKey(fromJson: _kind, toJson: _kindName)  DanmakuKind kind, @JsonKey(fromJson: _text)  String text, @JsonKey(fromJson: _at, toJson: formatUtc)  DateTime at, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? senderId, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? senderName, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? avatar, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false)  int? amount, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? itemName, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? itemId, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false)  int? color,  bool isSelf, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DanmakuMessage() when $default != null:
return $default(_that.room,_that.kind,_that.text,_that.at,_that.senderId,_that.senderName,_that.avatar,_that.amount,_that.itemName,_that.itemId,_that.color,_that.isSelf,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef room, @JsonKey(fromJson: _kind, toJson: _kindName)  DanmakuKind kind, @JsonKey(fromJson: _text)  String text, @JsonKey(fromJson: _at, toJson: formatUtc)  DateTime at, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? senderId, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? senderName, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? avatar, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false)  int? amount, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? itemName, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? itemId, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false)  int? color,  bool isSelf, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)  $default,) {final _that = this;
switch (_that) {
case _DanmakuMessage():
return $default(_that.room,_that.kind,_that.text,_that.at,_that.senderId,_that.senderName,_that.avatar,_that.amount,_that.itemName,_that.itemId,_that.color,_that.isSelf,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef room, @JsonKey(fromJson: _kind, toJson: _kindName)  DanmakuKind kind, @JsonKey(fromJson: _text)  String text, @JsonKey(fromJson: _at, toJson: formatUtc)  DateTime at, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? senderId, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? senderName, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? avatar, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false)  int? amount, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? itemName, @JsonKey(fromJson: _optionalText, includeIfNull: false)  String? itemId, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false)  int? color,  bool isSelf, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)?  $default,) {final _that = this;
switch (_that) {
case _DanmakuMessage() when $default != null:
return $default(_that.room,_that.kind,_that.text,_that.at,_that.senderId,_that.senderName,_that.avatar,_that.amount,_that.itemName,_that.itemId,_that.color,_that.isSelf,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DanmakuMessage extends DanmakuMessage {
  const _DanmakuMessage({@JsonKey(fromJson: refFromJson, toJson: refToJson) required this.room, @JsonKey(fromJson: _kind, toJson: _kindName) required this.kind, @JsonKey(fromJson: _text) required this.text, @JsonKey(fromJson: _at, toJson: formatUtc) required this.at, @JsonKey(fromJson: _optionalText, includeIfNull: false) this.senderId, @JsonKey(fromJson: _optionalText, includeIfNull: false) this.senderName, @JsonKey(fromJson: _optionalText, includeIfNull: false) this.avatar, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) this.amount, @JsonKey(fromJson: _optionalText, includeIfNull: false) this.itemName, @JsonKey(fromJson: _optionalText, includeIfNull: false) this.itemId, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) this.color, this.isSelf = false, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra,super._();
  factory _DanmakuMessage.fromJson(Map<String, dynamic> json) => _$DanmakuMessageFromJson(json);

@override@JsonKey(fromJson: refFromJson, toJson: refToJson) final  ContentRef room;
@override@JsonKey(fromJson: _kind, toJson: _kindName) final  DanmakuKind kind;
/// The text to show. For a gift this is the sentence ("送了火箭"), not the item name - the item is [itemName].
@override@JsonKey(fromJson: _text) final  String text;
/// When the source said it happened, in UTC. A wire row with no timestamp is stamped on receipt by the
/// provider, so a surface that scrolls by [at] treats rows from a provider that had to guess as arriving in
/// order rather than comparable across rooms.
@override@JsonKey(fromJson: _at, toJson: formatUtc) final  DateTime at;
@override@JsonKey(fromJson: _optionalText, includeIfNull: false) final  String? senderId;
@override@JsonKey(fromJson: _optionalText, includeIfNull: false) final  String? senderName;
@override@JsonKey(fromJson: _optionalText, includeIfNull: false) final  String? avatar;
/// Gift/superchat paid amount in the platform's own unit. The unit is deliberately *not* normalised: showing
/// it as money needs the platform's currency, and inventing a common one here would be a conversion nobody
/// asked for.
@override@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) final  int? amount;
/// The gifted item's name/id, when [kind] is a gift.
@override@JsonKey(fromJson: _optionalText, includeIfNull: false) final  String? itemName;
@override@JsonKey(fromJson: _optionalText, includeIfNull: false) final  String? itemId;
/// The sender's chosen colour as the source encoded it (0xRRGGBB), when it carries one.
@override@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) final  int? color;
/// The viewer's own message echoed back. A surface must not double-print it, and the only way to know is
/// that the source said so.
@override@JsonKey() final  bool isSelf;
/// Whatever the platform carries that this shape cannot name (see danmaku_kind.dart's note on `system`).
 final  Map<String, Object?> _extra;
/// Whatever the platform carries that this shape cannot name (see danmaku_kind.dart's note on `system`).
@override@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of DanmakuMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DanmakuMessageCopyWith<_DanmakuMessage> get copyWith => __$DanmakuMessageCopyWithImpl<_DanmakuMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DanmakuMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DanmakuMessage&&(identical(other.room, room) || other.room == room)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.text, text) || other.text == text)&&(identical(other.at, at) || other.at == at)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.itemName, itemName) || other.itemName == itemName)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.color, color) || other.color == color)&&(identical(other.isSelf, isSelf) || other.isSelf == isSelf)&&const DeepCollectionEquality().equals(other.extra, _extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,room,kind,text,at,senderId,senderName,avatar,amount,itemName,itemId,color,isSelf,const DeepCollectionEquality().hash(_extra));
}



}

/// @nodoc
abstract mixin class _$DanmakuMessageCopyWith<$Res> implements $DanmakuMessageCopyWith<$Res> {
  factory _$DanmakuMessageCopyWith(_DanmakuMessage value, $Res Function(_DanmakuMessage) _then) = __$DanmakuMessageCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef room,@JsonKey(fromJson: _kind, toJson: _kindName) DanmakuKind kind,@JsonKey(fromJson: _text) String text,@JsonKey(fromJson: _at, toJson: formatUtc) DateTime at,@JsonKey(fromJson: _optionalText, includeIfNull: false) String? senderId,@JsonKey(fromJson: _optionalText, includeIfNull: false) String? senderName,@JsonKey(fromJson: _optionalText, includeIfNull: false) String? avatar,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? amount,@JsonKey(fromJson: _optionalText, includeIfNull: false) String? itemName,@JsonKey(fromJson: _optionalText, includeIfNull: false) String? itemId,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? color, bool isSelf,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> extra
});




}
/// @nodoc
class __$DanmakuMessageCopyWithImpl<$Res>
    implements _$DanmakuMessageCopyWith<$Res> {
  __$DanmakuMessageCopyWithImpl(this._self, this._then);

  final _DanmakuMessage _self;
  final $Res Function(_DanmakuMessage) _then;

/// Create a copy of DanmakuMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? room = null,Object? kind = null,Object? text = null,Object? at = null,Object? senderId = freezed,Object? senderName = freezed,Object? avatar = freezed,Object? amount = freezed,Object? itemName = freezed,Object? itemId = freezed,Object? color = freezed,Object? isSelf = null,Object? extra = null,}) {
  return _then(_DanmakuMessage(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as ContentRef,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as DanmakuKind,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int?,itemName: freezed == itemName ? _self.itemName : itemName // ignore: cast_nullable_to_non_nullable
as String?,itemId: freezed == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String?,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int?,isSelf: null == isSelf ? _self.isSelf : isSelf // ignore: cast_nullable_to_non_nullable
as bool,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

// dart format on
