import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAuthCapability, LiveAuthPollStatus, LiveAuthSession, LiveSite, LiveSiteRegistry, SiteIds;
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account_platforms.dart';
import 'package:pure_live/features/account/account_providers.dart';
import 'package:pure_live/features/account/account_state.dart';
import 'package:pure_live/features/account/bilibili_web_cookies.dart' show bilibiliWebLoginAvailable;
import 'package:pure_live/features/account/bilibili_web_login_page.dart' show showBilibiliWebLoginPage;
import 'package:pure_live/features/account/douyu_login_store.dart' show accountSnapshotWithDouyu, douyuRenewalProvider;
import 'package:pure_live/features/account/platform_cookie_page.dart' show showPlatformCookiePage;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// "平台账号": one row per platform of the account catalog, in two groups.
///
/// A row says what the stored login is worth — not merely that something is
/// stored — so the platforms whose adapters can ask the platform who they
/// belong to are checked when the pane opens and whenever a credential
/// changes (each cookie is asked once). A row whose platform has something
/// stored ends in the sign-out; the rest end in a chevron, and a tap opens
/// that platform's sign-in.
final class AccountPane extends ConsumerStatefulWidget {
  /// The pane, or the accounts of [siteIds] alone (the Bilibili station
  /// shows just its own sign-in).
  const AccountPane({this.siteIds, super.key});

  /// The platform ids to keep; null lists every platform of the catalog.
  final Set<String>? siteIds;

  @override
  ConsumerState<AccountPane> createState() => _AccountPaneState();
}

class _AccountPaneState extends ConsumerState<AccountPane> {
  /// The last answer of each online check, keyed by platform id.
  final Map<String, AccountCheck> _checks = {};

  /// The cookie each check was run for, so one cookie is never asked twice.
  final Map<String, String> _checkedCookies = {};

  /// The platforms whose sign-out is currently being confirmed and applied.
  final Set<String> _signingOut = {};

