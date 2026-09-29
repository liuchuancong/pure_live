@DefaultAsset('package:media_kit_lifecycle_test/fixture.dart')
library;

import 'dart:ffi';
import 'package:media_kit/ffi/ffi.dart';

@Native<Pointer<Char> Function()>(symbol: 'fixture_library_path')
external Pointer<Char> _libraryPath();

DynamicLibrary openFixture() =>
    DynamicLibrary.open(_libraryPath().cast<Utf8>().toDartString());

@Native<Void Function(Pointer<Void>)>(symbol: 'fixture_emit')
external void emit(Pointer<Void> handle);

@Native<Void Function(Pointer<Void>)>(symbol: 'fixture_start_stress')
external void startStress(Pointer<Void> handle);

@Native<Int32 Function()>(symbol: 'fixture_destroyed')
external int destroyed();

@Native<Int32 Function()>(symbol: 'fixture_violations')
external int violations();

@Native<Int32 Function(Pointer<Void>)>(symbol: 'fixture_waits')
external int waits(Pointer<Void> handle);

@Native<Void Function(Int32)>(symbol: 'fixture_block_destroy')
external void blockDestroy(int block);

@Native<Int32 Function(Pointer<Char>)>(symbol: 'fixture_bind_video')
external int bindVideo(Pointer<Char> path);

@Native<Int32 Function(Pointer<Void>)>(symbol: 'fixture_video_pause')
external int videoPause(Pointer<Void> handle);

String fixturePath() => _libraryPath().cast<Utf8>().toDartString();
