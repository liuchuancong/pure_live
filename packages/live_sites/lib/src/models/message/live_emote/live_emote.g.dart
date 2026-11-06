// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_emote.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveEmote> _$liveEmoteSerializer = _$LiveEmoteSerializer();

class _$LiveEmoteSerializer implements StructuredSerializer<LiveEmote> {
  @override
  final Iterable<Type> types = const [LiveEmote, _$LiveEmote];
  @override
  final String wireName = 'LiveEmote';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveEmote object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'code',
      serializers.serialize(object.code, specifiedType: const FullType(String)),
      'url',
      serializers.serialize(object.url, specifiedType: const FullType(String)),
    ];

    return result;
  }

  @override
  LiveEmote deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveEmoteBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'code':
          result.code = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'url':
          result.url = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
      }
    }

    return result.build();
  }
}

class _$LiveEmote extends LiveEmote {
  @override
  final String code;
  @override
  final String url;

  factory _$LiveEmote([void Function(LiveEmoteBuilder)? updates]) => (LiveEmoteBuilder()..update(updates))._build();

  _$LiveEmote._({required this.code, required this.url}) : super._();
  @override
  LiveEmote rebuild(void Function(LiveEmoteBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  LiveEmoteBuilder toBuilder() => LiveEmoteBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveEmote && code == other.code && url == other.url;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, code.hashCode);
    _$hash = $jc(_$hash, url.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveEmote')
          ..add('code', code)
          ..add('url', url))
        .toString();
  }
}

class LiveEmoteBuilder implements Builder<LiveEmote, LiveEmoteBuilder> {
  _$LiveEmote? _$v;

  String? _code;
  String? get code => _$this._code;
  set code(String? code) => _$this._code = code;

  String? _url;
  String? get url => _$this._url;
  set url(String? url) => _$this._url = url;

  LiveEmoteBuilder();

  LiveEmoteBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _code = $v.code;
      _url = $v.url;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveEmote other) {
    _$v = other as _$LiveEmote;
  }

  @override
  void update(void Function(LiveEmoteBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveEmote build() => _build();

  _$LiveEmote _build() {
    final _$result =
        _$v ??
        _$LiveEmote._(
          code: BuiltValueNullFieldError.checkNotNull(code, r'LiveEmote', 'code'),
          url: BuiltValueNullFieldError.checkNotNull(url, r'LiveEmote', 'url'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
