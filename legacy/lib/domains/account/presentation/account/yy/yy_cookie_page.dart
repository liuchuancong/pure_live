import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/account/presentation/account/account_cookie_editor.dart';
import 'package:pure_live/domains/account/presentation/account/yy/yy_cookie_controller.dart';

class YyCookiePage extends GetView<YyCookieBindingCookieController> {
  const YyCookiePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountCookieEditorPage(
      controller: controller.cookieController,
      hintText: i18n('cookie_hint', args: {'name': 'YY'}),
      tipText: i18n('cookie_tip', args: {'name': 'YY'}),
      onSave: controller.setCookie,
    );
  }
}
