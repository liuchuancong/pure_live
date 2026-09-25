import 'dart:ffi';

import 'package:media_kit/ffi/ffi.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit/src/player/native/core/native_library.dart';
import 'package:media_kit_lifecycle_test/fixture.dart' as fixture;
import 'package:test/test.dart';

int bind(String path) {
  final pointer = path.toNativeUtf8();
  try {
    return fixture.bindVideo(pointer.cast());
  } finally {
    calloc.free(pointer);
  }
}

void main() {
  test(
    'video binds the player module, rejects alternatives, and recovers from errors',
    () async {
      expect(bind('missing-media-kit-library'), -1);
      // The lifecycle fixture lacks the render API. A failed load cannot poison
      // the subsequent binding or publish a partial symbol table.
      expect(bind(fixture.fixturePath()), -1);
      MediaKit.ensureInitialized();
      final player = Player(
        configuration: const PlayerConfiguration(vo: 'null', osc: false),
      );
      try {
        final handle = Pointer<Void>.fromAddress(await player.handle);
        expect(bind(NativeLibrary.path), 0);
        expect(bind(NativeLibrary.path), 0);
        await (player.platform! as NativePlayer).setProperty('pause', 'yes');
        expect(fixture.videoPause(handle), 1);
        expect(bind(fixture.fixturePath()), -2);
        // Rejection leaves the active symbol table and library reference intact.
        expect(fixture.videoPause(handle), 1);
      } finally {
        await player.dispose();
      }
    },
  );
}
