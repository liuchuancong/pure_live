import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_scheduler.dart';

void main() {
  test('cancellation is latched when native stop callback is registered late', () async {
    final token = TaskCancelToken();
    var calls = 0;

    await token.cancel();
    token.onCancel = () async {
      calls++;
    };
    await Future<void>.delayed(Duration.zero);

    expect(token.isCancelled, isTrue);
    expect(calls, 1);
    await token.cancel();
    expect(calls, 1);
  });
}
