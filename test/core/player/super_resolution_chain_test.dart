import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' show mpvListOptionCommands;
import 'package:path/path.dart' as path;
import 'package:pure_live/core/player/super_resolution.dart';

/// Every shader name the two chains are built from, so a test directory can
/// hold a complete pack without repeating the private order lists.
const _allShaderNames = <String>[
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_VL.glsl',
  'Anime4K_Restore_CNN_M.glsl',
  'Anime4K_Restore_CNN_S.glsl',
  'Anime4K_Upscale_CNN_x2_VL.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
  'Anime4K_Upscale_CNN_x2_S.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
];

void main() {
  late Directory pack;

  setUp(() {
    pack = Directory.systemTemp.createTempSync('anime_shaders');
    for (final name in _allShaderNames) {
      File(path.join(pack.path, name)).writeAsStringSync('// shader\n');
    }
  });

  tearDown(() {
    if (pack.existsSync()) pack.deleteSync(recursive: true);
  });

  group('超分链路', () {
    test('质量档按挂载顺序给出各自独立的路径', () {
      final chain = superResolutionChain(SuperResolutionMode.quality, pack)!;

      expect(chain.map(path.basename), <String>[
        'Anime4K_Clamp_Highlights.glsl',
        'Anime4K_Restore_CNN_VL.glsl',
        'Anime4K_Upscale_CNN_x2_VL.glsl',
        'Anime4K_AutoDownscalePre_x2.glsl',
        'Anime4K_AutoDownscalePre_x4.glsl',
        'Anime4K_Upscale_CNN_x2_M.glsl',
      ]);
      // 一条一个文件：逗号串会被 mpv 当成单个文件名（Windows 直接判为非法路径）。
      expect(chain.every((file) => !file.contains(',')), isTrue);
      expect(chain.every((file) => path.isAbsolute(file)), isTrue);
    });

    test('效率档换成轻量卷积链，同样按顺序', () {
      expect(superResolutionChain(SuperResolutionMode.efficiency, pack)!.map(path.basename).take(3), <String>[
        'Anime4K_Clamp_Highlights.glsl',
        'Anime4K_Restore_CNN_M.glsl',
        'Anime4K_Restore_CNN_S.glsl',
      ]);
    });

    test('关闭档不声明任何链路', () {
      expect(superResolutionChain(SuperResolutionMode.off, pack), isNull);
    });

    test('缺一个文件就整条不挂 —— 半条链既说不清画面，也会把直播源判成播放失败', () {
      File(path.join(pack.path, 'Anime4K_Restore_CNN_VL.glsl')).deleteSync();

      expect(superResolutionChain(SuperResolutionMode.quality, pack), isNull);
    });
  });

  group('mpv 列表选项的写法', () {
    test('先 clr 再逐条 append，逗号串不作为参数出现', () {
      final chain = superResolutionChain(SuperResolutionMode.quality, pack)!;
      final commands = mpvListOptionCommands('glsl-shaders', chain);

      expect(commands.first, <String>['change-list', 'glsl-shaders', 'clr', '']);
      expect(commands.length, chain.length + 1);
      for (var i = 0; i < chain.length; i++) {
        expect(commands[i + 1], <String>['change-list', 'glsl-shaders', 'append', chain[i]]);
      }
      // mpv 现在只认 {a,b} 那种列表写法，裸串是一条；命令本身也不报"这条被当成了
      // 几项"，所以挂载数由适配层回读 glsl-shaders-count 复核。这里钉住的是
      // 没有任何参数装着多条路径。
      expect(commands.every((command) => command.every((argument) => !argument.contains(','))), isTrue);
    });

    test('空链只剩一次 clr', () {
      expect(mpvListOptionCommands('glsl-shaders', const <String>[]), <List<String>>[
        <String>['change-list', 'glsl-shaders', 'clr', ''],
      ]);
    });
  });
}
