import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAuthCapability, LiveAuthPollStatus, LiveAuthSession, LiveCredential, LiveSite;
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/account/account_providers.dart';
import 'package:pure_live/l10n/translations.dart';

/// The account pane: one row per site that offers the auth capability —
/// the account's avatar and display name when the viewer is signed in, an
/// invite to sign in otherwise — with the site's own sign-in flows (a QR
/// scan, a pasted cookie, whichever it supports) and the destructive
/// sign-out behind a confirm.
final class AccountPane extends ConsumerWidget {
  /// The pane.
  const AccountPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final authSites = [
      for (final site in ref.watch(sitesProvider).all)
        if (site.capability<LiveAuthCapability>() != null) site,
    ];
    return DsListSection(
      header: Text(t.account.sectionHeader),
      children: [
        if (authSites.isEmpty)
          Padding(
            padding: const EdgeInsets.all(DsSpace.s12),
            child: DsEmptyState(icon: const DsIcon(DsIcons.user), title: Text(t.account.empty)),
          ),
        for (final site in authSites) _AccountRow(site: site),
      ],
    );
  }
}

/// One site's row: who is signed in (or that nobody is), and the row's
/// actions — the site's sign-in flow and, once signed in, the sign-out.
final class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.site});

  /// The site the row serves.
  final LiveSite site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final credential = ref.watch(accountsProvider.select((state) => state.credentials[site.manifest.id]));
    final auth = site.capability<LiveAuthCapability>();
    final withQr = auth != null && siteSupportsQrLogin(auth);
    final name = siteDisplayName(site);
    final signedIn = credential != null;
    return DsListRow(
      leading: credential?.avatar == null
          ? const DsIcon(DsIcons.user)
          : DsAvatar(image: NetworkImage(credential!.avatar!), initials: name, semanticLabel: name),
      title: Text(name),
      description: Text(signedIn ? t.account.signedInAs(name: _displayName(credential)) : t.account.notSignedIn),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s8,
        children: [
          if (auth != null)
            DsButton(
              variant: signedIn ? DsButtonVariant.tinted : DsButtonVariant.primary,
              onPressed: () => unawaited(_signIn(context, ref)),
              child: Text(withQr ? t.account.qrLogin : t.account.cookieLogin),
            ),
          if (signedIn)
            DsButton(
              variant: DsButtonVariant.dangerSoft,
              onPressed: () => unawaited(_signOut(context, ref)),
              child: Text(t.account.signOut),
            ),
        ],
      ),
    );
  }

  /// The account's display name: its nickname, else its platform id, else
  /// the site's own id.
  String _displayName(LiveCredential credential) => credential.nickname ?? credential.userId ?? credential.siteId;

  /// Opens the site's sign-in flow: the QR dialog when the site scans, the
  /// cookie dialog otherwise.
  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final auth = site.capability<LiveAuthCapability>();
    if (auth == null) return;
    final withQr = siteSupportsQrLogin(auth);
    if (!context.mounted) return;
    if (withQr) {
      await showDsDialog<void>(
        context: context,
        builder: (dialogContext) => _QrLoginDialog(site: site, auth: auth, onSignedIn: () => _toastSignedIn(context)),
      );
    } else {
      await showDsDialog<void>(
        context: context,
        builder: (dialogContext) =>
            _CookieLoginDialog(site: site, auth: auth, onSignedIn: () => _toastSignedIn(context)),
      );
    }
  }

  void _toastSignedIn(BuildContext context) {
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.account.loginSuccess);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final name = siteDisplayName(site);
    final confirmed = await showDsConfirm(
      context: context,
      title: t.account.signOut,
      description: t.account.signOutConfirmDesc(site: name),
      confirmLabel: t.common.confirm,
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(accountsProvider.notifier).signOut(site.manifest.id);
    if (!context.mounted) return;
    showDsToast(context: context, title: t.account.signOutSuccess);
  }
}

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
    Navigator.of(context).pop();
    widget.onSignedIn();
  }
}

/// The cookie sign-in's dialog: the pasted browser cookie goes through the
/// site's own verification, and a verified paste lands as the credential.
final class _CookieLoginDialog extends ConsumerStatefulWidget {
  const _CookieLoginDialog({required this.site, required this.auth, required this.onSignedIn});

  /// The site signing in.
  final LiveSite site;

  /// The site's auth capability.
  final LiveAuthCapability auth;

  /// Fired after a successful sign-in, once the dialog has closed.
  final VoidCallback onSignedIn;

  @override
  ConsumerState<_CookieLoginDialog> createState() => _CookieLoginDialogState();
}

final class _CookieLoginDialogState extends ConsumerState<_CookieLoginDialog> {
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
