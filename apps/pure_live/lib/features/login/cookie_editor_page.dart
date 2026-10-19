import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show DouyuAccount, DouyuSessionState, DouyuSite;
import 'package:pure_live/app/providers/app_providers.dart' show sitesProvider;
import 'package:pure_live/features/login/account_roster.dart' show RememberedAccountsGroup;
import 'package:pure_live/features/login/account_state.dart';
import 'package:pure_live/features/login/douyu_login_store.dart';
import 'package:pure_live/features/login/login_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:url_launcher/url_launcher.dart';

/// The per-platform cookie editor (the reference's `CookieEditorScaffold` +
/// `platform_cookie_view`, one page per sign-in site): the stored login's
/// status card, the how-to-get-a-cookie tip with the site's own website
/// button, the Cookie group (paste / clear / verify-before-save), the
/// sign-out and the privacy note.
///
/// Saving asks the platform first — [cookiePasteProvider] runs the site's
/// `applyPastedCookie`, and only a granted credential is stored and applied
/// (the reference's 正在核验并保存). Text without a `name=value` field is
/// refused before the check; leaving with unsaved text asks first; Ctrl/S
/// (Cmd/S) saves.
final class CookieEditorPage extends ConsumerStatefulWidget {
  /// The editor of the site [siteId].
  const new({required this.siteId, super.key});

  /// The platform whose cookie is edited (`douyu`, `huya`, …).
  final String siteId;

  @override
  ConsumerState<CookieEditorPage> createState() => _CookieEditorPageState();
}

final class _CookieEditorPageState extends ConsumerState<CookieEditorPage> {
  final TextEditingController _cookie = TextEditingController();
  late final TextEditingController? _ltp0 = widget.siteId == 'douyu' ? TextEditingController() : null;
  late final TextEditingController? _did = widget.siteId == 'douyu' ? TextEditingController() : null;
  bool _dirty = false;
  bool _seeded = false;
  bool _renewing = false;
  String? _error;
  String _savedText = '';
  String _savedLtp0 = '';
  String _savedDid = '';

  bool get _isDouyu => widget.siteId == 'douyu';

  @override
  void dispose() {
    _cookie.dispose();
    _ltp0?.dispose();
    _did?.dispose();
    super.dispose();
  }

  /// Puts the stored credential's cookies (and Douyu's renewal pair) into
  /// the boxes once, when the account first answers — the reference prefilled
  /// the pasted cookie, and the LTP0 pair from the store it renews through.
  void _seed() {
    if (_seeded) {
      return;
    }
    _seeded = true;
    final store = ref.read(douyuLoginStoreProvider);
    final credential = ref.read(accountProvider(widget.siteId));
    final header = _isDouyu && (store?.cookie ?? '').isNotEmpty ? store!.cookie : credential == null ? '' : cookieHeaderOf(credential);
    if (header.isNotEmpty) {
      _savedText = header;
      _cookie.value = TextEditingValue(
        text: header,
        selection: TextSelection.collapsed(offset: header.length),
      );
    }
    if (_isDouyu) {
      _savedLtp0 = store?.longTermKey ?? '';
      _savedDid = store?.deviceId ?? '';
      _ltp0?.text = _savedLtp0;
      _did?.text = _savedDid;
    }
  }

  void _changed([String? _]) {
    final dirty = cleanPastedCookie(_cookie.text) != cleanPastedCookie(_savedText) ||
        (_ltp0?.text.trim() ?? '') != _savedLtp0 ||
        (_did?.text.trim() ?? '') != _savedDid;
    if (dirty != _dirty || _error != null) {
      setState(() {
        _dirty = dirty;
        _error = null;
      });
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) {
      return;
    }
    if (text.isEmpty) {
      PureToast.show(context, context.t.account.clipboardEmpty);
      return;
    }
    _cookie.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    // Douyu's hint: the renewal pair fills itself from the pasted cookie
    // when the fields are still empty (the reference's 粘贴后自动填入).
    if (_isDouyu) {
      final ltp0Field = DouyuAccount.cookieField(cleanPastedCookie(text), DouyuAccount.longTermKeyName);
      final didField = DouyuAccount.cookieField(cleanPastedCookie(text), DouyuAccount.deviceIdName);
      if (ltp0Field != null && (_ltp0?.text.trim().isEmpty ?? true)) {
        _ltp0?.text = ltp0Field;
      }
      if (didField != null && (_did?.text.trim().isEmpty ?? true)) {
        _did?.text = didField;
      }
    }
    _changed();
  }

