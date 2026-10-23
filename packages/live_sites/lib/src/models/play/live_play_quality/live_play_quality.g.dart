// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_play_quality.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LivePlayQuality extends LivePlayQuality {
  @override
  final String label;
  @override
  final String? qualityId;
  @override
  final int platformOrder;
  @override
  final bool isPlaybackUnconfirmed;
  @override
  final LiveStreamCodec? codec;

  factory _$LivePlayQuality([void Function(LivePlayQualityBuilder)? updates]) =>
      (LivePlayQualityBuilder()..update(updates))._build();

  _$LivePlayQuality._({
    required this.label,
    this.qualityId,
    required this.platformOrder,
    required this.isPlaybackUnconfirmed,
    this.codec,
  }) : super._();
  @override
  LivePlayQuality rebuild(void Function(LivePlayQualityBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  LivePlayQualityBuilder toBuilder() => LivePlayQualityBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LivePlayQuality &&
        label == other.label &&
        qualityId == other.qualityId &&
        platformOrder == other.platformOrder &&
        isPlaybackUnconfirmed == other.isPlaybackUnconfirmed &&
        codec == other.codec;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, qualityId.hashCode);
    _$hash = $jc(_$hash, platformOrder.hashCode);
    _$hash = $jc(_$hash, isPlaybackUnconfirmed.hashCode);
    _$hash = $jc(_$hash, codec.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LivePlayQuality')
          ..add('label', label)
          ..add('qualityId', qualityId)
          ..add('platformOrder', platformOrder)
          ..add('isPlaybackUnconfirmed', isPlaybackUnconfirmed)
          ..add('codec', codec))
        .toString();
  }
}

class LivePlayQualityBuilder implements Builder<LivePlayQuality, LivePlayQualityBuilder> {
  _$LivePlayQuality? _$v;

  String? _label;
  String? get label => _$this._label;
  set label(String? label) => _$this._label = label;

  String? _qualityId;
  String? get qualityId => _$this._qualityId;
  set qualityId(String? qualityId) => _$this._qualityId = qualityId;

  int? _platformOrder;
  int? get platformOrder => _$this._platformOrder;
  set platformOrder(int? platformOrder) => _$this._platformOrder = platformOrder;

  bool? _isPlaybackUnconfirmed;
  bool? get isPlaybackUnconfirmed => _$this._isPlaybackUnconfirmed;
  set isPlaybackUnconfirmed(bool? isPlaybackUnconfirmed) => _$this._isPlaybackUnconfirmed = isPlaybackUnconfirmed;

  LiveStreamCodec? _codec;
  LiveStreamCodec? get codec => _$this._codec;
  set codec(LiveStreamCodec? codec) => _$this._codec = codec;

  LivePlayQualityBuilder() {
    LivePlayQuality._initialize(this);
  }

  LivePlayQualityBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _label = $v.label;
      _qualityId = $v.qualityId;
      _platformOrder = $v.platformOrder;
      _isPlaybackUnconfirmed = $v.isPlaybackUnconfirmed;
      _codec = $v.codec;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LivePlayQuality other) {
    _$v = other as _$LivePlayQuality;
  }

  @override
  void update(void Function(LivePlayQualityBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LivePlayQuality build() => _build();

  _$LivePlayQuality _build() {
    final _$result =
        _$v ??
        _$LivePlayQuality._(
          label: BuiltValueNullFieldError.checkNotNull(label, r'LivePlayQuality', 'label'),
          qualityId: qualityId,
          platformOrder: BuiltValueNullFieldError.checkNotNull(platformOrder, r'LivePlayQuality', 'platformOrder'),
          isPlaybackUnconfirmed: BuiltValueNullFieldError.checkNotNull(
            isPlaybackUnconfirmed,
            r'LivePlayQuality',
            'isPlaybackUnconfirmed',
          ),
          codec: codec,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
