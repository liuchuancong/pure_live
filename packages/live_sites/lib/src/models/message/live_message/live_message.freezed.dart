// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveMessage {

 LiveMessageType get type; String get text; MessageSender? get sender; LiveMessageColor? get color;@JsonKey(includeFromJson: false, includeToJson: false) LiveMessageStyle? get style; Object? get payload; List<LiveEmote> get emotes; String get messageId; DateTime? get sentAt; DateTime? get createdAt; bool get isLocal; bool get replayed; String get sourceRoomId;
/// Create a copy of LiveMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveMessageCopyWith<LiveMessage> get copyWith => _$LiveMessageCopyWithImpl<LiveMessage>(this as LiveMessage, _$identity);

  /// Serializes this LiveMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveMessage&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.sender, _this.sender) || other.sender == _this.sender)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.style, _this.style) || other.style == _this.style)&&const DeepCollectionEquality().equals(other.payload, _this.payload)&&const DeepCollectionEquality().equals(other.emotes, _this.emotes)&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId)&&(identical(other.sentAt, _this.sentAt) || other.sentAt == _this.sentAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.isLocal, _this.isLocal) || other.isLocal == _this.isLocal)&&(identical(other.replayed, _this.replayed) || other.replayed == _this.replayed)&&(identical(other.sourceRoomId, _this.sourceRoomId) || other.sourceRoomId == _this.sourceRoomId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveMessage;
  return Object.hash(runtimeType,_this.type,_this.text,_this.sender,_this.color,_this.style,const DeepCollectionEquality().hash(_this.payload),const DeepCollectionEquality().hash(_this.emotes),_this.messageId,_this.sentAt,_this.createdAt,_this.isLocal,_this.replayed,_this.sourceRoomId);
}

@override
String toString() {
  final _this = this as LiveMessage;
  return 'LiveMessage(type: ${_this.type}, text: ${_this.text}, sender: ${_this.sender}, color: ${_this.color}, style: ${_this.style}, payload: ${_this.payload}, emotes: ${_this.emotes}, messageId: ${_this.messageId}, sentAt: ${_this.sentAt}, createdAt: ${_this.createdAt}, isLocal: ${_this.isLocal}, replayed: ${_this.replayed}, sourceRoomId: ${_this.sourceRoomId})';
}


}

