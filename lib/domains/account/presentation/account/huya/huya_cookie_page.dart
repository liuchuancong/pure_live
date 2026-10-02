import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/account/presentation/account/huya/huya_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/account_cookie_editor.dart';

class HuyaCookiePage extends GetView<HuyaCookieController> {
  const HuyaCookiePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountCookieEditorPage(
      controller: controller.cookieController,
      hintText: i18n('huya_cookie_hint'),
      tipText: i18n('huya_cookie_tip'),
      onSave: controller.setCookie,
    );
  }
}
