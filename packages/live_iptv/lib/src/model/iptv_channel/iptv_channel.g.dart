// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_channel.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<IptvChannel> _$iptvChannelSerializer = _$IptvChannelSerializer();

class _$IptvChannelSerializer implements StructuredSerializer<IptvChannel> {
  @override
  final Iterable<Type> types = const [IptvChannel, _$IptvChannel];
  @override
  final String wireName = 'IptvChannel';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    IptvChannel object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'id',
      serializers.serialize(object.id, specifiedType: const FullType(String)),
      'entry',
      serializers.serialize(
        object.entry,
        specifiedType: const FullType(IptvEntry),
      ),
      'favorite',
      serializers.serialize(
        object.favorite,
        specifiedType: const FullType(bool),
      ),
      'hidden',
      serializers.serialize(object.hidden, specifiedType: const FullType(bool)),
      'pinned',
      serializers.serialize(object.pinned, specifiedType: const FullType(bool)),
      'position',
      serializers.serialize(
        object.position,
        specifiedType: const FullType(int),
      ),
    ];
    Object? value;
    value = object.number;
    if (value != null) {
      result
        ..add('number')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    return result;
  }

  @override
  IptvChannel deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IptvChannelBuilder();

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
        case 'entry':
          result.entry.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(IptvEntry),
                )!
                as IptvEntry,
          );
          break;
        case 'favorite':
          result.favorite =
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
        case 'pinned':
          result.pinned =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'position':
          result.position =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'number':
          result.number = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
      }
    }

    return result.build();
  }
}

class _$IptvChannel extends IptvChannel {
  @override
  final String id;
  @override
  final IptvEntry entry;
  @override
  final bool favorite;
  @override
  final bool hidden;
  @override
  final bool pinned;
  @override
  final int position;
  @override
  final int? number;

  factory _$IptvChannel([void Function(IptvChannelBuilder)? updates]) =>
      (IptvChannelBuilder()..update(updates))._build();

  _$IptvChannel._({
    required this.id,
    required this.entry,
    required this.favorite,
    required this.hidden,
    required this.pinned,
    required this.position,
    this.number,
  }) : super._();
  @override
  IptvChannel rebuild(void Function(IptvChannelBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IptvChannelBuilder toBuilder() => IptvChannelBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IptvChannel &&
        id == other.id &&
        entry == other.entry &&
        favorite == other.favorite &&
        hidden == other.hidden &&
        pinned == other.pinned &&
        position == other.position &&
        number == other.number;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, entry.hashCode);
    _$hash = $jc(_$hash, favorite.hashCode);
    _$hash = $jc(_$hash, hidden.hashCode);
    _$hash = $jc(_$hash, pinned.hashCode);
    _$hash = $jc(_$hash, position.hashCode);
    _$hash = $jc(_$hash, number.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IptvChannel')
          ..add('id', id)
          ..add('entry', entry)
          ..add('favorite', favorite)
          ..add('hidden', hidden)
          ..add('pinned', pinned)
          ..add('position', position)
          ..add('number', number))
        .toString();
  }
}

class IptvChannelBuilder implements Builder<IptvChannel, IptvChannelBuilder> {
  _$IptvChannel? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  IptvEntryBuilder? _entry;
  IptvEntryBuilder get entry => _$this._entry ??= IptvEntryBuilder();
  set entry(IptvEntryBuilder? entry) => _$this._entry = entry;

  bool? _favorite;
  bool? get favorite => _$this._favorite;
  set favorite(bool? favorite) => _$this._favorite = favorite;

  bool? _hidden;
  bool? get hidden => _$this._hidden;
  set hidden(bool? hidden) => _$this._hidden = hidden;

  bool? _pinned;
  bool? get pinned => _$this._pinned;
  set pinned(bool? pinned) => _$this._pinned = pinned;

  int? _position;
  int? get position => _$this._position;
  set position(int? position) => _$this._position = position;

  int? _number;
  int? get number => _$this._number;
  set number(int? number) => _$this._number = number;

  IptvChannelBuilder() {
    IptvChannel._initialize(this);
  }

  IptvChannelBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _entry = $v.entry.toBuilder();
      _favorite = $v.favorite;
      _hidden = $v.hidden;
      _pinned = $v.pinned;
      _position = $v.position;
      _number = $v.number;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IptvChannel other) {
    _$v = other as _$IptvChannel;
  }

  @override
  void update(void Function(IptvChannelBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IptvChannel build() => _build();

  _$IptvChannel _build() {
    _$IptvChannel _$result;
    try {
      _$result =
          _$v ??
          _$IptvChannel._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'IptvChannel', 'id'),
            entry: entry.build(),
            favorite: BuiltValueNullFieldError.checkNotNull(
              favorite,
              r'IptvChannel',
              'favorite',
            ),
            hidden: BuiltValueNullFieldError.checkNotNull(
              hidden,
              r'IptvChannel',
              'hidden',
            ),
            pinned: BuiltValueNullFieldError.checkNotNull(
              pinned,
              r'IptvChannel',
              'pinned',
            ),
            position: BuiltValueNullFieldError.checkNotNull(
              position,
              r'IptvChannel',
              'position',
            ),
            number: number,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'entry';
        entry.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'IptvChannel',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
