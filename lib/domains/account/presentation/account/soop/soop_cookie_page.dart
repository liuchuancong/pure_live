import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/account/presentation/account/soop/soop_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/account_cookie_editor.dart';

class SoopCookiePage extends GetView<SoopCookieBindingCookieController> {
  const SoopCookiePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountCookieEditorPage(
      controller: controller.cookieController,
      hintText: i18n('soop_cookie_hint'),
      tipText: i18n('soop_cookie_tip'),
      onSave: controller.setCookie,
    );
  }
}
