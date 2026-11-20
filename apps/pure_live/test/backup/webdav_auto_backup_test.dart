import 'dart:async' show Completer;
import 'dart:convert' show utf8;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart';
import 'package:pure_live/features/backup/panes/backup_actions.dart' show kIncludeSecretsPref;
import 'package:pure_live/features/backup/webdav/webdav_accounts.dart';
import 'package:pure_live/features/backup/webdav/webdav_auto_backup.dart';
import 'package:pure_live/features/backup/webdav/webdav_auto_backup_scheduler.dart';
import 'package:pure_live/features/backup/webdav/webdav_client.dart';
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show appSecretStoreProvider;
import 'package:pure_live/modules/live/areas/data/area_follow_repository.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart';
import 'package:pure_live/modules/live/history/history_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';

/// The scheduled WebDAV backup: the pure timing rules (the interval, the
/// changed target's immediate due, the failures' backoff), the folder and
/// file-name vocabulary, the retention that names only the automatic files
/// at its own depth, the service's end to end walk over a recording drive,
/// and the scheduler's failure told once per run.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;
  late BackupRepository repository;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    repository = BackupRepository(
      follows: FollowRepository(await stores.openStore('follows')),
      history: HistoryRepository(await stores.openStore('history')),
      areaFollows: AreaFollowRepository(await stores.openStore('area_follows')),
      recordings: RecordingTaskRepository(await stores.openStore('recordings')),
    );
  });

  tearDown(() => stores.close());

  group('the timing rules', () {
    final start = DateTime.utc(2026, 11, 21, 8);
    const interval = Duration(hours: 24);

    test('the interval, the changed target and the never-uploaded one decide', () {
      const target = 't';
      // A first run is due at once.
      expect(
        WebDavAutoBackupRules.isDue(now: start, interval: interval, target: target, meta: WebDavAutoBackupMeta.none),
        isTrue,
      );
      // An interval not yet spent holds.
      final fresh = WebDavAutoBackupMeta(lastSuccess: start.subtract(const Duration(hours: 1)), target: target);
      expect(WebDavAutoBackupRules.isDue(now: start, interval: interval, target: target, meta: fresh), isFalse);
      expect(
        WebDavAutoBackupRules.isDue(
          now: start.add(const Duration(hours: 25)),
          interval: interval,
          target: target,
          meta: fresh,
        ),
        isTrue,
      );
      // A target that never uploaded is due however recent the last success.
      final moved = WebDavAutoBackupMeta(lastSuccess: start, target: 'old');
      expect(WebDavAutoBackupRules.isDue(now: start, interval: interval, target: target, meta: moved), isTrue);
    });

    test('the failures hold the next try off, and hold a moved target off too', () {
      const target = 't';
      // One failure ten minutes ago: the fifteen-minute backoff holds even a
      // changed target.
      final refused = WebDavAutoBackupMeta(
        lastAttempt: start.subtract(const Duration(minutes: 10)),
        failures: 1,
        target: 'old',
      );
      expect(WebDavAutoBackupRules.isDue(now: start, interval: interval, target: target, meta: refused), isFalse);
      // Sixteen minutes on, the changed target is due.
      expect(
        WebDavAutoBackupRules.isDue(
          now: start.add(const Duration(minutes: 6)),
          interval: interval,
          target: target,
          meta: refused,
        ),
        isTrue,
      );
      // A backoff longer than the interval never outwaits the interval.
      final beaten = WebDavAutoBackupMeta(lastAttempt: start.subtract(const Duration(hours: 3)), failures: 3);
      expect(
        WebDavAutoBackupRules.isDue(now: start, interval: const Duration(hours: 1), target: 't', meta: beaten),
        isTrue,
      );
    });

    test('the backoff climbs and repeats its last step, capped by the interval', () {
      expect(WebDavAutoBackupRules.backoff(0, const Duration(hours: 24)), Duration.zero);
      expect(WebDavAutoBackupRules.backoff(1, const Duration(hours: 24)), const Duration(minutes: 15));
      expect(WebDavAutoBackupRules.backoff(3, const Duration(hours: 24)), const Duration(hours: 1));
      expect(WebDavAutoBackupRules.backoff(6, const Duration(hours: 24)), const Duration(hours: 6));
      expect(WebDavAutoBackupRules.backoff(7, const Duration(hours: 24)), const Duration(hours: 6)); // the last repeats
      expect(WebDavAutoBackupRules.backoff(1, const Duration(minutes: 10)), const Duration(minutes: 10)); // capped
    });

    test('nextDue answers the moment or null when it is due now', () {
      final now = DateTime.utc(2026, 11, 21, 8);
      expect(WebDavAutoBackupRules.nextDue(now: now, interval: interval, meta: WebDavAutoBackupMeta.none), isNull);
      final fresh = WebDavAutoBackupMeta(lastSuccess: now.subtract(const Duration(hours: 1)));
      expect(
        WebDavAutoBackupRules.nextDue(now: now, interval: interval, meta: fresh),
        now.add(const Duration(hours: 23)),
      );
      // A pending retry outwaits the interval.
      final beaten = WebDavAutoBackupMeta(
        lastSuccess: now.subtract(const Duration(hours: 30)),
        lastAttempt: now.subtract(const Duration(minutes: 5)),
        failures: 3,
      );
      expect(
        WebDavAutoBackupRules.nextDue(now: now, interval: interval, meta: beaten),
        now.add(const Duration(minutes: 55)),
      );
    });
  });

  group('the folder and the file name', () {
    test('the folder splits into safe segments and refuses the rest', () {
      expect(parseWebDavAutoFolder('a/b/c'), ['a', 'b', 'c']);
      expect(parseWebDavAutoFolder(' /x// '), ['x']);
      expect(parseWebDavAutoFolder('a/b/'), ['a', 'b']);
      expect(parseWebDavAutoFolder(''), isNull);
      expect(parseWebDavAutoFolder('.'), isNull);
      expect(parseWebDavAutoFolder('a/../b'), isNull);
      expect(parseWebDavAutoFolder(r'a\b'), isNull);
      expect(parseWebDavAutoFolder('a\x00b'), isNull);
    });

    test('the automatic name carries auto before the stamp, and only it matches', () {
      final moment = DateTime(2026, 11, 21, 9, 8, 7);
      expect(webDavAutoBackupFileName(moment, followsOnly: false), 'pure_live_backup_auto_20261121_090807.json');
      expect(webDavAutoBackupFileName(moment, followsOnly: true), 'pure_live_follows_auto_20261121_090807.json');
      expect(isWebDavAutoBackupFile('pure_live_backup_auto_20261121_090807.json'), isTrue);
      expect(isWebDavAutoBackupFile('PURE_LIVE_FOLLOWS_AUTO_20261121_090807.JSON'), isTrue); // case-free
      expect(isWebDavAutoBackupFile('pure_live_backup_20261121_090807.json'), isFalse); // the manual export
      expect(isWebDavAutoBackupFile('renamed.json'), isFalse);
      expect(webDavAutoBackupTimeKey('pure_live_backup_auto_20261121_090807.json'), '20261121_090807');
    });

    test('the retention names only the automatic files at its own depth', () {
      WebDavEntry auto(String stamp) => WebDavEntry(
        name: 'pure_live_backup_auto_$stamp.json',
        path: '/pure_live/pure_live_backup_auto_$stamp.json',
        isDirectory: false,
      );
      final entries = [
        auto('20261120_000000'),
        const WebDavEntry(name: 'sub', path: '/pure_live/sub', isDirectory: true), // a folder is never named
        auto('20261119_000000'),
        const WebDavEntry(
          name: 'pure_live_backup_20261118_000000.json',
          path: '/pure_live/pure_live_backup_20261118_000000.json',
          isDirectory: false,
        ), // the manual export stands
        const WebDavEntry(
          name: 'pure_live_backup_auto_20261117_000000.json',
          path: '/pure_live/sub/pure_live_backup_auto_20261117_000000.json',
          isDirectory: false,
        ), // another depth's file is not this folder's
        auto('20261121_000000'),
      ];
      final gone = WebDavAutoBackupRules.prune(entries, folder: '/pure_live', keep: 1);
      expect(gone.map((entry) => entry.name), [
        'pure_live_backup_auto_20261120_000000.json',
        'pure_live_backup_auto_20261119_000000.json',
      ]);
      expect(WebDavAutoBackupRules.prune(entries, folder: '/pure_live', keep: 30), isEmpty);
      expect(
        WebDavAutoBackupRules.prune(entries, folder: '/other', keep: 1),
        isEmpty,
      ); // another folder owns nothing here
    });
  });

  group('the service over a recording drive', () {
    late _Drive drive;
    late ProviderContainer container;
    var clock = DateTime.utc(2026, 11, 21, 9, 8, 7);

    late Provider<WebDavAutoBackupService> autoService;
    setUp(() {
      drive = _Drive();
      // The service takes the provider's own Ref, so it is built here.
      autoService = Provider<WebDavAutoBackupService>((ref) {
        return WebDavAutoBackupService(
          ref,
          now: () => clock,
          clientFactory: ({required url, required username, required password}) {
            drive.signIns.add((url, username, password));
            return drive;
          },
        );
      });
      container = ProviderContainer(
        overrides: [
          backupRepositoryProvider.overrideWith((ref) async => repository),
          // The real vault build opens the platform keystore; tests answer it.
          appSecretStoreProvider.overrideWith((ref) => SecretStore.load(vault: _MapVault())),
        ],
      );
      addTearDown(container.dispose);
      // Without a listener the container disposes the service at once, and
      // its Ref goes dead under the timer's feet.
      container.listen(autoService, (_, _) {});
    });

    WebDavAutoBackupService service() => container.read(autoService);

    /// The schedule on, an account chosen.
    Future<void> armSchedule() async {
      await StoragePrefs.setString(
        kWebDavAccountsPref,
        encodeWebDavAccounts([const (id: 'acc1', name: 'nas', url: 'https://nas.example', user: 'me')]),
      );
      await container.read(webdavAutoBackupSettingsProvider.notifier).setEnabled(enabled: true);
    }

    test('a forced run uploads the document, records the success and prunes the old', () async {
      await armSchedule();
      await repository.follows.store.put('bili:1', {'roomId': 1});
      // The listing as the server answers it after the upload: the fresh
      // file, two older automatic ones, and a manual export.
      drive.listing = const [
        WebDavEntry(
          name: 'pure_live_backup_auto_20261121_090807.json',
          path: '/pure_live/pure_live_backup_auto_20261121_090807.json',
          isDirectory: false,
        ),
        WebDavEntry(
          name: 'pure_live_backup_auto_20261120_000000.json',
          path: '/pure_live/pure_live_backup_auto_20261120_000000.json',
          isDirectory: false,
        ),
        WebDavEntry(
          name: 'pure_live_backup_auto_20261119_000000.json',
          path: '/pure_live/pure_live_backup_auto_20261119_000000.json',
          isDirectory: false,
        ),
        WebDavEntry(
          name: 'pure_live_backup_20261118_000000.json',
          path: '/pure_live/pure_live_backup_20261118_000000.json',
          isDirectory: false,
        ),
      ];
      await container.read(webdavAutoBackupSettingsProvider.notifier).setKeep(1);

      final result = await service().runIfDue(force: true);
      expect(result.fileName, 'pure_live_backup_auto_20261121_090807.json');
      expect(result.skipped, isFalse);
      expect(result.error, isNull);

      // The drive saw the account and the folder, and the stamped file
      // carries the sections.
      expect(drive.signIns, hasLength(1));
      expect(drive.signIns.single.$1, 'https://nas.example');
      expect(drive.folders, ['pure_live']);
      final written = drive.files['/pure_live/pure_live_backup_auto_20261121_090807.json'];
      expect(written, isNotNull);
      expect(written, contains('"follows"'));

      // The run record landed, and the retention took the older automatic
      // file while the manual one stood.
      final meta = container.read(webdavAutoBackupMetaProvider);
      expect(meta.lastSuccess, clock.toUtc());
      expect(meta.failures, 0);
      expect(meta.target, isNotNull);
      expect(drive.deleted, [
        'pure_live_backup_auto_20261120_000000.json',
        'pure_live_backup_auto_20261119_000000.json',
      ]);
    });

    test('the checks with nothing to do skip, and say when the device is empty', () async {
      final auto = service();

      // Off.
      expect((await auto.runIfDue(force: true)).skipped, isTrue);

      // On, but no account: the controller read the empty list at its first
      // build, and a controller lives for the container's life.
      await container.read(webdavAutoBackupSettingsProvider.notifier).setEnabled(enabled: true);
      expect((await auto.runIfDue(force: true)).skipped, isTrue);

      // An account, but a folder that does not parse: a fresh container
      // reads the junk folder the way a restart would.
      await StoragePrefs.setString(
        kWebDavAccountsPref,
        encodeWebDavAccounts([const (id: 'a', name: 'n', url: 'https://n.example', user: 'u')]),
      );
      await StoragePrefs.setString(kWebDavAutoFolderPref, 'a/../b');
      final badContainer = ProviderContainer(
        overrides: [
          backupRepositoryProvider.overrideWith((ref) async => repository),
          appSecretStoreProvider.overrideWith((ref) => SecretStore.load(vault: _MapVault())),
        ],
      );
      addTearDown(badContainer.dispose);
      final badService = Provider<WebDavAutoBackupService>(
        (ref) => WebDavAutoBackupService(
          ref,
          clientFactory: ({required url, required username, required password}) => drive,
        ),
      );
      badContainer.listen(badService, (_, _) {});
      await badContainer
          .read(webdavAutoBackupSettingsProvider.notifier)
          .setEnabled(enabled: true); // keeps the junk folder
      expect(
        (await badContainer.read(badService).runIfDue(force: true)).skipped,
        isTrue,
      ); // the junk folder refuses before any ask

      // A good folder, an empty device. The follows scope is what makes the
      // emptiness speak: the accounts pref itself is backed-up content, so
      // the full scope would never call this device empty.
      final seeded = ProviderContainer(
        overrides: [
          backupRepositoryProvider.overrideWith((ref) async => repository),
          appSecretStoreProvider.overrideWith((ref) => SecretStore.load(vault: _MapVault())),
        ],
      );
      addTearDown(seeded.dispose);
      final seededService = Provider<WebDavAutoBackupService>(
        (ref) => WebDavAutoBackupService(
          ref,
          now: () => clock,
          clientFactory: ({required url, required username, required password}) => drive,
        ),
      );
      seeded.listen(seededService, (_, _) {});
      final seededSettings = seeded.read(webdavAutoBackupSettingsProvider.notifier);
      await seededSettings.setEnabled(enabled: true);
      await seededSettings.setFolder(
        WebDavAutoBackupSettings.defaultFolder,
      ); // the junk folder from the last write yields
      await seededSettings.setScope(WebDavAutoBackupScope.follows);
      final empty = await seeded.read(seededService).runIfDue(force: true);
      expect(empty.skipped, isTrue);
      expect(empty.empty, isTrue);

      // A restore in progress is skipped; nothing was uploaded mid-restore.
      await repository.follows.store.put('F1', {'roomId': 1});
      final lock = seeded.read(backupRestoreLockProvider);
      final gate = Completer<void>();
      final held = lock.run(() => gate.future);
      final busy = await seeded.read(seededService).runIfDue(force: true);
      expect(busy.skipped, isTrue);
      expect(drive.files, isEmpty);
      gate.complete();
      await held;
    });

    test('a refused upload records the failure, and the backoff holds the retry', () async {
      await armSchedule();
      await repository.follows.store.put('F1', {'roomId': 1});
      drive.writeFails = true;

      final failed = await service().runIfDue(force: true);
      expect(failed.error, isNotNull);
      final meta = container.read(webdavAutoBackupMetaProvider);
      expect(meta.failures, 1);
      expect(meta.lastSuccess, isNull);
      expect(meta.lastAttempt, clock.toUtc());

      // Force skips the due check; the rules hold the unforced one off —
      // ten minutes is inside the fifteen-minute backoff, sixteen is out.
      clock = clock.add(const Duration(minutes: 10));
      expect(service().isDue(), isFalse);
      clock = clock.add(const Duration(minutes: 6));
      expect(service().isDue(), isTrue);
    });

    test('the secrets ride only when both switches say so', () async {
      await armSchedule();
      await container.read(webdavAutoBackupSettingsProvider.notifier).setIncludeSecrets(include: true);
      await repository.follows.store.put('F1', {'roomId': 1});
      final vaultStore = await SecretStore.load(vault: _MapVault());
      await vaultStore.set('webdav.main.password', 'hush');
      final withVault = ProviderContainer(
        overrides: [
          appSecretStoreProvider.overrideWith((ref) => vaultStore),
          backupRepositoryProvider.overrideWith(
            (ref) async => BackupRepository(
              follows: repository.follows,
              history: repository.history,
              areaFollows: repository.areaFollows,
              recordings: repository.recordings,
              secrets: vaultStore,
            ),
          ),
        ],
      );
      addTearDown(withVault.dispose);
      final vaultService = Provider<WebDavAutoBackupService>(
        (ref) => WebDavAutoBackupService(
          ref,
          now: () => clock,
          clientFactory: ({required url, required username, required password}) => drive,
        ),
      );
      withVault.listen(vaultService, (_, _) {});
      WebDavAutoBackupService run() => withVault.read(vaultService);

      // The hub's switch is off: no upload carries the vault.
      final gated = await run().runIfDue(force: true);
      expect(gated.fileName, isNotNull);
      expect(drive.files.values.last.contains('"secrets"'), isFalse);

      // The hub allows: the secrets section rides with the rest.
      await StoragePrefs.setBool(kIncludeSecretsPref, true);
      clock = clock.add(const Duration(seconds: 1));
      final allowed = await run().runIfDue(force: true);
      expect(allowed.fileName, isNotNull);
      expect(drive.files.values.last, contains('"secrets"'));
    });
  });

  group('the scheduler', () {
    test('a server that stays down is told once, not once a tick', () async {
      final container = ProviderContainer(
        overrides: [
          backupRepositoryProvider.overrideWith((ref) async => repository),
          appSecretStoreProvider.overrideWith((ref) => SecretStore.load(vault: _MapVault())),
        ],
      );
      addTearDown(container.dispose);
      await StoragePrefs.setString(
        kWebDavAccountsPref,
        encodeWebDavAccounts([const (id: 'a', name: 'n', url: 'https://n.example', user: 'u')]),
      );
      await container.read(webdavAutoBackupSettingsProvider.notifier).setEnabled(enabled: true);
      await repository.follows.store.put('F1', {'roomId': 1});

      final drive = _Drive()..writeFails = true;
      final toasts = <(String, bool)>[];
      final clock = DateTime.utc(2026, 11, 21, 9);
      final autoServiceProvider = Provider<WebDavAutoBackupService>(
        (ref) => WebDavAutoBackupService(
          ref,
          now: () => clock,
          clientFactory: ({required url, required username, required password}) => drive,
        ),
      );
      final schedulerProvider = Provider<WebDavAutoBackupScheduler>(
        (ref) => WebDavAutoBackupScheduler(
          ref,
          ref.watch(autoServiceProvider),
          toast: (message, {required failed}) => toasts.add((message, failed)),
          checkInterval: const Duration(milliseconds: 10),
          startDelay: const Duration(milliseconds: 5),
          observeLifecycle: false,
        ),
      );
      // The listener first: a bare read disposes the provider at once.
      final scheduler = container.read(schedulerProvider);
      container
        ..listen(schedulerProvider, (_, _) {})
        ..listen(webdavAutoBackupSettingsProvider, (_, _) {});
      scheduler.start();
      expect(scheduler.timerActive, isTrue);
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Many ticks, one attempt — the failures' backoff holds the rest —
      // and one word to the viewer.
      expect(drive.writeCalls, 1);
      expect(toasts.where((toast) => toast.$2), hasLength(1));
      scheduler.dispose();
      expect(scheduler.timerActive, isFalse);
    });

    test('a paused scheduler arms no timer and answers a plain check with nothing', () async {
      final container = ProviderContainer(
        overrides: [
          backupRepositoryProvider.overrideWith((ref) async => repository),
          appSecretStoreProvider.overrideWith((ref) => SecretStore.load(vault: _MapVault())),
        ],
      );
      addTearDown(container.dispose);
      await container.read(webdavAutoBackupSettingsProvider.notifier).setEnabled(enabled: true);
      final schedulerProvider = Provider<WebDavAutoBackupScheduler>(
        (ref) => WebDavAutoBackupScheduler(
          ref,
          ref.watch(webdavAutoBackupServiceProvider),
          toast: (_, {required failed}) {},
          checkInterval: const Duration(milliseconds: 10),
          startDelay: const Duration(milliseconds: 5),
          observeLifecycle: false,
        ),
      );
      final scheduler = container.read(schedulerProvider)
        ..start()
        ..pause();
      expect(scheduler.timerActive, isFalse);
      await scheduler.checkNow(); // paused, not forced: nothing runs
      scheduler.dispose();
    });
  });
}

/// A drive the service talks to, recording everything.
final class _Drive implements WebDavBackupDrive {
  final List<String> folders = [];
  final Map<String, String> files = {};
  final List<String> deleted = [];
  final List<(String, String, String)> signIns = [];
  List<WebDavEntry> listing = const [];
  bool writeFails = false;
  int writeCalls = 0;

  @override
  Future<void> ensureFolder(List<String> segments) async {
    folders.add(segments.join('/'));
  }

  @override
  Future<void> writeFile(String path, List<int> bytes) async {
    writeCalls++;
    if (writeFails) throw const WebDavFailure(WebDavProblem.network);
    files[path] = utf8.decode(bytes);
  }

  @override
  Future<List<WebDavEntry>> list({String path = '/'}) async => listing;

  @override
  Future<void> delete(WebDavEntry entry) async {
    deleted.add(entry.name);
  }
}

/// A vault of plain strings, as the tests hold it.
final class _MapVault implements SecretVault {
  final Map<String, String> values = {};

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String ref, String plain) async {
    values[ref] = plain;
  }

  @override
  Future<void> delete(String ref) async {
    values.remove(ref);
  }
}