  @override
  void initState() {
    super.initState();
    // The repository answers after the first frame, so the checks start from
    // the listener below; this pass only covers a store that was already
    // open when the pane came in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runChecks(_visiblePlatforms(), ref.read(accountsProvider));
    });
  }

  /// The catalog rows the pane shows, in the page's order.
  List<AccountPlatform> _visiblePlatforms() {
    final only = widget.siteIds;
    return [
      for (final platform in accountPlatforms)
        if (only == null || only.contains(platform.id)) platform,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(accountsProvider);
    final sites = ref.watch(sitesProvider);
    final platforms = _visiblePlatforms();
    // Every sign-in, sign-out and renewal leaves the store as a new state:
    // the cookies that changed get asked again, the vanished ones get their
    // answer dropped.
    ref.listen(accountsProvider, (_, next) => _runChecks(platforms, next));
    final domestic = [
      for (final platform in platforms)
        if (!platform.overseas) _row(state, sites, platform),
    ];
    final overseas = [
      for (final platform in platforms)
        if (platform.overseas) _row(state, sites, platform),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        if (domestic.isNotEmpty) DsListSection(header: Text(t.account.groupDomestic), children: domestic),
        if (overseas.isNotEmpty) DsListSection(header: Text(t.account.groupOverseas), children: overseas),
      ],
    );
  }

  /// One platform's row: its name, what its stored login is worth and the
  /// sign-out — or, with nothing stored, the chevron that says the row opens
  /// the sign-in.
  Widget _row(AccountsState state, LiveSiteRegistry sites, AccountPlatform platform) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final site = sites.getById(platform.id);
    final auth = site?.capability<LiveAuthCapability>();
    final name = site == null ? platform.id : localizedSiteName(site);
    final storedSnapshot = accountSnapshotOf(state, platform.id);
    // Douyu's row judges the whole login, so the renewal pair and save time
    // kept beside the cookie go into the snapshot the status is read from.
    final snapshot = platform.check == AccountCheckKind.douyu
        ? accountSnapshotWithDouyu(storedSnapshot, ref.watch(douyuRenewalProvider))
        : storedSnapshot;
    final status = accountStatus(platform, snapshot, t: t, now: DateTime.now(), check: _checks[platform.id]);
    final stored = accountStored(snapshot);
    final busy = _signingOut.contains(platform.id);
    return DsListRow(
      key: ValueKey('account-${platform.id}'),
      leading: snapshot.credential?.avatar == null
          ? (localizedSiteIcon(site, size: 32) ?? const DsIcon(DsIcons.user))
          : DsAvatar(image: cachedImage(snapshot.credential!.avatar!), initials: name, semanticLabel: name),
      title: Text(name),
      description: Text(
        status.text,
        style: TextStyle(
          color: accountToneColor(colors, status.tone),
          fontWeight: status.tone == AccountTone.ok ? FontWeight.w500 : null,
        ),
      ),
      trailing: stored
          ? DsTooltip(
              message: t.account.signOut,
              child: DsButton.icon(
                key: ValueKey('account-${platform.id}-sign-out'),
                semanticLabel: t.account.signOut,
                loading: busy,
                onPressed: busy ? null : () => unawaited(_signOut(platform.id, name)),
                icon: DsIcon(DsIcons.logOut, color: colors.danger.text),
              ),
            )
          : null,
      showChevron: !stored,
      onPressed: () => unawaited(_openSignIn(platform: platform, site: site, auth: auth, name: name, stored: stored)),
    );
  }

  /// The row's entry point. A platform that takes a pasted cookie opens the
  /// page the cookie lives on — the list row is only the way in. Bilibili,
  /// which also signs in by QR, goes straight to the code while it holds
  /// nothing, the way the reference list dispatches; a catalog platform whose
  /// adapter has no capability yet is said so rather than left to swallow the
  /// tap — its row stays on the page so the catalog never reads as shorter
  /// than it is.
  Future<void> _openSignIn({
    required AccountPlatform platform,
    required LiveSite? site,
    required LiveAuthCapability? auth,
    required String name,
    required bool stored,
  }) async {
    if (auth == null || site == null) {
      if (!mounted) return;
      showDsToast(
        context: context,
        title: context.t.account.noLoginMethod(site: name),
      );
      return;
    }
    if (auth.supportsCookiePaste) {
      if (siteSupportsQrLogin(auth) && !stored) {
        final exit = await showQrLoginDialog(context, site: site, auth: auth, onSignedIn: _toastSignedIn);
        if (!mounted || exit == AccountQrExit.closed) return;
        await showAccountSignInAlternative(context, siteId: site.manifest.id, exit: exit);
        return;
      }
      await showPlatformCookiePage(context, platform: platform);
      return;
    }
    if (siteSupportsQrLogin(auth)) {
      await showQrLoginDialog(context, site: site, auth: auth, onSignedIn: _toastSignedIn);
      return;
    }
    showDsToast(
      context: context,
      title: context.t.account.noLoginMethod(site: name),
    );
  }

  /// Runs the online checks [state]'s credentials call for: the platforms the
  /// page judges by asking the platform, once per cookie value.
  void _runChecks(List<AccountPlatform> platforms, AccountsState state) {
    var started = false;
    for (final platform in platforms) {
      if (platform.check != AccountCheckKind.online) continue;
      final cookie = accountCookieLine(state.credentials[platform.id]);
      if (cookie.isEmpty) {
        _checkedCookies.remove(platform.id);
        _checks.remove(platform.id);
        started = true;
        continue;
      }
      // The same cookie needs no second answer, and a check already out for
      // it needs no companion.
      if (_checkedCookies[platform.id] == cookie) continue;
      _checkedCookies[platform.id] = cookie;
      _checks[platform.id] = const AccountChecking();
      started = true;
      unawaited(_check(platform.id, cookie));
    }
    if (started && mounted) setState(() {});
  }

  /// Asks platform [siteId] who its [cookie] signs in, and keeps the answer
  /// for as long as that cookie is the stored one.
  Future<void> _check(String siteId, String cookie) async {
    final auth = ref.read(sitesProvider).getById(siteId)?.capability<LiveAuthCapability>();
    if (auth == null || !auth.canVerifyOnline) return;
    final result = await _askAccount(auth);
    if (!mounted || accountCookieLine(ref.read(accountsProvider).credentials[siteId]) != cookie) return;
    if (result is AccountRejected && siteId == SiteIds.bilibili) {
      // A bilibili login the platform no longer recognises is over: say so
      // and drop it, the way a browser gives up on a rejected session.
      showDsToast(context: context, title: context.t.account.bilibiliLoginExpired, status: DsStatus.danger);
      await _dropCredential(siteId);
      return;
    }
    setState(() => _checks[siteId] = result);
  }

  /// Asks [auth] who its applied login is: the platform's own refusal reads
  /// as a rejected credential, anything else (a breakdown, a changed answer)
  /// as a question the cookie is still waiting on.
  Future<AccountCheck> _askAccount(LiveAuthCapability auth) async {
    try {
      final account = await auth.fetchAccount();
      return AccountVerified(account.nickname ?? account.userId ?? account.siteId);
    } on Object catch (error) {
      return accountCheckFailure(error);
    }
  }

  void _toastSignedIn() {
    if (!mounted) return;
    showDsToast(context: context, title: context.t.account.loginSuccess);
  }

  /// Signs [siteId] out behind a confirm: the credential leaves the site and
  /// the secret store together and the row falls back to its chevron.
  Future<void> _signOut(String siteId, String name) async {
    if (_signingOut.contains(siteId)) return;
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.account.signOut,
      description: t.account.signOutConfirmDesc(site: name),
      confirmLabel: t.common.confirm,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _dropCredential(siteId);
  }

  /// Removes [siteId]'s credential. [announce] adds the toast a viewer
  /// pressing the sign-out expects; a check that signed a dead login out on
  /// its own has already said what happened.
  Future<void> _dropCredential(String siteId, {bool announce = true}) async {
    if (_signingOut.contains(siteId)) return;
    final t = context.t;
    setState(() => _signingOut.add(siteId));
    try {
      await ref.read(accountsProvider.notifier).signOut(siteId);
      if (mounted && announce) showDsToast(context: context, title: t.account.signOutSuccess);
    } on Object {
      if (mounted) showDsToast(context: context, title: t.account.signOutFailed, status: DsStatus.danger);
    } finally {
      if (mounted) setState(() => _signingOut.remove(siteId));
    }
  }
}

