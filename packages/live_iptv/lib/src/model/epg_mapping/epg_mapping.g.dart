// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_mapping.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<EpgMapping> _$epgMappingSerializer = _$EpgMappingSerializer();

class _$EpgMappingSerializer implements StructuredSerializer<EpgMapping> {
  @override
  final Iterable<Type> types = const [EpgMapping, _$EpgMapping];
  @override
  final String wireName = 'EpgMapping';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    EpgMapping object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'channelId',
      serializers.serialize(
        object.channelId,
        specifiedType: const FullType(String),
      ),
      'epgChannelKey',
      serializers.serialize(
        object.epgChannelKey,
        specifiedType: const FullType(String),
      ),
      'playlistId',
      serializers.serialize(
        object.playlistId,
        specifiedType: const FullType(String),
      ),
      'epgSourceId',
      serializers.serialize(
        object.epgSourceId,
        specifiedType: const FullType(String),
      ),
      'locked',
      serializers.serialize(object.locked, specifiedType: const FullType(bool)),
      'origin',
      serializers.serialize(
        object.origin,
        specifiedType: const FullType(String),
      ),
    ];

    return result;
  }

  @override
  EpgMapping deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EpgMappingBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'channelId':
          result.channelId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'epgChannelKey':
          result.epgChannelKey =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'playlistId':
          result.playlistId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'epgSourceId':
          result.epgSourceId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'locked':
          result.locked =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'origin':
          result.origin =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
      }
    }

    return result.build();
  }
}

class _$EpgMapping extends EpgMapping {
  @override
  final String channelId;
  @override
  final String epgChannelKey;
  @override
  final String playlistId;
  @override
  final String epgSourceId;
  @override
  final bool locked;
  @override
  final String origin;

  factory _$EpgMapping([void Function(EpgMappingBuilder)? updates]) =>
      (EpgMappingBuilder()..update(updates))._build();

  _$EpgMapping._({
    required this.channelId,
    required this.epgChannelKey,
    required this.playlistId,
    required this.epgSourceId,
    required this.locked,
    required this.origin,
  }) : super._();
  @override
  EpgMapping rebuild(void Function(EpgMappingBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EpgMappingBuilder toBuilder() => EpgMappingBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EpgMapping &&
        channelId == other.channelId &&
        epgChannelKey == other.epgChannelKey &&
        playlistId == other.playlistId &&
        epgSourceId == other.epgSourceId &&
        locked == other.locked &&
        origin == other.origin;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, channelId.hashCode);
    _$hash = $jc(_$hash, epgChannelKey.hashCode);
    _$hash = $jc(_$hash, playlistId.hashCode);
    _$hash = $jc(_$hash, epgSourceId.hashCode);
    _$hash = $jc(_$hash, locked.hashCode);
    _$hash = $jc(_$hash, origin.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EpgMapping')
          ..add('channelId', channelId)
          ..add('epgChannelKey', epgChannelKey)
          ..add('playlistId', playlistId)
          ..add('epgSourceId', epgSourceId)
          ..add('locked', locked)
          ..add('origin', origin))
        .toString();
  }
}

class EpgMappingBuilder implements Builder<EpgMapping, EpgMappingBuilder> {
  _$EpgMapping? _$v;

  String? _channelId;
  String? get channelId => _$this._channelId;
  set channelId(String? channelId) => _$this._channelId = channelId;

  String? _epgChannelKey;
  String? get epgChannelKey => _$this._epgChannelKey;
  set epgChannelKey(String? epgChannelKey) =>
      _$this._epgChannelKey = epgChannelKey;

  String? _playlistId;
  String? get playlistId => _$this._playlistId;
  set playlistId(String? playlistId) => _$this._playlistId = playlistId;

  String? _epgSourceId;
  String? get epgSourceId => _$this._epgSourceId;
  set epgSourceId(String? epgSourceId) => _$this._epgSourceId = epgSourceId;

  bool? _locked;
  bool? get locked => _$this._locked;
  set locked(bool? locked) => _$this._locked = locked;

  String? _origin;
  String? get origin => _$this._origin;
  set origin(String? origin) => _$this._origin = origin;

  EpgMappingBuilder() {
    EpgMapping._initialize(this);
  }

  EpgMappingBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _channelId = $v.channelId;
      _epgChannelKey = $v.epgChannelKey;
      _playlistId = $v.playlistId;
      _epgSourceId = $v.epgSourceId;
      _locked = $v.locked;
      _origin = $v.origin;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EpgMapping other) {
    _$v = other as _$EpgMapping;
  }

  @override
  void update(void Function(EpgMappingBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EpgMapping build() => _build();

  _$EpgMapping _build() {
    final _$result =
        _$v ??
        _$EpgMapping._(
          channelId: BuiltValueNullFieldError.checkNotNull(
            channelId,
            r'EpgMapping',
            'channelId',
          ),
          epgChannelKey: BuiltValueNullFieldError.checkNotNull(
            epgChannelKey,
            r'EpgMapping',
            'epgChannelKey',
          ),
          playlistId: BuiltValueNullFieldError.checkNotNull(
            playlistId,
            r'EpgMapping',
            'playlistId',
          ),
          epgSourceId: BuiltValueNullFieldError.checkNotNull(
            epgSourceId,
            r'EpgMapping',
            'epgSourceId',
          ),
          locked: BuiltValueNullFieldError.checkNotNull(
            locked,
            r'EpgMapping',
            'locked',
          ),
          origin: BuiltValueNullFieldError.checkNotNull(
            origin,
            r'EpgMapping',
            'origin',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
