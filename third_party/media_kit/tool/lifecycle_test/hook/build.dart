import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    await CBuilder.library(
      name: 'media_kit_test_mpv',
      assetName: 'fixture.dart',
      sources: [
        'src/fake_mpv.c',
        'src/video_binding.c',
        '../../../media_kit_video/common/mpv/media_kit_mpv.c',
      ],
      includes: ['../../../media_kit_video/common/mpv/include'],
      libraries: [
        if (input.config.code.targetOS == OS.linux) ...['pthread', 'dl'],
      ],
    ).run(input: input, output: output);
  });
}