/// The ink a status is drawn in: the plain one for a login that holds,
/// muted for what is stored but unproven, danger for what signs in nobody.
Color accountToneColor(DsColors colors, AccountTone tone) => switch (tone) {
  AccountTone.idle => colors.textMuted,
  AccountTone.ok => colors.text,
  AccountTone.busy || AccountTone.warning => colors.textSubtle,
  AccountTone.error => colors.danger.text,
};

/// Opens [site]'s QR login over a dialog: the row's one-tap sign-in and the
/// cookie page's scan entry share it, so a code asked from either place
/// polls, exchanges, applies and stores the same way. [onSignedIn] answers
/// once the dialog closed on a login that landed.
///
/// The dialog also carries the reference QR page's "扫不了？" row, and says
/// which of those ways the viewer took: the caller opens it, because only the
/// caller knows what is already underneath the dialog.
Future<AccountQrExit> showQrLoginDialog(
  BuildContext context, {
  required LiveSite site,
  required LiveAuthCapability auth,
  VoidCallback? onSignedIn,
}) async =>
    (await showDsDialog<AccountQrExit>(
      context: context,
      builder: (dialogContext) =>
          _QrLoginDialog(site: site, auth: auth, onSignedIn: onSignedIn ?? _noSignInAnnouncement),
    )) ??
    AccountQrExit.closed;

/// Why a QR dialog closed: on its own (cancelled, or a login that landed), or
/// on one of the two ways out the reference's QR page offers under 扫不了？.
enum AccountQrExit {
  /// Nothing else was asked for.
  closed,

  /// The web (SMS, password) sign-in in the app's built-in browser.
  webLogin,

  /// Fill in the cookie of a browser signed in elsewhere.
  cookiePage,
}

/// Opens what the QR dialog's 扫不了？ row asked for. The web sign-in is only
/// ever asked for where [bilibiliWebLoginAvailable] says there is a browser,
/// so this never pushes a page that cannot show one; a paste leads to the
/// platform's cookie page, which is where a cookie is read, checked and kept.
Future<void> showAccountSignInAlternative(
  BuildContext context, {
  required String siteId,
  required AccountQrExit exit,
}) async {
  if (exit == AccountQrExit.webLogin) {
    await showBilibiliWebLoginPage(context);
    return;
  }
  if (exit != AccountQrExit.cookiePage) return;
  final platform = accountPlatformOf(siteId);
  if (platform == null) return;
  await showPlatformCookiePage(context, platform: platform);
}

