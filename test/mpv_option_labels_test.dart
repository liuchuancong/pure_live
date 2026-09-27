import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/utils/mpv_option_labels.dart';

void main() {
  test('every offered option survives the platform normalization', () {
    for (final platform in TargetPlatform.values) {
      for (final kind in MpvOptionKind.values) {
        final options = mpvOptionsForPlatform(kind, platform, zh: true);
        expect(options, isNotEmpty, reason: '$kind $platform');
        expect(options.map((o) => o.key).toSet(), hasLength(options.length), reason: 'no duplicates');
        for (final option in options) {
          expect(normalizedMpvOption(kind, option.key, platform), option.key, reason: '$kind ${option.key} $platform');
          expect(option.label, isNotEmpty);
        }
      }
    }
  });

  test('software decoding stays selectable and platforms keep their own lists', () {
    final windowsDecoders = mpvOptionsForPlatform(MpvOptionKind.hardwareDecoder, TargetPlatform.windows, zh: true);
    expect(windowsDecoders.map((o) => o.key), contains('no'));
    expect(windowsDecoders.firstWhere((o) => o.key == 'no').label, '关闭（软件解码）');

    final androidAudio = mpvOptionsForPlatform(MpvOptionKind.audioOutput, TargetPlatform.android, zh: false);
    expect(androidAudio.map((o) => o.key), ['auto', 'audiotrack', 'aaudio', 'opensles', 'null']);

    final iosVideo = mpvOptionsForPlatform(MpvOptionKind.videoOutput, TargetPlatform.iOS, zh: false);
    expect(iosVideo.map((o) => o.key), ['libmpv']);
  });

  test('values the player would reset are shown as what it actually uses', () {
    // The renderer list upstream offered "auto" and "caca"; neither is accepted here.
    expect(normalizedMpvOption(MpvOptionKind.videoOutput, 'caca', TargetPlatform.windows), 'gpu');
    expect(
      mpvOptionLabel(MpvOptionKind.audioOutput, 'wasapi', TargetPlatform.windows, zh: false),
      'WASAPI (Windows only)',
    );
  });
}
