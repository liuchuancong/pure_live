// Runs inside the real Android/Windows runner, where the pure_live/native_http
// channel exists:  flutter test integration_test/native_http_kick_test.dart -d windows
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pure_live/core/common/android_native_http.dart';
import 'package:pure_live/core/site/kick/kick_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kick.com is reachable through the native TLS channel', (tester) async {
    expect(AndroidNativeHttp.supportsKick, isTrue);
    final response = await AndroidNativeHttp.getKickJson(
      url: 'https://kick.com/stream/livestreams/en?page=1&limit=5',
      headers: KickApi.headers,
    );
    expect(response.status, 200);
    expect(jsonDecode(response.body), isA<Object>());
  });

  testWidgets('the native channel refuses other hosts', (tester) async {
    await expectLater(
      AndroidNativeHttp.getKickJson(url: 'https://example.com/', headers: const {}),
      throwsA(anything),
    );
  });
}
