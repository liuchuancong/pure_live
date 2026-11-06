// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_gift_value.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveGiftValue> _$liveGiftValueSerializer = _$LiveGiftValueSerializer();

class _$LiveGiftValueSerializer implements StructuredSerializer<LiveGiftValue> {
  @override
  final Iterable<Type> types = const [LiveGiftValue, _$LiveGiftValue];
  @override
  final String wireName = 'LiveGiftValue';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveGiftValue object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>['unit', serializers.serialize(object.unit, specifiedType: const FullType(LiveGiftUnit))];
    Object? value;
    value = object.unitPrice;
    if (value != null) {
      result
        ..add('unitPrice')
        ..add(serializers.serialize(value, specifiedType: const FullType(double)));
    }
    value = object.totalValue;
    if (value != null) {
      result
        ..add('totalValue')
        ..add(serializers.serialize(value, specifiedType: const FullType(double)));
    }
    return result;
  }

  @override
  LiveGiftValue deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveGiftValueBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'unit':
          result.unit = serializers.deserialize(value, specifiedType: const FullType(LiveGiftUnit))! as LiveGiftUnit;
          break;
        case 'unitPrice':
          result.unitPrice = serializers.deserialize(value, specifiedType: const FullType(double)) as double?;
          break;
        case 'totalValue':
          result.totalValue = serializers.deserialize(value, specifiedType: const FullType(double)) as double?;
          break;
      }
    }

    return result.build();
  }
}

class _$LiveGiftValue extends LiveGiftValue {
  @override
  final LiveGiftUnit unit;
  @override
  final double? unitPrice;
  @override
  final double? totalValue;

  factory _$LiveGiftValue([void Function(LiveGiftValueBuilder)? updates]) =>
      (LiveGiftValueBuilder()..update(updates))._build();

  _$LiveGiftValue._({required this.unit, this.unitPrice, this.totalValue}) : super._();
  @override
  LiveGiftValue rebuild(void Function(LiveGiftValueBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  LiveGiftValueBuilder toBuilder() => LiveGiftValueBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveGiftValue &&
        unit == other.unit &&
        unitPrice == other.unitPrice &&
        totalValue == other.totalValue;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, unit.hashCode);
    _$hash = $jc(_$hash, unitPrice.hashCode);
    _$hash = $jc(_$hash, totalValue.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveGiftValue')
          ..add('unit', unit)
          ..add('unitPrice', unitPrice)
          ..add('totalValue', totalValue))
        .toString();
  }
}

class LiveGiftValueBuilder implements Builder<LiveGiftValue, LiveGiftValueBuilder> {
  _$LiveGiftValue? _$v;

  LiveGiftUnit? _unit;
  LiveGiftUnit? get unit => _$this._unit;
  set unit(LiveGiftUnit? unit) => _$this._unit = unit;

  double? _unitPrice;
  double? get unitPrice => _$this._unitPrice;
  set unitPrice(double? unitPrice) => _$this._unitPrice = unitPrice;

  double? _totalValue;
  double? get totalValue => _$this._totalValue;
  set totalValue(double? totalValue) => _$this._totalValue = totalValue;

  LiveGiftValueBuilder() {
    LiveGiftValue._initialize(this);
  }

  LiveGiftValueBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _unit = $v.unit;
      _unitPrice = $v.unitPrice;
      _totalValue = $v.totalValue;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveGiftValue other) {
    _$v = other as _$LiveGiftValue;
  }

  @override
  void update(void Function(LiveGiftValueBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveGiftValue build() => _build();

  _$LiveGiftValue _build() {
    final _$result =
        _$v ??
        _$LiveGiftValue._(
          unit: BuiltValueNullFieldError.checkNotNull(unit, r'LiveGiftValue', 'unit'),
          unitPrice: unitPrice,
          totalValue: totalValue,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
