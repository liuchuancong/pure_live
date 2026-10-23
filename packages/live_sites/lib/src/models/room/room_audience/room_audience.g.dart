// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_audience.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<RoomAudience> _$roomAudienceSerializer = _$RoomAudienceSerializer();

class _$RoomAudienceSerializer implements StructuredSerializer<RoomAudience> {
  @override
  final Iterable<Type> types = const [RoomAudience, _$RoomAudience];
  @override
  final String wireName = 'RoomAudience';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RoomAudience object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[];
    Object? value;
    value = object.popularity;
    if (value != null) {
      result
        ..add('popularity')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.onlineViewers;
    if (value != null) {
      result
        ..add('onlineViewers')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.totalViewers;
    if (value != null) {
      result
        ..add('totalViewers')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.primaryMetric;
    if (value != null) {
      result
        ..add('primaryMetric')
        ..add(serializers.serialize(value, specifiedType: const FullType(LiveAudienceMetricType)));
    }
    return result;
  }

  @override
  RoomAudience deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RoomAudienceBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'popularity':
          result.popularity = serializers.deserialize(value, specifiedType: const FullType(int)) as int?;
          break;
        case 'onlineViewers':
          result.onlineViewers = serializers.deserialize(value, specifiedType: const FullType(int)) as int?;
          break;
        case 'totalViewers':
          result.totalViewers = serializers.deserialize(value, specifiedType: const FullType(int)) as int?;
          break;
        case 'primaryMetric':
          result.primaryMetric = serializers.deserialize(
            value,
            specifiedType: const FullType(LiveAudienceMetricType),
          ) as LiveAudienceMetricType?;
          break;
      }
    }

    return result.build();
  }
}

class _$RoomAudience extends RoomAudience {
  @override
  final int? popularity;
  @override
  final int? onlineViewers;
  @override
  final int? totalViewers;
  @override
  final LiveAudienceMetricType? primaryMetric;

  factory _$RoomAudience([void Function(RoomAudienceBuilder)? updates]) =>
      (RoomAudienceBuilder()..update(updates))._build();

  _$RoomAudience._({this.popularity, this.onlineViewers, this.totalViewers, this.primaryMetric}) : super._();
  @override
  RoomAudience rebuild(void Function(RoomAudienceBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  RoomAudienceBuilder toBuilder() => RoomAudienceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RoomAudience &&
        popularity == other.popularity &&
        onlineViewers == other.onlineViewers &&
        totalViewers == other.totalViewers &&
        primaryMetric == other.primaryMetric;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, popularity.hashCode);
    _$hash = $jc(_$hash, onlineViewers.hashCode);
    _$hash = $jc(_$hash, totalViewers.hashCode);
    _$hash = $jc(_$hash, primaryMetric.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RoomAudience')
          ..add('popularity', popularity)
          ..add('onlineViewers', onlineViewers)
          ..add('totalViewers', totalViewers)
          ..add('primaryMetric', primaryMetric))
        .toString();
  }
}

class RoomAudienceBuilder implements Builder<RoomAudience, RoomAudienceBuilder> {
  _$RoomAudience? _$v;

  int? _popularity;
  int? get popularity => _$this._popularity;
  set popularity(int? popularity) => _$this._popularity = popularity;

  int? _onlineViewers;
  int? get onlineViewers => _$this._onlineViewers;
  set onlineViewers(int? onlineViewers) => _$this._onlineViewers = onlineViewers;

  int? _totalViewers;
  int? get totalViewers => _$this._totalViewers;
  set totalViewers(int? totalViewers) => _$this._totalViewers = totalViewers;

  LiveAudienceMetricType? _primaryMetric;
  LiveAudienceMetricType? get primaryMetric => _$this._primaryMetric;
  set primaryMetric(LiveAudienceMetricType? primaryMetric) => _$this._primaryMetric = primaryMetric;

  RoomAudienceBuilder();

  RoomAudienceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _popularity = $v.popularity;
      _onlineViewers = $v.onlineViewers;
      _totalViewers = $v.totalViewers;
      _primaryMetric = $v.primaryMetric;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RoomAudience other) {
    _$v = other as _$RoomAudience;
  }

  @override
  void update(void Function(RoomAudienceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RoomAudience build() => _build();

  _$RoomAudience _build() {
    final _$result =
        _$v ??
        _$RoomAudience._(
          popularity: popularity,
          onlineViewers: onlineViewers,
          totalViewers: totalViewers,
          primaryMetric: primaryMetric,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
