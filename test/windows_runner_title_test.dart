import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Upstream #883: the taskbar showed "pure_live" instead of the app name.
  test('Windows runner titles its window with the app name and finds it by the same title', () {
    final main = File('windows/runner/main.cpp').readAsStringSync();
    expect(main, contains(r'kWindowTitle[] = L"' + r'\u7EAF\u7CB9\u76F4\u64AD' + '"'));
    expect(main, contains('window.Create(kWindowTitle,'));
    expect(main, contains('FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", kWindowTitle)'));
    expect(main, isNot(contains('L"pure_live"')));

    final rc = File('windows/runner/Runner.rc').readAsStringSync();
    expect(rc, contains('VALUE "FileDescription", "纯粹直播"'));
    expect(rc, contains('#pragma code_page(65001)'));
  });
}
