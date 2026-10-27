import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:pure_live/features/account/account_platforms.dart' show accountPlatformOf;
import 'package:pure_live/features/account/account_providers.dart' show accountsProvider, signInFailureText;
import 'package:pure_live/features/account/account_state.dart' show cleanPastedCookie;
import 'package:pure_live/features/account/bilibili_web_cookies.dart';
import 'package:pure_live/features/account/platform_cookie_page.dart' show showPlatformCookiePage;
import 'package:pure_live/l10n/translations.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens bilibili's web sign-in in the app's built-in browser.
///
/// Answers true when a login landed (the page closes itself on one), false or
/// null when the viewer left without it. Callers show this only where
/// [bilibiliWebLoginAvailable] says there is a browser to show — on a host
/// without one the entry is not offered at all.
Future<bool?> showBilibiliWebLoginPage(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<bool>(DsPageRoute<bool>(builder: (context) => const BilibiliWebLoginPage()));

/// Bilibili's sign-in page (SMS or password) inside the app, in place of the
/// reference's 3.x `BiliBiliWebLoginPage`.
///
/// Three promises, in this order. Before the page opens the browser's
/// bilibili cookies are removed, so the account signed in there last time is
/// never read back as this viewer's own login. While the page is on
/// bilibili, its cookies are read on a timer and only a header that carries a
/// `SESSDATA` counts as a sign-in. And what the browser hands over goes
/// through the same door a pasted cookie does — the platform is asked who the
/// cookie signs in *before* anything is stored, so a cookie that signs in
/// nobody is refused and said so instead of quietly becoming the login.
final class BilibiliWebLoginPage extends ConsumerStatefulWidget {
  /// The page.
  const BilibiliWebLoginPage({super.key});

  @override
  ConsumerState<BilibiliWebLoginPage> createState() => _BilibiliWebLoginPageState();
}

final class _BilibiliWebLoginPageState extends ConsumerState<BilibiliWebLoginPage> {
  /// How often the browser's cookies are read for a sign-in.
  static const Duration _pollInterval = Duration(milliseconds: 1500);

  WebViewController? _controller;
  Timer? _poller;

  /// The browser's cookies are still being removed; nothing is read before
  /// that ends.
  bool _clearing = true;

  /// The page the browser is on, for the line under the bar.
  String? _url;

  /// A tick is in flight; ticks never overlap.
  bool _polling = false;

  /// A sign-in was found and is being checked and stored.
  bool _verifying = false;

  /// The sign-in stops after a refusal until the viewer asks again: the
  /// browser would hand the same refused cookie back on every tick.
  bool _paused = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    if (bilibiliWebLoginAvailable) unawaited(_open());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    // Fresh eyes only: whatever bilibili left in the browser from the last
    // visit is removed before the page loads.
    try {
      await clearBilibiliWebCookies();
    } on Object {
      // A browser that would not clear is still a browser to sign in on; the
      // check before the login is stored is what keeps an old account out.
    }
    if (!mounted) return;
    final controller = WebViewController();
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _url = url);
          },
          onUrlChange: (change) {
            if (mounted && change.url != null) setState(() => _url = change.url);
          },
        ),
      ),
    );
    unawaited(controller.loadRequest(bilibiliPassportLogin));
    setState(() {
      _clearing = false;
      _controller = controller;
    });
    _arm();
  }

  void _arm() {
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  /// Whether the browser is on one of bilibili's own pages; the cookies of
  /// anywhere else are not this login's business.
  bool get _onBilibili {
    final host = Uri.tryParse(_url ?? '')?.host.toLowerCase() ?? '';
    return host == 'bilibili.com' || host.endsWith('.bilibili.com');
  }

  Future<void> _poll() async {
    if (_polling || _verifying || _paused || !_onBilibili) return;
    _polling = true;
    final header = await readBilibiliWebCookieHeader();
    _polling = false;
    if (!mounted || _verifying || _paused) return;
    // No session cookie yet: the viewer is still signing in on the page.
    if (!hasBilibiliSessionCookie(header)) return;
    await _complete(cleanPastedCookie(header));
  }

  /// Stores the sign-in the browser just produced, the QR code's way: the
  /// platform's answer comes first, and a cookie it says signs in nobody
  /// stores nothing. A checked login also lands in the remembered sign-ins,
  /// the same as a scanned one.
  Future<void> _complete(String cookie) async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    _poller?.cancel();
    final failure = await ref.read(accountsProvider.notifier).signInWithCookie(SiteIds.bilibili, cookie);
    if (!mounted) return;
    if (failure != null) {
      final message = signInFailureText(failure);
      setState(() {
        _verifying = false;
        _paused = true;
        _error = message;
      });
      showDsToast(context: context, title: message, status: DsStatus.danger);
      return;
    }
    setState(() => _verifying = false);
    showDsToast(context: context, title: context.t.account.loginSuccess);
    Navigator.of(context).pop(true);
  }

  /// Tries again after a refusal: the browser may hold a new cookie by now
  /// (the viewer signed in a second time, or fixed the page).
  void _retry() {
    setState(() {
      _paused = false;
      _error = null;
    });
    _arm();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    return ColoredBox(
      color: colors.canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(t),
            if (_error case final error?) _failureBar(t, error),
            Expanded(child: _body(t)),
          ],
        ),
      ),
    );
  }

  Widget _header(Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s16, DsSpace.s8),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          DsButton.icon(
            variant: DsButtonVariant.ghost,
            onPressed: () => Navigator.of(context).maybePop(false),
            icon: const DsIcon(DsIcons.chevronLeft),
            semanticLabel: t.common.back,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  t.account.webLoginTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.title.copyWith(color: colors.text),
                ),
                if (!_clearing)
                  Text(
                    _statusLine(t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
              ],
            ),
          ),
          DsButton.icon(
            variant: DsButtonVariant.ghost,
            onPressed: () => Navigator.of(context).maybePop(false),
            icon: const DsIcon(DsIcons.x),
            semanticLabel: t.common.close,
          ),
        ],
      ),
    );
  }

  /// What the page is doing, in its own line: waiting for the browser, asking
  /// the viewer to sign in, reading the cookie or checking the account.
  String _statusLine(Translations t) {
    if (_verifying) return t.account.verifying;
    if (_error != null) return _error!;
    if (!_onBilibili) return t.account.webLoginSignInOnPage;
    final home = isBilibiliHome(Uri.tryParse(_url ?? '') ?? Uri());
    return home ? t.account.webLoginReading : t.account.webLoginSignInOnPage;
  }

  Widget _body(Translations t) {
    if (!bilibiliWebLoginAvailable) {
      return DsEmptyState(
        icon: const DsIcon(DsIcons.globe),
        title: Text(t.account.webLoginUnavailable),
        description: Text(t.account.webLoginUnavailableDesc),
        actions: [
          DsButton(
            onPressed: () => unawaited(_openCookiePage()),
            leading: const DsIcon(DsIcons.clipboardPaste),
            child: Text(t.account.pasteCookieEntry),
          ),
        ],
      );
    }
    if (_clearing) {
      return const Center(key: ValueKey('bilibili-web-clearing'), child: DsSpinner());
    }
    final controller = _controller;
    if (controller == null) {
      return DsEmptyState(icon: const DsIcon(DsIcons.globe), title: Text(t.account.webLoginUnavailable));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: controller),
        if (_verifying) _verifyingOverlay(t),
      ],
    );
  }

  Widget _verifyingOverlay(Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return ColoredBox(
      key: const ValueKey('bilibili-web-verifying'),
      color: colors.overlay,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s12,
          children: [
            const DsSpinner(),
            Text(t.account.verifying, style: theme.typography.small.copyWith(color: colors.text)),
          ],
        ),
      ),
    );
  }

  Widget _failureBar(Translations t, String message) {
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s16, 0, DsSpace.s8, 0),
      child: DsAlert(
        key: const ValueKey('bilibili-web-error'),
        status: DsStatus.danger,
        title: Text(t.account.webLoginFailed),
        description: Text(message, style: theme.typography.small.copyWith(height: 1.45)),
        action: DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          onPressed: _retry,
          leading: const DsIcon(DsIcons.refreshCw),
          child: Text(t.common.retry),
        ),
      ),
    );
  }

  /// The way out that is always real: paste the cookie of a browser the
  /// viewer signed in elsewhere. (Reached only on a host with no built-in
  /// browser, where this page is the fallback rather than the login.)
  Future<void> _openCookiePage() async {
    final platform = accountPlatformOf(SiteIds.bilibili);
    if (platform == null || !mounted) return;
    await showPlatformCookiePage(context, platform: platform);
  }
}
