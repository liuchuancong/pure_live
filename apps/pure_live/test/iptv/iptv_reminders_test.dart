import 'dart:async' show Completer, StreamSubscription, unawaited;
import 'dart:convert' show jsonDecode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_auto_update.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_reminders.dart';

/// The module's programme reminders and the update preferences beside them:
/// what a toggle does and says, the moment the reminder turns into, the
/// lapsed reminders a launch cleans up, and the interval and auto-sync
/// choices writing through.
void main() {
  // The due path reads the root navigator's context for its toast; the
  // binding must exist for the key to answer null honestly.
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  // The store keeps milliseconds: the times are cut to them, so a
  // round-trip compares equal.
  IptvReminder reminderOf(String channel, {int inMs = 3600_000, String title = '晚间新闻'}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return IptvReminder(
      channelId: channel,
      title: title,
      start: DateTime.fromMillisecondsSinceEpoch(now + inMs),
      stop: DateTime.fromMillisecondsSinceEpoch(now + inMs + 1800_000),
    );
  }

  group('the reminder record', () {
    test('round-trips through the store JSON', () {
      final reminder = reminderOf('cctv-1');
      final back = IptvReminder.fromJson(reminder.toJson());
      expect(back, isNotNull);
      expect(back!.channelId, 'cctv-1');
      expect(back.title, '晚间新闻');
      expect(back.start, reminder.start);
      expect(back.stop, reminder.stop);
      expect(back.isFor('cctv-1', reminder.start), isTrue);
      expect(back.isFor('cctv-2', reminder.start), isFalse);
      expect(back.isFor('cctv-1', reminder.start.add(const Duration(seconds: 1))), isFalse);
    });

    test('a mangled record reads as nothing', () {
      expect(IptvReminder.fromJson('not a map'), isNull);
      expect(IptvReminder.fromJson({'title': '没有频道'}), isNull);
      expect(IptvReminder.fromJson({'channelId': '', 'start': 1, 'stop': 2}), isNull);
      expect(IptvReminder.fromJson({'channelId': 'cctv-1'}), isNull);
      // A title the station lost still reads, as an empty one.
      expect(IptvReminder.fromJson({'channelId': 'cctv-1', 'title': 7, 'start': 1, 'stop': 2})!.title, '');
    });
  });

  group('the reminder shelf', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    /// A listener keeps the shelf alive: Riverpod disposes an unlistened
    /// provider between the reads, and the timer then never runs.
    void keepAlive() => container.listen(iptvRemindersProvider, (_, _) {});

    IptvRemindersController shelf() => container.read(iptvRemindersProvider.notifier);
    List<IptvReminder> reminders() => container.read(iptvRemindersProvider);

    test('a lapsed reminder leaves the store, so it announces once', () async {
      // A reminder that came due while the app was closed.
      final lapsed = IptvReminder(
        channelId: 'cctv-1',
        title: '过点的新闻',
        start: DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch - 7200_000),
        stop: DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch - 3600_000),
      );
      final upcoming = reminderOf('cctv-2');
      await StoragePrefs.setString(kIptvRemindersKey, '[${jsonLine(lapsed)},${jsonLine(upcoming)}]');

      keepAlive();
      final first = container.read(iptvRemindersProvider);
      expect(first.map((reminder) => reminder.channelId), ['cctv-2']); // soonest first, lapsed out
      await pumpEventQueue(); // the launch's own cleanup runs without a waiter

      // The store itself loses the lapsed one: the announcement is the
      // trace, and a record that has served must not announce again at the
      // next launch.
      final kept = jsonDecode(StoragePrefs.getString(kIptvRemindersKey) ?? '[]') as List<Object?>;
      expect(kept.map((entry) => (entry! as Map<Object?, Object?>)['channelId']), ['cctv-2']);
    });

    test('a toggle sets, sorts, persists, and clears', () async {
      keepAlive();
      final late9 = reminderOf('cctv-9', inMs: 9_000_000, title: '九点档');
      final early2 = reminderOf('cctv-2', inMs: 2_000_000, title: '两点档');

      expect(await shelf().toggle(late9), IptvReminderToggle.set);
      expect(await shelf().toggle(early2), IptvReminderToggle.set);
      // The shelf reads soonest first whatever the order of the asks.
      expect(reminders().map((reminder) => reminder.channelId), ['cctv-2', 'cctv-9']);
      await pumpEventQueue();
      expect((StoragePrefs.getString(kIptvRemindersKey) ?? '').contains('两点档'), isTrue);

      expect(await shelf().toggle(early2), IptvReminderToggle.cleared);
      expect(reminders().map((reminder) => reminder.channelId), ['cctv-9']);
      await pumpEventQueue();
      expect((StoragePrefs.getString(kIptvRemindersKey) ?? '').contains('两点档'), isFalse);
    });

    test('a started programme refuses, and a full shelf caps', () async {
      keepAlive();
      final started = IptvReminder(
        channelId: 'cctv-1',
        title: '已开始的节目',
        start: DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch - 60_000),
        stop: DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch + 1800_000),
      );
      expect(await shelf().toggle(started), IptvReminderToggle.refused);
      expect(reminders(), isEmpty);

      for (var i = 0; i < kIptvReminderCap; i++) {
        expect(await shelf().toggle(reminderOf('ch$i')), IptvReminderToggle.set);
      }
      expect(await shelf().toggle(reminderOf('one more')), IptvReminderToggle.capped);
      expect(reminders(), hasLength(kIptvReminderCap));
    });

    test('the due reminder fires, leaves the shelf, and the next one follows', () async {
      keepAlive();
      final fired = <String>[];
      final done = Completer<void>();
      late final StreamSubscription<IptvReminder> sub;
      sub = shelf().fired.listen((reminder) {
        fired.add(reminder.channelId);
        if (fired.length == 2) {
          unawaited(sub.cancel());
          done.complete();
        }
      });
      addTearDown(() => unawaited(sub.cancel()));

      await shelf().toggle(reminderOf('cctv-1', inMs: 120, title: '马上开演'));
      await shelf().toggle(reminderOf('cctv-2', inMs: 400, title: '随后开演'));
      expect(reminders(), hasLength(2));

      await done.future.timeout(const Duration(seconds: 3));
      expect(fired, ['cctv-1', 'cctv-2']); // in the order they were armed
      expect(reminders(), isEmpty); // a rung reminder is no longer needed

      await pumpEventQueue();
      expect(StoragePrefs.getString(kIptvRemindersKey), '[]'); // and leaves the store
    });

    test('a toggle keeps the shelf when the timer was armed for a later one', () async {
      keepAlive();
      final fired = <String>[];
      final done = Completer<void>();
      late final StreamSubscription<IptvReminder> sub;
      sub = shelf().fired.listen((reminder) {
        fired.add(reminder.channelId);
        if (fired.length == 2) {
          unawaited(sub.cancel());
          done.complete();
        }
      });
      addTearDown(() => unawaited(sub.cancel()));

      // A later reminder armed the timer; an earlier ask joins the shelf and
      // must take the timer over.
      await shelf().toggle(reminderOf('cctv-9', inMs: 500));
      await shelf().toggle(reminderOf('cctv-2', inMs: 120));

      await done.future.timeout(const Duration(seconds: 3));
      // The earlier one rang first, and the due walk ran to the end.
      expect(fired, ['cctv-2', 'cctv-9']);
      expect(reminders(), isEmpty);
    });
  });

  group('the update preferences', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('the interval defaults to a day and writes through', () async {
      expect(container.read(iptvUpdateIntervalProvider), IptvUpdateInterval.day);
      expect(IptvUpdateInterval.sixHours.duration, const Duration(hours: 6));

      await container.read(iptvUpdateIntervalProvider.notifier).select(IptvUpdateInterval.sixHours);
      expect(container.read(iptvUpdateIntervalProvider), IptvUpdateInterval.sixHours);
      expect(StoragePrefs.getInt('iptv.update.hours'), 6);

      // The same choice again is nothing.
      await container.read(iptvUpdateIntervalProvider.notifier).select(IptvUpdateInterval.sixHours);
      expect(container.read(iptvUpdateIntervalProvider), IptvUpdateInterval.sixHours);

      // A fresh read of the same store keeps the choice.
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(iptvUpdateIntervalProvider), IptvUpdateInterval.sixHours);
    });

    test('a stored interval the choices lost falls back to the day', () async {
      await StoragePrefs.setInt('iptv.update.hours', 5); // nobody offers five hours
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(iptvUpdateIntervalProvider), IptvUpdateInterval.day);
    });

    test('auto-sync defaults off and writes through', () async {
      expect(container.read(iptvAutoSyncProvider), isFalse);

      await container.read(iptvAutoSyncProvider.notifier).set(value: true);
      expect(container.read(iptvAutoSyncProvider), isTrue);
      await pumpEventQueue();
      expect(StoragePrefs.getBool('iptv.autoSync'), isTrue);

      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(iptvAutoSyncProvider), isTrue);
    });
  });
}

/// One reminder as the JSON line the store keeps.
String jsonLine(IptvReminder reminder) {
  final json = reminder.toJson();
  return '{"channelId":"${json['channelId']}","title":"${json['title']}",'
      '"start":${json['start']},"stop":${json['stop']}}';
}
