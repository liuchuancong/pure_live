// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_retraction.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveRetraction> _$liveRetractionSerializer =
    _$LiveRetractionSerializer();

class _$LiveRetractionSerializer
    implements StructuredSerializer<LiveRetraction> {
  @override
  final Iterable<Type> types = const [LiveRetraction, _$LiveRetraction];
  @override
  final String wireName = 'LiveRetraction';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveRetraction object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'all',
      serializers.serialize(object.all, specifiedType: const FullType(bool)),
    ];
    Object? value;
    value = object.userId;
    if (value != null) {
      result
        ..add('userId')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.messageId;
    if (value != null) {
      result
        ..add('messageId')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    return result;
  }

  @override
  LiveRetraction deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveRetractionBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'userId':
          result.userId = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'messageId':
          result.messageId = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'all':
          result.all =
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

class _$LiveRetraction extends LiveRetraction {
  @override
  final String? userId;
  @override
  final String? messageId;
  @override
  final bool all;

  factory _$LiveRetraction([void Function(LiveRetractionBuilder)? updates]) =>
      (LiveRetractionBuilder()..update(updates))._build();

  _$LiveRetraction._({this.userId, this.messageId, required this.all})
    : super._();
  @override
  LiveRetraction rebuild(void Function(LiveRetractionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LiveRetractionBuilder toBuilder() => LiveRetractionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveRetraction &&
        userId == other.userId &&
        messageId == other.messageId &&
        all == other.all;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, messageId.hashCode);
    _$hash = $jc(_$hash, all.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveRetraction')
          ..add('userId', userId)
          ..add('messageId', messageId)
          ..add('all', all))
        .toString();
  }
}

class LiveRetractionBuilder
    implements Builder<LiveRetraction, LiveRetractionBuilder> {
  _$LiveRetraction? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  String? _messageId;
  String? get messageId => _$this._messageId;
  set messageId(String? messageId) => _$this._messageId = messageId;

  bool? _all;
  bool? get all => _$this._all;
  set all(bool? all) => _$this._all = all;

  LiveRetractionBuilder() {
    LiveRetraction._initialize(this);
  }

  LiveRetractionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _messageId = $v.messageId;
      _all = $v.all;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveRetraction other) {
    _$v = other as _$LiveRetraction;
  }

  @override
  void update(void Function(LiveRetractionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveRetraction build() => _build();

  _$LiveRetraction _build() {
    final _$result =
        _$v ??
        _$LiveRetraction._(
          userId: userId,
          messageId: messageId,
          all: BuiltValueNullFieldError.checkNotNull(
            all,
            r'LiveRetraction',
            'all',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
