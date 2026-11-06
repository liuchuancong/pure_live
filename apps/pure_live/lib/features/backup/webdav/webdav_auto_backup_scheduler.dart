import 'dart:async' show Timer, unawaited;
import 'dart:convert' show utf8;

import 'package:desen_ui/desen_ui.dart' show DsStatus, showDsToast;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_storage/live_storage.dart' show SecretStore;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/window/window_providers.dart' show isPrimaryWindowProvider;
import 'package:pure_live/app/routing/navigation/root_navigator.dart' show rootNavigatorKey;
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart'
    show BackupRepository, backupRepositoryProvider, backupRestoreLockProvider;
import 'package:pure_live/features/backup/panes/backup_actions.dart' show includeSecretsAllowed;
import 'package:pure_live/features/backup/webdav/webdav_accounts.dart';
import 'package:pure_live/features/backup/webdav/webdav_auto_backup.dart';
import 'package:pure_live/features/backup/webdav/webdav_client.dart';
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show appSecretStoreProvider;
import 'package:pure_live/l10n/translations.dart' show t;

/// Builds the drive one scheduled upload goes through; the scheduler's
/// default makes the real client, a test hands in a fake.
typedef WebDavAutoBackupClientFactory =
    WebDavBackupDrive Function({required String url, required String username, required String password});

/// How one scheduled check ended.
final class WebDavAutoBackupResult {
  const WebDavAutoBackupResult._({this.fileName, this.error, this.skipped = false, this.empty = false});

  /// Uploaded [fileName].
  const WebDavAutoBackupResult.uploaded(String fileName) : this._(fileName: fileName);

  /// Nothing to do: off, not due, no account, an invalid folder, or — with
  /// [empty] — a document with nothing in it.
  const WebDavAutoBackupResult.skipped({bool empty = false}) : this._(skipped: true, empty: empty);

  /// The upload failed with [error].
  const WebDavAutoBackupResult.failed(Object error) : this._(error: error);

  /// The uploaded file, when there was one.
  final String? fileName;

  /// The failure, when there was one.
  final Object? error;

  /// Whether the check had nothing to do.
  final bool skipped;

  /// Whether the device's data was empty, so nothing was worth uploading.
  final bool empty;
}

/// One scheduled upload, end to end: reads the settings and the selected
/// account, decides whether a run is due, captures the document, makes
/// the remote folder, writes the stamped file, records the outcome and
/// deletes the automatic files beyond the retention count.
///
/// The service is plain — a `Ref`, a clock and a client factory — so the
/// scheduler and a test drive it the same way.
final class WebDavAutoBackupService {
  /// Creates the service over the ref's providers; `now` is the clock and
  /// `clientFactory` the transport, both replaceable for tests.
  WebDavAutoBackupService(this._ref, {DateTime Function()? now, WebDavAutoBackupClientFactory? clientFactory})
    : _now = now ?? DateTime.now,
      _clientFactory = clientFactory ?? _realClient;

  final Ref _ref;
  final DateTime Function() _now;
  final WebDavAutoBackupClientFactory _clientFactory;

  static WebDavBackupDrive _realClient({required String url, required String username, required String password}) =>
      WebDavBackupClient(url: url, username: username, password: password);

  /// Whether a run is due now (or at [now]): the switch is on, an account is
  /// selected, the folder parses, and the rules say so.
  bool isDue({DateTime? now}) {
    final plan = _plan();
    if (plan == null) return false;
    return WebDavAutoBackupRules.isDue(
      now: (now ?? _now()).toUtc(),
      interval: plan.settings.interval,
      target: plan.target,
      meta: _ref.read(webdavAutoBackupMetaProvider),
    );
  }

  /// Uploads when due; otherwise answers [WebDavAutoBackupResult.skipped].
  /// [force] skips the due check (the pane's "back up now").
  Future<WebDavAutoBackupResult> runIfDue({bool force = false}) async {
    final plan = _plan();
    if (plan == null) return const WebDavAutoBackupResult.skipped();
    final now = _now().toUtc();
    final meta = _ref.read(webdavAutoBackupMetaProvider);
    if (!force &&
        !WebDavAutoBackupRules.isDue(now: now, interval: plan.settings.interval, target: plan.target, meta: meta)) {
      return const WebDavAutoBackupResult.skipped();
    }
    // A restore in progress is rewriting the stores the document reads:
    // capturing mid-restore would back up a half-old half-new state. The
    // next tick retries.
    if (_ref.read(backupRestoreLockProvider).busy) return const WebDavAutoBackupResult.skipped();
    final log = appLog.forCategory('backup.webdav.auto');
    try {
      final repository = await _ref.read(backupRepositoryProvider.future);
      final document = _capture(repository, plan);
      if (document.isEmpty) {
        log.info('nothing to upload: the document is empty');
        return const WebDavAutoBackupResult.skipped(empty: true);
      }
      final password = await readAccountPassword(await _secretStore(), plan.account.id);
      final client = _clientFactory(url: plan.account.url, username: plan.account.user, password: password);
      await client.ensureFolder(plan.folder);
      final folderPath = '/${plan.folder.join('/')}';
      final name = webDavAutoBackupFileName(_now(), followsOnly: document.followsOnly);
      await client.writeFile('$folderPath/$name', utf8.encode(document.encode()));
      await _ref.read(webdavAutoBackupMetaProvider.notifier).recordSuccess(now: now, target: plan.target);
      log.info('uploaded', fields: {'file': name, 'folder': folderPath});
      await _prune(client, folderPath, plan.settings.keep, log);
      return WebDavAutoBackupResult.uploaded(name);
    } on Object catch (error, stackTrace) {
      log.error('the scheduled upload failed', error: error, stackTrace: stackTrace);
      await _ref.read(webdavAutoBackupMetaProvider.notifier).recordFailure(now: now);
      return WebDavAutoBackupResult.failed(error);
    }
  }

