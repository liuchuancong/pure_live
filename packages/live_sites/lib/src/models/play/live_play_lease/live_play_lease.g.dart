// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_play_lease.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LivePlayLease extends LivePlayLease {
  @override
  final DateTime refreshAt;
  @override
  final DateTime? expiresAt;
  @override
  final bool requiresReconnect;

  factory _$LivePlayLease([void Function(LivePlayLeaseBuilder)? updates]) =>
      (LivePlayLeaseBuilder()..update(updates))._build();

  _$LivePlayLease._({
    required this.refreshAt,
    this.expiresAt,
    required this.requiresReconnect,
  }) : super._();
  @override
  LivePlayLease rebuild(void Function(LivePlayLeaseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LivePlayLeaseBuilder toBuilder() => LivePlayLeaseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LivePlayLease &&
        refreshAt == other.refreshAt &&
        expiresAt == other.expiresAt &&
        requiresReconnect == other.requiresReconnect;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, refreshAt.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, requiresReconnect.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LivePlayLease')
          ..add('refreshAt', refreshAt)
          ..add('expiresAt', expiresAt)
          ..add('requiresReconnect', requiresReconnect))
        .toString();
  }
}

class LivePlayLeaseBuilder
    implements Builder<LivePlayLease, LivePlayLeaseBuilder> {
  _$LivePlayLease? _$v;

  DateTime? _refreshAt;
  DateTime? get refreshAt => _$this._refreshAt;
  set refreshAt(DateTime? refreshAt) => _$this._refreshAt = refreshAt;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  bool? _requiresReconnect;
  bool? get requiresReconnect => _$this._requiresReconnect;
  set requiresReconnect(bool? requiresReconnect) =>
      _$this._requiresReconnect = requiresReconnect;

  LivePlayLeaseBuilder() {
    LivePlayLease._initialize(this);
  }

  LivePlayLeaseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _refreshAt = $v.refreshAt;
      _expiresAt = $v.expiresAt;
      _requiresReconnect = $v.requiresReconnect;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LivePlayLease other) {
    _$v = other as _$LivePlayLease;
  }

  @override
  void update(void Function(LivePlayLeaseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LivePlayLease build() => _build();

  _$LivePlayLease _build() {
    final _$result =
        _$v ??
        _$LivePlayLease._(
          refreshAt: BuiltValueNullFieldError.checkNotNull(
            refreshAt,
            r'LivePlayLease',
            'refreshAt',
          ),
          expiresAt: expiresAt,
          requiresReconnect: BuiltValueNullFieldError.checkNotNull(
            requiresReconnect,
            r'LivePlayLease',
            'requiresReconnect',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
