// Explicit opt-in HTTPS/WUP compatibility check. No message text is persisted.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/data/platforms/huya/huya_site.dart';

void main() {
  test('production Huya site uses the bounded HTTPS message board', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final pid = int.parse(Platform.environment['PURELIVE_HUYA_BOARD_PID']!);
      final clock = Stopwatch()..start();
      try {
        final messages = await HuyaSite().getHuyaSuperChatMessageList(lPid: pid, first: true);
        // Counts and elapsed time only; never print messages or signed requests.
        // ignore: avoid_print
        print(
          jsonEncode({
            'probe': 'production-huya-message-board',
            'messageCount': messages.length,
            'elapsedMs': clock.elapsedMilliseconds,
            'secretsPersisted': false,
          }),
        );
      } catch (error) {
        fail('Huya message-board probe failed (${error.runtimeType})');
      }
    }, _RealNetwork());
  }, skip: Platform.environment['PURELIVE_HUYA_BOARD_PID'] == null);
}

class _RealNetwork extends HttpOverrides {}
