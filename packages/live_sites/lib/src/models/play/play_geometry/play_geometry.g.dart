// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play_geometry.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayGeometry extends PlayGeometry {
  @override
  final int? width;
  @override
  final int? height;
  @override
  final int? frameRate;
  @override
  final int? bitrateKbps;

  factory _$PlayGeometry([void Function(PlayGeometryBuilder)? updates]) =>
      (PlayGeometryBuilder()..update(updates))._build();

  _$PlayGeometry._({this.width, this.height, this.frameRate, this.bitrateKbps}) : super._();
  @override
  PlayGeometry rebuild(void Function(PlayGeometryBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  PlayGeometryBuilder toBuilder() => PlayGeometryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayGeometry &&
        width == other.width &&
        height == other.height &&
        frameRate == other.frameRate &&
        bitrateKbps == other.bitrateKbps;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, width.hashCode);
    _$hash = $jc(_$hash, height.hashCode);
    _$hash = $jc(_$hash, frameRate.hashCode);
    _$hash = $jc(_$hash, bitrateKbps.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayGeometry')
          ..add('width', width)
          ..add('height', height)
          ..add('frameRate', frameRate)
          ..add('bitrateKbps', bitrateKbps))
        .toString();
  }
}

class PlayGeometryBuilder implements Builder<PlayGeometry, PlayGeometryBuilder> {
  _$PlayGeometry? _$v;

  int? _width;
  int? get width => _$this._width;
  set width(int? width) => _$this._width = width;

  int? _height;
  int? get height => _$this._height;
  set height(int? height) => _$this._height = height;

  int? _frameRate;
  int? get frameRate => _$this._frameRate;
  set frameRate(int? frameRate) => _$this._frameRate = frameRate;

  int? _bitrateKbps;
  int? get bitrateKbps => _$this._bitrateKbps;
  set bitrateKbps(int? bitrateKbps) => _$this._bitrateKbps = bitrateKbps;

  PlayGeometryBuilder();

  PlayGeometryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _width = $v.width;
      _height = $v.height;
      _frameRate = $v.frameRate;
      _bitrateKbps = $v.bitrateKbps;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayGeometry other) {
    _$v = other as _$PlayGeometry;
  }

  @override
  void update(void Function(PlayGeometryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayGeometry build() => _build();

  _$PlayGeometry _build() {
    final _$result =
        _$v ?? _$PlayGeometry._(width: width, height: height, frameRate: frameRate, bitrateKbps: bitrateKbps);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
