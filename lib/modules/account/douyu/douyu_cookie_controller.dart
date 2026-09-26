import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/cookie_value.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';

class DouyuCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = SettingsService.to.cookieManager.douyuCookie.v;
  }

  void setCookie(String cookie) {
    final normalized = normalizeAccountCookie(cookie);
    cookieController.text = normalized;
    SettingsService.to.cookieManager.douyuCookie.v = normalized;
    ToastUtil.show(_sessionSummary(normalized));
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
      DouyuSessionState.valid => i18n('douyu_cookie_valid', args: {'time': at}),
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
    cookieController.dispose();
    super.onClose();
  }
}
