import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/backup/cloud/cloud_models.dart';
import 'package:pure_live/features/backup/cloud/cloud_service.dart';
import 'package:pure_live/features/backup/cloud/legacy_backup_importer.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart' show backupRepositoryProvider;
import 'package:pure_live/features/version/app_version.dart';

/// The Firebase endpoint a network that can reach Google answers. Checked
/// the way the reference app checks it; a device behind a blocked network
/// fails here and the feature stays off.
const String _probeUrl = 'https://firebase.google.com/?hl=zh-cn';

/// A backup downloaded from the cloud, ready to be picked over.
final class CloudDownload {
  /// The download.
  const CloudDownload({required this.document, this.skippedLegacy = const []});

  /// The document, in this app's shape.
  final BackupDocument document;

  /// The legacy sections a legacy document could not carry over, named for
  /// the confirm.
  final List<String> skippedLegacy;

  /// Whether it came from the reference app's format.
  bool get legacy => skippedLegacy.isNotEmpty;
}

/// Where the cloud backup stands and how it acts. The lifecycle is a
/// ladder: probe the network, only then load Firebase, only then listen
/// for the account, only then read permissions and the cloud's document.
///
/// Every user action sets `busy` and clears on settle, naming its failure
/// by code for the pane to translate.
final class CloudController extends Notifier<CloudState> {
  final CloudService _service = const CloudService();
  StreamSubscription<CloudUser?>? _users;
  int _epoch = 0;

  Future<void>? _started;

  @override
  CloudState build() {
    ref.onDispose(() {
      unawaited(_users?.cancel());
      _users = null;
    });
    return const CloudState();
  }

  /// Starts the ladder the first time a surface needs the cloud; later
  /// calls answer the same run. Nothing probes the network until then, so
  /// a device that never opens the page never pays for it.
  Future<void> ensureStarted() => _started ??= start();

  /// Probes, initialises and listens. A retry after a failed probe starts
  /// the ladder over; a stale run's answers are dropped by epoch.
  Future<void> start() async {
    final epoch = ++_epoch;
    _started ??= Future.value();
    state = const CloudState();
    final reachable = await _reachable();
    if (epoch != _epoch) return;
    if (!reachable) {
      state = state.copyWith(phase: CloudPhase.unreachable);
      return;
    }
    try {
      await CloudService.initialize();
    } on Object {
      if (epoch == _epoch) state = state.copyWith(phase: CloudPhase.unreachable);
      return;
    }
    if (epoch != _epoch) return;
    await _users?.cancel();
    _users = _service.users.listen((user) => unawaited(_onUser(user, epoch)));
  }

  /// One HTTP GET against Firebase through the app's own transport, which
  /// honours the user's proxy settings; answered within ten seconds or
  /// treated as unreachable.
  Future<bool> _reachable() async {
    try {
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      await http.getText(Uri.parse(_probeUrl), timeout: const Duration(seconds: 10));
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _onUser(CloudUser? user, int epoch) async {
    if (epoch != _epoch) return;
    if (user == null) {
      state = state.copyWith(
        phase: CloudPhase.signedOut,
        clearUser: true,
        permissions: CloudPermissions.none,
        backup: CloudBackupInfo.empty,
      );
      return;
    }
    final permissions = await _service.loadPermissions(user.uid);
    if (epoch != _epoch) return;
    var backup = CloudBackupInfo.empty;
    try {
      backup = await _service.backupInfo(user.uid);
    } on Object {
      // The cloud's document stays unknown; the pane shows nothing stored.
    }
    if (epoch != _epoch) return;
    state = state.copyWith(phase: CloudPhase.signedIn, user: user, permissions: permissions, backup: backup);
  }

  // -- Auth -----------------------------------------------------------------

  Future<void> signInWithEmail({required String email, required String password}) => _run(() async {
    await _service.signInWithEmail(email: email, password: password);
  });

  Future<void> signUpWithEmail({required String email, required String password}) => _run(() async {
    await _service.signUpWithEmail(email: email, password: password);
  });

  Future<void> sendPasswordReset(String email) => _run(() => _service.sendPasswordReset(email));

  Future<void> signInWithGitHubProvider() => _run(_service.signInWithGitHubProvider);

  /// Signs in with the token a `purelive://auth` callback carried; the
  /// ladder is climbed first when the link arrives before the page opened.
  Future<void> signInWithGitHubToken(String token) => _run(() async {
    await ensureStarted();
    if (state.phase == CloudPhase.unreachable || state.phase == CloudPhase.probing) {
      throw const CloudFailure('network-request-failed');
    }
    await _service.signInWithGitHubToken(token);
  });

  Future<void> signOut() => _run(_service.signOut);

  // -- The document ---------------------------------------------------------

  /// Refreshes what the cloud holds (after an upload or a delete).
  Future<void> refreshBackupInfo() async {
    final user = state.user;
    if (user == null) return;
    final info = await _service.backupInfo(user.uid);
    if (ref.mounted) state = state.copyWith(backup: info);
  }

  /// Uploads what the user picked to the cloud, honouring the secrets
  /// switch, and refreshes the info.
  Future<void> upload(BackupDocument document) => _run(() async {
    final user = state.user;
    if (user == null) throw const CloudFailure('signed-out');
    if (!state.permissions.canUpload) throw const CloudFailure('upload-refused');
    final version = await readInstalledVersion();
    await _service.uploadConfig(
      uid: user.uid,
      email: user.email,
      json: document.encode(),
      appVersion: version.toString(),
    );
    await refreshBackupInfo();
  });

  /// Reads the cloud's document into this app's shape. A legacy document
  /// comes back imported, with its skipped sections named.
  Future<CloudDownload> download() async {
    final user = state.user;
    if (user == null) throw const CloudFailure('signed-out');
    final root = await _service.downloadConfig(user.uid);
    if (root == null) throw const CloudFailure('nothing-stored');
    if (LegacyBackupImporter.looksLegacy(root)) {
      final imported = LegacyBackupImporter.tryImport(root);
      if (imported == null) throw const CloudFailure('not-a-backup');
      return CloudDownload(document: imported.document, skippedLegacy: imported.skipped);
    }
    final document = BackupDocument.tryFromJson(root);
    if (document == null) throw const CloudFailure('not-a-backup');
    return CloudDownload(document: document);
  }

  /// Restores [document] into this app and refreshes the info — the same
  /// repository path a local or WebDAV restore takes.
  Future<void> restore(BackupDocument document) => _run(() async {
    final repository = await ref.read(backupRepositoryProvider.future);
    await repository.apply(document);
    if (document.hasSettings) refreshSettings(ref);
    await refreshBackupInfo();
  });

  /// Deletes the cloud's document (the account stays).
  Future<void> deleteCloudDocument() => _run(() async {
    final user = state.user;
    if (user == null) throw const CloudFailure('signed-out');
    await _service.deleteConfig(user.uid);
    await refreshBackupInfo();
  });

  Future<void> _run(Future<void> Function() work) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await work();
    } on CloudFailure catch (failure) {
      state = state.copyWith(busy: false, error: failure.code);
      return;
    } on Object catch (error) {
      state = state.copyWith(busy: false, error: 'unknown');
      appLog.forCategory('backup.cloud').warning('a cloud action failed', fields: {'error': '$error'});
      return;
    }
    state = state.copyWith(busy: false);
  }

  /// Clears the pane's error line once it has been seen.
  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

/// The cloud controller.
final cloudControllerProvider = NotifierProvider<CloudController, CloudState>(CloudController.new);
