// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_source.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<EpgSource> _$epgSourceSerializer = _$EpgSourceSerializer();

class _$EpgSourceSerializer implements StructuredSerializer<EpgSource> {
  @override
  final Iterable<Type> types = const [EpgSource, _$EpgSource];
  @override
  final String wireName = 'EpgSource';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    EpgSource object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'id',
      serializers.serialize(object.id, specifiedType: const FullType(String)),
      'name',
      serializers.serialize(object.name, specifiedType: const FullType(String)),
      'source',
      serializers.serialize(
        object.source,
        specifiedType: const FullType(String),
      ),
      'autoUpdate',
      serializers.serialize(
        object.autoUpdate,
        specifiedType: const FullType(bool),
      ),
    ];
    Object? value;
    value = object.lastRefresh;
    if (value != null) {
      result
        ..add('lastRefresh')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(DateTime)),
        );
    }
    value = object.createdAt;
    if (value != null) {
      result
        ..add('createdAt')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(DateTime)),
        );
    }
    return result;
  }

  @override
  EpgSource deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EpgSourceBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'id':
          result.id =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'name':
          result.name =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'source':
          result.source =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'lastRefresh':
          result.lastRefresh = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime?;
          break;
        case 'createdAt':
          result.createdAt = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime?;
          break;
        case 'autoUpdate':
          result.autoUpdate =
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

class _$EpgSource extends EpgSource {
  @override
  final String id;
  @override
  final String name;
  @override
  final String source;
  @override
  final DateTime? lastRefresh;
  @override
  final DateTime? createdAt;
  @override
  final bool autoUpdate;

  factory _$EpgSource([void Function(EpgSourceBuilder)? updates]) =>
      (EpgSourceBuilder()..update(updates))._build();

  _$EpgSource._({
    required this.id,
    required this.name,
    required this.source,
    this.lastRefresh,
    this.createdAt,
    required this.autoUpdate,
  }) : super._();
  @override
  EpgSource rebuild(void Function(EpgSourceBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EpgSourceBuilder toBuilder() => EpgSourceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EpgSource &&
        id == other.id &&
        name == other.name &&
        source == other.source &&
        lastRefresh == other.lastRefresh &&
        createdAt == other.createdAt &&
        autoUpdate == other.autoUpdate;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, source.hashCode);
    _$hash = $jc(_$hash, lastRefresh.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, autoUpdate.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EpgSource')
          ..add('id', id)
          ..add('name', name)
          ..add('source', source)
          ..add('lastRefresh', lastRefresh)
          ..add('createdAt', createdAt)
          ..add('autoUpdate', autoUpdate))
        .toString();
  }
}

class EpgSourceBuilder implements Builder<EpgSource, EpgSourceBuilder> {
  _$EpgSource? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _source;
  String? get source => _$this._source;
  set source(String? source) => _$this._source = source;

  DateTime? _lastRefresh;
  DateTime? get lastRefresh => _$this._lastRefresh;
  set lastRefresh(DateTime? lastRefresh) => _$this._lastRefresh = lastRefresh;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  bool? _autoUpdate;
  bool? get autoUpdate => _$this._autoUpdate;
  set autoUpdate(bool? autoUpdate) => _$this._autoUpdate = autoUpdate;

  EpgSourceBuilder() {
    EpgSource._initialize(this);
  }

  EpgSourceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _source = $v.source;
      _lastRefresh = $v.lastRefresh;
      _createdAt = $v.createdAt;
      _autoUpdate = $v.autoUpdate;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EpgSource other) {
    _$v = other as _$EpgSource;
  }

  @override
  void update(void Function(EpgSourceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EpgSource build() => _build();

  _$EpgSource _build() {
    final _$result =
        _$v ??
        _$EpgSource._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'EpgSource', 'id'),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'EpgSource',
            'name',
          ),
          source: BuiltValueNullFieldError.checkNotNull(
            source,
            r'EpgSource',
            'source',
          ),
          lastRefresh: lastRefresh,
          createdAt: createdAt,
          autoUpdate: BuiltValueNullFieldError.checkNotNull(
            autoUpdate,
            r'EpgSource',
            'autoUpdate',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
