// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_gift.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveGift> _$liveGiftSerializer = _$LiveGiftSerializer();

class _$LiveGiftSerializer implements StructuredSerializer<LiveGift> {
  @override
  final Iterable<Type> types = const [LiveGift, _$LiveGift];
  @override
  final String wireName = 'LiveGift';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveGift object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'giftId',
      serializers.serialize(object.giftId, specifiedType: const FullType(String)),
      'name',
      serializers.serialize(object.name, specifiedType: const FullType(String)),
      'kind',
      serializers.serialize(object.kind, specifiedType: const FullType(LiveGiftKind)),
      'count',
      serializers.serialize(object.count, specifiedType: const FullType(int)),
      'value',
      serializers.serialize(object.value, specifiedType: const FullType(LiveGiftValue)),
      'combo',
      serializers.serialize(object.combo, specifiedType: const FullType(LiveGiftCombo)),
      'recipientName',
      serializers.serialize(object.recipientName, specifiedType: const FullType(String)),
    ];
    Object? value;
    value = object.iconUrl;
    if (value != null) {
      result
        ..add('iconUrl')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    return result;
  }

  @override
  LiveGift deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveGiftBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'giftId':
          result.giftId = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'name':
          result.name = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'iconUrl':
          result.iconUrl = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'kind':
          result.kind = serializers.deserialize(value, specifiedType: const FullType(LiveGiftKind))! as LiveGiftKind;
          break;
        case 'count':
          result.count = serializers.deserialize(value, specifiedType: const FullType(int))! as int;
          break;
        case 'value':
          result.value.replace(
            serializers.deserialize(value, specifiedType: const FullType(LiveGiftValue))! as LiveGiftValue,
          );
          break;
        case 'combo':
          result.combo.replace(
            serializers.deserialize(value, specifiedType: const FullType(LiveGiftCombo))! as LiveGiftCombo,
          );
          break;
        case 'recipientName':
          result.recipientName = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
      }
    }

    return result.build();
  }
}

class _$LiveGift extends LiveGift {
  @override
  final String giftId;
  @override
  final String name;
  @override
  final String? iconUrl;
  @override
  final LiveGiftKind kind;
  @override
  final int count;
  @override
  final LiveGiftValue value;
  @override
  final LiveGiftCombo combo;
  @override
  final String recipientName;

  factory _$LiveGift([void Function(LiveGiftBuilder)? updates]) => (LiveGiftBuilder()..update(updates))._build();

  _$LiveGift._({
    required this.giftId,
    required this.name,
    this.iconUrl,
    required this.kind,
    required this.count,
    required this.value,
    required this.combo,
    required this.recipientName,
  }) : super._();
  @override
  LiveGift rebuild(void Function(LiveGiftBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  LiveGiftBuilder toBuilder() => LiveGiftBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveGift &&
        giftId == other.giftId &&
        name == other.name &&
        iconUrl == other.iconUrl &&
        kind == other.kind &&
        count == other.count &&
        value == other.value &&
        combo == other.combo &&
        recipientName == other.recipientName;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, giftId.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, iconUrl.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, count.hashCode);
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jc(_$hash, combo.hashCode);
    _$hash = $jc(_$hash, recipientName.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveGift')
          ..add('giftId', giftId)
          ..add('name', name)
          ..add('iconUrl', iconUrl)
          ..add('kind', kind)
          ..add('count', count)
          ..add('value', value)
          ..add('combo', combo)
          ..add('recipientName', recipientName))
        .toString();
  }
}

class LiveGiftBuilder implements Builder<LiveGift, LiveGiftBuilder> {
  _$LiveGift? _$v;

  String? _giftId;
  String? get giftId => _$this._giftId;
  set giftId(String? giftId) => _$this._giftId = giftId;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _iconUrl;
  String? get iconUrl => _$this._iconUrl;
  set iconUrl(String? iconUrl) => _$this._iconUrl = iconUrl;

  LiveGiftKind? _kind;
  LiveGiftKind? get kind => _$this._kind;
  set kind(LiveGiftKind? kind) => _$this._kind = kind;

  int? _count;
  int? get count => _$this._count;
  set count(int? count) => _$this._count = count;

  LiveGiftValueBuilder? _value;
  LiveGiftValueBuilder get value => _$this._value ??= LiveGiftValueBuilder();
  set value(LiveGiftValueBuilder? value) => _$this._value = value;

  LiveGiftComboBuilder? _combo;
  LiveGiftComboBuilder get combo => _$this._combo ??= LiveGiftComboBuilder();
  set combo(LiveGiftComboBuilder? combo) => _$this._combo = combo;

  String? _recipientName;
  String? get recipientName => _$this._recipientName;
  set recipientName(String? recipientName) => _$this._recipientName = recipientName;

  LiveGiftBuilder() {
    LiveGift._initialize(this);
  }

  LiveGiftBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _giftId = $v.giftId;
      _name = $v.name;
      _iconUrl = $v.iconUrl;
      _kind = $v.kind;
      _count = $v.count;
      _value = $v.value.toBuilder();
      _combo = $v.combo.toBuilder();
      _recipientName = $v.recipientName;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveGift other) {
    _$v = other as _$LiveGift;
  }

  @override
  void update(void Function(LiveGiftBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveGift build() => _build();

  _$LiveGift _build() {
    _$LiveGift _$result;
    try {
      _$result =
          _$v ??
          _$LiveGift._(
            giftId: BuiltValueNullFieldError.checkNotNull(giftId, r'LiveGift', 'giftId'),
            name: BuiltValueNullFieldError.checkNotNull(name, r'LiveGift', 'name'),
            iconUrl: iconUrl,
            kind: BuiltValueNullFieldError.checkNotNull(kind, r'LiveGift', 'kind'),
            count: BuiltValueNullFieldError.checkNotNull(count, r'LiveGift', 'count'),
            value: value.build(),
            combo: combo.build(),
            recipientName: BuiltValueNullFieldError.checkNotNull(recipientName, r'LiveGift', 'recipientName'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'value';
        value.build();
        _$failedField = 'combo';
        combo.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'LiveGift', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