/// @nodoc
abstract mixin class $LiveMessageCopyWith<$Res>  {
  factory $LiveMessageCopyWith(LiveMessage value, $Res Function(LiveMessage) _then) = _$LiveMessageCopyWithImpl;
@useResult
$Res call({
 LiveMessageType type, String text, MessageSender? sender, LiveMessageColor? color,@JsonKey(includeFromJson: false, includeToJson: false) LiveMessageStyle? style, Object? payload, List<LiveEmote> emotes, String messageId, DateTime? sentAt, DateTime? createdAt, bool isLocal, bool replayed, String sourceRoomId
});


$MessageSenderCopyWith<$Res>? get sender;$LiveMessageColorCopyWith<$Res>? get color;$LiveMessageStyleCopyWith<$Res>? get style;

}
/// @nodoc
class _$LiveMessageCopyWithImpl<$Res>
    implements $LiveMessageCopyWith<$Res> {
  _$LiveMessageCopyWithImpl(this._self, this._then);

  final LiveMessage _self;
  final $Res Function(LiveMessage) _then;

/// Create a copy of LiveMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? text = null,Object? sender = freezed,Object? color = freezed,Object? style = freezed,Object? payload = freezed,Object? emotes = null,Object? messageId = null,Object? sentAt = freezed,Object? createdAt = freezed,Object? isLocal = null,Object? replayed = null,Object? sourceRoomId = null,}) {
  return _then(LiveMessage(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LiveMessageType,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,sender: freezed == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as MessageSender?,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as LiveMessageColor?,style: freezed == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as LiveMessageStyle?,payload: freezed == payload ? _self.payload : payload ,emotes: null == emotes ? _self.emotes : emotes // ignore: cast_nullable_to_non_nullable
as List<LiveEmote>,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isLocal: null == isLocal ? _self.isLocal : isLocal // ignore: cast_nullable_to_non_nullable
as bool,replayed: null == replayed ? _self.replayed : replayed // ignore: cast_nullable_to_non_nullable
as bool,sourceRoomId: null == sourceRoomId ? _self.sourceRoomId : sourceRoomId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of LiveMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageSenderCopyWith<$Res>? get sender {
    if (_self.sender == null) {
    return null;
  }

  return $MessageSenderCopyWith<$Res>(_self.sender!, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of LiveMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveMessageColorCopyWith<$Res>? get color {
    if (_self.color == null) {
    return null;
  }

  return $LiveMessageColorCopyWith<$Res>(_self.color!, (value) {
    return _then(_self.copyWith(color: value));
  });
}/// Create a copy of LiveMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveMessageStyleCopyWith<$Res>? get style {
    if (_self.style == null) {
    return null;
  }

  return $LiveMessageStyleCopyWith<$Res>(_self.style!, (value) {
    return _then(_self.copyWith(style: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveMessage].
extension LiveMessagePatterns on LiveMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveMessage value)  $default,){
final _that = this;
switch (_that) {
case _LiveMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveMessage value)?  $default,){
final _that = this;
switch (_that) {
case _LiveMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveMessageType type,  String text,  MessageSender? sender,  LiveMessageColor? color, @JsonKey(includeFromJson: false, includeToJson: false)  LiveMessageStyle? style,  Object? payload,  List<LiveEmote> emotes,  String messageId,  DateTime? sentAt,  DateTime? createdAt,  bool isLocal,  bool replayed,  String sourceRoomId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveMessage() when $default != null:
return $default(_that.type,_that.text,_that.sender,_that.color,_that.style,_that.payload,_that.emotes,_that.messageId,_that.sentAt,_that.createdAt,_that.isLocal,_that.replayed,_that.sourceRoomId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveMessageType type,  String text,  MessageSender? sender,  LiveMessageColor? color, @JsonKey(includeFromJson: false, includeToJson: false)  LiveMessageStyle? style,  Object? payload,  List<LiveEmote> emotes,  String messageId,  DateTime? sentAt,  DateTime? createdAt,  bool isLocal,  bool replayed,  String sourceRoomId)  $default,) {final _that = this;
switch (_that) {
case _LiveMessage():
return $default(_that.type,_that.text,_that.sender,_that.color,_that.style,_that.payload,_that.emotes,_that.messageId,_that.sentAt,_that.createdAt,_that.isLocal,_that.replayed,_that.sourceRoomId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveMessageType type,  String text,  MessageSender? sender,  LiveMessageColor? color, @JsonKey(includeFromJson: false, includeToJson: false)  LiveMessageStyle? style,  Object? payload,  List<LiveEmote> emotes,  String messageId,  DateTime? sentAt,  DateTime? createdAt,  bool isLocal,  bool replayed,  String sourceRoomId)?  $default,) {final _that = this;
switch (_that) {
case _LiveMessage() when $default != null:
return $default(_that.type,_that.text,_that.sender,_that.color,_that.style,_that.payload,_that.emotes,_that.messageId,_that.sentAt,_that.createdAt,_that.isLocal,_that.replayed,_that.sourceRoomId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveMessage implements LiveMessage {
  const _LiveMessage({required this.type, this.text = '', this.sender, this.color, @JsonKey(includeFromJson: false, includeToJson: false) this.style, this.payload,  List<LiveEmote> emotes = const [], this.messageId = '', this.sentAt, this.createdAt, this.isLocal = false, this.replayed = false, this.sourceRoomId = ''}): _emotes = emotes;
  factory _LiveMessage.fromJson(Map<String, dynamic> json) => _$LiveMessageFromJson(json);

@override final  LiveMessageType type;
@override@JsonKey() final  String text;
@override final  MessageSender? sender;
@override final  LiveMessageColor? color;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  LiveMessageStyle? style;
@override final  Object? payload;
 final  List<LiveEmote> _emotes;
@override@JsonKey() List<LiveEmote> get emotes {
  if (_emotes is EqualUnmodifiableListView) return _emotes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_emotes);
}

@override@JsonKey() final  String messageId;
@override final  DateTime? sentAt;
@override final  DateTime? createdAt;
@override@JsonKey() final  bool isLocal;
@override@JsonKey() final  bool replayed;
@override@JsonKey() final  String sourceRoomId;

/// Create a copy of LiveMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveMessageCopyWith<_LiveMessage> get copyWith => __$LiveMessageCopyWithImpl<_LiveMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveMessage&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.color, color) || other.color == color)&&(identical(other.style, style) || other.style == style)&&const DeepCollectionEquality().equals(other.payload, payload)&&const DeepCollectionEquality().equals(other.emotes, _emotes)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isLocal, isLocal) || other.isLocal == isLocal)&&(identical(other.replayed, replayed) || other.replayed == replayed)&&(identical(other.sourceRoomId, sourceRoomId) || other.sourceRoomId == sourceRoomId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,text,sender,color,style,const DeepCollectionEquality().hash(payload),const DeepCollectionEquality().hash(_emotes),messageId,sentAt,createdAt,isLocal,replayed,sourceRoomId);
}

@override
String toString() {
    return 'LiveMessage(type: $type, text: $text, sender: $sender, color: $color, style: $style, payload: $payload, emotes: $emotes, messageId: $messageId, sentAt: $sentAt, createdAt: $createdAt, isLocal: $isLocal, replayed: $replayed, sourceRoomId: $sourceRoomId)';
}


}

/// @nodoc
abstract mixin class _$LiveMessageCopyWith<$Res> implements $LiveMessageCopyWith<$Res> {
  factory _$LiveMessageCopyWith(_LiveMessage value, $Res Function(_LiveMessage) _then) = __$LiveMessageCopyWithImpl;
@override @useResult
$Res call({
 LiveMessageType type, String text, MessageSender? sender, LiveMessageColor? color,@JsonKey(includeFromJson: false, includeToJson: false) LiveMessageStyle? style, Object? payload, List<LiveEmote> emotes, String messageId, DateTime? sentAt, DateTime? createdAt, bool isLocal, bool replayed, String sourceRoomId
});


@override $MessageSenderCopyWith<$Res>? get sender;@override $LiveMessageColorCopyWith<$Res>? get color;@override $LiveMessageStyleCopyWith<$Res>? get style;

}
/// @nodoc
class __$LiveMessageCopyWithImpl<$Res>
    implements _$LiveMessageCopyWith<$Res> {
  __$LiveMessageCopyWithImpl(this._self, this._then);

  final _LiveMessage _self;
  final $Res Function(_LiveMessage) _then;

/// Create a copy of LiveMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? text = null,Object? sender = freezed,Object? color = freezed,Object? style = freezed,Object? payload = freezed,Object? emotes = null,Object? messageId = null,Object? sentAt = freezed,Object? createdAt = freezed,Object? isLocal = null,Object? replayed = null,Object? sourceRoomId = null,}) {
  return _then(_LiveMessage(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LiveMessageType,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,sender: freezed == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as MessageSender?,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as LiveMessageColor?,style: freezed == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as LiveMessageStyle?,payload: freezed == payload ? _self.payload : payload ,emotes: null == emotes ? _self._emotes : emotes // ignore: cast_nullable_to_non_nullable
as List<LiveEmote>,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isLocal: null == isLocal ? _self.isLocal : isLocal // ignore: cast_nullable_to_non_nullable
as bool,replayed: null == replayed ? _self.replayed : replayed // ignore: cast_nullable_to_non_nullable
as bool,sourceRoomId: null == sourceRoomId ? _self.sourceRoomId : sourceRoomId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of LiveMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageSenderCopyWith<$Res>? get sender {
    if (_self.sender == null) {
    return null;
  }

  return $MessageSenderCopyWith<$Res>(_self.sender!, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of LiveMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveMessageColorCopyWith<$Res>? get color {
    if (_self.color == null) {
    return null;
  }

  return $LiveMessageColorCopyWith<$Res>(_self.color!, (value) {
    return _then(_self.copyWith(color: value));
  });
}/// Create a copy of LiveMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveMessageStyleCopyWith<$Res>? get style {
    if (_self.style == null) {
    return null;
  }

  return $LiveMessageStyleCopyWith<$Res>(_self.style!, (value) {
    return _then(_self.copyWith(style: value));
  });
}
}

// dart format on
