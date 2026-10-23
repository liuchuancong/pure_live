// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_super_chat_message.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveSuperChatMessage> _$liveSuperChatMessageSerializer = _$LiveSuperChatMessageSerializer();

class _$LiveSuperChatMessageSerializer implements StructuredSerializer<LiveSuperChatMessage> {
  @override
  final Iterable<Type> types = const [LiveSuperChatMessage, _$LiveSuperChatMessage];
  @override
  final String wireName = 'LiveSuperChatMessage';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveSuperChatMessage object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'messageId',
      serializers.serialize(object.messageId, specifiedType: const FullType(String)),
      'userName',
      serializers.serialize(object.userName, specifiedType: const FullType(String)),
      'faceUrl',
      serializers.serialize(object.faceUrl, specifiedType: const FullType(String)),
      'text',
      serializers.serialize(object.text, specifiedType: const FullType(String)),
      'price',
      serializers.serialize(object.price, specifiedType: const FullType(SuperChatPrice)),
      'display',
      serializers.serialize(object.display, specifiedType: const FullType(SuperChatDisplay)),
    ];
    Object? value;
    value = object.startTime;
    if (value != null) {
      result
        ..add('startTime')
        ..add(serializers.serialize(value, specifiedType: const FullType(DateTime)));
    }
    value = object.endTime;
    if (value != null) {
      result
        ..add('endTime')
        ..add(serializers.serialize(value, specifiedType: const FullType(DateTime)));
    }
    return result;
  }

  @override
  LiveSuperChatMessage deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveSuperChatMessageBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'messageId':
          result.messageId = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'userName':
          result.userName = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'faceUrl':
          result.faceUrl = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'text':
          result.text = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'price':
          result.price.replace(
            serializers.deserialize(value, specifiedType: const FullType(SuperChatPrice))! as SuperChatPrice,
          );
          break;
        case 'startTime':
          result.startTime = serializers.deserialize(value, specifiedType: const FullType(DateTime)) as DateTime?;
          break;
        case 'endTime':
          result.endTime = serializers.deserialize(value, specifiedType: const FullType(DateTime)) as DateTime?;
          break;
        case 'display':
          result.display.replace(
            serializers.deserialize(value, specifiedType: const FullType(SuperChatDisplay))! as SuperChatDisplay,
          );
          break;
      }
    }

    return result.build();
  }
}

class _$LiveSuperChatMessage extends LiveSuperChatMessage {
  @override
  final String messageId;
  @override
  final String userName;
  @override
  final String faceUrl;
  @override
  final String text;
  @override
  final SuperChatPrice price;
  @override
  final DateTime? startTime;
  @override
  final DateTime? endTime;
  @override
  final SuperChatDisplay display;

  factory _$LiveSuperChatMessage([void Function(LiveSuperChatMessageBuilder)? updates]) =>
      (LiveSuperChatMessageBuilder()..update(updates))._build();

  _$LiveSuperChatMessage._({
    required this.messageId,
    required this.userName,
    required this.faceUrl,
    required this.text,
    required this.price,
    this.startTime,
    this.endTime,
    required this.display,
  }) : super._();
  @override
  LiveSuperChatMessage rebuild(void Function(LiveSuperChatMessageBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LiveSuperChatMessageBuilder toBuilder() => LiveSuperChatMessageBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveSuperChatMessage &&
        messageId == other.messageId &&
        userName == other.userName &&
        faceUrl == other.faceUrl &&
        text == other.text &&
        price == other.price &&
        startTime == other.startTime &&
        endTime == other.endTime &&
        display == other.display;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, messageId.hashCode);
    _$hash = $jc(_$hash, userName.hashCode);
    _$hash = $jc(_$hash, faceUrl.hashCode);
    _$hash = $jc(_$hash, text.hashCode);
    _$hash = $jc(_$hash, price.hashCode);
    _$hash = $jc(_$hash, startTime.hashCode);
    _$hash = $jc(_$hash, endTime.hashCode);
    _$hash = $jc(_$hash, display.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveSuperChatMessage')
          ..add('messageId', messageId)
          ..add('userName', userName)
          ..add('faceUrl', faceUrl)
          ..add('text', text)
          ..add('price', price)
          ..add('startTime', startTime)
          ..add('endTime', endTime)
          ..add('display', display))
        .toString();
  }
}

class LiveSuperChatMessageBuilder implements Builder<LiveSuperChatMessage, LiveSuperChatMessageBuilder> {
  _$LiveSuperChatMessage? _$v;

  String? _messageId;
  String? get messageId => _$this._messageId;
  set messageId(String? messageId) => _$this._messageId = messageId;

  String? _userName;
  String? get userName => _$this._userName;
  set userName(String? userName) => _$this._userName = userName;

  String? _faceUrl;
  String? get faceUrl => _$this._faceUrl;
  set faceUrl(String? faceUrl) => _$this._faceUrl = faceUrl;

  String? _text;
  String? get text => _$this._text;
  set text(String? text) => _$this._text = text;

  SuperChatPriceBuilder? _price;
  SuperChatPriceBuilder get price => _$this._price ??= SuperChatPriceBuilder();
  set price(SuperChatPriceBuilder? price) => _$this._price = price;

  DateTime? _startTime;
  DateTime? get startTime => _$this._startTime;
  set startTime(DateTime? startTime) => _$this._startTime = startTime;

  DateTime? _endTime;
  DateTime? get endTime => _$this._endTime;
  set endTime(DateTime? endTime) => _$this._endTime = endTime;

  SuperChatDisplayBuilder? _display;
  SuperChatDisplayBuilder get display => _$this._display ??= SuperChatDisplayBuilder();
  set display(SuperChatDisplayBuilder? display) => _$this._display = display;

  LiveSuperChatMessageBuilder() {
    LiveSuperChatMessage._initialize(this);
  }

  LiveSuperChatMessageBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _messageId = $v.messageId;
      _userName = $v.userName;
      _faceUrl = $v.faceUrl;
      _text = $v.text;
      _price = $v.price.toBuilder();
      _startTime = $v.startTime;
      _endTime = $v.endTime;
      _display = $v.display.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveSuperChatMessage other) {
    _$v = other as _$LiveSuperChatMessage;
  }

  @override
  void update(void Function(LiveSuperChatMessageBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveSuperChatMessage build() => _build();

  _$LiveSuperChatMessage _build() {
    _$LiveSuperChatMessage _$result;
    try {
      _$result =
          _$v ??
          _$LiveSuperChatMessage._(
            messageId: BuiltValueNullFieldError.checkNotNull(messageId, r'LiveSuperChatMessage', 'messageId'),
            userName: BuiltValueNullFieldError.checkNotNull(userName, r'LiveSuperChatMessage', 'userName'),
            faceUrl: BuiltValueNullFieldError.checkNotNull(faceUrl, r'LiveSuperChatMessage', 'faceUrl'),
            text: BuiltValueNullFieldError.checkNotNull(text, r'LiveSuperChatMessage', 'text'),
            price: price.build(),
            startTime: startTime,
            endTime: endTime,
            display: display.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'price';
        price.build();

        _$failedField = 'display';
        display.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'LiveSuperChatMessage', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
