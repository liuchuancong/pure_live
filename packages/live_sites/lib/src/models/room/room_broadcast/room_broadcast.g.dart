// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_broadcast.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<RoomBroadcast> _$roomBroadcastSerializer = _$RoomBroadcastSerializer();

class _$RoomBroadcastSerializer implements StructuredSerializer<RoomBroadcast> {
  @override
  final Iterable<Type> types = const [RoomBroadcast, _$RoomBroadcast];
  @override
  final String wireName = 'RoomBroadcast';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RoomBroadcast object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'activity',
      serializers.serialize(object.activity, specifiedType: const FullType(LiveRoomActivity)),
    ];
    Object? value;
    value = object.liveStatus;
    if (value != null) {
      result
        ..add('liveStatus')
        ..add(serializers.serialize(value, specifiedType: const FullType(LiveStatus)));
    }
    value = object.startedAt;
    if (value != null) {
      result
        ..add('startedAt')
        ..add(serializers.serialize(value, specifiedType: const FullType(DateTime)));
    }
    value = object.restriction;
    if (value != null) {
      result
        ..add('restriction')
        ..add(serializers.serialize(value, specifiedType: const FullType(LiveRestriction)));
    }
    return result;
  }

  @override
  RoomBroadcast deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RoomBroadcastBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'liveStatus':
          result.liveStatus = serializers.deserialize(value, specifiedType: const FullType(LiveStatus)) as LiveStatus?;
          break;
        case 'startedAt':
          result.startedAt = serializers.deserialize(value, specifiedType: const FullType(DateTime)) as DateTime?;
          break;
        case 'restriction':
          result.restriction =
              serializers.deserialize(value, specifiedType: const FullType(LiveRestriction)) as LiveRestriction?;
          break;
        case 'activity':
          result.activity =
              serializers.deserialize(value, specifiedType: const FullType(LiveRoomActivity))! as LiveRoomActivity;
          break;
      }
    }

    return result.build();
  }
}

class _$RoomBroadcast extends RoomBroadcast {
  @override
  final LiveStatus? liveStatus;
  @override
  final DateTime? startedAt;
  @override
  final LiveRestriction? restriction;
  @override
  final LiveRoomActivity activity;

  factory _$RoomBroadcast([void Function(RoomBroadcastBuilder)? updates]) =>
      (RoomBroadcastBuilder()..update(updates))._build();

  _$RoomBroadcast._({this.liveStatus, this.startedAt, this.restriction, required this.activity}) : super._();
  @override
  RoomBroadcast rebuild(void Function(RoomBroadcastBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  RoomBroadcastBuilder toBuilder() => RoomBroadcastBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RoomBroadcast &&
        liveStatus == other.liveStatus &&
        startedAt == other.startedAt &&
        restriction == other.restriction &&
        activity == other.activity;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, liveStatus.hashCode);
    _$hash = $jc(_$hash, startedAt.hashCode);
    _$hash = $jc(_$hash, restriction.hashCode);
    _$hash = $jc(_$hash, activity.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RoomBroadcast')
          ..add('liveStatus', liveStatus)
          ..add('startedAt', startedAt)
          ..add('restriction', restriction)
          ..add('activity', activity))
        .toString();
  }
}

class RoomBroadcastBuilder implements Builder<RoomBroadcast, RoomBroadcastBuilder> {
  _$RoomBroadcast? _$v;

  LiveStatus? _liveStatus;
  LiveStatus? get liveStatus => _$this._liveStatus;
  set liveStatus(LiveStatus? liveStatus) => _$this._liveStatus = liveStatus;

  DateTime? _startedAt;
  DateTime? get startedAt => _$this._startedAt;
  set startedAt(DateTime? startedAt) => _$this._startedAt = startedAt;

  LiveRestriction? _restriction;
  LiveRestriction? get restriction => _$this._restriction;
  set restriction(LiveRestriction? restriction) => _$this._restriction = restriction;

  LiveRoomActivity? _activity;
  LiveRoomActivity? get activity => _$this._activity;
  set activity(LiveRoomActivity? activity) => _$this._activity = activity;

  RoomBroadcastBuilder() {
    RoomBroadcast._initialize(this);
  }

  RoomBroadcastBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _liveStatus = $v.liveStatus;
      _startedAt = $v.startedAt;
      _restriction = $v.restriction;
      _activity = $v.activity;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RoomBroadcast other) {
    _$v = other as _$RoomBroadcast;
  }

  @override
  void update(void Function(RoomBroadcastBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RoomBroadcast build() => _build();

  _$RoomBroadcast _build() {
    final _$result =
        _$v ??
        _$RoomBroadcast._(
          liveStatus: liveStatus,
          startedAt: startedAt,
          restriction: restriction,
          activity: BuiltValueNullFieldError.checkNotNull(activity, r'RoomBroadcast', 'activity'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