/// What a QR sign-in answers to when the caller asked for nothing: the store
/// carries the login, so a page that follows it needs no further word.
void _noSignInAnnouncement() {}

/// One QR login's dialog: the code rendered from the session's content,
/// polled every two seconds until the platform answers success (the
/// exchange, the apply and the store follow) or expired (a fresh code on
/// request).
final class _QrLoginDialog extends ConsumerStatefulWidget {
  const _QrLoginDialog({required this.site, required this.auth, required this.onSignedIn});

  /// The site signing in.
  final LiveSite site;

  /// The site's auth capability.
  final LiveAuthCapability auth;

  /// Fired after a successful sign-in, once the dialog has closed.
  final VoidCallback onSignedIn;

  @override
  ConsumerState<_QrLoginDialog> createState() => _QrLoginDialogState();
}

final class _QrLoginDialogState extends ConsumerState<_QrLoginDialog> {
  static const Duration _pollInterval = Duration(seconds: 2);

  LiveAuthSession? _session;
  String? _qrContent;
  Object? _failure;
  bool _expired = false;
  bool _pollFailed = false;
  bool _completing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final name = siteDisplayName(widget.site);
    return DsDialog(
      title: Text(t.account.qrDialogTitle(site: name)),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Center(
            child: SizedBox(
              width: 184,
              height: 184,
              child: DecoratedBox(
                decoration: DsBoxDecoration(color: Colors.white, borderRadius: theme.radii.controlCorners(null, 16)),
                child: Padding(
                  padding: const EdgeInsets.all(DsSpace.s8),
                  child: Center(child: _qrBody(context)),
                ),
              ),
            ),
          ),
          Text(
            _expired ? t.account.qrExpired : t.account.qrHint(site: name),
            textAlign: TextAlign.center,
            style: theme.typography.body.copyWith(color: colors.textMuted),
          ),
          // "扫不了？" (the reference's QR page, c12): the web sign-in on a
          // device that has a built-in browser, and the cookie everywhere.
          // A way out the platform cannot actually take is not offered.
          Text(
            t.account.qrCannotScan,
            textAlign: TextAlign.center,
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s4,
            children: [
              if (_offersWebLogin)
                DsButton(
                  key: const ValueKey('account-qr-web-login'),
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: () => _leave(AccountQrExit.webLogin),
                  leading: const DsIcon(DsIcons.globe),
                  child: Text(t.account.webLogin),
                ),
              if (widget.auth.supportsCookiePaste)
                DsButton(
                  key: const ValueKey('account-qr-paste-cookie'),
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: () => _leave(AccountQrExit.cookiePage),
                  leading: const DsIcon(DsIcons.clipboardPaste),
                  child: Text(t.account.pasteCookieEntry),
                ),
            ],
          ),
          if (_failure != null)
            Text(
              t.account.loginFailed(message: signInFailureText(_failure!)),
              textAlign: TextAlign.center,
              style: theme.typography.small.copyWith(color: colors.danger.text),
            )
          else if (_pollFailed)
            Text(
              t.account.qrPollingFailed,
              textAlign: TextAlign.center,
              style: theme.typography.small.copyWith(color: colors.textSubtle),
            ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        if (_expired) DsButton(onPressed: () => setState(_start), child: Text(t.account.qrRetry)),
      ],
    );
  }

  /// The QR area's body: a spinner while the code is still being issued,
  /// the code once it exists, the empty state once it expired.
  Widget _qrBody(BuildContext context) {
    final content = _qrContent;
    if (content == null) {
      return _expired
          ? DsEmptyState(icon: const DsIcon(DsIcons.qrCode), title: Text(context.t.account.qrExpired))
          : const SizedBox(width: 28, height: 28, child: DsSpinner());
    }
    return PrettyQrView.data(data: content);
  }

  /// Starts (or restarts) one QR login: a fresh session and the poll
  /// timer. The first poll also issues the code, so the image appears
  /// after the first pending answer.
  void _start() {
    _timer?.cancel();
    try {
      _session = widget.auth.startQrLogin();
    } on Object {
      _session = null;
    }
    _qrContent = null;
    _failure = null;
    _expired = false;
    _pollFailed = false;
    _completing = false;
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
    unawaited(_poll());
  }

  Future<void> _poll() async {
    final session = _session;
    if (session == null || _completing || !mounted) return;
    try {
      final result = await session.poll();
      if (!mounted || _completing) return;
      switch (result.status) {
        case LiveAuthPollStatus.pending:
          _readQrContent(session);
          if (_pollFailed || _failure != null) {
            setState(() {
              _pollFailed = false;
              _failure = null;
            });
          }
        case LiveAuthPollStatus.success:
          _timer?.cancel();
          _completing = true;
          await _complete(session);
        case LiveAuthPollStatus.expired:
          _timer?.cancel();
          setState(() => _expired = true);
      }
    } on Object {
      // A transport breakdown is not the end of the login: the next tick
      // asks again, and the dialog says so.
      if (mounted && !_pollFailed) setState(() => _pollFailed = true);
    }
  }

  void _readQrContent(LiveAuthSession session) {
    if (_qrContent != null) return;
    try {
      final content = session.qrContent;
      if (mounted) setState(() => _qrContent = content);
    } on Object {
      // The code is still being issued; the next poll answers first.
    }
  }

  /// Whether this dialog offers the web sign-in: bilibili's, and only on a
  /// device that really has a built-in browser (`webview_flutter` ships no
  /// Windows or Linux implementation, where the entry is simply absent).
  bool get _offersWebLogin => widget.site.manifest.id == SiteIds.bilibili && bilibiliWebLoginAvailable;

  /// Closes the dialog asking the caller for one of the other ways in.
  void _leave(AccountQrExit exit) {
    _timer?.cancel();
    Navigator.of(context).pop(exit);
  }

  Future<void> _complete(LiveAuthSession session) async {
    final failure = await ref.read(accountsProvider.notifier).completeQrLogin(widget.site.manifest.id, session);
    if (!mounted) return;
    if (failure != null) {
      _completing = false;
      setState(() {
        _failure = failure;
        _pollFailed = false;
      });
      // The session stays confirmed — the next polls answer success again,
      // so re-arming the loop retries the exchange.
      _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
      return;
    }
    Navigator.of(context).pop(AccountQrExit.closed);
    widget.onSignedIn();
  }
}

