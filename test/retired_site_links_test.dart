import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/shared_live_link_opener.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('a shared link of a retired platform is taken and answered as retired', () async {
    const text = '快来看直播 https://live.shopee.co.id/share?session=657188017 ';
    expect(Sites.isRetiredLink(text), isTrue);
    expect(SharedLiveLinkOpener.containsLiveLink(text), isTrue);

    final notices = <String>[];
    final opened = <LiveRoom>[];
    final opener = SharedLiveLinkOpener(
      parse: (_) async => const [],
      open: (room) async => opened.add(room),
      notify: notices.add,
    );
    expect(await opener.open(text), isFalse);
    expect(notices, ['platform_retired']);
    expect(opened, isEmpty);
  });

  test('supported and unrelated links are not treated as retired', () {
    expect(Sites.isRetiredLink('https://live.bilibili.com/545068'), isFalse);
    expect(Sites.isRetiredLink('https://www.twitch.tv/kyo1984123'), isFalse);
    expect(Sites.isRetiredLink('https://notrumble.com.example.org/x'), isFalse);
    expect(Sites.isRetiredLink('https://www.nimo.tv/live/1'), isTrue);
    expect(Sites.isRetiredLink('https://m.tb.cn/h.abc'), isTrue);
  });
}