  /// Verify-before-store: the site's own refusal (the message is its text)
  /// lands under the box; a granted credential is adopted by the paste
  /// controller, and the card and the hub row follow the account provider.
  Future<void> _save() async {
    if (_busy) {
      return;
    }
    final cookie = cleanPastedCookie(_cookie.text);
    FocusScope.of(context).unfocus();
    if (cookie.isEmpty) {
      // Nothing left to store: that is signing out (the reference's c7).
      if (ref.read(accountProvider(widget.siteId)) != null) {
        await _signOut();
      }
      return;
    }
    if (!looksLikeCookie(cookie)) {
      setState(() => _error = context.t.account.cookieInvalid);
      return;
    }
    await ref.read(cookiePasteProvider(widget.siteId).notifier).verify(cookie);
    if (!mounted) {
      return;
    }
    final paste = ref.read(cookiePasteProvider(widget.siteId));
    if (paste.phase == CookiePastePhase.success) {
      // Douyu's renewal pair is saved with the cookie (the reference's
      // extraInputs): what the adapter renews through from now on.
      if (_isDouyu) {
        final store = ref.read(douyuLoginStoreProvider);
        await store?.saveRenewalPair(ltp0: _ltp0?.text ?? '', did: _did?.text ?? '');
        await store?.markSavedAt(DateTime.now());
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _savedText = cookie;
        _savedLtp0 = _isDouyu ? (_ltp0?.text.trim() ?? '') : '';
        _savedDid = _isDouyu ? (_did?.text.trim() ?? '') : '';
        _dirty = false;
        _error = null;
      });
      PureToast.show(
        context,
        context.t.account.signedIn(name: paste.account?.nickname ?? paste.account?.userId ?? ''),
        type: PureToastType.success,
      );
    } else if (paste.phase == CookiePastePhase.failure) {
      setState(() => _error = paste.message);
    }
  }

  bool get _busy => ref.read(cookiePasteProvider(widget.siteId)).phase == CookiePastePhase.verifying;
  Future<void> _signOut() async {
    final t = context.t;
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: t.account.signOutConfirm(site: _siteName(context)),
      child: Text(t.account.signOutHint),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: dialogContext.t.account.signOut,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (!(confirmed ?? false) || !mounted) {
      return;
    }
    await ref.read(accountProvider(widget.siteId).notifier).signOut();
    if (!mounted) {
      return;
    }
    _cookie.clear();
    setState(() {
      _savedText = '';
      _dirty = false;
      _error = null;
    });
  }

  Future<void> _confirmDiscard() async {
    final t = context.t;
    final discard = await showPureDialog<bool>(
      context: context,
      title: t.account.discardTitle,
      child: Text(t.account.discardDetail),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.account.keepEditing,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: dialogContext.t.account.discard,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (!(discard ?? false) || !mounted) {
      return;
    }
    setState(() => _dirty = false);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      await Navigator.of(context).maybePop();
    }
  }

  String _siteName(BuildContext context) {
    final site = ref.read(sitesProvider).registry.getById(widget.siteId);
    return site?.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN') ?? widget.siteId;
  }

  /// What the stored douyu login is worth (the reference's `_sessionSummary`
  /// and `douyuSessionState`): the session the cookie itself names, when it
  /// ends, and whether the saved LTP0 pair can renew it.
  AccountStatus _douyuStatus(AppDouyuLoginStore? store) {
    final t = context.t;
    final credential = ref.read(accountProvider(widget.siteId));
    final header = (store?.cookie ?? '').isNotEmpty ? store!.cookie : credential == null ? '' : cookieHeaderOf(credential);
    final credentials = DouyuAccount.renewalCredentials(
      header,
      storedLtp0: store?.longTermKey,
      storedDid: store?.deviceId,
    );
    final now = DateTime.now();
    final state = DouyuAccount.sessionState(
      header,
      now: now,
      savedAt: store?.savedAt,
      ltp0: credentials.ltp0,
      did: credentials.did,
    );
    final expiry = DouyuAccount.sessionExpiry(header, savedAt: store?.savedAt);
    final at = expiry == null ? '' : accountTimeText(expiry);
    return switch (state) {
      DouyuSessionState.none => AccountStatus(t.account.editorNoneHint),
      DouyuSessionState.guest => AccountStatus(t.account.douyuStatusGuest, tone: AccountTone.warning, signedIn: true),
      DouyuSessionState.valid when expiry == null =>
        AccountStatus(t.account.douyuStatusNoExpiry, tone: AccountTone.ok, signedIn: true),
      DouyuSessionState.valid when credentials.ltp0 != null && credentials.did != null =>
        AccountStatus(t.account.douyuStatusAutoRenew(time: at), tone: AccountTone.ok, signedIn: true),
      DouyuSessionState.valid =>
        AccountStatus(t.account.douyuStatusRepaste(time: at), tone: AccountTone.ok, signedIn: true),
      DouyuSessionState.expiredRefreshable =>
        AccountStatus(t.account.douyuStatusRenewable(time: at), tone: AccountTone.warning, signedIn: true),
      DouyuSessionState.expired => AccountStatus(t.account.douyuStatusExpired(time: at), tone: AccountTone.error, signedIn: true),
    };
  }

  /// Douyu's renewal group (the reference's `douyu_cookie_view` extras): the
  /// LTP0 / `dy_did` pair saved with the cookie and 立即续期.
  Widget _douyuCard(PureTheme theme, AppDouyuLoginStore? store, bool busy) {
    final t = context.t;
    final canRenew = store != null && store.longTermKey != null && store.deviceId != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(theme, label: t.account.douyuLtp0, hint: t.account.douyuLtp0Hint, controller: _ltp0!),
          const SizedBox(height: 10),
          _field(theme, label: t.account.douyuDid, hint: t.account.douyuDidHint, controller: _did!),
          const SizedBox(height: 12),
          PureButton(
            key: const ValueKey('douyu-renew-now'),
            label: _renewing ? t.account.savingVerifying : t.account.douyuRenew,
            icon: _renewing ? null : Icons.refresh,
            loading: _renewing,
            size: ControlSize.sm,
            variant: ButtonVariant.secondary,
            onPressed: busy || _renewing ? null : () => unawaited(_renewNow(canRenew)),
          ),
        ],
      ),
    );
  }

  /// The reference's own gate first: without the pair a renewal cannot
  /// happen at all, so the button says what to do instead of silently
  /// doing nothing.
  Future<void> _renewNow(bool canRenew) async {
    FocusScope.of(context).unfocus();
    if (!canRenew) {
      PureToast.show(context, context.t.account.douyuRenewNeedPair);
      return;
    }
    final site = ref.read(sitesProvider).registry.getById(widget.siteId);
    if (site is! DouyuSite) {
      PureToast.show(context, context.t.account.douyuRenewNeedPair);
      return;
    }
    setState(() => _renewing = true);
    try {
      await site.renewLogin(force: true);
    } on Object {
      // renewLogin never throws by contract; anything escaping it leaves
      // the stored cookie standing, exactly as its own failure path does.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _renewing = false;
      _seeded = false;
    });
    _seed();
    final store = ref.read(douyuLoginStoreProvider);
    PureToast.show(context, _douyuStatus(store).text);
  }

  /// A labelled one-line field (the reference's `AccountField`) for the
  /// renewal pair.
  Widget _field(PureTheme theme, {required String label, required String hint, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(label, style: theme.text.caption.copyWith(color: theme.colors.primary)),
        ),
        PureTextField(
          controller: controller,
          placeholder: hint,
          onChanged: (_) => _changed(),
        ),
      ],
    );
  }

  static String accountTimeText(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final name = _siteName(context);
    final credential = ref.watch(accountProvider(widget.siteId));
    _seed();
    final busy = ref.watch(cookiePasteProvider(widget.siteId)).phase == CookiePastePhase.verifying;
    final store = _isDouyu ? ref.watch(douyuLoginStoreProvider) : null;
    // What counts as a login on this page: the store's saved cookie for
    // douyu (it renews through that even beside an applied credential),
    // the applied account otherwise.
    final hasLogin = (store?.cookie ?? '').isNotEmpty || credential != null;
    final children = <Widget>[
      AccountStatusCard(
        status: _isDouyu ? _douyuStatus(store) : accountStatusFor(t, credential, now: DateTime.now()),
      ),
      // K01.2: the remembered sign-ins right under the status card (the
      // reference's accounts slot) — a switch re-adopts, the add row says
      // what a new login does.
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Text(
          t.account.savedAccounts,
          style: theme.text.bodySmall.copyWith(color: theme.colors.primary, fontWeight: FontWeight.w600),
        ),
      ),
      RememberedAccountsGroup(siteId: widget.siteId),
      const SizedBox(height: 12),
      _tip(theme, name),
      const SizedBox(height: 12),
      _cookieCard(theme, busy),
      if (_isDouyu) ...[
        const SizedBox(height: 8),
        _douyuCard(theme, store, busy),
      ],
      if (hasLogin) ...[
        const SizedBox(height: 12),
        PureButton(
          key: const ValueKey('account-cookie-sign-out'),
          label: t.account.signOut,
          icon: Icons.logout_rounded,
          variant: ButtonVariant.danger,
          onPressed: busy ? null : () => unawaited(_signOut()),
        ),
      ],
      const SizedBox(height: 12),
      Text(t.account.privacyNote, style: theme.text.caption.copyWith(color: theme.colors.textSecondary, height: 1.5)),
    ];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => unawaited(_save()),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () => unawaited(_save()),
      },
      child: PopScope<Object?>(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            unawaited(_confirmDiscard());
          }
        },
        child: PureScaffold(
          appBar: PureAppBar(title: t.account.editorTitle(name: name)),
          body: ListView(
            key: const ValueKey('account-cookie-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _tip(PureTheme theme, String name) {
    final site = ref.read(sitesProvider).registry.getById(widget.siteId);
    final homepage = site?.manifest.homepage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t.account.cookieTip, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
        if (homepage != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: PureButton(
              key: const ValueKey('account-open-website'),
              label: context.t.account.openSite(name: name),
              icon: Icons.open_in_new,
              size: ControlSize.sm,
              variant: ButtonVariant.secondary,
              onPressed: () => unawaited(launchUrl(homepage, mode: LaunchMode.externalApplication)),
            ),
          ),
      ],
    );
  }

  Widget _cookieCard(PureTheme theme, bool busy) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.account.cookieGroup, style: theme.text.bodySmall.copyWith(color: theme.colors.primary)),
          const SizedBox(height: 8),
          // The TextField is Material to the bone (minLines/maxLines and the
          // paste handle layers); a transparent Material sheet gives the
          // non-Material hosts the ancestor it asserts for.
          Material(
            type: MaterialType.transparency,
            child: TextField(
              key: const ValueKey('account-cookie-field'),
              controller: _cookie,
              minLines: 3,
              maxLines: 7,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              onChanged: (_) => _changed(),
              scrollPadding: const EdgeInsets.only(bottom: 120),
              decoration: InputDecoration(
                hintText: 'name=value; name2=value2',
                errorText: _error,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PureButton(
                key: const ValueKey('account-cookie-paste'),
                label: t.account.paste,
                icon: Icons.content_paste_go_outlined,
                size: ControlSize.sm,
                variant: ButtonVariant.secondary,
                onPressed: busy ? null : () => unawaited(_paste()),
              ),
              PureButton(
                key: const ValueKey('account-cookie-clear-input'),
                label: t.account.clearInput,
                icon: Icons.backspace_outlined,
                size: ControlSize.sm,
                variant: ButtonVariant.ghost,
                onPressed: busy
                    ? null
                    : () {
                        _cookie.clear();
                        _changed('');
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          PureButton(
            key: const ValueKey('account-cookie-save'),
            label: busy ? t.account.savingVerifying : t.common.save,
            icon: busy ? null : Icons.save_outlined,
            loading: busy,
            size: ControlSize.lg,
            onPressed: !busy && _dirty ? () => unawaited(_save()) : null,
          ),
        ],
      ),
    );
  }
}