  /// The settings, the account and the folder a run needs, or null when
  /// one of them is missing: off, no account, or a folder that does not
  /// parse.
  _Plan? _plan() {
    final settings = _ref.read(webdavAutoBackupSettingsProvider);
    if (!settings.enabled) return null;
    final account = _ref.read(webdavAccountsProvider.notifier).current;
    if (account == null) return null;
    final folder = parseWebDavAutoFolder(settings.folder);
    if (folder == null) return null;
    // The hub's switch has the last word on secrets: off there, the
    // document never carries them whatever the schedule's own switch says.
    final secrets = settings.includeSecrets && includeSecretsAllowed();
    return _Plan(
      settings: settings,
      account: account,
      folder: folder,
      includeSecrets: secrets,
      target: webDavAutoBackupTarget(
        account: account,
        folder: folder,
        scope: settings.scope,
        includeSecrets: secrets,
      ),
    );
  }

  BackupDocument _capture(BackupRepository repository, _Plan plan) =>
      repository.capture(sections: plan.settings.scope.sections(includeSecrets: plan.includeSecrets));

  Future<SecretStore?> _secretStore() async {
    try {
      return await _ref.read(appSecretStoreProvider.future);
    } on Object {
      return null;
    }
  }

  /// Deletes the automatic files beyond [keep]. A failure here is logged
  /// and swallowed: the upload already landed, and a full folder is a
  /// smaller problem than a missing backup.
  Future<void> _prune(WebDavBackupDrive client, String folder, int keep, LiveLog log) async {
    try {
      final entries = await client.list(path: folder);
      for (final entry in WebDavAutoBackupRules.prune(entries, folder: folder, keep: keep)) {
        try {
          await client.delete(entry);
        } on Object catch (error) {
          log.warning('an old automatic backup could not be deleted', fields: {'file': entry.name, 'error': '$error'});
        }
      }
    } on Object catch (error) {
      log.warning('the automatic backups could not be listed for retention', fields: {'error': '$error'});
    }
  }
}

final class _Plan {
  const _Plan({
    required this.settings,
    required this.account,
    required this.folder,
    required this.includeSecrets,
    required this.target,
  });

  final WebDavAutoBackupSettings settings;
  final WebDavAccount account;
  final List<String> folder;
  final bool includeSecrets;
  final String target;
}

/// Runs [WebDavAutoBackupService] while the app is in use: once shortly
/// after start, every [checkInterval], when the app returns to the
/// foreground, and after any of the schedule's settings change. Nothing
/// runs in the background or after the app closes — the most a timer in
/// the app process can honestly promise, like the IPTV guide updater.
///
/// Only the primary window runs one: a clone shares the same prefs, and
/// two windows would upload the same document twice.
final class WebDavAutoBackupScheduler with WidgetsBindingObserver {
  /// Creates the scheduler over the ref; the toast, the interval, the start
  /// delay and the lifecycle switch are replaceable for tests.
  WebDavAutoBackupScheduler(
    this._ref,
    this._service, {
    void Function(String message, {required bool failed})? toast,
    this.checkInterval = const Duration(minutes: 15),
    this.startDelay = const Duration(seconds: 20),
    this.observeLifecycle = true,
  }) : _toast = toast ?? _rootToast;

  final Ref _ref;
  final WebDavAutoBackupService _service;
  final void Function(String message, {required bool failed}) _toast;

  /// How often a check runs while the app is in use.
  final Duration checkInterval;

  /// How long after [start] the first check runs, so it does not compete
  /// with the first frame and the stores' own opening.
  final Duration startDelay;

  /// Whether the scheduler pauses while the app is in the background.
  final bool observeLifecycle;

  Timer? _first;
  Timer? _timer;
  ProviderSubscription<WebDavAutoBackupSettings>? _settings;
  Future<void>? _checking;
  bool _started = false;
  bool _paused = false;
  bool _disposed = false;
  bool _failureToldThisRun = false;

