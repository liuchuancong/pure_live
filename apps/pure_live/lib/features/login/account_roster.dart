import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential;
import 'package:live_storage/live_storage.dart' show SecretRefs, SecretStore;
import 'package:pure_live/features/login/login_providers.dart';
import 'package:pure_live/features/login/secure_vault.dart';
import 'package:pure_live/features/room/room_providers.dart' show danmakuSessionProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// One remembered sign-in (docs/K01.2, the reference's `SavedAccount`): the
/// account's id and name, the credential that switches back to it, and when
/// it was last used — the order the group shows and the eviction reads.
final class SavedAccount {
  /// A remembered sign-in.
  const new({required this.uid, required this.name, required this.credential, required this.usedAt});

  /// The platform account id the document is filed under.
  final int uid;

  /// The account's display name ('' when the platform gave none).
  final String name;

  /// The full credential — what [AccountController.adopt] applies back.
  final LiveCredential credential;

  /// The last login or switch; newest first in the list.
  final DateTime usedAt;

  /// The name a row shows: its account name, or UID n when none is known.
  String label(Translations t) => name.isEmpty ? t.account.accountUid(uid: '$uid') : name;
}

/// The remembered sign-ins of the platforms, over the secret vault's
/// `account/<site>/<uid>` refs (the reference's `AccountRoster`, trimmed to
/// what this build stores: the credential document itself is the entry).
///
/// [limit] is the reference's 5: remembering one more forgets the least
/// recently used of the others.
final class AccountRoster {
  /// The roster over the secret store; `now` stamps the entries.
  new(this._store, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final SecretStore _store;
  final DateTime Function() _now;

  /// How many sign-ins one platform keeps (V01.2 S3).
  static const int limit = 5;

  /// The remembered sign-ins of [site], most recently used first.
  List<SavedAccount> of(String site) {
    final prefix = 'account/${site.trim().toLowerCase()}/';
    final found = <SavedAccount>[];
    for (final ref in _store.refs) {
      if (!ref.startsWith(prefix)) {
        continue;
      }
      final uid = int.tryParse(ref.substring(prefix.length));
      final raw = _store.value(ref);
      if (uid == null || raw == null) {
        continue;
      }
      final entry = _decode(raw, uid);
      if (entry != null) {
        found.add(entry);
      }
    }
    return found..sort((a, b) {
      final used = b.usedAt.compareTo(a.usedAt);
      return used != 0 ? used : a.uid.compareTo(b.uid);
    });
  }

  /// Remembers [credential]'s account as the newest sign-in of its site.
  /// A credential without a numeric uid names no roster entry and is left
  /// out — the roster switches by uid, and an account it cannot name it
  /// cannot show. Beyond [limit] the least recently used go, the entry just
  /// written never among them.
  Future<void> remember(LiveCredential credential) async {
    final uid = int.tryParse(credential.userId?.trim() ?? '');
    if (uid == null || uid <= 0) {
      return;
    }
    final site = credential.siteId;
    await _store.set(SecretRefs.account(site, uid), jsonEncode(_documentOf(credential, _now())));
    final stale = of(site)..sort((a, b) => a.usedAt.compareTo(b.usedAt));
    var over = stale.length - limit;
    for (final entry in stale) {
      if (over <= 0) {
        break;
      }
      if (entry.uid == uid) {
        continue;
      }
      await _store.remove(SecretRefs.account(site, entry.uid));
      over--;
    }
  }

  /// Takes the sign-in of [uid] off the device; the current login is
  /// untouched (that one leaves with the page's 退出登录).
  Future<void> forget(String site, int uid) => _store.remove(SecretRefs.account(site, uid));

  Map<String, Object?> _documentOf(LiveCredential credential, DateTime usedAt) => <String, Object?>{
    'siteId': credential.siteId,
    'cookies': credential.cookies,
    'userId': credential.userId,
    'nickname': credential.nickname,
    'avatar': credential.avatar,
    if (credential.expiry != null) 'expiry': credential.expiry!.toIso8601String(),
    'usedAt': usedAt.millisecondsSinceEpoch,
  };

  SavedAccount? _decode(String raw, int uid) {
    if (raw.isEmpty) {
      return null;
    }
    try {
      final document = jsonDecode(raw);
      if (document is! Map) {
        return null;
      }
      final cookies = document['cookies'];
      final siteId = document['siteId'];
      if (cookies is! Map || siteId is! String || cookies.isEmpty) {
        return null;
      }
      final expiry = document['expiry'];
      final stamp = document['usedAt'];
      return SavedAccount(
        uid: uid,
        name: document['nickname'] is String ? document['nickname']! as String : '',
        credential: LiveCredential(
          siteId: siteId,
          cookies: <String, String>{for (final entry in cookies.entries) '${entry.key}': '${entry.value}'},
          userId: document['userId'] is String ? document['userId']! as String : null,
          nickname: document['nickname'] is String ? document['nickname']! as String : null,
          avatar: document['avatar'] is String ? document['avatar']! as String : null,
          expiry: expiry is String ? DateTime.tryParse(expiry) : null,
        ),
        usedAt: stamp is int ? DateTime.fromMillisecondsSinceEpoch(stamp) : DateTime.fromMillisecondsSinceEpoch(0),
      );
    } on Object {
      return null;
    }
  }
}

/// The process's roster, over its own vault handle (the same device store
/// the login repository writes; every ref the roster reads it also owns).
/// A vault this process cannot open leaves the provider in error state and
/// the group renders nothing — switching through a roster that cannot be
/// written would promise a login that never lands.
final accountRosterProvider = FutureProvider<AccountRoster>(
  (ref) => SecretStore.load(vault: SecureVault()).then(AccountRoster.new),
);

/// The remembered sign-ins of the current site, refreshed when the roster's
/// own writes land (the store's change stream is per-instance, so the group
/// re-reads after its actions and a login that just landed).
// The family provider type cannot be spelled for the annotation: riverpod
// does not export it.
// ignore_for_file: specify_nonobvious_property_types
final rememberedAccountsProvider =
    NotifierProvider.autoDispose.family<RememberedAccountsController, List<SavedAccount>, String>(
      RememberedAccountsController.new,
    );

/// The remembered sign-ins of one site, as the group reads and acts on them.
final class RememberedAccountsController extends Notifier<List<SavedAccount>> {
  /// The roster of this site.
  new(this.siteId);

