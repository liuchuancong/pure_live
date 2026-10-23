// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_area.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveArea> _$liveAreaSerializer = _$LiveAreaSerializer();

class _$LiveAreaSerializer implements StructuredSerializer<LiveArea> {
  @override
  final Iterable<Type> types = const [LiveArea, _$LiveArea];
  @override
  final String wireName = 'LiveArea';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveArea object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'platform',
      serializers.serialize(object.platform, specifiedType: const FullType(String)),
      'areaId',
      serializers.serialize(object.areaId, specifiedType: const FullType(String)),
      'areaName',
      serializers.serialize(object.areaName, specifiedType: const FullType(String)),
    ];
    Object? value;
    value = object.parentAreaId;
    if (value != null) {
      result
        ..add('parentAreaId')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.parentAreaName;
    if (value != null) {
      result
        ..add('parentAreaName')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.iconUrl;
    if (value != null) {
      result
        ..add('iconUrl')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.shortName;
    if (value != null) {
      result
        ..add('shortName')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.position;
    if (value != null) {
      result
        ..add('position')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    return result;
  }

  @override
  LiveArea deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveAreaBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'platform':
          result.platform = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'areaId':
          result.areaId = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'areaName':
          result.areaName = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'parentAreaId':
          result.parentAreaId = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'parentAreaName':
          result.parentAreaName = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'iconUrl':
          result.iconUrl = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'shortName':
          result.shortName = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'position':
          result.position = serializers.deserialize(value, specifiedType: const FullType(int)) as int?;
          break;
      }
    }

    return result.build();
  }
}

class _$LiveArea extends LiveArea {
  @override
  final String platform;
  @override
  final String areaId;
  @override
  final String areaName;
  @override
  final String? parentAreaId;
  @override
  final String? parentAreaName;
  @override
  final String? iconUrl;
  @override
  final String? shortName;
  @override
  final int? position;

  factory _$LiveArea([void Function(LiveAreaBuilder)? updates]) => (LiveAreaBuilder()..update(updates))._build();

  _$LiveArea._({
    required this.platform,
    required this.areaId,
    required this.areaName,
    this.parentAreaId,
    this.parentAreaName,
    this.iconUrl,
    this.shortName,
    this.position,
  }) : super._();
  @override
  LiveArea rebuild(void Function(LiveAreaBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  LiveAreaBuilder toBuilder() => LiveAreaBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveArea &&
        platform == other.platform &&
        areaId == other.areaId &&
        areaName == other.areaName &&
        parentAreaId == other.parentAreaId &&
        parentAreaName == other.parentAreaName &&
        iconUrl == other.iconUrl &&
        shortName == other.shortName &&
        position == other.position;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, areaId.hashCode);
    _$hash = $jc(_$hash, areaName.hashCode);
    _$hash = $jc(_$hash, parentAreaId.hashCode);
    _$hash = $jc(_$hash, parentAreaName.hashCode);
    _$hash = $jc(_$hash, iconUrl.hashCode);
    _$hash = $jc(_$hash, shortName.hashCode);
    _$hash = $jc(_$hash, position.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveArea')
          ..add('platform', platform)
          ..add('areaId', areaId)
          ..add('areaName', areaName)
          ..add('parentAreaId', parentAreaId)
          ..add('parentAreaName', parentAreaName)
          ..add('iconUrl', iconUrl)
          ..add('shortName', shortName)
          ..add('position', position))
        .toString();
  }
}

class LiveAreaBuilder implements Builder<LiveArea, LiveAreaBuilder> {
  _$LiveArea? _$v;

  String? _platform;
  String? get platform => _$this._platform;
  set platform(String? platform) => _$this._platform = platform;

  String? _areaId;
  String? get areaId => _$this._areaId;
  set areaId(String? areaId) => _$this._areaId = areaId;

  String? _areaName;
  String? get areaName => _$this._areaName;
  set areaName(String? areaName) => _$this._areaName = areaName;

  String? _parentAreaId;
  String? get parentAreaId => _$this._parentAreaId;
  set parentAreaId(String? parentAreaId) => _$this._parentAreaId = parentAreaId;

  String? _parentAreaName;
  String? get parentAreaName => _$this._parentAreaName;
  set parentAreaName(String? parentAreaName) => _$this._parentAreaName = parentAreaName;

  String? _iconUrl;
  String? get iconUrl => _$this._iconUrl;
  set iconUrl(String? iconUrl) => _$this._iconUrl = iconUrl;

  String? _shortName;
  String? get shortName => _$this._shortName;
  set shortName(String? shortName) => _$this._shortName = shortName;

  int? _position;
  int? get position => _$this._position;
  set position(int? position) => _$this._position = position;

  LiveAreaBuilder() {
    LiveArea._initialize(this);
  }

  LiveAreaBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _platform = $v.platform;
      _areaId = $v.areaId;
      _areaName = $v.areaName;
      _parentAreaId = $v.parentAreaId;
      _parentAreaName = $v.parentAreaName;
      _iconUrl = $v.iconUrl;
      _shortName = $v.shortName;
      _position = $v.position;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveArea other) {
    _$v = other as _$LiveArea;
  }

  @override
  void update(void Function(LiveAreaBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveArea build() => _build();

  _$LiveArea _build() {
    final _$result =
        _$v ??
        _$LiveArea._(
          platform: BuiltValueNullFieldError.checkNotNull(platform, r'LiveArea', 'platform'),
          areaId: BuiltValueNullFieldError.checkNotNull(areaId, r'LiveArea', 'areaId'),
          areaName: BuiltValueNullFieldError.checkNotNull(areaName, r'LiveArea', 'areaName'),
          parentAreaId: parentAreaId,
          parentAreaName: parentAreaName,
          iconUrl: iconUrl,
          shortName: shortName,
          position: position,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
