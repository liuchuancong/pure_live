import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/adapters/fvp_adapter.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/utils/player_consts.dart';

void main() {
  test('fvp is a selectable engine with its own key and label', () {
    expect(PlayerConsts.engines['fvp'], PlayerEngine.fvp);
    expect(PlayerConsts.names['fvp'], 'player_fvp');
    // Automatic fallback order keeps the existing engines first.
    expect(PlayerEngine.values.last, PlayerEngine.fvp);
  });

  test('request headers become CRLF lines and injected lines are dropped', () {
    expect(
      FvpAdapter.encodeHeaders({'Referer': 'https://live.shopee.co.id/', 'User-Agent': 'UA'}),
      'Referer: https://live.shopee.co.id/\r\nUser-Agent: UA\r\n',
    );
    expect(FvpAdapter.encodeHeaders({'X-A': 'ok\r\nInjected: 1', 'Bad:Name': 'v', '': 'v'}), isEmpty);
  });

  test('software-only decoding when hardware decoding is off', () {
    expect(FvpAdapter.videoDecoders(hardware: false), ['FFmpeg', 'dav1d']);
    expect(FvpAdapter.videoDecoders(hardware: true), contains('FFmpeg'));
  });

  test('Android prefers OpenSL over AAudio; desktop keeps mdk defaults', () {
    expect(FvpAdapter.audioBackends(android: true), ['OpenSL', 'AudioTrack', 'AAudio']);
    expect(FvpAdapter.audioBackends(android: false), isNull);
  });

  test('legacy HEVC FLV hosts decode in software on Android only', () {
    const shopee = 'https://play-spe.livestream.shopee.co.id/live/id-live-1.flv?x=1';
    const other = 'https://hw.flv.huya.com/src/a.flv';
    expect(FvpAdapter.videoDecodersFor(shopee, hardware: true, android: true), ['FFmpeg', 'dav1d']);
    expect(FvpAdapter.videoDecodersFor(other, hardware: true, android: true), FvpAdapter.videoDecoders(hardware: true));
    expect(
      FvpAdapter.videoDecodersFor(shopee, hardware: true, android: false),
      FvpAdapter.videoDecoders(hardware: true),
    );
  });
}
