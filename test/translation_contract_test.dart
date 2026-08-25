import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recording private-path messages use the keys consumed by the UI', () {
    final english = jsonDecode(File('assets/translations/en.json').readAsStringSync()) as Map<String, dynamic>;
    final chinese = jsonDecode(File('assets/translations/zh.json').readAsStringSync()) as Map<String, dynamic>;

    for (final key in ['record_private_path_title', 'record_private_path_message']) {
      expect(english[key], isA<String>().having((value) => value.trim(), key, isNotEmpty));
      expect(chinese[key], isA<String>().having((value) => value.trim(), key, isNotEmpty));
    }

    final hanCharacters = RegExp(r'[\u4e00-\u9fff]');
    expect(english['record_private_path_title'], isNot(matches(hanCharacters)));
    expect(english['record_private_path_message'], isNot(matches(hanCharacters)));
  });
}
