// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_room_ref.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveRoomRef> _$liveRoomRefSerializer = _$LiveRoomRefSerializer();

class _$LiveRoomRefSerializer implements StructuredSerializer<LiveRoomRef> {
  @override
  final Iterable<Type> types = const [LiveRoomRef, _$LiveRoomRef];
  @override
  final String wireName = 'LiveRoomRef';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveRoomRef object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'platform',
      serializers.serialize(
        object.platform,
        specifiedType: const FullType(String),
      ),
      'roomId',
      serializers.serialize(
        object.roomId,
        specifiedType: const FullType(String),
      ),
    ];

    return result;
  }

  @override
  LiveRoomRef deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveRoomRefBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'platform':
          result.platform =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'roomId':
          result.roomId =
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

class _$LiveRoomRef extends LiveRoomRef {
  @override
  final String platform;
  @override
  final String roomId;

  factory _$LiveRoomRef([void Function(LiveRoomRefBuilder)? updates]) =>
      (LiveRoomRefBuilder()..update(updates))._build();

  _$LiveRoomRef._({required this.platform, required this.roomId}) : super._();
  @override
  LiveRoomRef rebuild(void Function(LiveRoomRefBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LiveRoomRefBuilder toBuilder() => LiveRoomRefBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveRoomRef &&
        platform == other.platform &&
        roomId == other.roomId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, roomId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveRoomRef')
          ..add('platform', platform)
          ..add('roomId', roomId))
        .toString();
  }
}

class LiveRoomRefBuilder implements Builder<LiveRoomRef, LiveRoomRefBuilder> {
  _$LiveRoomRef? _$v;

  String? _platform;
  String? get platform => _$this._platform;
  set platform(String? platform) => _$this._platform = platform;

  String? _roomId;
  String? get roomId => _$this._roomId;
  set roomId(String? roomId) => _$this._roomId = roomId;

  LiveRoomRefBuilder();

  LiveRoomRefBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _platform = $v.platform;
      _roomId = $v.roomId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveRoomRef other) {
    _$v = other as _$LiveRoomRef;
  }

  @override
  void update(void Function(LiveRoomRefBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveRoomRef build() => _build();

  _$LiveRoomRef _build() {
    final _$result =
        _$v ??
        _$LiveRoomRef._(
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'LiveRoomRef',
            'platform',
          ),
          roomId: BuiltValueNullFieldError.checkNotNull(
            roomId,
            r'LiveRoomRef',
            'roomId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
