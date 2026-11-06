// The scheduled WebDAV backup: the pure rules (naming, folder, due/backoff,
// retention), the settings and meta round-trips, and one end-to-end upload
// against a recording client. The upload path is the data-loss boundary —
// it names the file it wrote and the copies it deleted.

import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, utf8;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show SecretStore, SecretVault, StoragePrefs;
import 'package:pure_live/features/backup/document/backup_document.dart' show BackupDocument, BackupSection;
import 'package:pure_live/features/backup/document/backup_repository.dart';
import 'package:pure_live/features/backup/webdav/webdav_accounts.dart';
import 'package:pure_live/features/backup/webdav/webdav_auto_backup.dart';
import 'package:pure_live/features/backup/webdav/webdav_auto_backup_scheduler.dart';
import 'package:pure_live/features/backup/webdav/webdav_client.dart';
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show appSecretStoreProvider;
import 'package:pure_live/modules/live/areas/areas.dart' show AreaFollowRepository;
import 'package:pure_live/modules/live/favorites/favorites.dart' show FollowRepository;
import 'package:pure_live/modules/live/history/history.dart' show HistoryRepository;
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart' show RecordingTaskRepository;

import '../features/lan_sync/support/memory_json_store.dart';

const ({String id, String name, String url, String user}) _account = (
  id: 'home',
  name: 'home',
  url: 'https://dav.test/dav/',
  user: 'u',
);

DateTime _utc(int year, int month, int day, [int hour = 0, int minute = 0, int second = 0]) =>
    DateTime.utc(year, month, day, hour, minute, second);

Future<void> _seedAccounts() async {
  await StoragePrefs.initSeeded({
    kWebDavAccountsPref: encodeWebDavAccounts([_account]),
    kWebDavSelectedPref: _account.id,
  });
}

/// A follows store holding one room, so the captured document is not empty.
MemoryJsonStore _followed() {
  final store = MemoryJsonStore();
  unawaited(store.put('douyin:1', {'roomId': '1'}));
  return store;
}

/// A vault that keeps its secrets in a map, so no test touches the platform
/// keychain.
final class _MemoryVault implements SecretVault {
  @override
  Future<Map<String, String>> readAll() async => const {};

  @override
  Future<void> write(String ref, String plain) async {}

  @override
  Future<void> delete(String ref) async {}
}

BackupRepository _repository({
  MemoryJsonStore? follows,
  MemoryJsonStore? history,
  MemoryJsonStore? areas,
  MemoryJsonStore? recordings,
}) {
  final followStore = follows ?? MemoryJsonStore();
  return BackupRepository(
    follows: FollowRepository(followStore),
    history: HistoryRepository(history ?? MemoryJsonStore()),
    areaFollows: AreaFollowRepository(areas ?? MemoryJsonStore()),
    recordings: RecordingTaskRepository(recordings ?? MemoryJsonStore()),
  );
}

/// A drive that records what the service asked of it, in place of the real
/// [WebDavBackupClient]; `ensureFolder` mirrors the real walk over the
/// recorded `createFolder` calls.
final class _RecordingClient implements WebDavBackupDrive {
  final List<String> foldersMade = [];
  final List<String> deleted = [];
  List<WebDavEntry> entries = const [];
  String? writtenPath;
  String? writtenBody;
  Exception? writeError;
  Exception? deleteError;

  /// The drive interface has no plain mkdir; the walk calls createFolder,
  /// which the real client exposes beside the four drive verbs.
  Future<void> createFolder(String path) async {
    foldersMade.add(path);
  }

  @override
  Future<void> ensureFolder(List<String> segments) async {
    final path = StringBuffer();
    for (final segment in segments) {
      path
        ..write('/')
        ..write(segment);
      await createFolder(path.toString());
    }
  }

  @override
  Future<void> writeFile(String path, List<int> bytes) async {
    if (writeError != null) throw writeError!;
    writtenPath = path;
    writtenBody = utf8.decode(bytes);
  }

  @override
  Future<List<WebDavEntry>> list({String path = WebDavBackupClient.root}) async => entries;

  @override
  Future<void> delete(WebDavEntry entry) async {
    if (deleteError != null) throw deleteError!;
    deleted.add(entry.path);
  }
}

