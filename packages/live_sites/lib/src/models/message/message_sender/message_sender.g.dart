// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_sender.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<MessageSender> _$messageSenderSerializer =
    _$MessageSenderSerializer();

class _$MessageSenderSerializer implements StructuredSerializer<MessageSender> {
  @override
  final Iterable<Type> types = const [MessageSender, _$MessageSender];
  @override
  final String wireName = 'MessageSender';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    MessageSender object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'userId',
      serializers.serialize(
        object.userId,
        specifiedType: const FullType(String),
      ),
      'userName',
      serializers.serialize(
        object.userName,
        specifiedType: const FullType(String),
      ),
      'fanBadgeLevel',
      serializers.serialize(
        object.fanBadgeLevel,
        specifiedType: const FullType(String),
      ),
      'fanBadgeName',
      serializers.serialize(
        object.fanBadgeName,
        specifiedType: const FullType(String),
      ),
      'badges',
      serializers.serialize(
        object.badges,
        specifiedType: const FullType(BuiltList, const [
          const FullType(LiveBadge),
        ]),
      ),
      'role',
      serializers.serialize(
        object.role,
        specifiedType: const FullType(LiveAnchorRole),
      ),
    ];
    Object? value;
    value = object.avatarUrl;
    if (value != null) {
      result
        ..add('avatarUrl')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.userLevel;
    if (value != null) {
      result
        ..add('userLevel')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.nameColor;
    if (value != null) {
      result
        ..add('nameColor')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(LiveMessageColor),
          ),
        );
    }
    value = object.membershipTier;
    if (value != null) {
      result
        ..add('membershipTier')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    return result;
  }

  @override
  MessageSender deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MessageSenderBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'userId':
          result.userId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'userName':
          result.userName =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'avatarUrl':
          result.avatarUrl = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'userLevel':
          result.userLevel = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'fanBadgeLevel':
          result.fanBadgeLevel =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'fanBadgeName':
          result.fanBadgeName =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'nameColor':
          result.nameColor = serializers.deserialize(
            value,
            specifiedType: const FullType(LiveMessageColor),
          ) as LiveMessageColor?;
          break;
        case 'badges':
          result.badges.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(LiveBadge),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'role':
          result.role =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(LiveAnchorRole),
                  )!
                  as LiveAnchorRole;
          break;
        case 'membershipTier':
          result.membershipTier = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
      }
    }

    return result.build();
  }
}

class _$MessageSender extends MessageSender {
  @override
  final String userId;
  @override
  final String userName;
  @override
  final String? avatarUrl;
  @override
  final String? userLevel;
  @override
  final String fanBadgeLevel;
  @override
  final String fanBadgeName;
  @override
  final LiveMessageColor? nameColor;
  @override
  final BuiltList<LiveBadge> badges;
  @override
  final LiveAnchorRole role;
  @override
  final int? membershipTier;

  factory _$MessageSender([void Function(MessageSenderBuilder)? updates]) =>
      (MessageSenderBuilder()..update(updates))._build();

