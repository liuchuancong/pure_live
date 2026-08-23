import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/utils/window_helper.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';

void main() {
  test('restores a saved Windows PiP rectangle on its original display', () {
    const primary = Rect.fromLTWH(0, 0, 1920, 1040);
    const secondary = Rect.fromLTWH(1920, 0, 2560, 1400);
    const saved = Rect.fromLTWH(3700, 800, 640, 360);

    expect(
      resolveWindowsPipBounds(
        defaultSize: const Size(360, 203),
        primaryWorkArea: primary,
        workAreas: const [primary, secondary],
        savedBounds: saved,
      ),
      saved,
    );
  });

  test('clamps an off-screen saved PiP rectangle into the primary work area', () {
    const primary = Rect.fromLTWH(0, 0, 1920, 1040);
    final resolved = resolveWindowsPipBounds(
      defaultSize: const Size(360, 203),
      primaryWorkArea: primary,
      workAreas: const [primary],
      savedBounds: const Rect.fromLTWH(8000, 5000, 600, 400),
    );

    expect(primary.contains(resolved.topLeft), isTrue);
    expect(resolved.right, lessThanOrEqualTo(primary.right));
    expect(resolved.bottom, lessThanOrEqualTo(primary.bottom));
    expect(resolved.size, const Size(600, 400));
  });

  test('window settings migration preserves PiP size and position', () {
    final config = WindowSizeController.extractConfig({
      'windowSize': <String, dynamic>{
        'windowsPipWidth': 640,
        'windowsPipHeight': 360,
        'windowsPipX': -600,
        'windowsPipY': 120,
      },
    });

    expect(config['windowsPipWidth'], 640.0);
    expect(config['windowsPipHeight'], 360.0);
    expect(config['windowsPipX'], -600.0);
    expect(config['windowsPipY'], 120.0);
    expect(config['windowsPip'], {
      'displayId': '',
      'windowsPipWidth': 640.0,
      'windowsPipHeight': 360.0,
      'windowsPipX': -600.0,
      'windowsPipY': 120.0,
    });
    expect(config['windowsPipDisplayId'], '');
  });

  test('window settings migration adopts the legacy player-owned preference', () {
    final config = WindowSizeController.extractConfig({
      'player': <String, dynamic>{'rememberPipPosition': false},
      'windowSize': <String, dynamic>{},
    });

    expect(config['rememberPipPosition'], isFalse);
  });

  test('current window preference wins over the legacy player value', () {
    final config = WindowSizeController.extractConfig({
      'player': <String, dynamic>{'rememberPipPosition': false},
      'windowSize': <String, dynamic>{'rememberPipPosition': true},
    });

    expect(config['rememberPipPosition'], isTrue);
  });

  test('legacy PiP edits are normalized into the current nested shape', () {
    final root = <String, dynamic>{
      'windowSize': <String, dynamic>{
        'windowsPip': <String, dynamic>{
          'displayId': 'display-1',
          'windowsPipWidth': 360.0,
          'windowsPipHeight': 203.0,
          'windowsPipX': 20.0,
          'windowsPipY': 30.0,
        },
      },
    };

    final merged = WindowSizeController.mergeConfig(root, {'windowsPipWidth': 640, 'windowsPipX': 100});
    final pip = merged['windowSize']['windowsPip'] as Map<String, dynamic>;

    expect(pip['displayId'], 'display-1');
    expect(pip['windowsPipWidth'], 640);
    expect(pip['windowsPipHeight'], 203.0);
    expect(pip['windowsPipX'], 100);
    expect(pip['windowsPipY'], 30.0);
  });
}