  /// The platform whose roster this controller serves.
  final String siteId;

  bool _disposed = false;

  @override
  List<SavedAccount> build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    try {
      final roster = await ref.read(accountRosterProvider.future);
      if (!_disposed) {
        state = roster.of(siteId);
      }
    } on Object {
      // A vault this process cannot open leaves the list empty; the group
      // then shows only what adding a login would do.
    }
  }

  /// Switches to [account]: the credential is adopted (apply, store,
  /// publish in one move) and the room's danmaku reconnect with it — the
  /// reference's promise that the switch bites the picture, not the next run.
  Future<void> switchTo(SavedAccount account) async {
    await ref.read(accountProvider(siteId).notifier).adopt(account.credential);
    try {
      final roster = await ref.read(accountRosterProvider.future);
      await roster.remember(account.credential);
    } on Object {
      // The switch itself landed; only the used-at stamp did not.
    }
    ref.invalidate(danmakuSessionProvider);
    if (!_disposed) {
      await _load();
    }
  }

  /// Takes [account] off the device (the group asks first).
  Future<void> forget(SavedAccount account) async {
    final roster = await ref.read(accountRosterProvider.future);
    await roster.forget(siteId, account.uid);
    if (!_disposed) {
      await _load();
    }
  }
}

/// The "已记住的账号" group (the reference's `BilibiliAccountsGroup`, one
/// widget per site): every remembered sign-in with its name and uid, the
/// current one marked, the others with 切换 and 删除; the add row says that
/// signing another account in leaves this list.
final class RememberedAccountsGroup extends ConsumerWidget {
  /// The group of [siteId]'s remembered sign-ins.
  const new({required this.siteId, super.key});

  /// The platform whose roster is shown.
  final String siteId;

  Future<void> _confirmSwitch(BuildContext context, WidgetRef ref, SavedAccount account) async {
    final t = context.t;
    final go = await showPureDialog<bool>(
      context: context,
      title: t.account.accountSwitch,
      child: Text(t.account.accountSwitchConfirm(name: account.label(t))),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: dialogContext.t.account.accountSwitch,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (!(go ?? false) || !context.mounted) {
      return;
    }
    await ref.read(rememberedAccountsProvider(siteId).notifier).switchTo(account);
    if (context.mounted) {
      PureToast.show(
        context,
        context.t.account.accountSwitched(name: account.label(context.t)),
        type: PureToastType.success,
      );
    }
  }

  Future<void> _confirmForget(BuildContext context, WidgetRef ref, SavedAccount account) async {
    final t = context.t;
    final go = await showPureDialog<bool>(
      context: context,
      title: t.account.accountForget,
      child: Text(t.account.accountForgetConfirm(name: account.label(t))),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: dialogContext.t.account.accountForget,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (!(go ?? false) || !context.mounted) {
      return;
    }
    await ref.read(rememberedAccountsProvider(siteId).notifier).forget(account);
    if (context.mounted) {
      PureToast.show(context, context.t.account.accountForgot(name: account.label(context.t)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final accounts = ref.watch(rememberedAccountsProvider(siteId));
    final current = ref.watch(accountProvider(siteId));
    final currentUid = int.tryParse(current?.userId?.trim() ?? '');
    return Column(
      key: ValueKey('account-roster-$siteId'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final account in accounts)
          PureListRow(
            key: ValueKey('account-roster-${account.uid}'),
            leading: PureAvatar(name: account.name.isEmpty ? null : account.name, size: 36),
            title: account.label(t),
            subtitle: account.uid == currentUid
                ? '${t.account.accountUid(uid: '${account.uid}')} · ${t.account.accountCurrent}'
                : t.account.accountUid(uid: '${account.uid}'),
            selected: account.uid == currentUid,
            trailing: account.uid == currentUid
                ? null
                : PureIconButton(
                    key: ValueKey('account-roster-forget-${account.uid}'),
                    icon: Icons.delete_outline,
                    tooltip: t.account.accountForget,
                    onPressed: () => unawaited(_confirmForget(context, ref, account)),
                  ),
            onTap: account.uid == currentUid ? null : () => unawaited(_confirmSwitch(context, ref, account)),
          ),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Text(t.account.accountAddHint, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: Text(
            accounts.length >= AccountRoster.limit
                ? t.account.accountAddFull(count: '${AccountRoster.limit}')
                : t.account.savedAccountsNote(count: '${AccountRoster.limit}'),
            style: theme.text.caption.copyWith(color: theme.colors.textTertiary),
          ),
        ),
      ],
    );
  }
}
