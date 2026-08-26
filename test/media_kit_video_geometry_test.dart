import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pure_live/player/adapters/media_kit_adapter.dart';

void main() {
  test('media_kit dimensions use one display-corrected decoder snapshot', () {
    expect(resolveMediaKitDisplaySize(const VideoParams(w: 1920, h: 1080, dw: 1920, dh: 1080)), (
      width: 1920,
      height: 1080,
    ));
    expect(resolveMediaKitDisplaySize(const VideoParams(w: 1920, h: 1080, dw: 1920, dh: 1080, rotate: 90)), (
      width: 1080,
      height: 1920,
    ));
    expect(resolveMediaKitDisplaySize(const VideoParams()), isNull);
  });
}