/// The container with a real repository over memory stores, a memory vault
/// and the service always pointed at the recording drive.
Future<(ProviderContainer, _RecordingClient)> _container({
  WebDavAutoBackupSettings settings = const WebDavAutoBackupSettings(enabled: true),
  BackupRepository? repository,
  DateTime Function()? now,
}) async {
  await _seedAccounts();
  await StoragePrefs.setPrefs({
    kWebDavAutoEnabledPref: settings.enabled,
    kWebDavAutoHoursPref: settings.hours,
    kWebDavAutoScopePref: settings.scope.id,
    kWebDavAutoFolderPref: settings.folder,
    kWebDavAutoKeepPref: settings.keep,
    kWebDavAutoIncludeSecretsPref: settings.includeSecrets,
  });
  final client = _RecordingClient();
  final container = ProviderContainer(
    overrides: [
      backupRepositoryProvider.overrideWith((ref) async => repository ?? _repository(follows: _followed())),
      appSecretStoreProvider.overrideWith((ref) => SecretStore.load(vault: _MemoryVault())),
      webdavAutoBackupServiceProvider.overrideWith(
        (ref) =>
            WebDavAutoBackupService(ref, now: now, clientFactory: ({required url, required username, required password}) => client),
      ),
    ],
  );
  return (container, client);
}

