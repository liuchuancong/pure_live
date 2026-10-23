// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_playback_plan.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LivePlaybackPlan extends LivePlaybackPlan {
  @override
  final BuiltList<LivePlayLine> lines;
  @override
  final LivePlayQuality? appliedQuality;
  @override
  final bool qualityUnconfirmed;
  @override
  final Duration? start;

  factory _$LivePlaybackPlan([void Function(LivePlaybackPlanBuilder)? updates]) =>
      (LivePlaybackPlanBuilder()..update(updates))._build();

  _$LivePlaybackPlan._({required this.lines, this.appliedQuality, required this.qualityUnconfirmed, this.start})
    : super._();
  @override
  LivePlaybackPlan rebuild(void Function(LivePlaybackPlanBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  LivePlaybackPlanBuilder toBuilder() => LivePlaybackPlanBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LivePlaybackPlan &&
        lines == other.lines &&
        appliedQuality == other.appliedQuality &&
        qualityUnconfirmed == other.qualityUnconfirmed &&
        start == other.start;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, lines.hashCode);
    _$hash = $jc(_$hash, appliedQuality.hashCode);
    _$hash = $jc(_$hash, qualityUnconfirmed.hashCode);
    _$hash = $jc(_$hash, start.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LivePlaybackPlan')
          ..add('lines', lines)
          ..add('appliedQuality', appliedQuality)
          ..add('qualityUnconfirmed', qualityUnconfirmed)
          ..add('start', start))
        .toString();
  }
}

class LivePlaybackPlanBuilder implements Builder<LivePlaybackPlan, LivePlaybackPlanBuilder> {
  _$LivePlaybackPlan? _$v;

  ListBuilder<LivePlayLine>? _lines;
  ListBuilder<LivePlayLine> get lines => _$this._lines ??= ListBuilder<LivePlayLine>();
  set lines(ListBuilder<LivePlayLine>? lines) => _$this._lines = lines;

  LivePlayQualityBuilder? _appliedQuality;
  LivePlayQualityBuilder get appliedQuality => _$this._appliedQuality ??= LivePlayQualityBuilder();
  set appliedQuality(LivePlayQualityBuilder? appliedQuality) => _$this._appliedQuality = appliedQuality;

  bool? _qualityUnconfirmed;
  bool? get qualityUnconfirmed => _$this._qualityUnconfirmed;
  set qualityUnconfirmed(bool? qualityUnconfirmed) => _$this._qualityUnconfirmed = qualityUnconfirmed;

  Duration? _start;
  Duration? get start => _$this._start;
  set start(Duration? start) => _$this._start = start;

  LivePlaybackPlanBuilder() {
    LivePlaybackPlan._initialize(this);
  }

  LivePlaybackPlanBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _lines = $v.lines.toBuilder();
      _appliedQuality = $v.appliedQuality?.toBuilder();
      _qualityUnconfirmed = $v.qualityUnconfirmed;
      _start = $v.start;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LivePlaybackPlan other) {
    _$v = other as _$LivePlaybackPlan;
  }

  @override
  void update(void Function(LivePlaybackPlanBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LivePlaybackPlan build() => _build();

  _$LivePlaybackPlan _build() {
    _$LivePlaybackPlan _$result;
    try {
      _$result =
          _$v ??
          _$LivePlaybackPlan._(
            lines: lines.build(),
            appliedQuality: _appliedQuality?.build(),
            qualityUnconfirmed: BuiltValueNullFieldError.checkNotNull(
              qualityUnconfirmed,
              r'LivePlaybackPlan',
              'qualityUnconfirmed',
            ),
            start: start,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'lines';
        lines.build();
        _$failedField = 'appliedQuality';
        _appliedQuality?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'LivePlaybackPlan', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
