// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_message.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveMessage> _$liveMessageSerializer = _$LiveMessageSerializer();

class _$LiveMessageSerializer implements StructuredSerializer<LiveMessage> {
  @override
  final Iterable<Type> types = const [LiveMessage, _$LiveMessage];
  @override
  final String wireName = 'LiveMessage';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveMessage object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'type',
      serializers.serialize(object.type, specifiedType: const FullType(LiveMessageType)),
      'text',
      serializers.serialize(object.text, specifiedType: const FullType(String)),
      'emotes',
      serializers.serialize(object.emotes, specifiedType: const FullType(BuiltList, const [const FullType(LiveEmote)])),
      'messageId',
      serializers.serialize(object.messageId, specifiedType: const FullType(String)),
      'isLocal',
      serializers.serialize(object.isLocal, specifiedType: const FullType(bool)),
      'replayed',
      serializers.serialize(object.replayed, specifiedType: const FullType(bool)),
      'sourceRoomId',
      serializers.serialize(object.sourceRoomId, specifiedType: const FullType(String)),
    ];
    Object? value;
    value = object.color;
    if (value != null) {
      result
        ..add('color')
        ..add(serializers.serialize(value, specifiedType: const FullType(LiveMessageColor)));
    }
    value = object.sentAt;
    if (value != null) {
      result
        ..add('sentAt')
        ..add(serializers.serialize(value, specifiedType: const FullType(DateTime)));
    }
    value = object.createdAt;
    if (value != null) {
      result
        ..add('createdAt')
        ..add(serializers.serialize(value, specifiedType: const FullType(DateTime)));
    }
    return result;
  }

  @override
  LiveMessage deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveMessageBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'type':
          result.type =
              serializers.deserialize(value, specifiedType: const FullType(LiveMessageType))! as LiveMessageType;
          break;
        case 'text':
          result.text = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'color':
          result.color =
              serializers.deserialize(value, specifiedType: const FullType(LiveMessageColor)) as LiveMessageColor?;
          break;
        case 'emotes':
          result.emotes.replace(
            serializers.deserialize(value, specifiedType: const FullType(BuiltList, const [const FullType(LiveEmote)]))!
                as BuiltList<Object?>,
          );
          break;
        case 'messageId':
          result.messageId = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'sentAt':
          result.sentAt = serializers.deserialize(value, specifiedType: const FullType(DateTime)) as DateTime?;
          break;
        case 'createdAt':
          result.createdAt = serializers.deserialize(value, specifiedType: const FullType(DateTime)) as DateTime?;
          break;
        case 'isLocal':
          result.isLocal = serializers.deserialize(value, specifiedType: const FullType(bool))! as bool;
          break;
        case 'replayed':
          result.replayed = serializers.deserialize(value, specifiedType: const FullType(bool))! as bool;
          break;
        case 'sourceRoomId':
          result.sourceRoomId = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
      }
    }

    return result.build();
  }
}

class _$LiveMessage extends LiveMessage {
  @override
  final LiveMessageType type;
  @override
  final String text;
  @override
  final MessageSender? sender;
  @override
  final LiveMessageColor? color;
  @override
  final LiveMessageStyle? style;
  @override
  final Object? payload;
  @override
  final BuiltList<LiveEmote> emotes;
  @override
  final String messageId;
  @override
  final DateTime? sentAt;
  @override
  final DateTime? createdAt;
  @override
  final bool isLocal;
  @override
  final bool replayed;
  @override
  final String sourceRoomId;

  factory _$LiveMessage([void Function(LiveMessageBuilder)? updates]) =>
      (LiveMessageBuilder()..update(updates))._build();

  _$LiveMessage._({
    required this.type,
    required this.text,
    this.sender,
    this.color,
    this.style,
    this.payload,
    required this.emotes,
    required this.messageId,
    this.sentAt,
    this.createdAt,
    required this.isLocal,
    required this.replayed,
    required this.sourceRoomId,
  }) : super._();
  @override
  LiveMessage rebuild(void Function(LiveMessageBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  LiveMessageBuilder toBuilder() => LiveMessageBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveMessage &&
        type == other.type &&
        text == other.text &&
        sender == other.sender &&
        color == other.color &&
        style == other.style &&
        payload == other.payload &&
        emotes == other.emotes &&
        messageId == other.messageId &&
        sentAt == other.sentAt &&
        createdAt == other.createdAt &&
        isLocal == other.isLocal &&
        replayed == other.replayed &&
        sourceRoomId == other.sourceRoomId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, text.hashCode);
    _$hash = $jc(_$hash, sender.hashCode);
    _$hash = $jc(_$hash, color.hashCode);
    _$hash = $jc(_$hash, style.hashCode);
    _$hash = $jc(_$hash, payload.hashCode);
    _$hash = $jc(_$hash, emotes.hashCode);
    _$hash = $jc(_$hash, messageId.hashCode);
    _$hash = $jc(_$hash, sentAt.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, isLocal.hashCode);
    _$hash = $jc(_$hash, replayed.hashCode);
    _$hash = $jc(_$hash, sourceRoomId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveMessage')
          ..add('type', type)
          ..add('text', text)
          ..add('sender', sender)
          ..add('color', color)
          ..add('style', style)
          ..add('payload', payload)
          ..add('emotes', emotes)
          ..add('messageId', messageId)
          ..add('sentAt', sentAt)
          ..add('createdAt', createdAt)
          ..add('isLocal', isLocal)
          ..add('replayed', replayed)
          ..add('sourceRoomId', sourceRoomId))
        .toString();
  }
}

