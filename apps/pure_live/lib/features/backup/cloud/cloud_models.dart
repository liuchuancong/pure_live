/// The cloud backup's own types: where the feature stands, who is signed
/// in, what they may do, and what the cloud holds for them.
library;

/// Where the cloud backup stands. The phases are a ladder: the probe comes
/// first, and only a reachable Firebase is ever initialised.
enum CloudPhase {
  /// Checking whether Firebase can be reached from this network.
  probing,

  /// It cannot: the feature stays off until a retry succeeds. The local,
  /// WebDAV and LAN transports are untouched.
  unreachable,

  /// Reachable, nobody signed in.
  signedOut,

  /// Reachable, signed in.
  signedIn,
}

/// The signed-in account, as the pane shows it.
final class CloudUser {
  /// The account.
  const CloudUser({required this.uid, required this.email, this.displayName, this.providerIds = const {}});

  /// Firebase's user id.
  final String uid;

  /// The account's email ('' when the provider gave none).
  final String email;

  /// A display name, when the provider set one.
  final String? displayName;

  /// The providers linked to the account ('password', 'github.com').
  final Set<String> providerIds;

  /// Whether the account came in through GitHub.
  bool get viaGitHub => providerIds.contains('github.com');
}

/// What the account may do, from the `users`, `permissions` and `roles`
/// collections — the reference app's permission model, read as-is.
final class CloudPermissions {
  /// The permissions.
  const CloudPermissions({
    required this.canUpload,
    this.role,
    this.roleWeights = const {'user': 2},
    this.roleVisibility = const {},
    this.managementRoles = const {},
  });

  /// Nothing known yet: uploads refused, no role.
  static const CloudPermissions none = CloudPermissions(canUpload: false);

  /// Whether `users/{uid}.canUpload` is not false (absent means allowed).
  final bool canUpload;

  /// `permissions/{uid}.role`, when the account has one.
  final String? role;

  /// `roles/{id}.weight`: 0 admin, 1 manager, 2 user.
  final Map<String, int> roleWeights;

  /// `roles/{id}.canSeeRoles`: which roles each role may list.
  final Map<String, List<String>> roleVisibility;

  /// The roles flagged `isManagement`.
  final Set<String> managementRoles;

  /// The weight of this account's role; a role nobody defined reads as a
  /// plain user.
  int get weight => roleWeights[role ?? 'user'] ?? 2;

  /// Whether the account is an admin (weight 0).
  bool get isAdmin => weight == 0;

  /// Whether the account may manage other accounts (weight below user).
  bool get hasManagementPower => weight < 2;

  /// The roles this account may see in the admin list.
  List<String> get visibleRoles {
    final listed = roleVisibility[role ?? 'user'];
    if (listed != null && listed.isNotEmpty) return listed;
    return switch (weight) {
      0 => const ['admin', 'manager', 'user'],
      1 => const ['manager', 'user'],
      _ => const ['user'],
    };
  }
}

/// What the cloud holds for the account: whether a document exists, when
/// it was last written and by which app version.
final class CloudBackupInfo {
  /// The info.
  const CloudBackupInfo({required this.exists, this.updatedAt, this.appVersion, this.legacy = false});

  /// Nothing uploaded yet.
  static const CloudBackupInfo empty = CloudBackupInfo(exists: false);

  /// Whether `users/{uid}.config` holds a document.
  final bool exists;

  /// `update_at` as the writer formatted it (`yyyy-MM-dd HH:mm:ss`).
  final String? updatedAt;

  /// `version` as the writer wrote it.
  final String? appVersion;

  /// Whether the document is the reference app's format (imported on
  /// download, with the sections it cannot carry reported).
  final bool legacy;
}

/// One account in the admin list.
final class CloudUserItem {
  /// The row.
  const CloudUserItem({required this.uid, required this.email, required this.canUpload, required this.role});

  /// Firebase's user id.
  final String uid;

  /// The account's email.
  final String email;

  /// Whether the account may upload.
  final bool canUpload;

  /// Its role ('user' when none is set).
  final String role;
}

/// The whole feature's state, as the pane reads it.
final class CloudState {
  /// The state.
  const CloudState({
    this.phase = CloudPhase.probing,
    this.user,
    this.permissions = CloudPermissions.none,
    this.backup = CloudBackupInfo.empty,
    this.busy = false,
    this.error,
  });

  /// Where the feature stands.
  final CloudPhase phase;

  /// The signed-in account, while [phase] is [CloudPhase.signedIn].
  final CloudUser? user;

  /// What the account may do.
  final CloudPermissions permissions;

  /// What the cloud holds for the account.
  final CloudBackupInfo backup;

  /// Whether an action is running; the pane greys its rows out.
  final bool busy;

  /// The last failure's code, for the pane to name; null when none.
  final String? error;

  /// A copy with some fields changed; `clearError` drops the error.
  CloudState copyWith({
    CloudPhase? phase,
    CloudUser? user,
    bool clearUser = false,
    CloudPermissions? permissions,
    CloudBackupInfo? backup,
    bool? busy,
    String? error,
    bool clearError = false,
  }) => CloudState(
    phase: phase ?? this.phase,
    user: clearUser ? null : (user ?? this.user),
    permissions: permissions ?? this.permissions,
    backup: backup ?? this.backup,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
  );
}

/// A failure the cloud reports by code, so the pane can name it in the
/// user's language. [code] is Firebase's (`wrong-password`,
/// `network-request-failed`…) or this feature's own (`upload-refused`,
/// `not-a-backup`, `callback-invalid`).
final class CloudFailure implements Exception {
  /// The failure.
  const CloudFailure(this.code, [this.message]);

  /// The code.
  final String code;

  /// The provider's message, for the log.
  final String? message;

  @override
  String toString() => 'CloudFailure($code${message == null ? '' : ': $message'})';
}
