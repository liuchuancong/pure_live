import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/utils/live_buffer_policy.dart';

void main() {
  test('live player keeps a bounded low-latency native buffer budget', () {
    expect(LiveBufferPolicy.forwardBytes, 32 * 1024 * 1024);
    expect(LiveBufferPolicy.backBytes, 4 * 1024 * 1024);
    expect(LiveBufferPolicy.readaheadSeconds, 2);
    expect(
      LiveBufferPolicy.forwardBytes + LiveBufferPolicy.backBytes,
      lessThanOrEqualTo(36 * 1024 * 1024),
    );
  });
}
