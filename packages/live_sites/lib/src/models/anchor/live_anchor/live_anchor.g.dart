// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_anchor.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveAnchor> _$liveAnchorSerializer = _$LiveAnchorSerializer();

class _$LiveAnchorSerializer implements StructuredSerializer<LiveAnchor> {
  @override
  final Iterable<Type> types = const [LiveAnchor, _$LiveAnchor];
  @override
  final String wireName = 'LiveAnchor';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveAnchor object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'platform',
      serializers.serialize(object.platform, specifiedType: const FullType(String)),
      'anchorId',
      serializers.serialize(object.anchorId, specifiedType: const FullType(String)),
      'name',
      serializers.serialize(object.name, specifiedType: const FullType(String)),
    ];
    Object? value;
    value = object.avatarUrl;
    if (value != null) {
      result
        ..add('avatarUrl')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.profileUrl;
    if (value != null) {
      result
        ..add('profileUrl')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.followerCount;
    if (value != null) {
      result
        ..add('followerCount')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.introduction;
    if (value != null) {
      result
        ..add('introduction')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.isVerified;
    if (value != null) {
      result
        ..add('isVerified')
        ..add(serializers.serialize(value, specifiedType: const FullType(bool)));
    }
    value = object.anchorLevel;
    if (value != null) {
      result
        ..add('anchorLevel')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.liveStatus;
    if (value != null) {
      result
        ..add('liveStatus')
        ..add(serializers.serialize(value, specifiedType: const FullType(LiveStatus)));
    }
    return result;
  }

  @override
  LiveAnchor deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveAnchorBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'platform':
          result.platform = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'anchorId':
          result.anchorId = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'name':
          result.name = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'avatarUrl':
          result.avatarUrl = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'profileUrl':
          result.profileUrl = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'followerCount':
          result.followerCount = serializers.deserialize(value, specifiedType: const FullType(int)) as int?;
          break;
        case 'introduction':
          result.introduction = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'isVerified':
          result.isVerified = serializers.deserialize(value, specifiedType: const FullType(bool)) as bool?;
          break;
        case 'anchorLevel':
          result.anchorLevel = serializers.deserialize(value, specifiedType: const FullType(int)) as int?;
          break;
        case 'liveStatus':
          result.liveStatus = serializers.deserialize(value, specifiedType: const FullType(LiveStatus)) as LiveStatus?;
          break;
      }
    }

    return result.build();
  }
}

class _$LiveAnchor extends LiveAnchor {
  @override
  final String platform;
  @override
  final String anchorId;
  @override
  final String name;
  @override
  final String? avatarUrl;
  @override
  final String? profileUrl;
  @override
  final int? followerCount;
  @override
  final String? introduction;
  @override
  final bool? isVerified;
  @override
  final int? anchorLevel;
  @override
  final LiveStatus? liveStatus;

  factory _$LiveAnchor([void Function(LiveAnchorBuilder)? updates]) => (LiveAnchorBuilder()..update(updates))._build();

  _$LiveAnchor._({
    required this.platform,
    required this.anchorId,
    required this.name,
    this.avatarUrl,
    this.profileUrl,
    this.followerCount,
    this.introduction,
    this.isVerified,
    this.anchorLevel,
    this.liveStatus,
  }) : super._();
  @override
  LiveAnchor rebuild(void Function(LiveAnchorBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  LiveAnchorBuilder toBuilder() => LiveAnchorBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveAnchor &&
        platform == other.platform &&
        anchorId == other.anchorId &&
        name == other.name &&
        avatarUrl == other.avatarUrl &&
        profileUrl == other.profileUrl &&
        followerCount == other.followerCount &&
        introduction == other.introduction &&
        isVerified == other.isVerified &&
        anchorLevel == other.anchorLevel &&
        liveStatus == other.liveStatus;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, anchorId.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, avatarUrl.hashCode);
    _$hash = $jc(_$hash, profileUrl.hashCode);
    _$hash = $jc(_$hash, followerCount.hashCode);
    _$hash = $jc(_$hash, introduction.hashCode);
    _$hash = $jc(_$hash, isVerified.hashCode);
    _$hash = $jc(_$hash, anchorLevel.hashCode);
    _$hash = $jc(_$hash, liveStatus.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveAnchor')
          ..add('platform', platform)
          ..add('anchorId', anchorId)
          ..add('name', name)
          ..add('avatarUrl', avatarUrl)
          ..add('profileUrl', profileUrl)
          ..add('followerCount', followerCount)
          ..add('introduction', introduction)
          ..add('isVerified', isVerified)
          ..add('anchorLevel', anchorLevel)
          ..add('liveStatus', liveStatus))
        .toString();
  }
}

class LiveAnchorBuilder implements Builder<LiveAnchor, LiveAnchorBuilder> {
  _$LiveAnchor? _$v;

  String? _platform;
  String? get platform => _$this._platform;
  set platform(String? platform) => _$this._platform = platform;

  String? _anchorId;
  String? get anchorId => _$this._anchorId;
  set anchorId(String? anchorId) => _$this._anchorId = anchorId;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _avatarUrl;
  String? get avatarUrl => _$this._avatarUrl;
  set avatarUrl(String? avatarUrl) => _$this._avatarUrl = avatarUrl;

  String? _profileUrl;
  String? get profileUrl => _$this._profileUrl;
  set profileUrl(String? profileUrl) => _$this._profileUrl = profileUrl;

  int? _followerCount;
  int? get followerCount => _$this._followerCount;
  set followerCount(int? followerCount) => _$this._followerCount = followerCount;

  String? _introduction;
  String? get introduction => _$this._introduction;
  set introduction(String? introduction) => _$this._introduction = introduction;

  bool? _isVerified;
  bool? get isVerified => _$this._isVerified;
  set isVerified(bool? isVerified) => _$this._isVerified = isVerified;

  int? _anchorLevel;
  int? get anchorLevel => _$this._anchorLevel;
  set anchorLevel(int? anchorLevel) => _$this._anchorLevel = anchorLevel;

  LiveStatus? _liveStatus;
  LiveStatus? get liveStatus => _$this._liveStatus;
  set liveStatus(LiveStatus? liveStatus) => _$this._liveStatus = liveStatus;

  LiveAnchorBuilder() {
    LiveAnchor._initialize(this);
  }

  LiveAnchorBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _platform = $v.platform;
      _anchorId = $v.anchorId;
      _name = $v.name;
      _avatarUrl = $v.avatarUrl;
      _profileUrl = $v.profileUrl;
      _followerCount = $v.followerCount;
      _introduction = $v.introduction;
      _isVerified = $v.isVerified;
      _anchorLevel = $v.anchorLevel;
      _liveStatus = $v.liveStatus;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveAnchor other) {
    _$v = other as _$LiveAnchor;
  }

  @override
  void update(void Function(LiveAnchorBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveAnchor build() => _build();

  _$LiveAnchor _build() {
    final _$result =
        _$v ??
        _$LiveAnchor._(
          platform: BuiltValueNullFieldError.checkNotNull(platform, r'LiveAnchor', 'platform'),
          anchorId: BuiltValueNullFieldError.checkNotNull(anchorId, r'LiveAnchor', 'anchorId'),
          name: BuiltValueNullFieldError.checkNotNull(name, r'LiveAnchor', 'name'),
          avatarUrl: avatarUrl,
          profileUrl: profileUrl,
          followerCount: followerCount,
          introduction: introduction,
          isVerified: isVerified,
          anchorLevel: anchorLevel,
          liveStatus: liveStatus,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
