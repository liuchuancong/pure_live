import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/cookie_value.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';

class DouyuCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();

  /// The long-term key and device id from the passport request.
  ///
  /// They live next to the cookie rather than inside it: `www.douyu.com` never
  /// hands them out with the page cookie, so the viewer copies them from the
  /// `passport.douyu.com` request separately — and they are what makes the
  /// cookie renew itself instead of expiring after seven days.
  final TextEditingController ltp0Controller = TextEditingController();
  final TextEditingController didController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    final cookies = SettingsService.to.cookieManager;
    cookieController.text = cookies.douyuCookie.v;
    ltp0Controller.text = cookies.douyuLtp0.v;
    didController.text = cookies.douyuDid.v;

    // A cookie pasted from the passport request already contains the renewal
    // key and the device id; filling the two fields from what was pasted saves
    // the viewer from hunting through the same string by hand.
    cookieController.addListener(_absorbPastedCredentials);
    _absorbPastedCredentials();
  }

  /// Copies `LTP0` / `dy_did` out of the pasted cookie into their fields.
  ///
  /// Only fills what it actually finds, and never clears a field: a page cookie
  /// legitimately has neither, and wiping a value the viewer typed earlier would
  /// silently disable the renewal.
  void _absorbPastedCredentials() {
    final pasted = cookieController.text;
    if (pasted.trim().isEmpty) return;

    final ltp0 = _fieldOf(pasted, DouyuUtils.longTermTokenName);
    if (ltp0 != null && ltp0 != ltp0Controller.text) {
      ltp0Controller.text = ltp0;
    }

    final did = _fieldOf(pasted, DouyuUtils.deviceIdName);
    if (did != null && did != didController.text) {
      didController.text = did;
    }
  }

  /// Reads one field, tolerating a whole `Cookie: a=b; c=d` header line.
  static String? _fieldOf(String cookie, String name) {
    final header = cookie.replaceFirst(RegExp(r'^\s*Cookie:\s*', caseSensitive: false), '');
    final value = DouyuUtils.cookieField(header, name)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  void setCookie(String cookie) {
    final normalized = normalizeAccountCookie(cookie);
    final cookies = SettingsService.to.cookieManager;

    // The box accepts either cookie, and they are not interchangeable: the page
    // cookie carries `dy_auth` (the login) while the passport cookie carries
    // LTP0/dy_did (the ability to renew it). Pasting the passport one must not
    // replace a stored login — that would sign the viewer out while looking like
    // it added something.
    final stored = cookies.douyuCookie.v;
    final pastedIsSession = DouyuUtils.sessionToken(normalized) != null;
    final keepsStoredSession = !pastedIsSession && stored.isNotEmpty && DouyuUtils.sessionToken(stored) != null;
    final effective = keepsStoredSession ? stored : normalized;

    cookieController.text = effective;
    cookies.douyuCookie.v = effective;
    cookies.douyuLtp0.v = ltp0Controller.text.trim();
    cookies.douyuDid.v = didController.text.trim();
    // douyu.com issues `dy_auth` for seven days and the header the viewer pasted
    // does not carry that deadline: recording the moment is the only way to know
    // when to renew it.
    cookies.douyuCookieSavedAt.v =
        effective.isEmpty ? 0 : DateTime.now().millisecondsSinceEpoch ~/ 1000;

    ToastUtil.show(
      keepsStoredSession ? i18n('douyu_cookie_credentials_absorbed') : _sessionSummary(effective),
    );
  }

  /// Renews the cookie with the long-term key, right now.
  ///
  /// Playback renews on its own inside the seven-day window; this exists so the
  /// viewer can check that the pasted LTP0 and dy_did actually work instead of
  /// waiting up to a week to find out.
  Future<void> refreshNow() async {
    final cookie = normalizeAccountCookie(cookieController.text);
    if (cookie.isEmpty) {
      ToastUtil.show(i18n('douyu_cookie_refresh_no_cookie'));
      return;
    }

    final credentials = DouyuUtils.refreshCredentials(
      cookie,
      longTerm: ltp0Controller.text,
      did: didController.text,
    );
    if (credentials.longTerm == null || credentials.did == null) {
      ToastUtil.show(i18n('douyu_cookie_refresh_no_credentials'));
      return;
    }

    if (DouyuUtils.sessionToken(cookie) == null) {
      ToastUtil.show(i18n('douyu_cookie_refresh_no_session'));
      return;
    }

    // Persist what was typed first: the renewal reads the stored pair, and the
    // viewer pressing this button means "use these values".
    SettingsService.to.cookieManager.douyuLtp0.v = credentials.longTerm!;
    SettingsService.to.cookieManager.douyuDid.v = credentials.did!;

    final renewed = await DouyuUtils.refreshSession(
      accountCookie: cookie,
      longTerm: credentials.longTerm,
      did: credentials.did,
      force: true,
    );

    if (renewed == null) {
      ToastUtil.show(i18n('douyu_cookie_refresh_no_change'));
      return;
    }

    cookieController.text = renewed;
    ToastUtil.show(i18n('douyu_cookie_refresh_ok', args: {'time': _refreshedAtLabel()}));
  }

  String _refreshedAtLabel() {
    final seconds = SettingsService.to.cookieManager.douyuCookieSavedAt.v;
    final savedAt = seconds > 0 ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000) : DateTime.now();
    return _formatExpiry(savedAt.add(DouyuUtils.webCookieLifetime));
  }

  /// Says what the pasted cookie is actually worth.
  ///
  /// A cookie that is present but expired (or that never carried a session
  /// token) looks identical to a working one in the editor, and the difference
  /// only shows up later as "why is this room a guest room".
  String _sessionSummary(String cookie) {
    final state = DouyuUtils.sessionState(cookie);
    final expiry = DouyuUtils.sessionExpiry(cookie);
    final at = expiry == null ? '' : _formatExpiry(expiry);

    return switch (state) {
      DouyuSessionState.none => i18n('douyu_cookie_cleared'),
      DouyuSessionState.guest => i18n('douyu_cookie_guest'),
      // The web cookie's token is opaque: its end comes from the recorded save
      // time and Douyu's seven-day rule, so say that instead of a bare expiry.
      DouyuSessionState.valid => expiry == null
          ? i18n('douyu_cookie_valid_no_expiry')
          : DouyuUtils.canRefreshSession(cookie)
              ? i18n('douyu_cookie_valid_auto_renew', args: {'time': at})
              : i18n('douyu_cookie_valid_needs_repaste', args: {'time': at}),
      DouyuSessionState.expiredRefreshable => i18n('douyu_cookie_expired_refreshable', args: {'time': at}),
      DouyuSessionState.expired => i18n('douyu_cookie_expired', args: {'time': at}),
    };
  }

  String _formatExpiry(DateTime expiry) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${expiry.year}-${two(expiry.month)}-${two(expiry.day)} ${two(expiry.hour)}:${two(expiry.minute)}';
  }

  @override
  void onClose() {
    cookieController.removeListener(_absorbPastedCredentials);
    cookieController.dispose();
    ltp0Controller.dispose();
    didController.dispose();
    super.onClose();
  }
}