  /// Whether the periodic check is armed (tests read it).
  bool get timerActive => _timer?.isActive ?? false;

  /// Starts the schedule once.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _settings = _ref.listen(webdavAutoBackupSettingsProvider, (previous, next) {
      if (previous == next) return;
      _syncTimer();
      // A changed target is due at once; a changed interval is answered by
      // the rules on the next check. Either way one check settles it.
      unawaited(checkNow());
    });
    if (observeLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _paused = switch (WidgetsBinding.instance.lifecycleState) {
        AppLifecycleState.paused || AppLifecycleState.detached || AppLifecycleState.hidden => true,
        _ => false,
      };
    }
    _syncTimer();
    _first = Timer(startDelay, () => unawaited(checkNow()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        pause();
      case AppLifecycleState.resumed:
        resume();
      case AppLifecycleState.inactive:
        // Transient on the way to paused, or a dialog taking focus.
        break;
    }
  }

  /// Stops checking while the app is away.
  void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  /// Checks once when the app is back, then resumes the schedule.
  void resume() {
    if (!_started || _disposed || !_paused) return;
    _paused = false;
    _syncTimer();
    unawaited(checkNow());
  }

  /// One check; a second call while one runs shares its future. [force]
  /// skips the due check (the pane's "back up now") and tells every
  /// failure, not only the first.
  Future<void> checkNow({bool force = false}) {
    if (_disposed || (_paused && !force)) return Future<void>.value();
    if (!force && !_ref.read(webdavAutoBackupSettingsProvider).enabled) return Future<void>.value();
    if (_checking case final running?) return running;
    late final Future<void> check;
    check = _run(force: force).whenComplete(() {
      if (identical(_checking, check)) _checking = null;
    });
    _checking = check;
    return check;
  }

  Future<void> _run({required bool force}) async {
    try {
      final result = await _service.runIfDue(force: force);
      if (result.fileName case final name?) {
        _toast(t.backup.webdavAutoUploaded(file: name), failed: false);
      } else if (result.error case final error?) {
        _tellFailure(error, force: force);
      }
    } on Object catch (error, stackTrace) {
      appLog.forCategory('backup.webdav.auto').error('the scheduler failed', error: error, stackTrace: stackTrace);
      _tellFailure(error, force: force);
    }
  }

  /// A failure is told once per run of the app unless the viewer asked for
  /// the upload themselves; later ones go to the log alone, so a server
  /// that stays down does not nag every fifteen minutes.
  void _tellFailure(Object error, {required bool force}) {
    if (!force && _failureToldThisRun) return;
    _failureToldThisRun = true;
    _toast(t.backup.webdavAutoFailed(reason: webDavAutoFailureText(error)), failed: true);
  }

  void _syncTimer() {
    final on = !_disposed && !_paused && _ref.read(webdavAutoBackupSettingsProvider).enabled;
    if (on && _timer == null) {
      _timer = Timer.periodic(checkInterval, (_) => unawaited(checkNow()));
    } else if (!on && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  /// Stops the schedule.
  void dispose() {
    _disposed = true;
    _first?.cancel();
    _first = null;
    _timer?.cancel();
    _timer = null;
    _settings?.close();
    _settings = null;
    if (observeLifecycle) WidgetsBinding.instance.removeObserver(this);
  }

  /// The default toast: the root navigator's overlay, when it is there.
  static void _rootToast(String message, {required bool failed}) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    showDsToast(context: context, title: message, status: failed ? DsStatus.danger : DsStatus.success);
  }
}

/// One message per failure kind, the same words the WebDAV page uses.
String webDavAutoFailureText(Object error) => switch (error) {
  WebDavFailure(problem: WebDavProblem.auth) => t.backup.webdavAuthFailed,
  WebDavFailure(problem: WebDavProblem.notFound) => t.backup.webdavNotFound,
  WebDavFailure(:final status?) => t.backup.webdavServerFailed(status: status),
  WebDavFailure() => t.backup.webdavNetworkFailed,
  _ => t.backup.webdavFailed,
};

/// The process-wide scheduler, started by the primary window's root.
///
/// Reading the provider in a clone window builds a scheduler that never
/// starts: the primary is the one process that uploads.
final webdavAutoBackupSchedulerProvider = Provider<WebDavAutoBackupScheduler>((ref) {
  final scheduler = WebDavAutoBackupScheduler(ref, WebDavAutoBackupService(ref));
  ref.onDispose(scheduler.dispose);
  if (ref.read(isPrimaryWindowProvider)) scheduler.start();
  return scheduler;
});

/// The service alone, for the pane's "back up now" and its due reading.
final webdavAutoBackupServiceProvider = Provider<WebDavAutoBackupService>(WebDavAutoBackupService.new);
