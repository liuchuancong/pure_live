import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LiveAudienceMetricType, LiveAudienceRankTier, LiveRoom, RoomAudience;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/settings/browse/audience_metric_provider.dart';

/// The figure a room card leads with, and the order a list sorts by: the
/// viewer's choice of metric, the real-online preference and the platforms
/// it reaches (normalized on the way in), a source without the asked figure
/// never leaving a blank card, and the store's answers.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  LiveRoom room(String platform, {int? popularity, int? online, int? total, LiveAudienceMetricType? primary}) =>
      LiveRoom.normalized(
        platform: platform,
        roomId: '1',
        audience: RoomAudience.of(
          popularity: popularity,
          onlineViewers: online,
          totalViewers: total,
          primaryMetric: primary,
        ),
      );

  group('the platform list', () {
    test('a platform id arrives trimmed, lower-cased and alone', () {
      expect(
        normalizeRealOnlinePlatforms([' douyin ', 'DOUYIN', 'kuaishou', '']),
        ['douyin', 'kuaishou'], // the duplicate and the blank dropped
      );
      expect(normalizeRealOnlinePlatforms(['nosuch-site']), isEmpty); // an unknown platform is not one
    });
  });

  group('the card figure', () {
    test("the viewer's choice leads, the rest fills in", () {
      final rich = room('douyin', popularity: 100, online: 10, total: 1000, primary: LiveAudienceMetricType.popularity);
      expect(audienceFigureOf(rich, AudienceMetricChoice.onlineViewers), 10); // the ask, over the primary
      expect(audienceFigureOf(rich, AudienceMetricChoice.totalViewers), 1000);
      expect(audienceFigureOf(rich, AudienceMetricChoice.automatic), 100); // automatic: the platform's own
    });

    test('a source without the asked figure still shows one', () {
      final shy = room('douyin', popularity: 100, primary: LiveAudienceMetricType.popularity);
      expect(audienceFigureOf(shy, AudienceMetricChoice.onlineViewers), 100); // the heat stands in
    });

    test('the real-online preference moves the lead, on the platforms it reaches', () {
      const on = AudiencePolicy(preferRealOnline: true, platforms: {'douyin'});
      final douyin = room('douyin', popularity: 100, online: 10, primary: LiveAudienceMetricType.popularity);
      final huya = room('huya', popularity: 200, online: 20, primary: LiveAudienceMetricType.popularity);
      final quiet = room('douyin', popularity: 100, primary: LiveAudienceMetricType.popularity);

      expect(audienceFigureOf(douyin, AudienceMetricChoice.automatic, policy: on), 10); // real viewers lead here
      expect(audienceFigureOf(huya, AudienceMetricChoice.automatic, policy: on), 200); // not on this platform
      expect(audienceFigureOf(quiet, AudienceMetricChoice.automatic, policy: on), 100); // nothing real: the primary
      expect(
        audienceFigureOf(douyin, AudienceMetricChoice.popularity, policy: on),
        100,
      ); // the preference only rides automatic
    });
  });

  group('the rank', () {
    test('the preference reaches the sort only under automatic', () {
      final douyin = room('douyin', popularity: 100, online: 10, primary: LiveAudienceMetricType.popularity);
      const on = AudiencePolicy(preferRealOnline: true, platforms: {'douyin'});

      expect(
        audienceRankOf(douyin, AudienceMetricChoice.automatic, policy: on).tier,
        LiveAudienceRankTier.concurrent, // the sort reads the way its cards do
      );
      expect(
        audienceRankOf(douyin, AudienceMetricChoice.popularity, policy: on).tier,
        LiveAudienceRankTier.native, // an explicit choice sorts by itself
      );
    });
  });

  group('the store', () {
    test('the metric choice defaults to automatic, stores, and a stranger reads as automatic', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(audienceMetricProvider), AudienceMetricChoice.automatic);

      await container.read(audienceMetricProvider.notifier).select(AudienceMetricChoice.totalViewers);
      expect(container.read(audienceMetricProvider), AudienceMetricChoice.totalViewers);

      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(second.read(audienceMetricProvider), AudienceMetricChoice.totalViewers); // the stored choice

      await StoragePrefs.setString(kAudienceMetricPref, 'junk');
      final third = ProviderContainer();
      addTearDown(third.dispose);
      expect(third.read(audienceMetricProvider), AudienceMetricChoice.automatic);
    });

    test("the real-online platforms start at the reference's list and keep their edits", () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final policy = container.read(audiencePolicyProvider);
      expect(policy.preferRealOnline, isFalse);
      expect(policy.platforms, kDefaultRealOnlinePlatforms.toSet()); // the reference's own list

      await container.read(audiencePolicyProvider.notifier).setPlatformEnabled('twitcasting', enabled: false);
      await container.read(audiencePolicyProvider.notifier).setPreferRealOnline(value: true);

      expect(container.read(audiencePolicyProvider).platforms.contains('twitcasting'), isFalse);
      expect(container.read(audiencePolicyProvider).preferRealOnline, isTrue);

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final stored = second.read(audiencePolicyProvider);
      expect(stored.preferRealOnline, isTrue);
      expect(stored.platforms.contains('twitcasting'), isFalse); // the edit survives the store
      expect(stored.enabledFor(' DOUYIN '), isTrue); // the untouched ones stay, reached by any case
      expect(stored.enabledFor('twitcasting'), isFalse); // and the dropped one stays out
    });

    test('a platform without a concurrent count cannot join', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(audiencePolicyProvider.notifier).setPlatformEnabled('nosuch-site', enabled: true);
      expect(container.read(audiencePolicyProvider).platforms.contains('nosuch-site'), isFalse);
    });
  });
}
