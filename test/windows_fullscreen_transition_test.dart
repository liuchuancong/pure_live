import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/utils/fullscreen.dart';

void main() {
  test('Windows clears the frameless guard before entering fullscreen', () async {
    final calls = <String>[];

    await enterDesktopFullscreen(
      isWindows: true,
      prepareWindowsFullscreen: () async => calls.add('prepare-hidden-title-bar'),
      setFullScreen: (fullscreen) async => calls.add('fullscreen:$fullscreen'),
    );

    expect(calls, <String>['prepare-hidden-title-bar', 'fullscreen:true']);
  });

  test('other desktop platforms enter fullscreen without Windows preparation', () async {
    final calls = <String>[];

    await enterDesktopFullscreen(
      isWindows: false,
      prepareWindowsFullscreen: () async => calls.add('prepare-hidden-title-bar'),
      setFullScreen: (fullscreen) async => calls.add('fullscreen:$fullscreen'),
    );

    expect(calls, <String>['fullscreen:true']);
  });
}
