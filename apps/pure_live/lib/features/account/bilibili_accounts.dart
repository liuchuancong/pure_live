import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential;
import 'package:pure_live/features/account/account_providers.dart';
import 'package:pure_live/features/account/account_repository.dart' show AccountRepository, BilibiliAccount;
import 'package:pure_live/features/account/account_state.dart' show accountCookieLine;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart' show cachedImage;

/// The sign-ins bilibili remembers on this device (the reference's
/// `BilibiliAccountsGroup`, docs/K-账号和登录/K01.2): what the vault holds, how
/// one is recognised as the current login, and the list the cookie page shows.
///
/// The current login itself stays the single `credentials/bilibili` document —
/// the roster beside it only makes switching back to a remembered account need
/// no new scan.

/// The remembered bilibili sign-ins, most recently used first; empty while the
/// secret store is still opening.
final bilibiliAccountsProvider = Provider<List<BilibiliAccount>>((ref) {
  // Every roster write lands under the vault's `credentials/` prefix, so the
  // accounts state moves with it: a sign-in, a switch, a deletion or a
  // sign-out re-reads the list through this watch.
  ref.watch(accountsProvider);
  return ref.read(accountsProvider.notifier).bilibiliAccounts();
});

/// Whether [account] is the login [credential] currently stored: the same
/// cookie, or the uid that cookie was just checked as.
bool isCurrentBilibiliAccount(BilibiliAccount account, LiveCredential? credential) {
  final cookie = accountCookieLine(credential);
  if (cookie.isEmpty) return false;
  if (account.cookie == cookie) return true;
  final uid = int.tryParse(credential?.userId ?? '');
  return uid != null && uid > 0 && account.uid == uid;
}

/// The name a remembered sign-in is listed under: its account name, or its uid
/// when the platform gave no name.
String bilibiliAccountLabel(BilibiliAccount account, Translations t) =>
    account.name.isEmpty ? t.account.accountUid(uid: '${account.uid}') : account.name;

/// How many sign-ins the roster holds, and the wording that says so.
int get bilibiliAccountLimit => AccountRepository.bilibiliAccountLimit;

/// The "已记住的账号" group of bilibili's cookie page: every remembered
/// sign-in with its picture, name and uid, the current one marked and without
/// buttons of its own (it is left with the page's "退出登录"), the others with
/// 切换 and 删除; the last row signs another account in.
final class BilibiliAccountsGroup extends StatelessWidget {
  /// Creates the group.
  const BilibiliAccountsGroup({
    required this.accounts,
    required this.isCurrent,
    required this.onSwitch,
    required this.onForget,
    required this.onAdd,
    this.busy = false,
    super.key,
  });

  /// The remembered sign-ins, most recently used first.
  final List<BilibiliAccount> accounts;

  /// Whether a sign-in is the current one.
  final bool Function(BilibiliAccount account) isCurrent;

  /// Switches to a sign-in (the page asks first).
  final ValueSetter<BilibiliAccount> onSwitch;

  /// Forgets a sign-in (the page asks first).
  final ValueSetter<BilibiliAccount> onForget;

  /// Signs another account in with the QR code.
  final VoidCallback onAdd;

  /// A switch or a deletion is running: the buttons wait.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final full = accounts.length >= bilibiliAccountLimit;
    return Column(
      key: const ValueKey('bilibili-accounts'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        DsListSection(
          header: Text(t.account.savedAccounts),
          children: [
            for (final account in accounts) _row(context, account, current: isCurrent(account)),
            _addRow(context, full: full),
          ],
        ),
        Text(
          t.account.savedAccountsNote(count: '$bilibiliAccountLimit'),
          style: theme.typography.caption.copyWith(color: colors.textMuted, height: 1.5),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, BilibiliAccount account, {required bool current}) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final name = bilibiliAccountLabel(account, t);
    final uid = t.account.accountUid(uid: '${account.uid}');
    final key = 'bilibili-account-${account.uid}';
    final avatar = account.avatar;
    return DsListRow(
      key: ValueKey(key),
      leading: avatar == null || avatar.isEmpty
          ? const DsIcon(DsIcons.userRound)
          : DsAvatar(image: cachedImage(avatar), initials: name, semanticLabel: name),
      title: Text(name),
      description: Text(current ? '$uid · ${t.account.accountCurrent}' : uid),
      trailing: current
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s4,
              children: [
                DsButton(
                  key: ValueKey('$key-switch'),
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: busy ? null : () => onSwitch(account),
                  child: Text(t.account.switchAccount),
                ),
                DsButton.icon(
                  key: ValueKey('$key-forget'),
                  size: DsSize.sm,
                  semanticLabel: t.account.forgetAccount,
                  onPressed: busy ? null : () => onForget(account),
                  icon: DsIcon(DsIcons.trash, color: colors.danger.text),
                ),
              ],
            ),
      onPressed: current || busy ? null : () => onSwitch(account),
    );
  }

  Widget _addRow(BuildContext context, {required bool full}) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    return DsListRow(
      key: const ValueKey('bilibili-account-add'),
      leading: DsIcon(DsIcons.userPlus, color: colors.textSubtle),
      title: Text(t.account.addAccount),
      description: Text(
        full ? t.account.addAccountFull(count: '$bilibiliAccountLimit') : t.account.addAccountHint,
        style: TextStyle(color: colors.textMuted, height: 1.45),
      ),
      onPressed: busy ? null : onAdd,
    );
  }
}
