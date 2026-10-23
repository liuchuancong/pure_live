// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_local.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<RoomLocal> _$roomLocalSerializer = _$RoomLocalSerializer();

class _$RoomLocalSerializer implements StructuredSerializer<RoomLocal> {
  @override
  final Iterable<Type> types = const [RoomLocal, _$RoomLocal];
  @override
  final String wireName = 'RoomLocal';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RoomLocal object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'tagIds',
      serializers.serialize(
        object.tagIds,
        specifiedType: const FullType(BuiltList, const [
          const FullType(String),
        ]),
      ),
    ];
    Object? value;
    value = object.lastWatchedAt;
    if (value != null) {
      result
        ..add('lastWatchedAt')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(DateTime)),
        );
    }
    value = object.watchDurationMs;
    if (value != null) {
      result
        ..add('watchDurationMs')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    return result;
  }

  @override
  RoomLocal deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RoomLocalBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'lastWatchedAt':
          result.lastWatchedAt = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime?;
          break;
        case 'tagIds':
          result.tagIds.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(String),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'watchDurationMs':
          result.watchDurationMs = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
      }
    }

    return result.build();
  }
}

class _$RoomLocal extends RoomLocal {
  @override
  final DateTime? lastWatchedAt;
  @override
  final BuiltList<String> tagIds;
  @override
  final int? watchDurationMs;

  factory _$RoomLocal([void Function(RoomLocalBuilder)? updates]) =>
      (RoomLocalBuilder()..update(updates))._build();

  _$RoomLocal._({
    this.lastWatchedAt,
    required this.tagIds,
    this.watchDurationMs,
  }) : super._();
  @override
  RoomLocal rebuild(void Function(RoomLocalBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RoomLocalBuilder toBuilder() => RoomLocalBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RoomLocal &&
        lastWatchedAt == other.lastWatchedAt &&
        tagIds == other.tagIds &&
        watchDurationMs == other.watchDurationMs;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, lastWatchedAt.hashCode);
    _$hash = $jc(_$hash, tagIds.hashCode);
    _$hash = $jc(_$hash, watchDurationMs.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RoomLocal')
          ..add('lastWatchedAt', lastWatchedAt)
          ..add('tagIds', tagIds)
          ..add('watchDurationMs', watchDurationMs))
        .toString();
  }
}

class RoomLocalBuilder implements Builder<RoomLocal, RoomLocalBuilder> {
  _$RoomLocal? _$v;

  DateTime? _lastWatchedAt;
  DateTime? get lastWatchedAt => _$this._lastWatchedAt;
  set lastWatchedAt(DateTime? lastWatchedAt) =>
      _$this._lastWatchedAt = lastWatchedAt;

  ListBuilder<String>? _tagIds;
  ListBuilder<String> get tagIds => _$this._tagIds ??= ListBuilder<String>();
  set tagIds(ListBuilder<String>? tagIds) => _$this._tagIds = tagIds;

  int? _watchDurationMs;
  int? get watchDurationMs => _$this._watchDurationMs;
  set watchDurationMs(int? watchDurationMs) =>
      _$this._watchDurationMs = watchDurationMs;

  RoomLocalBuilder();

  RoomLocalBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _lastWatchedAt = $v.lastWatchedAt;
      _tagIds = $v.tagIds.toBuilder();
      _watchDurationMs = $v.watchDurationMs;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RoomLocal other) {
    _$v = other as _$RoomLocal;
  }

  @override
  void update(void Function(RoomLocalBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RoomLocal build() => _build();

  _$RoomLocal _build() {
    _$RoomLocal _$result;
    try {
      _$result =
          _$v ??
          _$RoomLocal._(
            lastWatchedAt: lastWatchedAt,
            tagIds: tagIds.build(),
            watchDurationMs: watchDurationMs,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'tagIds';
        tagIds.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'RoomLocal',
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
