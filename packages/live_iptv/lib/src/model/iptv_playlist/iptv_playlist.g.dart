// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_playlist.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<IptvPlaylist> _$iptvPlaylistSerializer = _$IptvPlaylistSerializer();

class _$IptvPlaylistSerializer implements StructuredSerializer<IptvPlaylist> {
  @override
  final Iterable<Type> types = const [IptvPlaylist, _$IptvPlaylist];
  @override
  final String wireName = 'IptvPlaylist';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    IptvPlaylist object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'id',
      serializers.serialize(object.id, specifiedType: const FullType(String)),
      'name',
      serializers.serialize(object.name, specifiedType: const FullType(String)),
      'importedAt',
      serializers.serialize(
        object.importedAt,
        specifiedType: const FullType(DateTime),
      ),
      'channelCount',
      serializers.serialize(
        object.channelCount,
        specifiedType: const FullType(int),
      ),
    ];
    Object? value;
    value = object.url;
    if (value != null) {
      result
        ..add('url')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    return result;
  }

  @override
  IptvPlaylist deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IptvPlaylistBuilder();

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
        case 'importedAt':
          result.importedAt =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )!
                  as DateTime;
          break;
        case 'url':
          result.url = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'channelCount':
          result.channelCount =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
      }
    }

    return result.build();
  }
}

class _$IptvPlaylist extends IptvPlaylist {
  @override
  final String id;
  @override
  final String name;
  @override
  final DateTime importedAt;
  @override
  final String? url;
  @override
  final int channelCount;

  factory _$IptvPlaylist([void Function(IptvPlaylistBuilder)? updates]) =>
      (IptvPlaylistBuilder()..update(updates))._build();

  _$IptvPlaylist._({
    required this.id,
    required this.name,
    required this.importedAt,
    this.url,
    required this.channelCount,
  }) : super._();
  @override
  IptvPlaylist rebuild(void Function(IptvPlaylistBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IptvPlaylistBuilder toBuilder() => IptvPlaylistBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IptvPlaylist &&
        id == other.id &&
        name == other.name &&
        importedAt == other.importedAt &&
        url == other.url &&
        channelCount == other.channelCount;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, importedAt.hashCode);
    _$hash = $jc(_$hash, url.hashCode);
    _$hash = $jc(_$hash, channelCount.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IptvPlaylist')
          ..add('id', id)
          ..add('name', name)
          ..add('importedAt', importedAt)
          ..add('url', url)
          ..add('channelCount', channelCount))
        .toString();
  }
}

class IptvPlaylistBuilder
    implements Builder<IptvPlaylist, IptvPlaylistBuilder> {
  _$IptvPlaylist? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  DateTime? _importedAt;
  DateTime? get importedAt => _$this._importedAt;
  set importedAt(DateTime? importedAt) => _$this._importedAt = importedAt;

  String? _url;
  String? get url => _$this._url;
  set url(String? url) => _$this._url = url;

  int? _channelCount;
  int? get channelCount => _$this._channelCount;
  set channelCount(int? channelCount) => _$this._channelCount = channelCount;

  IptvPlaylistBuilder() {
    IptvPlaylist._initialize(this);
  }

  IptvPlaylistBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _importedAt = $v.importedAt;
      _url = $v.url;
      _channelCount = $v.channelCount;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IptvPlaylist other) {
    _$v = other as _$IptvPlaylist;
  }

  @override
  void update(void Function(IptvPlaylistBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IptvPlaylist build() => _build();

  _$IptvPlaylist _build() {
    final _$result =
        _$v ??
        _$IptvPlaylist._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'IptvPlaylist', 'id'),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'IptvPlaylist',
            'name',
          ),
          importedAt: BuiltValueNullFieldError.checkNotNull(
            importedAt,
            r'IptvPlaylist',
            'importedAt',
          ),
          url: url,
          channelCount: BuiltValueNullFieldError.checkNotNull(
            channelCount,
            r'IptvPlaylist',
            'channelCount',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
