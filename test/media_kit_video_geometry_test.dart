import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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

  test('missing rotation metadata keeps an already portrait source portrait', () {
    const params = VideoParams(w: 1080, h: 1920, dw: 1080, dh: 1920);
    final surfaceSize = resolveVideoParamsDisplaySize(params);
    expect(surfaceSize?.width, 1080);
    expect(surfaceSize?.height, 1920);
    expect(resolveMediaKitDisplaySize(params), (width: 1080, height: 1920));
  });

  test('display geometry falls back only to a complete raw dimension pair', () {
    final rawFallback = resolveVideoParamsDisplaySize(const VideoParams(w: 720, h: 1280, dw: 1920));
    final correctedPair = resolveVideoParamsDisplaySize(const VideoParams(w: 720, dw: 1920, dh: 1080));
    expect((rawFallback?.width, rawFallback?.height), (720, 1280));
    expect((correctedPair?.width, correctedPair?.height), (1920, 1080));
  });

  test('rotation is normalized and applied exactly once', () {
    const portraitByNegativeRotation = VideoParams(w: 1920, h: 1080, dw: 1920, dh: 1080, rotate: -90);
    const portraitByLargeRotation = VideoParams(w: 1920, h: 1080, dw: 1920, dh: 1080, rotate: 450);
    final negativeRotation = resolveVideoParamsDisplaySize(portraitByNegativeRotation);
    final largeRotation = resolveVideoParamsDisplaySize(portraitByLargeRotation);
    expect((negativeRotation?.width, negativeRotation?.height), (1080, 1920));
    expect((largeRotation?.width, largeRotation?.height), (1080, 1920));
  });
}
