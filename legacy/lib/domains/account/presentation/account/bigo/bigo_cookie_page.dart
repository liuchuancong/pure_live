import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/account/presentation/account/account_cookie_editor.dart';
import 'package:pure_live/domains/account/presentation/account/bigo/bigo_cookie_controller.dart';

class BigoCookiePage extends GetView<BigoCookieBindingCookieController> {
  const BigoCookiePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountCookieEditorPage(
      controller: controller.cookieController,
      hintText: i18n('cookie_hint', args: {'name': 'BIGO'}),
      tipText: i18n('cookie_tip', args: {'name': 'BIGO'}),
      onSave: controller.setCookie,
    );
  }
}
