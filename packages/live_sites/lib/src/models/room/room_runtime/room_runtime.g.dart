// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_runtime.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RoomRuntime extends RoomRuntime {
  @override
  final Object? streamHandle;
  @override
  final Object? danmakuHandle;

  factory _$RoomRuntime([void Function(RoomRuntimeBuilder)? updates]) =>
      (RoomRuntimeBuilder()..update(updates))._build();

  _$RoomRuntime._({this.streamHandle, this.danmakuHandle}) : super._();
  @override
  RoomRuntime rebuild(void Function(RoomRuntimeBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  RoomRuntimeBuilder toBuilder() => RoomRuntimeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RoomRuntime && streamHandle == other.streamHandle && danmakuHandle == other.danmakuHandle;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, streamHandle.hashCode);
    _$hash = $jc(_$hash, danmakuHandle.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RoomRuntime')
          ..add('streamHandle', streamHandle)
          ..add('danmakuHandle', danmakuHandle))
        .toString();
  }
}

class RoomRuntimeBuilder implements Builder<RoomRuntime, RoomRuntimeBuilder> {
  _$RoomRuntime? _$v;

  Object? _streamHandle;
  Object? get streamHandle => _$this._streamHandle;
  set streamHandle(Object? streamHandle) => _$this._streamHandle = streamHandle;

  Object? _danmakuHandle;
  Object? get danmakuHandle => _$this._danmakuHandle;
  set danmakuHandle(Object? danmakuHandle) => _$this._danmakuHandle = danmakuHandle;

  RoomRuntimeBuilder();

  RoomRuntimeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _streamHandle = $v.streamHandle;
      _danmakuHandle = $v.danmakuHandle;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RoomRuntime other) {
    _$v = other as _$RoomRuntime;
  }

  @override
  void update(void Function(RoomRuntimeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RoomRuntime build() => _build();

  _$RoomRuntime _build() {
    final _$result = _$v ?? _$RoomRuntime._(streamHandle: streamHandle, danmakuHandle: danmakuHandle);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
