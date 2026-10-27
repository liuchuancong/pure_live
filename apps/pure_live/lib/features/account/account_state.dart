import 'package:flutter/foundation.dart' show immutable;
import 'package:live_sites/live_sites.dart'
    show DouyuAccount, DouyuSessionState, LiveCredential, LiveSiteAuthenticationError, twitchChatLogin;
import 'package:pure_live/features/account/account_platforms.dart';
import 'package:pure_live/l10n/translations.dart';

/// How a status reads: its colour and weight.
enum AccountTone {
  /// Nothing is stored.
  idle,

  /// Signed in, or stored and usable.
  ok,

  /// A check is running.
  busy,

  /// Stored, but something is missing or could not be checked.
  warning,

  /// Stored, but it signs in nobody.
  error,
}

/// What the page says about one platform's login.
@immutable
final class AccountStatus {
  /// Creates the status sentence.
  const AccountStatus(this.text, {this.tone = AccountTone.idle, this.signedIn = false});

  /// The sentence shown under the platform's name.
  final String text;

  /// How it reads.
  final AccountTone tone;

  /// Whether the login counts as signed in; the row offers the sign-out.
  final bool signedIn;

  @override
  bool operator ==(Object other) =>
      other is AccountStatus && other.text == text && other.tone == tone && other.signedIn == signedIn;

  @override
  int get hashCode => Object.hash(text, tone, signedIn);

  @override
  String toString() => 'AccountStatus($text, ${tone.name}, signedIn: $signedIn)';
}

/// What the last online check of a credential answered.
sealed class AccountCheck {
  const AccountCheck();
}

/// The question is still out.
final class AccountChecking extends AccountCheck {
  /// Creates the state.
  const AccountChecking();
}

/// The credential signs in [name].
final class AccountVerified extends AccountCheck {
  /// Creates the result.
  const AccountVerified(this.name);

  /// The account's display name, as the platform spelled it.
  final String name;
}

/// The platform said the credential signs in nobody.
final class AccountRejected extends AccountCheck {
  /// Creates the result.
  const AccountRejected();
}

/// The question itself failed (a breakdown, a changed answer); the credential
/// stays stored and unjudged.
final class AccountCheckFailed extends AccountCheck {
  /// Creates the result.
  const AccountCheckFailed();
}

/// What a check that ended with [error] means: only the platform itself
/// condemning the login (`LiveSiteError.authentication`) counts as a rejected
/// credential; a breakdown on the way there leaves it stored and unjudged.
AccountCheck accountCheckFailure(Object error) =>
    error is LiveSiteAuthenticationError ? const AccountRejected() : const AccountCheckFailed();

/// What one platform has stored, as far as the page can see.
@immutable
final class AccountSnapshot {
  /// Creates the snapshot.
  const AccountSnapshot({
    this.credential,
    this.unreadable = false,
    this.douyuLtp0,
    this.douyuDid,
    this.douyuSavedAt,
  });

  /// The stored credential; null when the platform has none on this device.
  final LiveCredential? credential;

  /// Something is stored under the platform's key but it cannot be read back
  /// (the vault's answer was not a credential this app can open).
  final bool unreadable;

  /// Douyu's renewal key (LTP0) kept beside the cookie; null when none.
  final String? douyuLtp0;

  /// Douyu's login device id kept beside the cookie; null when none.
  final String? douyuDid;

  /// When douyu's cookie was saved or last renewed; null when unset. It turns
  /// an opaque `dy_auth` (no `exp` of its own) into a seven-day end.
  final DateTime? douyuSavedAt;

  /// The stored cookies as the `name=value; …` header line a request carries;
  /// empty when nothing is stored. The page keys its checks on this value, so
  /// one cookie is never asked twice.
  String get cookie => accountCookieLine(credential);
}

/// The cookie header line [credential] carries; empty when there is none.
String accountCookieLine(LiveCredential? credential) {
  final cookies = credential?.cookies;
  if (cookies == null || cookies.isEmpty) return '';
  return cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
}