void main() {
  setUp(() async {
    await StoragePrefs.initSeeded(const <String, Object?>{});
  });

  test('the automatic file name keeps the manual name readable and adds auto', () {
    final now = DateTime(2026, 11, 6, 9, 8, 7);
    expect(webDavAutoBackupFileName(now, followsOnly: false), 'pure_live_backup_auto_20261106_090807.json');
    expect(webDavAutoBackupFileName(now, followsOnly: true), 'pure_live_follows_auto_20261106_090807.json');
    // The manual exports themselves never match the retention pattern.
    expect(isWebDavAutoBackupFile('pure_live_backup_20261106_090807.json'), isFalse);
    expect(isWebDavAutoBackupFile('pure_live_follows_20261106_090807.json'), isFalse);
    expect(isWebDavAutoBackupFile('pure_live_backup_auto_20261106_090807.json'), isTrue);
    expect(isWebDavAutoBackupFile('pure_live_follows_auto_20261106_090807.JSON'), isTrue);
    expect(isWebDavAutoBackupFile('notes.json'), isFalse);
    expect(webDavAutoBackupTimeKey('pure_live_follows_auto_20261106_090807.json'), '20261106_090807');
  });

  test('a remote folder is a safe relative path', () {
    expect(parseWebDavAutoFolder(' pure_live '), ['pure_live']);
    expect(parseWebDavAutoFolder('/backup/pure_live/'), ['backup', 'pure_live']);
    expect(parseWebDavAutoFolder('备份/直播'), ['备份', '直播']);
    expect(parseWebDavAutoFolder(''), isNull);
    expect(parseWebDavAutoFolder('/'), isNull);
    expect(parseWebDavAutoFolder('..'), isNull);
    expect(parseWebDavAutoFolder('a/../b'), isNull);
    expect(parseWebDavAutoFolder(r'a\b'), isNull);
    expect(parseWebDavAutoFolder('a/./b'), isNull);
  });

  test('the backoff ramps up and never passes the interval', () {
    const interval = Duration(hours: 24);
    expect(WebDavAutoBackupRules.backoff(0, interval), Duration.zero);
    expect(WebDavAutoBackupRules.backoff(1, interval), const Duration(minutes: 15));
    expect(WebDavAutoBackupRules.backoff(2, interval), const Duration(minutes: 30));
    expect(WebDavAutoBackupRules.backoff(3, interval), const Duration(hours: 1));
    expect(WebDavAutoBackupRules.backoff(6, interval), const Duration(hours: 6));
    expect(WebDavAutoBackupRules.backoff(50, interval), const Duration(hours: 6));
    // A one-hour schedule cannot be pushed past itself.
    expect(WebDavAutoBackupRules.backoff(3, const Duration(hours: 1)), const Duration(hours: 1));
  });

  test('a run is due on the first check and only after the interval passed', () {
    const target = 't';
    const meta = WebDavAutoBackupMeta.none;
    final now = _utc(2026, 11, 6, 12);
    expect(
      WebDavAutoBackupRules.isDue(now: now, interval: const Duration(hours: 24), target: target, meta: meta),
      isTrue,
    );
    final succeeded = meta.copyWith(lastSuccess: now, target: target);
    expect(
      WebDavAutoBackupRules.isDue(now: _utc(2026, 11, 6, 13), interval: const Duration(hours: 24), target: target, meta: succeeded),
      isFalse,
    );
    expect(
      WebDavAutoBackupRules.isDue(now: _utc(2026, 11, 7, 12), interval: const Duration(hours: 24), target: target, meta: succeeded),
      isTrue,
    );
  });

  test('a changed target is due at once, unless a failure still holds', () {
    const oldTarget = 'a';
    const newTarget = 'b';
    final now = _utc(2026, 11, 6, 12);
    final fresh = WebDavAutoBackupMeta(lastSuccess: now, target: oldTarget);
    expect(
      WebDavAutoBackupRules.isDue(now: _utc(2026, 11, 6, 12, 1), interval: const Duration(hours: 24), target: newTarget, meta: fresh),
      isTrue,
    );
    // One failure ten minutes ago: the retry waits out the backoff.
    final failed = WebDavAutoBackupMeta(lastSuccess: now, target: oldTarget, lastAttempt: _utc(2026, 11, 6, 11, 55), failures: 1);
    expect(
      WebDavAutoBackupRules.isDue(now: _utc(2026, 11, 6, 12, 5), interval: const Duration(hours: 24), target: newTarget, meta: failed),
      isFalse,
    );
    expect(
      WebDavAutoBackupRules.isDue(now: _utc(2026, 11, 6, 12, 10), interval: const Duration(hours: 24), target: newTarget, meta: failed),
      isTrue,
    );
  });

  test('failures push the next try back but the last success still bounds it', () {
    const target = 't';
    // A failure after a success: the later of interval and backoff wins.
    final recovered = WebDavAutoBackupMeta(
      lastSuccess: _utc(2026, 11, 6, 10),
      target: target,
      lastAttempt: _utc(2026, 11, 6, 11, 58),
      failures: 1,
    );
    expect(
      WebDavAutoBackupRules.isDue(now: _utc(2026, 11, 6, 12), interval: const Duration(hours: 24), target: target, meta: recovered),
      isFalse,
    );
    // Due when both the backoff and the interval have run out.
    expect(
      WebDavAutoBackupRules.isDue(now: _utc(2026, 11, 7, 10), interval: const Duration(hours: 24), target: target, meta: recovered),
      isTrue,
    );
    // Failures alone (never succeeded): the backoff decides. The target is
    // "never uploaded", so the rules treat the check as a changed target
    // that a fresh failure still holds off.
    final never = WebDavAutoBackupMeta(lastAttempt: _utc(2026, 11, 6, 11, 58), failures: 1);
    expect(
      WebDavAutoBackupRules.isDue(now: _utc(2026, 11, 6, 12, 10), interval: const Duration(hours: 24), target: target, meta: never),
      isFalse,
    );
    expect(
      WebDavAutoBackupRules.isDue(now: _utc(2026, 11, 6, 12, 15), interval: const Duration(hours: 24), target: target, meta: never),
      isTrue,
    );
  });

  test('nextDue answers the earliest future moment the rules can name', () {
    const target = 't';
    final now = _utc(2026, 11, 6, 12);
    expect(
      WebDavAutoBackupRules.nextDue(now: now, interval: const Duration(hours: 24), meta: WebDavAutoBackupMeta.none),
      isNull,
      reason: 'nothing uploaded and nothing failed: due now',
    );
    final succeeded = WebDavAutoBackupMeta(lastSuccess: now, target: target);
    expect(
      WebDavAutoBackupRules.nextDue(now: _utc(2026, 11, 6, 13), interval: const Duration(hours: 24), meta: succeeded),
      _utc(2026, 11, 7, 12),
    );
    // The interval wins when it is already the later moment: a backoff
    // inside it does not pull the answer earlier.
    final failed = WebDavAutoBackupMeta(
      lastSuccess: now,
      target: target,
      lastAttempt: _utc(2026, 11, 7, 10),
      failures: 1,
    );
    expect(
      WebDavAutoBackupRules.nextDue(now: _utc(2026, 11, 7, 11), interval: const Duration(hours: 24), meta: failed),
      _utc(2026, 11, 7, 12),
    );
    // A backoff that outlasts the interval does move the answer.
    final lateFailure = WebDavAutoBackupMeta(
      lastSuccess: now,
      target: target,
      lastAttempt: _utc(2026, 11, 7, 13),
      failures: 1,
    );
    expect(
      WebDavAutoBackupRules.nextDue(now: _utc(2026, 11, 7, 11), interval: const Duration(hours: 24), meta: lateFailure),
      _utc(2026, 11, 7, 13, 15),
    );
    // A backoff already past answers null: due now.
    expect(
      WebDavAutoBackupRules.nextDue(now: _utc(2026, 11, 7, 13, 20), interval: const Duration(hours: 24), meta: lateFailure),
      isNull,
    );
  });

  test('retention names only the automatic files past the count, in place', () {
    WebDavEntry file(String name) => WebDavEntry(name: name, path: '/pure_live/$name', isDirectory: false);
    final entries = [
      file('pure_live_backup_auto_20261101_100000.json'),
      const WebDavEntry(name: 'sub', path: '/pure_live/sub', isDirectory: true),
      const WebDavEntry(
        name: 'pure_live_backup_20261102_100000.json',
        path: '/pure_live/pure_live_backup_20261102_100000.json',
        isDirectory: false,
      ),
      file('pure_live_follows_auto_20261103_100000.json'),
      const WebDavEntry(name: 'nested.json', path: '/pure_live/sub/pure_live_backup_auto_20261104_100000.json', isDirectory: false),
      file('pure_live_backup_auto_20261105_100000.json'),
    ];
    final doomed = WebDavAutoBackupRules.prune(entries, folder: '/pure_live', keep: 2);
    // Newest two automatic files stay; the 1st's copy goes. The manual file,
    // the folder and the nested copy are never named.
    expect(doomed.map((entry) => entry.name), ['pure_live_backup_auto_20261101_100000.json']);
  });

  test('retention with a count below one keeps nothing extra and nothing less', () {
    WebDavEntry file(String name) => WebDavEntry(name: name, path: '/a/$name', isDirectory: false);
    final entries = [file('pure_live_backup_auto_20261101_100000.json'), file('pure_live_backup_auto_20261102_100000.json')];
    expect(WebDavAutoBackupRules.prune(entries, folder: '/a', keep: 0), hasLength(2));
    expect(WebDavAutoBackupRules.prune(entries, folder: '/a', keep: 5), isEmpty);
  });

  test('settings round-trip through the prefs and clamp stored numbers', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(webdavAutoBackupSettingsProvider.notifier);

    expect(
      container.read(webdavAutoBackupSettingsProvider),
      const WebDavAutoBackupSettings(),
      reason: 'an empty store answers the defaults',
    );

    await controller.setEnabled(enabled: true);
    await controller.setHours(6);
    await controller.setKeep(30);
    await controller.setIncludeSecrets(include: true);
    expect(await controller.setFolder('backup/pure_live'), isTrue);
    expect(
      container.read(webdavAutoBackupSettingsProvider),
      const WebDavAutoBackupSettings(enabled: true, hours: 6, keep: 30, folder: 'backup/pure_live', includeSecrets: true),
    );

    // A fresh controller re-reads what was stored.
    final reread = container.refresh(webdavAutoBackupSettingsProvider);
    expect(reread.hours, 6);
    expect(reread.folder, 'backup/pure_live');

    // Stored junk clamps; an invalid folder keeps the old value.
    await StoragePrefs.setPrefs({kWebDavAutoHoursPref: 9999, kWebDavAutoKeepPref: 0, kWebDavAutoScopePref: 'nonsense'});
    final clamped = container.refresh(webdavAutoBackupSettingsProvider);
    expect(clamped.hours, WebDavAutoBackupSettings.maxHours);
    expect(clamped.keep, WebDavAutoBackupSettings.minKeep);
    expect(clamped.scope, WebDavAutoBackupScope.all);

    expect(await controller.setFolder(''), isFalse);
    expect(await controller.setFolder('a/../b'), isFalse);
    expect(container.read(webdavAutoBackupSettingsProvider).folder, 'backup/pure_live');
  });

  test('the follow scope carries rooms and areas only; the full scope carries settings too', () {
    expect(WebDavAutoBackupScope.follows.sections(includeSecrets: true), BackupSection.followsOnly);
    expect(WebDavAutoBackupScope.all.sections(includeSecrets: false), BackupSection.all);
    expect(WebDavAutoBackupScope.all.sections(includeSecrets: true), {...BackupSection.all, BackupSection.secrets});
  });

  test('the target fingerprint moves with the account, the folder and the contents', () {
    final folder = ['pure_live'];
    final base = webDavAutoBackupTarget(account: _account, folder: folder, scope: WebDavAutoBackupScope.all, includeSecrets: false);
    expect(
      webDavAutoBackupTarget(account: _account, folder: folder, scope: WebDavAutoBackupScope.all, includeSecrets: true),
      isNot(base),
    );
    expect(
      webDavAutoBackupTarget(account: _account, folder: ['other'], scope: WebDavAutoBackupScope.all, includeSecrets: false),
      isNot(base),
    );
    expect(
      webDavAutoBackupTarget(
        account: (id: 'home2', name: 'home2', url: 'https://other/dav/', user: ''),
        folder: folder,
        scope: WebDavAutoBackupScope.all,
        includeSecrets: false,
      ),
      isNot(base),
    );
    expect(jsonDecode(base), isMap);
  });

  test('the meta record round-trips through the prefs', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(webdavAutoBackupMetaProvider.notifier);

    expect(container.read(webdavAutoBackupMetaProvider), WebDavAutoBackupMeta.none);
    await controller.recordSuccess(now: _utc(2026, 11, 6, 12), target: 't');
    final after = container.read(webdavAutoBackupMetaProvider);
    expect(after.lastSuccess, _utc(2026, 11, 6, 12));
    expect(after.lastAttempt, _utc(2026, 11, 6, 12));
    expect(after.failures, 0);
    expect(after.target, 't');

    // The write is UTC-stamped and a fresh read restores it.
    await StoragePrefs.clear();
    expect(WebDavAutoBackupMeta.stored().lastSuccess, isNull, reason: 'the stored record is gone with the prefs');
    await controller.recordFailure(now: _utc(2026, 11, 6, 13));
    final failed = container.refresh(webdavAutoBackupMetaProvider);
    expect(failed.lastSuccess, _utc(2026, 11, 6, 12), reason: 'a failure never erases the last success');
    expect(failed.lastAttempt, _utc(2026, 11, 6, 13));
    expect(failed.failures, 1);
    expect(failed.target, 't');
  });

  test('an off schedule, a missing account and a broken folder skip without touching anything', () async {
    final (container, client) = await _container();
    addTearDown(container.dispose);
    final service = container.read(webdavAutoBackupServiceProvider);

    await container.read(webdavAutoBackupSettingsProvider.notifier).setEnabled(enabled: false);
    expect((await service.runIfDue(force: true)).skipped, isTrue);
    expect(client.foldersMade, isEmpty);

    await container.read(webdavAutoBackupSettingsProvider.notifier).setEnabled(enabled: true);
    await StoragePrefs.remove(kWebDavAccountsPref);
    expect(container.refresh(webdavAccountsProvider).accounts, isEmpty);
    expect((await service.runIfDue(force: true)).skipped, isTrue, reason: 'no account selected');
    expect(client.foldersMade, isEmpty);

    await _seedAccounts();
    expect(container.refresh(webdavAccountsProvider).accounts, isNotEmpty);
    // setFolder refuses junk and keeps the stored value; a corrupted pref is
    // what the parse guard is really for.
    await StoragePrefs.setString(kWebDavAutoFolderPref, 'a/../b');
    container.refresh(webdavAutoBackupSettingsProvider);
    expect((await service.runIfDue(force: true)).skipped, isTrue);
    expect(client.foldersMade, isEmpty);
    expect(service.isDue(), isFalse);
  });

  test('a due run makes the levels, uploads the document and records the success', () async {
    final (container, client) = await _container(
      settings: const WebDavAutoBackupSettings(enabled: true, folder: 'backup/pure_live'),
      now: () => _utc(2026, 11, 6, 12, 34, 56),
    );
    addTearDown(container.dispose);
    final service = container.read(webdavAutoBackupServiceProvider);
    expect(service.isDue(), isTrue, reason: 'nothing uploaded yet');

    final result = await service.runIfDue();
    expect(result.fileName, 'pure_live_backup_auto_20261106_123456.json');
    expect(client.foldersMade, ['/backup', '/backup/pure_live']);
    expect(client.writtenPath, '/backup/pure_live/${result.fileName}');
    // The written bytes are a backup document this app tagged.
    final document = jsonDecode(client.writtenBody!) as Map<String, Object?>;
    final version = document['version']! as Map<String, Object?>;
    expect(version['app'], BackupDocument.appTag);

    final meta = container.read(webdavAutoBackupMetaProvider);
    expect(meta.lastSuccess, _utc(2026, 11, 6, 12, 34, 56));
    expect(meta.failures, 0);
    expect(meta.target, isNotNull);
    expect(StoragePrefs.getString(kWebDavAutoLastSuccessPref), isNotNull);

    // The next check inside the interval is not due.
    expect(service.isDue(), isFalse);
  });

  test('a forced run uploads without waiting for the interval', () async {
    final (container, client) = await _container(now: () => _utc(2026, 11, 6, 12, 34, 56));
    addTearDown(container.dispose);
    final service = container.read(webdavAutoBackupServiceProvider);
    final first = await service.runIfDue();
    expect(first.fileName, isNotNull);
    expect(service.isDue(), isFalse);
    // Two uploads in the same second share a name by design: the later one
    // replaces the earlier, like the drive page's own upload does.
    final second = await service.runIfDue(force: true);
    expect(second.fileName, first.fileName);
    expect(client.writtenPath, '/pure_live/${second.fileName}');
  });

  test('a failed upload records the attempt and holds the next one off', () async {
    final (container, client) = await _container();
    addTearDown(container.dispose);
    client.writeError = const WebDavFailure(WebDavProblem.server, status: 500);
    final service = container.read(webdavAutoBackupServiceProvider);

    final result = await service.runIfDue();
    expect(result.error, isA<WebDavFailure>());
    final meta = container.read(webdavAutoBackupMetaProvider);
    expect(meta.lastSuccess, isNull);
    expect(meta.lastAttempt, isNotNull);
    expect(meta.failures, 1);
    expect(service.isDue(), isFalse, reason: 'the 15-minute backoff holds');
    expect(service.isDue(now: DateTime.now().toUtc().add(const Duration(minutes: 15))), isTrue);
  });

  test('a follows-only upload names a follows file and never carries secrets', () async {
    final (container, client) = await _container(
      settings: const WebDavAutoBackupSettings(enabled: true, scope: WebDavAutoBackupScope.follows, includeSecrets: true),
      now: () => _utc(2026, 11, 6, 12, 34, 56),
    );
    addTearDown(container.dispose);
    final result = await container.read(webdavAutoBackupServiceProvider).runIfDue(force: true);
    expect(result.fileName, 'pure_live_follows_auto_20261106_123456.json');
    // The follow scope cannot carry secrets, whatever its own switch says:
    // the target fingerprint says so, and the settings capture excludes them.
    final meta = container.read(webdavAutoBackupMetaProvider);
    expect(jsonDecode(meta.target!), containsPair('scope', 'follows'));
    expect((jsonDecode(meta.target!) as Map<String, Object?>)['secrets'], isFalse);
  });

  test('retention deletes only the automatic files beyond the count', () async {
    final (container, client) = await _container(settings: const WebDavAutoBackupSettings(enabled: true, keep: 2));
    addTearDown(container.dispose);
    client.entries = [
      const WebDavEntry(
        name: 'pure_live_backup_auto_20261101_100000.json',
        path: '/pure_live/pure_live_backup_auto_20261101_100000.json',
        isDirectory: false,
      ),
      const WebDavEntry(
        name: 'pure_live_backup_auto_20261102_100000.json',
        path: '/pure_live/pure_live_backup_auto_20261102_100000.json',
        isDirectory: false,
      ),
      const WebDavEntry(
        name: 'pure_live_backup_auto_20261103_100000.json',
        path: '/pure_live/pure_live_backup_auto_20261103_100000.json',
        isDirectory: false,
      ),
      const WebDavEntry(
        name: 'pure_live_backup_20261104_100000.json',
        path: '/pure_live/pure_live_backup_20261104_100000.json',
        isDirectory: false,
      ),
    ];
    final result = await container.read(webdavAutoBackupServiceProvider).runIfDue(force: true);
    expect(result.fileName, isNotNull);
    // The new upload plus the newest two old copies stay; the 1st's copy
    // goes, the manual file never does.
    expect(client.deleted, ['/pure_live/pure_live_backup_auto_20261101_100000.json']);
  });

  test('a failing listing or delete never fails the upload', () async {
    final (container, client) = await _container(settings: const WebDavAutoBackupSettings(enabled: true, keep: 1));
    addTearDown(container.dispose);
    // Retention runs after the upload landed; a delete the server refuses
    // is logged and the run still reports its file.
    client
      ..deleteError = const WebDavFailure(WebDavProblem.server, status: 500)
      ..entries = [
        const WebDavEntry(
          name: 'pure_live_backup_auto_20261101_100000.json',
          path: '/pure_live/pure_live_backup_auto_20261101_100000.json',
          isDirectory: false,
        ),
      ];
    final service = container.read(webdavAutoBackupServiceProvider);
    final result = await service.runIfDue(force: true);
    expect(result.fileName, isNotNull);
    expect(client.writtenPath, isNotNull);
  });

  testWidgets('the scheduler arms after the start delay, checks on the tick and stops on dispose', (tester) async {
    await _seedAccounts();
    await StoragePrefs.setPrefs({kWebDavAutoEnabledPref: true});
    final client = _RecordingClient();
    final container = ProviderContainer(
      overrides: [
        backupRepositoryProvider.overrideWith((ref) async => _repository(follows: _followed())),
        appSecretStoreProvider.overrideWith((ref) => SecretStore.load(vault: _MemoryVault())),
        webdavAutoBackupServiceProvider.overrideWith(
          (ref) =>
              WebDavAutoBackupService(ref, clientFactory: ({required url, required username, required password}) => client),
        ),
      ],
    );
    addTearDown(container.dispose);
    final toasts = <(String, bool)>[];
    // Built inside a provider so the scheduler sees a real Ref.
    final scheduler = container.read(
      Provider<WebDavAutoBackupScheduler>((ref) {
        return WebDavAutoBackupScheduler(
          ref,
          ref.read(webdavAutoBackupServiceProvider),
          toast: (message, {required failed}) => toasts.add((message, failed)),
          startDelay: Duration.zero,
          observeLifecycle: false,
        );
      }),
    )..start();
    expect(scheduler.timerActive, isTrue);
    // The start check is a fake-async timer; the pump fires it, and the
    // runAsync wait lets its awaited upload land.
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(container.read(webdavAutoBackupMetaProvider).lastSuccess, isNotNull, reason: 'the start check caught up');
    // The upload is told through the injected toast, as success.
    expect(toasts, hasLength(1));
    expect(toasts.single.$2, isFalse);
    expect(toasts.single.$1, contains('pure_live_backup_auto_'));
    scheduler.dispose();
    expect(scheduler.timerActive, isFalse);
  });

  testWidgets('a schedule switched off arms no timer and checks nothing', (tester) async {
    await _seedAccounts();
    await StoragePrefs.setPrefs({kWebDavAutoEnabledPref: false});
    final client = _RecordingClient();
    final container = ProviderContainer(
      overrides: [
        backupRepositoryProvider.overrideWith((ref) async => _repository(follows: _followed())),
        appSecretStoreProvider.overrideWith((ref) => SecretStore.load(vault: _MemoryVault())),
        webdavAutoBackupServiceProvider.overrideWith(
          (ref) =>
              WebDavAutoBackupService(ref, clientFactory: ({required url, required username, required password}) => client),
        ),
      ],
    );
    addTearDown(container.dispose);
    final scheduler = container.read(
      Provider<WebDavAutoBackupScheduler>(
        (ref) => WebDavAutoBackupScheduler(
          ref,
          ref.read(webdavAutoBackupServiceProvider),
          startDelay: Duration.zero,
          observeLifecycle: false,
        ),
      ),
    )..start();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    expect(scheduler.timerActive, isFalse);
    expect(container.read(webdavAutoBackupMetaProvider).lastSuccess, isNull);
    expect(client.writtenPath, isNull);
    scheduler.dispose();
  });
}
