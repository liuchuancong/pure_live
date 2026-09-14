import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

void main() {
  test('desktop playback never exposes application brightness control', () {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      expect(PlatformHelper.supportsBrightness, isFalse);
    }
  });

  test('resolved plugin graph keeps brightness writes on Android and iOS only', () {
    final graph = jsonDecode(File('.flutter-plugins-dependencies').readAsStringSync()) as Map<String, dynamic>;
    final plugins = Map<String, dynamic>.from(graph['plugins'] as Map);

    Set<String> namesFor(String platform) => (plugins[platform] as List<dynamic>)
        .map((entry) => Map<String, dynamic>.from(entry as Map)['name'] as String)
        .toSet();

    expect(namesFor('android'), contains('screen_brightness_android'));
    expect(namesFor('ios'), contains('screen_brightness_ios'));
    expect(namesFor('windows'), isNot(contains('screen_brightness_windows')));
    expect(namesFor('macos'), isNot(contains('screen_brightness_macos')));
  });

  test('tracked desktop registrants contain no physical-monitor brightness plugin', () {
    final windowsRegistrant = File('windows/flutter/generated_plugin_registrant.cc').readAsStringSync();
    final windowsCmake = File('windows/flutter/generated_plugins.cmake').readAsStringSync();
    final windowsProject = File('windows/CMakeLists.txt').readAsStringSync();
    final macosRegistrant = File('macos/Flutter/GeneratedPluginRegistrant.swift').readAsStringSync();

    expect(windowsRegistrant, isNot(contains('screen_brightness_windows')));
    expect(windowsCmake, isNot(contains('screen_brightness_windows')));
    expect(windowsProject, isNot(contains('screen_brightness_NOT_IMPLEMENTED')));
    expect(macosRegistrant, isNot(contains('screen_brightness_macos')));
  });

  test('dependency manifest uses only the mobile implementations', () {
    final manifest = File('pubspec.yaml').readAsStringSync();
    final lockfile = File('pubspec.lock').readAsStringSync();

    expect(RegExp(r'^  screen_brightness:', multiLine: true).hasMatch(manifest), isFalse);
    expect(RegExp(r'^  screen_brightness_platform_interface:', multiLine: true).hasMatch(manifest), isTrue);
    expect(RegExp(r'^  screen_brightness_android:', multiLine: true).hasMatch(manifest), isTrue);
    expect(RegExp(r'^  screen_brightness_ios:', multiLine: true).hasMatch(manifest), isTrue);
    expect(RegExp(r'^  screen_brightness_windows:', multiLine: true).hasMatch(lockfile), isFalse);
    expect(RegExp(r'^  screen_brightness_macos:', multiLine: true).hasMatch(lockfile), isFalse);
  });
}