/// The status of [platform] from what is stored and, for the platforms judged
/// online, the last [check].
AccountStatus accountStatus(
  AccountPlatform platform,
  AccountSnapshot stored, {
  required Translations t,
  required DateTime now,
  AccountCheck? check,
}) {
  if (stored.cookie.isEmpty) {
    // A credential the vault cannot open is still something stored: the row
    // offers the sign-out so the viewer can drop it and paste again.
    if (stored.unreadable) return AccountStatus(t.account.statusUnreadable, tone: AccountTone.error, signedIn: true);
    return AccountStatus(t.account.statusNone);
  }
  return switch (platform.check) {
    AccountCheckKind.online => _onlineStatus(t, check),
    AccountCheckKind.douyu => _douyuStatus(stored, t, now: now),
    AccountCheckKind.twitch => _twitchStatus(stored, t),
    AccountCheckKind.huya => _huyaStatus(stored, t),
    AccountCheckKind.none =>
      platform.usedByRequests
          ? AccountStatus(t.account.statusSaved, tone: AccountTone.ok, signedIn: true)
          : AccountStatus(t.account.statusStoredUnused, tone: AccountTone.warning, signedIn: true),
  };
}

/// The status of a credential the platform can be asked about: while the
/// answer is out the row says so, and a rejected login reads as one error
/// line rather than the silence of an unchecked one.
AccountStatus _onlineStatus(Translations t, AccountCheck? check) => switch (check) {
  null || AccountChecking() => AccountStatus(t.account.verifying, tone: AccountTone.busy, signedIn: true),
  AccountVerified(:final name) => AccountStatus(t.account.signedInAs(name: name), tone: AccountTone.ok, signedIn: true),
  AccountRejected() => AccountStatus(t.account.statusRejected, tone: AccountTone.error, signedIn: true),
  AccountCheckFailed() => AccountStatus(t.account.statusCheckFailed, tone: AccountTone.warning, signedIn: true),
};

/// Douyu's own answer: what the stored login is worth now that the renewal
/// pair lives beside the cookie (the four states 3.x's page reads out).
AccountStatus _douyuStatus(AccountSnapshot stored, Translations t, {required DateTime now}) {
  final credentials = douyuCredentials(stored);
  final state = DouyuAccount.sessionState(
    stored.cookie,
    now: now,
    savedAt: stored.douyuSavedAt,
    ltp0: credentials.ltp0,
    did: credentials.did,
  );
  return switch (state) {
    // A cookie with no session token signs in nobody: the row stays where it
    // was before the paste, so the viewer knows to fill it again. It is not a
    // stored login, so the row shows no sign-out.
    DouyuSessionState.none || DouyuSessionState.guest => AccountStatus(t.account.statusDouyuRepaste),
    DouyuSessionState.valid => AccountStatus(_douyuValid(stored, credentials, t), tone: AccountTone.ok, signedIn: true),
    // A lapsed login with a pair to renew it: the row reads as renewable and
    // the site renews it on the next play, so it stays signed in.
    DouyuSessionState.expiredRefreshable =>
      AccountStatus(t.account.statusDouyuRenewsOnPlay, tone: AccountTone.warning, signedIn: true),
    // Expired with nothing to renew it with — the pair is gone, so it is no
    // longer a login and the row drops the sign-out.
    DouyuSessionState.expired => AccountStatus(t.account.statusDouyuRepaste),
  };
}

/// Douyu's renewal pair for [stored]: the cookie's own `LTP0`/`dy_did`, else
/// the values stored beside it (the package's `renewalCredentials` order).
({String? ltp0, String? did}) douyuCredentials(AccountSnapshot stored, {String? typedLtp0, String? typedDid}) =>
    DouyuAccount.renewalCredentials(
      stored.cookie,
      typedLtp0: typedLtp0,
      typedDid: typedDid,
      storedLtp0: stored.douyuLtp0,
      storedDid: stored.douyuDid,
    );

/// The short line of a live douyu login: a pair that renews it before it
/// ends, the date it ends, or — with neither to go on — simply stored.
String _douyuValid(AccountSnapshot stored, ({String? ltp0, String? did}) credentials, Translations t) {
  if (credentials.ltp0 != null && credentials.did != null) return t.account.statusDouyuAutoRenew;
  return _douyuExpiry(stored, t);
}

