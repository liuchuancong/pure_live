import 'package:live_sites/src/core/site_facts.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:test/test.dart';

void main() {
  group('platform facts (the reference tables)', () {
    test('the voice platforms are Missevan and KilaKila', () {
      expect(SiteFacts.voiceLive, {SiteIds.missevan, SiteIds.kilakila});
      expect(SiteFacts.isVoiceLive('KilaKila'), isTrue);
      expect(SiteFacts.isVoiceLive('bilibili'), isFalse);
    });

    test('ten platforms fold room id case', () {
      expect(SiteFacts.caseInsensitiveRoomIds, {
        SiteIds.twitch,
        SiteIds.soop,
        SiteIds.picarto,
        SiteIds.twitcasting,
        SiteIds.tiktok,
        SiteIds.pandaLive,
        SiteIds.douyu,
        SiteIds.kuaishou,
        SiteIds.bigo,
        SiteIds.kick,
      });
      expect(SiteFacts.ignoresRoomIdCase('TikTok'), isTrue);
      expect(SiteFacts.ignoresRoomIdCase('pandalive'), isTrue);
      expect(SiteFacts.ignoresRoomIdCase('bilibili'), isFalse);
    });

    test('the retired platforms and their hosts', () {
      expect(SiteFacts.retired, hasLength(11));
      expect(SiteFacts.retiredHosts, hasLength(15));
      expect(SiteFacts.isRetired('openrec'), isTrue);
      expect(SiteFacts.isRetired('kick'), isFalse, reason: 'Kick is supported again');
    });

    test('eleven platforms report super chats, in their own unit', () {
      expect(SiteFacts.superChatPlatforms, {
        SiteIds.bilibili,
        SiteIds.douyu,
        SiteIds.huya,
        SiteIds.missevan,
        SiteIds.kilakila,
        SiteIds.picarto,
        SiteIds.chzzk,
        SiteIds.youtube,
        SiteIds.seventeenLive,
        SiteIds.kick,
        SiteIds.sixRoom,
      });
      expect(SiteFacts.superChatUnitOf('bilibili'), LiveGiftUnit.yuan);
      expect(SiteFacts.superChatUnitOf('chzzk'), LiveGiftUnit.cheese);
      expect(SiteFacts.superChatUnitOf('sixroom'), LiveGiftUnit.sixCoin);
      expect(SiteFacts.superChatUnitOf('kick'), LiveGiftUnit.kicks);
      expect(SiteFacts.superChatUnitOf('acfun'), isNull);
      expect(SiteFacts.hasSuperChats('huya'), isTrue);
      expect(SiteFacts.hasSuperChats('acfun'), isFalse);
    });
  });
}