/// The cookie sign-in's dialog: the pasted browser cookie goes through the
/// site's own verification, and a verified paste lands as the credential.
///
/// The account list's rows no longer open it — a cookie is read, edited and
/// dropped on the full page (`PlatformCookiePage`) — but a caller that needs
/// the paste without leaving its own view can show this one.
final class CookieLoginDialog extends ConsumerStatefulWidget {
  /// The dialog for [site]'s cookie paste.
  const CookieLoginDialog({required this.site, required this.auth, required this.onSignedIn, super.key});

  /// The site signing in.
  final LiveSite site;

  /// The site's auth capability.
  final LiveAuthCapability auth;

  /// Fired after a successful sign-in, once the dialog has closed.
  final VoidCallback onSignedIn;

  @override
  ConsumerState<CookieLoginDialog> createState() => _CookieLoginDialogState();
}

final class _CookieLoginDialogState extends ConsumerState<CookieLoginDialog> {
  final TextEditingController _field = TextEditingController();
  Object? _failure;
  bool _busy = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final name = siteDisplayName(widget.site);
    return DsDialog(
      title: Text(t.account.cookieDialogTitle(site: name)),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(t.account.cookieDialogHint, style: theme.typography.body.copyWith(color: colors.textMuted)),
          DsTextField.multiline(
            controller: _field,
            autofocus: true,
            placeholder: t.account.cookieFieldHint,
            semanticLabel: t.account.cookieFieldHint,
          ),
          if (_failure != null)
            Text(
              t.account.loginFailed(message: signInFailureText(_failure!)),
              style: theme.typography.small.copyWith(color: colors.danger.text),
            ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(loading: _busy, onPressed: _busy ? null : () => unawaited(_commit()), child: Text(t.common.confirm)),
      ],
    );
  }

  Future<void> _commit() async {
    final raw = _field.text.trim();
    if (raw.isEmpty || _busy) return;
    setState(() => _busy = true);
    final failure = await ref.read(accountsProvider.notifier).signInWithCookie(widget.site.manifest.id, raw);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _failure = failure;
      });
      return;
    }
    Navigator.of(context).pop();
    widget.onSignedIn();
  }
}