/// The short line of a douyu login whose renewal says nothing: stored, or
/// stored until the web token's own end / the seven days counted from saving.
String _douyuExpiry(AccountSnapshot stored, Translations t) {
  final expiry = DouyuAccount.sessionExpiry(stored.cookie, savedAt: stored.douyuSavedAt) ?? stored.credential?.expiry;
  return expiry == null ? t.account.statusSaved : t.account.statusDouyuUntil(time: accountTime(expiry));
}

/// What douyu's login is worth, spelled out for the page's status card: the
/// session, when it ends and whether the pair renews it (3.x `_sessionSummary`).
String douyuSummary(AccountSnapshot stored, Translations t, {required DateTime now}) {
  final credentials = douyuCredentials(stored);
  final expiry = DouyuAccount.sessionExpiry(stored.cookie, savedAt: stored.douyuSavedAt);
  final at = expiry == null ? '' : accountTime(expiry);
  final hasPair = stored.douyuLtp0 != null || stored.douyuDid != null;
  return switch (
      DouyuAccount.sessionState(
        stored.cookie,
        now: now,
        savedAt: stored.douyuSavedAt,
        ltp0: credentials.ltp0,
        did: credentials.did,
      )
    ) {
    DouyuSessionState.none || DouyuSessionState.guest => stored.cookie.isEmpty
        ? (hasPair ? t.account.douyuPairOnly : t.account.douyuCookieCleared)
        : t.account.douyuCookieGuest,
    DouyuSessionState.valid when expiry == null => t.account.douyuCookieValidNoExpiry,
    DouyuSessionState.valid when credentials.ltp0 != null && credentials.did != null =>
      t.account.douyuCookieValidAutoRenew(time: at),
    DouyuSessionState.valid => t.account.douyuCookieValidRepaste(time: at),
    DouyuSessionState.expiredRefreshable => t.account.douyuCookieRenewable(time: at),
    DouyuSessionState.expired => t.account.douyuCookieExpired(time: at),
  };
}

/// Twitch's login is the chat identity its cookie carries; without the pair
/// the cookie opens no chat and the row says what is missing.
AccountStatus _twitchStatus(AccountSnapshot stored, Translations t) {
  final chat = twitchChatLogin(stored.cookie);
  return chat == null
      ? AccountStatus(t.account.statusTwitchNoChat, tone: AccountTone.warning, signedIn: true)
      : AccountStatus(t.account.statusTwitchChat(login: chat.login), tone: AccountTone.ok, signedIn: true);
}

/// Huya's login is its `yyuid` account id; a cookie without one signs in
/// nobody, however complete it looks.
AccountStatus _huyaStatus(AccountSnapshot stored, Translations t) {
  final uid = stored.credential?.cookies['yyuid'];
  return uid == null || uid.isEmpty
      ? AccountStatus(t.account.statusHuyaNoUid, tone: AccountTone.warning, signedIn: true)
      : AccountStatus(t.account.statusHuyaUid(uid: uid), tone: AccountTone.ok, signedIn: true);
}

/// Whether anything of the login is stored on this device (the row then
/// offers the sign-out; an unreadable credential can be removed too).
bool accountStored(AccountSnapshot stored) => stored.cookie.isNotEmpty || stored.unreadable;

/// [time] in local time as `yyyy-MM-dd HH:mm`.
String accountTime(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

final RegExp _cookieHeaderPrefix = RegExp(r'^\s*cookie\s*:\s*', caseSensitive: false);
final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');
final RegExp _cookiePair = RegExp(r'(?:^|;)\s*[^\s=;]+\s*=');

/// A pasted cookie as it should be stored: control characters, outer blanks
/// and a copied `Cookie:` header name removed.
String cleanPastedCookie(String text) =>
    text.replaceAll(_controlCharacters, '').replaceFirst(_cookieHeaderPrefix, '').trim();

/// Whether [cookie] has at least one `name=value` field — pasted text that
/// says nothing of the sort is not a cookie yet.
bool looksLikeCookie(String cookie) => _cookiePair.hasMatch(cookie);
