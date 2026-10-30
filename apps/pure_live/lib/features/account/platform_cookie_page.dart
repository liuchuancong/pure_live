import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, LogicalKeyboardKey, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show DouyuAccount, DouyuSite, LiveAuthCapability, LiveSite, SiteIds;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account_pane.dart'
    show AccountQrExit, accountToneColor, showAccountSignInAlternative, showQrLoginDialog;
import 'package:pure_live/features/account/account_platforms.dart';
import 'package:pure_live/features/account/account_providers.dart';
import 'package:pure_live/features/account/account_repository.dart' show BilibiliAccount;
import 'package:pure_live/features/account/account_state.dart';
import 'package:pure_live/features/account/bilibili_accounts.dart'
    show
        BilibiliAccountsGroup,
        bilibiliAccountLabel,
        bilibiliAccountLimit,
        bilibiliAccountsProvider,
        isCurrentBilibiliAccount;
import 'package:pure_live/features/account/douyu_cookie_saved_at.dart' show douyuCookieSavedAtProvider;
import 'package:pure_live/features/account/douyu_login_store.dart'
    show accountSnapshotWithDouyu, douyuRenewalProvider;
import 'package:pure_live/features/settings/settings.dart' show douyuForceRenewProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart' show cachedImage, localizedSiteIcon, localizedSiteName;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The widest the cookie page's column gets on a big window; below that it
/// fills the width, so a phone or a narrow pane never scrolls sideways.
const double _cookiePageMaxWidth = 720;

/// Opens [platform]'s cookie page — the whole page an account's cookie is
/// read, pasted, verified and dropped on, the way 3.x's
/// `AccountCookieEditorPage` did rather than as a dialog over the list.
///
/// The account list's rows lead here for every platform that takes a pasted
/// cookie; a platform signed in only by QR (bilibili with nothing stored)
/// still goes straight to the code.
Future<void> showPlatformCookiePage(BuildContext context, {required AccountPlatform platform}) {
  // The root navigator, so the page replaces the shell the way the app's
  // other full pages do; the theme scope above the navigator reaches it.
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(builder: (context) => PlatformCookiePage(platform: platform)));
}

/// The cookie page of one platform: its status up top, the cookie box with
/// its paste/clear/save row, the sign-out when a login is stored and the
/// privacy note at the bottom.
///
/// Two promises shape the flow. A platform the app can ask online is asked
/// *before* a paste is kept: a cookie that signs in nobody is refused and the
/// card falls back to what it said before. And text that was never saved is
/// not silently dropped — leaving asks first, on every way out (back button,
/// Escape, the edge gesture).
final class PlatformCookiePage extends ConsumerStatefulWidget {
  /// The page for one platform of the account catalog.
  const PlatformCookiePage({required this.platform, super.key});

  /// The platform whose credential is edited.
  final AccountPlatform platform;

  @override
  ConsumerState<PlatformCookiePage> createState() => _PlatformCookiePageState();
}

class _PlatformCookiePageState extends ConsumerState<PlatformCookiePage> {
  final TextEditingController _cookie = TextEditingController();

  /// The renewal key (LTP0) and login device id, kept beside the cookie for
  /// the platforms that renew a lapsed login (douyu only).
  final TextEditingController _ltp0 = TextEditingController();
  final TextEditingController _did = TextEditingController();

  /// The cookie as the vault holds it: the box counts as unchanged while it
  /// says this.
  String _saved = '';

  /// The pair as the vault holds it, for the same dirty count on douyu.
  ({String ltp0, String did}) _savedPair = (ltp0: '', did: '');

  /// A douyu renewal request is in flight (the "renew now" button's spinner).
  bool _renewing = false;

  /// A bilibili account switch or deletion is running: the roster's buttons
  /// wait, and the page does not take a second one underneath it.
  bool _accountsBusy = false;

  /// The last answer about the stored login, for the platforms judged online.
  AccountCheck? _check;

  /// Bumped by every check so an answer about a superseded cookie is dropped.
  int _checkRun = 0;

  bool _dirty = false;
  bool _busy = false;
  bool _confirmingDiscard = false;
  String? _error;

  String get _siteId => widget.platform.id;

  /// Whether this is the douyu page: the one platform with a renewal pair, a
  /// save time and a "renew now" inside its cookie card.
  bool get _isDouyu => widget.platform.check == AccountCheckKind.douyu;

  /// Whether this is bilibili's page: the one platform that remembers the
  /// accounts it has signed in, so they can be switched back to without a new
  /// scan.
  bool get _isBilibili => widget.platform.id == SiteIds.bilibili;

  LiveSite? get _site => ref.read(sitesProvider).getById(_siteId);

  LiveAuthCapability? get _auth => _site?.capability<LiveAuthCapability>();