class LiveMessageBuilder implements Builder<LiveMessage, LiveMessageBuilder> {
  _$LiveMessage? _$v;

  LiveMessageType? _type;
  LiveMessageType? get type => _$this._type;
  set type(LiveMessageType? type) => _$this._type = type;

  String? _text;
  String? get text => _$this._text;
  set text(String? text) => _$this._text = text;

  MessageSenderBuilder? _sender;
  MessageSenderBuilder get sender => _$this._sender ??= MessageSenderBuilder();
  set sender(MessageSenderBuilder? sender) => _$this._sender = sender;

  LiveMessageColor? _color;
  LiveMessageColor? get color => _$this._color;
  set color(LiveMessageColor? color) => _$this._color = color;

  LiveMessageStyle? _style;
  LiveMessageStyle? get style => _$this._style;
  set style(LiveMessageStyle? style) => _$this._style = style;

  Object? _payload;
  Object? get payload => _$this._payload;
  set payload(Object? payload) => _$this._payload = payload;

  ListBuilder<LiveEmote>? _emotes;
  ListBuilder<LiveEmote> get emotes => _$this._emotes ??= ListBuilder<LiveEmote>();
  set emotes(ListBuilder<LiveEmote>? emotes) => _$this._emotes = emotes;

  String? _messageId;
  String? get messageId => _$this._messageId;
  set messageId(String? messageId) => _$this._messageId = messageId;

  DateTime? _sentAt;
  DateTime? get sentAt => _$this._sentAt;
  set sentAt(DateTime? sentAt) => _$this._sentAt = sentAt;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  bool? _isLocal;
  bool? get isLocal => _$this._isLocal;
  set isLocal(bool? isLocal) => _$this._isLocal = isLocal;

  bool? _replayed;
  bool? get replayed => _$this._replayed;
  set replayed(bool? replayed) => _$this._replayed = replayed;

  String? _sourceRoomId;
  String? get sourceRoomId => _$this._sourceRoomId;
  set sourceRoomId(String? sourceRoomId) => _$this._sourceRoomId = sourceRoomId;

  LiveMessageBuilder() {
    LiveMessage._initialize(this);
  }

  LiveMessageBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _text = $v.text;
      _sender = $v.sender?.toBuilder();
      _color = $v.color;
      _style = $v.style;
      _payload = $v.payload;
      _emotes = $v.emotes.toBuilder();
      _messageId = $v.messageId;
      _sentAt = $v.sentAt;
      _createdAt = $v.createdAt;
      _isLocal = $v.isLocal;
      _replayed = $v.replayed;
      _sourceRoomId = $v.sourceRoomId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveMessage other) {
    _$v = other as _$LiveMessage;
  }

  @override
  void update(void Function(LiveMessageBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveMessage build() => _build();

  _$LiveMessage _build() {
    _$LiveMessage _$result;
    try {
      _$result =
          _$v ??
          _$LiveMessage._(
            type: BuiltValueNullFieldError.checkNotNull(type, r'LiveMessage', 'type'),
            text: BuiltValueNullFieldError.checkNotNull(text, r'LiveMessage', 'text'),
            sender: _sender?.build(),
            color: color,
            style: style,
            payload: payload,
            emotes: emotes.build(),
            messageId: BuiltValueNullFieldError.checkNotNull(messageId, r'LiveMessage', 'messageId'),
            sentAt: sentAt,
            createdAt: createdAt,
            isLocal: BuiltValueNullFieldError.checkNotNull(isLocal, r'LiveMessage', 'isLocal'),
            replayed: BuiltValueNullFieldError.checkNotNull(replayed, r'LiveMessage', 'replayed'),
            sourceRoomId: BuiltValueNullFieldError.checkNotNull(sourceRoomId, r'LiveMessage', 'sourceRoomId'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'sender';
        _sender?.build();

        _$failedField = 'emotes';
        emotes.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'LiveMessage', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
