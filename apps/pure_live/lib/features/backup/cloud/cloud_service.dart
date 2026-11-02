import 'dart:convert' show jsonDecode;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pure_live/features/backup/cloud/cloud_models.dart';
import 'package:pure_live/features/backup/cloud/firebase_options.dart';

/// The one place Firebase is spoken to: initialisation, the auth calls, and
/// the Firestore documents the reference app laid out — `users/{uid}`
/// (the backup document, email, version, timestamps, the upload switch),
/// `permissions/{uid}` (the role) and `roles/{id}` (what a role may do).
///
/// Nothing here touches Firebase before [initialize]; the controller only
/// calls it after the reachability probe passed, so a device that cannot
/// reach Google never loads the SDK's network stack at all.
final class CloudService {
  /// The service.
  const CloudService();

  /// The GitHub provider, asking for the email scope the account needs.
  static GithubAuthProvider get _github => GithubAuthProvider()..addScope('user:email');

  /// The page that runs the GitHub OAuth dance for a desktop and hands the
  /// token back over the custom scheme.
  static const String middlePageUrl = 'https://pure-live-26c7f.web.app/auth_callback.html';

  /// The custom scheme the middle page redirects to.
  static const String callbackScheme = 'purelive';

  /// The URL a desktop opens to sign in with GitHub.
  static Uri gitHubDesktopUrl({required String platform}) =>
      Uri.parse('$middlePageUrl?platform=$platform&scheme=$callbackScheme');

  /// Initialises the default app once; later calls are no-ops.
  static Future<void> initialize() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // -- Auth -----------------------------------------------------------------

  /// The account as it signs in and out.
  Stream<CloudUser?> get users => _auth.authStateChanges().map(_userOf);

  /// The account right now.
  CloudUser? get currentUser => _userOf(_auth.currentUser);