  /// Whether a paste is asked about before it is kept: the catalog says the
  /// platform's login is judged online and its adapter can actually ask.
  bool get _verifiesOnline => widget.platform.check == AccountCheckKind.online && (_auth?.canVerifyOnline ?? false);

  @override
  void initState() {
    super.initState();
    // A vault still opening answers empty here; the post-frame pass below
    // takes whatever it holds once it is ready.
    _saved = accountCookieLine(ref.read(accountsProvider).credentials[_siteId]);
    _cookie
      ..text = _saved
      ..addListener(_onTextChanged);
    if (_isDouyu) {
      final renewal = ref.read(douyuRenewalProvider);
      _savedPair = (ltp0: renewal.ltp0 ?? '', did: renewal.did ?? '');
      _ltp0
        ..text = _savedPair.ltp0
        ..addListener(_onPairChanged);
      _did
        ..text = _savedPair.did
        ..addListener(_onPairChanged);
    }
    if (_verifiesOnline && _saved.isNotEmpty) {
      _check = const AccountChecking();
      unawaited(_runVerify(++_checkRun));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _adopt(ref.read(accountsProvider));
    });
  }

  @override
  void dispose() {
    _cookie
      ..removeListener(_onTextChanged)
      ..dispose();
    _ltp0.removeListener(_onPairChanged);
    _ltp0.dispose();
    _did.removeListener(_onPairChanged);
    _did.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // Every sign-in, sign-out and renewal elsewhere in the app lands here as
    // a new store value: the box follows it while nothing is being edited.
    ref.listen(accountsProvider, (_, next) => _adopt(next));
    final storedSnapshot = accountSnapshotOf(ref.watch(accountsProvider), _siteId);
    // Douyu's status card reads the whole login, so the renewal pair and save
    // time kept beside the cookie go into the snapshot it is judged from.
    final snapshot = _isDouyu
        ? accountSnapshotWithDouyu(storedSnapshot, ref.watch(douyuRenewalProvider))
        : storedSnapshot;
    final status = accountStatus(widget.platform, snapshot, t: t, now: DateTime.now(), check: _check);
    final stored = accountStored(snapshot);
    final auth = _auth;
    final qrLogin = auth != null && siteSupportsQrLogin(auth);
    final recheck = _verifiesOnline && snapshot.cookie.isNotEmpty && _check is! AccountChecking;
    return CallbackShortcuts(
      // The page's own save key, the way 3.x's editor had one; the text field
      // does not claim Ctrl/Cmd+S, so the shortcut reaches this layer.
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => unawaited(_save()),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () => unawaited(_save()),
      },
      child: PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_confirmDiscard());
        },
        child: ColoredBox(
          color: DsTheme.colorsOf(context).canvas,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(t),
                Expanded(
                  child: _body(
                    t,
                    snapshot: snapshot,
                    status: status,
                    stored: stored,
                    qrLogin: qrLogin,
                    recheck: recheck,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The page's bar: back and the platform's name. The actions live in the
  /// body, where they can wrap on a narrow window instead of crowding this
  /// row.
  Widget _header(Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s16, DsSpace.s4),
      child: Row(
        children: [
          DsButton.icon(
            variant: DsButtonVariant.ghost,
            // `maybePop`, so an unsaved paste is asked about exactly as it is
            // by the back gesture and the keyboard.
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            icon: const DsIcon(DsIcons.chevronLeft),
            semanticLabel: t.common.back,
          ),
          Expanded(
            child: Text(
              t.account.cookiePageTitle(site: _displayName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.title.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
  }

  /// The scrollable body. Each block is centred and capped at
  /// [_cookiePageMaxWidth], so a wide window reads a column and a phone or a
  /// narrow pane gets the same blocks full width without squeezing the row of
  /// buttons — a `Wrap` puts the save button on a line of its own when the
  /// width runs out.
  Widget _body(
    Translations t, {
    required AccountSnapshot snapshot,
    required AccountStatus status,
    required bool stored,
    required bool qrLogin,
    required bool recheck,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = constraints.maxWidth < 360 ? DsSpace.s12 : DsSpace.s20;
        final blocks = <Widget>[
          _statusCard(t, snapshot: snapshot, status: status, recheck: recheck),
          _howTo(t),
          _cookieGroup(t, qrLogin: qrLogin),
          // Bilibili's remembered sign-ins: what this device can switch back
          // to without a new scan. Once the current login or a remembered one
          // exists, the group is the place they are read.
          if (_isBilibili && (stored || ref.watch(bilibiliAccountsProvider).isNotEmpty))
            _bilibiliAccountsGroup(t, snapshot: snapshot),
          // A login that signs in nobody (a lapsed douyu cookie with nothing
          // to renew it) shows no sign-out — the row's whole point there is
          // to paste again, so the box stays the way out.
          if (stored && status.signedIn) _signOutRow(t),
          _privacy(t),
        ];
        return ListView(
          key: const ValueKey('account-cookie-scroll'),
          padding: EdgeInsets.fromLTRB(gutter, DsSpace.s12, gutter, DsSpace.s32),
          children: [
            for (final block in blocks)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.s12),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _cookiePageMaxWidth),
                    child: SizedBox(width: double.infinity, child: block),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The status card: the platform, the same sentence the list's row reads
  /// out in the same ink, and "重新核验" for a login the platform can be
  /// asked about.
  Widget _statusCard(Translations t, {required AccountSnapshot snapshot, required AccountStatus status, required bool recheck}) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final credential = ref.read(accountsProvider).credentials[_siteId];
    final avatar = credential?.avatar;
    final name = _displayName;
    // Douyu has a fuller one-line read of its login (session, end, renewal);
    // every other platform's card carries the row's own sentence.
    final line = _isDouyu ? douyuSummary(snapshot, t, now: DateTime.now()) : status.text;
    return DsCard(
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.s16),
        child: Row(
          children: [
            if (avatar != null && avatar.isNotEmpty)
              DsAvatar(image: cachedImage(avatar), initials: name, semanticLabel: name)
            else
              localizedSiteIcon(_site, size: 36) ?? const DsIcon(DsIcons.userRound, size: 36),
            const SizedBox(width: DsSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.typography.heading.copyWith(color: colors.text)),
                  const SizedBox(height: DsSpace.s3),
                  Text(
                    line,
                    key: const ValueKey('account-status-text'),
                    style: theme.typography.small.copyWith(color: accountToneColor(colors, status.tone), height: 1.45),
                  ),
                ],
              ),
            ),
            if (recheck) ...[
              const SizedBox(width: DsSpace.s8),
              DsButton(
                key: const ValueKey('account-recheck'),
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: _verifyStored,
                leading: const DsIcon(DsIcons.refreshCw),
                child: Text(t.account.recheck),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The instructions: where the cookie comes from and the site to copy it
  /// off, in the app's own browser.
  Widget _howTo(Translations t) {
    final theme = DsTheme.of(context);
    return DsAlert(
      title: Text(t.account.cookieHowToTitle),
      description: Text(t.account.cookieDialogHint, style: theme.typography.small.copyWith(height: 1.5)),
      action: DsButton(
        key: const ValueKey('account-open-website'),
        variant: DsButtonVariant.ghost,
        size: DsSize.sm,
        onPressed: () => unawaited(_openWebsite()),
        leading: const DsIcon(DsIcons.externalLink),
        child: Text(t.account.openSiteWebsite(site: _displayName)),
      ),
    );
  }

  /// The cookie box and its row of actions: paste, clear and save, with the
  /// scan entry beside them for a platform that also signs in by QR.
  Widget _cookieGroup(Translations t, {required bool qrLogin}) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsCard(
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.s16),
        child: Column(
          key: const ValueKey('account-cookie-group'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [
            Text(t.account.cookieSection, style: theme.typography.fieldLabel.copyWith(color: colors.textSubtle)),
            DsTextField.multiline(
              key: const ValueKey('account-cookie-input'),
              controller: _cookie,
              placeholder: t.account.cookieFieldHint,
              semanticLabel: t.account.cookieFieldHint,
              enabled: !_busy,
              error: _error != null,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              enableSuggestions: false,
            ),
            if (_error case final error?)
              Text(
                key: const ValueKey('account-cookie-error'),
                error,
                style: theme.typography.small.copyWith(color: colors.danger.text, height: 1.45),
              ),
            Wrap(
              spacing: DsSpace.s8,
              runSpacing: DsSpace.s8,
              children: [
                DsButton(
                  key: const ValueKey('account-cookie-paste'),
                  variant: DsButtonVariant.secondary,
                  onPressed: _busy ? null : () => unawaited(_paste()),
                  leading: const DsIcon(DsIcons.clipboardPaste),
                  child: Text(t.account.paste),
                ),
                DsButton(
                  key: const ValueKey('account-cookie-clear-input'),
                  variant: DsButtonVariant.secondary,
                  onPressed: _busy ? null : _cookie.clear,
                  leading: const DsIcon(DsIcons.eraser),
                  child: Text(t.account.clearInput),
                ),
                if (qrLogin)
                  DsButton(
                    key: const ValueKey('account-cookie-qr'),
                    variant: DsButtonVariant.tinted,
                    onPressed: _busy ? null : () => unawaited(_qrLogin()),
                    leading: const DsIcon(DsIcons.qrCode),
                    child: Text(t.account.qrLogin),
                  ),
                DsButton(
                  key: const ValueKey('account-cookie-save'),
                  // The page's one primary action, and only ever for text that
                  // differs from what is stored.
                  onPressed: _busy || !_dirty ? null : () => unawaited(_save()),
                  loading: _busy,
                  leading: _busy ? null : const DsIcon(DsIcons.save),
                  child: Text(t.common.save),
                ),
              ],
            ),
            Text(t.account.cookieSaveShortcut, style: theme.typography.caption.copyWith(color: colors.textMuted)),
            // Douyu's session is kept alive by the renewal that rides on the
            // same cookie: its two values and switch sit in this card rather
            // than in a second one, so the page reads one login, not two.
            if (_isDouyu) ...[DsLine(color: colors.border), _douyuRenewal(t)],
          ],
        ),
      ),
    );
  }

  /// Bilibili's remembered sign-ins, and the ways to another one: switch to
  /// one, drop one, or scan a new account in. The current login is not one of
  /// the group's buttons — it is left with the page's own 退出登录, which also
  /// forgets its remembered copy.
  Widget _bilibiliAccountsGroup(Translations t, {required AccountSnapshot snapshot}) {
    return BilibiliAccountsGroup(
      accounts: ref.watch(bilibiliAccountsProvider),
      isCurrent: (account) => isCurrentBilibiliAccount(account, snapshot.credential),
      busy: _accountsBusy,
      onSwitch: (account) => unawaited(_switchBilibiliAccount(account)),
      onForget: (account) => unawaited(_forgetBilibiliAccount(account)),
      onAdd: () => unawaited(_addBilibiliAccount()),
    );
  }

  /// Makes a remembered sign-in the current one, asking first: the rooms being
  /// watched reconnect with the account it switches to. The cookie goes
  /// through the same door a paste does, so one the platform says signs in
  /// nobody is refused rather than stored — and stays remembered for another
  /// try or a fresh scan.
  Future<void> _switchBilibiliAccount(BilibiliAccount account) async {
    if (_accountsBusy || _busy) return;
    final t = context.t;
    final name = bilibiliAccountLabel(account, t);
    final confirmed = await showDsConfirm(
      context: context,
      title: t.account.switchTitle,
      description: t.account.switchConfirmDesc(name: name),
      confirmLabel: t.account.switchAccount,
    );
    if (!confirmed || !mounted) return;
    setState(() => _accountsBusy = true);
    final failure = await ref.read(accountsProvider.notifier).switchBilibiliAccount(account.uid);
    if (!mounted) return;
    setState(() => _accountsBusy = false);
    if (failure != null) {
      final message = signInFailureText(failure);
      setState(() => _error = message);
      showDsToast(context: context, title: message, status: DsStatus.danger);
      return;
    }
    showDsToast(context: context, title: t.account.switchedSuccess(name: name));
  }

  /// Forgets one remembered sign-in, asking first. The current login keeps
  /// running: only the copy in the roster leaves the device.
  Future<void> _forgetBilibiliAccount(BilibiliAccount account) async {
    if (_accountsBusy || _busy) return;
    final t = context.t;
    final name = bilibiliAccountLabel(account, t);
    final confirmed = await showDsConfirm(
      context: context,
      title: t.account.forgetTitle,
      description: t.account.forgetConfirmDesc(name: name),
      confirmLabel: t.common.delete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _accountsBusy = true);
    final failure = await ref.read(accountsProvider.notifier).forgetBilibiliAccount(account.uid);
    if (!mounted) return;
    setState(() => _accountsBusy = false);
    if (failure != null) {
      showDsToast(context: context, title: t.account.accountsSaveFailed, status: DsStatus.danger);
      return;
    }
    showDsToast(context: context, title: t.account.forgottenSuccess(name: name));
  }

  /// Signs another account in with the QR code, the way the reference's add row
  /// does. Past the limit the viewer is asked first, because the newest login
  /// takes the slot of the account used longest ago — said, never silently
  /// dropped.
  Future<void> _addBilibiliAccount() async {
    if (_accountsBusy || _busy) return;
    final site = _site;
    final auth = _auth;
    if (site == null || auth == null) return;
    final t = context.t;
    if (ref.read(bilibiliAccountsProvider).length >= bilibiliAccountLimit) {
      final confirmed = await showDsConfirm(
        context: context,
        title: t.account.addAccount,
        description: t.account.addFullConfirmDesc(count: '$bilibiliAccountLimit'),
        confirmLabel: t.account.addAccount,
      );
      if (!confirmed || !mounted) return;
    }
    final exit = await showQrLoginDialog(context, site: site, auth: auth, onSignedIn: _toastSignedIn);
    if (!mounted || exit == AccountQrExit.closed) return;
    await showAccountSignInAlternative(context, siteId: site.manifest.id, exit: exit);
  }

  /// The red sign-out under the box, once a login is stored.
  Widget _signOutRow(Translations t) {
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.s4),
      child: Align(
        child: DsButton(
          key: const ValueKey('account-cookie-sign-out'),
          variant: DsButtonVariant.dangerSoft,
          onPressed: _busy ? null : () => unawaited(_signOut()),
          leading: const DsIcon(DsIcons.logOut),
          child: Text(t.account.signOut),
        ),
      ),
    );
  }

  /// The note every account page ends on.
  Widget _privacy(Translations t) {
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s4, DsSpace.s8, DsSpace.s4, 0),
      child: Text(
        t.account.cookiePrivacy,
        style: theme.typography.caption.copyWith(color: theme.colors.textMuted, height: 1.5),
      ),
    );
  }

  /// The platform's display name, as the site registry spells it.
  String get _displayName {
    final site = _site;
    return site == null ? _siteId : localizedSiteName(site);
  }

  void _onTextChanged() {
    // A pasted passport cookie carries the renewal pair; its fields copy into
    // their own boxes and never empty them (a page cookie has neither).
    if (_isDouyu) _absorbPasted();
    _recomputeDirty();
  }

  void _onPairChanged() {
    if (!mounted) return;
    _recomputeDirty();
  }

  /// Copies `LTP0` and `dy_did` out of the cookie box into their own fields;
  /// never overwrites a filled field with nothing, so a page cookie (which has
  /// neither) leaves a stored pair intact.
  void _absorbPasted() {
    final text = _cookie.text;
    if (text.trim().isEmpty) return;
    final ltp0 = DouyuAccount.cookieField(cleanPastedCookie(text), DouyuAccount.longTermKeyName);
    if (ltp0 != null && ltp0 != _ltp0.text) _ltp0.text = ltp0;
    final did = DouyuAccount.cookieField(cleanPastedCookie(text), DouyuAccount.deviceIdName);
    if (did != null && did != _did.text) _did.text = did;
  }

  /// Recomputes the unsaved flag from the cookie box and, for douyu, the pair
  /// boxes against what the vault holds; clears any stale error.
  void _recomputeDirty() {
    if (!mounted) return;
    final cookieChanged = cleanPastedCookie(_cookie.text) != _saved;
    final pairChanged = _isDouyu &&
        (_cleanValue(_ltp0.text) != _savedPair.ltp0 || _cleanValue(_did.text) != _savedPair.did);
    final dirty = cookieChanged || pairChanged;
    if (dirty == _dirty && _error == null) return;
    setState(() {
      _dirty = dirty;
      _error = null;
    });
  }

  /// A box's value as it is stored: normalised, or null when blank.
  static String? _cleanValue(String text) {
    final value = DouyuAccount.normalizeCookie(text);
    return value.isEmpty ? null : value;
  }

  /// Puts [cookie] into the box as the stored value, so the page stops
  /// counting it as a change.
  void _markSaved(String cookie) {
    _saved = cookie;
    if (_cookie.text != cookie) {
      _cookie.value = TextEditingValue(
        text: cookie,
        selection: TextSelection.collapsed(offset: cookie.length),
      );
    }
    if (_isDouyu) {
      // The boxes now read as stored: the pair taken from them is saved.
      _savedPair = (ltp0: _cleanValue(_ltp0.text) ?? '', did: _cleanValue(_did.text) ?? '');
    }
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _error = null;
    });
  }

  /// Follows the vault: a login that appeared, changed or left while the page
  /// was open (a QR sign-in, a sign-out from the list) goes into the box and,
  /// for a platform asked online, is judged again. The viewer's own unsaved
  /// text wins, so a sign-in elsewhere never eats a paste in progress.
  void _adopt(AccountsState state) {
    if (!state.ready) return;
    final cookie = accountCookieLine(state.credentials[_siteId]);
    if (cookie == _saved || _dirty) return;
    _checkRun++;
    _saved = cookie;
    _cookie.value = TextEditingValue(
      text: cookie,
      selection: TextSelection.collapsed(offset: cookie.length),
    );
    // Douyu follows its renewal pair and save time too, so a login renewed by
    // playback (or signed out elsewhere) reads back into the boxes.
    if (_isDouyu) {
      final renewal = ref.read(douyuRenewalProvider);
      _savedPair = (ltp0: renewal.ltp0 ?? '', did: renewal.did ?? '');
      _ltp0.text = _savedPair.ltp0;
      _did.text = _savedPair.did;
    }
    final checking = _verifiesOnline && cookie.isNotEmpty;
    setState(() {
      _error = null;
      _check = checking ? const AccountChecking() : null;
    });
    if (checking) unawaited(_runVerify(_checkRun));
  }

  /// Asks the platform who its stored login signs in.
  void _verifyStored() {
    final auth = _auth;
    if (auth == null || !auth.canVerifyOnline) return;
    setState(() => _check = const AccountChecking());
    unawaited(_runVerify(++_checkRun));
  }

  Future<void> _runVerify(int run) async {
    final auth = _auth;
    if (auth == null) return;
    final check = await _ask(auth);
    if (!mounted || run != _checkRun) return;
    setState(() => _check = check);
  }

  /// Who [auth] says its applied login belongs to: the platform's own refusal
  /// is a rejected credential, anything else a question it could not answer.
  Future<AccountCheck> _ask(LiveAuthCapability auth) async {
    try {
      final account = await auth.fetchAccount();
      return AccountVerified(account.nickname ?? account.userId ?? account.siteId);
    } on Object catch (error) {
      return accountCheckFailure(error);
    }
  }

  /// Keeps the pasted cookie.
  ///
  /// A platform the app can ask is asked *first*: the paste goes through
  /// `applyPastedCookie`, which is the platform's own answer about it, and
  /// only what the platform accepts is applied and stored. A refusal stores
  /// nothing and puts the card back where it was; the text stays in the box
  /// for the viewer to fix. A platform that judges its login out of the
  /// cookie's own fields is stored as it came in.
  Future<void> _save() async {
    if (_busy || !_dirty) return;
    if (_isDouyu) {
      await _saveDouyu();
      return;
    }
    final t = context.t;
    final cookie = cleanPastedCookie(_cookie.text);
    if (cookie.isEmpty) {
      // Nothing left in the box is not an empty login but the end of one.
      if (accountStored(accountSnapshotOf(ref.read(accountsProvider), _siteId))) await _signOut();
      return;
    }
    if (!looksLikeCookie(cookie)) {
      setState(() => _error = t.account.cookieInvalid);
      return;
    }
    final auth = _auth;
    if (auth == null) {
      setState(() => _error = t.account.noLoginMethod(site: _displayName));
      return;
    }
    final verifies = _verifiesOnline;
    final previous = _check;
    final run = ++_checkRun;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      if (verifies) _check = const AccountChecking();
    });
    final failure = await ref.read(accountsProvider.notifier).signInWithCookie(_siteId, cookie);
    if (!mounted) return;
    if (failure == null) {
      // The vault holds what was accepted, in its own spelling; the box shows
      // that, so the page reads as saved.
      final state = ref.read(accountsProvider);
      final credential = state.credentials[_siteId];
      final storedLine = accountCookieLine(credential);
      final name = credential?.nickname ?? credential?.userId;
      setState(() {
        _busy = false;
        if (verifies) _check = name == null ? const AccountCheckFailed() : AccountVerified(name);
      });
      _markSaved(storedLine.isEmpty ? cookie : storedLine);
      showDsToast(
        context: context,
        title: verifies && name != null ? t.account.cookieSavedAs(name: name) : t.account.cookieSavedLocal,
      );
      return;
    }
    final rejected = verifies && accountCheckFailure(failure) is AccountRejected;
    final message = rejected ? t.account.cookieRejected : signInFailureText(failure);
    setState(() {
      _busy = false;
      // Back to what the card said: the refused paste changed nothing.
      if (verifies && run == _checkRun) _check = previous;
      _error = message;
    });
    showDsToast(context: context, title: message, status: DsStatus.danger);
  }

  Future<void> _signOut() async {
    if (_busy) return;
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.account.signOut,
      description: t.account.signOutConfirmDesc(site: _displayName),
      confirmLabel: t.common.confirm,
      destructive: true,
    );
    if (!confirmed) return;
    if (!mounted) return;
    _checkRun++;
    setState(() => _busy = true);
    try {
      await ref.read(accountsProvider.notifier).signOut(_siteId);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      showDsToast(context: context, title: context.t.account.signOutFailed, status: DsStatus.danger);
      return;
    }
    if (!mounted) return;
    // The vault drops the cookie, douyu's pair and the save time together;
    // the boxes follow so nothing left typed reads as still stored.
    if (_isDouyu) {
      _ltp0.text = '';
      _did.text = '';
    }
    setState(() {
      _busy = false;
      _check = null;
    });
    _markSaved('');
    showDsToast(context: context, title: context.t.account.signOutSuccess);
  }

  /// Keeps a douyu paste. The login cookie and the renewal pair are stored
  /// apart, and the two are not interchangeable (3.x's controller): the box
  /// takes either cookie, but only a cookie with a session token becomes the
  /// login.
  ///
  /// A cookie from the passport request is never kept as a login — its fields
  /// would make the play edge answer 403 — so pasting it copies only `LTP0`
  /// and `dy_did` into the pair and leaves a stored login exactly as it was.
  /// The login's save time moves only when the login itself changes, so the
  /// seven-day clock is not reset by a pair-only update.
  Future<void> _saveDouyu() async {
    final t = context.t;
    final repository = ref.read(accountRepositoryProvider).value;
    final auth = _auth;
    if (repository == null || auth == null) {
      setState(() => _error = t.account.noLoginMethod(site: _displayName));
      return;
    }
    final pasted = DouyuAccount.normalizeCookie(cleanPastedCookie(_cookie.text));
    final stored = _saved;
    final pastedIsSession = DouyuAccount.sessionToken(pasted) != null;
    final storedIsSession = DouyuAccount.sessionToken(stored) != null;
    final ltp0 = _cleanValue(_ltp0.text);
    final did = _cleanValue(_did.text);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    // The passport request's cookie: keep the pair, keep the login.
    if (!pastedIsSession && DouyuAccount.isPassportCookie(pasted)) {
      await repository.saveDouyuPair(ltp0: ltp0, did: did);
      if (!mounted) return;
      setState(() => _busy = false);
      _markSaved(stored);
      showDsToast(
        context: context,
        title: storedIsSession ? t.account.douyuCredentialsAbsorbed : t.account.douyuCredentialsOnly,
      );
      return;
    }

    // A cookie with no session token beside a stored login brings only the
    // pair; with no login beside it there is nothing to keep as a login.
    final keep = storedIsSession && !pastedIsSession;
    final effective = keep ? stored : pasted;
    if (effective.isEmpty) {
      await repository.saveDouyuPair(ltp0: ltp0, did: did);
      if (!mounted) return;
      setState(() => _busy = false);
      _markSaved('');
      showDsToast(context: context, title: t.account.douyuCredentialsOnly);
      return;
    }

    // The login is a session cookie: the site verifies and applies it.
    final failure = await ref.read(accountsProvider.notifier).signInWithCookie(_siteId, effective);
    if (!mounted) return;
    if (failure != null) {
      final message = signInFailureText(failure);
      setState(() {
        _busy = false;
        _error = message;
      });
      showDsToast(context: context, title: message, status: DsStatus.danger);
      return;
    }
    // The pair rides beside the login; the save time starts only on a real
    // login change.
    await repository.saveDouyuPair(ltp0: ltp0, did: did);
    final changed = effective != stored;
    if (changed) await ref.read(douyuCookieSavedAtProvider.notifier).markSaved();
    if (!mounted) return;
    final storedLine = accountCookieLine(ref.read(accountsProvider).credentials[_siteId]);
    setState(() => _busy = false);
    _markSaved(storedLine.isEmpty ? effective : storedLine);
    showDsToast(
      context: context,
      title: changed ? t.account.cookieSavedLocal : t.account.douyuCredentialsAbsorbed,
    );
  }

  /// Renews the login now (3.x's `refreshNow`): proves the pair works instead
  /// of waiting up to a week to find out. The button means "use these values",
  /// so the box's cookie and pair are stored first, then the site's own
  /// renewal runs against them and writes the new login back through the
  /// store's `saveRenewed`.
  Future<void> _renewNow() async {
    if (_renewing || _busy) return;
    final t = context.t;
    final repository = ref.read(accountRepositoryProvider).value;
    final cookie = DouyuAccount.normalizeCookie(cleanPastedCookie(_cookie.text));
    if (cookie.isEmpty) {
      showDsToast(context: context, title: t.account.douyuRenewNoCookie, status: DsStatus.warning);
      return;
    }
    final credentials = DouyuAccount.renewalCredentials(
      cookie,
      typedLtp0: _ltp0.text,
      typedDid: _did.text,
      storedLtp0: repository?.douyuLtp0(),
      storedDid: repository?.douyuDid(),
    );
    final ltp0 = credentials.ltp0;
    final did = credentials.did;
    if (ltp0 == null || did == null) {
      showDsToast(context: context, title: t.account.douyuRenewNoCredentials, status: DsStatus.warning);
      return;
    }
    if (DouyuAccount.sessionToken(cookie) == null) {
      showDsToast(context: context, title: t.account.douyuRenewNoSession, status: DsStatus.warning);
      return;
    }
    final site = _site;
    if (site is! DouyuSite) {
      showDsToast(context: context, title: t.account.noLoginMethod(site: _displayName), status: DsStatus.danger);
      return;
    }
    final before = accountCookieLine(ref.read(accountsProvider).credentials[_siteId]);
    setState(() => _renewing = true);
    try {
      await repository?.saveDouyuPair(ltp0: ltp0, did: did);
      await ref.read(accountsProvider.notifier).signInWithCookie(_siteId, cookie);
      await site.renewLogin(force: true);
      if (!mounted) return;
      final after = accountCookieLine(ref.read(accountsProvider).credentials[_siteId]);
      // No new login came back (nothing was due, or the passport stayed
      // silent), so the save time must not pretend the session moved.
      if (after.isEmpty || after == before) {
        setState(() => _renewing = false);
        showDsToast(context: context, title: t.account.douyuRenewNoChange, status: DsStatus.warning);
        return;
      }
      final renewal = ref.read(douyuRenewalProvider);
      final expiry = DouyuAccount.sessionExpiry(after, savedAt: renewal.savedAt) ??
          (renewal.savedAt ?? DateTime.now()).add(DouyuAccount.webCookieLifetime);
      setState(() => _renewing = false);
      _markSaved(after);
      showDsToast(context: context, title: t.account.douyuRenewOk(time: accountTime(expiry)));
    } on Object {
      if (!mounted) return;
      setState(() => _renewing = false);
      showDsToast(context: context, title: t.account.douyuRenewFailed, status: DsStatus.danger);
    }
  }

  /// The douyu-only part of the cookie card: the two values the renewal
  /// reads (kept apart from the login), the "renew now" button and the
  /// "force renewal" switch — the only place the switch lives now.
  Widget _douyuRenewal(Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final enabled = !_busy && !_renewing;
    final forceRenew = ref.watch(douyuForceRenewProvider);
    return Column(
      key: const ValueKey('douyu-renewal-group'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        Text(t.account.douyuRenewalTitle, style: theme.typography.fieldLabel.copyWith(color: colors.textSubtle)),
        Text(t.account.douyuLtp0Label, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        DsTextField(
          key: const ValueKey('douyu-ltp0-input'),
          controller: _ltp0,
          placeholder: t.account.douyuLtp0Hint,
          semanticLabel: t.account.douyuLtp0Label,
          enabled: enabled,
          autocorrect: false,
          enableSuggestions: false,
        ),
        Text(t.account.douyuDidLabel, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        DsTextField(
          key: const ValueKey('douyu-did-input'),
          controller: _did,
          placeholder: t.account.douyuDidHint,
          semanticLabel: t.account.douyuDidLabel,
          enabled: enabled,
          autocorrect: false,
          enableSuggestions: false,
        ),
        Row(
          children: [
            DsButton(
              key: const ValueKey('douyu-renew-now'),
              variant: DsButtonVariant.secondary,
              onPressed: enabled ? () => unawaited(_renewNow()) : null,
              loading: _renewing,
              leading: _renewing ? null : const DsIcon(DsIcons.refreshCw),
              child: Text(t.account.douyuRenewNow),
            ),
            const SizedBox(width: DsSpace.s12),
            Expanded(
              child: Text(
                t.account.douyuRenewNowDesc,
                style: theme.typography.caption.copyWith(color: colors.textMuted, height: 1.45),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.settings.douyuForceRenew, style: theme.typography.small.copyWith(color: colors.text)),
                  const SizedBox(height: DsSpace.s3),
                  Text(
                    t.settings.douyuForceRenewDesc,
                    style: theme.typography.caption.copyWith(color: colors.textMuted, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DsSpace.s12),
            DsSwitch(
              key: const ValueKey('douyu-force-renew'),
              value: forceRenew,
              semanticLabel: t.settings.douyuForceRenew,
              onChanged: (value) => unawaited(ref.read(douyuForceRenewProvider.notifier).set(value: value)),
            ),
          ],
        ),
      ],
    );
  }

  /// Drops the store's cookie into the box and asks about it again — what a
  /// QR sign-in that landed here leaves behind.
  Future<void> _qrLogin() async {
    final site = _site;
    final auth = _auth;
    if (site == null || auth == null) return;
    // The dialog's own sign-in writes through the account store, and the
    // listener above moves the result into this page. A viewer who instead
    // asks for the web sign-in gets the browser; asking for the cookie is the
    // page this dialog was opened from, so there is nothing to open.
    final exit = await showQrLoginDialog(context, site: site, auth: auth, onSignedIn: _toastSignedIn);
    if (!mounted || exit != AccountQrExit.webLogin) return;
    await showAccountSignInAlternative(context, siteId: site.manifest.id, exit: exit);
  }

  void _toastSignedIn() {
    if (!mounted) return;
    showDsToast(context: context, title: context.t.account.loginSuccess);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = cleanPastedCookie(data?.text ?? '');
    if (text.isEmpty) {
      showDsToast(context: context, title: context.t.account.clipboardEmpty);
      return;
    }
    _cookie.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _openWebsite() async {
    final opened = await launchUrl(widget.platform.website, mode: LaunchMode.externalApplication);
    if (!mounted || opened) return;
    showDsToast(context: context, title: context.t.account.browserNotOpened, status: DsStatus.warning);
  }

  /// The one way out of a page whose text was never saved: asked, then
  /// dropped — with the flag cleared first so the pop itself is not stopped
  /// a second time.
  Future<void> _confirmDiscard() async {
    if (_confirmingDiscard) return;
    _confirmingDiscard = true;
    final t = context.t;
    final discard = await showDsConfirm(
      context: context,
      title: t.account.discardTitle,
      description: t.account.discardDesc,
      confirmLabel: t.account.discard,
      cancelLabel: t.account.keepEditing,
      destructive: true,
    );
    _confirmingDiscard = false;
    if (!discard) return;
    if (!mounted) return;
    setState(() => _dirty = false);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await Navigator.of(context).maybePop();
  }
}
