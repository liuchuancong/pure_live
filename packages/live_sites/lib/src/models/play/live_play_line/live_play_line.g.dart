// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_play_line.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LivePlayLine extends LivePlayLine {
  @override
  final String url;
  @override
  final LiveStreamFormat format;
  @override
  final LivePlayFormatSource formatSource;
  @override
  final BuiltMap<String, String> headers;
  @override
  final LiveStreamCodec? codec;
  @override
  final String? lineLabel;
  @override
  final LivePlayLease? lease;
  @override
  final PlayGeometry geometry;
  @override
  final bool singleUse;

  factory _$LivePlayLine([void Function(LivePlayLineBuilder)? updates]) =>
      (LivePlayLineBuilder()..update(updates))._build();

  _$LivePlayLine._({
    required this.url,
    required this.format,
    required this.formatSource,
    required this.headers,
    this.codec,
    this.lineLabel,
    this.lease,
    required this.geometry,
    required this.singleUse,
  }) : super._();
  @override
  LivePlayLine rebuild(void Function(LivePlayLineBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LivePlayLineBuilder toBuilder() => LivePlayLineBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LivePlayLine &&
        url == other.url &&
        format == other.format &&
        formatSource == other.formatSource &&
        headers == other.headers &&
        codec == other.codec &&
        lineLabel == other.lineLabel &&
        lease == other.lease &&
        geometry == other.geometry &&
        singleUse == other.singleUse;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, url.hashCode);
    _$hash = $jc(_$hash, format.hashCode);
    _$hash = $jc(_$hash, formatSource.hashCode);
    _$hash = $jc(_$hash, headers.hashCode);
    _$hash = $jc(_$hash, codec.hashCode);
    _$hash = $jc(_$hash, lineLabel.hashCode);
    _$hash = $jc(_$hash, lease.hashCode);
    _$hash = $jc(_$hash, geometry.hashCode);
    _$hash = $jc(_$hash, singleUse.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LivePlayLine')
          ..add('url', url)
          ..add('format', format)
          ..add('formatSource', formatSource)
          ..add('headers', headers)
          ..add('codec', codec)
          ..add('lineLabel', lineLabel)
          ..add('lease', lease)
          ..add('geometry', geometry)
          ..add('singleUse', singleUse))
        .toString();
  }
}

class LivePlayLineBuilder
    implements Builder<LivePlayLine, LivePlayLineBuilder> {
  _$LivePlayLine? _$v;

  String? _url;
  String? get url => _$this._url;
  set url(String? url) => _$this._url = url;

  LiveStreamFormat? _format;
  LiveStreamFormat? get format => _$this._format;
  set format(LiveStreamFormat? format) => _$this._format = format;

  LivePlayFormatSource? _formatSource;
  LivePlayFormatSource? get formatSource => _$this._formatSource;
  set formatSource(LivePlayFormatSource? formatSource) =>
      _$this._formatSource = formatSource;

  MapBuilder<String, String>? _headers;
  MapBuilder<String, String> get headers =>
      _$this._headers ??= MapBuilder<String, String>();
  set headers(MapBuilder<String, String>? headers) => _$this._headers = headers;

  LiveStreamCodec? _codec;
  LiveStreamCodec? get codec => _$this._codec;
  set codec(LiveStreamCodec? codec) => _$this._codec = codec;

  String? _lineLabel;
  String? get lineLabel => _$this._lineLabel;
  set lineLabel(String? lineLabel) => _$this._lineLabel = lineLabel;

  LivePlayLeaseBuilder? _lease;
  LivePlayLeaseBuilder get lease => _$this._lease ??= LivePlayLeaseBuilder();
  set lease(LivePlayLeaseBuilder? lease) => _$this._lease = lease;

  PlayGeometryBuilder? _geometry;
  PlayGeometryBuilder get geometry =>
      _$this._geometry ??= PlayGeometryBuilder();
  set geometry(PlayGeometryBuilder? geometry) => _$this._geometry = geometry;

  bool? _singleUse;
  bool? get singleUse => _$this._singleUse;
  set singleUse(bool? singleUse) => _$this._singleUse = singleUse;

  LivePlayLineBuilder() {
    LivePlayLine._initialize(this);
  }

  LivePlayLineBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _url = $v.url;
      _format = $v.format;
      _formatSource = $v.formatSource;
      _headers = $v.headers.toBuilder();
      _codec = $v.codec;
      _lineLabel = $v.lineLabel;
      _lease = $v.lease?.toBuilder();
      _geometry = $v.geometry.toBuilder();
      _singleUse = $v.singleUse;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LivePlayLine other) {
    _$v = other as _$LivePlayLine;
  }

  @override
  void update(void Function(LivePlayLineBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LivePlayLine build() => _build();

  _$LivePlayLine _build() {
    _$LivePlayLine _$result;
    try {
      _$result =
          _$v ??
          _$LivePlayLine._(
            url: BuiltValueNullFieldError.checkNotNull(
              url,
              r'LivePlayLine',
              'url',
            ),
            format: BuiltValueNullFieldError.checkNotNull(
              format,
              r'LivePlayLine',
              'format',
            ),
            formatSource: BuiltValueNullFieldError.checkNotNull(
              formatSource,
              r'LivePlayLine',
              'formatSource',
            ),
            headers: headers.build(),
            codec: codec,
            lineLabel: lineLabel,
            lease: _lease?.build(),
            geometry: geometry.build(),
            singleUse: BuiltValueNullFieldError.checkNotNull(
              singleUse,
              r'LivePlayLine',
              'singleUse',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'headers';
        headers.build();

        _$failedField = 'lease';
        _lease?.build();
        _$failedField = 'geometry';
        geometry.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'LivePlayLine',
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
