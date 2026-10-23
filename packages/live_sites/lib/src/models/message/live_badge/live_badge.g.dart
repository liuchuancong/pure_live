// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_badge.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveBadge> _$liveBadgeSerializer = _$LiveBadgeSerializer();

class _$LiveBadgeSerializer implements StructuredSerializer<LiveBadge> {
  @override
  final Iterable<Type> types = const [LiveBadge, _$LiveBadge];
  @override
  final String wireName = 'LiveBadge';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveBadge object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'url',
      serializers.serialize(object.url, specifiedType: const FullType(String)),
      'id',
      serializers.serialize(object.id, specifiedType: const FullType(String)),
    ];

    return result;
  }

  @override
  LiveBadge deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveBadgeBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'url':
          result.url =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'id':
          result.id =
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

class _$LiveBadge extends LiveBadge {
  @override
  final String url;
  @override
  final String id;

  factory _$LiveBadge([void Function(LiveBadgeBuilder)? updates]) =>
      (LiveBadgeBuilder()..update(updates))._build();

  _$LiveBadge._({required this.url, required this.id}) : super._();
  @override
  LiveBadge rebuild(void Function(LiveBadgeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LiveBadgeBuilder toBuilder() => LiveBadgeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveBadge && url == other.url && id == other.id;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, url.hashCode);
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveBadge')
          ..add('url', url)
          ..add('id', id))
        .toString();
  }
}

class LiveBadgeBuilder implements Builder<LiveBadge, LiveBadgeBuilder> {
  _$LiveBadge? _$v;

  String? _url;
  String? get url => _$this._url;
  set url(String? url) => _$this._url = url;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  LiveBadgeBuilder() {
    LiveBadge._initialize(this);
  }

  LiveBadgeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _url = $v.url;
      _id = $v.id;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveBadge other) {
    _$v = other as _$LiveBadge;
  }

  @override
  void update(void Function(LiveBadgeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveBadge build() => _build();

  _$LiveBadge _build() {
    final _$result =
        _$v ??
        _$LiveBadge._(
          url: BuiltValueNullFieldError.checkNotNull(url, r'LiveBadge', 'url'),
          id: BuiltValueNullFieldError.checkNotNull(id, r'LiveBadge', 'id'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
