// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_audience_update.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LiveAudienceUpdate extends LiveAudienceUpdate {
  @override
  final LiveAudienceSignalKind kind;
  @override
  final int value;

  factory _$LiveAudienceUpdate([
    void Function(LiveAudienceUpdateBuilder)? updates,
  ]) => (LiveAudienceUpdateBuilder()..update(updates))._build();

  _$LiveAudienceUpdate._({required this.kind, required this.value}) : super._();
  @override
  LiveAudienceUpdate rebuild(
    void Function(LiveAudienceUpdateBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  LiveAudienceUpdateBuilder toBuilder() =>
      LiveAudienceUpdateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveAudienceUpdate &&
        kind == other.kind &&
        value == other.value;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveAudienceUpdate')
          ..add('kind', kind)
          ..add('value', value))
        .toString();
  }
}

class LiveAudienceUpdateBuilder
    implements Builder<LiveAudienceUpdate, LiveAudienceUpdateBuilder> {
  _$LiveAudienceUpdate? _$v;

  LiveAudienceSignalKind? _kind;
  LiveAudienceSignalKind? get kind => _$this._kind;
  set kind(LiveAudienceSignalKind? kind) => _$this._kind = kind;

  int? _value;
  int? get value => _$this._value;
  set value(int? value) => _$this._value = value;

  LiveAudienceUpdateBuilder();

  LiveAudienceUpdateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _value = $v.value;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveAudienceUpdate other) {
    _$v = other as _$LiveAudienceUpdate;
  }

  @override
  void update(void Function(LiveAudienceUpdateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveAudienceUpdate build() => _build();

  _$LiveAudienceUpdate _build() {
    final _$result =
        _$v ??
        _$LiveAudienceUpdate._(
          kind: BuiltValueNullFieldError.checkNotNull(
            kind,
            r'LiveAudienceUpdate',
            'kind',
          ),
          value: BuiltValueNullFieldError.checkNotNull(
            value,
            r'LiveAudienceUpdate',
            'value',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