  _$MessageSender._({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.userLevel,
    required this.fanBadgeLevel,
    required this.fanBadgeName,
    this.nameColor,
    required this.badges,
    required this.role,
    this.membershipTier,
  }) : super._();
  @override
  MessageSender rebuild(void Function(MessageSenderBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MessageSenderBuilder toBuilder() => MessageSenderBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MessageSender &&
        userId == other.userId &&
        userName == other.userName &&
        avatarUrl == other.avatarUrl &&
        userLevel == other.userLevel &&
        fanBadgeLevel == other.fanBadgeLevel &&
        fanBadgeName == other.fanBadgeName &&
        nameColor == other.nameColor &&
        badges == other.badges &&
        role == other.role &&
        membershipTier == other.membershipTier;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, userName.hashCode);
    _$hash = $jc(_$hash, avatarUrl.hashCode);
    _$hash = $jc(_$hash, userLevel.hashCode);
    _$hash = $jc(_$hash, fanBadgeLevel.hashCode);
    _$hash = $jc(_$hash, fanBadgeName.hashCode);
    _$hash = $jc(_$hash, nameColor.hashCode);
    _$hash = $jc(_$hash, badges.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jc(_$hash, membershipTier.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MessageSender')
          ..add('userId', userId)
          ..add('userName', userName)
          ..add('avatarUrl', avatarUrl)
          ..add('userLevel', userLevel)
          ..add('fanBadgeLevel', fanBadgeLevel)
          ..add('fanBadgeName', fanBadgeName)
          ..add('nameColor', nameColor)
          ..add('badges', badges)
          ..add('role', role)
          ..add('membershipTier', membershipTier))
        .toString();
  }
}

class MessageSenderBuilder
    implements Builder<MessageSender, MessageSenderBuilder> {
  _$MessageSender? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  String? _userName;
  String? get userName => _$this._userName;
  set userName(String? userName) => _$this._userName = userName;

  String? _avatarUrl;
  String? get avatarUrl => _$this._avatarUrl;
  set avatarUrl(String? avatarUrl) => _$this._avatarUrl = avatarUrl;

  String? _userLevel;
  String? get userLevel => _$this._userLevel;
  set userLevel(String? userLevel) => _$this._userLevel = userLevel;

  String? _fanBadgeLevel;
  String? get fanBadgeLevel => _$this._fanBadgeLevel;
  set fanBadgeLevel(String? fanBadgeLevel) =>
      _$this._fanBadgeLevel = fanBadgeLevel;

  String? _fanBadgeName;
  String? get fanBadgeName => _$this._fanBadgeName;
  set fanBadgeName(String? fanBadgeName) => _$this._fanBadgeName = fanBadgeName;

  LiveMessageColor? _nameColor;
  LiveMessageColor? get nameColor => _$this._nameColor;
  set nameColor(LiveMessageColor? nameColor) => _$this._nameColor = nameColor;

  ListBuilder<LiveBadge>? _badges;
  ListBuilder<LiveBadge> get badges =>
      _$this._badges ??= ListBuilder<LiveBadge>();
  set badges(ListBuilder<LiveBadge>? badges) => _$this._badges = badges;

  LiveAnchorRole? _role;
  LiveAnchorRole? get role => _$this._role;
  set role(LiveAnchorRole? role) => _$this._role = role;

  int? _membershipTier;
  int? get membershipTier => _$this._membershipTier;
  set membershipTier(int? membershipTier) =>
      _$this._membershipTier = membershipTier;

  MessageSenderBuilder() {
    MessageSender._initialize(this);
  }

  MessageSenderBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _userName = $v.userName;
      _avatarUrl = $v.avatarUrl;
      _userLevel = $v.userLevel;
      _fanBadgeLevel = $v.fanBadgeLevel;
      _fanBadgeName = $v.fanBadgeName;
      _nameColor = $v.nameColor;
      _badges = $v.badges.toBuilder();
      _role = $v.role;
      _membershipTier = $v.membershipTier;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MessageSender other) {
    _$v = other as _$MessageSender;
  }

  @override
  void update(void Function(MessageSenderBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MessageSender build() => _build();

  _$MessageSender _build() {
    _$MessageSender _$result;
    try {
      _$result =
          _$v ??
          _$MessageSender._(
            userId: BuiltValueNullFieldError.checkNotNull(
              userId,
              r'MessageSender',
              'userId',
            ),
            userName: BuiltValueNullFieldError.checkNotNull(
              userName,
              r'MessageSender',
              'userName',
            ),
            avatarUrl: avatarUrl,
            userLevel: userLevel,
            fanBadgeLevel: BuiltValueNullFieldError.checkNotNull(
              fanBadgeLevel,
              r'MessageSender',
              'fanBadgeLevel',
            ),
            fanBadgeName: BuiltValueNullFieldError.checkNotNull(
              fanBadgeName,
              r'MessageSender',
              'fanBadgeName',
            ),
            nameColor: nameColor,
            badges: badges.build(),
            role: BuiltValueNullFieldError.checkNotNull(
              role,
              r'MessageSender',
              'role',
            ),
            membershipTier: membershipTier,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'badges';
        badges.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'MessageSender',
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
