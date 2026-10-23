// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_content.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<RoomContent> _$roomContentSerializer = _$RoomContentSerializer();

class _$RoomContentSerializer implements StructuredSerializer<RoomContent> {
  @override
  final Iterable<Type> types = const [RoomContent, _$RoomContent];
  @override
  final String wireName = 'RoomContent';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RoomContent object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'title',
      serializers.serialize(object.title, specifiedType: const FullType(String)),
      'coverUrl',
      serializers.serialize(object.coverUrl, specifiedType: const FullType(String)),
      'badges',
      serializers.serialize(object.badges, specifiedType: const FullType(BuiltList, const [const FullType(LiveBadge)])),
      'platformTags',
      serializers.serialize(
        object.platformTags,
        specifiedType: const FullType(BuiltList, const [const FullType(String)]),
      ),
    ];
    Object? value;
    value = object.introduction;
    if (value != null) {
      result
        ..add('introduction')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.notice;
    if (value != null) {
      result
        ..add('notice')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    return result;
  }

  @override
  RoomContent deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RoomContentBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'title':
          result.title = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'coverUrl':
          result.coverUrl = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'introduction':
          result.introduction = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'notice':
          result.notice = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'badges':
          result.badges.replace(
            serializers.deserialize(value, specifiedType: const FullType(BuiltList, const [const FullType(LiveBadge)]))!
                as BuiltList<Object?>,
          );
          break;
        case 'platformTags':
          result.platformTags.replace(
            serializers.deserialize(value, specifiedType: const FullType(BuiltList, const [const FullType(String)]))!
                as BuiltList<Object?>,
          );
          break;
      }
    }

    return result.build();
  }
}

class _$RoomContent extends RoomContent {
  @override
  final String title;
  @override
  final String coverUrl;
  @override
  final String? introduction;
  @override
  final String? notice;
  @override
  final BuiltList<LiveBadge> badges;
  @override
  final BuiltList<String> platformTags;

  factory _$RoomContent([void Function(RoomContentBuilder)? updates]) =>
      (RoomContentBuilder()..update(updates))._build();

  _$RoomContent._({
    required this.title,
    required this.coverUrl,
    this.introduction,
    this.notice,
    required this.badges,
    required this.platformTags,
  }) : super._();
  @override
  RoomContent rebuild(void Function(RoomContentBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  RoomContentBuilder toBuilder() => RoomContentBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RoomContent &&
        title == other.title &&
        coverUrl == other.coverUrl &&
        introduction == other.introduction &&
        notice == other.notice &&
        badges == other.badges &&
        platformTags == other.platformTags;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, coverUrl.hashCode);
    _$hash = $jc(_$hash, introduction.hashCode);
    _$hash = $jc(_$hash, notice.hashCode);
    _$hash = $jc(_$hash, badges.hashCode);
    _$hash = $jc(_$hash, platformTags.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RoomContent')
          ..add('title', title)
          ..add('coverUrl', coverUrl)
          ..add('introduction', introduction)
          ..add('notice', notice)
          ..add('badges', badges)
          ..add('platformTags', platformTags))
        .toString();
  }
}

class RoomContentBuilder implements Builder<RoomContent, RoomContentBuilder> {
  _$RoomContent? _$v;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _coverUrl;
  String? get coverUrl => _$this._coverUrl;
  set coverUrl(String? coverUrl) => _$this._coverUrl = coverUrl;

  String? _introduction;
  String? get introduction => _$this._introduction;
  set introduction(String? introduction) => _$this._introduction = introduction;

  String? _notice;
  String? get notice => _$this._notice;
  set notice(String? notice) => _$this._notice = notice;

  ListBuilder<LiveBadge>? _badges;
  ListBuilder<LiveBadge> get badges => _$this._badges ??= ListBuilder<LiveBadge>();
  set badges(ListBuilder<LiveBadge>? badges) => _$this._badges = badges;

  ListBuilder<String>? _platformTags;
  ListBuilder<String> get platformTags => _$this._platformTags ??= ListBuilder<String>();
  set platformTags(ListBuilder<String>? platformTags) => _$this._platformTags = platformTags;

  RoomContentBuilder() {
    RoomContent._initialize(this);
  }

  RoomContentBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _title = $v.title;
      _coverUrl = $v.coverUrl;
      _introduction = $v.introduction;
      _notice = $v.notice;
      _badges = $v.badges.toBuilder();
      _platformTags = $v.platformTags.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RoomContent other) {
    _$v = other as _$RoomContent;
  }

  @override
  void update(void Function(RoomContentBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RoomContent build() => _build();

  _$RoomContent _build() {
    _$RoomContent _$result;
    try {
      _$result =
          _$v ??
          _$RoomContent._(
            title: BuiltValueNullFieldError.checkNotNull(title, r'RoomContent', 'title'),
            coverUrl: BuiltValueNullFieldError.checkNotNull(coverUrl, r'RoomContent', 'coverUrl'),
            introduction: introduction,
            notice: notice,
            badges: badges.build(),
            platformTags: platformTags.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'badges';
        badges.build();
        _$failedField = 'platformTags';
        platformTags.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'RoomContent', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
