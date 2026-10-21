import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// How a stored login reads on an account page: its colour and icon — the
/// reference's `AccountTone`.
enum AccountTone {
  /// Nothing stored.
  idle,

  /// Signed in, or stored and usable.
  ok,

  /// A check is running.
  busy,

  /// Stored, but something is missing.
  warning,

  /// Stored, but it signs in nobody.
  error,
}

/// What the page says about one platform's login — the reference's
/// `AccountStatus` over the workspace's [LiveCredential] (the credential the
/// auth capability granted; this build has no per-platform online account
/// check, so the status reads what the stored login itself names).
@immutable
final class AccountStatus {
  /// A status reading [text] in [tone].
  const new(this.text, {this.tone = AccountTone.idle, this.signedIn = false});

  /// The sentence shown.
  final String text;

  /// How it reads.
  final AccountTone tone;

  /// Whether the login counts as signed in (the sign-out button shows).
  final bool signedIn;
}

/// The status of a stored [credential] as the cookie editor's card says it.
AccountStatus accountStatusFor(Translations t, LiveCredential? credential, {DateTime? now}) {
  if (credential == null) {
    return AccountStatus(t.account.editorNoneHint);
  }
  final expiry = credential.expiry;
  if (expiry != null && expiry.isBefore(now ?? DateTime.now())) {
    return AccountStatus(t.account.statusExpired, tone: AccountTone.error, signedIn: true);
  }
  final name = credential.nickname?.trim() ?? '';
  if (name.isNotEmpty) {
    return AccountStatus(t.account.signedIn(name: name), tone: AccountTone.ok, signedIn: true);
  }
  final uid = credential.userId?.trim() ?? '';
  if (uid.isNotEmpty) {
    return AccountStatus(t.account.statusUid(uid: uid), tone: AccountTone.ok, signedIn: true);
  }
  return AccountStatus(t.account.saved, tone: AccountTone.ok, signedIn: true);
}

/// The uikit colour of a [tone].
Color accountToneColor(BuildContext context, AccountTone tone) {
  final colors = PureTheme.of(context).colors;
  return switch (tone) {
    AccountTone.ok => colors.success,
    AccountTone.busy => colors.primary,
    AccountTone.warning => colors.warning,
    AccountTone.error => colors.error,
    AccountTone.idle => colors.textSecondary,
  };
}

final RegExp _controlChars = RegExp(r'[\u0000-\u001f\u007f]+');
final RegExp _cookieHeaderPrefix = RegExp(r'^\s*cookie\s*:\s*', caseSensitive: false);
final RegExp _cookiePair = RegExp(r'(?:^|;)\s*[^\s=;]+\s*=');

/// A pasted cookie as stored: control characters folded to spaces, outer
/// blanks and a copied `Cookie:` header name removed (the reference's
/// `cleanPastedCookie`).
String cleanPastedCookie(String text) => text.replaceAll(_controlChars, ' ').trim().replaceFirst(_cookieHeaderPrefix, '').trim();

/// Whether [cookie] has at least one `name=value` field.
bool looksLikeCookie(String cookie) => _cookiePair.hasMatch(cookie);

/// The stored credential's cookies as one paste-ready header line.
String cookieHeaderOf(LiveCredential credential) =>
    credential.cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');

/// The card that opens an account page: the platform's state in one line,
/// coloured like the reference's `AccountStatusCard`.
class AccountStatusCard extends StatelessWidget {
  /// The card for [status].
  const new({required this.status, this.action, super.key});

  /// What to say.
  final AccountStatus status;

  /// An optional button on the card's right (the reference's 重新核验).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final color = accountToneColor(context, status.tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(_iconOf(status.tone), size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status.text.isEmpty ? context.t.account.saved : status.text,
              style: theme.text.body,
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  static IconData _iconOf(AccountTone tone) => switch (tone) {
    AccountTone.ok => Icons.verified_outlined,
    AccountTone.busy => Icons.autorenew,
    AccountTone.warning => Icons.warning_amber_rounded,
    AccountTone.error => Icons.error_outline,
    AccountTone.idle => Icons.info_outline,
  };
}
