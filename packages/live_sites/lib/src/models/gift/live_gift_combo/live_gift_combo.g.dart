// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_gift_combo.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveGiftCombo> _$liveGiftComboSerializer = _$LiveGiftComboSerializer();

class _$LiveGiftComboSerializer implements StructuredSerializer<LiveGiftCombo> {
  @override
  final Iterable<Type> types = const [LiveGiftCombo, _$LiveGiftCombo];
  @override
  final String wireName = 'LiveGiftCombo';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveGiftCombo object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>['comboKey', serializers.serialize(object.comboKey, specifiedType: const FullType(String))];
    Object? value;
    value = object.comboTotal;
    if (value != null) {
      result
        ..add('comboTotal')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    return result;
  }

  @override
  LiveGiftCombo deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveGiftComboBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'comboKey':
          result.comboKey = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'comboTotal':
          result.comboTotal = serializers.deserialize(value, specifiedType: const FullType(int)) as int?;
          break;
      }
    }

    return result.build();
  }
}

class _$LiveGiftCombo extends LiveGiftCombo {
  @override
  final String comboKey;
  @override
  final int? comboTotal;

  factory _$LiveGiftCombo([void Function(LiveGiftComboBuilder)? updates]) =>
      (LiveGiftComboBuilder()..update(updates))._build();

  _$LiveGiftCombo._({required this.comboKey, this.comboTotal}) : super._();
  @override
  LiveGiftCombo rebuild(void Function(LiveGiftComboBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  LiveGiftComboBuilder toBuilder() => LiveGiftComboBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveGiftCombo && comboKey == other.comboKey && comboTotal == other.comboTotal;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, comboKey.hashCode);
    _$hash = $jc(_$hash, comboTotal.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveGiftCombo')
          ..add('comboKey', comboKey)
          ..add('comboTotal', comboTotal))
        .toString();
  }
}

class LiveGiftComboBuilder implements Builder<LiveGiftCombo, LiveGiftComboBuilder> {
  _$LiveGiftCombo? _$v;

  String? _comboKey;
  String? get comboKey => _$this._comboKey;
  set comboKey(String? comboKey) => _$this._comboKey = comboKey;

  int? _comboTotal;
  int? get comboTotal => _$this._comboTotal;
  set comboTotal(int? comboTotal) => _$this._comboTotal = comboTotal;

  LiveGiftComboBuilder() {
    LiveGiftCombo._initialize(this);
  }

  LiveGiftComboBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _comboKey = $v.comboKey;
      _comboTotal = $v.comboTotal;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveGiftCombo other) {
    _$v = other as _$LiveGiftCombo;
  }

  @override
  void update(void Function(LiveGiftComboBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveGiftCombo build() => _build();

  _$LiveGiftCombo _build() {
    final _$result =
        _$v ??
        _$LiveGiftCombo._(
          comboKey: BuiltValueNullFieldError.checkNotNull(comboKey, r'LiveGiftCombo', 'comboKey'),
          comboTotal: comboTotal,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