  static CloudUser? _userOf(User? user) => user == null
      ? null
      : CloudUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          providerIds: {for (final info in user.providerData) info.providerId},
        );

  /// Signs in with an email and password.
  Future<CloudUser> signInWithEmail({required String email, required String password}) => _guard(() async {
    final result = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return _userOf(result.user)!;
  });

  /// Creates the account, then its `users/{uid}` profile (email and the
  /// creation stamp), as the reference app did.
  Future<CloudUser> signUpWithEmail({required String email, required String password}) => _guard(() async {
    final result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = result.user!;
    await _db.collection('users').doc(user.uid).set({
      'email': email.trim(),
      'created_at': FieldValue.serverTimestamp(),
    });
    return _userOf(user)!;
  });

  /// Sends the password reset mail.
  Future<void> sendPasswordReset(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  /// Signs in with GitHub through the platform's own browser session
  /// (Android, iOS, macOS).
  Future<CloudUser> signInWithGitHubProvider() => _guard(() async {
    final result = await _auth.signInWithProvider(_github);
    return _userOf(result.user)!;
  });

  /// Signs in with a GitHub access token the middle page handed back.
  Future<CloudUser> signInWithGitHubToken(String accessToken) => _guard(() async {
    final result = await _auth.signInWithCredential(GithubAuthProvider.credential(accessToken));
    return _userOf(result.user)!;
  });

  /// Signs out.
  Future<void> signOut() => _guard(_auth.signOut);

  // -- Permissions ----------------------------------------------------------

  /// What [uid] may do, from the three collections. A read that fails
  /// answers [CloudPermissions.none]: uploads stay refused until it works.
  Future<CloudPermissions> loadPermissions(String uid) async {
    try {
      final user = await _db.collection('users').doc(uid).get();
      final permission = await _db.collection('permissions').doc(uid).get();
      final roles = await _db.collection('roles').get();
      final weights = <String, int>{};
      final visibility = <String, List<String>>{};
      final management = <String>{};
      for (final doc in roles.docs) {
        final data = doc.data();
        weights[doc.id] = switch (data['weight']) {
          final num value => value.toInt(),
          _ => 2,
        };
        visibility[doc.id] = _strings(data['canSeeRoles']);
        if (data['isManagement'] == true) management.add(doc.id);
      }
      weights['user'] = 2;
      return CloudPermissions(
        canUpload: !user.exists || user.data()?['canUpload'] != false,
        role: permission.exists ? (permission.data()?['role'] as String?) : null,
        roleWeights: weights,
        roleVisibility: visibility,
        managementRoles: management,
      );
    } on Object {
      return CloudPermissions.none;
    }
  }

  // -- The backup document --------------------------------------------------

  /// What the cloud holds for [uid].
  Future<CloudBackupInfo> backupInfo(String uid) async {
    final doc = await _guard(() => _db.collection('users').doc(uid).get());
    final data = doc.data();
    final config = data?['config'];
    if (config == null || (config is String && config.trim().isEmpty)) return CloudBackupInfo.empty;
    final decoded = _decodeConfig(config);
    return CloudBackupInfo(
      exists: true,
      updatedAt: data?['update_at'] as String?,
      appVersion: data?['version'] as String?,
      legacy: decoded is Map && !(decoded.containsKey('version') && decoded['version'] is Map),
    );
  }

  /// Writes [json] as `users/{uid}.config`, with the email, the app
  /// version and the stamps the reference app wrote beside it, merging
  /// into whatever the document already holds.
  Future<void> uploadConfig({
    required String uid,
    required String email,
    required String json,
    required String appVersion,
  }) => _guard(() async {
    final reference = _db.collection('users').doc(uid);
    await _db.runTransaction((transaction) async {
      final existing = (await transaction.get(reference)).data();
      final payload = <String, Object?>{
        'config': json,
        'email': email,
        'version': appVersion,
        'update_at': _stamp(DateTime.now()),
      };
      if (existing == null || !existing.containsKey('created_at')) {
        payload['created_at'] = existing?['createdAt'] ?? FieldValue.serverTimestamp();
      }
      transaction.set(reference, payload, SetOptions(merge: true));
    });
  });

  /// Reads `users/{uid}.config` as decoded JSON; null when nothing is
  /// stored. Throws [CloudFailure] `not-a-backup` when it is not an object.
  Future<Map<String, Object?>?> downloadConfig(String uid) => _guard(() async {
    final doc = await _db.collection('users').doc(uid).get();
    final config = doc.data()?['config'];
    if (config == null || (config is String && config.trim().isEmpty)) return null;
    final decoded = _decodeConfig(config);
    if (decoded is! Map) throw const CloudFailure('not-a-backup');
    return Map<String, Object?>.from(decoded);
  });

  /// Removes the document from `users/{uid}` (the profile stays).
  Future<void> deleteConfig(String uid) => _guard(
    () => _db.collection('users').doc(uid).set({
      'config': FieldValue.delete(),
      'update_at': FieldValue.delete(),
      'version': FieldValue.delete(),
    }, SetOptions(merge: true)),
  );

  static List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String) item,
    ];
  }

  static Object? _decodeConfig(Object? config) {
    if (config is String) {
      try {
        return jsonDecode(config);
      } on Object {
        return null;
      }
    }
    return config;
  }

  static String _stamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  // -- Admin ----------------------------------------------------------------

  /// One page of accounts ordered by email, optionally those whose email
  /// starts with [keyword], the signed-in [selfUid] left out, each with its
  /// role and upload switch. [after] continues from the previous page's
  /// last document.
  Future<({List<CloudUserItem> items, DocumentSnapshot<Map<String, Object?>>? last})> listUsers({
    required String selfUid,
    required List<String> visibleRoles,
    String keyword = '',
    int pageSize = 30,
    DocumentSnapshot<Map<String, Object?>>? after,
  }) => _guard(() async {
    Query<Map<String, Object?>> query = _db.collection('users').orderBy('email');
    final start = keyword.trim().toLowerCase();
    if (start.isNotEmpty) {
      final end = start.substring(0, start.length - 1) + String.fromCharCode(start.codeUnitAt(start.length - 1) + 1);
      query = query.where('email', isGreaterThanOrEqualTo: start).where('email', isLessThan: end);
    }
    if (after != null) query = query.startAfterDocument(after);
    final page = await query.limit(pageSize).get();
    final docs = page.docs.where((doc) => doc.id != selfUid).toList();
    final permissions = <String, Map<String, Object?>?>{};
    for (var i = 0; i < docs.length; i += 30) {
      final slice = docs.sublist(i, i + 30 > docs.length ? docs.length : i + 30);
      final found = await _db
          .collection('permissions')
          .where(FieldPath.documentId, whereIn: [for (final doc in slice) doc.id])
          .get();
      for (final doc in found.docs) {
        permissions[doc.id] = doc.data();
      }
    }
    final items = <CloudUserItem>[];
    for (final doc in docs) {
      final data = doc.data();
      final permission = permissions[doc.id];
      final role = switch (permission?['role']) {
        final String value when value.trim().isNotEmpty => value.trim(),
        _ => 'user',
      };
      if (!visibleRoles.contains(role)) continue;
      items.add(
        CloudUserItem(
          uid: doc.id,
          email: data['email'] as String? ?? '',
          canUpload: permission?['canUpload'] != null ? permission!['canUpload'] != false : data['canUpload'] != false,
          role: role,
        ),
      );
    }
    return (items: items, last: page.docs.isEmpty ? null : page.docs.last);
  });

  /// Allows or refuses uploads for [uid] (`users/{uid}.canUpload`).
  Future<void> setUploadAllowed(String uid, {required bool allowed}) =>
      _guard(() => _db.collection('users').doc(uid).set({'canUpload': allowed}, SetOptions(merge: true)));

  /// Makes [uid] a manager.
  Future<void> promote(String uid, {required String email}) =>
      _guard(() => _db.collection('permissions').doc(uid).set({'canUpload': true, 'role': 'manager', 'email': email}));

  /// Drops [uid]'s role record (back to a plain user).
  Future<void> demote(String uid) => _guard(() => _db.collection('permissions').doc(uid).delete());

  /// Deletes [uid]'s profile and role record.
  Future<void> deleteUser(String uid) => _guard(() async {
    await _db.collection('permissions').doc(uid).delete();
    await _db.collection('users').doc(uid).delete();
  });

  /// Maps the SDK's exceptions to [CloudFailure] codes the pane can name.
  static Future<T> _guard<T>(Future<T> Function() work) async {
    try {
      return await work();
    } on CloudFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw CloudFailure(error.code, error.message);
    } on FirebaseException catch (error) {
      throw CloudFailure(error.code, error.message);
    }
  }
}
