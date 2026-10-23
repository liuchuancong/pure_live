// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_super_chat_price.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<SuperChatPrice> _$superChatPriceSerializer = _$SuperChatPriceSerializer();

class _$SuperChatPriceSerializer implements StructuredSerializer<SuperChatPrice> {
  @override
  final Iterable<Type> types = const [SuperChatPrice, _$SuperChatPrice];
  @override
  final String wireName = 'SuperChatPrice';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    SuperChatPrice object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'displayText',
      serializers.serialize(object.displayText, specifiedType: const FullType(String)),
    ];
    Object? value;
    value = object.amount;
    if (value != null) {
      result
        ..add('amount')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.currency;
    if (value != null) {
      result
        ..add('currency')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    return result;
  }

  @override
  SuperChatPrice deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SuperChatPriceBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'amount':
          result.amount = serializers.deserialize(value, specifiedType: const FullType(int)) as int?;
          break;
        case 'currency':
          result.currency = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'displayText':
          result.displayText = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
      }
    }

    return result.build();
  }
}

class _$SuperChatPrice extends SuperChatPrice {
  @override
  final int? amount;
  @override
  final String? currency;
  @override
  final String displayText;

  factory _$SuperChatPrice([void Function(SuperChatPriceBuilder)? updates]) =>
      (SuperChatPriceBuilder()..update(updates))._build();

  _$SuperChatPrice._({this.amount, this.currency, required this.displayText}) : super._();
  @override
  SuperChatPrice rebuild(void Function(SuperChatPriceBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  SuperChatPriceBuilder toBuilder() => SuperChatPriceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SuperChatPrice &&
        amount == other.amount &&
        currency == other.currency &&
        displayText == other.displayText;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, amount.hashCode);
    _$hash = $jc(_$hash, currency.hashCode);
    _$hash = $jc(_$hash, displayText.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SuperChatPrice')
          ..add('amount', amount)
          ..add('currency', currency)
          ..add('displayText', displayText))
        .toString();
  }
}

class SuperChatPriceBuilder implements Builder<SuperChatPrice, SuperChatPriceBuilder> {
  _$SuperChatPrice? _$v;

  int? _amount;
  int? get amount => _$this._amount;
  set amount(int? amount) => _$this._amount = amount;

  String? _currency;
  String? get currency => _$this._currency;
  set currency(String? currency) => _$this._currency = currency;

  String? _displayText;
  String? get displayText => _$this._displayText;
  set displayText(String? displayText) => _$this._displayText = displayText;

  SuperChatPriceBuilder() {
    SuperChatPrice._initialize(this);
  }

  SuperChatPriceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _amount = $v.amount;
      _currency = $v.currency;
      _displayText = $v.displayText;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SuperChatPrice other) {
    _$v = other as _$SuperChatPrice;
  }

  @override
  void update(void Function(SuperChatPriceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SuperChatPrice build() => _build();

  _$SuperChatPrice _build() {
    final _$result =
        _$v ??
        _$SuperChatPrice._(
          amount: amount,
          currency: currency,
          displayText: BuiltValueNullFieldError.checkNotNull(displayText, r'SuperChatPrice', 'displayText'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
