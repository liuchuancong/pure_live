import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart'
    show hongguoLowerRendition, hongguoPickRendition;
import 'package:pure_live/modules/hongguo/controller/hongguo_decoder.dart' show hongguoDecoderKey;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoRendition;

HongguoRendition _tier(int quality, String codec, {int? height}) => HongguoRendition(
  quality: quality,
  codec: codec,
  url: 'https://cdn.example/$quality-$codec.mp4',
  width: (quality * 9 / 16).round(),
  height: height ?? quality,
);

void main() {
  final ladder = [_tier(1080, 'h264'), _tier(1080, 'h265'), _tier(720, 'h265'), _tier(720, 'h264'), _tier(480, 'h264')];

  test('the best fitting tier wins, h264 breaking a tie', () {
    expect(hongguoPickRendition(ladder, 1080).codec, 'h264');
    expect(hongguoPickRendition(ladder, 720).quality, 720);
    expect(hongguoPickRendition(ladder, 720).codec, 'h264');
    expect(hongguoPickRendition(ladder, 480).quality, 480);
  });

  test('a tier the device failed before is passed over', () {
    final failed = hongguoDecoderKey('h264', (720 * 9 / 16).round(), 720);

    expect(hongguoPickRendition(ladder, 720, learnedFailures: {failed}).codec, 'h265');
  });

  test('with every fitting tier failed, the platform gets its way back', () {
    final failed = {
      for (final rendition in ladder)
        if (rendition.quality <= 480) hongguoDecoderKey(rendition.codec, rendition.width, rendition.height),
    };

    expect(hongguoPickRendition(ladder, 480, learnedFailures: failed).quality, 480);
  });

  test('a downgrade takes the next tier below, skipping failed ones', () {
    final current = _tier(1080, 'h264');
    expect(hongguoLowerRendition(ladder, current, 1080)!.quality, 720);

    final failed720 = {
      hongguoDecoderKey('h264', (720 * 9 / 16).round(), 720),
      hongguoDecoderKey('h265', (720 * 9 / 16).round(), 720),
    };
    expect(hongguoLowerRendition(ladder, current, 1080, learnedFailures: failed720)!.quality, 480);

    expect(hongguoLowerRendition(ladder, _tier(480, 'h264'), 1080), isNull);
  });
}
