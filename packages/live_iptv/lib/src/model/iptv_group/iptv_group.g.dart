// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_group.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<IptvGroup> _$iptvGroupSerializer = _$IptvGroupSerializer();

class _$IptvGroupSerializer implements StructuredSerializer<IptvGroup> {
  @override
  final Iterable<Type> types = const [IptvGroup, _$IptvGroup];
  @override
  final String wireName = 'IptvGroup';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    IptvGroup object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'name',
      serializers.serialize(object.name, specifiedType: const FullType(String)),
      'order',
      serializers.serialize(object.order, specifiedType: const FullType(int)),
      'pinned',
      serializers.serialize(object.pinned, specifiedType: const FullType(bool)),
      'hidden',
      serializers.serialize(object.hidden, specifiedType: const FullType(bool)),
    ];

    return result;
  }

  @override
  IptvGroup deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IptvGroupBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'name':
          result.name =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'order':
          result.order =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'pinned':
          result.pinned =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'hidden':
          result.hidden =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
      }
    }

    return result.build();
  }
}

class _$IptvGroup extends IptvGroup {
  @override
  final String name;
  @override
  final int order;
  @override
  final bool pinned;
  @override
  final bool hidden;

  factory _$IptvGroup([void Function(IptvGroupBuilder)? updates]) =>
      (IptvGroupBuilder()..update(updates))._build();

  _$IptvGroup._({
    required this.name,
    required this.order,
    required this.pinned,
    required this.hidden,
  }) : super._();
  @override
  IptvGroup rebuild(void Function(IptvGroupBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IptvGroupBuilder toBuilder() => IptvGroupBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IptvGroup &&
        name == other.name &&
        order == other.order &&
        pinned == other.pinned &&
        hidden == other.hidden;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, order.hashCode);
    _$hash = $jc(_$hash, pinned.hashCode);
    _$hash = $jc(_$hash, hidden.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IptvGroup')
          ..add('name', name)
          ..add('order', order)
          ..add('pinned', pinned)
          ..add('hidden', hidden))
        .toString();
  }
}

class IptvGroupBuilder implements Builder<IptvGroup, IptvGroupBuilder> {
  _$IptvGroup? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  int? _order;
  int? get order => _$this._order;
  set order(int? order) => _$this._order = order;

  bool? _pinned;
  bool? get pinned => _$this._pinned;
  set pinned(bool? pinned) => _$this._pinned = pinned;

  bool? _hidden;
  bool? get hidden => _$this._hidden;
  set hidden(bool? hidden) => _$this._hidden = hidden;

  IptvGroupBuilder() {
    IptvGroup._initialize(this);
  }

  IptvGroupBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _order = $v.order;
      _pinned = $v.pinned;
      _hidden = $v.hidden;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IptvGroup other) {
    _$v = other as _$IptvGroup;
  }

  @override
  void update(void Function(IptvGroupBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IptvGroup build() => _build();

  _$IptvGroup _build() {
    final _$result =
        _$v ??
        _$IptvGroup._(
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'IptvGroup',
            'name',
          ),
          order: BuiltValueNullFieldError.checkNotNull(
            order,
            r'IptvGroup',
            'order',
          ),
          pinned: BuiltValueNullFieldError.checkNotNull(
            pinned,
            r'IptvGroup',
            'pinned',
          ),
          hidden: BuiltValueNullFieldError.checkNotNull(
            hidden,
            r'IptvGroup',
            'hidden',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
