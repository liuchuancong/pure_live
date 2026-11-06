// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_super_chat_display.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<SuperChatDisplay> _$superChatDisplaySerializer = _$SuperChatDisplaySerializer();

class _$SuperChatDisplaySerializer implements StructuredSerializer<SuperChatDisplay> {
  @override
  final Iterable<Type> types = const [SuperChatDisplay, _$SuperChatDisplay];
  @override
  final String wireName = 'SuperChatDisplay';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    SuperChatDisplay object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'backgroundColor',
      serializers.serialize(object.backgroundColor, specifiedType: const FullType(String)),
      'backgroundBottomColor',
      serializers.serialize(object.backgroundBottomColor, specifiedType: const FullType(String)),
    ];

    return result;
  }

  @override
  SuperChatDisplay deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SuperChatDisplayBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'backgroundColor':
          result.backgroundColor = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'backgroundBottomColor':
          result.backgroundBottomColor =
              serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
      }
    }

    return result.build();
  }
}

class _$SuperChatDisplay extends SuperChatDisplay {
  @override
  final String backgroundColor;
  @override
  final String backgroundBottomColor;

  factory _$SuperChatDisplay([void Function(SuperChatDisplayBuilder)? updates]) =>
      (SuperChatDisplayBuilder()..update(updates))._build();

  _$SuperChatDisplay._({required this.backgroundColor, required this.backgroundBottomColor}) : super._();
  @override
  SuperChatDisplay rebuild(void Function(SuperChatDisplayBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  SuperChatDisplayBuilder toBuilder() => SuperChatDisplayBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SuperChatDisplay &&
        backgroundColor == other.backgroundColor &&
        backgroundBottomColor == other.backgroundBottomColor;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, backgroundColor.hashCode);
    _$hash = $jc(_$hash, backgroundBottomColor.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SuperChatDisplay')
          ..add('backgroundColor', backgroundColor)
          ..add('backgroundBottomColor', backgroundBottomColor))
        .toString();
  }
}

class SuperChatDisplayBuilder implements Builder<SuperChatDisplay, SuperChatDisplayBuilder> {
  _$SuperChatDisplay? _$v;

  String? _backgroundColor;
  String? get backgroundColor => _$this._backgroundColor;
  set backgroundColor(String? backgroundColor) => _$this._backgroundColor = backgroundColor;

  String? _backgroundBottomColor;
  String? get backgroundBottomColor => _$this._backgroundBottomColor;
  set backgroundBottomColor(String? backgroundBottomColor) => _$this._backgroundBottomColor = backgroundBottomColor;

  SuperChatDisplayBuilder() {
    SuperChatDisplay._initialize(this);
  }

  SuperChatDisplayBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _backgroundColor = $v.backgroundColor;
      _backgroundBottomColor = $v.backgroundBottomColor;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SuperChatDisplay other) {
    _$v = other as _$SuperChatDisplay;
  }

  @override
  void update(void Function(SuperChatDisplayBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SuperChatDisplay build() => _build();

  _$SuperChatDisplay _build() {
    final _$result =
        _$v ??
        _$SuperChatDisplay._(
          backgroundColor: BuiltValueNullFieldError.checkNotNull(
            backgroundColor,
            r'SuperChatDisplay',
            'backgroundColor',
          ),
          backgroundBottomColor: BuiltValueNullFieldError.checkNotNull(
            backgroundBottomColor,
            r'SuperChatDisplay',
            'backgroundBottomColor',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
