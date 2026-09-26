import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/douyu/douyu_cookie_controller.dart';
import 'package:pure_live/modules/account/widgets/account_cookie_editor.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the renewal key and the device id are found.
final Uri _passportUri = Uri.parse('https://passport.douyu.com/');

/// Douyu's cookie page: the page cookie, plus the two values renewal needs.
///
/// The page cookie carries only `dy_auth`, which is good for seven days and then
/// stops being a login. `LTP0` and `dy_did` come from a different request — the
/// one to `passport.douyu.com` — and are what let the app renew the cookie by
/// itself. They are separate fields because they are separate values in the
/// browser; pasting the passport cookie into the box above fills them for you.
class DouyuCookiePage extends GetView<DouyuCookieController> {
  const DouyuCookiePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AccountCookieEditorPage(
      controller: controller.cookieController,
      hintText: i18n('douyu_cookie_hint'),
      tipText: i18n('douyu_cookie_tip'),
      onSave: controller.setCookie,
      tipBody: _DouyuCookieTip(theme: theme),
      extraFields: <Widget>[
        TextField(
          key: const ValueKey('douyu-ltp0-input'),
          controller: controller.ltp0Controller,
          style: AppTextStyles.t14,
          autocorrect: false,
          enableSuggestions: false,
          scrollPadding: const EdgeInsets.only(bottom: 120),
          decoration: accountCookieFieldDecoration(
            theme,
            labelText: i18n('douyu_ltp0_label'),
            hintText: i18n('douyu_ltp0_hint'),
          ),
        ),
        TextField(
          key: const ValueKey('douyu-did-input'),
          controller: controller.didController,
          style: AppTextStyles.t14,
          autocorrect: false,
          enableSuggestions: false,
          scrollPadding: const EdgeInsets.only(bottom: 120),
          decoration: accountCookieFieldDecoration(
            theme,
            labelText: i18n('douyu_did_label'),
            hintText: i18n('douyu_did_hint'),
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('douyu-refresh-now'),
          onPressed: controller.refreshNow,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(i18n('douyu_cookie_refresh_now')),
        ),
      ],
    );
  }
}

/// How to obtain the cookie, and where the renewal pair comes from.
///
/// Kept as steps rather than one paragraph: the two are done in different places
/// in the browser, and the passport endpoint is a link the viewer has to open.
class _DouyuCookieTip extends StatelessWidget {
  const _DouyuCookieTip({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final body = AppTextStyles.t13.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      height: 1.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(i18n('douyu_cookie_tip_step1'), style: body),
        const SizedBox(height: 8),
        Text(i18n('douyu_cookie_tip_step2'), style: body),
        const SizedBox(height: 6),
        InkWell(
          onTap: _openPassport,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.open_in_new, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'https://passport.douyu.com/',
                  style: body.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(i18n('douyu_cookie_tip_lifetime'), style: body),
      ],
    );
  }

  Future<void> _openPassport() async {
    try {
      await launchUrl(_passportUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No browser (a test host, a stripped-down device): the address is on
      // screen and can be typed instead.
    }
  }
}
