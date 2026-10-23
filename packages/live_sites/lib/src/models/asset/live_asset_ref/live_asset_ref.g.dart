// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_asset_ref.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LiveAssetRef extends LiveAssetRef {
  @override
  final LiveAssetType type;
  @override
  final String? path;
  @override
  final Uri? uri;
  @override
  final LiveAssetRef? fallback;

  factory _$LiveAssetRef([void Function(LiveAssetRefBuilder)? updates]) =>
      (LiveAssetRefBuilder()..update(updates))._build();

  _$LiveAssetRef._({required this.type, this.path, this.uri, this.fallback})
    : super._();
  @override
  LiveAssetRef rebuild(void Function(LiveAssetRefBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LiveAssetRefBuilder toBuilder() => LiveAssetRefBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveAssetRef &&
        type == other.type &&
        path == other.path &&
        uri == other.uri &&
        fallback == other.fallback;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, path.hashCode);
    _$hash = $jc(_$hash, uri.hashCode);
    _$hash = $jc(_$hash, fallback.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveAssetRef')
          ..add('type', type)
          ..add('path', path)
          ..add('uri', uri)
          ..add('fallback', fallback))
        .toString();
  }
}

class LiveAssetRefBuilder
    implements Builder<LiveAssetRef, LiveAssetRefBuilder> {
  _$LiveAssetRef? _$v;

  LiveAssetType? _type;
  LiveAssetType? get type => _$this._type;
  set type(LiveAssetType? type) => _$this._type = type;

  String? _path;
  String? get path => _$this._path;
  set path(String? path) => _$this._path = path;

  Uri? _uri;
  Uri? get uri => _$this._uri;
  set uri(Uri? uri) => _$this._uri = uri;

  LiveAssetRefBuilder? _fallback;
  LiveAssetRefBuilder get fallback =>
      _$this._fallback ??= LiveAssetRefBuilder();
  set fallback(LiveAssetRefBuilder? fallback) => _$this._fallback = fallback;

  LiveAssetRefBuilder();

  LiveAssetRefBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _path = $v.path;
      _uri = $v.uri;
      _fallback = $v.fallback?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveAssetRef other) {
    _$v = other as _$LiveAssetRef;
  }

  @override
  void update(void Function(LiveAssetRefBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveAssetRef build() => _build();

  _$LiveAssetRef _build() {
    _$LiveAssetRef _$result;
    try {
      _$result =
          _$v ??
          _$LiveAssetRef._(
            type: BuiltValueNullFieldError.checkNotNull(
              type,
              r'LiveAssetRef',
              'type',
            ),
            path: path,
            uri: uri,
            fallback: _fallback?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'fallback';
        _fallback?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'LiveAssetRef',
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
